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
  SysUtils, diagnostics, tokens, lexer, symtable, astree;

const maxAddress = 2047;         {maximum address}
    maxNestingLevel = 1;         {the language has only global and procedure-local lexical scopes}
    codeMaxIndex = 200;          {maximum code array index}

type opcode = (lit, opr, lod, sto, cal, int, jmp, jpc); {functions}
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

{Writes a generated-instruction trace entry.}
procedure traceInstruction(messageText: string);
begin
    emitDiagnostic(debug, '[EMIT] ' + messageText)
end {traceInstruction} ;

procedure dumpAstIfVerbose(rootNode: astNode);
begin
    if getDiagnosticVerbosity = diagnostics.all then
        dumpAstPreOrder(rootNode)
end {dumpAstIfVerbose} ;

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
function compileBlock (currentLevel: integer; blockSymbolIndex: symbolIndex; followTokens: symbolSet;
                       allowProcedureDeclarations: boolean): astNode;
    var dataAllocationIndex: integer;     {next local-variable slot; slots 0..2 are the activation record header}
        declarationNode: astNode;         {AST node produced for one declaration}
        procedureSymbolIndex: symbolIndex;{symbol table slot for a declared procedure before compiling its body}
        scopeMarker: symbolIndex;         {symbol table size on entry so locals can shadow outer names}
        blockCodeStart: integer;          {first emitted instruction that belongs to this block body}
        blockNode: astNode;      {AST node for the current block}
        activeDeclarationStartTokens: symbolSet;

    {Parses one constant declaration and records it in the symbol table.}
    function parseConstantDeclaration: astNode;
        var declarationIdentifier: identifier;
            declarationValue: integer;
            declarationSource: sourceContext;
    begin
        parseConstantDeclaration := nil;
        if lexerCurrentToken = ident then
        begin
            declarationIdentifier := lexerCurrentIdentifier;
            declarationSource := lexerCurrentSourceContext;
            readNextToken(errorCount);
            if lexerCurrentToken in [eql, becomes] then
            begin
                if lexerCurrentToken = becomes then
                    reportCompilerError(ERR_USE_EQUAL_NOT_BECOMES, lexerCurrentSourceContext, errorCount);
                readNextToken(errorCount);
                if lexerCurrentToken = number then
                begin
                    declarationValue := lexerCurrentNumber;
                    enterDeclaration(constant, lexerCurrentIdentifier, lexerCurrentNumber,
                                     currentLevel, maxAddress, lexerCurrentSourceContext,
                                     dataAllocationIndex, errorCount);
                    parseConstantDeclaration := newConstDeclarationNode(declarationIdentifier,
                                                                        declarationValue,
                                                                        declarationSource);
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
    function parseVariableDeclaration: astNode;
        var declarationIdentifier: identifier;
            declarationSource: sourceContext;
    begin
        parseVariableDeclaration := nil;
        if lexerCurrentToken = ident then
        begin
            declarationIdentifier := lexerCurrentIdentifier;
            declarationSource := lexerCurrentSourceContext;
            enterDeclaration(variable, lexerCurrentIdentifier, 0, currentLevel,
                             maxAddress,
                             lexerCurrentSourceContext, dataAllocationIndex, errorCount);
            parseVariableDeclaration := newVarDeclarationNode(declarationIdentifier, declarationSource);
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
    function compileStatement (followTokens: symbolSet): astNode;
        var symbolIndex, conditionalJumpIndex, loopExitJumpIndex: integer;
            statementSource: sourceContext;

        {Compiles an expression, including leading signs and additive operators.}
        function compileExpression(followTokens: symbolSet): astNode;
            var additiveOperator: symbol;
                expressionNode, rightHandNode, termNode: astNode;
                expressionSource: sourceContext;

            {Compiles a term and emits multiplication or division operations.}
            function compileTerm(followTokens: symbolSet): astNode;
                var multiplicativeOperator: symbol;
                    factorNode, rightHandNode, termNode: astNode;
                    termSource: sourceContext;

                {Compiles a factor such as an identifier, number, or parenthesized expression.}
                function compileFactor (followTokens: symbolSet): astNode;
                    var symbolIndex: integer;
                        factorNode: astNode;
                        factorSource: sourceContext;
                begin
                    compileFactor := nil;
                    recoverIfUnexpectedToken(factorStartTokens, followTokens, ERR_INVALID_TOKEN_AT_EXPRESSION_START);
                    while lexerCurrentToken in factorStartTokens do
                    begin
                        if lexerCurrentToken = ident then
                        begin
                            factorSource := lexerCurrentSourceContext;
                            factorNode := newIdentifierReferenceNode(lexerCurrentIdentifier, factorSource);
                            symbolIndex := lookupSymbol(lexerCurrentIdentifier);
                            if symbolIndex = 0 then
                                reportCompilerError(ERR_UNDECLARED_IDENTIFIER, lexerCurrentSourceContext, errorCount)
                            else
                                case getDeclarationKind(symbolIndex) of
                                    constant: emitInstruction(lit, 0, getConstantValue(symbolIndex));
                                    variable: emitInstruction(lod, lexicalLevelDistance(currentLevel, getDeclarationLevel(symbolIndex),
                                                                                       lexerCurrentSourceContext, errorCount),
                                                              getAddress(symbolIndex));
                                    proc: reportCompilerError(ERR_PROCEDURE_IDENTIFIER_IN_EXPRESSION, lexerCurrentSourceContext, errorCount)
                                end ;
                            compileFactor := factorNode;
                            readNextToken(errorCount)
                        end
                        else
                            if lexerCurrentToken = number then
                            begin
                                factorSource := lexerCurrentSourceContext;
                                factorNode := newNumberLiteralNode(lexerCurrentNumber, factorSource);
                                if lexerCurrentNumber > maxAddress then
                                begin
                                    reportCompilerError(ERR_NUMBER_TOO_LARGE, lexerCurrentSourceContext, errorCount);
                                    emitInstruction(lit, 0, 0)
                                end ;
                                if lexerCurrentNumber <= maxAddress then
                                    emitInstruction(lit, 0, lexerCurrentNumber);
                                compileFactor := factorNode;
                                readNextToken(errorCount)
                            end
                            else
                                if lexerCurrentToken = lparen then
                                begin
                                    factorSource := lexerCurrentSourceContext;
                                    readNextToken(errorCount);
                                    factorNode := compileExpression([rparen]+followTokens);
                                    if lexerCurrentToken = rparen then
                                        readNextToken(errorCount)
                                    else
                                        reportCompilerError(ERR_RIGHT_PARENTHESIS_MISSING, lexerCurrentSourceContext, errorCount);
                                    compileFactor := factorNode
                                end ;
                        recoverIfUnexpectedToken (followTokens, [lparen], ERR_INVALID_TOKEN_AFTER_FACTOR)
                    end
                end {compileFactor} ;

            begin {compileTerm}
                termNode := compileFactor(followTokens+[times, slash]);
                while lexerCurrentToken in [times, slash] do
                begin
                    multiplicativeOperator := lexerCurrentToken;
                    termSource := lexerCurrentSourceContext;
                    readNextToken(errorCount);
                    rightHandNode := compileFactor(followTokens+[times, slash]);
                    factorNode := newBinaryExpressionNode(multiplicativeOperator, termSource);
                    appendExpressionChild(factorNode, termNode);
                    appendExpressionChild(factorNode, rightHandNode);
                    termNode := factorNode;
                    if multiplicativeOperator = times then
                        emitInstruction(opr, 0, 4)
                    else
                        emitInstruction(opr, 0, 5)
                end;
                compileTerm := termNode
            end {compileTerm} ;

        begin {compileExpression}
            if lexerCurrentToken in [plus, minus] then
            begin
                additiveOperator := lexerCurrentToken;
                expressionSource := lexerCurrentSourceContext;
                readNextToken(errorCount);
                termNode := compileTerm(followTokens+[plus, minus]);
                expressionNode := newUnaryExpressionNode(additiveOperator, expressionSource);
                appendExpressionChild(expressionNode, termNode);
                if additiveOperator = minus then
                    emitInstruction(opr,0,1)
            end
            else
                expressionNode := compileTerm(followTokens+[plus, minus]);
            while lexerCurrentToken in [plus, minus] do
            begin
                additiveOperator := lexerCurrentToken;
                expressionSource := lexerCurrentSourceContext;
                readNextToken(errorCount);
                rightHandNode := compileTerm(followTokens+[plus, minus]);
                termNode := newBinaryExpressionNode(additiveOperator, expressionSource);
                appendExpressionChild(termNode, expressionNode);
                appendExpressionChild(termNode, rightHandNode);
                expressionNode := termNode;
                if additiveOperator = plus then
                    emitInstruction(opr,0,2)
                else
                    emitInstruction(opr,0,3)
            end;
            compileExpression := expressionNode
        end {compileExpression} ;

        {Compiles a boolean condition and emits the comparison operation.}
        function compileCondition(followTokens: symbolSet): astNode;
            var relationalOperator: symbol;
                conditionNode, leftExpressionNode, rightExpressionNode: astNode;
                conditionSource: sourceContext;
        begin
            if lexerCurrentToken = oddsym then
            begin
                conditionSource := lexerCurrentSourceContext;
                readNextToken(errorCount);
                leftExpressionNode := compileExpression(followTokens);
                conditionNode := newConditionNode(oddsym, conditionSource);
                appendExpressionChild(conditionNode, leftExpressionNode);
                emitInstruction(opr,0,6)
            end
            else
            begin
                leftExpressionNode := compileExpression([eql, neq, lss, gtr, leq, geq]+followTokens);
                conditionSource := lexerCurrentSourceContext;
                if not (lexerCurrentToken in [eql, neq, lss, leq, gtr, geq]) then
                begin
                    reportCompilerError(ERR_RELATIONAL_OPERATOR_EXPECTED, lexerCurrentSourceContext, errorCount);
                    conditionNode := newConditionNode(nul, conditionSource);
                    appendExpressionChild(conditionNode, leftExpressionNode)
                end
                else
                begin
                    relationalOperator := lexerCurrentToken;
                    readNextToken(errorCount);
                    rightExpressionNode := compileExpression(followTokens);
                    conditionNode := newConditionNode(relationalOperator, conditionSource);
                    appendExpressionChild(conditionNode, leftExpressionNode);
                    appendExpressionChild(conditionNode, rightExpressionNode);
                    case relationalOperator of
                        eql: emitInstruction(opr,0, 8);
                        neq: emitInstruction(opr,0, 9);
                        lss: emitInstruction(opr,0,10);
                        geq: emitInstruction(opr,0,11);
                        gtr: emitInstruction(opr,0,12);
                        leq: emitInstruction(opr,0,13);
                    end
                end
            end;
            compileCondition := conditionNode
        end {compileCondition} ;

    begin {compileStatement}
        compileStatement := nil;
        if lexerCurrentToken = ident then
        begin
            statementSource := lexerCurrentSourceContext;
            compileStatement := newAssignmentStatementNode(statementSource);
            appendExpressionChild(compileStatement,
                                  newIdentifierReferenceNode(lexerCurrentIdentifier, statementSource));
            symbolIndex := lookupSymbol(lexerCurrentIdentifier);
            if symbolIndex = 0 then
                reportCompilerError(ERR_UNDECLARED_IDENTIFIER, lexerCurrentSourceContext, errorCount)
            else
                if getDeclarationKind(symbolIndex) <> variable then
                begin {assignment to non-variable}
                    reportCompilerError(ERR_ASSIGNMENT_TO_CONSTANT_OR_PROCEDURE, lexerCurrentSourceContext, errorCount);
                    symbolIndex := 0
                end ;
            readNextToken(errorCount);
            if lexerCurrentToken = becomes then
                readNextToken(errorCount)
            else
                reportCompilerError(ERR_ASSIGNMENT_OPERATOR_EXPECTED, lexerCurrentSourceContext, errorCount);
            appendExpressionChild(compileStatement, compileExpression(followTokens));
            if symbolIndex <> 0 then
                emitInstruction(sto, lexicalLevelDistance(currentLevel, getDeclarationLevel(symbolIndex),
                                                          lexerCurrentSourceContext, errorCount),
                                getAddress(symbolIndex))
        end
        else
            if lexerCurrentToken = callsym then
            begin
                statementSource := lexerCurrentSourceContext;
                compileStatement := newCallStatementNode(statementSource);
                readNextToken(errorCount);
                if lexerCurrentToken <> ident then
                    reportCompilerError(ERR_CALL_MUST_BE_FOLLOWED_BY_IDENTIFIER, lexerCurrentSourceContext, errorCount)
                else
                begin
                    appendArgumentNode(compileStatement,
                                       newIdentifierReferenceNode(lexerCurrentIdentifier, lexerCurrentSourceContext));
                    symbolIndex := lookupSymbol(lexerCurrentIdentifier);
                    if symbolIndex = 0 then
                        reportCompilerError(ERR_UNDECLARED_IDENTIFIER, lexerCurrentSourceContext, errorCount)
                    else
                        if getDeclarationKind(symbolIndex) = proc then
                            emitInstruction (cal, lexicalLevelDistance(currentLevel, getDeclarationLevel(symbolIndex),
                                                                       lexerCurrentSourceContext, errorCount),
                                             getAddress(symbolIndex))
                        else
                            reportCompilerError(ERR_CALL_OF_CONSTANT_OR_VARIABLE, lexerCurrentSourceContext, errorCount);
                    readNextToken(errorCount)
                end
            end
            else
                if lexerCurrentToken = ifsym then
                begin
                    statementSource := lexerCurrentSourceContext;
                    compileStatement := newIfStatementNode(statementSource);
                    readNextToken(errorCount);
                    appendChild(compileStatement, compileCondition([thensym, dosym]+followTokens));
                    if lexerCurrentToken = thensym then
                        readNextToken(errorCount)
                    else
                        reportCompilerError(ERR_THEN_EXPECTED, lexerCurrentSourceContext, errorCount);
                    conditionalJumpIndex := codeIndex;
                    emitInstruction(jpc,0,0);
                    appendStatementNode(compileStatement, compileStatement(followTokens));
                    pCode[conditionalJumpIndex].argument := codeIndex
                end
                else
                    if lexerCurrentToken = beginsym then
                    begin
                        statementSource := lexerCurrentSourceContext;
                        compileStatement := newCompoundStatementNode(statementSource);
                        readNextToken(errorCount);
                        recoverIfUnexpectedToken(statementStartTokens+[ident],
                                                 [semicolon, endsym]+followTokens, ERR_STATEMENT_EXPECTED);
                        appendStatementNode(compileStatement,
                                            compileStatement([semicolon, endsym]+followTokens));
                        while lexerCurrentToken in [semicolon]+statementStartTokens do
                        begin
                            if lexerCurrentToken = semicolon then
                                readNextToken(errorCount)
                            else
                                reportCompilerError(ERR_MISSING_SEMICOLON_BETWEEN_STATEMENTS, lexerCurrentSourceContext, errorCount);
                            appendStatementNode(compileStatement,
                                                compileStatement([semicolon, endsym]+followTokens))
                        end ;
                        if lexerCurrentToken = endsym then
                            readNextToken(errorCount)
                        else
                            reportCompilerError(ERR_SEMICOLON_OR_END_EXPECTED, lexerCurrentSourceContext, errorCount)
                    end
                    else
                        if lexerCurrentToken = whilesym then
                        begin
                            statementSource := lexerCurrentSourceContext;
                            compileStatement := newWhileStatementNode(statementSource);
                            conditionalJumpIndex := codeIndex;
                            readNextToken(errorCount);
                            appendChild(compileStatement, compileCondition([dosym]+followTokens));
                            loopExitJumpIndex := codeIndex;
                            emitInstruction(jpc,0,0);
                            if lexerCurrentToken = dosym then
                                readNextToken(errorCount)
                            else
                                reportCompilerError(ERR_DO_EXPECTED, lexerCurrentSourceContext, errorCount);
                            appendStatementNode(compileStatement, compileStatement(followTokens));
                            emitInstruction(jmp, 0, conditionalJumpIndex);
                            pCode[loopExitJumpIndex].argument := codeIndex
                        end ;
        recoverIfUnexpectedToken(followTokens, [ ], ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT)
     end {compileStatement} ;

