{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-21

  Lexical analysis for the parser front end.  This unit owns lexer state, source file
  reading, reserved-word recognition, tokenization, and the minimal setup and
  cleanup needed to feed tokens to the parser. }
unit lexer;

interface

uses
  diagnostics, tokens;

procedure initializeLexer(const inputFileName: string; var errorCount: integer);
procedure cleanupLexer;
procedure readNextToken(var errorCount: integer);
function lexerCurrentToken: symbol;
function lexerCurrentIdentifier: identifier;
function lexerCurrentNumber: integer;
function lexerCurrentSourceContext: sourceContext;

implementation

uses
  SysUtils;

const reservedWordCount = 14;
    numberMaxDigits = 14;

type sourceLineBuffer = array [1..81] of char;
    LexerState = record
                   sourceFile: Text;
                   sourceFileName: string;
                   currentChar: char;
                   currentToken: symbol;
                   currentIdentifier: identifier;
                   currentNumber: integer;
                   currentLineNumber: integer;
                   charIndex: integer;
                   lineLength: integer;
                   sourceLine: sourceLineBuffer;
                   identifierBuffer: identifier;
                   identifierBufferLength: integer;
                 end;

var lexState: LexerState;

const
  reservedWords: array [1..reservedWordCount] of identifier = (
    'begin     ',
    'boolean   ',
    'call      ',
    'const     ',
    'do        ',
    'end       ',
    'false     ',
    'if        ',
    'integer   ',
    'procedure ',
    'then      ',
    'true      ',
    'var       ',
    'while     '
  );
  reservedWordTokens: array [1..reservedWordCount] of symbol = (
    beginsym,
    booleansym,
    callsym,
    constsym,
    dosym,
    endsym,
    falsesym,
    ifsym,
    integersym,
    procsym,
    thensym,
    truesym,
    varsym,
    whilesym
  );

function identifierToString(const identifier: identifier): string;
    var characterIndex: integer;
begin
    identifierToString := '';
    for characterIndex := Low(identifier) to High(identifier) do
        identifierToString := identifierToString + identifier[characterIndex];
    identifierToString := TrimRight(identifierToString)
end {identifierToString} ;

function lexerCurrentToken: symbol;
begin
    lexerCurrentToken := lexState.currentToken
end {lexerCurrentToken} ;

function lexerCurrentIdentifier: identifier;
begin
    lexerCurrentIdentifier := lexState.currentIdentifier
end {lexerCurrentIdentifier} ;

function lexerCurrentNumber: integer;
begin
    lexerCurrentNumber := lexState.currentNumber
end {lexerCurrentNumber} ;

function lexerCurrentSourceContext: sourceContext;
var
  sourceText: string;
  characterIndex: integer;
begin
    sourceText := '';
    for characterIndex := 1 to lexState.lineLength - 1 do
        sourceText := sourceText + lexState.sourceLine[characterIndex];
    lexerCurrentSourceContext := makeSourceContext(lexState.sourceFileName,
                                                   lexState.currentLineNumber,
                                                   lexState.charIndex,
                                                   sourceText)
end {lexerCurrentSourceContext} ;

procedure traceSourceLine;
    var sourceText: string;
        characterIndex: integer;
begin
    sourceText := '';
    for characterIndex := 1 to lexState.lineLength - 1 do
        sourceText := sourceText + lexState.sourceLine[characterIndex];
    emitDiagnostic(debug, '[SRC ] ' + sourceText)
end {traceSourceLine} ;

procedure traceToken;
    var tokenText: string;
begin
    if lexState.currentToken = ident then
        tokenText := identifierToString(lexState.currentIdentifier)
    else if lexState.currentToken = number then
        tokenText := IntToStr(lexState.currentNumber)
    else
        tokenText := '';
    emitDiagnostic(debug, '[LEX ] ' + IntToStr(ord(lexState.currentToken)) + ' ' + tokenText)
end {traceToken} ;

procedure cleanupLexer;
begin
    close(lexState.sourceFile)
end {cleanupLexer} ;

procedure readNextToken(var errorCount: integer);
    var reservedWordLow, reservedWordHigh, reservedWordIndex: integer;
        identifierCharCount, digitCount: integer;

    procedure readNextChar;
    begin
        if lexState.charIndex = lexState.lineLength then
        begin
            if eof(lexState.sourceFile) then
            begin
                emitDiagnostic(error, STATUS_PROGRAM_INCOMPLETE);
                cleanupLexer;
                halt
            end ;
            lexState.lineLength := 0;
            lexState.charIndex := 0;
            lexState.currentLineNumber := lexState.currentLineNumber + 1;
            while not eoln(lexState.sourceFile) do
            begin
                lexState.lineLength := lexState.lineLength + 1;
                read(lexState.sourceFile, lexState.currentChar);
                lexState.sourceLine[lexState.lineLength] := lexState.currentChar
            end ;
            lexState.lineLength := lexState.lineLength + 1;
            read(lexState.sourceFile, lexState.sourceLine[lexState.lineLength]);
            traceSourceLine
        end ;
        lexState.charIndex := lexState.charIndex + 1;
        lexState.currentChar := lexState.sourceLine[lexState.charIndex]
     end {readNextChar} ;

