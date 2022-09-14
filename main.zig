const std = @import("std");

pub fn main() void {
    CM2.start();
}

// This sample program calculates fib(35) where:
// fib(n) =
//   if n > 2 then n
//   else fib(n - 1) + fib(n - 2)
const program = [_]Instruction{
    // begin/setup
    .{ .op = CM2.call, .d0 = 0, .d1 = 2, .d2 = 3 },
    .{ .op = CM2.li, .d0 = 0, .d1 = 0 },
    .{ .op = CM2.exit, .d0 = 0 },
    .{ .op = CM2.li, .d0 = 1, .d1 = 35 }, // INPUT
    .{ .op = CM2.call, .d0 = 1, .d1 = 5, .d2 = 7 },
    .{ .op = CM2.put, .d0 = 0 },
    .{ .op = CM2.ret },
    // r2 = 2
    .{ .op = CM2.li, .d0 = 2, .d1 = 2 },
    // if/else
    .{ .op = CM2.bge, .d0 = 1, .d1 = 2, .d2 = 11 },
    // case: n < 2
    .{ .op = CM2.cp, .d0 = 0, .d1 = 1 },
    // retrun r0
    .{ .op = CM2.ret },
    // case: n >= 2
    // r3 = 1
    .{ .op = CM2.li, .d0 = 3, .d1 = 1 },
    // r1 = r1 - r3
    .{ .op = CM2.sub, .d0 = 1, .d1 = 1, .d2 = 3 },
    // r0 = fib(r1)
    .{ .op = CM2.call, .d0 = 1, .d1 = 5, .d2 = 7 },
    // r4 = 0
    .{ .op = CM2.li, .d0 = 4, .d1 = 0 },
    // r4 = r4 + r0
    .{ .op = CM2.add, .d0 = 4, .d1 = 4, .d2 = 0 },
    // r1 = r1 - r3 = r1 - 1
    .{ .op = CM2.sub, .d0 = 1, .d1 = 1, .d2 = 3 },
    // r0 = fib(r1)
    .{ .op = CM2.call, .d0 = 1, .d1 = 5, .d2 = 7 },
    // r4 = r4 + r0
    .{ .op = CM2.add, .d0 = 4, .d1 = 4, .d2 = 0 },
    // r0 = r4
    .{ .op = CM2.cp, .d0 = 0, .d1 = 4 },
    // retrun r0
    .{ .op = CM2.ret },
};

export var stack = [_]usize{0} ** 2048;

// Instruction opcode.
const Opcode = enum(usize) {
    li,
    cp,
    bge,
    ret,
    add,
    sub,
    call,
    exit,
    put,
};

// Reference to the function executed on each Instruction.
const Operation = *const fn (pc: usize, sp: usize) void;

// A mapping from Instruction opcodes to operations.
const ops: std.EnumArray(Opcode, Operation) = ops: {
    var map = std.EnumArray(Opcode, Operation).initUndefined();
    var iter = map.iterator();
    while (iter.next()) |entry| {
        entry.value.* = @field(CM2, @tagName(entry.key));
    }
    break :ops map;
};

// CM2 bytecode format.
const Instruction = struct {
    const Data = usize;

    op: Operation,
    d0: Data = 0,
    d1: Data = 0,
    d2: Data = 0,
};

// Chimera Meta Machine.
const CM2 = struct {
    // Start CM2.
    pub fn start() void {
        @call(
            .{ .modifier = .never_tail },
            program[0].op,
            .{ 0, 0 },
        );
    }
    // Load an immediate value into rX.
    // > li rX imm N/A
    pub fn li(pc: usize, sp: usize) void {
        const c = program[pc];
        stack[sp - c.d0] = c.d1;
        @call(
            .{ .modifier = .always_tail },
            program[pc + 1].op,
            .{ pc + 1, sp },
        );
    }
    // Copy the value of rY to rX.
    // > cp rX rY N/A
    pub fn cp(pc: usize, sp: usize) void {
        const c = program[pc];
        stack[sp - c.d0] = stack[sp - c.d1];
        @call(
            .{ .modifier = .always_tail },
            program[pc + 1].op,
            .{ pc + 1, sp },
        );
    }
    // Branch to lbl if rX is greater than or equal to rY.
    // > bge rX rY lbl
    pub fn bge(pc: usize, sp: usize) void {
        const c = program[pc];
        if (stack[sp - c.d0] >= stack[sp - c.d1]) {
            @call(
                .{ .modifier = .always_tail },
                program[c.d2].op,
                .{ c.d2, sp },
            );
        } else {
            @call(
                .{ .modifier = .always_tail },
                program[pc + 1].op,
                .{ pc + 1, sp },
            );
        }
    }
    // Return from a function by collapsing its frame.
    // > ret N/A N/A N/A
    pub fn ret(pc: usize, sp: usize) void {
        // Thanks Zig :P
        _ = pc;
        _ = sp;
        return;
    }
    // Write into rX the value of (rY + rZ).
    // > add rX rY rZ
    pub fn add(pc: usize, sp: usize) void {
        const c = program[pc];
        stack[sp - c.d0] = stack[sp - c.d1] + stack[sp - c.d2];
        @call(
            .{ .modifier = .always_tail },
            program[pc + 1].op,
            .{ pc + 1, sp },
        );
    }
    // Write into rX the value of (rY - rZ).
    // > sub rX rY rZ
    pub fn sub(pc: usize, sp: usize) void {
        const c = program[pc];
        stack[sp - c.d0] = stack[sp - c.d1] - stack[sp - c.d2];
        @call(
            .{ .modifier = .always_tail },
            program[pc + 1].op,
            .{ pc + 1, sp },
        );
    }
    // Call function with imm1 arguments, imm2 frame size and lbl branch target.
    // > call imm1 imm2 lbl
    // [ rN, ..., r0 ]
    //            ^ sp (rX = stack[X])
    pub fn call(pc: usize, sp: usize) void {
        const c = program[pc];
        const bp = sp + c.d1;
        std.mem.copy(
            usize,
            stack[(bp - c.d0)..bp],
            stack[(sp - c.d0)..sp],
        );
        @call(
            .{},
            program[c.d2].op,
            .{ c.d2, bp },
        );
        stack[sp] = stack[bp];
        @call(
            .{ .modifier = .always_tail },
            program[pc + 1].op,
            .{ pc + 1, sp },
        );
    }
    // Exit with rX code.
    // > exit rX N/A N/A
    pub fn exit(pc: usize, sp: usize) void {
        const c = program[pc];
        std.process.exit(@intCast(u8, stack[sp - c.d0]));
    }
    // Print a register to stdout.
    // > put rX N/A N/A
    pub fn put(pc: usize, sp: usize) void {
        const c = program[pc];
        std.io.getStdOut().writer().print("{}\n", .{stack[sp - c.d0]}) catch {
            // TODO: handle this.
        };
        @call(
            .{ .modifier = .always_tail },
            program[pc + 1].op,
            .{ pc + 1, sp },
        );
    }
};