begin {compileBlock}
    blockNode := newBlockNode(lexerCurrentSourceContext);
    dataAllocationIndex := 3; {reserve static link, dynamic link, and return address}
    scopeMarker := markScope;
    activeDeclarationStartTokens := [constsym, varsym];
    if allowProcedureDeclarations then
    begin
        activeDeclarationStartTokens := activeDeclarationStartTokens + [procsym];
        setAddress(blockSymbolIndex, codeIndex);
        emitInstruction(jmp,0,0); {skip top-level procedure bodies until the main block is entered}
    end;
    if currentLevel > 1 then
        reportCompilerError(ERR_PROCEDURES_GLOBAL_SCOPE_ONLY, lexerCurrentSourceContext, errorCount);
    repeat
        if lexerCurrentToken = constsym then
        begin
            readNextToken(errorCount);
            repeat
                declarationNode := parseConstantDeclaration;
                appendDeclarationNode(blockNode, declarationNode);
                while lexerCurrentToken = comma do
                begin
                    readNextToken(errorCount);
                    declarationNode := parseConstantDeclaration;
                    appendDeclarationNode(blockNode, declarationNode)
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
                declarationNode := parseVariableDeclaration;
                appendDeclarationNode(blockNode, declarationNode);
                while lexerCurrentToken = comma do
                begin
                    readNextToken(errorCount);
                    declarationNode := parseVariableDeclaration;
                    appendDeclarationNode(blockNode, declarationNode)
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
                declarationNode := newProcedureDeclarationNode(lexerCurrentIdentifier, lexerCurrentSourceContext);
                procedureSymbolIndex := enterDeclaration(proc, lexerCurrentIdentifier, 0,
                                                         currentLevel, maxAddress, lexerCurrentSourceContext,
                                                         dataAllocationIndex, errorCount);
                readNextToken(errorCount)
            end
            else
                reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, lexerCurrentSourceContext, errorCount);
            if lexerCurrentToken = semicolon then
                readNextToken(errorCount)
            else
                reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, lexerCurrentSourceContext, errorCount);
            appendChild(declarationNode,
                        compileBlock(currentLevel+1, procedureSymbolIndex, [semicolon]+followTokens, false));
            appendDeclarationNode(blockNode, declarationNode);
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
        pCode[getAddress(blockSymbolIndex)].argument := codeIndex;
    if (currentLevel = 0) or (blockSymbolIndex <> 0) then
        setAddress(blockSymbolIndex, codeIndex); {entry point of this block after declarations}
    blockCodeStart := codeIndex;
    emitInstruction(int, 0, dataAllocationIndex);
    appendStatementNode(blockNode, compileStatement([semicolon, endsym]+followTokens));
    emitInstruction(opr, 0, 0); {return}
    recoverIfUnexpectedToken(followTokens, [ ], ERR_INVALID_TOKEN_AFTER_STATEMENT_PART_IN_BLOCK);
    listGeneratedCode;
    restoreScope(scopeMarker);
    compileBlock := blockNode
end {compileBlock} ;

procedure compileFile(const inputFileName: string);
    var programNode: astNode;
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
    initializeSymbolTable;
    programNode := newProgramNode(lexerCurrentSourceContext);
    appendChild(programNode,
                compileBlock(0, 0, [period]+declarationStartTokens+statementStartTokens, true));
    if lexerCurrentToken <> period then
        reportCompilerError(ERR_PERIOD_EXPECTED, lexerCurrentSourceContext, errorCount);
    if errorCount = 0 then
    begin
        emitDiagnostic(status, STATUS_COMPILER_SUCCESS);
        dumpAstIfVerbose(programNode);
        for outputInstructionIndex := 0 to codeIndex - 1 do
            with pCode[outputInstructionIndex] do
                writeln(pCodeFile, outputInstructionIndex,
                        opcodeMnemonics[operation]:5, lexicalLevel:3, argument:5);
    end
    else
        emitDiagnostic(status, STATUS_COMPILER_ERRORS);
    cleanupLexer;
    freeAst(programNode);
    closeFilesAndHalt()
end {compileFile} ;

end.
