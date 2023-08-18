# Paradox: A self-hosted FALSE compiler for Linux x86-64

Paradox is a FALSE compiler emitting 64-bit NASM, written in FALSE itself and targeting the Linux syscall ABI.

Made for [code guessing, round #41](https://cg.esolangs.gay/41/).

Prerequisites: You need NASM and a linker in addition to paradox to compile programs.

You can use an existing FALSE implementation or the included bootstrap.lua to bootstrap paradox.

## Bootstrapping

### Using bootstrap.lua

For any given correct input, bootstrap.lua output is (supposed to be) equivalent to paradox output.
This means you can use bootstrap.lua as a feature-complete substitue for paradox.

```sh
# compile paradox using bootstrap.lua
./bootstrap.lua < paradox.false > paradox.asm && nasm -f elf64 paradox.asm && ld paradox.o -o paradox
```

### Using an existing FALSE implementation

Note: paradox uses ø and ß rather than O and B in its own source code. It still supports O and B; to bootstrap paradox with a FALSE implementation that does not support these symbols, use `sed -i 's/ø/O/g;s/ß/B/g' paradox.false` to substitute them.

Note: bootstrapping paradox has been tested with several standard compliant FALSE implementations. If it does not work with a certain implementation, it's likely due to a bug in that implementation.

```sh
# make paradox build itself using an existing false implementation to run paradox
existing_run_false paradox.false < paradox.false > paradox.asm && nasm -f elf64 paradox.asm && ld paradox.o -o paradox
```

## Recompiling self

Paradox can (obviously) rebuild itself once it has been bootstrapped, and the result should be equivalent.

```sh
# rebuild paradox using itself
./paradox < paradox.false > paradox2.asm && nasm -f elf64 paradox2.asm && ld paradox2.o -o paradox2

# verify the resulting binaries are equal
diff paradox paradox2
```

## Additional notes

For convenience and in accordance with the CG spec, paradox includes a `run.sh` script that will automatically compile and execute a file.

```sh
./run.sh my_file.false
```

Syntax errors are emitted as `%fatal` NASM-directives, so you will see them at the assembly stage.

Paradox issues syscalls for I/O directly without buffering; ß/B are no-ops in paradox.

Paradox has its own inline assembly syntax: anything between backticks is emitted as assembly, like so:

```
"hi"

{ issue exit(0) syscall }
`mov rax, 60
mov rdi, 0
syscall
`

"bye"
```

The output should be just "hi", without "bye".

## A challenge for the reader

Check the output of `["my_stringy"]$12+;$@21+;+\[$@$@>][1-$;,\]#%%10,`. Replace my_stringy by a different string and check the output. Try to make sense of how & why this works.
