# Roadmap

This roadmap is intentionally conservative. The goal is to build the project in a sane order, with every milestone remaining coherent and buildable. The short term plan is listed in reverse order, and completed milestones will be moved to the changelog.

## Main Short Term Milestones

### v0.0.3 - Expression and Type Foundations

- Replace the current expression handling with a precedence climbing parser.
- Add a `type table` layer and introduce boolean datatype support.
- Rework conditions to use the new boolean datatype.

### v0.0.2 - Compiler Layer Separation

- Separate the compiler into main program and units for better project structure.
- Establish at least these layers: `lexer`, `parser`, `ast`, `symbol table`, `semantics`, `codegen`, `diagnostics`.
- Reduce cross-unit global state and make dependencies more explicit for better maintainability.

### v0.0.1 - Cleanup and Naming

- Rename old 1976-PL/0-era identifiers to clearer names.
- Remove obvious code cruft and artificial limitations that do not belong in modern Pascal.
- Improve comments, datatypes, and code shape where needed, but no new language features.
- Add pcode machine and codebase documentation.

For older releases, see [CHANGELOG.md](./CHANGELOG.md).
