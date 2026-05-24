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
This file contains the parser front end.
}

unit parser;
{PL/0 parser front end: parse, analyze, then invoke code generation}

interface

procedure parseFile(const inputFileName: string);

implementation

uses
  SysUtils, diagnostics, tokens, lexer, astree, semantics, codegen, symtable;

const
  declarationStartTokens: symbolSet = [constsym, varsym, procsym];
  statementStartTokens: symbolSet = [beginsym, callsym, ifsym, whilesym];
  factorStartTokens: symbolSet = [ident, number, lparen];

procedure dumpAstIfVerbose(rootNode: astNode);
begin
    if getDiagnosticVerbosity = diagnostics.all then
        dumpAstPreOrder(rootNode)
end {dumpAstIfVerbose} ;

{Reports an unexpected token and skips input until parsing can safely resume.}
procedure recoverIfUnexpectedToken (allowedTokens, recoveryTokens: symbolSet; errorCode: integer;
                                    var errorCount: integer);
begin
    if not (lexerCurrentToken in allowedTokens) then
    begin
        reportCompilerError(errorCode, lexerCurrentSourceContext, errorCount);
        allowedTokens := allowedTokens + recoveryTokens;
        while not (lexerCurrentToken in allowedTokens) do
            readNextToken(errorCount)
    end
end {recoverIfUnexpectedToken} ;

{Parses a PL/0 block into AST declarations and a statement body.
 Top-level blocks may declare procedures; procedure bodies may not.}
