# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project is expected to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### [Added]

- Allow bare `return;` in procedures, while functions still require `return <expr>;`.
- Add `continue` and `break` as loop-only statements for `while`, `repeat`, and `for`.
- Add support for functions returning a simple scalar value with a return statement.
- Add support for procedure parameters, simple types and by value only for now.

### [Changed]

- Allow each `switch` arm to match one or more comma-separated literals.
- Remove (`break` | `next`) finalizer from switch statement, now the statement sequence ends with `end`.

### [Fixed]

- Fix `switch` statement, at least one label and statement sequence is required.

## [v0.0.9] - 2026-06-02

### [Added]

- Add SQL-style `case` expressions in both simple and searched forms, usable anywhere an expression primary is allowed.
- Add `switch` ident `on` { literal `then` statementSequence ( `break` | `next` ) `;` } [ `else` statementSequence ] `endswitch` statement.
- Add `for` ident := low `to` high `do` statementSequence `endfor` loop statement.
- Add `repeat` .. `until` loop statement.

### [Changed]

- Enhance primes example, minor docs cleanup.
- Move primes.pl0 into programs folder, enhance with new statements.
- Update ROADMAP.md.

## [v0.0.8] - 2026-06-01

### Added

- Add README usage notes for compiling the PL/0 source and running p-code and TAC outputs.
- Add TAC IR format and interpreter documentation.
- Add a new `tacirint` TAC IR interpreter for executing dumped `.tac` images.
- Dump the IR image into a `.tac` file during compiler builds alongside `.pcode`.
- Add a new unit `tacircgen` with an AST-to-TAC lowering walker.
- Add a new `tacir` unit with flat three-address-code IR data structures and low-level build/dump state management.
- Add a new `builder` unit to drive the build control flow.

### Changed

- Rename the p-code interpreter program from `interpreter.pas` to `pcodeint.pas` and align p-code interpreter diagnostics around the new name.
- Wire the generation of the three-address-code IR into the builder.
- Rename the p-code generation unit from `codegen` to `pcode` and align its public procedure names around p-code generation.
- Extract compiler pipeline orchestration into a new `builder` unit, leaving the parser responsible only for producing an AST and parse errors.

## [v0.0.7] - 2026-05-30

### Added

- Improve README.md with a Motivation section.
- Add fizzbuzz example to main README.md file.
- Add readln() and writeln() as intrinsics procedures, only integer, char or boolean values.
- Add a fizzbuzz example program.
- Add mandatory main program header written as `program <name>;`.
- Add read() and write() as intrinsics procedures, only integer, char or boolean values.
- Add `char` datatype, single-character ASCII char literals such as `'a'` and char relational comparisons.

### Fixed

- Enhance fizzbuzz example program.
- Add diagnostic verbosity level to the interpreter to prevent flooding the expected output with trace and debug info.
- Fix additive expression parsing bug so binary `+` and `-` preserve their left operand instead of being misparsed as unary operators.

## [v0.0.6] - 2026-05-26

### Changed

- Replace `call ident` with Pascal-style zero-argument procedure calls written as `ident()`, and remove `call` from the reserved words.
- The `begin ... end` pair is no longer a statement form, it is now required only around the main program body and each procedure body.
- Change `if` syntax to `if expression then statementSequence {elsif expression then statementSequence} [else statementSequence] endif`, sharing the same required statement sequence form used by `while` and allowing optional `elsif` and `else` branches.
- Change `while` syntax to `while expression do statementSequence endwhile`, requiring `endwhile`, requiring at least one body statement, and treating `;` inside the loop body as a statement terminator.

### Fixed

- Many small fixes and cleanup of leftovers from previous commits.

## [v0.0.5] - 2026-05-25

### Added

- Add boolean operators `and`, `or`, `not`, and `xor` across lexing, parsing, semantic checks, codegen, and interpretation.
- Add relational operators to the precedence table, make them non-associative in the precedence parser while keeping them at the lowest binary precedence.
- Add support for `boolean` datatype, `true` and `false` literals in declarations.

### Changed

- Reject invalid boolean operator operand types with a dedicated semantic diagnostic.
- Reject constant declarations whose declared type and literal value type do not match.
- Make relational operators produce boolean expression values instead of using a separate condition-only parse path.
- Reject assignments whose target type and value type do not match, with a dedicated semantic diagnostic.
- Reject invalid arithmetic and relational operator operand types with dedicated semantic diagnostics.
- Reject non-boolean `if` and `while` conditions with a dedicated semantic diagnostic.
- Update grammar and p-code documentation so `if`/`while` use `expression` syntactically, with semantic analysis requiring a boolean result.

### Removed

- Remove legacy condition-only AST, semantic, and codegen scaffolding now that conditions use ordinary expressions.

## [v0.0.4] - 2026-05-24

### Added

- Add type information to ast nodes, filled by the semantics pass.
- Add new type table unit, very minimal for now.
- Add support for type declaration in `var` and `const`, mandatory and only `integer` datatype for now.

### Changed

- Replace grammar based parsing with an operator precedence climbing (Pratt) parser.
- Rename symtable to symboltable.

### Fixed

- Fix unwinding symbol table bug, leftover from codegen separation from parser.

### Removed

- Remove support for the `odd` operator.

## [v0.0.3] - 2026-05-22

### Added

- Add pcode generation unit.
- Add a new unit for semantic checks pass.
- Add an abstract syntax tree unit and add ast creation into the parser.
- Add symbol table unit for symbol table handling.
- Add lexer unit for lexical analysis.
- Add token unit for shared token data types.
- Add diagnostics unit for error and diagnostics helpers.
- Add main compiler program driver.

### Changed

- Rename compiler unit to parser, small cleanups and adjustements in all other units.
- Extract pcode generation from the compiler unit.
- Extract some semantic checks into semantics unit.
- Extract symbol table and symbol handling into its own unit.
- Extract lexer state and routines into its own unit.
- Extract token data types from parser into tokens unit.
- Extract error reporting from compiler into diagnostics unit.
- Extract main program driver from compiler, convert compiler into a unit.

## [v0.0.2] - 2026-05-20

### Added

- Add another three examples.
- Add tracing helpers for better debugging.

### Changed

- Change identifier names in examples to lowercase
- Change procedures declaration, they can only be declared in the global scope now.
- Update compiler, grammar, and p-code documentation to describe the two-scope model consistently.

### Removed

- Remove support for nested procedures from the grammar and the implementation.

## [v0.0.1] - 2026-05-18

### Added

- Add grammar documentation and implementation constraints.
- Add more comments in compiler and interpreter code.
- Add pcode machine documentation.
- Add basic project housekeeping files (`CHANGELOG.md`, `ROADMAP.md`, `RELEASING.md` ).
- Initial PL/0 source code and examples commit.
- Initial repository scaffolding commit.

### Changed

- Update RELEASING.md to reflect the current release plan workflow.
- Fix empty `begin` .. `end` statements, at least one inner statement is required.
- Small fixes related to ancient Pascal features (fixed around '↑' character, print only non empty instruction array positions, etc.).
- Rename all compact procedure names to more readable names, added comments in the procedure headers.
- Split variables names when a variable was used for two different purposes.
- Rename all compact variable names to more readable names.
- Rename all compact type names to more readable names.
- Rename all compact constant names to more readable names.
- Replace single character relational operators with double character ones.
- Change reserved words to lowercase, identifiers can be upper and lowercase.

### Removed

- Remove some old comments about goto statements and other ancient Pascal features.
