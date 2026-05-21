{
From the book Algorithms + Data Structures = Programs, by Niklaus Wirth (1976)

Chapter 5, page 337

Program 5.6 PL/O Compiler with Code Generation

OCRed, cleaned, fixed, formatted, converted to modern Free Pascal
and tested by Daniel Toffetti.
Formatted with PTop (https://wiki.freepascal.org/PTop)


NOTE: This is a modified version of the original Program 5.6, changing
the code generation so that the code is emitted directly to a file, and
moving the interpreter to a separate program that reads the p-code from
the file and executes it.
This file contains the compiler.
}

unit compiler;
{PL/0 compiler with code generation}

interface

procedure compileFile(const inputFileName: string);

implementation

uses
  SysUtils, diagnostics, tokens;

const reservedWordCount = 11;    {no. of reserved words}
    symbolTableMax = 100;        {length of identifier table}
    numberMaxDigits = 14;        {max. no. of digits in numbers}
    maxAddress = 2047;           {maximum address}
    maxNestingLevel = 1;         {the language has only global and procedure-local lexical scopes}
    codeMaxIndex = 200;          {maximum code array index}

type declarationKind = (constant, variable, proc);
    opcode = (lit, opr, lod, sto, cal, int, jmp, jpc); {functions}
    pCodeInstruction = packed record
                    operation: opcode;                  {virtual machine opcode}
                    lexicalLevel: 0..maxNestingLevel;   {static-link distance}
                    argument: 0..maxAddress;            {opcode-specific operand}
                  end ;
{   LIT 0,a  :  load constant a
    OPR 0,a  :  execute operation a
    LOD l,a  :  load variable l,a
    STO l,a  :  store variable l,a
    CAL l,a  :  call procedure a at level l
    INT 0,a  :  increment t-register by a
    JMP 0,a  :  jump to a
    JPC 0,a  :  jump conditional to a      }

var currentChar: char;        {current source character}
    currentToken: symbol;  {current token produced by the lexer}
    currentIdentifier: identifier; {identifier text for currentToken = ident}
    currentNumber: integer;   {numeric value for currentToken = number}
    charIndex: integer;       {1-based cursor into sourceLine}
    lineLength: integer;      {number of valid characters in sourceLine}
    identifierBufferLength, errorCount: integer;
    codeIndex: integer;       {index of the next instruction to emit}
    sourceLine: array [1..81] of char; {current source line plus trailing newline}
    identifierBuffer: identifier;  {scratch buffer used while reading identifiers}
    pCode: array [0..codeMaxIndex] of pCodeInstruction; {generated program image}
    reservedWords: array [1..reservedWordCount] of identifier; {sorted for binary search}
    reservedWordTokens: array [1..reservedWordCount] of symbol; {token for each reserved word}
    opcodeMnemonics: array [opcode] of
                packed array [1 .. 5] of char; {fixed-width listing/output text}
    declarationStartTokens, statementStartTokens, factorStartTokens: symbolSet;
    symbolTable: array [0..symbolTableMax] of
              record identifier: identifier; {sentinel slot 0 is used by findSymbol}
                case declarationType: declarationKind of
                  constant: (constantValue: integer);
                  variable, proc: (declarationLevel, address: integer)
                  {for variables, address is the stack slot; for procedures, the entry point}
              end ;

    sourceFile, pCodeFile: Text;
    sourceFileName, pCodeFileName: string;
    outputInstructionIndex: integer; {used when flushing generated code to disk}

{Converts a fixed-width identifier buffer into a trimmed string for trace output.}
function identifierToString(const identifier: identifier): string;
    var characterIndex: integer;
begin
    identifierToString := '';
    for characterIndex := Low(identifier) to High(identifier) do
        identifierToString := identifierToString + identifier[characterIndex];
    identifierToString := TrimRight(identifierToString)
end {identifierToString} ;

{Converts an opcode mnemonic array entry into a trimmed string for trace output.}
function opcodeMnemonicToString(instructionOpcode: opcode): string;
    var characterIndex: integer;
begin
    opcodeMnemonicToString := '';
    for characterIndex := 1 to 5 do
        opcodeMnemonicToString := opcodeMnemonicToString + opcodeMnemonics[instructionOpcode][characterIndex];
    opcodeMnemonicToString := TrimRight(opcodeMnemonicToString)
end {opcodeMnemonicToString} ;

{Writes the current source line trace entry.}
procedure traceSourceLine;
    var sourceText: string;
        characterIndex: integer;
begin
    sourceText := '';
    for characterIndex := 1 to lineLength - 1 do
        sourceText := sourceText + sourceLine[characterIndex];
    emitDiagnostic(debug, Format('[SRC ] %4d %s', [codeIndex, sourceText]))
end {traceSourceLine} ;

{Writes the current token trace entry.}
procedure traceToken;
    var tokenText: string;
begin
    {Pending lexer extraction cleanup:
     restore human-readable token labels with a symbolToString helper.
     That helper can stay here temporarily, but it will likely belong in the
     lexer or a later shared syntax unit once token ownership is extracted.}
    if currentToken = ident then
        tokenText := identifierToString(currentIdentifier)
    else if currentToken = number then
        tokenText := IntToStr(currentNumber)
    else
        tokenText := '';
    emitDiagnostic(debug, '[LEX ] ' + IntToStr(ord(currentToken)) + ' ' + tokenText)
end {traceToken} ;

{Writes a declaration-related trace entry.}
procedure traceDeclaration(messageText: string);
begin
    emitDiagnostic(debug, '[DECL] ' + messageText)
end {traceDeclaration} ;

{Writes a generated-instruction trace entry.}
procedure traceInstruction(messageText: string);
begin
    emitDiagnostic(debug, '[EMIT] ' + messageText)
end {traceInstruction} ;

{Closes the open compiler files and terminates the process.}
procedure closeFilesAndHalt;
begin
    writeln;
    close(sourceFile);
    close(pCodeFile);
    halt
end {closeFilesAndHalt} ;

{Builds the current source context for diagnostics.
 Only source name and column are filled for now; line and source text will
 move in once the lexer owns them directly.}
function currentSourceContext: sourceContext;
begin
    currentSourceContext := makeSourceContext(sourceFileName, charIndex)
end {currentSourceContext} ;

{Reads the next lexical token from the source file into the current token state.}
procedure readNextToken;
    var reservedWordLow, reservedWordHigh, reservedWordIndex: integer;
        identifierCharCount, digitCount: integer;

    {Reads the next source character, reloading sourceLine when the cursor reaches its end.}
    procedure readNextChar;
    begin
        if charIndex = lineLength then
        begin
            if eof(sourceFile) then
            begin
                emitDiagnostic(error, STATUS_PROGRAM_INCOMPLETE);
                closeFilesAndHalt()
            end ;
            lineLength := 0;
            charIndex := 0;
            while not eoln(sourceFile) do
            begin
                lineLength := lineLength + 1;
                read(sourceFile, currentChar);
                sourceLine[lineLength] := currentChar
            end ;
            lineLength := lineLength + 1;
            read(sourceFile, sourceLine[lineLength]);
            traceSourceLine
        end ;
        charIndex := charIndex + 1;
        currentChar := sourceLine[charIndex]
     end {readNextChar} ;

begin {readNextToken}
    while (currentChar = ' ') or (currentChar = chr(10)) or (currentChar = chr(13)) do
        readNextChar;
    if currentChar in ['A'..'Z', 'a'..'z'] then
    begin {identifier or reserved word}
        identifierCharCount := 0;
        repeat
            if identifierCharCount < maxIdentLength then
            begin
                identifierCharCount := identifierCharCount + 1;
                identifierBuffer[identifierCharCount] := currentChar
            end ;
            readNextChar
        until not (currentChar in ['A'..'Z', 'a'..'z', '0'..'9']);
        if identifierCharCount >= identifierBufferLength then
            identifierBufferLength := identifierCharCount
        else
            repeat
                identifierBuffer[identifierBufferLength] := ' ';
                identifierBufferLength := identifierBufferLength - 1
            until identifierBufferLength = identifierCharCount;
        currentIdentifier := identifierBuffer;
        reservedWordLow := 1;
        reservedWordHigh := reservedWordCount;
        repeat
            reservedWordIndex := (reservedWordLow + reservedWordHigh) div 2;
            if currentIdentifier <= reservedWords[reservedWordIndex] then
                reservedWordHigh := reservedWordIndex - 1;
            if currentIdentifier >= reservedWords[reservedWordIndex] then
                reservedWordLow := reservedWordIndex + 1
        until reservedWordLow > reservedWordHigh;
        if reservedWordLow-1 > reservedWordHigh then
            currentToken := reservedWordTokens[reservedWordIndex]
        else
            currentToken := ident
    end
    else
    if currentChar in ['0'..'9'] then
    begin {number}
        digitCount := 0;
        currentNumber := 0;
        currentToken := number;
        repeat
            currentNumber := 10 * currentNumber + (ord(currentChar) - ord('0'));
            digitCount := digitCount + 1;
            readNextChar
        until not (currentChar in ['0'..'9']);
        if digitCount > numberMaxDigits then
            reportCompilerError(ERR_NUMBER_TOO_LARGE, currentSourceContext, errorCount)
    end
    else
        case currentChar of
            '+':
                begin
                    currentToken := plus;
                    readNextChar
                end;
            '-':
                begin
                    currentToken := minus;
                    readNextChar
                end;
            '*':
                begin
                    currentToken := times;
                    readNextChar
                end;
            '/':
                begin
                    currentToken := slash;
                    readNextChar
                end;
            '(':
                begin
                    currentToken := lparen;
                    readNextChar
                end;
            ')':
                begin
                    currentToken := rparen;
                    readNextChar
                end;
            '=':
                begin
                    currentToken := eql;
                    readNextChar
                end;
            ',':
                begin
                    currentToken := comma;
                    readNextChar
                end;
            '.':
                begin
                    currentToken := period;
                    readNextChar
                end;
            ';':
                begin
                    currentToken := semicolon;
                    readNextChar
                end;
            ':':
                begin
                    readNextChar;
                    if currentChar = '=' then
                    begin
                        currentToken := becomes;
                        readNextChar
                    end
                    else
                        currentToken := nul;
                end;
            '<':
                begin
                    readNextChar;
                    if currentChar = '=' then
                    begin
                        currentToken := leq;
                        readNextChar
                    end
                    else if currentChar = '>' then
                    begin
                        currentToken := neq;
                        readNextChar
                    end
                    else
                        currentToken := lss;
                end;
            '>':
                begin
                    readNextChar;
                    if currentChar = '=' then
                    begin
                        currentToken := geq;
                        readNextChar
                    end
                    else
                        currentToken := gtr;
                end
            else
                begin
                    currentToken := nul;
                    readNextChar
                end
        end;
    traceToken
end {readNextToken} ;

{Appends one p-code instruction to the generated instruction array.}
procedure emitInstruction(instructionOpcode: opcode; instructionLevel, instructionArgument: integer);
begin
    if codeIndex > codeMaxIndex then
    begin
        emitDiagnostic(error, STATUS_PROGRAM_TOO_LONG);
        closeFilesAndHalt()
    end ;
    with pCode[codeIndex] do
    begin
        operation := instructionOpcode;
        lexicalLevel := instructionLevel;
        argument := instructionArgument
    end ;
    codeIndex := codeIndex + 1
end {emitInstruction} ;

{Reports an unexpected token and skips input until parsing can safely resume.}
procedure recoverIfUnexpectedToken (allowedTokens, recoveryTokens: symbolSet; errorCode: integer);
begin
    if not (currentToken in allowedTokens) then
    begin
        reportCompilerError(errorCode, currentSourceContext, errorCount);
        allowedTokens := allowedTokens + recoveryTokens;
        while not (currentToken in allowedTokens) do
            readNextToken
    end
end {recoverIfUnexpectedToken} ;

{Compiles a PL/0 block with declarations and a statement body.
 Top-level blocks may declare procedures; procedure bodies may not.}
procedure compileBlock (currentLevel, tableIndex: integer; followTokens: symbolSet;
                        allowProcedureDeclarations: boolean);
    var dataAllocationIndex,     {next local-variable slot; slots 0..2 are the activation record header}
        savedTableIndex,         {symbol table size on entry so locals can shadow outer names}
        blockCodeStart: integer; {first emitted instruction that belongs to this block body}
        activeDeclarationStartTokens: symbolSet;

    {Adds the current identifier as a constant, variable, or procedure declaration.}
    procedure enterDeclaration(declarationToEnter: declarationKind);
    begin {enterDeclaration object into table}
        tableIndex := tableIndex + 1;
        with symbolTable[tableIndex] do
        begin
            identifier := currentIdentifier;
            declarationType := declarationToEnter;
            case declarationToEnter of
                constant:
                    begin
                        if currentNumber > maxAddress then
                        begin
                            reportCompilerError(ERR_NUMBER_TOO_LARGE, currentSourceContext, errorCount);
                            currentNumber := 0
                        end ;
                        constantValue := currentNumber;
                        traceDeclaration('const ' + identifierToString(identifier) +
                                         ' = ' + IntToStr(constantValue))
                    end ;
                variable:
                    begin
                        declarationLevel := currentLevel;
                        address := dataAllocationIndex;
                        dataAllocationIndex := dataAllocationIndex + 1;
                        traceDeclaration('var ' + identifierToString(identifier) +
                                         ' level=' + IntToStr(declarationLevel) +
                                         ' addr=' + IntToStr(address))
                    end ;
                proc:
                    begin
                        declarationLevel := currentLevel;
                        traceDeclaration('procedure ' + identifierToString(identifier) +
                                         ' level=' + IntToStr(declarationLevel))
                    end
            end
        end
    end {enterDeclaration} ;

    {Finds an identifier in the active symbol table, returning zero when absent.}
    function findSymbol(identifierToFind: identifier): integer;
        var searchIndex: integer;
    begin {find identifier id in table}
        symbolTable[0].identifier := identifierToFind;
        searchIndex := tableIndex;
        while symbolTable[searchIndex].identifier <> identifierToFind do
            searchIndex := searchIndex - 1;
        findSymbol := searchIndex
    end { findSymbol} ;

    {Returns the outward lexical distance for a resolved symbol reference.
     The language now allows only two scopes: global (0) and procedure-local (1).}
    function lexicalLevelDistance(targetDeclarationLevel: integer): integer;
    begin
        lexicalLevelDistance := currentLevel - targetDeclarationLevel;
        if (lexicalLevelDistance < 0) or (lexicalLevelDistance > 1) then
        begin
            reportCompilerError(ERR_PROCEDURES_GLOBAL_SCOPE_ONLY, currentSourceContext, errorCount);
            lexicalLevelDistance := 0
        end
    end {lexicalLevelDistance} ;

    {Parses one constant declaration and records it in the symbol table.}
    procedure parseConstantDeclaration;
    begin
        if currentToken = ident then
        begin
            readNextToken;
            if currentToken in [eql, becomes] then
            begin
                if currentToken = becomes then
                    reportCompilerError(ERR_USE_EQUAL_NOT_BECOMES, currentSourceContext, errorCount);
                readNextToken;
                if currentToken = number then
                begin
                    enterDeclaration(constant);
                    readNextToken
                end
                else
                    reportCompilerError(ERR_NUMBER_EXPECTED_AFTER_EQUAL, currentSourceContext, errorCount)
            end
            else
                reportCompilerError(ERR_IDENTIFIER_MUST_BE_FOLLOWED_BY_EQUAL, currentSourceContext, errorCount)
        end
        else
            reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, currentSourceContext, errorCount)
    end {parseConstantDeclaration} ;

    {Parses one variable declaration and records its stack address.}
    procedure parseVariableDeclaration;
    begin
        if currentToken = ident then
        begin
            enterDeclaration (variable);
            readNextToken
        end
        else
            reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, currentSourceContext, errorCount)
    end {parseVariableDeclaration} ;

    {Writes the p-code instructions generated for the current block.}
    procedure listGeneratedCode;
        var instructionIndex: integer;
    begin {list code generated for this block}
        for instructionIndex := blockCodeStart to codeIndex-1 do
            with pCode[instructionIndex] do
                traceInstruction(Format('%4d %-5s %3d %5d',
                                        [instructionIndex,
                                         opcodeMnemonicToString(operation),
                                         lexicalLevel,
                                         argument]));
    end {listGeneratedCode} ;

    {Compiles one statement and emits the p-code needed to execute it.}
    procedure compileStatement (followTokens: symbolSet);
        var symbolIndex, conditionalJumpIndex, loopExitJumpIndex: integer;

        {Compiles an expression, including leading signs and additive operators.}
        procedure compileExpression(followTokens: symbolSet);
            var additiveOperator: symbol;

            {Compiles a term and emits multiplication or division operations.}
            procedure compileTerm(followTokens: symbolSet);
                var multiplicativeOperator: symbol;

                {Compiles a factor such as an identifier, number, or parenthesized expression.}
                procedure compileFactor (followTokens: symbolSet);
                    var symbolIndex: integer;
                begin
                    recoverIfUnexpectedToken(factorStartTokens, followTokens, ERR_INVALID_TOKEN_AT_EXPRESSION_START);
                    while currentToken in factorStartTokens do
                    begin
                        if currentToken = ident then
                        begin symbolIndex := findSymbol(currentIdentifier);
                            if symbolIndex = 0 then
                                reportCompilerError(ERR_UNDECLARED_IDENTIFIER, currentSourceContext, errorCount)
                            else
                                with symbolTable[symbolIndex] do
                                case declarationType of
                                    constant: emitInstruction(lit, 0, constantValue);
                                    variable: emitInstruction(lod, lexicalLevelDistance(declarationLevel), address);
                                    proc: reportCompilerError(ERR_PROCEDURE_IDENTIFIER_IN_EXPRESSION, currentSourceContext, errorCount)
                                end ;
                                readNextToken
                        end
                        else
                            if currentToken = number then
                            begin
                                if currentNumber > maxAddress then
                                begin
                                    reportCompilerError(ERR_NUMBER_TOO_LARGE, currentSourceContext, errorCount);
                                    currentNumber := 0
                                end ;
                                emitInstruction(lit, 0, currentNumber); readNextToken
                            end
                            else
                                if currentToken = lparen then
                                begin
                                    readNextToken;
                                    compileExpression([rparen]+followTokens);
                                    if currentToken = rparen then
                                        readNextToken
                                    else
                                        reportCompilerError(ERR_RIGHT_PARENTHESIS_MISSING, currentSourceContext, errorCount)
                                end ;
                        recoverIfUnexpectedToken (followTokens, [lparen], ERR_INVALID_TOKEN_AFTER_FACTOR)
                    end
                end { compileFactor} ;

            begin {compileTerm}
                compileFactor(followTokens+[times, slash]);
                while currentToken in [times, slash] do
                begin
                    multiplicativeOperator := currentToken;
                    readNextToken;
                    compileFactor(followTokens+[times, slash]);
                    if multiplicativeOperator = times then
                        emitInstruction(opr, 0, 4)
                    else
                        emitInstruction(opr, 0, 5)
                end
            end {compileTerm} ;

        begin {compileExpression}
            if currentToken in [plus, minus] then
            begin
                additiveOperator := currentToken;
                readNextToken;
                compileTerm(followTokens+[plus, minus]);
                if additiveOperator = minus then
                    emitInstruction(opr,0,1)
            end
            else
                compileTerm(followTokens+[plus, minus]);
            while currentToken in [plus, minus] do
            begin
                additiveOperator := currentToken;
                readNextToken;
                compileTerm(followTokens+[plus, minus]);
                if additiveOperator = plus then
                    emitInstruction(opr,0,2)
                else
                    emitInstruction(opr,0,3)
            end
        end {compileExpression} ;

        {Compiles a boolean condition and emits the comparison operation.}
        procedure compileCondition(followTokens: symbolSet);
            var relationalOperator: symbol;
        begin
            if currentToken = oddsym then
            begin
                readNextToken;
                compileExpression(followTokens);
                emitInstruction(opr,0,6)
            end
            else
            begin
                compileExpression([eql, neq, lss, gtr, leq, geq]+followTokens);
                if not (currentToken in [eql, neq, lss, leq, gtr, geq]) then
                    reportCompilerError(ERR_RELATIONAL_OPERATOR_EXPECTED, currentSourceContext, errorCount)
                else
                begin
                    relationalOperator := currentToken;
                    readNextToken;
                    compileExpression(followTokens);
                    case relationalOperator of
                        eql: emitInstruction(opr,0, 8);
                        neq: emitInstruction(opr,0, 9);
                        lss: emitInstruction(opr,0,10);
                        geq: emitInstruction(opr,0,11);
                        gtr: emitInstruction(opr,0,12);
                        leq: emitInstruction(opr,0,13);
                    end
                end
            end
        end {compileCondition} ;

    begin {compileStatement}
        if currentToken = ident then
        begin
            symbolIndex := findSymbol(currentIdentifier);
            if symbolIndex = 0 then
                reportCompilerError(ERR_UNDECLARED_IDENTIFIER, currentSourceContext, errorCount)
            else
                if symbolTable[symbolIndex].declarationType <> variable then
                begin {assignment to non-variable}
                    reportCompilerError(ERR_ASSIGNMENT_TO_CONSTANT_OR_PROCEDURE, currentSourceContext, errorCount);
                    symbolIndex := 0
                end ;
            readNextToken;
            if currentToken = becomes then
                readNextToken
            else
                reportCompilerError(ERR_ASSIGNMENT_OPERATOR_EXPECTED, currentSourceContext, errorCount);
            compileExpression(followTokens);
            if symbolIndex <> 0 then
                with symbolTable[symbolIndex] do
                    emitInstruction(sto, lexicalLevelDistance(declarationLevel), address)
        end
        else
            if currentToken = callsym then
            begin
                readNextToken;
                if currentToken <> ident then
                    reportCompilerError(ERR_CALL_MUST_BE_FOLLOWED_BY_IDENTIFIER, currentSourceContext, errorCount)
                else
                begin
                    symbolIndex := findSymbol(currentIdentifier);
                    if symbolIndex = 0 then
                        reportCompilerError(ERR_UNDECLARED_IDENTIFIER, currentSourceContext, errorCount)
                    else
                        with symbolTable[symbolIndex] do
                            if declarationType = proc then
                                emitInstruction (cal, lexicalLevelDistance(declarationLevel), address)
                            else
                                reportCompilerError(ERR_CALL_OF_CONSTANT_OR_VARIABLE, currentSourceContext, errorCount);
                    readNextToken
                end
            end
            else
                if currentToken = ifsym then
                begin
                    readNextToken;
                    compileCondition([thensym, dosym]+followTokens);
                    if currentToken = thensym then
                        readNextToken
                    else
                        reportCompilerError(ERR_THEN_EXPECTED, currentSourceContext, errorCount);
                    conditionalJumpIndex := codeIndex;
                    emitInstruction(jpc,0,0);
                    compileStatement(followTokens);
                    pCode[conditionalJumpIndex].argument := codeIndex
                end
                else
                    if currentToken = beginsym then
                    begin
                        readNextToken;
                        recoverIfUnexpectedToken(statementStartTokens+[ident],
                                                 [semicolon, endsym]+followTokens, ERR_STATEMENT_EXPECTED);
                        compileStatement([semicolon, endsym]+followTokens);
                        while currentToken in [semicolon]+statementStartTokens do
                        begin
                            if currentToken = semicolon then
                                readNextToken
                            else
                                reportCompilerError(ERR_MISSING_SEMICOLON_BETWEEN_STATEMENTS, currentSourceContext, errorCount);
                            compileStatement([semicolon, endsym]+followTokens)
                        end ;
                        if currentToken = endsym then
                            readNextToken
                        else
                            reportCompilerError(ERR_SEMICOLON_OR_END_EXPECTED, currentSourceContext, errorCount)
                    end
                    else
                        if currentToken = whilesym then
                        begin
                            conditionalJumpIndex := codeIndex;
                            readNextToken;
                            compileCondition([dosym]+followTokens);
                            loopExitJumpIndex := codeIndex;
                            emitInstruction(jpc,0,0);
                            if currentToken = dosym then
                                readNextToken
                            else
                                reportCompilerError(ERR_DO_EXPECTED, currentSourceContext, errorCount);
                            compileStatement(followTokens);
                            emitInstruction(jmp, 0, conditionalJumpIndex);
                            pCode[loopExitJumpIndex].argument := codeIndex
                        end ;
        recoverIfUnexpectedToken(followTokens, [ ], ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT)
     end {compileStatement} ;

