# Dime HLIR

`HLIR` is the structured high-level intermediate representation used between
semantic analysis and backend-oriented lowering.

For an input file named `program.pl0`, the current compiler emits:

```text
program.hlir
program.llir
program.pcode
```

`program.hlir` is produced after parsing and semantic analysis. It is the first
IR that is meant to be a stable compiler-internal representation rather than a
syntax tree.

## Pipeline Position

The current pipeline is:

```text
source
  -> AST
  -> semantic analysis
  -> HLIR
  -> LLIR
  -> p-code
```

Relevant units:

- `astree.pas`: raw parsed tree shape
- `semantics.pas`: type checking and symbol binding
- `asttohlir.pas`: AST-to-HLIR lowering
- `hlir.pas`: HLIR data model and dump support
- `llircgen.pas`: HLIR-to-LLIR lowering

The intended split is:

- `AST` is still syntax-shaped.
- `HLIR` is language-shaped.
- `LLIR` is backend-shaped.

## Why HLIR Exists

HLIR keeps frontend meaning explicit without committing to backend storage or
control-flow details too early.

It preserves:

- routines as routines
- statements as statements
- expressions as expressions
- builtin calls as builtin calls
- typed symbol references

It deliberately avoids:

- stack slots
- frame offsets
- explicit loads/stores for every symbol use
- basic blocks and CFG edges
- target calling convention details

That separation keeps the frontend from caring where `x` will eventually live
in memory.

## HLIR Shape

At the top level, HLIR models a program as:

```text
hirProgramRecord
  globals
  entryRoutine
  routines
```

The entry routine is the lowered program body. User-declared procedures and
functions live in the `routines` list.

### Routines

Each routine carries:

- routine kind: `program`, `procedure`, or `function`
- source position
- name
- bound symbol
- return type
- parameter declarations
- local declarations
- structured body

### Declarations

HLIR currently models three declaration kinds:

- `hirDeclConstant`
- `hirDeclVariable`
- `hirDeclParameter`

Each declaration stores:

- an internal HLIR id
- source context
- bound symbol info
- constant value when applicable

### Statements

Current statement kinds:

- `hirStmtCompound`
- `hirStmtAssignment`
- `hirStmtCall`
- `hirStmtReturn`
- `hirStmtBreak`
- `hirStmtContinue`
- `hirStmtIf`
- `hirStmtWhile`
- `hirStmtRepeat`
- `hirStmtFor`
- `hirStmtSwitch`

Statements remain fully structured. There are no labels or jumps in HLIR.

### Expressions

Current expression kinds:

- integer literal
- boolean literal
- char literal
- symbol reference
- unary expression
- binary expression
- call expression
- case expression

Expressions are typed and still close to the source language.

### Calls

Call sites are shared by call-statements and call-expressions. A call site
stores:

- whether the target is a user routine or builtin
- the bound target symbol
- argument list
- argument count

This is important because HLIR still distinguishes:

- `call target=isprime ...`
- `call builtin target=writeln ...`

That builtin identity is intentionally preserved until LLIR lowering.

## Symbols and Types

HLIR is not just names. It carries semantic bindings.

Each `hirSymbolRef` stores:

- symbol table index
- identifier text
- declaration kind
- builtin kind when applicable
- typed `hirTypeRef`

Each `hirTypeRef` currently covers the scalar types already supported by the
language:

- `integer`
- `boolean`
- `char`

There is also room for later user-defined type identity without dragging
backend concerns into the frontend IR.

## Dump Format

The `.hlir` dump is a readable tree-shaped rendering of the structured IR.

Example:

```text
hlir program primes symbol=0 globals=3 routines=2 entry=TRUE
globals
  decl 1 const max#5:integer value=100
  decl 2 var arg#6:integer
entry
  routine 1 program primes symbol=0 return=integer params=0 locals=0
    body
      stmt 1 compound
        stmt 3 call
          call target=printprime#10:integer argc=0
```

The dump is organized by:

- globals
- entry routine
- declared routines

Inside each routine, the dump shows:

- parameters
- locals
- structured statements
- typed expressions

## Lowering from AST to HLIR

`asttohlir.pas` performs the lowering from the analyzed AST into HLIR.

The overall rule is simple:

- keep source structure
- attach semantic bindings
- discard parser-only syntax scaffolding

### Program lowering

`lowerAstToHirProgram`:

- initializes a fresh HLIR program record
- copies the program name and bound symbol
- collects global constants and variables
- creates a synthetic entry routine for the program body
- lowers user-declared procedures and functions into separate routines

### Declarations

AST declarations become HLIR declarations:

- `astConstDeclaration` -> `hirDeclConstant`
- `astVarDeclaration` -> `hirDeclVariable`
- routine parameter declarations -> `hirDeclParameter`

Constants keep their literal value in the declaration record. Variables and
parameters keep their bound symbol and type.

### Routine lowering

A procedure/function AST node becomes a `hirRoutineRecord`.

The lowering pass:

