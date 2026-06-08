# Roadmap

This roadmap is intentionally conservative. The goal is to build the project in a sane order, with every milestone remaining coherent and buildable. The short term plan is listed in reverse order, and completed milestones will be moved to the changelog.

## Main Short Term Milestones

### v0.0.26 - Cleanup and First Optimizations

- Add small, safe optimization passes only after the assembler path is stable.
- Fold obvious constants in the high-level IR.
- Remove trivially dead blocks in the lowered IR.
- Add minimal copy cleanup where it is clearly correct.

### v0.0.25 - Language Reference Draft

- Start consolidating grammar, semantics, and implementation notes into a proper language guide.
- Document the high-level IR and lowered IR contracts.
- Record calling convention, frame layout, and intrinsic behavior.

### v0.0.24 - Data Layout Consolidation

- Centralize layout rules for scalars, strings, arrays, records, and sets.
- Make backend code query layout metadata instead of re-deriving it ad hoc.
- Prepare for size, alignment, and offset queries to become first-class services.

### v0.0.23 - Sets

- Add set datatypes.
- Decide on a concrete first representation before implementing the full feature.
- Introduce membership and basic set operations incrementally.

### v0.0.22 - Records

- Add record datatypes.
- Add field access to the high-level IR.
- Lower field access into explicit offsets and address arithmetic in the lowered IR.

### v0.0.21 - Arrays

- Add array datatypes.
- Add indexing semantics to the high-level IR.
- Lower indexing into explicit address arithmetic in the lowered IR.

### v0.0.20 - String Type

- Add the `string` datatype.
- Decide on the first string representation early.
- Add runtime or intrinsic support needed to read, write, and carry strings through the pipeline.
- Use strings in examples once the representation stabilizes.

### v0.0.19 - Enumerations and Subranges

- Add enumeration datatypes.
- Add subrange datatypes.
- Define their representation and comparison rules clearly in lowering and runtime behavior.

### v0.0.18 - Type System Refactor

- Rework the type table into a stronger representation.
- Add explicit size, layout, and type-category queries.
- Prepare the compiler for non-scalar types without rewriting the frontend later.

### v0.0.17 - Backend Validation

- Expand examples and golden-style output checks for both interpreter and assembler paths.
- Cross-check the TAC interpreter backend against the assembler backend.
- Stabilize frame layout and calling convention behavior with broader coverage.

### v0.0.16 - Intrinsics to Runtime / Syscall Layer

- Lower TAC intrinsics to a clean runtime or syscall boundary.
- Implement read and write using the target OS interface.
- Preserve the target-neutral intrinsic model above that boundary.

### v0.0.15 - Toolchain Integration

- Add assembling and linking flow for generated assembly.
- Produce runnable executables from the assembler backend.
- Keep the pcode backend in parallel while the native path matures.

### v0.0.14 - First Assembler Backend

- Emit a first x86/x64 text assembly backend for scalar programs.
- Use the current stack-slot temporary policy and simple scratch-register lowering.
- Support locals, parameters, calls, branches, returns, and intrinsics well enough to run real examples.

### v0.0.13 - LIR / Assembler Boundary

- Define a clear boundary between the lowered IR and the assembler emitter.
- Separate target-neutral assembly emission logic from target-specific ABI and OS concerns.
- Freeze a small backend-ready lowered IR surface before codegen grows further.

### v0.0.12 - IR Split

- Introduce explicit high-level IR and lowered IR concepts.
- Treat the current TAC shape as the seed of the lowered IR.
- Add an initial high-level-IR-to-lowered-IR lowering pass.
- Keep frame layout and backend preparation below the high-level IR boundary.
- Preserve current behavior while making the stages conceptually explicit.

For older releases, see [CHANGELOG.md](./CHANGELOG.md).
