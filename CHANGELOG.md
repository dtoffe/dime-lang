# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project is expected to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Add diagnostics unit for error and diagnostics helpers.
- Add main compiler program driver.

### Changed

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
