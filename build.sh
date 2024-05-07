#!/usr/bin/env bash

: EXTRA_LIB_PATH="${1:?}" || EXTRA_LIB_PATH="$(readlink -f ./lib)"

MINGW=/usr/i686-w64-mingw32
EXTRA_LIB_NAME="Irvine32"

build() {
	uasm -nologo -c -Fl=listing_file.lst -Zd -Zi -elf \
		-I "$EXTRA_LIB_PATH" -I $MINGW/include \
		"$INPUT_ASM_FILE_PATH"
}

link() {
	i686-w64-mingw32-ld -nostdlib \
		"${ASM_BASENAME}.o" \
		-I "$EXTRA_LIB_PATH" -I $MINGW/include \
		-L "$EXTRA_LIB_PATH" -L $MINGW/lib \
		--start-group \
		-l kernel32 \
		-l user32 \
		-l gdi32 \
		-l winspool \
		-l comdlg32 \
		-l advapi32 \
		-l shell32 \
		-l ole32 \
		-l oleaut32 \
		-l uuid \
		-l odbc32 \
		-l odbccp32 \
		-l "$EXTRA_LIB_NAME" \
		--end-group \
		-o "${ASM_BASENAME}.exe"
}

main() {
	INPUT_ASM_FILE_PATH="${1:?}"
	INPUT_ASM_FILE_PATH="$(readlink -f "$INPUT_ASM_FILE_PATH")"
	ASM_BASENAME="$(basename -s .asm "$INPUT_ASM_FILE_PATH")"

	mkdir -p build
	cd build || return

	build
	link
}

main "$@"
