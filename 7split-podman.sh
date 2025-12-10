#!/bin/bash
set -euo pipefail

APPNAME=$(basename "$0" | sed "s/\.sh$//" | sed "s/-podman$//")
PLATFORM='linux/amd64'

if [[ $# -lt 2 || -z "$1" || -z "$2" ]]; then
	echo "Usage: $(basename "$0") <input.mp4> <output.png> [OPTIONS]" >&2
	exit 1
fi

if [[ ! -f "$1" ]]; then
	echo "$APPNAME: Input path \"$1\" doesn't exist, or it's not a file." >&2
	exit 1
fi

realpath() {
  OURPWD=$PWD
  cd "$(dirname "$1")"
  LINK=$(readlink "$(basename "$1")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$1")")
  done
  REALPATH="$PWD/$(basename "$1")"
  cd "$OURPWD"
  echo "$REALPATH"
}

BASE_DIR="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
INPUT_PATH=$(realpath "$1")
INPUT_DIR=$(dirname "$INPUT_PATH")
INPUT_FILENAME=$(basename "$INPUT_PATH")
OUTPUT_PATH=$(realpath "$2")
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
OUTPUT_FILENAME=$(basename "$OUTPUT_PATH")

podman build --platform "$PLATFORM" -t "$APPNAME" .
podman run --rm \
  --platform "$PLATFORM" \
  -v "$BASE_DIR:/app" \
  -v "$INPUT_DIR:/7input" \
  -v "$OUTPUT_DIR:/7output" \
  "$APPNAME" app/7split.sh "/7input/$INPUT_FILENAME" "/7output/$OUTPUT_FILENAME" "${@:3}"
