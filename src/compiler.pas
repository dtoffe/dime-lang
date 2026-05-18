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

program compiler;
{PL/0 compiler with code generation}

uses
  SysUtils;

const reservedWordCount = 11;    {no. of reserved words}
    symbolTableMax = 100;        {length of identifier table}
    numberMaxDigits = 14;        {max. no. of digits in numbers}
    identifierLength = 10;       {length of identifiers}
    maxAddress = 2047;           {maximum address}
    maxNestingLevel = 3;         {maximum depth of block nesting}
    codeMaxIndex = 200;          {maximum code array index}

type tokenKind =
        (nul, ident, number, plus, minus, times, slash, oddsym,
        eql, neq, lss, leq, gtr, geq, lparen, rparen, comma, semicolon,
        period, becomes, beginsym, endsym, ifsym, thensym,
        whilesym, dosym, callsym, constsym, varsym, procsym);
    identifierText = packed array [1 .. identifierLength] of char;
    declarationKind = (constant, variable, proc);
    tokenSet = set of tokenKind;
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
    currentToken: tokenKind;  {current token produced by the lexer}
    currentIdentifier: identifierText; {identifier text for currentToken = ident}
    currentNumber: integer;   {numeric value for currentToken = number}
    charIndex: integer;       {1-based cursor into sourceLine}
    lineLength: integer;      {number of valid characters in sourceLine}
    identifierBufferLength, errorCount: integer;
    codeIndex: integer;       {index of the next instruction to emit}
    sourceLine: array [1..81] of char; {current source line plus trailing newline}
    identifierBuffer: identifierText;  {scratch buffer used while reading identifiers}
    pCode: array [0..codeMaxIndex] of pCodeInstruction; {generated program image}
    reservedWords: array [1..reservedWordCount] of identifierText; {sorted for binary search}
    reservedWordTokens: array [1..reservedWordCount] of tokenKind; {token for each reserved word}
    opcodeMnemonics: array [opcode] of
                packed array [1 .. 5] of char; {fixed-width listing/output text}
    declarationStartTokens, statementStartTokens, factorStartTokens: tokenSet;
    symbolTable: array [0..symbolTableMax] of
              record identifier: identifierText; {sentinel slot 0 is used by findSymbol}
                case declarationType: declarationKind of
                  constant: (constantValue: integer);
                  variable, proc: (declarationLevel, address: integer)
                  {for variables, address is the stack slot; for procedures, the entry point}
              end ;

    sourceFile, pCodeFile: Text;
    sourceFileName, pCodeFileName: string;
    outputInstructionIndex: integer; {used when flushing generated code to disk}

{Closes the open compiler files and terminates the process.}
procedure closeFilesAndHalt;
begin
    writeln;
    close(sourceFile);
    close(pCodeFile);
    halt
end {closeFilesAndHalt} ;

{Reports a compiler diagnostic and increments the global error count.}
procedure reportError (errorCode: integer);
begin
    writeln (' ****', ' ': charIndex - 1, '^', errorCode:2);
    errorCount := errorCount + 1;
    case errorCode of
         1: writeln (' Use = instead of :=.');
         2: writeln (' = must be followed by a number.');
         3: writeln (' Identifier must be followed by =.');
         4: writeln (' "const", "var", "procedure" must be followed by an identifier. Possible reserved-word case error.');
         5: writeln (' Semicolon or comma missing.');
         6: writeln (' Incorrect symbol after procedure declaration.');
         7: writeln (' Statement expected.');
         8: writeln (' Incorrect symbol after statement part in block.');
         9: writeln (' Period expected.');
        10: writeln (' Semicolon between statements is missing.');
        11: writeln (' Undeclared identifier.');
        12: writeln (' Assignment to constant or procedure is not allowed.');
        13: writeln (' Assignment operator := expected.');
        14: writeln (' "call" must be followed by an identifier. Possible reserved-word case error.');
        15: writeln (' Call of a constant or a variable is meaningless.');
        16: writeln (' "then" expected. Possible reserved-word case error.');
        17: writeln (' Semicolon or "end" expected. Possible reserved-word case error.');
        18: writeln (' "do" expected. Possible reserved-word case error.');
        19: writeln (' Incorrect symbol following statement.');
        20: writeln (' Relational operator expected.');
        21: writeln (' Expression must not contain a procedure identifier.');
        22: writeln (' Right parenthesis missing.');
        23: writeln (' The preceding compileFactor cannot be followed by this symbol.');
        24: writeln (' An expression cannot begin with this symbol.');
        30: writeln (' This number is too large.');
        //31: writeln (' .'); // Not included in code or error messages
        32: writeln (' Only three levels of nesting are supported.')
    end;
