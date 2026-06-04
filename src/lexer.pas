{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-21

  Lexical analysis for the parser front end.  This unit owns lexer state, source file
  reading, reserved-word recognition, tokenization, and the minimal setup and
  cleanup needed to feed tokens to the parser. }
unit lexer;

{$mode objfpc}

interface

uses
  diagnostics, tokens;

procedure initializeLexer(const inputFileName: string; var errorCount: integer);
procedure cleanupLexer;
procedure readNextToken(var errorCount: integer);
function lexerCurrentToken: symbol;
function lexerCurrentIdentifier: identifier;
function lexerCurrentNumber: integer;
function lexerCurrentCharValue: integer;
function lexerCurrentSourceContext: sourceContext;

implementation

uses
  SysUtils;

const reservedWordCount = 37;
    numberMaxDigits = 14;

type sourceLineBuffer = array [1..81] of char;
    LexerState = record
                   sourceFile: Text;
                   sourceFileName: string;
                   currentChar: char;
                   currentToken: symbol;
                   currentIdentifier: identifier;
                   currentNumber: integer;
                   currentCharValue: integer;
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
    'by        ',
    'case      ',
    'char      ',
    'const     ',
    'continue  ',
    'do        ',
    'else      ',
    'elsif     ',
    'end       ',
    'endfor    ',
    'endif     ',
    'endswitch ',
    'endwhile  ',
    'false     ',
    'for       ',
    'function  ',
    'if        ',
    'integer   ',
    'not       ',
    'on        ',
    'or        ',
    'procedure ',
    'program   ',
    'repeat    ',
    'return    ',
    'switch    ',
    'then      ',
    'to        ',
    'true      ',
    'until     ',
    'var       ',
    'when      ',
    'while     ',
    'xor       '
  );
  reservedWordTokens: array [1..reservedWordCount] of symbol = (
    andsym,
    beginsym,
    booleansym,
    bysym,
    casesym,
    charsym,
    constsym,
    continuesym,
    dosym,
    elsesym,
    elsifsym,
    endsym,
    endforsym,
    endifsym,
    endswitchsym,
    endwhilesym,
    falsesym,
    forsym,
    funcsym,
    ifsym,
    integersym,
    notsym,
    onsym,
    orsym,
    procsym,
    programsym,
    repeatsym,
    returnsym,
    switchsym,
    thensym,
    tosym,
    truesym,
    untilsym,
    varsym,
    whensym,
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

function lexerCurrentCharValue: integer;
begin
    lexerCurrentCharValue := lexState.currentCharValue
end {lexerCurrentCharValue} ;

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
    else if lexState.currentToken = charlit then
        tokenText := IntToStr(lexState.currentCharValue)
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
        literalStartContext: sourceContext;
        literalCharacter: char;

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
    lexState.currentNumber := 0;
    lexState.currentCharValue := 0;
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
    if lexState.currentChar = '''' then
    begin
        literalStartContext := lexerCurrentSourceContext;
        readNextChar;
        if lexState.currentLineNumber <> literalStartContext.line then
        begin
            lexState.currentToken := nul;
            reportCompilerError(ERR_UNTERMINATED_CHARACTER_LITERAL, literalStartContext, errorCount)
        end
        else if lexState.currentChar = '''' then
        begin
            lexState.currentToken := nul;
            reportCompilerError(ERR_EMPTY_CHARACTER_LITERAL, literalStartContext, errorCount);
            readNextChar
        end
        else if lexState.currentChar in [chr(10), chr(13)] then
        begin
            lexState.currentToken := nul;
            reportCompilerError(ERR_UNTERMINATED_CHARACTER_LITERAL, literalStartContext, errorCount)
        end
        else
        begin
            literalCharacter := lexState.currentChar;
            if (ord(literalCharacter) < $20) or (ord(literalCharacter) > $7F) then
                reportCompilerError(ERR_CHARACTER_LITERAL_OUT_OF_RANGE, literalStartContext, errorCount);
            readNextChar;
            if lexState.currentLineNumber <> literalStartContext.line then
            begin
                lexState.currentToken := nul;
                reportCompilerError(ERR_UNTERMINATED_CHARACTER_LITERAL, literalStartContext, errorCount)
            end
            else if lexState.currentChar = '''' then
            begin
                lexState.currentToken := charlit;
                lexState.currentCharValue := ord(literalCharacter);
                readNextChar
            end
            else if lexState.currentChar in [chr(10), chr(13)] then
            begin
                lexState.currentToken := nul;
                reportCompilerError(ERR_UNTERMINATED_CHARACTER_LITERAL, literalStartContext, errorCount)
            end
            else
            begin
                lexState.currentToken := nul;
                reportCompilerError(ERR_CHARACTER_LITERAL_MUST_CONTAIN_EXACTLY_ONE_CHARACTER,
                                    literalStartContext, errorCount);
                while not (lexState.currentChar in ['''', chr(10), chr(13)]) do
                    readNextChar;
                if lexState.currentChar = '''' then
                    readNextChar
            end
        end
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
    lexState.charIndex := 0;
    lexState.lineLength := 0;
    lexState.currentLineNumber := 0;
    lexState.currentChar := ' ';
    lexState.currentNumber := 0;
    lexState.currentCharValue := 0;
    lexState.identifierBufferLength := maxIdentLength;
    readNextToken(errorCount)
end {initializeLexer} ;

end.