function compileBlock (currentLevel: integer; followTokens: symbolSet;
                       allowProcedureDeclarations: boolean;
                       var errorCount: integer): astNode;
    var declarationNode: astNode;         {AST node produced for one declaration}
        blockNode: astNode;      {AST node for the current block}
        activeDeclarationStartTokens: symbolSet;

    {Parses the shared mandatory declaration type annotation.}
    function parseDeclarationType(followTokens: symbolSet): typeValue;
    begin
        parseDeclarationType := typeInteger;
        if lexerCurrentToken = colon then
        begin
            readNextToken(errorCount);
            if lexerCurrentToken = integersym then
                readNextToken(errorCount)
            else
            begin
                reportCompilerError(ERR_TYPE_NAME_EXPECTED, lexerCurrentSourceContext, errorCount);
                if not (lexerCurrentToken in followTokens) then
                    readNextToken(errorCount)
            end
        end
        else
            reportCompilerError(ERR_TYPE_ANNOTATION_EXPECTED, lexerCurrentSourceContext, errorCount)
    end {parseDeclarationType} ;

    {Parses one constant declaration and builds its AST node.}
    function parseConstantDeclaration: astNode;
        var declarationIdentifier: identifier;
            declarationType: typeValue;
            declarationValue: integer;
            declarationSource: sourceContext;
    begin
        parseConstantDeclaration := nil;
        if lexerCurrentToken = ident then
        begin
            declarationIdentifier := lexerCurrentIdentifier;
            declarationSource := lexerCurrentSourceContext;
            readNextToken(errorCount);
            declarationType := parseDeclarationType([eql, becomes, comma, semicolon]);
            if lexerCurrentToken in [eql, becomes] then
            begin
                if lexerCurrentToken = becomes then
                    reportCompilerError(ERR_USE_EQUAL_NOT_BECOMES, lexerCurrentSourceContext, errorCount);
                readNextToken(errorCount);
                if lexerCurrentToken = number then
                begin
                    declarationValue := lexerCurrentNumber;
                    parseConstantDeclaration := newConstDeclarationNode(declarationIdentifier,
                                                                        declarationValue,
                                                                        declarationType,
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

    {Parses one variable declaration and builds its AST node.}
    function parseVariableDeclaration: astNode;
        var declarationIdentifier: identifier;
            declarationType: typeValue;
            declarationSource: sourceContext;
    begin
        parseVariableDeclaration := nil;
        if lexerCurrentToken = ident then
        begin
            declarationIdentifier := lexerCurrentIdentifier;
            declarationSource := lexerCurrentSourceContext;
            readNextToken(errorCount);
            declarationType := parseDeclarationType([comma, semicolon]);
            parseVariableDeclaration := newVarDeclarationNode(declarationIdentifier, declarationType,
                                                              declarationSource)
        end
        else
            reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, lexerCurrentSourceContext, errorCount)
    end {parseVariableDeclaration} ;

    {Parses one statement into AST form.}
    function compileStatement (followTokens: symbolSet): astNode;
        var statementSource: sourceContext;

        {Parses an expression, including leading signs and additive operators.}
        function compileExpression(followTokens: symbolSet): astNode;
            var additiveOperator: symbol;
                expressionNode, rightHandNode, termNode: astNode;
                expressionSource: sourceContext;

            {Parses a term.}
            function compileTerm(followTokens: symbolSet): astNode;
                var multiplicativeOperator: symbol;
                    factorNode, rightHandNode, termNode: astNode;
                    termSource: sourceContext;

                {Parses a factor such as an identifier, number, or parenthesized expression.}
                function compileFactor (followTokens: symbolSet): astNode;
                    var factorNode: astNode;
                        factorSource: sourceContext;
                begin
                    compileFactor := nil;
                    recoverIfUnexpectedToken(factorStartTokens, followTokens, ERR_INVALID_TOKEN_AT_EXPRESSION_START,
                                             errorCount);
                    while lexerCurrentToken in factorStartTokens do
                    begin
                        if lexerCurrentToken = ident then
                        begin
                            factorSource := lexerCurrentSourceContext;
                            factorNode := newIdentifierReferenceNode(lexerCurrentIdentifier, factorSource);
                            compileFactor := factorNode;
                            readNextToken(errorCount)
                        end
                        else
                            if lexerCurrentToken = number then
                            begin
                                factorSource := lexerCurrentSourceContext;
                                factorNode := newNumberLiteralNode(lexerCurrentNumber, factorSource);
                                if lexerCurrentNumber > maxNumericValue then
                                    reportCompilerError(ERR_NUMBER_TOO_LARGE, lexerCurrentSourceContext, errorCount);
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
                        recoverIfUnexpectedToken (followTokens, [lparen], ERR_INVALID_TOKEN_AFTER_FACTOR,
                                                  errorCount)
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
                    termNode := factorNode
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
                appendExpressionChild(expressionNode, termNode)
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
                expressionNode := termNode
            end;
            compileExpression := expressionNode
        end {compileExpression} ;

        {Parses a boolean condition.}
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
                appendExpressionChild(conditionNode, leftExpressionNode)
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
                    appendExpressionChild(conditionNode, rightExpressionNode)
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
            readNextToken(errorCount);
            if lexerCurrentToken = becomes then
                readNextToken(errorCount)
            else
                reportCompilerError(ERR_ASSIGNMENT_OPERATOR_EXPECTED, lexerCurrentSourceContext, errorCount);
            appendExpressionChild(compileStatement, compileExpression(followTokens))
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
                    appendStatementNode(compileStatement, compileStatement(followTokens))
                end
                else
                    if lexerCurrentToken = beginsym then
                    begin
                        statementSource := lexerCurrentSourceContext;
                        compileStatement := newCompoundStatementNode(statementSource);
                        readNextToken(errorCount);
                        recoverIfUnexpectedToken(statementStartTokens+[ident],
                                                 [semicolon, endsym]+followTokens, ERR_STATEMENT_EXPECTED,
                                                 errorCount);
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
                            readNextToken(errorCount);
                            appendChild(compileStatement, compileCondition([dosym]+followTokens));
                            if lexerCurrentToken = dosym then
                                readNextToken(errorCount)
                            else
                                reportCompilerError(ERR_DO_EXPECTED, lexerCurrentSourceContext, errorCount);
                            appendStatementNode(compileStatement, compileStatement(followTokens))
                        end ;
        recoverIfUnexpectedToken(followTokens, [ ], ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT, errorCount)
     end {compileStatement} ;

