# Dime LLIR

The compiler can emit two textual intermediate representations beside the
existing p-code image. For an input file named `program.pl0`, the current build
pipeline writes:

```text
program.hlir
program.llir
program.pcode
```

`HLIR` is the structured frontend IR built from the semantically checked AST.
`LLIR` is the lower, backend-facing IR dumped by `llir.pas`. It makes control
flow, loads/stores, procedure boundaries, calls, and intrinsics explicit while
staying target-neutral.

For the intended `v0.0.13` boundary, see [LIR-Contract.md](./LIR-Contract.md).
That page freezes what belongs in target-neutral LIR and what stays below the
backend boundary.

## Pipeline Position

The current compiler stages are:

```text
source
  -> AST
  -> semantic analysis
  -> HLIR
  -> LLIR
  -> p-code
```

In code, the relevant lowering units are:

- `asttohlir.pas`: lowers the analyzed AST into structured HLIR.
- `llircgen.pas`: lowers HLIR into LLIR.
- `llir.pas`: owns the in-memory LLIR program model and the `.llir` dump.

The important conceptual boundary is:

- `HLIR` still looks like the source language: routines, `if`, `while`, `for`,
  `switch`, `case`, typed expressions, and builtin calls are all structured.
- `LLIR` is no longer structured syntax. It is procedure-scoped, block-based,
  temporary-heavy, and explicit about storage and control flow.

## What LLIR Makes Explicit

Compared with HLIR, LLIR introduces these backend-oriented details:

- Procedure-scoped units instead of one flat stream.
- Basic blocks and label-to-block mappings.
- Explicit operand kinds: immediates, locals, parameters, temporaries, globals,
  labels, procedures, and intrinsics.
- Explicit `load` and `store` operations for memory-backed symbols.
- Explicit user routine calls with inline arguments and optional result binding.
- Explicit intrinsic calls for `read`, `readln`, `write`, and `writeln`.
- Explicit `return` instructions.

## File Shape

An `.llir` file is a textual dump of the current LLIR program. A simplified
example:

```text
llir program
globals 1
global 1 global[total]:integer/dword
procedures 2
proc 1 procparams return=none params=0 locals=0 temps=6 blocks=1 labels=1 instructions=18
  temp 1 temp[t1]:integer/dword
  block 1 label=L1 first=1 count=18
   1 copy result=temp[t1]:integer/dword left=imm(65):integer/dword
   2 call target=proc[store]:address arg1=temp[t1]:integer/dword
  labelmap L1 block=1 first=1
endproc
```

The first line identifies the dump as `llir program`, matching the current file
format and stage name.

Each procedure dump contains:

- An optional top-level `global` summary section for program storage.
- A procedure header with name, return type, and counts.
- Optional `param`, `local`, and `temp` summaries.
- `block` summaries with labels and aliases.
- The instruction lines that belong to each block.
- A `labelmap` section mapping symbolic labels to blocks/instruction indexes.

## Procedures and Temporaries

LLIR is procedure-based. Each procedure carries:

- `name`
- `return` type or `none`
- parameter list
- local list
- temporary list
- basic blocks
- instructions

Program-wide global storage is listed once at the top of the dump rather than
being repeated as fake locals on the entry procedure.

Example:

```text
proc 2 store return=none params=3 locals=0 temps=3 blocks=1 labels=1 instructions=9
  param 1 param[value]:integer/dword
  param 2 param[flag]:boolean/byte
  param 3 param[ch]:char/byte
  temp 1 temp[t7]:integer/dword
```

## Basic Blocks

LLIR is no longer just a flat instruction stream. Instructions are grouped into
basic blocks.

A block begins at:

- procedure entry
- a label target
- the instruction after a block-terminating branch/jump/return

A block ends at:

- `jump`
- `brtrue`
- `brfalse`
- `return`

The dump records both a primary block label and any aliases that were folded
into the same block:

```text
block 5 label=L10 alias=L8 first=16 count=5
...
labelmap L8 block=5 first=16
labelmap L10 block=5 first=16
```

This is useful for:

- assembler label emission
- CFG construction
- jump validation
- dead code analysis
- later optimization passes

## Operands

Operands are strongly classified and typed. The textual forms currently emitted
are:

| Form | Meaning |
| --- | --- |
| `imm(12):integer/dword` | immediate integer constant |
| `imm(1):boolean/byte` | immediate boolean value |
| `imm(65):char/byte` | immediate char value as code point |
| `local[x]:integer/dword` | procedure-local storage |
| `param[value]:integer/dword` | procedure parameter storage |
| `global[n]:integer/dword` | top-level storage seen from a procedure |
| `temp[t4]:boolean/byte` | temporary value |
| `label[L3]:address` | control-flow label |
| `proc[store]:address` | user procedure/function target |
| `intrinsic[write_int]:address` | compiler-known intrinsic target |

Each operand carries:

- kind
- source-level type
- size class (`byte`, `word`, `dword`, `qword`, `address`)
- optional symbol or intrinsic identity

## Instruction Set

The current normalized LLIR instruction families are:

### Data movement

