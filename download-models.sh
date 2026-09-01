#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
readonly SCRIPT_DIR
readonly MODELS_DIR="${SCRIPT_DIR}/models"

readonly MODEL_2B_NAME="Qwen3.5-2B-UD-Q4_K_XL.gguf"
readonly MODEL_2B_URL="https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/f6d5376be1edb4d416d56da11e5397a961aca8ae/Qwen3.5-2B-UD-Q4_K_XL.gguf"
readonly MODEL_2B_SHA256="0af96165ea615bea39a04118d63f0b6d35908aea850ee4a51aa6151d851b8b35"
readonly MODEL_2B_SIZE=1339752704

readonly MODEL_4B_NAME="Qwen3.5-4B-UD-Q4_K_XL.gguf"
readonly MODEL_4B_URL="https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/e87f176479d0855a907a41277aca2f8ee7a09523/Qwen3.5-4B-UD-Q4_K_XL.gguf"
readonly MODEL_4B_SHA256="b252c5610a42ca82d20fe2a12813e9d069eed89292907e26c783eeb0bc961bc7"
readonly MODEL_4B_SIZE=2912109728

readonly WHISPER_NAME="whisper-base.en-q8_0.bin"
readonly WHISPER_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.en-q8_0.bin"
readonly WHISPER_SHA256="a4d4a0768075e13cfd7e19df3ae2dbc4a68d37d36a7dad45e8410c9a34f8c87e"
readonly WHISPER_SIZE=81781811

usage() {
    printf 'Usage: %s [all|2b|4b|whisper]...\n' "${0##*/}"
    printf 'With no arguments, all three models are selected.\n'
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

want_2b=0
want_4b=0
want_whisper=0

if (( $# == 0 )); then
    set -- all
fi

for selection in "$@"; do
    case "$selection" in
        all)
            want_2b=1
            want_4b=1
            want_whisper=1
            ;;
        2b)
            want_2b=1
            ;;
        4b)
            want_4b=1
            ;;
        whisper)
            want_whisper=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Error: unknown model selection: %s\n' "$selection" >&2
            usage >&2
            exit 2
            ;;
    esac
done

total_size=0
selected_models=""
if (( want_2b )); then
    (( total_size += MODEL_2B_SIZE ))
    selected_models="${selected_models} 2b"
fi
if (( want_4b )); then
    (( total_size += MODEL_4B_SIZE ))
    selected_models="${selected_models} 4b"
fi
if (( want_whisper )); then
    (( total_size += WHISPER_SIZE ))
    selected_models="${selected_models} whisper"
fi

printf 'Selected models: %s\n' "${selected_models# }"
printf 'Selected download size if absent: %d bytes (about %d MiB)\n' \
    "$total_size" "$(( (total_size + 524288) / 1048576 ))"

mkdir -p -- "$MODELS_DIR"

if command -v sha256sum >/dev/null 2>&1; then
    hash_tool="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    hash_tool="shasum"
elif command -v openssl >/dev/null 2>&1; then
    hash_tool="openssl"
else
    die "SHA-256 verification requires sha256sum, shasum, or openssl."
fi

if command -v curl >/dev/null 2>&1; then
    downloader="curl"
elif command -v wget >/dev/null 2>&1; then
    downloader="wget"
else
    downloader=""
fi

sha256_of() {
    local file=$1
    local output

    case "$hash_tool" in
        sha256sum)
            output=$(sha256sum "$file")
            printf '%s\n' "${output%% *}"
            ;;
        shasum)
            output=$(shasum -a 256 "$file")
            printf '%s\n' "${output%% *}"
            ;;
        openssl)
            output=$(openssl dgst -sha256 "$file")
            printf '%s\n' "${output##* }"
            ;;
    esac
}

download_to_partial() {
    local url=$1
    local partial=$2

    case "$downloader" in
        curl)
            curl -fL --retry 3 -C - -o "$partial" "$url"
            ;;
        wget)
            wget -c -O "$partial" "$url"
            ;;
        *)
            die "downloading requires curl or wget, but neither was found."
            ;;
    esac
}

active_partial=""
handle_interrupt() {
    if [[ -n ${active_partial:-} && -f "$active_partial" ]]; then
        printf '\nInterrupted; partial download kept for resume: %s\n' \
            "$active_partial" >&2
    elif [[ -n ${active_partial:-} ]]; then
        printf '\nInterrupted before a partial download was created.\n' >&2
    fi
    exit 130
}
trap handle_interrupt HUP INT TERM

