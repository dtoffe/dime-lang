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
  SysUtils, diagnostics, tokens, lexer, astree, semantics, codegen, symboltable, typetable;

const
  declarationStartTokens: symbolSet = [constsym, varsym, procsym];
  statementStartTokens: symbolSet = [beginsym, callsym, ifsym, whilesym];
  factorStartTokens: symbolSet = [ident, number, truesym, falsesym, lparen, plus, minus, notsym];
  binaryOperatorTokens: symbolSet = [eql, neq, lss, leq, gtr, geq,
                                     plus, minus, orsym, xorsym,
                                     times, slash, andsym];

type
  binaryOperatorPrecedenceEntry = record
    operatorToken: symbol;
    precedence: integer;
    isNonAssociative: boolean;
  end;

const
  binaryOperatorPrecedenceTable: array [1..13] of binaryOperatorPrecedenceEntry = (
    (operatorToken: eql; precedence: 1; isNonAssociative: true),
    (operatorToken: neq; precedence: 1; isNonAssociative: true),
    (operatorToken: lss; precedence: 1; isNonAssociative: true),
    (operatorToken: leq; precedence: 1; isNonAssociative: true),
    (operatorToken: gtr; precedence: 1; isNonAssociative: true),
    (operatorToken: geq; precedence: 1; isNonAssociative: true),
    (operatorToken: plus; precedence: 2; isNonAssociative: false),
    (operatorToken: minus; precedence: 2; isNonAssociative: false),
    (operatorToken: orsym; precedence: 2; isNonAssociative: false),
    (operatorToken: xorsym; precedence: 2; isNonAssociative: false),
    (operatorToken: times; precedence: 3; isNonAssociative: false),
    (operatorToken: slash; precedence: 3; isNonAssociative: false),
    (operatorToken: andsym; precedence: 3; isNonAssociative: false)
  );

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
            begin
                parseDeclarationType := typeInteger;
                readNextToken(errorCount)
            end
            else if lexerCurrentToken = booleansym then
            begin
                parseDeclarationType := typeBoolean;
                readNextToken(errorCount)
            end
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
                                                                        typeInteger,
                                                                        declarationSource);
                    readNextToken(errorCount)
                end
                else if lexerCurrentToken = truesym then
                begin
                    parseConstantDeclaration := newConstDeclarationNode(declarationIdentifier,
                                                                        1,
                                                                        declarationType,
                                                                        typeBoolean,
                                                                        declarationSource);
                    readNextToken(errorCount)
                end
                else if lexerCurrentToken = falsesym then
                begin
                    parseConstantDeclaration := newConstDeclarationNode(declarationIdentifier,
                                                                        0,
                                                                        declarationType,
                                                                        typeBoolean,
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

        function compileStatementSequence(statementFollowTokens: symbolSet): astNode;
        const whileBodyBoundaryTokens: symbolSet = [endsym, period, nul];
        var sequenceNode: astNode;
        begin
            sequenceNode := newCompoundStatementNode(statementSource);
            recoverIfUnexpectedToken(statementStartTokens+[ident],
                                     [endwhilesym]+whileBodyBoundaryTokens, ERR_STATEMENT_EXPECTED,
                                     errorCount);
            if lexerCurrentToken in whileBodyBoundaryTokens then
            begin
                reportCompilerError(ERR_SEMICOLON_OR_ENDWHILE_EXPECTED,
                                    lexerCurrentSourceContext, errorCount);
                compileStatementSequence := sequenceNode;
                exit
            end;
            while lexerCurrentToken <> endwhilesym do
            begin
                if lexerCurrentToken in whileBodyBoundaryTokens then
                begin
                    reportCompilerError(ERR_SEMICOLON_OR_ENDWHILE_EXPECTED,
                                        lexerCurrentSourceContext, errorCount);
                    break
                end;
                appendStatementNode(sequenceNode,
                                    compileStatement([semicolon, endwhilesym]+statementFollowTokens));
                if lexerCurrentToken = semicolon then
                    readNextToken(errorCount)
                else
                begin
                    reportCompilerError(ERR_SEMICOLON_OR_ENDWHILE_EXPECTED,
                                        lexerCurrentSourceContext, errorCount);
                    if not (lexerCurrentToken in statementStartTokens+[ident]) then
                        recoverIfUnexpectedToken([semicolon, endwhilesym]+statementStartTokens+[ident],
                                                 whileBodyBoundaryTokens,
                                             ERR_SEMICOLON_OR_ENDWHILE_EXPECTED, errorCount);
                    if lexerCurrentToken = semicolon then
                        readNextToken(errorCount)
                    else if lexerCurrentToken = endwhilesym then
                    begin
                        readNextToken(errorCount);
                        break
                    end
                    else if lexerCurrentToken in whileBodyBoundaryTokens then
                        break
                end
            end;
            if lexerCurrentToken = endwhilesym then
                readNextToken(errorCount);
            compileStatementSequence := sequenceNode
        end;

        {Parses an expression, including leading signs and additive operators.}
        function compileExpression(followTokens: symbolSet): astNode;
            var expressionNode: astNode;

            function binaryOperatorPrecedence(currentToken: symbol): integer;
                var precedenceEntry: binaryOperatorPrecedenceEntry;
            begin
                binaryOperatorPrecedence := 0;
                for precedenceEntry in binaryOperatorPrecedenceTable do
                    if precedenceEntry.operatorToken = currentToken then
                    begin
                        binaryOperatorPrecedence := precedenceEntry.precedence;
                        exit
                    end
            end {binaryOperatorPrecedence} ;

            function operatorIsNonAssociative(currentToken: symbol): boolean;
                var precedenceEntry: binaryOperatorPrecedenceEntry;
            begin
                operatorIsNonAssociative := false;
                for precedenceEntry in binaryOperatorPrecedenceTable do
                    if precedenceEntry.operatorToken = currentToken then
                    begin
                        operatorIsNonAssociative := precedenceEntry.isNonAssociative;
                        exit
                    end
            end {operatorIsNonAssociative} ;

            function compileExpressionWithPrecedence(minPrecedence: integer;
                                                     followTokens: symbolSet): astNode; forward;

            {Parses an identifier, number, or parenthesized expression.}
            function compilePrimary(followTokens: symbolSet): astNode;
                var primaryNode: astNode;
                    primarySource: sourceContext;
                    unaryOperator: symbol;
            begin
                compilePrimary := nil;
                recoverIfUnexpectedToken(factorStartTokens, followTokens, ERR_INVALID_TOKEN_AT_EXPRESSION_START,
                                         errorCount);
                while lexerCurrentToken in factorStartTokens do
                begin
                    if lexerCurrentToken in [plus, minus, notsym] then
                    begin
                        unaryOperator := lexerCurrentToken;
                        primarySource := lexerCurrentSourceContext;
                        readNextToken(errorCount);
                        primaryNode := newUnaryExpressionNode(unaryOperator, primarySource);
                        appendExpressionChild(primaryNode, compilePrimary(followTokens));
                        compilePrimary := primaryNode
                    end
                    else
                    if lexerCurrentToken = ident then
                    begin
                        primarySource := lexerCurrentSourceContext;
                        primaryNode := newIdentifierReferenceNode(lexerCurrentIdentifier, primarySource);
                        compilePrimary := primaryNode;
                        readNextToken(errorCount)
                    end
                        else
                            if lexerCurrentToken = number then
                        begin
                            primarySource := lexerCurrentSourceContext;
                            primaryNode := newNumberLiteralNode(lexerCurrentNumber, primarySource);
                            if lexerCurrentNumber > maxNumericValue then
                                reportCompilerError(ERR_NUMBER_TOO_LARGE, lexerCurrentSourceContext, errorCount);
                            compilePrimary := primaryNode;
                            readNextToken(errorCount)
                        end
                        else
                            if lexerCurrentToken = truesym then
                            begin
                                primarySource := lexerCurrentSourceContext;
                                primaryNode := newBooleanLiteralNode(true, primarySource);
                                compilePrimary := primaryNode;
                                readNextToken(errorCount)
                            end
                            else
                                if lexerCurrentToken = falsesym then
                                begin
                                    primarySource := lexerCurrentSourceContext;
                                    primaryNode := newBooleanLiteralNode(false, primarySource);
                                    compilePrimary := primaryNode;
                                    readNextToken(errorCount)
                                end
                        else
                            if lexerCurrentToken = lparen then
                            begin
                                primarySource := lexerCurrentSourceContext;
                                readNextToken(errorCount);
                                primaryNode := compileExpressionWithPrecedence(1, [rparen]+followTokens);
                                if lexerCurrentToken = rparen then
                                    readNextToken(errorCount)
                                else
                                    reportCompilerError(ERR_RIGHT_PARENTHESIS_MISSING, lexerCurrentSourceContext, errorCount);
                                compilePrimary := primaryNode
                            end;
                    recoverIfUnexpectedToken (followTokens, [lparen], ERR_INVALID_TOKEN_AFTER_FACTOR,
                                              errorCount)
                end
            end {compilePrimary} ;

            function compileExpressionWithPrecedence(minPrecedence: integer;
                                                     followTokens: symbolSet): astNode;
                var currentOperator: symbol;
                    operatorPrecedence: integer;
                    leftNode, rightNode, binaryNode: astNode;
                    operatorSource: sourceContext;
            begin
                leftNode := compilePrimary(followTokens+binaryOperatorTokens);
                operatorPrecedence := binaryOperatorPrecedence(lexerCurrentToken);
                while operatorPrecedence >= minPrecedence do
                begin
                    currentOperator := lexerCurrentToken;
                    operatorSource := lexerCurrentSourceContext;
                    readNextToken(errorCount);
                    rightNode := compileExpressionWithPrecedence(operatorPrecedence + 1,
                                                                 followTokens+binaryOperatorTokens);
                    binaryNode := newBinaryExpressionNode(currentOperator, operatorSource);
                    appendExpressionChild(binaryNode, leftNode);
                    appendExpressionChild(binaryNode, rightNode);
                    leftNode := binaryNode;
                    if operatorIsNonAssociative(currentOperator) then
                        operatorPrecedence := 0
                    else
                        operatorPrecedence := binaryOperatorPrecedence(lexerCurrentToken)
                end;
                compileExpressionWithPrecedence := leftNode
            end {compileExpressionWithPrecedence} ;

        begin {compileExpression}
            expressionNode := compileExpressionWithPrecedence(1, followTokens);
            compileExpression := expressionNode
        end {compileExpression} ;

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
                    appendChild(compileStatement, compileExpression([thensym, dosym]+followTokens));
                    if lexerCurrentToken = thensym then
                        readNextToken(errorCount)
                    else
                        reportCompilerError(ERR_THEN_EXPECTED, lexerCurrentSourceContext, errorCount);
                    appendStatementNode(compileStatement,
                                        compileStatement([endifsym]+followTokens));
                    if lexerCurrentToken = endifsym then
                        readNextToken(errorCount)
                    else
                        reportCompilerError(ERR_ENDIF_EXPECTED, lexerCurrentSourceContext, errorCount)
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
                            appendChild(compileStatement, compileExpression([dosym]+followTokens));
                            if lexerCurrentToken = dosym then
                                readNextToken(errorCount)
                            else
                                reportCompilerError(ERR_DO_EXPECTED, lexerCurrentSourceContext, errorCount);
                            appendStatementNode(compileStatement,
                                                compileStatementSequence(followTokens))
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
