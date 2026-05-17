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

{$modeSwitch nonlocalgoto+}

program compiler {(input,output)};
{PL/0 compiler with code generation}

{label 99;}

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
                    operation: opcode;             {function code}
                    lexicalLevel: 0..maxNestingLevel;    {level}
                    argument: 0..maxAddress;             {displacement address}
                  end ;
{   LIT 0,a  :  load constant a
    OPR 0,a  :  execute operation a
    LOD l,a  :  load variable l,a
    STO l,a  :  store variable l,a
    CAL l,a  :  call procedure a at level l
    INT 0,a  :  increment t-register by a
    JMP 0,a  :  jump to a
    JPC 0,a  :  jump conditional to a      }

var currentChar: char;        {last character read}
    currentToken: tokenKind;  {last symbol read}
    currentIdentifier: identifierText; {last identifier read}
    currentNumber: integer;   {last number read}
    charIndex: integer;       {character count}
    lineLength: integer;      {line length}
    identifierBufferLength, errorCount: integer;
    codeIndex: integer;       {code allocation index}
    sourceLine: array [1..81] of char;
    identifierBuffer: identifierText;
    pCode: array [0..codeMaxIndex] of pCodeInstruction;
    reservedWords: array [1..reservedWordCount] of identifierText;
    reservedWordTokens: array [1..reservedWordCount] of tokenKind;
    opcodeMnemonics: array [opcode] of
                packed array [1 .. 5] of char;
    declarationStartTokens, statementStartTokens, factorStartTokens: tokenSet;
    symbolTable: array [0..symbolTableMax] of
              record identifier: identifierText;
                case declarationType: declarationKind of
                  constant: (constantValue: integer);
                  variable, proc: (declarationLevel, address: integer)
              end ;

    sourceFile, pCodeFile: Text;
    sourceFileName, pCodeFileName: string;
    outputInstructionIndex: integer;

procedure cleanExit;
begin
    writeln;
    close(sourceFile);
    close(pCodeFile);
    halt
end {cleanExit} ;

procedure error (errorCode: integer);
begin
    writeln (' ****', ' ': charIndex - 1, '↑', errorCode:2);
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
        23: writeln (' The preceding factor cannot be followed by this symbol.');
        24: writeln (' An expression cannot begin with this symbol.');
        30: writeln (' This number is too large.');
        //31: writeln (' .'); // Not included in code or error messages
        32: writeln (' Only three levels of nesting are supported.')
    end;
    // cleanExit() { goto 99 }
end {error} ;

procedure getsym;
    var reservedWordLow, reservedWordHigh, reservedWordIndex: integer;
        identifierCharCount, digitCount: integer;

    procedure getch;
    begin
        if charIndex = lineLength then
        begin
            if eof(sourceFile) then
            begin
                write(' PROGRAM INCOMPLETE');
                cleanExit() { goto 99 }
            end ;
            lineLength := 0;
            charIndex := 0;
            write(codeIndex:5, ' ');
            while not eoln(sourceFile) do
            begin
                lineLength := lineLength + 1;
                read(sourceFile, currentChar);
                //write(currentChar);
                sourceLine[lineLength] := currentChar
            end ;
            writeln;
            lineLength := lineLength + 1;
            read(sourceFile, sourceLine[lineLength])
        end ;
        charIndex := charIndex + 1;
        currentChar := sourceLine[charIndex]
     end {getch} ;