- `copy`
- `load`
- `store`
- `load_addr`
- `store_addr`

### Arithmetic and comparison

- `add`
- `sub`
- `mul`
- `div`
- `mod`
- `neg`
- `cmp_eq`
- `cmp_ne`
- `cmp_lt`
- `cmp_le`
- `cmp_gt`
- `cmp_ge`

### Control flow

- `jump`
- `brtrue`
- `brfalse`
- `return`

### Calls and procedure shape

- `call`
- `return`

### Addressing

- `addr_local`
- `addr_param`
- `addr_global`
- `field_addr`
- `index_addr`

### Intrinsics

- `intrinsic_call`

Not every instruction is emitted by every source program yet, but the LLIR data
model and validator already reserve space for the full lowered set above.

## Lowering from HLIR

`llircgen.pas` lowers structured HLIR into LLIR by making implicit behavior
explicit.

### Expressions

HLIR expressions are recursively lowered into temporaries.

Example:

```text
HLIR: x + 1
```

becomes:

```text
load result=temp[t1]:integer/dword left=local[x]:integer/dword
copy result=temp[t2]:integer/dword left=imm(1):integer/dword
add result=temp[t3]:integer/dword left=temp[t1]:integer/dword right=temp[t2]:integer/dword
```

### Assignments

Assignments separate computed values from storage:

```text
store result=local[x]:integer/dword left=temp[t3]:integer/dword
```

### Structured control flow

HLIR `if`, `while`, `repeat`, `for`, `switch`, and `case` are lowered into
basic blocks, labels, and branches.

Example `if` shape:

```text
... condition into temp[t1] ...
brfalse left=temp[t1]:boolean/byte target=label[Lelse]:address
... then block ...
jump target=label[Lend]:address
block ... label=Lelse
... else block ...
block ... label=Lend
```

### Procedure entry and exit

Each lowered procedure gets:

- an entry block
- body instructions
- `return`

### Builtins become intrinsics

HLIR still knows about source builtins such as `write`, `writeln`, `read`, and
`readln`. LLIR lowers them to compiler-known intrinsics:

- `write(integer|boolean)` -> `intrinsic[write_int]`
- `write(char)` -> `intrinsic[write_char]`
- `writeln` -> `intrinsic[writeln]`
- `read(integer|boolean)` -> `intrinsic[read_int]`
- `read(char)` -> `intrinsic[read_char]`
- `readln` -> `intrinsic[readln]`

Example:

```text
load result=temp[t4]:integer/dword left=global[total]:integer/dword
intrinsic_call target=intrinsic[write_int]:address arg1=temp[t4]:integer/dword
intrinsic_call target=intrinsic[writeln]:address
```

## Call Shape in LLIR

User routine calls carry their argument operands directly on the `call`
instruction:

```text
copy result=temp[t1]:integer/dword left=imm(65):integer/dword
copy result=temp[t2]:boolean/byte left=imm(1):boolean/byte
copy result=temp[t3]:char/byte left=imm(65):char/byte
call target=proc[store]:address arg1=temp[t1]:integer/dword arg2=temp[t2]:boolean/byte arg3=temp[t3]:char/byte
```

If a call returns a value, the destination temporary is attached directly to the
same instruction:

```text
call result=temp[t4]:integer/dword target=proc[compute]:address arg1=temp[t1]:integer/dword
```

Intrinsic calls use the same basic shape:

- user routines use `call`
- intrinsics use `intrinsic_call`
- both carry `argN=...` operands inline
- both may carry `result=...` when they produce a value

## Interpreter

`llirint` is the standalone interpreter for the textual LLIR dump:

```text
llirint program.llir [quiet|all]
```

It reconstructs a runtime image from the dump:

- procedures
- procedure parameters
- instruction arrays
- label-to-instruction maps
- temporary storage
- symbolic variables/memory cells
- a small return-address stack

It begins execution at the first emitted procedure, which is the lowered entry
routine for the source program.

## Current Runtime Model

The interpreter is intentionally small and still more symbolic than a real
backend:

- It executes the textual `.llir` dump, not a binary IR image.
- Variables are still interpreted symbolically.
- Temporary slots exist as indexed runtime cells.
- Calls use a return stack rather than a full machine model.
- Intrinsics are executed through an interpreter-specific testing adapter rather
  than lowered to syscalls yet.

This is still useful because it gives the compiler a checkable backend-facing
IR before assembler generation lands, while keeping the intrinsic names
themselves target-neutral. The native backend in later milestones can consume
the same `intrinsic_call` operations and lower them differently.

## Current Limits

LLIR is already lower than HLIR, but it is not yet final target code.

Current limits worth keeping in mind:

- The textual dump still uses some legacy `tac*` names internally.
- The file header still says `llir program`.
- `write_string` exists in the intrinsic model but is not implemented by the
  interpreter yet.
- Addressing instructions are modeled in LLIR but not heavily exercised by the
  current scalar-only language subset.
- There is no register allocation yet.

That is the intended tradeoff for this stage: LLIR should be explicit,
verifiable, and boring enough to support the upcoming assembler backend.

