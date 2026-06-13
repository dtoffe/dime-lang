# Dime LIR Contract

This document freezes the intended lowered IR contract for milestone
`v0.0.13 - Backend Lowering Contract`.

It describes the target-neutral LIR surface that frontend lowering may produce
and backend-specific lowering may consume. It is intentionally narrower than
the current implementation notes in `LLIR.md`: this page states the intended
contract, not every detail currently present in the dump.

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

- `arg`
- `call`
- `result`
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

The current `LLIR.md` describes the implementation as it exists today.

For `v0.0.13`, this contract is the design target:

- structural lowering belongs in LIR
- machine-facing frame and ABI decisions belong below LIR

Any current LLIR detail that violates this boundary should be treated as
transitional implementation state, not as the intended long-term contract.

## Current Boundary Status

The structural LLIR layer now satisfies the main `v0.0.13` split:

- frame offsets no longer live in `llir.pas`
- stack-slot policy no longer lives in `llir.pas`
- `enter` and `leave` are no longer part of structural LLIR
- the `.llir` dump no longer emits frame summaries or slot assignments

What still remains below full backend separation is narrower and mostly concerns
call/runtime behavior rather than frame layout.

### The current call shape still leaks some ABI-facing decisions

The contract allows explicit calls, but the current LLIR still bakes in more of
the calling sequence than the intended boundary should promise.

Still-present details:

- `arg` instructions carry ordered argument positions
- calls require exact argument-count agreement with callee parameter count
- `result` models a distinct post-call value retrieval step

Evidence in code:

- `src/llir.pas`: `llirInstruction.positionIndex`, `callArgumentCount`, and
  `callArguments`
- `src/llircgen.pas`: `appendCallArgument`
- `src/llircgen.pas`: `lowerCall` emits `arg`, `call`, and optional `result`
- `src/llirint.pas`: `pendingCallArguments`
- `src/llirint.pas`: `rtCall` checks `pendingCallArgumentCount` against callee
  `parameterCount`
- `src/llirint.pas`: `rtResult` consumes saved call result state

Why this is only partially compatible with the contract:

- explicit call sequencing is acceptable at LIR
- tying it to one exact runtime argument-transfer model is still more
  backend-shaped than intended

### Intrinsics are coupled to the current runtime model

The contract allows target-neutral intrinsics, but the current LLIR and
interpreter couple those intrinsics directly to a concrete runtime execution
path.

Still-present details:

- LLIR names a fixed compiler-known intrinsic set in the core IR model
- intrinsic validation hardcodes argument counts, return types, and side-effect
  classification in `llir.pas`
- HLIR-to-LLIR lowering maps source builtins directly onto those concrete
  intrinsic names
- `llirint` executes those intrinsic names directly instead of consuming a
  lower runtime/backend boundary

Evidence in code and docs:

- `src/llir.pas`: `llirIntrinsicKind`
- `src/llir.pas`: `intrinsicParameterCount`, `intrinsicReturnType`,
  `intrinsicSideEffect`, `intrinsicParameterType`,
  `intrinsicAcceptsValueType`, `validateTacIntrinsicCall`
- `src/llircgen.pas`: `appendIntrinsicCall`, builtin lowering in `lowerCall`
- `src/llirint.pas`: `executeIntrinsicCall`
- `docs/LLIR.md`: "Intrinsics are interpreted directly rather than lowered to
  syscalls yet"

Why this is a contract leak:

- target-neutral intrinsic identity is fine at LIR
- direct execution semantics in the LLIR interpreter mean the current stage is
  still acting as both IR boundary and runtime boundary
- that makes it harder to keep runtime/OS concerns cleanly below LIR
