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
  SysUtils, diagnostics, tokens, lexer;

const symbolTableMax = 100;      {length of identifier table}
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

var errorCount: integer;
    codeIndex: integer;       {index of the next instruction to emit}
    pCode: array [0..codeMaxIndex] of pCodeInstruction; {generated program image}
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

    pCodeFile: Text;
    pCodeFileName: string;
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
    close(pCodeFile);
    halt
end {closeFilesAndHalt} ;

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
    if not (lexerCurrentToken in allowedTokens) then
    begin
        reportCompilerError(errorCode, lexerCurrentSourceContext, errorCount);
        allowedTokens := allowedTokens + recoveryTokens;
        while not (lexerCurrentToken in allowedTokens) do
            readNextToken(errorCount)
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
            identifier := lexerCurrentIdentifier;
            declarationType := declarationToEnter;
            case declarationToEnter of
                constant:
                    begin
                        if lexerCurrentNumber > maxAddress then
                        begin
                            reportCompilerError(ERR_NUMBER_TOO_LARGE, lexerCurrentSourceContext, errorCount);
                            constantValue := 0
                        end
                        else
                            constantValue := lexerCurrentNumber;
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
            reportCompilerError(ERR_PROCEDURES_GLOBAL_SCOPE_ONLY, lexerCurrentSourceContext, errorCount);
            lexicalLevelDistance := 0
        end
    end {lexicalLevelDistance} ;

    {Parses one constant declaration and records it in the symbol table.}
    procedure parseConstantDeclaration;
    begin
        if lexerCurrentToken = ident then
        begin
            readNextToken(errorCount);
            if lexerCurrentToken in [eql, becomes] then
            begin
                if lexerCurrentToken = becomes then
                    reportCompilerError(ERR_USE_EQUAL_NOT_BECOMES, lexerCurrentSourceContext, errorCount);
                readNextToken(errorCount);
                if lexerCurrentToken = number then
                begin
                    enterDeclaration(constant);
                    readNextToken(errorCount)
                end
                else
                    reportCompilerError(ERR_NUMBER_EXPECTED_AFTER_EQUAL, lexerCurrentSourceContext, errorCount)
            end
            else
                reportCompilerError(ERR_IDENTIFIER_MUST_BE_FOLLOWED_BY_EQUAL, lexerCurrentSourceContext, errorCount)
        end
        else
            reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, lexerCurrentSourceContext, errorCount)
    end {parseConstantDeclaration} ;

    {Parses one variable declaration and records its stack address.}
    procedure parseVariableDeclaration;
    begin
        if lexerCurrentToken = ident then
        begin
            enterDeclaration (variable);
            readNextToken(errorCount)
        end
        else
            reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, lexerCurrentSourceContext, errorCount)
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
                    while lexerCurrentToken in factorStartTokens do
                    begin
                        if lexerCurrentToken = ident then
                        begin symbolIndex := findSymbol(lexerCurrentIdentifier);
                            if symbolIndex = 0 then
                                reportCompilerError(ERR_UNDECLARED_IDENTIFIER, lexerCurrentSourceContext, errorCount)
                            else
                                with symbolTable[symbolIndex] do
                                case declarationType of
                                    constant: emitInstruction(lit, 0, constantValue);
                                    variable: emitInstruction(lod, lexicalLevelDistance(declarationLevel), address);
                                    proc: reportCompilerError(ERR_PROCEDURE_IDENTIFIER_IN_EXPRESSION, lexerCurrentSourceContext, errorCount)
                                end ;
                                readNextToken(errorCount)
                        end
                        else
                            if lexerCurrentToken = number then
                            begin
                                if lexerCurrentNumber > maxAddress then
                                begin
                                    reportCompilerError(ERR_NUMBER_TOO_LARGE, lexerCurrentSourceContext, errorCount);
                                    emitInstruction(lit, 0, 0)
                                end ;
                                if lexerCurrentNumber <= maxAddress then
                                    emitInstruction(lit, 0, lexerCurrentNumber);
                                readNextToken(errorCount)
                            end
                            else
                                if lexerCurrentToken = lparen then
                                begin
                                    readNextToken(errorCount);
                                    compileExpression([rparen]+followTokens);
                                    if lexerCurrentToken = rparen then
                                        readNextToken(errorCount)
                                    else
                                        reportCompilerError(ERR_RIGHT_PARENTHESIS_MISSING, lexerCurrentSourceContext, errorCount)
                                end ;
                        recoverIfUnexpectedToken (followTokens, [lparen], ERR_INVALID_TOKEN_AFTER_FACTOR)
                    end
                end { compileFactor} ;

            begin {compileTerm}
                compileFactor(followTokens+[times, slash]);
                while lexerCurrentToken in [times, slash] do
                begin
                    multiplicativeOperator := lexerCurrentToken;
                    readNextToken(errorCount);
                    compileFactor(followTokens+[times, slash]);
                    if multiplicativeOperator = times then
                        emitInstruction(opr, 0, 4)
                    else
                        emitInstruction(opr, 0, 5)
                end
            end {compileTerm} ;

        begin {compileExpression}
            if lexerCurrentToken in [plus, minus] then
            begin
                additiveOperator := lexerCurrentToken;
                readNextToken(errorCount);
                compileTerm(followTokens+[plus, minus]);
                if additiveOperator = minus then
                    emitInstruction(opr,0,1)
            end
            else
                compileTerm(followTokens+[plus, minus]);
            while lexerCurrentToken in [plus, minus] do
            begin
                additiveOperator := lexerCurrentToken;
                readNextToken(errorCount);
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
            if lexerCurrentToken = oddsym then
            begin
                readNextToken(errorCount);
                compileExpression(followTokens);
                emitInstruction(opr,0,6)
            end
            else
            begin
                compileExpression([eql, neq, lss, gtr, leq, geq]+followTokens);
                if not (lexerCurrentToken in [eql, neq, lss, leq, gtr, geq]) then
                    reportCompilerError(ERR_RELATIONAL_OPERATOR_EXPECTED, lexerCurrentSourceContext, errorCount)
                else
                begin
                    relationalOperator := lexerCurrentToken;
                    readNextToken(errorCount);
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
        if lexerCurrentToken = ident then
        begin
            symbolIndex := findSymbol(lexerCurrentIdentifier);
            if symbolIndex = 0 then
                reportCompilerError(ERR_UNDECLARED_IDENTIFIER, lexerCurrentSourceContext, errorCount)
            else
                if symbolTable[symbolIndex].declarationType <> variable then
                begin {assignment to non-variable}
                    reportCompilerError(ERR_ASSIGNMENT_TO_CONSTANT_OR_PROCEDURE, lexerCurrentSourceContext, errorCount);
                    symbolIndex := 0
                end ;
            readNextToken(errorCount);
            if lexerCurrentToken = becomes then
                readNextToken(errorCount)
            else
                reportCompilerError(ERR_ASSIGNMENT_OPERATOR_EXPECTED, lexerCurrentSourceContext, errorCount);
            compileExpression(followTokens);
            if symbolIndex <> 0 then
                with symbolTable[symbolIndex] do
                    emitInstruction(sto, lexicalLevelDistance(declarationLevel), address)
        end
        else
            if lexerCurrentToken = callsym then
            begin
                readNextToken(errorCount);
                if lexerCurrentToken <> ident then
                    reportCompilerError(ERR_CALL_MUST_BE_FOLLOWED_BY_IDENTIFIER, lexerCurrentSourceContext, errorCount)
                else
                begin
                    symbolIndex := findSymbol(lexerCurrentIdentifier);
                    if symbolIndex = 0 then
                        reportCompilerError(ERR_UNDECLARED_IDENTIFIER, lexerCurrentSourceContext, errorCount)
                    else
                        with symbolTable[symbolIndex] do
                            if declarationType = proc then
                                emitInstruction (cal, lexicalLevelDistance(declarationLevel), address)
                            else
                                reportCompilerError(ERR_CALL_OF_CONSTANT_OR_VARIABLE, lexerCurrentSourceContext, errorCount);
                    readNextToken(errorCount)
                end
            end
            else
                if lexerCurrentToken = ifsym then
                begin
                    readNextToken(errorCount);
                    compileCondition([thensym, dosym]+followTokens);
                    if lexerCurrentToken = thensym then
                        readNextToken(errorCount)
                    else
                        reportCompilerError(ERR_THEN_EXPECTED, lexerCurrentSourceContext, errorCount);
                    conditionalJumpIndex := codeIndex;
                    emitInstruction(jpc,0,0);
                    compileStatement(followTokens);
                    pCode[conditionalJumpIndex].argument := codeIndex
                end
                else
                    if lexerCurrentToken = beginsym then
                    begin
                        readNextToken(errorCount);
                        recoverIfUnexpectedToken(statementStartTokens+[ident],
                                                 [semicolon, endsym]+followTokens, ERR_STATEMENT_EXPECTED);
                        compileStatement([semicolon, endsym]+followTokens);
                        while lexerCurrentToken in [semicolon]+statementStartTokens do
                        begin
                            if lexerCurrentToken = semicolon then
                                readNextToken(errorCount)
                            else
                                reportCompilerError(ERR_MISSING_SEMICOLON_BETWEEN_STATEMENTS, lexerCurrentSourceContext, errorCount);
                            compileStatement([semicolon, endsym]+followTokens)
                        end ;
                        if lexerCurrentToken = endsym then
                            readNextToken(errorCount)
                        else
                            reportCompilerError(ERR_SEMICOLON_OR_END_EXPECTED, lexerCurrentSourceContext, errorCount)
                    end
                    else
                        if lexerCurrentToken = whilesym then
                        begin
                            conditionalJumpIndex := codeIndex;
                            readNextToken(errorCount);
                            compileCondition([dosym]+followTokens);
                            loopExitJumpIndex := codeIndex;
                            emitInstruction(jpc,0,0);
                            if lexerCurrentToken = dosym then
                                readNextToken(errorCount)
                            else
                                reportCompilerError(ERR_DO_EXPECTED, lexerCurrentSourceContext, errorCount);
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
        reportCompilerError(ERR_PROCEDURES_GLOBAL_SCOPE_ONLY, lexerCurrentSourceContext, errorCount);
    repeat
        if lexerCurrentToken = constsym then
        begin
            readNextToken(errorCount);
            repeat
                parseConstantDeclaration;
                while lexerCurrentToken = comma do
                begin
                    readNextToken(errorCount);
                    parseConstantDeclaration
                end ;
                if lexerCurrentToken = semicolon then
                    readNextToken(errorCount)
                else
                    reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, lexerCurrentSourceContext, errorCount)
            until lexerCurrentToken <> ident
        end ;
        if lexerCurrentToken = varsym then
        begin
            readNextToken(errorCount);
            repeat
                parseVariableDeclaration;
                while lexerCurrentToken = comma do
                begin
                    readNextToken(errorCount);
                    parseVariableDeclaration
                end ;
                if lexerCurrentToken = semicolon then
                    readNextToken(errorCount)
                else
                    reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, lexerCurrentSourceContext, errorCount)
            until lexerCurrentToken <> ident;
        end ;
        while allowProcedureDeclarations and (lexerCurrentToken = procsym) do
        begin
            if currentLevel <> 0 then
            begin
                reportCompilerError(ERR_NESTED_PROCEDURES_NOT_SUPPORTED, lexerCurrentSourceContext, errorCount);
                readNextToken(errorCount);
                recoverIfUnexpectedToken([ident], [semicolon] + followTokens +
                                         statementStartTokens + activeDeclarationStartTokens, ERR_DECLARATION_IDENTIFIER_EXPECTED);
                while not (lexerCurrentToken in [semicolon] + followTokens +
                                        statementStartTokens + activeDeclarationStartTokens) do
                    readNextToken(errorCount);
                continue
            end;
            readNextToken(errorCount);
            if lexerCurrentToken = ident then
            begin
                enterDeclaration(proc);
                readNextToken(errorCount)
            end
            else
                reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, lexerCurrentSourceContext, errorCount);
            if lexerCurrentToken = semicolon then
                readNextToken(errorCount)
            else
                reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, lexerCurrentSourceContext, errorCount);
            compileBlock(currentLevel+1, tableIndex, [semicolon]+followTokens, false);
            if lexerCurrentToken = semicolon then
            begin
                readNextToken(errorCount);
                recoverIfUnexpectedToken(statementStartTokens+[ident] +
                                         activeDeclarationStartTokens, followTokens, ERR_INVALID_TOKEN_AFTER_PROCEDURE_DECLARATION)
            end
            else
                reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, lexerCurrentSourceContext, errorCount)
        end ;
        if (not allowProcedureDeclarations) and (lexerCurrentToken = procsym) then
        begin
            reportCompilerError(ERR_NESTED_PROCEDURES_NOT_SUPPORTED, lexerCurrentSourceContext, errorCount);
            readNextToken(errorCount);
            recoverIfUnexpectedToken([ident], [semicolon] + followTokens +
                                     statementStartTokens + activeDeclarationStartTokens, ERR_DECLARATION_IDENTIFIER_EXPECTED);
            while not (lexerCurrentToken in [semicolon] + followTokens +
                                    statementStartTokens + activeDeclarationStartTokens) do
                readNextToken(errorCount);
        end;
        recoverIfUnexpectedToken(statementStartTokens+[ident], activeDeclarationStartTokens, ERR_STATEMENT_EXPECTED)
    until not(lexerCurrentToken in activeDeclarationStartTokens);
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
    errorCount := 0;
    initializeLexer(inputFileName, errorCount);
    pCodeFileName := ChangeFileExt(inputFileName, '.pcode');
    Assign(pCodeFile, pCodeFileName);
    Rewrite(pCodeFile);
    emitDiagnostic(status, STATUS_COMPILER_PROCESSING_FILE + inputFileName);
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
    codeIndex := 0;
    compileBlock(0, 0, [period]+declarationStartTokens+statementStartTokens, true);
    if lexerCurrentToken <> period then
        reportCompilerError(ERR_PERIOD_EXPECTED, lexerCurrentSourceContext, errorCount);
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
    cleanupLexer;
    closeFilesAndHalt()
end {compileFile} ;

end.
