{
From the book Algorithms + Data Structures = Programs, by Niklaus Wirth (1976)

Chapter 5, page 337

Program 5.6 PL/O Compiler with Code Generation

OCRed, cleaned, fixed, formatted, converted to modern Free Pascal
and tested by Daniel Toffetti.
Formatted with PTop (https://wiki.freepascal.org/PTop)


NOTE: This is a modified version of the original Program 5.6, changing
the code generation so that the code is emitted directly to a file, and
moving p-code interpretation to a separate program that reads the p-code
from the file and executes it.
This file contains the parser front end.
}

unit parser;
{PL/0 parser front end: parse source text into an AST}

{$mode objfpc}

interface

uses
  astree;

procedure parseFile(const inputFileName: string; var programNode: astNode; var errorCount: integer);

implementation

uses
  diagnostics, tokens, lexer, typetable;

const
  declarationStartTokens: symbolSet = [constsym, varsym, procsym, funcsym];
  statementStartTokens: symbolSet = [breaksym, continuesym, forsym, ifsym, repeatsym, returnsym, switchsym, whilesym];
  switchLabelStartTokens: symbolSet = [number, charlit, truesym, falsesym];
  factorStartTokens: symbolSet = [casesym, ident, number, charlit, truesym, falsesym, lparen, plus, minus, notsym];
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
    const blockBodyStartTokens: symbolSet = [beginsym];
    var declarationNode: astNode;         {AST node produced for one declaration}
        blockNode: astNode;      {AST node for the current block}
        activeDeclarationStartTokens: symbolSet;
        routineIdentifier: identifier;
        routineSource: sourceContext;

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
            else if lexerCurrentToken = charsym then
            begin
                parseDeclarationType := typeChar;
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
                else if lexerCurrentToken = charlit then
                begin
                    declarationValue := lexerCurrentCharValue;
                    parseConstantDeclaration := newConstDeclarationNode(declarationIdentifier,
                                                                        declarationValue,
                                                                        declarationType,
                                                                        typeChar,
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
                begin
                    reportCompilerError(ERR_NUMBER_EXPECTED_AFTER_EQUAL, lexerCurrentSourceContext, errorCount);
                    if lexerCurrentToken = nul then
                        readNextToken(errorCount);
                    while (lexerCurrentToken <> nul) and
                          not (lexerCurrentToken in [comma, semicolon, period]) do
                        readNextToken(errorCount)
                end
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

    procedure parseRoutineParameterList(routineNode: astNode; followTokens: symbolSet);
    var
      parameterNode: astNode;
      parameterCount: integer;
    begin
      parameterCount := 0;
      if lexerCurrentToken <> lparen then
        exit;

      readNextToken(errorCount);
      if lexerCurrentToken = rparen then
      begin
        readNextToken(errorCount);
        exit
      end;

      repeat
        parameterNode := parseVariableDeclaration;
        if parameterNode <> nil then
        begin
          parameterCount := parameterCount + 1;
          if parameterCount <= maxProcedureParameters then
            appendChild(routineNode, parameterNode)
          else
          begin
            reportCompilerError(ERR_PROCEDURE_PARAMETER_LIMIT_EXCEEDED,
                                parameterNode^.source, errorCount);
            freeAst(parameterNode)
          end
        end;

        if lexerCurrentToken = comma then
          readNextToken(errorCount)
        else
          break
      until false;

      if lexerCurrentToken = rparen then
        readNextToken(errorCount)
      else
      begin
        reportCompilerError(ERR_RIGHT_PARENTHESIS_MISSING, lexerCurrentSourceContext, errorCount);
        recoverIfUnexpectedToken([rparen], followTokens, ERR_RIGHT_PARENTHESIS_MISSING, errorCount);
        if lexerCurrentToken = rparen then
          readNextToken(errorCount)
      end
    end;

    function compileStatement (followTokens: symbolSet): astNode; forward;

    {Parses one statement into AST form.}
    function compileStatement (followTokens: symbolSet): astNode;
    var statementSource, elsifSource: sourceContext;
        elseBranchTarget: astNode;
        statementIdentifier: identifier;
        callNode: astNode;

        function compileExpression(followTokens: symbolSet): astNode; forward;

        procedure parseCallArguments(targetCallNode: astNode; argumentFollowTokens: symbolSet);
        var
          parsedArgument: astNode;
          argumentCount: integer;
        begin
          argumentCount := 0;
          if lexerCurrentToken = rparen then
          begin
            readNextToken(errorCount);
            exit
          end;

          repeat
            parsedArgument := compileExpression([comma, rparen] + argumentFollowTokens);
            argumentCount := argumentCount + 1;
            if argumentCount <= maxProcedureParameters then
              appendCallArgumentNode(targetCallNode, parsedArgument)
            else
            begin
              reportCompilerError(ERR_PROCEDURE_PARAMETER_LIMIT_EXCEEDED,
                                  lexerCurrentSourceContext, errorCount);
              freeAst(parsedArgument)
            end;

            if lexerCurrentToken = comma then
              readNextToken(errorCount)
            else
              break
          until false;

          if lexerCurrentToken = rparen then
            readNextToken(errorCount)
          else
          begin
            reportCompilerError(ERR_RIGHT_PARENTHESIS_MISSING, lexerCurrentSourceContext, errorCount);
            recoverIfUnexpectedToken([rparen], argumentFollowTokens, ERR_RIGHT_PARENTHESIS_MISSING, errorCount);
            if lexerCurrentToken = rparen then
              readNextToken(errorCount)
          end
        end;

        procedure parseReturnStatement(targetReturnNode: astNode; returnFollowTokens: symbolSet);
        begin
          appendExpressionChild(targetReturnNode,
                                compileExpression(returnFollowTokens))
        end;

        function compileStatementSequence(statementFollowTokens: symbolSet;
                                          closingTokens: symbolSet;
                                          missingDelimiterErrorCode: integer;
                                          missingClosingErrorCode: integer;
                                          boundaryTokens: symbolSet): astNode;
        var sequenceNode: astNode;
        begin
            sequenceNode := newCompoundStatementNode(statementSource);
            recoverIfUnexpectedToken(statementStartTokens+[ident],
                                     closingTokens+boundaryTokens, ERR_STATEMENT_EXPECTED,
                                     errorCount);
            if lexerCurrentToken in boundaryTokens then
            begin
                reportCompilerError(missingClosingErrorCode,
                                    lexerCurrentSourceContext, errorCount);
                compileStatementSequence := sequenceNode;
                exit
            end;
            while not (lexerCurrentToken in closingTokens) do
            begin
                if lexerCurrentToken in boundaryTokens then
                begin
                    reportCompilerError(missingClosingErrorCode,
                                        lexerCurrentSourceContext, errorCount);
                    break
                end;
                appendStatementNode(sequenceNode,
                                    compileStatement([semicolon]+closingTokens+statementFollowTokens));
                if lexerCurrentToken = semicolon then
                    readNextToken(errorCount)
                else
                begin
                    reportCompilerError(missingDelimiterErrorCode, lexerCurrentSourceContext, errorCount);
                    if not (lexerCurrentToken in statementStartTokens+[ident]) then
                        recoverIfUnexpectedToken([semicolon]+closingTokens+statementStartTokens+[ident],
                                                 boundaryTokens,
                                              missingDelimiterErrorCode, errorCount);
                    if lexerCurrentToken = semicolon then
                        readNextToken(errorCount)
                    else if lexerCurrentToken in closingTokens then
                        break
                    else if lexerCurrentToken in boundaryTokens then
                        break
                end
            end;
            compileStatementSequence := sequenceNode
        end;

        function compileSwitchLabel(labelFollowTokens: symbolSet): astNode;
        var
          labelSource: sourceContext;
        begin
            compileSwitchLabel := nil;
            if lexerCurrentToken = number then
            begin
                labelSource := lexerCurrentSourceContext;
                compileSwitchLabel := newNumberLiteralNode(lexerCurrentNumber, labelSource);
                if lexerCurrentNumber > maxNumericValue then
                    reportCompilerError(ERR_NUMBER_TOO_LARGE, lexerCurrentSourceContext, errorCount);
                readNextToken(errorCount)
            end
            else if lexerCurrentToken = charlit then
            begin
                labelSource := lexerCurrentSourceContext;
                compileSwitchLabel := newCharLiteralNode(lexerCurrentCharValue, labelSource);
                readNextToken(errorCount)
            end
            else if lexerCurrentToken = truesym then
            begin
                labelSource := lexerCurrentSourceContext;
                compileSwitchLabel := newBooleanLiteralNode(true, labelSource);
                readNextToken(errorCount)
            end
            else if lexerCurrentToken = falsesym then
            begin
                labelSource := lexerCurrentSourceContext;
                compileSwitchLabel := newBooleanLiteralNode(false, labelSource);
                readNextToken(errorCount)
            end
            else
                reportCompilerError(ERR_SWITCH_LABEL_EXPECTED, lexerCurrentSourceContext, errorCount);
            recoverIfUnexpectedToken(labelFollowTokens, [ ], ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT, errorCount)
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

            function compileCaseExpression(followTokens: symbolSet): astNode;
            var
              caseNode, caseArmNode: astNode;
              caseSource: sourceContext;
            begin
                caseSource := lexerCurrentSourceContext;
                caseNode := newCaseExpressionNode(whensym, caseSource);
                readNextToken(errorCount);

                if lexerCurrentToken <> whensym then
                begin
                    caseNode^.operatorSymbol := casesym;
                    appendExpressionChild(caseNode,
                                          compileExpressionWithPrecedence(1, [whensym] + followTokens))
                end;

                if lexerCurrentToken <> whensym then
                    reportCompilerError(ERR_WHEN_EXPECTED, lexerCurrentSourceContext, errorCount);

                while lexerCurrentToken = whensym do
                begin
                    caseArmNode := newCaseArmNode(lexerCurrentSourceContext);
                    readNextToken(errorCount);
                    appendExpressionChild(caseArmNode,
                                          compileExpressionWithPrecedence(1, [thensym] + followTokens));
                    if lexerCurrentToken = thensym then
                        readNextToken(errorCount)
                    else
                        reportCompilerError(ERR_THEN_EXPECTED, lexerCurrentSourceContext, errorCount);
                    appendExpressionChild(caseArmNode,
                                          compileExpressionWithPrecedence(1, [whensym, elsesym, endsym] +
                                                                             followTokens));
                    appendExpressionChild(caseNode, caseArmNode)
                end;

                if lexerCurrentToken = elsesym then
                begin
                    readNextToken(errorCount);
                    appendExpressionChild(caseNode,
                                          compileExpressionWithPrecedence(1, [endsym] + followTokens))
                end
                else
                    reportCompilerError(ERR_CASE_ELSE_EXPECTED, lexerCurrentSourceContext, errorCount);

                if lexerCurrentToken = endsym then
                    readNextToken(errorCount)
                else
                    reportCompilerError(ERR_END_EXPECTED, lexerCurrentSourceContext, errorCount);

                compileCaseExpression := caseNode
            end;

            {Parses an identifier, number, or parenthesized expression.}
            function compilePrimary(followTokens: symbolSet): astNode;
                var primaryNode: astNode;
                    primarySource: sourceContext;
                    unaryOperator: symbol;
            begin
                compilePrimary := nil;
                recoverIfUnexpectedToken(factorStartTokens, followTokens, ERR_INVALID_TOKEN_AT_EXPRESSION_START,
                                         errorCount);
                if lexerCurrentToken in [plus, minus, notsym] then
                begin
                    unaryOperator := lexerCurrentToken;
                    primarySource := lexerCurrentSourceContext;
                    readNextToken(errorCount);
                    primaryNode := newUnaryExpressionNode(unaryOperator, primarySource);
                    appendExpressionChild(primaryNode, compilePrimary(followTokens));
                    compilePrimary := primaryNode
                end
                else if lexerCurrentToken = casesym then
                    compilePrimary := compileCaseExpression(followTokens)
                else if lexerCurrentToken = ident then
                begin
                    primarySource := lexerCurrentSourceContext;
                    primaryNode := newIdentifierReferenceNode(lexerCurrentIdentifier, primarySource);
                    readNextToken(errorCount);
                    if lexerCurrentToken = lparen then
                    begin
                        compilePrimary := newCallExpressionNode(primarySource);
                        appendCalleeNode(compilePrimary, primaryNode);
                        readNextToken(errorCount);
                        parseCallArguments(compilePrimary, followTokens)
                    end
                    else
                        compilePrimary := primaryNode
                end
                else if lexerCurrentToken = number then
                begin
                    primarySource := lexerCurrentSourceContext;
                    primaryNode := newNumberLiteralNode(lexerCurrentNumber, primarySource);
                    if lexerCurrentNumber > maxNumericValue then
                        reportCompilerError(ERR_NUMBER_TOO_LARGE, lexerCurrentSourceContext, errorCount);
                    compilePrimary := primaryNode;
                    readNextToken(errorCount)
                end
                else if lexerCurrentToken = charlit then
                begin
                    primarySource := lexerCurrentSourceContext;
                    primaryNode := newCharLiteralNode(lexerCurrentCharValue, primarySource);
                    compilePrimary := primaryNode;
                    readNextToken(errorCount)
                end
                else if lexerCurrentToken = truesym then
                begin
                    primarySource := lexerCurrentSourceContext;
                    primaryNode := newBooleanLiteralNode(true, primarySource);
                    compilePrimary := primaryNode;
                    readNextToken(errorCount)
                end
                else if lexerCurrentToken = falsesym then
                begin
                    primarySource := lexerCurrentSourceContext;
                    primaryNode := newBooleanLiteralNode(false, primarySource);
                    compilePrimary := primaryNode;
                    readNextToken(errorCount)
                end
                else if lexerCurrentToken = lparen then
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
            statementIdentifier := lexerCurrentIdentifier;
            readNextToken(errorCount);
            if lexerCurrentToken = becomes then
            begin
                compileStatement := newAssignmentStatementNode(statementSource);
                appendExpressionChild(compileStatement,
                                      newIdentifierReferenceNode(statementIdentifier, statementSource));
                readNextToken(errorCount);
                appendExpressionChild(compileStatement, compileExpression(followTokens))
            end
            else if lexerCurrentToken = lparen then
            begin
                callNode := newCallStatementNode(statementSource);
                compileStatement := callNode;
                appendCalleeNode(callNode,
                                 newIdentifierReferenceNode(statementIdentifier, statementSource));
                readNextToken(errorCount);
                parseCallArguments(callNode, followTokens)
            end
            else
            begin
                compileStatement := newAssignmentStatementNode(statementSource);
                appendExpressionChild(compileStatement,
                                      newIdentifierReferenceNode(statementIdentifier, statementSource));
                reportCompilerError(ERR_IDENTIFIER_STATEMENT_MUST_BE_ASSIGNMENT_OR_CALL,
                                    lexerCurrentSourceContext, errorCount)
            end
        end
        else
            if lexerCurrentToken = returnsym then
                begin
                    statementSource := lexerCurrentSourceContext;
                    compileStatement := newReturnStatementNode(statementSource);
                    readNextToken(errorCount);
                    parseReturnStatement(compileStatement, followTokens)
                end
            else
            if lexerCurrentToken = breaksym then
                begin
                    statementSource := lexerCurrentSourceContext;
                    compileStatement := newBreakStatementNode(statementSource);
                    readNextToken(errorCount)
                end
            else
            if lexerCurrentToken = continuesym then
                begin
                    statementSource := lexerCurrentSourceContext;
                    compileStatement := newContinueStatementNode(statementSource);
                    readNextToken(errorCount)
                end
            else
            if lexerCurrentToken = ifsym then
                begin
                    statementSource := lexerCurrentSourceContext;
                    compileStatement := newIfStatementNode(statementSource);
                    readNextToken(errorCount);
                    appendChild(compileStatement, compileExpression([thensym]+followTokens));
                    if lexerCurrentToken = thensym then
                        readNextToken(errorCount)
                    else
                        reportCompilerError(ERR_THEN_EXPECTED, lexerCurrentSourceContext, errorCount);
                    appendStatementNode(compileStatement,
                                        compileStatementSequence(followTokens,
                                                                 [elsifsym, elsesym, endifsym],
                                                                 ERR_SEMICOLON_EXPECTED_BEFORE_ELSIF_ELSE_OR_ENDIF,
                                                                 ERR_ENDIF_EXPECTED,
                                                                 [endsym, period, nul]));
                    elseBranchTarget := compileStatement;
                    while lexerCurrentToken = elsifsym do
                    begin
                        elsifSource := lexerCurrentSourceContext;
                        readNextToken(errorCount);
                        appendStatementNode(elseBranchTarget,
                                            newIfStatementNode(elsifSource));
                        elseBranchTarget := elseBranchTarget^.firstChild;
                        while elseBranchTarget^.nextSibling <> nil do
                            elseBranchTarget := elseBranchTarget^.nextSibling;
                        appendChild(elseBranchTarget,
                                    compileExpression([thensym]+followTokens));
                        if lexerCurrentToken = thensym then
                            readNextToken(errorCount)
                        else
                            reportCompilerError(ERR_THEN_EXPECTED, lexerCurrentSourceContext, errorCount);
                        appendStatementNode(elseBranchTarget,
                                            compileStatementSequence(followTokens,
                                                                     [elsifsym, elsesym, endifsym],
                                                                     ERR_SEMICOLON_EXPECTED_BEFORE_ELSIF_ELSE_OR_ENDIF,
                                                                     ERR_ENDIF_EXPECTED,
                                                                     [endsym, period, nul]))
                    end;
                    if lexerCurrentToken = elsesym then
                    begin
                        readNextToken(errorCount);
                        appendStatementNode(elseBranchTarget,
                                            compileStatementSequence(followTokens,
                                                                     [endifsym],
                                                                     ERR_SEMICOLON_EXPECTED_BEFORE_ENDIF,
                                                                     ERR_ENDIF_EXPECTED,
                                                                     [endsym, period, nul]))
                    end;
                    if lexerCurrentToken = endifsym then
                        readNextToken(errorCount)
                    else
                        reportCompilerError(ERR_ENDIF_EXPECTED, lexerCurrentSourceContext, errorCount)
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
                                            compileStatementSequence(followTokens,
                                                                     [endwhilesym],
                                                                     ERR_SEMICOLON_OR_ENDWHILE_EXPECTED,
                                                                     ERR_SEMICOLON_OR_ENDWHILE_EXPECTED,
                                                                     [endsym, period, nul]));
                        if lexerCurrentToken = endwhilesym then
                            readNextToken(errorCount)
                        else if not (lexerCurrentToken in [endsym, period, nul]) then
                            reportCompilerError(ERR_SEMICOLON_OR_ENDWHILE_EXPECTED,
                                                lexerCurrentSourceContext, errorCount)
                        else
                            {The shared statement-sequence parser already reported
                             the missing loop terminator at structural boundaries.}
                    end
                    else if lexerCurrentToken = repeatsym then
                    begin
                        statementSource := lexerCurrentSourceContext;
                        compileStatement := newRepeatStatementNode(statementSource);
                        readNextToken(errorCount);
                        appendStatementNode(compileStatement,
                                            compileStatementSequence(followTokens,
                                                                     [untilsym],
                                                                     ERR_SEMICOLON_OR_UNTIL_EXPECTED,
                                                                     ERR_UNTIL_EXPECTED,
                                                                     [endsym, period, nul]));
                        if lexerCurrentToken = untilsym then
                            readNextToken(errorCount)
                        else if not (lexerCurrentToken in [endsym, period, nul]) then
                            reportCompilerError(ERR_UNTIL_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);
                        appendChild(compileStatement, compileExpression(followTokens))
                    end
                    else if lexerCurrentToken = forsym then
                    begin
                        statementSource := lexerCurrentSourceContext;
                        compileStatement := newForStatementNode(statementSource);
                        readNextToken(errorCount);
                        if lexerCurrentToken = ident then
                        begin
                            appendChild(compileStatement,
                                        newIdentifierReferenceNode(lexerCurrentIdentifier,
                                                                   lexerCurrentSourceContext));
                            readNextToken(errorCount)
                        end
                        else
                            reportCompilerError(ERR_FOR_CONTROL_VARIABLE_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);
                        if lexerCurrentToken = becomes then
                            readNextToken(errorCount)
                        else
                            reportCompilerError(ERR_BECOMES_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);
                        appendChild(compileStatement,
                                    compileExpression([tosym] + followTokens));
                        if lexerCurrentToken = tosym then
                            readNextToken(errorCount)
                        else
                            reportCompilerError(ERR_TO_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);
                        appendChild(compileStatement,
                                    compileExpression([bysym] + followTokens));
                        if lexerCurrentToken = bysym then
                            readNextToken(errorCount)
                        else
                            reportCompilerError(ERR_BY_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);
                        appendChild(compileStatement,
                                    compileExpression([dosym] + followTokens));
                        if lexerCurrentToken = dosym then
                            readNextToken(errorCount)
                        else
                            reportCompilerError(ERR_DO_EXPECTED, lexerCurrentSourceContext, errorCount);
                        appendStatementNode(compileStatement,
                                            compileStatementSequence(followTokens,
                                                                     [endforsym],
                                                                     ERR_SEMICOLON_OR_ENDFOR_EXPECTED,
                                                                     ERR_ENDFOR_EXPECTED,
                                                                     [endsym, period, nul]));
                        if lexerCurrentToken = endforsym then
                            readNextToken(errorCount)
                        else if not (lexerCurrentToken in [endsym, period, nul]) then
                            reportCompilerError(ERR_ENDFOR_EXPECTED,
                                                lexerCurrentSourceContext, errorCount)
                    end
                    else if lexerCurrentToken = switchsym then
                    begin
                        statementSource := lexerCurrentSourceContext;
                        compileStatement := newSwitchStatementNode(statementSource);
                        readNextToken(errorCount);
                        if lexerCurrentToken = ident then
                        begin
                            appendChild(compileStatement,
                                        newIdentifierReferenceNode(lexerCurrentIdentifier,
                                                                   lexerCurrentSourceContext));
                            readNextToken(errorCount)
                        end
                        else
                            reportCompilerError(ERR_SWITCH_IDENTIFIER_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);
                        if lexerCurrentToken = onsym then
                            readNextToken(errorCount)
                        else
                            reportCompilerError(ERR_ON_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);

                        if lexerCurrentToken in switchLabelStartTokens then
                        begin
                            while lexerCurrentToken in switchLabelStartTokens do
                            begin
                                appendStatementNode(compileStatement,
                                                    newSwitchCaseArmNode(lexerCurrentSourceContext));
                                elseBranchTarget := compileStatement^.firstChild;
                                while elseBranchTarget^.nextSibling <> nil do
                                    elseBranchTarget := elseBranchTarget^.nextSibling;
                                appendChild(elseBranchTarget,
                                            compileSwitchLabel([comma, thensym] + followTokens));
                                while lexerCurrentToken = comma do
                                begin
                                    readNextToken(errorCount);
                                    appendChild(elseBranchTarget,
                                                compileSwitchLabel([comma, thensym] + followTokens))
                                end;
                                if lexerCurrentToken = thensym then
                                    readNextToken(errorCount)
                                else
                                    reportCompilerError(ERR_THEN_EXPECTED, lexerCurrentSourceContext, errorCount);
                                appendStatementNode(elseBranchTarget,
                                                    compileStatementSequence(followTokens,
                                                                             [endsym],
                                                                             ERR_SEMICOLON_OR_END_EXPECTED,
                                                                             ERR_END_EXPECTED,
                                                                             switchLabelStartTokens + [elsesym, endswitchsym,
                                                                                                      period, nul]));
                                if lexerCurrentToken = endsym then
                                    readNextToken(errorCount)
                                else if not (lexerCurrentToken in switchLabelStartTokens + [elsesym, endswitchsym,
                                                                                           period, nul]) then
                                    reportCompilerError(ERR_END_EXPECTED,
                                                        lexerCurrentSourceContext, errorCount);
                                if lexerCurrentToken = semicolon then
                                    readNextToken(errorCount)
                                else if lexerCurrentToken in switchLabelStartTokens + [elsesym, endswitchsym] then
                                    reportCompilerError(ERR_SEMICOLON_EXPECTED_BEFORE_ELSE_OR_ENDSWITCH,
                                                        lexerCurrentSourceContext, errorCount)
                                else if lexerCurrentToken in [period, nul] then
                                begin
                                    reportCompilerError(ERR_ENDSWITCH_EXPECTED,
                                                        lexerCurrentSourceContext, errorCount);
                                    break
                                end
                            end
                        end
                        else
                            reportCompilerError(ERR_SWITCH_LABEL_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);

                        if lexerCurrentToken = elsesym then
                        begin
                            readNextToken(errorCount);
                            appendStatementNode(compileStatement,
                                                compileStatementSequence(followTokens,
                                                                         [endswitchsym],
                                                                         ERR_SEMICOLON_OR_ENDSWITCH_EXPECTED,
                                                                         ERR_ENDSWITCH_EXPECTED,
                                                                         [period, nul]))
                        end;

                        if lexerCurrentToken in switchLabelStartTokens then
                            reportCompilerError(ERR_SEMICOLON_EXPECTED_BEFORE_ELSE_OR_ENDSWITCH,
                                                lexerCurrentSourceContext, errorCount)
                        else if lexerCurrentToken in [period, nul] then
                            reportCompilerError(ERR_ENDSWITCH_EXPECTED,
                                                lexerCurrentSourceContext, errorCount);

                        if lexerCurrentToken = endswitchsym then
                            readNextToken(errorCount)
                        else if not (lexerCurrentToken in [endsym, period, nul]) then
                            reportCompilerError(ERR_ENDSWITCH_EXPECTED,
                                                lexerCurrentSourceContext, errorCount)
                    end ;
        recoverIfUnexpectedToken(followTokens, [ ], ERR_INCORRECT_SYMBOL_FOLLOWING_STATEMENT, errorCount)
     end {compileStatement} ;

    function compileBlockBody(statementFollowTokens: symbolSet): astNode;
    var
      bodyNode: astNode;
      bodySource: sourceContext;
    begin
        bodySource := lexerCurrentSourceContext;
        bodyNode := newCompoundStatementNode(bodySource);
        if lexerCurrentToken = beginsym then
            readNextToken(errorCount)
        else
            reportCompilerError(ERR_BLOCK_BEGIN_EXPECTED, lexerCurrentSourceContext, errorCount);
        recoverIfUnexpectedToken(statementStartTokens+[ident],
                                 [semicolon, endsym]+statementFollowTokens, ERR_STATEMENT_EXPECTED,
                                 errorCount);
        while lexerCurrentToken <> endsym do
        begin
            appendStatementNode(bodyNode,
                                compileStatement([semicolon, endsym]+statementFollowTokens));
            if lexerCurrentToken = semicolon then
                readNextToken(errorCount)
            else
            begin
                reportCompilerError(ERR_SEMICOLON_OR_END_EXPECTED,
                                    lexerCurrentSourceContext, errorCount);
                if not (lexerCurrentToken in statementStartTokens+[ident]) then
                    recoverIfUnexpectedToken([semicolon, endsym]+statementStartTokens+[ident],
                                             [period, nul]+statementFollowTokens,
                                             ERR_SEMICOLON_OR_END_EXPECTED, errorCount);
                if lexerCurrentToken = semicolon then
                    readNextToken(errorCount)
                else if lexerCurrentToken = endsym then
                    break
                else if lexerCurrentToken in [period, nul]+statementFollowTokens then
                begin
                    reportCompilerError(ERR_BLOCK_END_EXPECTED, lexerCurrentSourceContext, errorCount);
                    break
                end
            end
        end;
        if lexerCurrentToken = endsym then
            readNextToken(errorCount)
        else
            reportCompilerError(ERR_BLOCK_END_EXPECTED, lexerCurrentSourceContext, errorCount);
        compileBlockBody := bodyNode
    end;

begin {compileBlock}
    blockNode := newBlockNode(lexerCurrentSourceContext);
    activeDeclarationStartTokens := [constsym, varsym];
    if allowProcedureDeclarations then
        activeDeclarationStartTokens := activeDeclarationStartTokens + [procsym, funcsym];
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
        while allowProcedureDeclarations and (lexerCurrentToken in [procsym, funcsym]) do
        begin
            if currentLevel <> 0 then
            begin
                reportCompilerError(ERR_NESTED_PROCEDURES_NOT_SUPPORTED, lexerCurrentSourceContext, errorCount);
                readNextToken(errorCount);
                recoverIfUnexpectedToken([ident], [semicolon] + followTokens +
                                         blockBodyStartTokens + activeDeclarationStartTokens,
                                         ERR_DECLARATION_IDENTIFIER_EXPECTED, errorCount);
                while not (lexerCurrentToken in [semicolon] + followTokens +
                                        blockBodyStartTokens + activeDeclarationStartTokens) do
                    readNextToken(errorCount);
                continue
            end;
            if lexerCurrentToken = procsym then
            begin
                readNextToken(errorCount);
                if lexerCurrentToken = ident then
                begin
                    declarationNode := newProcedureDeclarationNode(lexerCurrentIdentifier, lexerCurrentSourceContext);
                    readNextToken(errorCount);
                    parseRoutineParameterList(declarationNode, [semicolon] + followTokens)
                end
                else
                    reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, lexerCurrentSourceContext, errorCount)
            end
            else
            begin
                readNextToken(errorCount);
                if lexerCurrentToken = ident then
                begin
                    routineIdentifier := lexerCurrentIdentifier;
                    routineSource := lexerCurrentSourceContext;
                    readNextToken(errorCount)
                end
                else
                    reportCompilerError(ERR_DECLARATION_IDENTIFIER_EXPECTED, lexerCurrentSourceContext, errorCount);
                declarationNode := newFunctionDeclarationNode(routineIdentifier,
                                                              typeInteger,
                                                              routineSource);
                parseRoutineParameterList(declarationNode, [colon, semicolon] + followTokens);
                declarationNode^.declaredType := parseDeclarationType([semicolon] + followTokens)
            end;
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
                recoverIfUnexpectedToken(blockBodyStartTokens +
                                         activeDeclarationStartTokens,
                                         followTokens + statementStartTokens + [ident],
                                         ERR_BLOCK_BEGIN_EXPECTED, errorCount)
            end
            else
                reportCompilerError(ERR_SEMICOLON_OR_COMMA_MISSING, lexerCurrentSourceContext, errorCount)
        end ;
        if (not allowProcedureDeclarations) and (lexerCurrentToken in [procsym, funcsym]) then
        begin
            reportCompilerError(ERR_NESTED_PROCEDURES_NOT_SUPPORTED, lexerCurrentSourceContext, errorCount);
            readNextToken(errorCount);
            recoverIfUnexpectedToken([ident], [semicolon] + followTokens +
                                     blockBodyStartTokens + activeDeclarationStartTokens,
                                     ERR_DECLARATION_IDENTIFIER_EXPECTED, errorCount);
            while not (lexerCurrentToken in [semicolon] + followTokens +
                                    blockBodyStartTokens + activeDeclarationStartTokens) do
                readNextToken(errorCount);
        end;
        recoverIfUnexpectedToken(blockBodyStartTokens, activeDeclarationStartTokens,
                                 ERR_STATEMENT_EXPECTED, errorCount)
    until not(lexerCurrentToken in activeDeclarationStartTokens);
    appendStatementNode(blockNode, compileBlockBody(followTokens));
    recoverIfUnexpectedToken(followTokens, [ ], ERR_INVALID_TOKEN_AFTER_STATEMENT_PART_IN_BLOCK, errorCount);
    compileBlock := blockNode
