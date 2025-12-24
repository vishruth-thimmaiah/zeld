# Zeld
A small linker built with zig, that can link Elf64 files.

[![Tests](https://github.com/vishruth-thimmaiah/zeld/actions/workflows/run_tests.yml/badge.svg)](https://github.com/vishruth-thimmaiah/zeld/actions/workflows/run_tests.yml)

## Build

```sh
zig build
```

## Usage

```sh
./zig-out/bin/zeld --help
```

## Flags

```
Usage: zeld [options] <input files>
  Options:
    -o, --output <file>    Specify the output file
    -r, --relocatable      Create a relocatable file
    -dynamic-linker <file> Specify the dynamic linker
    -h, --help             Display this help message
```

A few example binaries can be found in the `examples` directory.