end {reportError} ;

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
                write(' PROGRAM INCOMPLETE');
                closeFilesAndHalt()
            end ;
            lineLength := 0;
            charIndex := 0;
            write(codeIndex:5, ' ');
            while not eoln(sourceFile) do
            begin
                lineLength := lineLength + 1;
                read(sourceFile, currentChar);
                sourceLine[lineLength] := currentChar
            end ;
            writeln;
            lineLength := lineLength + 1;
            read(sourceFile, sourceLine[lineLength])
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
            if identifierCharCount < identifierLength then
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
            reportError (30)
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
    {Echo the lexer stream to stdout for trace/debug output.}
    write(currentToken, ' ');
    if currentToken = ident then
        writeln(currentIdentifier)
    else if currentToken = number then
        writeln(currentNumber)
    else
        writeln
end {readNextToken} ;

{Appends one p-code instruction to the generated instruction array.}
procedure emitInstruction(instructionOpcode: opcode; instructionLevel, instructionArgument: integer);
begin
    if codeIndex > codeMaxIndex then
    begin
        write(' PROGRAM TOO LONG');
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
procedure recoverIfUnexpectedToken (allowedTokens, recoveryTokens: tokenSet; errorCode: integer);
begin
    if not (currentToken in allowedTokens) then
    begin
        reportError(errorCode);
        allowedTokens := allowedTokens + recoveryTokens;
        while not (currentToken in allowedTokens) do
            readNextToken
    end
end {recoverIfUnexpectedToken} ;

{Compiles a PL/0 block, including declarations, nested procedures, and its body.}
procedure compileBlock (currentLevel, tableIndex: integer; followTokens: tokenSet);
    var dataAllocationIndex,     {next local-variable slot; slots 0..2 are the activation record header}
        savedTableIndex,         {symbol table size on entry so locals can shadow outer names}
        blockCodeStart: integer; {first emitted instruction that belongs to this block body}

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
                            reportError (30);
                            currentNumber := 0
                        end ;
                        constantValue := currentNumber
                    end ;
                variable:
                    begin
                        declarationLevel := currentLevel;
                        address := dataAllocationIndex;
                        dataAllocationIndex := dataAllocationIndex + 1;
                    end ;
                proc:
                    declarationLevel := currentLevel
            end
        end
    end {enterDeclaration} ;

    {Finds an identifier in the active symbol table, returning zero when absent.}
    function findSymbol(identifierToFind: identifierText): integer;
        var searchIndex: integer;
    begin {find identifier id in table}
        symbolTable[0].identifier := identifierToFind;
        searchIndex := tableIndex;
        while symbolTable[searchIndex].identifier <> identifierToFind do
            searchIndex := searchIndex - 1;
        findSymbol := searchIndex
    end { findSymbol} ;

    {Parses one constant declaration and records it in the symbol table.}
    procedure parseConstantDeclaration;
    begin
        if currentToken = ident then
        begin
            readNextToken;
            if currentToken in [eql, becomes] then
            begin
                if currentToken = becomes then
                    reportError(1);
                readNextToken;
                if currentToken = number then
                begin
                    enterDeclaration(constant);
                    readNextToken
                end
                else
                    reportError (2)
            end
            else
                reportError (3)
        end
        else
            reportError (4)
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
            reportError (4)
    end {parseVariableDeclaration} ;

    {Writes the p-code instructions generated for the current block.}
    procedure listGeneratedCode;
        var instructionIndex: integer;
    begin {list code generated for this block}
        for instructionIndex := blockCodeStart to codeIndex-1 do
            with pCode[instructionIndex] do
                writeln(instructionIndex, opcodeMnemonics[operation]:5, lexicalLevel:3, argument:5);
    end {listGeneratedCode} ;

    {Compiles one statement and emits the p-code needed to execute it.}
    procedure compileStatement (followTokens: tokenSet);
        var symbolIndex, conditionalJumpIndex, loopExitJumpIndex: integer;

        {Compiles an expression, including leading signs and additive operators.}
        procedure compileExpression(followTokens: tokenSet);
            var additiveOperator: tokenKind;

            {Compiles a term and emits multiplication or division operations.}
            procedure compileTerm(followTokens: tokenSet);
                var multiplicativeOperator: tokenKind;

                {Compiles a factor such as an identifier, number, or parenthesized expression.}
                procedure compileFactor (followTokens: tokenSet);
                    var symbolIndex: integer;
                begin
                    recoverIfUnexpectedToken(factorStartTokens, followTokens, 24);
                    while currentToken in factorStartTokens do
                    begin
                        if currentToken = ident then
                        begin symbolIndex := findSymbol(currentIdentifier);
                            if symbolIndex = 0 then
                                reportError (11)
                            else
                                with symbolTable[symbolIndex] do
                                case declarationType of
                                    constant: emitInstruction(lit, 0, constantValue);
                                    variable: emitInstruction(lod, currentLevel - declarationLevel, address);
                                    proc: reportError (21)
                                end ;
                                readNextToken
                        end
                        else
                            if currentToken = number then
                            begin
                                if currentNumber > maxAddress then
                                begin
                                    reportError (30);
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
                                        reportError (22)
                                end ;
                        recoverIfUnexpectedToken (followTokens, [lparen], 23)
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
        procedure compileCondition(followTokens: tokenSet);
            var relationalOperator: tokenKind;
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
                    reportError (20)
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
                reportError (11)
            else
                if symbolTable[symbolIndex].declarationType <> variable then
                begin {assignment to non-variable}
                    reportError (12);
                    symbolIndex := 0
                end ;
            readNextToken;
            if currentToken = becomes then
                readNextToken
            else
                reportError (13);
            compileExpression(followTokens);
            if symbolIndex <> 0 then
                with symbolTable[symbolIndex] do
                    emitInstruction(sto, currentLevel - declarationLevel, address)
        end
        else
            if currentToken = callsym then
            begin
                readNextToken;
                if currentToken <> ident then
                    reportError (14)
                else
                begin
                    symbolIndex := findSymbol(currentIdentifier);
                    if symbolIndex = 0 then
                        reportError (11)
                    else
                        with symbolTable[symbolIndex] do
                            if declarationType = proc then
                                emitInstruction (cal, currentLevel-declarationLevel, address)
                            else
                                reportError (15);
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
                        reportError (16);
                    conditionalJumpIndex := codeIndex;
                    emitInstruction(jpc,0,0);
                    compileStatement(followTokens);
                    pCode[conditionalJumpIndex].argument := codeIndex
                end
                else
                    if currentToken = beginsym then
                    begin
                        readNextToken;
                        compileStatement([semicolon, endsym]+followTokens);
                        while currentToken in [semicolon]+statementStartTokens do
                        begin
                            if currentToken = semicolon then
                                readNextToken
                            else
                                reportError (10);
                            compileStatement([semicolon, endsym]+followTokens)
                        end ;
                        if currentToken = endsym then
                            readNextToken
                        else
                            reportError (17)
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
                                reportError (18);
                            compileStatement(followTokens);
                            emitInstruction(jmp, 0, conditionalJumpIndex);
                            pCode[loopExitJumpIndex].argument := codeIndex
                        end ;
        recoverIfUnexpectedToken(followTokens, [ ], 19)
     end {compileStatement} ;