- chooses `hirRoutineProcedure` or `hirRoutineFunction`
- copies the resolved routine symbol
- records the return type
- collects parameter declarations from the routine header
- collects local declarations from the routine block
- lowers the routine body as a structured statement tree

The program body is treated similarly, but wrapped as a `hirRoutineProgram`
entry routine.

### Statement lowering

AST statements map almost one-to-one into HLIR statements:

- assignment -> assignment
- procedure call -> call statement
- return -> return statement
- `if` -> structured `if`
- `while` -> structured `while`
- `repeat` -> structured `repeat`
- `for` -> structured `for`
- `switch` -> structured `switch`
- `break` / `continue` stay explicit

Compound statements become `hirStmtCompound` nodes containing ordered child
statements.

### Expression lowering

AST expressions are converted into typed HLIR expressions:

- identifiers -> symbol expressions
- literals -> literal expressions
- unary operators -> `hirExprUnary`
- binary operators -> `hirExprBinary`
- function calls -> `hirExprCall`
- case expressions -> `hirExprCase`

Operator tokens are translated into HLIR enums such as:

- `plus` -> `hirBinaryAdd`
- `eql` -> `hirBinaryEq`
- `notsym` -> `hirUnaryNot`

This removes direct parser token dependence from later passes.

### What AST details disappear here

AST-specific concerns that do not survive into HLIR include:

- parser node kinds that only exist to encode syntax
- punctuation and grouping artifacts
- routine block scanning logic after declarations are collected
- token-level operator encoding

The result is still structured, but cleaner and more semantic than the AST.

## Why HLIR Is Still High-Level

HLIR does not lower variable access into loads and stores yet.

For example, a source assignment like:

```text
x := y + 1
```

still looks conceptually like:

```text
assign
  target symbol x
  value binary(add)
    symbol y
    int literal 1
```

There are:

- no temporaries
- no explicit `load`
- no explicit `store`
- no explicit `jump`
- no frame references

That is exactly the point of HLIR.

## Lowering from HLIR to LLIR

`llircgen.pas` lowers HLIR into LLIR by making storage and control flow
explicit.

### Routine lowering

Each HLIR routine becomes one LLIR procedure with:

- a procedure header
- parameter/local metadata
- temporary allocation
- frame information
- an entry basic block
- `enter` / `leave` / `return`

### Expression lowering

HLIR expressions are recursively lowered into LLIR temporaries.

Example:

```text
HLIR:
  binary(add)
    symbol y
    int literal 1
```

becomes LLIR shaped like:

```text
load result=temp[t1] left=local[y]
copy result=temp[t2] left=imm(1)
add result=temp[t3] left=temp[t1] right=temp[t2]
```

### Assignment lowering

HLIR assignment targets are symbol-backed lvalues. LLIR turns them into explicit
stores:

```text
store result=local[x] left=temp[t3]
```

### Control-flow lowering

Structured HLIR control flow is lowered into labels, blocks, and branches:

- `if` -> conditional branch plus optional join block
- `while` -> loop header, exit branch, back edge
- `repeat` -> body-first loop with explicit test
- `for` -> explicit initialization, comparison, increment, and back edge
- `switch` / `case` -> explicit comparisons, labels, and merges

This is where LLIR stops being statement-shaped and becomes block-shaped.

### Builtin lowering

HLIR still knows about language builtins like `write`, `writeln`, `read`, and
`readln`.

LLIR lowers them into intrinsic operations:

- `write(integer|boolean)` -> `intrinsic_call write_int`
- `write(char)` -> `intrinsic_call write_char`
- `writeln` -> `intrinsic_call writeln`
- `read(integer|boolean)` -> `intrinsic_call read_int`
- `read(char)` -> `intrinsic_call read_char`
- `readln` -> `intrinsic_call readln`

### Call lowering

User routine calls become explicit LLIR call setup:

```text
arg ...
arg ...
call target=proc[foo]
result ...
```

Intrinsic calls currently carry their arguments directly on the
`intrinsic_call` instruction.

### Frame-aware lowering

HLIR does not know stack layout. LLIR does.

During HLIR-to-LLIR lowering and LLIR construction, the compiler records:

- parameters
- locals
- temporaries
- frame slot sizes
- frame offsets
- total frame size

That makes LLIR suitable for later assembler emission without forcing those
concerns into the frontend.

## Design Boundary

The most important current boundary is:

- `asttohlir.pas` should preserve language meaning.
- `llircgen.pas` should preserve meaning while making backend mechanics
  explicit.

In other words:

- AST-to-HLIR is a frontend cleanup and semantic-shaping pass.
- HLIR-to-LLIR is a backend-preparation lowering pass.

## Current Limits

Current HLIR limitations are intentional:

- Type modeling is still scalar-only in practice.
- Lvalues are still direct symbol targets, not general access paths.
- There is no explicit CFG in HLIR.
- There are no memory ownership/free helpers for HLIR nodes yet.
- Builtin identity remains at the HLIR level until LLIR lowering.

Those tradeoffs keep HLIR simple while the language and backend continue to
grow.