begin {compileBlock}
    dataAllocationIndex := 3; {reserve static link, dynamic link, and return address}
    savedTableIndex := tableIndex;
    activeDeclarationStartTokens := [constsym, varsym];
    if allowProcedureDeclarations then
    begin
        activeDeclarationStartTokens := activeDeclarationStartTokens + [procsym];
        symbolTable[tableIndex].address := codeIndex;
        emitInstruction(jmp,0,0); {skip top-level procedure bodies until the main block is entered}
    end;
    if currentLevel > 1 then
        reportCompilerError(ERR_PROCEDURES_GLOBAL_SCOPE_ONLY, currentSourceContext, errorCount);
    repeat
        if currentToken = constsym then
        begin
            readNextToken;
            repeat
                parseConstantDeclaration;
                while currentToken = comma do
                begin
                    readNextToken;
                    parseConstantDeclaration
                end ;
                if currentToken = semicolon then
                    readNextToken
                else
                    reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, currentSourceContext, errorCount)
            until currentToken <> ident
        end ;
        if currentToken = varsym then
        begin
            readNextToken;
            repeat
                parseVariableDeclaration;
                while currentToken = comma do
                begin
                    readNextToken;
                    parseVariableDeclaration
                end ;
                if currentToken = semicolon then
                    readNextToken
                else
                    reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, currentSourceContext, errorCount)
            until currentToken <> ident;
        end ;
        while allowProcedureDeclarations and (currentToken = procsym) do
        begin
            if currentLevel <> 0 then
            begin
                reportCompilerError(ERR_NESTED_PROCEDURES_NOT_SUPPORTED, currentSourceContext, errorCount);
                readNextToken;
                recoverIfUnexpectedToken([ident], [semicolon] + followTokens +
                                         statementStartTokens + activeDeclarationStartTokens, ERR_DECLARATION_IDENTIFIER_EXPECTED);
                while not (currentToken in [semicolon] + followTokens +
                                        statementStartTokens + activeDeclarationStartTokens) do
                    readNextToken;
                continue
            end;
            readNextToken;
            if currentToken = ident then
            begin
                enterDeclaration(proc);
                readNextToken
            end
            else
                reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, currentSourceContext, errorCount);
            if currentToken = semicolon then
                readNextToken
            else
                reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, currentSourceContext, errorCount);
            compileBlock(currentLevel+1, tableIndex, [semicolon]+followTokens, false);
            if currentToken = semicolon then
            begin
                readNextToken;
                recoverIfUnexpectedToken(statementStartTokens+[ident] +
                                         activeDeclarationStartTokens, followTokens, ERR_INVALID_TOKEN_AFTER_PROCEDURE_DECLARATION)
            end
            else
                reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, currentSourceContext, errorCount)
        end ;
        if (not allowProcedureDeclarations) and (currentToken = procsym) then
        begin
            reportCompilerError(ERR_NESTED_PROCEDURES_NOT_SUPPORTED, currentSourceContext, errorCount);
            readNextToken;
            recoverIfUnexpectedToken([ident], [semicolon] + followTokens +
                                     statementStartTokens + activeDeclarationStartTokens, ERR_DECLARATION_IDENTIFIER_EXPECTED);
            while not (currentToken in [semicolon] + followTokens +
                                    statementStartTokens + activeDeclarationStartTokens) do
                readNextToken;
        end;
        recoverIfUnexpectedToken(statementStartTokens+[ident], activeDeclarationStartTokens, ERR_STATEMENT_EXPECTED)
    until not(currentToken in activeDeclarationStartTokens);
    if allowProcedureDeclarations then
        pCode[symbolTable[savedTableIndex].address].argument := codeIndex;
    with symbolTable[savedTableIndex] do
    begin
        address := codeIndex; {entry point of this block after declarations}
    end ;
    blockCodeStart := codeIndex;
    emitInstruction(int, 0, dataAllocationIndex);
    compileStatement([semicolon, endsym]+followTokens);
    emitInstruction(opr, 0, 0); {return}
    recoverIfUnexpectedToken(followTokens, [ ], ERR_INVALID_TOKEN_AFTER_STATEMENT_PART_IN_BLOCK);
    listGeneratedCode;
