#!/bin/sh

# This is just a tiny wrapper script so you don't have to memorize arguments

ACTION=${1:?}
INPUT_ASM_FILE_PATH=${2:?}
OUTPUT_DIR=${3:?}

INPUT_ASM_FILE_NAME="$(basename "$INPUT_ASM_FILE_PATH")"
DOCKER_IMAGE_NAME="masm-cross:latest"

mkdir -p "$OUTPUT_DIR" || return

docker run \
	--rm \
	--interactive \
	--tty \
	--mount type=bind,ro=true,source="$INPUT_ASM_FILE_PATH",destination="/build/$INPUT_ASM_FILE_NAME" \
	--mount type=bind,ro=false,source="$OUTPUT_DIR",destination=/out \
	"$DOCKER_IMAGE_NAME" \
	"$ACTION" \
	"/build/$INPUT_ASM_FILE_NAME"
