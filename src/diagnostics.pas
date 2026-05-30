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
    ERR_STATEMENT_EXPECTED = 7;
    ERR_INVALID_TOKEN_AFTER_STATEMENT_PART_IN_BLOCK = 8;
    ERR_PERIOD_EXPECTED = 9;
    ERR_UNDECLARED_IDENTIFIER = 11;
    ERR_ASSIGNMENT_TO_CONSTANT_OR_PROCEDURE = 12;
    ERR_IDENTIFIER_STATEMENT_MUST_BE_ASSIGNMENT_OR_CALL = 14;
    ERR_CALL_OF_CONSTANT_OR_VARIABLE = 15;
    ERR_THEN_EXPECTED = 16;
    ERR_SEMICOLON_OR_END_EXPECTED = 17;
    ERR_DO_EXPECTED = 18;
    ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT = 19;
    ERR_SEMICOLON_OR_ENDWHILE_EXPECTED = 20;
    ERR_PROCEDURE_IDENTIFIER_IN_EXPRESSION = 21;
    ERR_RIGHT_PARENTHESIS_MISSING = 22;
    ERR_INVALID_TOKEN_AFTER_FACTOR = 23;
    ERR_INVALID_TOKEN_AT_EXPRESSION_START = 24;
    ERR_NUMBER_TOO_LARGE = 30;
    ERR_NESTED_PROCEDURES_NOT_SUPPORTED = 31;
    ERR_PROCEDURES_GLOBAL_SCOPE_ONLY = 32;
    ERR_SYMBOL_TABLE_OVERFLOW = 33;
    ERR_TYPE_NAME_EXPECTED = 34;
    ERR_TYPE_ANNOTATION_EXPECTED = 35;
    ERR_BOOLEAN_CONDITION_REQUIRED = 36;
    ERR_ASSIGNMENT_TYPE_MISMATCH = 37;
    ERR_ARITHMETIC_OPERATOR_REQUIRES_INTEGER_OPERANDS = 38;
    ERR_RELATIONAL_OPERANDS_MUST_HAVE_MATCHING_TYPES = 39;
    ERR_ORDERING_OPERATOR_REQUIRES_INTEGER_OPERANDS = 40;
    ERR_BOOLEAN_OPERATOR_REQUIRES_BOOLEAN_OPERANDS = 41;
    ERR_CONSTANT_TYPE_MISMATCH = 42;
    ERR_ENDIF_EXPECTED = 43;
    ERR_SEMICOLON_EXPECTED_BEFORE_ENDIF = 44;
    ERR_SEMICOLON_EXPECTED_BEFORE_ELSIF_ELSE_OR_ENDIF = 45;
    ERR_BLOCK_BEGIN_EXPECTED = 46;
    ERR_BLOCK_END_EXPECTED = 47;
    ERR_EMPTY_CHARACTER_LITERAL = 48;
    ERR_CHARACTER_LITERAL_MUST_CONTAIN_EXACTLY_ONE_CHARACTER = 49;
    ERR_CHARACTER_LITERAL_OUT_OF_RANGE = 50;
    ERR_UNTERMINATED_CHARACTER_LITERAL = 51;
    ERR_PROCEDURE_ARGUMENTS_NOT_YET_SUPPORTED = 52;
    ERR_ONLY_ONE_CALL_ARGUMENT_SUPPORTED = 53;
    ERR_BUILTIN_PROCEDURE_NOT_YET_IMPLEMENTED = 54;
    ERR_WRITE_REQUIRES_ARGUMENT = 55;
    ERR_WRITE_ARGUMENT_TYPE_UNSUPPORTED = 56;
    ERR_READ_REQUIRES_ARGUMENT = 57;
    ERR_READ_ARGUMENT_MUST_BE_VARIABLE = 58;
    ERR_READ_ARGUMENT_TYPE_UNSUPPORTED = 59;
    ERR_PROGRAM_HEADER_EXPECTED = 60;
    ERR_PROGRAM_NAME_EXPECTED = 61;
    ERR_PROGRAM_HEADER_SEMICOLON_EXPECTED = 62;

    ERROR_INTERPRETER_INVALID_L_VALUE = 'Error converting l-value';
    ERROR_INTERPRETER_INVALID_A_VALUE = 'Error converting a-value';
    ERROR_INTERPRETER_INPUT_EXHAUSTED = 'Input exhausted while executing built-in read/readln.';
    ERROR_INTERPRETER_INVALID_INTEGER_INPUT = 'Built-in read/readln expected an integer token.';
    ERROR_INTERPRETER_INVALID_CHARACTER_INPUT = 'Built-in read/readln expected a one-character token.';
    ERROR_INTERPRETER_INVALID_BOOLEAN_INPUT = 'Built-in read/readln expected 0 or 1.';

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
        ERR_NUMBER_EXPECTED_AFTER_EQUAL: compilerErrorMessage := 'Constant declaration = must be followed by a literal value.';
        ERR_IDENTIFIER_MUST_BE_FOLLOWED_BY_EQUAL: compilerErrorMessage := 'Identifier must be followed by =.';
        ERR_DECLARATION_IDENTIFIER_EXPECTED: compilerErrorMessage := '"const", "var", "procedure" must be followed by an identifier. Possible reserved-word case error.';
        ERR_SEMICOLON_OR_COMMA_MISSING: compilerErrorMessage := 'Semicolon or comma missing.';
        ERR_STATEMENT_EXPECTED: compilerErrorMessage := 'Statement expected.';
        ERR_INVALID_TOKEN_AFTER_STATEMENT_PART_IN_BLOCK: compilerErrorMessage := 'Incorrect symbol after statement part in block.';
        ERR_PERIOD_EXPECTED: compilerErrorMessage := 'Period expected.';
        ERR_UNDECLARED_IDENTIFIER: compilerErrorMessage := 'Undeclared identifier.';
        ERR_ASSIGNMENT_TO_CONSTANT_OR_PROCEDURE: compilerErrorMessage := 'Assignment to constant or procedure is not allowed.';
        ERR_IDENTIFIER_STATEMENT_MUST_BE_ASSIGNMENT_OR_CALL: compilerErrorMessage := 'Statement starting with an identifier must be an assignment or a procedure call written as ident().';
        ERR_CALL_OF_CONSTANT_OR_VARIABLE: compilerErrorMessage := 'Call of a constant or a variable is meaningless.';
        ERR_THEN_EXPECTED: compilerErrorMessage := '"then" expected. Possible reserved-word case error.';
        ERR_ENDIF_EXPECTED: compilerErrorMessage := '"endif" expected. Possible reserved-word case error.';
        ERR_SEMICOLON_OR_END_EXPECTED: compilerErrorMessage := 'Semicolon or "end" expected. Possible reserved-word case error.';
        ERR_DO_EXPECTED: compilerErrorMessage := '"do" expected. Possible reserved-word case error.';
        ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT: compilerErrorMessage := 'Incorrect symbol following statement.';
        ERR_SEMICOLON_OR_ENDWHILE_EXPECTED: compilerErrorMessage := 'Semicolon or "endwhile" expected. Possible reserved-word case error.';
        ERR_PROCEDURE_IDENTIFIER_IN_EXPRESSION: compilerErrorMessage := 'Expression must not contain a procedure identifier.';
        ERR_RIGHT_PARENTHESIS_MISSING: compilerErrorMessage := 'Right parenthesis missing.';
        ERR_INVALID_TOKEN_AFTER_FACTOR: compilerErrorMessage := 'The preceding factor cannot be followed by this symbol.';
        ERR_INVALID_TOKEN_AT_EXPRESSION_START: compilerErrorMessage := 'An expression cannot begin with this symbol.';
        ERR_NUMBER_TOO_LARGE: compilerErrorMessage := 'This number is too large.';
        ERR_NESTED_PROCEDURES_NOT_SUPPORTED: compilerErrorMessage := 'Nested procedures are not supported.';
        ERR_PROCEDURES_GLOBAL_SCOPE_ONLY: compilerErrorMessage := 'Procedures may only be declared at global scope.';
        ERR_SYMBOL_TABLE_OVERFLOW: compilerErrorMessage := 'Symbol table capacity exceeded.';
        ERR_TYPE_NAME_EXPECTED: compilerErrorMessage := 'Type name expected after ":".';
        ERR_TYPE_ANNOTATION_EXPECTED: compilerErrorMessage := 'Declaration must include a type annotation.';
        ERR_BOOLEAN_CONDITION_REQUIRED: compilerErrorMessage := 'Condition expression must resolve to boolean.';
        ERR_ASSIGNMENT_TYPE_MISMATCH: compilerErrorMessage := 'Assignment target type must match assigned value type.';
        ERR_ARITHMETIC_OPERATOR_REQUIRES_INTEGER_OPERANDS: compilerErrorMessage := 'Arithmetic operator requires integer operands.';
        ERR_RELATIONAL_OPERANDS_MUST_HAVE_MATCHING_TYPES: compilerErrorMessage := 'Relational operands must have matching operand types.';
        ERR_ORDERING_OPERATOR_REQUIRES_INTEGER_OPERANDS: compilerErrorMessage := 'Ordering relational operators require integer or char operands.';
        ERR_BOOLEAN_OPERATOR_REQUIRES_BOOLEAN_OPERANDS: compilerErrorMessage := 'Boolean operator requires boolean operands.';
        ERR_CONSTANT_TYPE_MISMATCH: compilerErrorMessage := 'Constant declaration type must match its literal value type.';
        ERR_SEMICOLON_EXPECTED_BEFORE_ENDIF: compilerErrorMessage := 'Semicolon expected before "endif". Possible reserved-word case error.';
        ERR_SEMICOLON_EXPECTED_BEFORE_ELSIF_ELSE_OR_ENDIF: compilerErrorMessage := 'Semicolon expected before "elsif", "else" or "endif". Possible reserved-word case error.';
        ERR_BLOCK_BEGIN_EXPECTED: compilerErrorMessage := '"begin" expected to start block body. Possible reserved-word case error.';
        ERR_BLOCK_END_EXPECTED: compilerErrorMessage := '"end" expected to close block body. Possible reserved-word case error.';
        ERR_EMPTY_CHARACTER_LITERAL: compilerErrorMessage := 'Character literal must not be empty.';
        ERR_CHARACTER_LITERAL_MUST_CONTAIN_EXACTLY_ONE_CHARACTER: compilerErrorMessage := 'Character literal must contain exactly one character.';
        ERR_CHARACTER_LITERAL_OUT_OF_RANGE: compilerErrorMessage := 'Character literal must use a raw ASCII character in the range $20..$7F.';
        ERR_UNTERMINATED_CHARACTER_LITERAL: compilerErrorMessage := 'Character literal is missing its closing quote.';
        ERR_PROCEDURE_ARGUMENTS_NOT_YET_SUPPORTED: compilerErrorMessage := 'Procedure call arguments parse into the AST, but argument passing is not implemented yet.';
        ERR_ONLY_ONE_CALL_ARGUMENT_SUPPORTED: compilerErrorMessage := 'Only one procedure-call argument is supported at this temporary stage.';
        ERR_BUILTIN_PROCEDURE_NOT_YET_IMPLEMENTED: compilerErrorMessage := 'Built-in procedure is recognized by the compiler, but code generation for it is not implemented yet.';
        ERR_WRITE_REQUIRES_ARGUMENT: compilerErrorMessage := 'Built-in procedures "write" and "writeln" currently require exactly one argument.';
        ERR_WRITE_ARGUMENT_TYPE_UNSUPPORTED: compilerErrorMessage := 'Built-in procedures "write" and "writeln" require an integer, char, or boolean argument.';
        ERR_READ_REQUIRES_ARGUMENT: compilerErrorMessage := 'Built-in procedures "read" and "readln" currently require exactly one variable argument.';
        ERR_READ_ARGUMENT_MUST_BE_VARIABLE: compilerErrorMessage := 'Built-in procedures "read" and "readln" require a writable variable argument.';
        ERR_READ_ARGUMENT_TYPE_UNSUPPORTED: compilerErrorMessage := 'Built-in procedures "read" and "readln" require an integer, char, or boolean variable.';
        ERR_PROGRAM_HEADER_EXPECTED: compilerErrorMessage := 'Program must start with "program <name>;". Possible reserved-word case error.';
        ERR_PROGRAM_NAME_EXPECTED: compilerErrorMessage := '"program" must be followed by an identifier.';
        ERR_PROGRAM_HEADER_SEMICOLON_EXPECTED: compilerErrorMessage := 'Semicolon expected after program header.';
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
