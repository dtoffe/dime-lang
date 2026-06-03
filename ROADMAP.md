# Roadmap

This roadmap is intentionally conservative. The goal is to build the project in a sane order, with every milestone remaining coherent and buildable. The short term plan is listed in reverse order, and completed milestones will be moved to the changelog.

## Main Short Term Milestones

### v0.0.14 - Structured Datatypes

- Add array datatypes
- Add record datatypes
- Add set datatypes.
- Rework type table adding specialized tables for types.

### v0.0.13 - Additional Datatypes

- Add `string` datatype.
- Add enumeration datatypes.
- Add subrange datatypes
- Use strings in all examples.

### v0.0.12 - Add assembler codegen

- Define some kind of boundary between the assembler generator and some target arch/OS specific layer.
- Add an x86/x64 assembler code generator.
- Add support for write and read syscalls.
- Setup the tooling for the assembling and linking process.
- Keep the pcode backend in paralell for some time.

### v0.0.11 - Backend preparation

- Define storage layout assignment for locals, temporaries, and procedure state.
- Add a model for the activation records of procedure calls.
- Define an explicit call and return convention in the IR.
- Introduce a target-neutral intrinsic layer for read, readln, write, and writeln.
- Stress test TAC with more examples so it becomes stable and solid before moving on to assembler generation.

### v0.0.10 - Add function and return

- Add `function` construct.
- Add `return` statement.
- Possibly add some `break` and `continue` to adjust loops behaviour.

### v0.0.9 - Add more statements

- Add `case` expression.
- Add `switch` statement.
- Add `repeat` statement.
- Add `for` statement.
- Rework examples to add the new statements.

For older releases, see [CHANGELOG.md](./CHANGELOG.md).
