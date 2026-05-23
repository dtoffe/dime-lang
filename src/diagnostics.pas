{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-21

  Centralized diagnostic reporting for the compiler and interpreter.  This unit
  owns diagnostic levels, verbosity handling, source-location context, and the
  shared compiler/runtime error reporting helpers. }
unit diagnostics;

interface

type
    diagnosticLevel = (debug, info, warn, error, status);
    diagnosticVerbosity = (quiet, all);
    {Source context travels with diagnostics and is typically produced by the
     lexer, then carried forward into AST, semantic, and codegen reporting.}
    sourceContext = record
        sourceName: string;
        line: integer;
        column: integer;
        sourceText: string;
    end;

const
    ERR_USE_EQUAL_NOT_BECOMES = 1;
    ERR_NUMBER_EXPECTED_AFTER_EQUAL = 2;
    ERR_IDENTIFIER_MUST_BE_FOLLOWED_BY_EQUAL = 3;
    ERR_DECLARATION_IDENTIFIER_EXPECTED = 4;
    ERR_SEMICOLON_OR_COMMA_MISSING = 5;
    ERR_INVALID_TOKEN_AFTER_PROCEDURE_DECLARATION = 6;
    ERR_STATEMENT_EXPECTED = 7;
    ERR_INVALID_TOKEN_AFTER_STATEMENT_PART_IN_BLOCK = 8;
    ERR_PERIOD_EXPECTED = 9;
    ERR_MISSING_SEMICOLON_BETWEEN_STATEMENTS = 10;
    ERR_UNDECLARED_IDENTIFIER = 11;
    ERR_ASSIGNMENT_TO_CONSTANT_OR_PROCEDURE = 12;
    ERR_ASSIGNMENT_OPERATOR_EXPECTED = 13;
    ERR_CALL_MUST_BE_FOLLOWED_BY_IDENTIFIER = 14;
    ERR_CALL_OF_CONSTANT_OR_VARIABLE = 15;
    ERR_THEN_EXPECTED = 16;
    ERR_SEMICOLON_OR_END_EXPECTED = 17;
    ERR_DO_EXPECTED = 18;
    ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT = 19;
    ERR_RELATIONAL_OPERATOR_EXPECTED = 20;
    ERR_PROCEDURE_IDENTIFIER_IN_EXPRESSION = 21;
    ERR_RIGHT_PARENTHESIS_MISSING = 22;
    ERR_INVALID_TOKEN_AFTER_FACTOR = 23;
    ERR_INVALID_TOKEN_AT_EXPRESSION_START = 24;
    ERR_NUMBER_TOO_LARGE = 30;
    ERR_NESTED_PROCEDURES_NOT_SUPPORTED = 31;
    ERR_PROCEDURES_GLOBAL_SCOPE_ONLY = 32;
    ERR_SYMBOL_TABLE_OVERFLOW = 33;

    ERROR_INTERPRETER_INVALID_L_VALUE = 'Error converting l-value';
    ERROR_INTERPRETER_INVALID_A_VALUE = 'Error converting a-value';

    STATUS_PROGRAM_INCOMPLETE = 'PROGRAM INCOMPLETE';
    STATUS_PROGRAM_TOO_LONG = 'PROGRAM TOO LONG';
    STATUS_PCODE_READING_COMPLETE = 'Reading complete. Records loaded: ';
    STATUS_INTERPRETER_START = 'START PROGRAM';
    STATUS_INTERPRETER_END = 'END PROGRAM';
    STATUS_COMPILER_PROCESSING_FILE = 'Processing file: ';
    STATUS_COMPILER_SUCCESS = 'PROGRAM COMPILED SUCCESSFULLY';
    STATUS_COMPILER_ERRORS = 'ERRORS IN PROGRAM';

procedure setDiagnosticVerbosity(verbosity: diagnosticVerbosity);
function getDiagnosticVerbosity: diagnosticVerbosity;
function tryParseDiagnosticVerbosity(const text: string; var verbosity: diagnosticVerbosity): boolean;
function makeSourceContext(const sourceName: string; line, column: integer;
                           const sourceText: string): sourceContext;
procedure emitDiagnostic(level: diagnosticLevel; const messageText: string);
procedure reportCompilerError(errorCode: integer; const context: sourceContext; var errorCount: integer);
procedure reportRuntimeError(const messageText: string);

implementation

uses
    SysUtils;

var
    currentDiagnosticVerbosity: diagnosticVerbosity = quiet;

procedure setDiagnosticVerbosity(verbosity: diagnosticVerbosity);
begin
    currentDiagnosticVerbosity := verbosity
end;

function getDiagnosticVerbosity: diagnosticVerbosity;
begin
    getDiagnosticVerbosity := currentDiagnosticVerbosity
end;

function tryParseDiagnosticVerbosity(const text: string; var verbosity: diagnosticVerbosity): boolean;
begin
    if SameText(text, 'quiet') then
        verbosity := quiet
    else if SameText(text, 'all') then
        verbosity := all
    else
    begin
        tryParseDiagnosticVerbosity := false;
        exit
    end;

    tryParseDiagnosticVerbosity := true
end;

function makeSourceContext(const sourceName: string; line, column: integer;
                           const sourceText: string): sourceContext;
begin
    makeSourceContext.sourceName := sourceName;
    makeSourceContext.line := line;
    makeSourceContext.column := column;
    makeSourceContext.sourceText := sourceText
end;