end {compileBlock} ;

procedure parseFile(const inputFileName: string; var programNode: astNode; var errorCount: integer);

    function parseProgramHeader: astNode;
        var programIdentifier: identifier;
            programSource: sourceContext;
    begin
        FillChar(programIdentifier, SizeOf(programIdentifier), ' ');
        programSource := lexerCurrentSourceContext;
        if lexerCurrentToken = programsym then
        begin
            readNextToken(errorCount);
            if lexerCurrentToken = ident then
            begin
                programIdentifier := lexerCurrentIdentifier;
                readNextToken(errorCount)
            end
            else
                reportCompilerError(ERR_PROGRAM_NAME_EXPECTED, lexerCurrentSourceContext, errorCount);
            if lexerCurrentToken = semicolon then
                readNextToken(errorCount)
            else
                reportCompilerError(ERR_PROGRAM_HEADER_SEMICOLON_EXPECTED,
                                    lexerCurrentSourceContext, errorCount)
        end
        else
            reportCompilerError(ERR_PROGRAM_HEADER_EXPECTED, lexerCurrentSourceContext, errorCount);
        parseProgramHeader := newProgramNode(programIdentifier, programSource)
    end;
begin
    initializeLexer(inputFileName, errorCount);
    programNode := parseProgramHeader;
    appendChild(programNode,
                compileBlock(0, [period]+declarationStartTokens+statementStartTokens, true, errorCount));
    if lexerCurrentToken <> period then
        reportCompilerError(ERR_PERIOD_EXPECTED, lexerCurrentSourceContext, errorCount);
    cleanupLexer
end {parseFile} ;

end.