begin {getsym}
    while (currentChar = ' ') or (currentChar = chr(10)) or (currentChar = chr(13)) do
        getch;
    if currentChar in ['A'..'Z', 'a'..'z'] then
    begin {identifier or reserved word}
        identifierCharCount := 0;
        repeat
            if identifierCharCount < identifierLength then
            begin
                identifierCharCount := identifierCharCount + 1;
                identifierBuffer[identifierCharCount] := currentChar
            end ;
            getch
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
            getch
        until not (currentChar in ['0'..'9']);
        if digitCount > numberMaxDigits then
            error (30)
    end
    else
        case currentChar of
            '+':
                begin
                    currentToken := plus;
                    getch
                end;
            '-':
                begin
                    currentToken := minus;
                    getch
                end;
            '*':
                begin
                    currentToken := times;
                    getch
                end;
            '/':
                begin
                    currentToken := slash;
                    getch
                end;
            '(':
                begin
                    currentToken := lparen;
                    getch
                end;
            ')':
                begin
                    currentToken := rparen;
                    getch
                end;
            '=':
                begin
                    currentToken := eql;
                    getch
                end;
            ',':
                begin
                    currentToken := comma;
                    getch
                end;
            '.':
                begin
                    currentToken := period;
                    getch
                end;
            ';':
                begin
                    currentToken := semicolon;
                    getch
                end;
            ':':
                begin
                    getch;
                    if currentChar = '=' then
                    begin
                        currentToken := becomes;
                        getch
                    end
                    else
                        currentToken := nul;
                end;
            '<':
                begin
                    getch;
                    if currentChar = '=' then
                    begin
                        currentToken := leq;
                        getch
                    end
                    else if currentChar = '>' then
                    begin
                        currentToken := neq;
                        getch
                    end
                    else
                        currentToken := lss;
                end;
            '>':
                begin
                    getch;
                    if currentChar = '=' then
                    begin
                        currentToken := geq;
                        getch
                    end
                    else
                        currentToken := gtr;
                end
            else
                begin
                    currentToken := nul;
                    getch
                end
        end;
    // Following output is added for debugging
    write(currentToken, ' ');
    if currentToken = ident then
        writeln(currentIdentifier)
    else if currentToken = number then
        writeln(currentNumber)
    else
        writeln
end {getsym} ;

procedure gen(instructionOpcode: opcode; instructionLevel, instructionArgument: integer);
begin
    if codeIndex > codeMaxIndex then
    begin
        write(' PROGRAM TOO LONG');
        {goto 99}
        cleanExit()
    end ;
    with pCode[codeIndex] do
    begin
        operation := instructionOpcode;
        lexicalLevel := instructionLevel;
        argument := instructionArgument
    end ;
    codeIndex := codeIndex + 1
end {gen} ;

procedure test (allowedTokens, recoveryTokens: tokenSet; errorCode: integer);
begin
    if not (currentToken in allowedTokens) then
    begin
        error(errorCode);
        allowedTokens := allowedTokens + recoveryTokens;
        while not (currentToken in allowedTokens) do
            getsym
    end
end {test} ;

