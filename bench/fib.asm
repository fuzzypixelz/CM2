# This sample program calculates fib(32)
@start                  # this calls the main function and then stops execution
  call 0 2 @main        # jump to @main, reserve 2 registers
  li r0 0               # r0 = 0
  exit r0               # exit with code r0
@main
  li r1 32              # change the input to @fib here
  call 1 5 @fib         # jump to @fib, reserve 5 registers, copy r1
  put r0                # print r0 to stdout
  ret                   # return to call site, free regs
@fib
  li r2 2               # r2 = 2
  bge r1 r2 @ge_two     # jump to @ge_two if r1 >= r2
@lt_two
  cp r0 r1              # r0 = r1
  ret
@ge_two
  li r3 1               # r3 = 1
  sub r1 r1 r3          # r1 = r1 - r3
  call 1 5 @fib
  li r4 0               # r4 = 0, registers are not zeroed between calls
  add r4 r4 r0          # r4 = r4 - r0
  sub r1 r1 r3          # r1 = r1 - r3
  call 1 5 @fib
  add r4 r4 r0          # r4 = r4 - r0
  cp r0 r4              # r0 = r4
  ret
