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

readonly WHISPER_EN_SMALL_NAME="whisper-small.en-q8_0.bin"
readonly WHISPER_EN_SMALL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/\
5359861c739e955e79d9a303bcbc70fb988958b1/ggml-small.en-q8_0.bin"
readonly WHISPER_EN_SMALL_SHA256="67a179f608ea6114bd3fdb9060e762b588a3fb3bd00c4387971be4d177958067"
readonly WHISPER_EN_SMALL_SIZE=264477561

readonly VOICE_HU_ANNA_NAME="piper-hu_HU-anna-medium.onnx"
readonly VOICE_HU_ANNA_URL="https://huggingface.co/rhasspy/piper-voices/resolve/\
c10ece1aade47bb51c153c893d14e5bf8e5b7117/hu/hu_HU/anna/medium/hu_HU-anna-medium.onnx"
readonly VOICE_HU_ANNA_COMMIT="c10ece1aade47bb51c153c893d14e5bf8e5b7117"
readonly VOICE_HU_ANNA_SHA256="968c0c3a66cb667811242cc88653bff9247395fc7a0517fbeef7d8c08cdae62a"
readonly VOICE_HU_ANNA_SIZE=63201294

readonly ORT_NAME="onnxruntime-android-1.31.0.aar"
readonly ORT_URL="https://repo.maven.apache.org/maven2/com/microsoft/onnxruntime/\
onnxruntime-android/1.31.0/onnxruntime-android-1.31.0.aar"
readonly ORT_SHA256="72683787a80d0608a3121b967d8e1239aef48286826661c953211626690540a7"
readonly ORT_SIZE=55138854
readonly ORT_DIR="${SCRIPT_DIR}/prebuilts/onnxruntime"

pinned_model_url() {
    local url=$1
    local LC_ALL=C
    (( ${#url} <= 8192 )) || return 1
    local commit=${2:-'[0-9a-f]{40}'}
    local pattern='^https://huggingface.co/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/resolve/'
    pattern+="${commit}/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$"
    [[ "$url" =~ $pattern ]] || return 1
    local part
    local -a parts
    IFS='/' read -r -a parts <<< "${url#https://huggingface.co/}"
    for part in "${parts[@]}"; do
        [[ "$part" != . && "$part" != .. ]] || return 1
    done
}

usage() {
    printf 'Usage: %s [all|2b|4b|whisper|whisper-en-small|voice-hu|ort]...\n' "${0##*/}"
    printf 'With no arguments, all models and the TTS runtime are selected.\n'
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

pin_value() {
    local key="${1}_${2}"
    printf '%s' "${!key:-}"
}

if (( $# == 0 )); then
    set -- all
fi
requested=()
for selection in "$@"; do
    case "$selection" in
        all) requested+=(MODEL_2B MODEL_4B WHISPER WHISPER_EN_SMALL VOICE_HU_ANNA ORT) ;;
        2b) requested+=(MODEL_2B) ;;
        4b) requested+=(MODEL_4B) ;;
        whisper) requested+=(WHISPER) ;;
        whisper-en-small) requested+=(WHISPER_EN_SMALL) ;;
        voice-hu) requested+=(VOICE_HU_ANNA) ;;
        ort) requested+=(ORT) ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown model selection: $selection" ;;
    esac
done

selected=()
selected_models=""
total_size=0
for prefix in "${requested[@]}"; do
    [[ " ${selected[*]} " != *" $prefix "* ]] || continue
    if [[ "$prefix" != ORT ]]; then
        pinned_model_url "$(pin_value "$prefix" URL)" || die "Invalid pinned URL for $prefix"
    fi
    selected+=("$prefix")
    selected_models+=" $(pin_value "$prefix" NAME)"
    (( total_size += $(pin_value "$prefix" SIZE) ))
done

printf 'Selected models: %s\n' "${selected_models# }"
printf 'Selected download size if absent: %d bytes (about %d MiB)\n' \
    "$total_size" "$(( (total_size + 524288) / 1048576 ))"

mkdir -p -- "$MODELS_DIR" "$ORT_DIR"

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
    local directory=${5:-$MODELS_DIR}
    local destination="${directory}/${name}"
    local partial="${directory}/.${name}.${expected_hash}.part"
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
        if [[ "$actual_hash" == "$expected_hash" && $(wc -c < "$destination") == "$expected_size" ]]; then
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

for prefix in "${selected[@]}"; do
    directory=$MODELS_DIR
    [[ "$prefix" != ORT ]] || directory=$ORT_DIR
    fetch_model "$(pin_value "$prefix" NAME)" "$(pin_value "$prefix" URL)" \
        "$(pin_value "$prefix" SHA256)" "$(pin_value "$prefix" SIZE)" "$directory"
done

printf 'All selected models are ready.\n'
