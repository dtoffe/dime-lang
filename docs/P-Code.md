# PL/0 P-Code

This compiler emits a small stack-machine instruction set, usually called
p-code. The interpreter loads the generated `.pcode` file into an instruction
array and executes it with three registers:

- `programCounter`: index of the next instruction.
- `basePointer`: base address of the current activation record.
- `stackTop`: top occupied slot in the runtime stack.

Each instruction has this shape:

```text
OPCODE lexicalLevel argument
```

`lexicalLevel` is used by variable access and procedure calls. It says how many
static scopes outward the machine must walk from the current frame. `argument`
is either a literal value, stack address, jump target, procedure entry point,
or operation number, depending on the opcode.

## Stack Frames

The stack is one-based. Every block reserves three slots for frame linkage, so
local variables start at address `3`.

```text
base + 0  static link: base of the enclosing lexical scope
base + 1  dynamic link: caller's base pointer
base + 2  return address: caller's program counter
base + 3  first local variable
base + 4  second local variable
...
```

The main program starts with `basePointer = 1`, `programCounter = 0`, and
`stackTop = 0`. Its first `INT` instruction reserves the linkage slots and any
variables in the main block.

To access a non-local variable, the interpreter follows the static link
`lexicalLevel` times. For example, `LOD 1,4` loads address `4` from the
immediately enclosing block.

## Opcodes

### `LIT 0, value`

Pushes a literal integer.

```text
stackTop := stackTop + 1
stack[stackTop] := value
```

### `OPR 0, operation`

Performs arithmetic, comparison, or return. Arithmetic and comparison operators
consume operands from the top of the stack and leave their result on the stack.
Boolean results are stored as `0` for false and `1` for true.

| Operation | Meaning | Stack effect |
| --- | --- | --- |
| `0` | return from procedure/block | restores `programCounter` and `basePointer` |
| `1` | unary minus | `x -> -x` |
| `2` | addition | `x y -> x + y` |
| `3` | subtraction | `x y -> x - y` |
| `4` | multiplication | `x y -> x * y` |
| `5` | integer division | `x y -> x div y` |
| `8` | equals | `x y -> ord(x = y)` |
| `9` | not equals | `x y -> ord(x <> y)` |
| `10` | less than | `x y -> ord(x < y)` |
| `11` | greater/equal | `x y -> ord(x >= y)` |
| `12` | greater than | `x y -> ord(x > y)` |
| `13` | less/equal | `x y -> ord(x <= y)` |

### `LOD lexicalLevel, address`

Loads a variable onto the stack.

```text
stackTop := stackTop + 1
stack[stackTop] := stack[findBase(lexicalLevel) + address]
```

Constants do not use `LOD`; the compiler emits `LIT` with the constant value.

### `STO lexicalLevel, address`

Stores the top stack value into a variable and then pops it.

```text
stack[findBase(lexicalLevel) + address] := stack[stackTop]
stackTop := stackTop - 1
```

This interpreter also prints the stored value as a side effect.

### `CAL lexicalLevel, address`

Calls a procedure whose first instruction is at `address`. The machine writes a
new activation record above the current stack top:

```text
stack[stackTop + 1] := findBase(lexicalLevel)  // static link
stack[stackTop + 2] := basePointer             // dynamic link
stack[stackTop + 3] := programCounter          // return address
basePointer := stackTop + 1
programCounter := address
```

The called block's `INT` instruction then moves `stackTop` past the frame header
and local variables.

### `INT 0, size`

Allocates stack space for the current block.

```text
stackTop := stackTop + size
```

`size` is `3 + numberOfVariablesInBlock`.

### `JMP 0, address`

Unconditionally jumps to `address`.

```text
programCounter := address
```

### `JPC 0, address`

Pops the top stack value. If it is `0`, jumps to `address`; otherwise execution
continues at the next instruction.

```text
if stack[stackTop] = 0 then
    programCounter := address
stackTop := stackTop - 1
```

## Generated Code Patterns

### Block

Only the global block starts with a placeholder jump over its top-level
procedure bodies. Procedure blocks no longer need this jump because nested
procedure declarations are not part of the language. After global declarations
are parsed, the compiler patches that jump to the main block body.

```text
JMP 0, body
... top-level procedure code ...
body:
INT 0, frameSize
... statement code ...
OPR 0, 0
```

For a procedure block, code generation begins directly at:

```text
INT 0, frameSize
... statement code ...
OPR 0, 0
```

`OPR 0,0` returns to the caller. For the main block, returning sets
`programCounter` to `0`, ending interpretation.

### Constants

Constants are compile-time symbol table entries. Referencing a constant emits:

```text
LIT 0, constantValue
```

No stack-frame slot is allocated.

### Variables

Variables are assigned consecutive addresses starting at `3` in their declaring
block. Referencing a variable emits:

```text
LOD levelDifference, address
```

Assigning a variable compiles the right-hand expression first, then stores it:

```text
... expression leaves value on stack ...
STO levelDifference, address
```

`levelDifference` is `currentLevel - declarationLevel`.

### Procedures

A procedure declaration records the current code index as the procedure entry
address. Calling it emits:

```text
CAL levelDifference, procedureAddress
```

The static link created by `CAL` lets the procedure access variables from its
lexically enclosing blocks.

### Expressions

Expressions are evaluated left to right on the stack.

```pl0
x + 3 * y
```

Typical code shape:

```text
LOD l,xAddress
LIT 0,3
LOD l,yAddress
OPR 0,4    // multiply 3 * y
OPR 0,2    // add x
```

Unary minus compiles the term and then emits `OPR 0,1`.

### Boolean Conditions

`if` and `while` now compile an ordinary expression in condition position.
Semantic analysis is responsible for ensuring that the expression resolves to a
boolean value.

Relational expressions compile both operands and then emit the matching
comparison operation:

```text
left = right   -> OPR 0,8
left <> right  -> OPR 0,9
left < right   -> OPR 0,10
left >= right  -> OPR 0,11
left > right   -> OPR 0,12
left <= right  -> OPR 0,13
```

The boolean result remains on the stack for `if` and `while`.

### Assignment

```pl0
x := expression
```

Compiles to:

```text
... expression ...
STO levelDifference, xAddress
```

### `call`

```pl0
call p
```

Compiles to:

```text
CAL levelDifference, pAddress
```

### `begin ... end`

Statements are compiled in order. Semicolons do not emit p-code; they only
separate source statements.

### `if`

```pl0
if expression then statement
```

Compiles to:

```text
... expression leaves 0 or 1 on stack ...
JPC 0, afterThen
... statement ...
afterThen:
```

`JPC` consumes the boolean expression value.

### `while`

```pl0
while expression do statement
```

Compiles to:

```text
loopStart:
... expression leaves 0 or 1 on stack ...
JPC 0, afterLoop
... statement ...
JMP 0, loopStart
afterLoop:
```

The boolean expression is re-evaluated before each iteration.
