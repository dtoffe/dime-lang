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

const reservedWordCount = 21;
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
    'and       ',
    'begin     ',
    'boolean   ',
    'call      ',
    'const     ',
    'do        ',
    'else      ',
    'end       ',
    'endif     ',
    'endwhile  ',
    'false     ',
    'if        ',
    'integer   ',
    'not       ',
    'or        ',
    'procedure ',
    'then      ',
    'true      ',
    'var       ',
    'while     ',
    'xor       '
  );
  reservedWordTokens: array [1..reservedWordCount] of symbol = (
    andsym,
    beginsym,
    booleansym,
    callsym,
    constsym,
    dosym,
    elsesym,
    endsym,
    endifsym,
    endwhilesym,
    falsesym,
    ifsym,
    integersym,
    notsym,
    orsym,
    procsym,
    thensym,
    truesym,
    varsym,
    whilesym,
    xorsym
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

    reservedWords[ 1] := 'and       ';
    reservedWords[ 2] := 'begin     ';
    reservedWords[ 3] := 'boolean   ';
    reservedWords[ 4] := 'call      ';
    reservedWords[ 5] := 'const     ';
    reservedWords[ 6] := 'do        ';
    reservedWords[ 7] := 'else      ';
    reservedWords[ 8] := 'end       ';
    reservedWords[ 9] := 'endif     ';
    reservedWords[10] := 'endwhile  ';
    reservedWords[11] := 'false     ';
    reservedWords[12] := 'if        ';
    reservedWords[13] := 'integer   ';
    reservedWords[14] := 'not       ';
    reservedWords[15] := 'or        ';
    reservedWords[16] := 'procedure ';
    reservedWords[17] := 'then      ';
    reservedWords[18] := 'true      ';
    reservedWords[19] := 'var       ';
    reservedWords[20] := 'while     ';
    reservedWords[21] := 'xor       ';
    reservedWordTokens[ 1] := andsym;
    reservedWordTokens[ 2] := beginsym;
    reservedWordTokens[ 3] := booleansym;
    reservedWordTokens[ 4] := callsym;
    reservedWordTokens[ 5] := constsym;
    reservedWordTokens[ 6] := dosym;
    reservedWordTokens[ 7] := elsesym;
    reservedWordTokens[ 8] := endsym;
    reservedWordTokens[ 9] := endifsym;
    reservedWordTokens[10] := endwhilesym;
    reservedWordTokens[11] := falsesym;
    reservedWordTokens[12] := ifsym;
    reservedWordTokens[13] := integersym;
    reservedWordTokens[14] := notsym;
    reservedWordTokens[15] := orsym;
    reservedWordTokens[16] := procsym;
    reservedWordTokens[17] := thensym;
    reservedWordTokens[18] := truesym;
    reservedWordTokens[19] := varsym;
    reservedWordTokens[20] := whilesym;
    reservedWordTokens[21] := xorsym;
    lexState.charIndex := 0;
    lexState.lineLength := 0;
    lexState.currentLineNumber := 0;
    lexState.currentChar := ' ';
    lexState.identifierBufferLength := maxIdentLength;
    readNextToken(errorCount)
end {initializeLexer} ;

end.