begin {compileBlock}
    dataAllocationIndex := 3; {reserve static link, dynamic link, and return address}
    savedTableIndex := tableIndex;
    symbolTable[tableIndex].address := codeIndex;
    emitInstruction(jmp,0,0); {skip nested procedure bodies until the block is entered}
    if currentLevel > maxNestingLevel then
        reportError (32);
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
                    reportError (5)
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
                    reportError (5)
            until currentToken <> ident;
        end ;
        while currentToken = procsym do
        begin
            readNextToken;
            if currentToken = ident then
            begin
                enterDeclaration(proc);
                readNextToken
            end
            else
                reportError (4);
            if currentToken = semicolon then
                readNextToken
            else
                reportError (5);
            compileBlock(currentLevel+1, tableIndex, [semicolon]+followTokens);
            if currentToken = semicolon then
            begin
                readNextToken;
                recoverIfUnexpectedToken(statementStartTokens+[ident, procsym], followTokens, 6)
            end
            else
                reportError (5)
        end ;
        recoverIfUnexpectedToken(statementStartTokens+[ident], declarationStartTokens, 7)
    until not(currentToken in declarationStartTokens);
    pCode[symbolTable[savedTableIndex].address].argument := codeIndex;
    with symbolTable[savedTableIndex] do
    begin
        address := codeIndex; {entry point of this block after declarations}
    end ;
    blockCodeStart := codeIndex;
    emitInstruction(int, 0, dataAllocationIndex);
    compileStatement([semicolon, endsym]+followTokens);
    emitInstruction(opr, 0, 0); {return}
    recoverIfUnexpectedToken(followTokens, [ ], 8);
    listGeneratedCode;
end {compileBlock} ;

begin {main program}
    sourceFileName := ParamStr(1);
    Assign(sourceFile, sourceFileName);
    Reset(sourceFile);

    pCodeFileName := ChangeFileExt(sourceFileName, '.pcode');
    Assign(pCodeFile, pCodeFileName);
    Rewrite(pCodeFile);
    
    writeln('Processing file: ', sourceFileName);
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
    identifierBufferLength := identifierLength;
    readNextToken;
    compileBlock(0, 0, [period]+declarationStartTokens+statementStartTokens);
    if currentToken <> period then
        reportError (9);
    if errorCount = 0 then
    begin
        write(' PL/O PROGRAM COMPILED SUCCESSFULLY');
        for outputInstructionIndex := 0 to codeIndex - 1 do
            with pCode[outputInstructionIndex] do
                writeln(pCodeFile, outputInstructionIndex,
                        opcodeMnemonics[operation]:5, lexicalLevel:3, argument:5);
    end
    else
        write(' ERRORS IN PL/O PROGRAM');
    closeFilesAndHalt()
end .