procedure block (currentLevel, tableIndex: integer; followTokens: tokenSet);
    var dataAllocationIndex,     {data allocation index}
        savedTableIndex,         {initial table index}
        blockCodeStart: integer; {initial code index}

    procedure enter(declarationToEnter: declarationKind);
    begin {enter object into table}
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
                            error (30);
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
    end {enter} ;

    function position(identifierToFind: identifierText): integer;
        var searchIndex: integer;
    begin {find indentifier id in table}
        symbolTable[0].identifier := identifierToFind;
        searchIndex := tableIndex;
        while symbolTable[searchIndex].identifier <> identifierToFind do
            searchIndex := searchIndex - 1;
        position := searchIndex
    end { position} ;

    procedure constdeclaration;
    begin
        if currentToken = ident then
        begin
            getsym;
            if currentToken in [eql, becomes] then
            begin
                if currentToken = becomes then
                    error(1);
                getsym;
                if currentToken = number then
                begin
                    enter(constant);
                    getsym
                end
                else
                    error (2)
            end
            else
                error (3)
        end
        else
            error (4)
    end {constdeclaration} ;

    procedure vardeclaration;
    begin
        if currentToken = ident then
        begin
            enter (variable);
            getsym
        end
        else
            error (4)
    end {vardeclaration} ;

    procedure listcode;
        var instructionIndex: integer;
    begin {list code generated for this block}
        for instructionIndex := blockCodeStart to codeIndex-1 do
            with pCode[instructionIndex] do
                writeln(instructionIndex, opcodeMnemonics[operation]:5, lexicalLevel:3, argument:5);
    end {listcode} ;

    procedure statement (followTokens: tokenSet);
        var symbolIndex, conditionalJumpIndex, loopExitJumpIndex: integer;

        procedure expression(followTokens: tokenSet);
            var additiveOperator: tokenKind;

            procedure term(followTokens: tokenSet);
                var multiplicativeOperator: tokenKind;

                procedure factor (followTokens: tokenSet);
                    var symbolIndex: integer;
                begin
                    test(factorStartTokens, followTokens, 24);
                    while currentToken in factorStartTokens do
                    begin
                        if currentToken = ident then
                        begin symbolIndex := position(currentIdentifier);
                            if symbolIndex = 0 then
                                error (11)
                            else
                                with symbolTable[symbolIndex] do
                                case declarationType of
                                    constant: gen(lit, 0, constantValue);
                                    variable: gen(lod, currentLevel - declarationLevel, address);
                                    proc: error (21)
                                end ;
                                getsym
                        end
                        else
                            if currentToken = number then
                            begin
                                if currentNumber > maxAddress then
                                begin
                                    error (30);
                                    currentNumber := 0
                                end ;
                                gen(lit, 0, currentNumber); getsym
                            end
                            else
                                if currentToken = lparen then
                                begin
                                    getsym;
                                    expression([rparen]+followTokens);
                                    if currentToken = rparen then
                                        getsym
                                    else
                                        error (22)
                                end ;
                        test (followTokens, [lparen], 23)
                    end
                end { factor} ;

            begin {term}
                factor(followTokens+[times, slash]);
                while currentToken in [times, slash] do
                begin
                    multiplicativeOperator := currentToken;
                    getsym;
                    factor(followTokens+[times, slash]);
                    if multiplicativeOperator = times then
                        gen(opr, 0, 4)
                    else
                        gen(opr, 0, 5)
                end
            end {term} ;

        begin {expression}
            if currentToken in [plus, minus] then
            begin
                additiveOperator := currentToken;
                getsym;
                term(followTokens+[plus, minus]);
                if additiveOperator = minus then
                    gen(opr,0,1)
            end
            else
                term(followTokens+[plus, minus]);
            while currentToken in [plus, minus] do
            begin
                additiveOperator := currentToken;
                getsym;
                term(followTokens+[plus, minus]);
                if additiveOperator = plus then
                    gen(opr,0,2)
                else
                    gen(opr,0,3)
            end
        end {expression} ;

        procedure condition(followTokens: tokenSet);
            var relationalOperator: tokenKind;
        begin
            if currentToken = oddsym then
            begin
                getsym;
                expression(followTokens);
                gen(opr,0,6)
            end
            else
            begin
                expression([eql, neq, lss, gtr, leq, geq]+followTokens);
                if not (currentToken in [eql, neq, lss, leq, gtr, geq]) then
                    error (20)
                else
                begin
                    relationalOperator := currentToken;
                    getsym;
                    expression(followTokens);
                    case relationalOperator of
                        eql: gen(opr,0, 8);
                        neq: gen(opr,0, 9);
                        lss: gen(opr,0,10);
                        geq: gen(opr,0,11);
                        gtr: gen(opr,0,12);
                        leq: gen(opr,0,13);
                    end
                end
            end
        end {condition} ;

    begin {statement}
        if currentToken = ident then
        begin
            symbolIndex := position(currentIdentifier);
            if symbolIndex = 0 then
                error (11)
            else
                if symbolTable[symbolIndex].declarationType <> variable then
                begin {assignment to non-variable}
                    error (12);
                    symbolIndex := 0
                end ;
            getsym;
            if currentToken = becomes then
                getsym
            else
                error (13);
            expression(followTokens);
            if symbolIndex <> 0 then
                with symbolTable[symbolIndex] do
                    gen(sto, currentLevel - declarationLevel, address)
        end
        else
            if currentToken = callsym then
            begin
                getsym;
                if currentToken <> ident then
                    error (14)
                else
                begin
                    symbolIndex := position(currentIdentifier);
                    if symbolIndex = 0 then
                        error (11)
                    else
                        with symbolTable[symbolIndex] do
                            if declarationType = proc then
                                gen (cal, currentLevel-declarationLevel, address)
                            else
                                error (15);
                    getsym
                end
            end
            else
                if currentToken = ifsym then
                begin
                    getsym;
                    condition([thensym, dosym]+followTokens);
                    if currentToken = thensym then
                        getsym
                    else
                        error (16);
                    conditionalJumpIndex := codeIndex;
                    gen(jpc,0,0);
                    statement(followTokens);
                    pCode[conditionalJumpIndex].argument := codeIndex
                end
                else
                    if currentToken = beginsym then
                    begin
                        getsym;
                        statement([semicolon, endsym]+followTokens);
                        while currentToken in [semicolon]+statementStartTokens do
                        begin
                            if currentToken = semicolon then
                                getsym
                            else
                                error (10);
                            statement([semicolon, endsym]+followTokens)
                        end ;
                        if currentToken = endsym then
                            getsym
                        else
                            error (17)
                    end
                    else
                        if currentToken = whilesym then
                        begin
                            conditionalJumpIndex := codeIndex;
                            getsym;
                            condition([dosym]+followTokens);
                            loopExitJumpIndex := codeIndex;
                            gen(jpc,0,0);
                            if currentToken = dosym then
                                getsym
                            else
                                error (18);
                            statement(followTokens);
                            gen(jmp, 0, conditionalJumpIndex);
                            pCode[loopExitJumpIndex].argument := codeIndex
                        end ;
        test(followTokens, [ ], 19)
     end {statement} ;

