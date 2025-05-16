# Zeld
A basic linker built with zig, that can link Elf64 files.

[![Tests](https://github.com/vishruth-thimmaiah/zeld/actions/workflows/run_tests.yml/badge.svg)](https://github.com/vishruth-thimmaiah/zeld/actions/workflows/run_tests.yml)

> **Project Naming and Inspiration**  
> This project is named after 
> [The Legend of Zelda game series](https://en.wikipedia.org/wiki/The_Legend_of_Zelda),
> and its aptly named protagonist, Link. In keeping with the common
> convention for linker names to end in 'ld'(examples: ld, lld, gold, mold),
> this project follows a similar pattern. Additionally, since it is written in
> Zig, the name begins with 'z'.

>[!NOTE]
> This is a small project I made to learn the basics of linking ELF files.

## Build:
```bash
zig build
```
## Run:
```bash
zig build run -- <path to files>
```

## Running the given examples

### Generating relocatables
```bash
gcc -o examples/2/test.o examples/2/test.c -c
gcc -o examples/2/main.o examples/2/main.c -c
zig build run -- -r examples/2/test.o examples/2/main.o -o output.o
gcc -o output output.o       # Build an executable from the generated relocatable.
```

### Generating executables
```bash
gcc -o examples/3/main.o examples/3/main.s -c
zig build run -- examples/3/main.o -o output
```

Using clang as your compiler *should* also work.

## Running tests
```bash
zig build test
```


## ELF specification
#### [elf.pdf](https://refspecs.linuxfoundation.org/elf/elf.pdf)  
You can also check out `/usr/include/elf.h`.

## Projects that I've referenced
- [byo-linker](https://github.com/andrewhalle/byo-linker)
