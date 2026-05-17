# Roadmap

This roadmap is intentionally conservative. The goal is to build the project in a sane order, with every milestone remaining coherent and buildable. The short term plan is listed in reverse order, and completed milestones will be moved to the changelog.

## Main Short Term Milestones

### v0.0.7 - Structured and Additional Datatypes

- Add `char` datatype and `string` datatype.
- Add enumerations, subranges, arrays, records and sets.
- Add more and better examples.

### v0.0.6 - Add more statements

- Add `case`, `repeat` and `for` statement.
- Possibly add `function` and `return` statement.
- Add more and better examples.

### v0.0.5 - Statement Shape Refactor

- Refactor the shape of `if` and `while` statements to Modula style.
- Remove `begin`...`end` as statement, allow it in program and procedure block syntax.
- Align statement syntax and AST representation.
- Tighten diagnostics and examples around the new statement forms.

### v0.0.4 - Expression and Type Foundations

- Replace the current expression handling with a precedence climbing (Pratt)parser.
- Add a `type table` layer and introduce boolean datatype support.
- Ensure the AST is typed independently of the symbol table.
- Rework conditions to use the new boolean datatype, adjust grammar to reflect that.

### v0.0.3 - Compiler Layer Separation

- Separate the compiler into main program and units for better project structure.
- Establish at least these layers: `lexer`, `parser`, `ast`, `symbol table`, `semantics`, `codegen`, `diagnostics`.
- Reduce cross-unit global state and make dependencies more explicit for better maintainability.

### v0.0.2 - Small enhancements and better debugging

- Remove support for nested procedures, adjust grammar to reflect that.
- Add read() and write() as intrinsics procedures, not statements as traditional PL/0.
- Add some better tracing and/or debug machinery to simplify testing and debugging.
- Add a couple additional examples, use read() and write() in all of them.

### v0.0.1 - Cleanup and Naming

- Rename old 1976-PL/0-era identifiers to clearer names for readability and consistency.
- Remove obvious code cruft and artificial limitations that do not belong in modern Pascal.
- Improve comments, datatypes, and code shape where needed, but no new language features.
- Add pcode machine and codebase documentation.
- Make sure grammar documentation matches the actual accepted syntax before later refactors begin.

For older releases, see [CHANGELOG.md](./CHANGELOG.md).