begin {block}
    dataAllocationIndex := 3;
    savedTableIndex := tableIndex;
    symbolTable[tableIndex].address := codeIndex;
    gen(jmp,0,0);
    if currentLevel > maxNestingLevel then
        error (32);
    repeat
        if currentToken = constsym then
        begin
            getsym;
            repeat
                constdeclaration;
                while currentToken = comma do
                begin
                    getsym;
                    constdeclaration
                end ;
                if currentToken = semicolon then
                    getsym
                else
                    error (5)
            until currentToken <> ident
        end ;
        if currentToken = varsym then
        begin
            getsym;
            repeat
                vardeclaration;
                while currentToken = comma do
                begin
                    getsym;
                    vardeclaration
                end ;
                if currentToken = semicolon then
                    getsym
                else
                    error (5)
            until currentToken <> ident;
        end ;
        while currentToken = procsym do
        begin
            getsym;
            if currentToken = ident then
            begin
                enter(proc);
                getsym
            end
            else
                error (4);
            if currentToken = semicolon then
                getsym
            else
                error (5);
            block(currentLevel+1, tableIndex, [semicolon]+followTokens);
            if currentToken = semicolon then
            begin
                getsym;
                test(statementStartTokens+[ident, procsym], followTokens, 6)
            end
            else
                error (5)
        end ;
        test(statementStartTokens+[ident], declarationStartTokens, 7)
    until not(currentToken in declarationStartTokens);
    pCode[symbolTable[savedTableIndex].address].argument := codeIndex;
    with symbolTable[savedTableIndex] do
    begin
        address := codeIndex; {start adr of code}
    end ;
    blockCodeStart := codeIndex;
    gen(int, 0, dataAllocationIndex);
    statement([semicolon, endsym]+followTokens);
    gen(opr, 0, 0); {return}
    test(followTokens, [ ], 8);
    listcode;
end {block} ;

begin {main program}
    sourceFileName := ParamStr(1);
    Assign(sourceFile, sourceFileName);
    Reset(sourceFile);

    pCodeFileName := ChangeFileExt(sourceFileName, '.pcode');
    //pCodeFileName := ExtractFileName(pCodeFileName);
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
    { page(output);  standard library feature of old Pascals to clear screen }
    errorCount := 0;
    charIndex := 0;
    codeIndex := 0;
    lineLength := 0;
    currentChar := ' ';
    identifierBufferLength := identifierLength;
    getsym;
    block(0, 0, [period]+declarationStartTokens+statementStartTokens);
    if currentToken <> period then
        error (9);
    if errorCount = 0 then
    begin
        write(' PL/O PROGRAM COMPILED SUCCESSFULLY');
        for outputInstructionIndex := 0 to codeMaxIndex do
            with pCode[outputInstructionIndex] do
                writeln(pCodeFile, outputInstructionIndex,
                        opcodeMnemonics[operation]:5, lexicalLevel:3, argument:5);
    end
    else
        write(' ERRORS IN PL/O PROGRAM');
    {99: writeln}
    cleanExit()
end .
