# Roadmap

This roadmap is intentionally conservative. The goal is to build the project in a sane order, with every milestone remaining coherent and buildable. The short term plan is listed in reverse order, and completed milestones will be moved to the changelog.

## Main Short Term Milestones

### v0.0.24 - Cleanup and First Optimizations

- Add small, safe optimization passes only after the assembler path is stable.
- Fold obvious constants in the high-level IR.
- Remove trivially dead blocks in the lowered IR.
- Add minimal copy cleanup where it is clearly correct.

### v0.0.23 - Language Reference Draft

- Start consolidating grammar, semantics, and implementation notes into a proper language guide.
- Document the high-level IR and lowered IR contracts.
- Record calling convention, frame layout, and intrinsic behavior.

### v0.0.22 - Data Layout Consolidation

- Centralize layout rules for scalars, strings, arrays, records, and sets.
- Make backend code query layout metadata instead of re-deriving it ad hoc.
- Prepare for size, alignment, and offset queries to become first-class services.

### v0.0.21 - Sets

- Add set datatypes.
- Decide on a concrete first representation before implementing the full feature.
- Introduce membership and basic set operations incrementally.

### v0.0.20 - Records

- Add record datatypes.
- Add field access to the high-level IR.
- Lower field access into explicit offsets and address arithmetic in the lowered IR.

### v0.0.19 - Arrays

- Add array datatypes.
- Add indexing semantics to the high-level IR.
- Lower indexing into explicit address arithmetic in the lowered IR.

### v0.0.18 - String Type

- Add the `string` datatype.
- Decide on the first string representation early.
- Add runtime or intrinsic support needed to read, write, and carry strings through the pipeline.
- Use strings in examples once the representation stabilizes.

### v0.0.17 - Enumerations and Subranges

- Add enumeration datatypes.
- Add subrange datatypes.
- Define their representation and comparison rules clearly in lowering and runtime behavior.

### v0.0.16 - Type System Refactor

- Rework the type table into a stronger representation.
- Add explicit size, layout, and type-category queries.
- Prepare the compiler for non-scalar types without rewriting the frontend later.

### v0.0.15 - Runtime Boundary and Backend Validation

- Lower target-neutral intrinsics to a runtime or syscall boundary.
- Implement read/write through the first supported OS interface.
- Cross-check interpreter and native backend behavior.
- Expand examples and golden-style output tests.
- Stabilize frame layout and calling convention behavior with broader coverage.

### v0.0.14 - First Native Backend

- Emit first x86-64 assembly for scalar programs.
- Use stack-slot temporaries and simple scratch-register lowering.
- Support locals, parameters, calls, branches, returns, and basic intrinsics.
- Add assembling and linking flow.
- Produce runnable native executables.
- Keep the p-code/interpreter backend in parallel.

### v0.0.13 - Backend Lowering Contract

- Define the backend-ready lowered IR surface.
- Make HIR-to-LIR lowering explicit and inspectable.
- Keep frame layout, ABI, and OS concerns below the LIR boundary.
- Preserve current interpreter behavior while preparing for native codegen.

For older releases, see [CHANGELOG.md](./CHANGELOG.md).
