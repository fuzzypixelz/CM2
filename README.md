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
zig build-exe -O ReleaseFast main.zig --name cm2
```

The `program` global variable currently contains a hardcoded example assembly program that computes the 35th element of the Fibonacci sequence. You can play around with it to run your own programs. There is no assembler nor any bytecode reader.

## Preliminary Benchmarks

The following was obtained on an x86_64 Linux system running an `Intel(R) Core(TM) i5-6300U CPU @ 2.40GHz`.

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `./cm2` | 479.1 ± 5.2 | 476.3 | 493.6 | 1.00 |
| `lua bench/fib.lua` | 882.6 ± 10.9 | 876.4 | 913.3 | 1.84 ± 0.03 |
| `python3 bench/fib.py` | 3179.3 ± 27.9 | 3147.8 | 3231.2 | 6.64 ± 0.09 |