begin {readNextToken}
    while (lexState.currentChar = ' ') or (lexState.currentChar = chr(10)) or
          (lexState.currentChar = chr(13)) do
        readNextChar;
    if lexState.currentChar in ['A'..'Z', 'a'..'z'] then
    begin
        identifierCharCount := 0;
        repeat
            if identifierCharCount < maxIdentLength then
            begin
                identifierCharCount := identifierCharCount + 1;
                lexState.identifierBuffer[identifierCharCount] := lexState.currentChar
            end ;
            readNextChar
        until not (lexState.currentChar in ['A'..'Z', 'a'..'z', '0'..'9']);
        if identifierCharCount >= lexState.identifierBufferLength then
            lexState.identifierBufferLength := identifierCharCount
        else
            repeat
                lexState.identifierBuffer[lexState.identifierBufferLength] := ' ';
                lexState.identifierBufferLength := lexState.identifierBufferLength - 1
            until lexState.identifierBufferLength = identifierCharCount;
        lexState.currentIdentifier := lexState.identifierBuffer;
        reservedWordLow := 1;
        reservedWordHigh := reservedWordCount;
        repeat
            reservedWordIndex := (reservedWordLow + reservedWordHigh) div 2;
            if lexState.currentIdentifier <= reservedWords[reservedWordIndex] then
                reservedWordHigh := reservedWordIndex - 1;
            if lexState.currentIdentifier >= reservedWords[reservedWordIndex] then
                reservedWordLow := reservedWordIndex + 1
        until reservedWordLow > reservedWordHigh;
        if reservedWordLow - 1 > reservedWordHigh then
            lexState.currentToken := reservedWordTokens[reservedWordIndex]
        else
            lexState.currentToken := ident
    end
    else
    if lexState.currentChar in ['0'..'9'] then
    begin
        digitCount := 0;
        lexState.currentNumber := 0;
        lexState.currentToken := number;
        repeat
            lexState.currentNumber := 10 * lexState.currentNumber +
                                      (ord(lexState.currentChar) - ord('0'));
            digitCount := digitCount + 1;
            readNextChar
        until not (lexState.currentChar in ['0'..'9']);
        if digitCount > numberMaxDigits then
            reportCompilerError(ERR_NUMBER_TOO_LARGE, lexerCurrentSourceContext, errorCount)
    end
    else
        case lexState.currentChar of
            '+':
                begin
                    lexState.currentToken := plus;
                    readNextChar
                end;
            '-':
                begin
                    lexState.currentToken := minus;
                    readNextChar
                end;
            '*':
                begin
                    lexState.currentToken := times;
                    readNextChar
                end;
            '/':
                begin
                    lexState.currentToken := slash;
                    readNextChar
                end;
            '(':
                begin
                    lexState.currentToken := lparen;
                    readNextChar
                end;
            ')':
                begin
                    lexState.currentToken := rparen;
                    readNextChar
                end;
            '=':
                begin
                    lexState.currentToken := eql;
                    readNextChar
                end;
            ',':
                begin
                    lexState.currentToken := comma;
                    readNextChar
                end;
            '.':
                begin
                    lexState.currentToken := period;
                    readNextChar
                end;
            ';':
                begin
                    lexState.currentToken := semicolon;
                    readNextChar
                end;
            ':':
                begin
                    readNextChar;
                    if lexState.currentChar = '=' then
                    begin
                        lexState.currentToken := becomes;
                        readNextChar
                    end
                    else
                        lexState.currentToken := colon;
                end;
            '<':
                begin
                    readNextChar;
                    if lexState.currentChar = '=' then
                    begin
                        lexState.currentToken := leq;
                        readNextChar
                    end
                    else if lexState.currentChar = '>' then
                    begin
                        lexState.currentToken := neq;
                        readNextChar
                    end
                    else
                        lexState.currentToken := lss;
                end;
            '>':
                begin
                    readNextChar;
                    if lexState.currentChar = '=' then
                    begin
                        lexState.currentToken := geq;
                        readNextChar
                    end
                    else
                        lexState.currentToken := gtr;
                end
            else
                begin
                    lexState.currentToken := nul;
                    readNextChar
                end
        end;
    traceToken
end {readNextToken} ;

procedure initializeLexer(const inputFileName: string; var errorCount: integer);
begin
    lexState.sourceFileName := inputFileName;
    Assign(lexState.sourceFile, lexState.sourceFileName);
    Reset(lexState.sourceFile);

    reservedWords[ 1] := 'begin     ';
    reservedWords[ 2] := 'boolean   ';
    reservedWords[ 3] := 'call      ';
    reservedWords[ 4] := 'const     ';
    reservedWords[ 5] := 'do        ';
    reservedWords[ 6] := 'end       ';
    reservedWords[ 7] := 'false     ';
    reservedWords[ 8] := 'if        ';
    reservedWords[ 9] := 'integer   ';
    reservedWords[10] := 'procedure ';
    reservedWords[11] := 'then      ';
    reservedWords[12] := 'true      ';
    reservedWords[13] := 'var       ';
    reservedWords[14] := 'while     ';
    reservedWordTokens[ 1] := beginsym;
    reservedWordTokens[ 2] := booleansym;
    reservedWordTokens[ 3] := callsym;
    reservedWordTokens[ 4] := constsym;
    reservedWordTokens[ 5] := dosym;
    reservedWordTokens[ 6] := endsym;
    reservedWordTokens[ 7] := falsesym;
    reservedWordTokens[ 8] := ifsym;
    reservedWordTokens[ 9] := integersym;
    reservedWordTokens[10] := procsym;
    reservedWordTokens[11] := thensym;
    reservedWordTokens[12] := truesym;
    reservedWordTokens[13] := varsym;
    reservedWordTokens[14] := whilesym;
    lexState.charIndex := 0;
    lexState.lineLength := 0;
    lexState.currentLineNumber := 0;
    lexState.currentChar := ' ';
    lexState.identifierBufferLength := maxIdentLength;
    readNextToken(errorCount)
end {initializeLexer} ;

end.
