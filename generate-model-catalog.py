#!/usr/bin/env python3
# Copyright (C) 2026 The MosaicOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
BLOCK = 4096
REDIRECT_HOSTS = ['us.aws.cdn.hf.co', 'us.gcp.cdn.hf.co', 'cdn-lfs-us-1.hf.co',
                  'cdn-lfs-eu-1.hf.co', 'cas-bridge.xethub.hf.co']


def verified_entry(prefix, model_id, engine, kind, pins):
    def pin(suffix):
        match = re.search(r'^readonly ' + prefix + '_' + suffix + r'="?([^"\n]+)"?$',
                          pins, re.MULTILINE)
        if not match:
            raise ValueError('Missing pin: ' + prefix + '_' + suffix)
        return match[1]

    name, size, expected = pin('NAME'), int(pin('SIZE')), pin('SHA256')
    if Path(name).name != name or not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise ValueError('Invalid model pin')
    source_url = pin('URL')
    url = urlsplit(source_url)
    if (url.scheme != 'https' or url.netloc != 'huggingface.co' or url.query or url.fragment
            or not re.fullmatch(r'/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/resolve/[0-9a-f]{40}/[A-Za-z0-9._-]+', url.path)):
        raise ValueError('Source must be a pinned HTTPS Hugging Face revision')
    fd = os.open(ROOT / 'models' / name, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as source:
        info = os.fstat(source.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size != size:
            raise ValueError('Model type or size mismatch: ' + model_id)
        digest = hashlib.sha256()
        leaves = bytearray()
        total = 0
        while block := source.read(BLOCK):
            total += len(block)
            if total > size:
                raise ValueError('Model exceeds pinned size: ' + model_id)
            digest.update(block)
            leaves.extend(hashlib.sha256(block.ljust(BLOCK, b'\0')).digest())
        if total != size or digest.hexdigest() != expected:
            raise ValueError('Pinned SHA-256 mismatch: ' + model_id)
        while len(leaves) > 32:
            leaves = bytearray().join(hashlib.sha256(leaves[i:i + BLOCK].ljust(BLOCK, b'\0')).digest()
                                     for i in range(0, len(leaves), BLOCK))
        descriptor = struct.pack('<BBBBIQ64s32s144s', 1, 1, 12, 0, 0, size,
                                 bytes(leaves), b'', b'')
        verity = hashlib.sha256(descriptor).hexdigest()
        reference = subprocess.run(
            ['fsverity', 'digest', '--hash-alg=sha256', '--block-size=4096',
             '/proc/self/fd/' + str(source.fileno())],
            pass_fds=(source.fileno(),), stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        if reference.stdout.split()[0] != ('sha256:' + verity).encode('ascii'):
            raise ValueError('fsverity utility disagrees with catalog digest: ' + model_id)
    return dict(id=model_id, file=name, kind=kind, size=size, sha256=expected,
                sourceUrl=source_url, redirectHosts=REDIRECT_HOSTS,
                verity=verity, verityVersion=1,
                verityAlgorithm='sha256', verityBlockSize=BLOCK, veritySalt='',
                engine=engine, format='gguf' if kind == 'chat' else 'whisper-ggml')


def main():
    pins = (ROOT / 'download-models.sh').read_text(encoding='utf-8')
    models = [verified_entry('MODEL_2B', 'chat-2b', 'llama-b10737-mosaic-1', 'chat', pins),
              verified_entry('MODEL_4B', 'chat-4b', 'llama-b10737-mosaic-1', 'chat', pins),
              verified_entry('WHISPER', 'speech-en', 'whisper-v1.9.3-mosaic-1', 'speech', pins)]
    destination = ROOT / 'catalog'
    destination.mkdir(exist_ok=True)
    for tier in ('2b', '4b'):
        catalog = dict(schema=2, recommendedChat='chat-' + tier, models=models)
        output = destination / ('catalog-' + tier + '.json')
        temporary = output.with_suffix('.tmp')
        with temporary.open('wb') as stream:
            stream.write((json.dumps(catalog, indent=2) + '\n').encode('utf-8'))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, output)
    print('Catalogs generated from all three pinned model byte streams.')


if __name__ == '__main__':
    main()