begin {compileBlock}
    blockNode := newBlockNode(lexerCurrentSourceContext);
    activeDeclarationStartTokens := [constsym, varsym];
    if allowProcedureDeclarations then
        activeDeclarationStartTokens := activeDeclarationStartTokens + [procsym];
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
                                         statementStartTokens + activeDeclarationStartTokens,
                                         ERR_DECLARATION_IDENTIFIER_EXPECTED, errorCount);
                while not (lexerCurrentToken in [semicolon] + followTokens +
                                        statementStartTokens + activeDeclarationStartTokens) do
                    readNextToken(errorCount);
                continue
            end;
            readNextToken(errorCount);
            if lexerCurrentToken = ident then
            begin
                declarationNode := newProcedureDeclarationNode(lexerCurrentIdentifier, lexerCurrentSourceContext);
                readNextToken(errorCount)
            end
            else
                reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, lexerCurrentSourceContext, errorCount);
            if lexerCurrentToken = semicolon then
                readNextToken(errorCount)
            else
                reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, lexerCurrentSourceContext, errorCount);
            appendChild(declarationNode,
                        compileBlock(currentLevel+1, [semicolon]+followTokens, false, errorCount));
            appendDeclarationNode(blockNode, declarationNode);
            if lexerCurrentToken = semicolon then
            begin
                readNextToken(errorCount);
                recoverIfUnexpectedToken(statementStartTokens+[ident] +
                                         activeDeclarationStartTokens, followTokens,
                                         ERR_INVALID_TOKEN_AFTER_PROCEDURE_DECLARATION, errorCount)
            end
            else
                reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, lexerCurrentSourceContext, errorCount)
        end ;
        if (not allowProcedureDeclarations) and (lexerCurrentToken = procsym) then
        begin
            reportCompilerError(ERR_NESTED_PROCEDURES_NOT_SUPPORTED, lexerCurrentSourceContext, errorCount);
            readNextToken(errorCount);
            recoverIfUnexpectedToken([ident], [semicolon] + followTokens +
                                     statementStartTokens + activeDeclarationStartTokens,
                                     ERR_DECLARATION_IDENTIFIER_EXPECTED, errorCount);
            while not (lexerCurrentToken in [semicolon] + followTokens +
                                    statementStartTokens + activeDeclarationStartTokens) do
                readNextToken(errorCount);
        end;
        recoverIfUnexpectedToken(statementStartTokens+[ident], activeDeclarationStartTokens,
                                 ERR_STATEMENT_EXPECTED, errorCount)
    until not(lexerCurrentToken in activeDeclarationStartTokens);
    appendStatementNode(blockNode, compileStatement([semicolon, endsym]+followTokens));
    recoverIfUnexpectedToken(followTokens, [ ], ERR_INVALID_TOKEN_AFTER_STATEMENT_PART_IN_BLOCK, errorCount);
    compileBlock := blockNode
end {compileBlock} ;

procedure parseFile(const inputFileName: string);
    var programNode: astNode;
        errorCount: integer;
begin
    errorCount := 0;
    initializeLexer(inputFileName, errorCount);
    emitDiagnostic(status, STATUS_COMPILER_PROCESSING_FILE + inputFileName);
    programNode := newProgramNode(lexerCurrentSourceContext);
    appendChild(programNode,
                compileBlock(0, [period]+declarationStartTokens+statementStartTokens, true, errorCount));
    if lexerCurrentToken <> period then
        reportCompilerError(ERR_PERIOD_EXPECTED, lexerCurrentSourceContext, errorCount);
    analyzeAst(programNode, errorCount);
    if errorCount = 0 then
    begin
        initializeCodegen(ChangeFileExt(inputFileName, '.pcode'));
        generateProgram(programNode, errorCount);
        if errorCount = 0 then
        begin
            emitDiagnostic(status, STATUS_COMPILER_SUCCESS);
            dumpAstIfVerbose(programNode);
            traceGeneratedCode(0);
            writeProgramImage
        end
        else
            emitDiagnostic(status, STATUS_COMPILER_ERRORS);
        cleanupCodegen
    end
    else
        emitDiagnostic(status, STATUS_COMPILER_ERRORS);
    cleanupLexer;
    freeAst(programNode);
end {parseFile} ;

end.