end {compileBlock} ;

procedure compileFile(const inputFileName: string);
begin
    sourceFileName := inputFileName;
    Assign(sourceFile, sourceFileName);
    Reset(sourceFile);

    pCodeFileName := ChangeFileExt(sourceFileName, '.pcode');
    Assign(pCodeFile, pCodeFileName);
    Rewrite(pCodeFile);
    
    emitDiagnostic(status, STATUS_COMPILER_PROCESSING_FILE + sourceFileName);
    reservedWords[ 1] := 'begin     ';
    reservedWords[ 2] := 'call      ';
    reservedWords[ 3] := 'const     ';
    reservedWords[ 4] := 'do        ';
    reservedWords[ 5] := 'end       ';
    reservedWords[ 6] := 'if        ';
    reservedWords[ 7] := 'odd       ';
    reservedWords[ 8] := 'procedure ';
    reservedWords[ 9] := 'then      ';
    reservedWords[10] := 'var       ';
    reservedWords[11] := 'while     ';
    reservedWordTokens[ 1] := beginsym;
    reservedWordTokens[ 2] := callsym;
    reservedWordTokens[ 3] := constsym;
    reservedWordTokens[ 4] := dosym;
    reservedWordTokens[ 5] := endsym;
    reservedWordTokens[ 6] := ifsym;
    reservedWordTokens[ 7] := oddsym;
    reservedWordTokens[ 8] := procsym;
    reservedWordTokens[ 9] := thensym;
    reservedWordTokens[10] := varsym;
    reservedWordTokens[11] := whilesym;
    opcodeMnemonics[lit] := 'LIT  ';
    opcodeMnemonics[opr] := 'OPR  ';
    opcodeMnemonics[lod] := 'LOD  ';
    opcodeMnemonics[sto] := 'STO  ';
    opcodeMnemonics[cal] := 'CAL  ';
    opcodeMnemonics[int] := 'INT  ';
    opcodeMnemonics[jmp] := 'JMP  ';
    opcodeMnemonics[jpc] := 'JPC  ';
    declarationStartTokens := [constsym, varsym, procsym];
    statementStartTokens := [beginsym, callsym, ifsym, whilesym];
    factorStartTokens := [ident, number, lparen];
    errorCount := 0;
    charIndex := 0;
    codeIndex := 0;
    lineLength := 0;
    currentChar := ' ';
    identifierBufferLength := maxIdentLength;
    readNextToken;
    compileBlock(0, 0, [period]+declarationStartTokens+statementStartTokens, true);
    if currentToken <> period then
        reportCompilerError(ERR_PERIOD_EXPECTED, currentSourceContext, errorCount);
    if errorCount = 0 then
    begin
        emitDiagnostic(status, STATUS_COMPILER_SUCCESS);
        for outputInstructionIndex := 0 to codeIndex - 1 do
            with pCode[outputInstructionIndex] do
                writeln(pCodeFile, outputInstructionIndex,
                        opcodeMnemonics[operation]:5, lexicalLevel:3, argument:5);
    end
    else
        emitDiagnostic(status, STATUS_COMPILER_ERRORS);
    closeFilesAndHalt()
end {compileFile} ;

end.
