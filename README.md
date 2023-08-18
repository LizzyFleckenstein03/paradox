# Paradox: A self-hosted FALSE compiler for Linux x86-64

Paradox is a FALSE compiler emitting 64-bit NASM, written in FALSE itself, targeting the Linux syscall ABI.

Made for [code guessing, round #41](https://cg.esolangs.gay/41/).

Prerequisites: You need NASM and an ELF64 linker in addition to paradox to compile programs.

You can use an existing FALSE implementation or the included bootstram.asm to bootstrap paradox.

## Bootstrapping using bootstrap.asm

```sh
# compile bootstrap
nasm -f elf64 bootstrap.asm && ld bootstrap.o -o bootstrap

# use bootstrap to compile paradox
./bootstrap < paradox.false > paradox.asm && nasm -f elf64 paradox.asm && ld paradox.o -o paradox

# verify the resulting binaries are equal
diff bootstrap paradox
```

## Bootstrapping using an existing FALSE implementation

Note: paradox uses ø and ß rather than O and B in its own source code. It still supports O and B; to bootstrap paradox with a FALSE implementation that does not support these symbols, use `sed -i 's/ø/O/g;s/ß/B/g' paradox.false` to substitute them.

```sh
# build stage2 using an existing false implementation to run paradox ("stage 1")
existing_run_false paradox.false < paradox.false > stage2.asm && nasm -f elf64 stage2.asm && ld stage2.o -o stage2

# rebuild paradox with itself (stage 3)
./stage2 < paradox.false > stage3.asm && nasm -f elf64 stage3.asm && ld stage3.o -o paradox

# verify the resulting binaries are equal
diff stage2 paradox
```

## Additional notes

For convenience and to conform with the CG spec, paradox includes a `run.sh` script that will automatically compile and execute a file.
```sh
./run.sh my_file.false
```
