# Dime TAC IR

The compiler can emit a textual three-address-code intermediate representation
beside the p-code image. For an input file named `program.pl0`, the builder
writes:

```text
program.pcode
program.tac
```

The `.tac` file is produced after parsing and semantic analysis. It is lower
level than the AST but still higher level than p-code: variables are symbolic,
temporaries are explicit, labels are symbolic, and no stack slots or registers
have been assigned.

## Shape

A TAC dump has three sections:

```text
tac program
procedures 2
  proc 1 main blocks=3 instructions=12 temps=5 labels=3
blocks 3
  block 1 label=L1 first=1 count=4
instructions 12
   1 label label=L1
   2 load_const result=t1:integer left=#1:integer
   3 store_var result=n:integer left=t1:integer
```

The procedure and block sections are summaries. The interpreter mainly uses the
procedure summaries and instruction stream:

- Procedure summaries tell `tacirint` each procedure name and instruction count.
- Label instructions map symbolic labels such as `L3` to instruction indexes.
- Instruction lines contain the executable TAC.

## Operands

TAC operands are value operands. They use this textual form:

```text
atom:type
```

The current operand atoms are:

| Form | Meaning |
| --- | --- |
| `#12:integer` | constant literal |
| `#70:char` | char literal, stored as an ASCII code |
| `n:integer` | symbolic variable reference |
| `t4:boolean` | temporary value |

Boolean values use `0` for false and `1` for true. `char` values use integer
ASCII code points, the same representation used by the p-code interpreter.

## Instructions

Each instruction starts with a one-based instruction index and an instruction
kind. The remaining fields are named operands or metadata:

```text
17 binary result=t9:boolean left=t7:integer right=t8:integer op=<=
18 goto_if_zero left=t9:boolean label=L3
```

The deliberately small instruction set is:

| Instruction | Meaning |
| --- | --- |
| `load_const` | copy a constant literal into a temporary |
| `copy` | copy one operand into another |
| `unary` | evaluate a unary operator into a temporary |
| `binary` | evaluate a binary operator into a temporary |
| `goto` | jump to a label |
| `goto_if_zero` | jump to a label when the condition operand is `0` |
| `label` | mark a jump target |
| `load_var` | load a symbolic variable into a temporary |
| `store_var` | store an operand into a symbolic variable |
| `call_proc` | call a named procedure |
| `builtin_read` | read a value into a symbolic variable |
| `builtin_write` | write an operand value |
| `return` | return from the current procedure, or finish the program |

Supported unary operators are `-` and `not`.

Supported binary operators are `+`, `-`, `*`, `/`, `=`, `<>`, `<`, `<=`, `>`,
`>=`, `and`, `or`, and `xor`.

## Lowering Patterns

Expressions are recursively lowered into temporaries. For example:

```text
n + 1
```

becomes:

```text
load_var result=t1:integer left=n:integer
load_const result=t2:integer left=#1:integer
binary result=t3:integer left=t1:integer right=t2:integer op=+
```

An assignment stores the final expression operand into the symbolic target:

```text
store_var result=n:integer left=t3:integer
```

An `if` statement lowers to a conditional jump over the then-body, plus an
optional jump over the else-body:

```text
... condition into t1 ...
goto_if_zero left=t1:boolean label=Lelse
... then body ...
goto label=Lend
label label=Lelse
... else body ...
label label=Lend
```

A `while` statement lowers to a loop label, condition, exit jump, body, and
back edge:

```text
label label=Lstart
... condition into t1 ...
goto_if_zero left=t1:boolean label=Lexit
... body ...
goto label=Lstart
label label=Lexit
```

## `tacirint`

`tacirint` is a standalone interpreter for the dumped textual TAC format:

```text
tacirint program.tac [quiet|all]
```

It reconstructs a flat runtime image from the dump:

- `instructions`: the parsed instruction stream.
- `procedures`: procedure names, starting instruction indexes, and instruction counts.
- `labelTargets`: a table from label IDs to instruction indexes.
- `temporaries`: integer slots indexed by temporary ID.
- `variables`: symbolic variable names and integer values.
- `returnStack`: return instruction indexes for procedure calls.

At startup, the interpreter loads the `.tac` file, builds the label table from
`label` instructions, derives procedure start addresses from the procedure
instruction counts, and begins execution at the first procedure.

## Execution Model

There is no operand stack. Each instruction reads named operands and writes a
named result operand.

`load_const` writes the constant value into its result temporary:

```text
temporaries[resultTemporary] := constantValue
```

`load_var` reads the symbolic variable store:

```text
temporaries[resultTemporary] := variables[name]
```

`store_var` writes the symbolic variable store:

```text
variables[name] := operandValue
```

`binary` reads both operands, applies the operator, and writes the result:

```text
temporaries[resultTemporary] := applyBinaryOperator(left, right)
```

`goto` replaces the program counter with the target label's instruction index.
`goto_if_zero` does the same only when its condition operand is `0`; otherwise
execution continues at the next instruction.

`call_proc` looks up the procedure by name, pushes the next instruction index
onto `returnStack`, and jumps to the callee's first instruction. `return` pops
that stack. If the stack is empty, the program is finished.

## Built-ins

`builtin_write` follows the same output behavior as the p-code interpreter:

- `write` prints without a trailing newline.
- `writeln` prints with a trailing newline.
- `char` operands are printed with `chr(value)`.
- `integer` and `boolean` operands are printed as decimal values.

`builtin_read` reads into a symbolic variable:

- `read` consumes one token.
- `readln` consumes one token and then discards the rest of the input line.
- `integer` uses decimal parsing.
- `char` requires a one-character token.
- `boolean` accepts `0` or `1`.

## Current Limits

The current interpreter is intentionally small and mirrors the staged compiler:

- It executes the textual `.tac` dump, not an in-memory binary IR image.
- Variables are one global symbolic store; no stack layout exists yet.
- Procedure calls use a return-address stack but no activation records.
- The format assumes whitespace-free identifiers and operand fields.
- The default fixed capacities match the current TAC staging constants.

These limits are useful for now: the TAC path can be compared against p-code
execution while the compiler grows toward later IR-to-p-code or native backends.
