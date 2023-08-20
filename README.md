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

### run.sh

For convenience and in accordance with the CG spec, paradox includes a `run.sh` script that will automatically compile and execute a file.

```sh
./run.sh my_file.false
```

### Error handling

Due to lack of `stderr` access in FALSE, syntax errors are emitted as `%fatal` NASM-directives, so you will see them at the assembly stage. `bootstrap.lua` uses stderr and a nonzero exit code to signal errors.

### I/O Buffering

Paradox currently does not buffer I/O (using syscalls directly) but will do so in the future. B/ß are no-ops.

### Inline assembly

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

### Pointer arithmetic

Paradox (coincidentally) supports pointer arithmetic. Pointers and numbers can be added and subtracted using `+` and `-`.

Note that addition and subtraction (as well as other arithmetic and bitwise operations) operate on 32-bit numbers while pointers are 64-bit, so it will only work reliably as long as the pointers are in the appropriate range.

 `;` can be used to read from a pointer; `:` can be used to write to a pointer. Both operations read/write 64 bits.

To read and write individual bytes, one can use bitwise operations.

Variables and lambdas are pointers.

#### String pointers

`["my_stringy"]$12+;$@21+;+\[$@$@>][1-$;,\]#%%10,` will print my_stringy in reverse (ygnirts_ym). This works with any string. This is due to the binary layout of lambdas containing a single string (consisting of just a syscall to print out the string):

```
0000000000401002 <fun_1>:
	 401002:	b8 01 00 00 00       	mov    eax,0x1
	 401007:	bf 01 00 00 00       	mov    edi,0x1
	 40100c:	48 be 1e 10 40 00 00 	movabs rsi,0x40101e
	 401013:	00 00 00
	 401016:	ba 0a 00 00 00       	mov    edx,0xa
	 40101b:	0f 05                	syscall
	 40101d:	c3                   	ret
```

A pointer to the string is stored at offset 12, and the length is stored at offset 21.

Strings are stored in the data section, so it is possible to write to them.

It is possible to make memory allocations using strings by compiling your program like so:

```sh
(echo "[\"$(head -c YOUR_ALLOCATION_SIZE /dev/zero)\"]" && cat your_source_file.false) | ./paradox
```

In the program, you can then use `12+;` at the beginning of the file to extract a pointer to your allocation.

Since all operations fetch 64-bits, it is recommended to set the allocation size to 7 bytes higher than desired (if you wish to fetch/write the last few bytes of the allocation individually).