function shouldEmitDiagnostic(level: diagnosticLevel): boolean;
begin
    case currentDiagnosticVerbosity of
        all:
            shouldEmitDiagnostic := true;
        quiet:
            shouldEmitDiagnostic := level in [error, status]
    end
end;

function diagnosticLevelLabel(level: diagnosticLevel): string;
begin
    case level of
        debug: diagnosticLevelLabel := 'DEBUG';
        info: diagnosticLevelLabel := 'INFO';
        warn: diagnosticLevelLabel := 'WARN';
        error: diagnosticLevelLabel := 'ERROR';
        status: diagnosticLevelLabel := 'STATUS'
    end
end;

procedure emitDiagnostic(level: diagnosticLevel; const messageText: string);
begin
    {Much-later CLI tooling improvement:
     decide whether error diagnostics should be emitted to stderr instead of
     stdout. For now all diagnostics share the same output stream to keep the
     reporting path simple during compiler/interpreter refactoring.}
    if shouldEmitDiagnostic(level) then
        writeln('[', diagnosticLevelLabel(level), '] ', messageText)
end;

function compilerErrorMessage(errorCode: integer): string;
begin
    case errorCode of
        ERR_USE_EQUAL_NOT_BECOMES: compilerErrorMessage := 'Use = instead of :=.';
        ERR_NUMBER_EXPECTED_AFTER_EQUAL: compilerErrorMessage := '= must be followed by a number.';
        ERR_IDENTIFIER_MUST_BE_FOLLOWED_BY_EQUAL: compilerErrorMessage := 'Identifier must be followed by =.';
        ERR_DECLARATION_IDENTIFIER_EXPECTED: compilerErrorMessage := '"const", "var", "procedure" must be followed by an identifier. Possible reserved-word case error.';
        ERR_SEMICOLON_OR_COMMA_MISSING: compilerErrorMessage := 'Semicolon or comma missing.';
        ERR_INVALID_TOKEN_AFTER_PROCEDURE_DECLARATION: compilerErrorMessage := 'Incorrect symbol after procedure declaration.';
        ERR_STATEMENT_EXPECTED: compilerErrorMessage := 'Statement expected.';
        ERR_INVALID_TOKEN_AFTER_STATEMENT_PART_IN_BLOCK: compilerErrorMessage := 'Incorrect symbol after statement part in block.';
        ERR_PERIOD_EXPECTED: compilerErrorMessage := 'Period expected.';
        ERR_MISSING_SEMICOLON_BETWEEN_STATEMENTS: compilerErrorMessage := 'Semicolon between statements is missing.';
        ERR_UNDECLARED_IDENTIFIER: compilerErrorMessage := 'Undeclared identifier.';
        ERR_ASSIGNMENT_TO_CONSTANT_OR_PROCEDURE: compilerErrorMessage := 'Assignment to constant or procedure is not allowed.';
        ERR_ASSIGNMENT_OPERATOR_EXPECTED: compilerErrorMessage := 'Assignment operator := expected.';
        ERR_CALL_MUST_BE_FOLLOWED_BY_IDENTIFIER: compilerErrorMessage := '"call" must be followed by an identifier. Possible reserved-word case error.';
        ERR_CALL_OF_CONSTANT_OR_VARIABLE: compilerErrorMessage := 'Call of a constant or a variable is meaningless.';
        ERR_THEN_EXPECTED: compilerErrorMessage := '"then" expected. Possible reserved-word case error.';
        ERR_SEMICOLON_OR_END_EXPECTED: compilerErrorMessage := 'Semicolon or "end" expected. Possible reserved-word case error.';
        ERR_DO_EXPECTED: compilerErrorMessage := '"do" expected. Possible reserved-word case error.';
        ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT: compilerErrorMessage := 'Incorrect symbol following statement.';
        ERR_RELATIONAL_OPERATOR_EXPECTED: compilerErrorMessage := 'Relational operator expected.';
        ERR_PROCEDURE_IDENTIFIER_IN_EXPRESSION: compilerErrorMessage := 'Expression must not contain a procedure identifier.';
        ERR_RIGHT_PARENTHESIS_MISSING: compilerErrorMessage := 'Right parenthesis missing.';
        ERR_INVALID_TOKEN_AFTER_FACTOR: compilerErrorMessage := 'The preceding compileFactor cannot be followed by this symbol.';
        ERR_INVALID_TOKEN_AT_EXPRESSION_START: compilerErrorMessage := 'An expression cannot begin with this symbol.';
        ERR_NUMBER_TOO_LARGE: compilerErrorMessage := 'This number is too large.';
        ERR_NESTED_PROCEDURES_NOT_SUPPORTED: compilerErrorMessage := 'Nested procedures are not supported.';
        ERR_PROCEDURES_GLOBAL_SCOPE_ONLY: compilerErrorMessage := 'Procedures may only be declared at global scope.';
        ERR_SYMBOL_TABLE_OVERFLOW: compilerErrorMessage := 'Symbol table capacity exceeded.'
    else
        compilerErrorMessage := 'Unknown compiler error.'
    end
end;

procedure reportCompilerError(errorCode: integer; const context: sourceContext; var errorCount: integer);
begin
    errorCount := errorCount + 1;
    if shouldEmitDiagnostic(error) then
        writeln (' ****', ' ': context.column - 1, '^', errorCode:2);
    emitDiagnostic(error, compilerErrorMessage(errorCode));
end;

procedure reportRuntimeError(const messageText: string);
begin
    emitDiagnostic(error, messageText)
end;

end.
