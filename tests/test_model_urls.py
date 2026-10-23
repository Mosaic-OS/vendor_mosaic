#!/usr/bin/env python3
# Copyright (C) 2026 The MosaicOS Project
# SPDX-License-Identifier: Apache-2.0

import importlib.util
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('catalog', ROOT / 'generate-model-catalog.py')
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)
script = (ROOT / 'download-models.sh').read_text(encoding='utf-8')
function = script[script.index('pinned_model_url() {'):script.index('\n}\n', script.index('pinned_model_url() {')) + 3]


class ModelUrlTest(unittest.TestCase):
    def check_url(self, url, expected):
        self.assertEqual(expected, catalog.valid_model_url(url), url)
        result = subprocess.run(['bash', '-c', function + '\npinned_model_url "$1"\n', 'validator', url],
                                capture_output=True, check=False)
        self.assertEqual(expected, result.returncode == 0, url)

    def test_nested_paths(self):
        root = 'https://huggingface.co/test/model/resolve/' + 'c' * 40 + '/'
        for path in ['model.bin', 'hu/hu_HU/anna/medium/model.onnx', 'a_b-c.1/.hidden/model.bin']:
            self.check_url(root + path, True)
        for path in ['', '/model.bin', 'a//model.bin', 'a/./model.bin', 'a/../model.bin', './model.bin',
                     '../model.bin', 'a/', 'a/%2f/b', 'a/%2F/b', 'a/%5c/b', 'a/%2e%2e/b', 'a\\b',
                     'model.bin?', 'model.bin?x=1', 'model.bin#', 'model.bin#x', 'm odel.bin']:
            self.check_url(root + path, False)
        for url in [root.replace('https:', 'http:') + 'model.bin',
                    root.replace('huggingface.co', 'huggingface.co:443') + 'model.bin',
                    root.replace('huggingface.co', 'huggingface.co.evil') + 'model.bin',
                    root.replace('test/model', './model') + 'model.bin', '\n' + root + 'model.bin']:
            self.check_url(url, False)

    def test_all_actual_model_pins(self):
        pins = script.replace('\\\n', '')
        prefixes = re.findall(r'^readonly (.+)_URL=', pins, re.M)
        for prefix in prefixes:
            if prefix != 'ORT':
                self.check_url(catalog.pin_value(pins, prefix, 'URL'), True)
        self.assertEqual('63201294', catalog.pin_value(pins, 'VOICE_HU_ANNA', 'SIZE'))
        self.assertEqual('piper-hu_HU-anna-medium.onnx', catalog.pin_value(pins, 'VOICE_HU_ANNA', 'NAME'))


if __name__ == '__main__':
    unittest.main()
