# Dime LIR Contract

This document defines the lowered IR contract for milestone
`v0.0.13 - Backend Lowering Contract`.

It describes the target-neutral LIR surface that frontend lowering may produce
and backend-specific lowering may consume. It is intentionally narrower than
the implementation notes in `LLIR.md`: this page states the contract, not
every detail present in the dump.

## Purpose

The lowered IR boundary exists to make backend preparation explicit without
forcing frontend stages to care about:

- machine frame layout
- concrete ABI rules
- OS/syscall details
- register allocation
- final stack-slot assignment policy

At this boundary:

- HLIR is still structured and language-shaped.
- LIR is block-shaped and explicit about values, storage, and control flow.
- Native backend details begin only below LIR.

## Contract Summary

LIR is allowed to make these things explicit:

- procedures as separate units
- basic blocks and labels
- typed operands
- explicit loads and stores
- explicit temporaries
- explicit control-flow branches and joins
- explicit user-call setup
- explicit target-neutral intrinsic calls
- explicit address-forming operations needed by later lowering

LIR must not require these things to be decided yet:

- physical registers
- machine stack frame offsets
- concrete calling convention register/stack assignment
- callee/caller-save policy
- object file or executable format
- concrete OS entrypoints, syscalls, or libc binding details

## Allowed Procedure Model

Each LIR procedure may contain:

- procedure identity
- return type or `none`
- parameter list
- local symbol list
- temporary list
- basic blocks
- instructions

It may describe logical parameters, locals, and temporaries, but their final
machine storage belongs below this boundary.

## Allowed Operand Kinds

The allowed operand surface above backend-specific lowering is:

- `imm`
- `local`
- `param`
- `global`
- `temp`
- `label`
- `proc`
- `intrinsic`

Operand meaning at this boundary:

- `imm` is a typed literal value.
- `local`, `param`, and `global` name logical storage classes, not machine
  addresses or frame offsets.
- `temp` is a compiler-created SSA-like scratch value identifier, not a fixed
  stack slot or register.
- `label` names a control-flow destination.
- `proc` names a user routine target.
- `intrinsic` names a target-neutral runtime operation known to the compiler.

## Allowed Instruction Surface

The intended LIR instruction set above backend-specific lowering is:

### Data movement

- `copy`
- `load`
- `store`

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

### Calls

- `call`
- `intrinsic_call`

### Address formation

- `addr_local`
- `addr_param`
- `addr_global`
- `field_addr`
- `index_addr`
- `load_addr`
- `store_addr`

## What Stays Below LIR

The following concerns are explicitly below the LIR boundary:

- frame size computation
- positive/negative frame-pointer offset conventions
- temporary stack-slot policy
- parameter home locations
- register assignment
- stack alignment rules
- target calling convention details
- syscall lowering
- runtime ABI glue

If one backend uses frame-pointer offsets and another uses register homes first,
both should still be able to consume the same LIR program.

## Intrinsic Boundary

LIR may contain compiler-known intrinsics when the source language refers to
target-neutral operations such as `read`, `readln`, `write`, and `writeln`.

That is still within the contract as long as:

- the intrinsic name is target-neutral
- operand and result typing are explicit
- no OS binding detail leaks into the LIR instruction

Turning an intrinsic into a syscall sequence, runtime helper call, or foreign
ABI call belongs below LIR.

## Inspectability Requirement

HIR-to-LIR lowering should stay inspectable with a stable textual dump.

The dump should make it possible to see:

- procedure boundaries
- block boundaries
- labels and branches
- temporaries
- load/store points
- call setup
- intrinsic use

The dump does not need to expose final backend placement decisions that belong
to later lowering.

## Relation to Current LLIR

`LLIR.md` describes the implementation and dump format.

For `v0.0.13`, this contract is the project boundary:

- structural lowering belongs in LIR
- machine-facing frame and ABI decisions belong below LIR

Any LLIR detail that violates this boundary is outside the intended contract.

## Current Boundary Status

The structural LLIR layer satisfies the main `v0.0.13` split:

- frame offsets do not live in `llir.pas`
- stack-slot policy does not live in `llir.pas`
- `enter` and `leave` are not part of structural LLIR
- the `.llir` dump does not emit frame summaries or slot assignments

What remains below full backend separation is narrower and mostly concerns
call/runtime behavior rather than frame layout.

### User Calls Are Structural Rather Than Transport-Shaped

User calls use the same structural pattern as intrinsics:

- the `call` instruction carries its argument operands directly as `arg1=`,
  `arg2=`, and so on
- a value-returning call writes its destination directly through the `call`
  instruction `result=...` operand
- the interpreter binds procedure parameters from the `call` instruction
  itself and writes the returned function value directly to the caller-provided
  result operand on return

Evidence in code:

- `src/llir.pas`: `irCall` validation accepts inline call arguments and an
  optional temporary result operand
- `src/llircgen.pas`: `lowerCall` emits one `call` carrying both arguments and
  optional result
- `src/llirint.pas`: `rtCall` consumes `callArguments` directly and stores the
  pending result destination on the return stack
- `src/llirint.pas`: `rtReturn` writes the function result directly to that
  destination

The structural LLIR core does not include separate `arg` or `result`
transport instructions.

Why this fits the contract:

- LIR exposes explicit calls and ordered operands
- but it no longer commits structural LLIR to one staged runtime transfer model
- a native backend can consume one call node and decide later how argument
  movement and return-value placement are realized physically

### Intrinsics Stay Target-Neutral While Backends Choose The Implementation

The boundary at this layer is:

- LLIR keeps target-neutral intrinsic identities for testing and inspection
- `llirint` may continue to execute those intrinsics directly as a fake testing
  backend
- later native backends may lower the same intrinsic identities to syscalls or
  runtime helpers without changing frontend lowering

LLIR describes which intrinsic operation is requested, but not how a
particular backend realizes it.

The implementation reflects that boundary like this:

- shared intrinsic identifiers, names, and signature rules live in a dedicated
  intrinsic-contract unit
- HLIR-to-LLIR lowering maps builtins onto those shared target-neutral
  identifiers
- structural LLIR validation consumes that shared intrinsic contract
- `llirint` implements those identifiers in an interpreter-side adapter used to
  test `.llir` directly

Evidence in code and docs:

- `src/llirintrinsics.pas`: shared intrinsic identifiers, names, and
  validation metadata
- `src/llir.pas`: LLIR validation consumes the shared intrinsic contract
- `src/llircgen.pas`: builtin lowering targets the shared intrinsic contract
- `src/llirint.pas`: `executeInterpreterIntrinsicCall` is an interpreter-side
  backend adapter, not part of structural LLIR
- `docs/LLIR.md`: documents direct intrinsic execution as an interpreter
  testing path rather than the meaning of LLIR itself

Why this fits the contract:

- target-neutral intrinsic identity stays available in LLIR for debugging and
  regression testing
- the interpreter can keep faking `read` and `write` behavior before syscall
  and runtime milestones land
- frontend lowering will not need to reopen semantics when native intrinsic
  lowering appears later
