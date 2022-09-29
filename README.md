# CM2: Chimera Meta Machine

## What is this?

This is a process virtual machine where execution is driven by tail calls,
and function calls in bytecode correspond to Zig function calls.
Locals are stored in a stack of registers and calls explicitly allocate the frame size,

The aim of this design (present in the [wasm3](https://github.com/wasm3/wasm3) interpreter) is to use Zig suspend/resume
to implement a limited form of algebraic effects (think resumable exceptions). Ultimately, CM2 will be a runtime for the [Chimera](https://github.com/fuzzypixelz/Chimera) programming language.

## How do I run it?

Note that I only tested this on x86_64 Linux with Zig 0.10-dev.

Assuming you have a Zig toolchain up and running, I recommend you compile `cm2` in fast release mode:

```console
# gotta go fast
zig build-exe -O ReleaseFast cm2.zig -fstage1 --strip
```

The `cm2` commandline program accepts a `file.cm2` binary executable that's very hard to read and write.
Instead, you can write CM2 programs in ASCII assembly and generate binary executables from them using the
`asm.py` program.

You can start with the `bench/fib.asm` assembly program since it has comments explaining what each instruction does:

```console
# outputs bench/fib.cm2
./asm.py bench/fib.asm
# fib(32) = 2178309
./cm2 bench/fib/cm2
```

There is no full documentation of the bytecode, outside of comments in `cm2.zig`, just yet.

## Preliminary Benchmarks

The following was obtained on an x86_64 Linux system running an `Intel(R) Core(TM) i5-6300U CPU @ 2.40GHz`.
You can see that CM2 is on par with wasm3, which is to be expected.

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `./cm2 bench/fib.cm2` | 185.2 ± 3.6 | 177.7 | 192.5 | 1.00 |
| `./wasm3-cosmopolitan.com --func fib bench/fib32.wasm 32` | 210.7 ± 1.5 | 208.7 | 214.0 | 1.14 ± 0.02 |
| `lua bench/fib.lua` | 347.4 ± 5.6 | 341.3 | 356.3 | 1.88 ± 0.05 |
