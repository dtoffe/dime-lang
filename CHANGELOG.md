# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project is expected to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Add grammar documentation and implementation constraints.
- Add more comments in compiler and interpreter code.
- Add pcode machine documentation.
- Add basic project housekeeping files (`CHANGELOG.md`, `ROADMAP.md`, `RELEASING.md` ).
- Initial PL/0 source code and examples commit.
- Initial repository scaffolding commit.

### Changed

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
