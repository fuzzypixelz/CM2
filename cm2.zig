const std = @import("std");

// Type of virtual registers and instruction data.
const Register = usize;

// Instruction opcode.
const Opcode = enum(Register) {
    li,
    cp,
    bge,
    add,
    sub,
    call,
    ret,
    put,
    exit,
};

// Reference to the function executed on each Instruction.
const Operation = fn (pc: Register, sp: Register) void;

// CM2 bytecode format, after complilation.
// FIXME: this should be extern instead.
const Instruction = packed struct {
    const Data = usize;
    op: Operation,
    d0: Data = 0,
    d1: Data = 0,
    d2: Data = 0,
};

// A mapping from Instruction opcodes to operations.
const operations: std.EnumArray(Opcode, Operation) = blk: {
    var map = std.EnumArray(Opcode, Operation).initUndefined();
    var iter = map.iterator();
    while (iter.next()) |entry| {
        entry.value.* = @field(Machine, @tagName(entry.key));
    }
    break :blk map;
};
// const operations: std.EnumArray(Opcode, Operation) = undefined;

// Maximum size of input files, arbitrarily set to 1GB.
const max_input_size = 1024 * 1024 * 1024;

// Finite stack of registers.
var stack = [_]Register{0} ** 2048;

// Compiled program, initilized once after reading bytecode.
var program: []Instruction = undefined;

pub fn main() !void {
    if (std.os.argv.len != 2) {
        try usage();
        std.os.exit(1);
    } else {
        try start(std.mem.sliceTo(std.os.argv[1], 0));
    }
}

// Print commandline usage information.
pub fn usage() !void {
    const help =
        \\Usage: {s} filename
        \\
    ;
    try std.io.getStdOut().writer().print(help, .{std.os.argv[0]});
}

// Report fatal error and exit with code 1.
pub fn report(comptime format: []const u8, args: anytype) noreturn {
    std.io.getStdErr().writer().print(format, args) catch {
        // All hope's lost :c
    };
    std.os.exit(1);
}

// Start CM2.
pub fn start(filename: []u8) !void {
    const f = std.fs.cwd().openFile(filename, .{}) catch
        report("error: could not open file {s}", .{filename});
    defer f.close();

    var r = std.io.bufferedReader(f.reader());
    var input = r.reader().readAllAlloc(std.heap.page_allocator, max_input_size) catch
        report("error: could not read file {s} into memory", .{filename});

    var code = std.mem.bytesAsSlice([4]Register, input);
    for (code) |*c, i| {
        const op = std.meta.intToEnum(Opcode, c[0]) catch
            report("error: invalid opcode {} at instruction #{}", .{ c[0], i });
        c[0] = @ptrToInt(operations.get(op));
    }
    program = std.mem.bytesAsSlice(
        Instruction,
        @alignCast(@alignOf(Instruction), input),
    );

    @call(
        .{},
        program[0].op,
        .{ 0, 0 },
    );
}

// All operations of CM2.
const Machine = struct {
    // Load an immediate value into rX.
    // > li rX imm N/A
    pub fn li(pc: Register, sp: Register) void {
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
    pub fn cp(pc: Register, sp: Register) void {
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
    pub fn bge(pc: Register, sp: Register) void {
        const c = program[pc];
        // FIXME: this is a weird way of writing this.
        var o: Operation = undefined;
        var p: Register = undefined;
        if (stack[sp - c.d0] >= stack[sp - c.d1]) {
            o = program[c.d2].op;
            p = c.d2;
        } else {
            o = program[pc + 1].op;
            p = pc + 1;
        }
        @call(.{ .modifier = .always_tail }, o, .{ p, sp });
    }
    // Return from a function by collapsing its frame.
    // > ret N/A N/A N/A
    pub fn ret(pc: Register, sp: Register) void {
        // Thanks Zig :P
        _ = pc;
        _ = sp;
        return;
    }
    // Write into rX the value of (rY + rZ).
    // > add rX rY rZ
    pub fn add(pc: Register, sp: Register) void {
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
    pub fn sub(pc: Register, sp: Register) void {
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
    // Arguments are r1, r2, .. r(imm1), they're copied from the current frame to next frame.
    // The return value is r0, it's copied from the next frame to the current frame.
    // There is no need for a return address, execution will return here if and only if we reach a `ret`.
    pub fn call(pc: Register, sp: Register) void {
        const c = program[pc];
        const bp = sp + c.d1;
        std.mem.copy(
            Register,
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
    pub fn exit(pc: Register, sp: Register) void {
        const c = program[pc];
        std.process.exit(@intCast(u8, stack[sp - c.d0]));
    }
    // Print a register to stdout.
    // > put rX N/A N/A
    pub fn put(pc: Register, sp: Register) void {
        const c = program[pc];
        std.io.getStdOut().writer().print("{}\n", .{stack[sp - c.d0]}) catch {
            // TODO: handle this by throwing an exception catchable by the host language.
        };
        @call(
            .{ .modifier = .always_tail },
            program[pc + 1].op,
            .{ pc + 1, sp },
        );
    }
};
