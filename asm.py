#!/usr/bin/env python3

"""
This is quick assembler for CM2.
It reads in an ASCII encoded `example.asm` file and outputs a binary `example.cm2` file.
"""

import sys
from typing import Iterable, NamedTuple,  Mapping

# Representation of a signle CM2 bytecode instruction.
Instruction = NamedTuple('Instruction', op=int, d0=int, d1=int, d2=int)


class Location:
    """
    Current location in assemble source code.
    """
    line: int

    def __init__(self):
        self.line = 1

    def reset(self):
        """
        Reset location to the start of the file.
        """
        self.line = 1


# Map from opcode names to their 64-bit values.
OPCODE_NUMBER = {
    'li': 0x0,
    'cp': 0x1,
    'bge': 0x2,
    'add': 0x3,
    'sub': 0x4,
    'call': 0x5,
    'ret': 0x6,
    'put': 0x7,
    'exit': 0x8,
}


def usage():
    """
    Print commandline usage information.
    """
    print(f"""
    Usage: {sys.argv[0]} file.asm
    """)
    sys.exit(1)


def wrong_number_of_operands_error(op: str, loc: int, expected: int, found: int):
    """
    An instruction doesn't have enough operands.
    """
    print(
        f'error at line {loc}: instruction {op} expects {expected} arguments, found {found}')
    sys.exit(1)


def malformed_instruction_error(chunks: str, loc: Location):
    """
    An instruction cannot be parsed into opcode/operand elements.
    """
    print(
        f'error at line {loc.line}: CM2 instructions should have an opcode \
        and 0 to 3 operands, but found {len(chunks)}')
    sys.exit(1)


def unknown_opcode(op: str, loc: Location):
    """
    Bad syntax for a label.
    """
    print(
        f'error at line {loc.line}: unknown opcode {op}')
    sys.exit(1)


def parse_instruction(line: str, loc: Location, labels: Mapping[str, int]) -> Instruction:
    """
    Parse any Instruction from an ascii-encoded line in source code.
    """
    chunks = line.split(' ')
    if not len(chunks) in range(5):
        malformed_instruction_error(chunks, loc)
    op = chunks[0]
    ds = list(map(
        lambda s: s.lstrip('r').lstrip('@'),
        chunks[1:])
    )
    match op:
        # op - - -
        case 'ret':
            if len(ds) != 0:
                wrong_number_of_operands_error(op, loc, 0, len(ds))
            return Instruction(OPCODE_NUMBER[op], 0, 0, 0)
        # op X - -
        case 'put' | 'exit':
            if len(ds) != 1:
                wrong_number_of_operands_error(op, loc, 1, len(ds))
            return Instruction(OPCODE_NUMBER[op], int(ds[0]), 0, 0)
        # op X Y -
        case 'li' | 'cp':
            if len(ds) != 2:
                wrong_number_of_operands_error(op, loc, 2, len(ds))
            return Instruction(OPCODE_NUMBER[op], int(ds[0]), int(ds[1]), 0)
        # op X Y @Z
        case 'bge' | 'call':
            if len(ds) != 3:
                wrong_number_of_operands_error(op, loc, 3, len(ds))
            return Instruction(OPCODE_NUMBER[op], int(ds[0]), int(ds[1]), labels[ds[2]])
        # op X Y Z
        case 'add' | 'sub':
            if len(ds) != 3:
                wrong_number_of_operands_error(op, loc, 3, len(ds))
            return Instruction(OPCODE_NUMBER[op], int(ds[0]), int(ds[1]), int(ds[2]))
        case _:
            unknown_opcode(op, loc)


def serialize_instruction(instruction: Instruction) -> Iterable[bytes]:
    """
    Serialize an instruction into a bytearray, more precisely an array of 4 64-bit integers.
    """
    return map(lambda x: int.to_bytes(x, length=8, byteorder='little'), [*instruction])


def read_file(filename: str) -> Iterable[Instruction]:
    """
    Parse an assembly file into a sequence of instructions.
    """
    with open(filename, mode='rt', encoding='ascii') as f:
        instructions = []
        loc = Location()
        labels = {}

        for line in f:
            match line[0]:
                case '#':
                    continue
                case '@':
                    label = line.strip()[1:]
                    labels[label] = loc.line - 1
                case _:
                    loc.line += 1

        loc.reset()
        f.seek(0)

        for line in f:
            match line[0]:
                # # Comment
                # @label
                case '#' | '@':
                    continue
                # op - - -
                case _:
                    line = line.split('#')[0].strip()
                    instructions.append(parse_instruction(line, loc, labels))
                    loc.line += 1

        return instructions


def write_binary(filename: str, instructions: Iterable[Instruction]) -> None:
    """
    Serialize a sequence of instructions into a binary file.
    """
    with open(filename, mode='wb') as f:
        for instruction in instructions:
            for b in serialize_instruction(instruction):
                f.write(b)


def main():
    """
    Entry point.
    """
    if len(sys.argv) != 2:
        usage()

    instructions = read_file(sys.argv[1])
    ouput = sys.argv[1].rstrip('.asm') + '.cm2'
    write_binary(ouput, instructions)


if __name__ == "__main__":
    main()
