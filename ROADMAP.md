# Roadmap

This roadmap is intentionally conservative. The goal is to build the project in a sane order, with every milestone remaining coherent and buildable. The short term plan is listed in reverse order, and completed milestones will be moved to the changelog.

## Main Short Term Milestones

### v0.0.13 - Structured Datatypes

- Add array datatypes
- Add record datatypes
- Add set datatypes.
- Rework type table adding specialized tables for types.

### v0.0.12 - Additional Datatypes

- Add `string` datatype.
- Add enumeration datatypes.
- Add subrange datatypes
- Use strings in all examples.

### v0.0.11 - Add function and return

- Add `function` construct.
- Add `return` statement.
- Possibly add some `break` and `continue` to adjust loops behaviour

### v0.0.10 - Add assembler codegen

- Add an x86/x64 assembler code generator.
- Decide if adding an asm interpreter or going straight to binary.
- Keep the pcode backend in paralell for some time.
- Maybe start defining some kind of target specific layer.

### v0.0.8 - Add more statements

- Add `case` statement.
- Add `repeat` statement.
- Add `for` statement.
- Rework examples to add the new statements.

### v0.0.8 - Add a mid-level IR

- Add codegen for a mid-level IR, likely some form of three address code
- Add another interpreter for the new mid-level IR
- Keep pcode and the stack machine in paralell for some time

### v0.0.7 - Char datatype, read and write

- Add read() and write() as intrinsics procedures, not statements as traditional PL/0.
- Add `char` datatype.
- Rework examples, separate in programs and tests.

### v0.0.6 - Statement Shape Refactor

- Refactor the shape of `if` and `while` statements to Modula style.
- Remove `begin`...`end` as statement, allow it in program and procedure block syntax.
- Replace `call` statement with proper procedure calls with mandatory parens even when without parameters
- Align statement syntax and AST representation.
- Tighten diagnostics and examples around the new statement forms.

For older releases, see [CHANGELOG.md](./CHANGELOG.md).