fetch_model() {
    local name=$1
    local url=$2
    local expected_hash=$3
    local expected_size=$4
    local destination="${MODELS_DIR}/${name}"
    local partial="${MODELS_DIR}/.${name}.${expected_hash}.part"
    local actual_hash
    local partial_size

    if [[ -L "$destination" || -L "$partial" ]]; then
        die "refusing to use a symbolic link as a model or partial file: $name"
    fi

    if [[ -e "$destination" && ! -f "$destination" ]]; then
        die "model path exists but is not a regular file: $destination"
    fi

    if [[ -f "$destination" ]]; then
        actual_hash=$(sha256_of "$destination")
        if [[ "$actual_hash" == "$expected_hash" ]]; then
            if [[ -f "$partial" ]]; then
                rm -f -- "$partial"
            elif [[ -e "$partial" ]]; then
                die "partial path exists but is not a regular file: $partial"
            fi
            printf 'Already present and verified; skipping: %s\n' "$name"
            return
        fi
        printf 'Existing file has the wrong SHA-256; downloading a verified replacement: %s\n' \
            "$name" >&2
    fi

    if [[ -e "$partial" && ! -f "$partial" ]]; then
        die "partial path exists but is not a regular file: $partial"
    fi

    if [[ -f "$partial" ]]; then
        partial_size=$(wc -c < "$partial")
        if (( partial_size > expected_size )); then
            printf 'Discarding oversized partial: %s\n' \
                "$partial" >&2
            rm -f -- "$partial"
        elif (( partial_size == expected_size )); then
            actual_hash=$(sha256_of "$partial")
            if [[ "$actual_hash" == "$expected_hash" ]]; then
                mv -f -- "$partial" "$destination"
                printf 'Verified and installed completed partial: %s\n' "$name"
                return
            fi
            printf 'Discarding completed partial with the wrong SHA-256: %s\n' \
                "$partial" >&2
            rm -f -- "$partial"
        else
            printf 'Resuming partial download at %d of %d bytes: %s\n' \
                "$partial_size" "$expected_size" "$name"
        fi
    fi

    printf 'Downloading with %s: %s\n' "${downloader:-no available downloader}" "$name"
    active_partial=$partial
    if ! download_to_partial "$url" "$partial"; then
        if [[ -f "$partial" ]]; then
            printf 'Error: download failed; partial kept for resume: %s\n' \
                "$partial" >&2
        else
            printf 'Error: download failed before a partial file was created.\n' >&2
        fi
        active_partial=""
        return 1
    fi
    active_partial=""

    partial_size=$(wc -c < "$partial")
    if (( partial_size != expected_size )); then
        rm -f -- "$partial"
        printf 'Error: size mismatch for %s.\n' "$name" >&2
        printf 'Expected: %d bytes\nActual:   %d bytes\n' \
            "$expected_size" "$partial_size" >&2
        printf 'The invalid partial was removed.\n' >&2
        return 1
    fi

    actual_hash=$(sha256_of "$partial")
    if [[ "$actual_hash" != "$expected_hash" ]]; then
        rm -f -- "$partial"
        printf 'Error: SHA-256 mismatch for %s.\n' "$name" >&2
        printf 'Expected: %s\nActual:   %s\n' "$expected_hash" "$actual_hash" >&2
        printf 'The invalid partial was removed; the transfer may be corrupt or upstream storage may be inconsistent.\n' >&2
        return 1
    fi

    mv -f -- "$partial" "$destination"
    printf 'Verified and installed: %s\n' "$name"
}

if (( want_2b )); then
    fetch_model "$MODEL_2B_NAME" "$MODEL_2B_URL" "$MODEL_2B_SHA256" "$MODEL_2B_SIZE"
fi
if (( want_4b )); then
    fetch_model "$MODEL_4B_NAME" "$MODEL_4B_URL" "$MODEL_4B_SHA256" "$MODEL_4B_SIZE"
fi
if (( want_whisper )); then
    fetch_model "$WHISPER_NAME" "$WHISPER_URL" "$WHISPER_SHA256" "$WHISPER_SIZE"
fi

printf 'All selected models are ready.\n'
