#!/bin/bash
set -e
./paradox < "$1" > "$1.asm"
nasm -f elf64 "/tmp/$1.asm" -o "/tmp/$1.o"
ld "/tmp/$1.o" -o "$1.bin"
./"$1.bin"
