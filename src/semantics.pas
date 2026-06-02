{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-22

  First semantic-analysis pass for the parser pipeline.  This pass is intentionally
  narrow and read-only over the AST.  It currently owns:
  - declaration collection into a temporary symbol table
  - undeclared identifier checks
  - assignment target kind checks
  - procedure identifier rejection inside expressions
  - call target kind checks
  - top-level procedure nesting checks

  It does not mutate the AST or generate code. }
unit semantics;

{$mode objfpc}

interface

uses
  astree, symboltable;

procedure analyzeAst(rootNode: astNode; var errorCount: integer);
procedure clearSemanticInfo;
function hasResolvedSymbol(node: astNode): boolean;
function resolvedSymbolOf(node: astNode): symbolIndex;

implementation

uses
  diagnostics, tokens, typetable;

type
  semanticContext = record
    currentLevel: integer;
    nextAddress: integer;
  end;
  semanticBinding = ^semanticBindingRecord;
  semanticBindingRecord = record
    node: astNode;
    resolvedSymbol: symbolIndex;
    next: semanticBinding;
  end;

var
  semanticBindings: semanticBinding;

function isRelationalOperator(operatorSymbol: symbol): boolean;
begin
  isRelationalOperator := operatorSymbol in [eql, neq, lss, leq, gtr, geq]
end;

function isOrderingRelationalOperator(operatorSymbol: symbol): boolean;
begin
  isOrderingRelationalOperator := operatorSymbol in [lss, leq, gtr, geq]
end;

function isArithmeticBinaryOperator(operatorSymbol: symbol): boolean;
begin
  isArithmeticBinaryOperator := operatorSymbol in [plus, minus, times, slash]
end;

function isBooleanBinaryOperator(operatorSymbol: symbol): boolean;
begin
  isBooleanBinaryOperator := operatorSymbol in [andsym, orsym, xorsym]
end;

function isArithmeticUnaryOperator(operatorSymbol: symbol): boolean;
begin
  isArithmeticUnaryOperator := operatorSymbol in [plus, minus]
end;

function isBooleanUnaryOperator(operatorSymbol: symbol): boolean;
begin
  isBooleanUnaryOperator := operatorSymbol = notsym
end;

function nodeSourceContext(node: astNode): sourceContext;
begin
  nodeSourceContext := node^.source
end;

procedure requireBooleanExpression(node: astNode; var errorCount: integer);
begin
  if node = nil then
    exit;

  if (not hasNodeType(node)) or (getNodeType(node) <> typeBoolean) then
    reportCompilerError(ERR_BOOLEAN_CONDITION_REQUIRED, nodeSourceContext(node), errorCount)
end;

procedure requireMatchingAssignmentTypes(targetNode, valueNode: astNode; var errorCount: integer);
begin
  if (targetNode = nil) or (valueNode = nil) then
    exit;

  if hasNodeType(targetNode) and hasNodeType(valueNode) and
     (getNodeType(targetNode) <> getNodeType(valueNode)) then
    reportCompilerError(ERR_ASSIGNMENT_TYPE_MISMATCH, nodeSourceContext(valueNode), errorCount)
end;

procedure requireMatchingSwitchLabelType(selectorNode, labelNode: astNode; var errorCount: integer);
begin
  if (selectorNode = nil) or (labelNode = nil) then
    exit;

  if hasNodeType(selectorNode) and hasNodeType(labelNode) and
     (getNodeType(selectorNode) <> getNodeType(labelNode)) then
    reportCompilerError(ERR_SWITCH_LABEL_TYPE_MISMATCH,
                        nodeSourceContext(labelNode), errorCount)
end;

procedure requireMatchingCaseResultType(expectedNode, actualNode: astNode; var errorCount: integer);
begin
  if (expectedNode = nil) or (actualNode = nil) then
    exit;

  if hasNodeType(expectedNode) and hasNodeType(actualNode) and
     (getNodeType(expectedNode) <> getNodeType(actualNode)) then
    reportCompilerError(ERR_CASE_RESULT_TYPE_MISMATCH,
                        nodeSourceContext(actualNode), errorCount)
end;

procedure requireIntegerExpression(node: astNode; errorCode: integer; var errorCount: integer);
begin
  if node = nil then
    exit;

  if (not hasNodeType(node)) or (getNodeType(node) <> typeInteger) then
    reportCompilerError(errorCode, nodeSourceContext(node), errorCount)
end;

procedure requireOrderedExpression(node: astNode; errorCode: integer; var errorCount: integer);
begin
  if node = nil then
    exit;

  if (not hasNodeType(node)) or
     not (getNodeType(node) in [typeInteger, typeChar]) then
    reportCompilerError(errorCode, nodeSourceContext(node), errorCount)
end;

procedure requireBooleanOperand(node: astNode; var errorCount: integer);
begin
  if node = nil then
    exit;

  if (not hasNodeType(node)) or (getNodeType(node) <> typeBoolean) then
    reportCompilerError(ERR_BOOLEAN_OPERATOR_REQUIRES_BOOLEAN_OPERANDS,
                        nodeSourceContext(node), errorCount)
end;

procedure requireWriteArgumentType(node: astNode; var errorCount: integer);
begin
  if node = nil then
    exit;

  if (not hasNodeType(node)) or
     not (getNodeType(node) in [typeInteger, typeChar, typeBoolean]) then
    reportCompilerError(ERR_WRITE_ARGUMENT_TYPE_UNSUPPORTED,
                        nodeSourceContext(node), errorCount)
end;

procedure requireReadArgumentType(node: astNode; var errorCount: integer);
begin
  if node = nil then
    exit;

  if (not hasNodeType(node)) or
     not (getNodeType(node) in [typeInteger, typeChar, typeBoolean]) then
    reportCompilerError(ERR_READ_ARGUMENT_TYPE_UNSUPPORTED,
                        nodeSourceContext(node), errorCount)
end;

function findSemanticBinding(node: astNode): semanticBinding;
begin
  findSemanticBinding := semanticBindings;
  while (findSemanticBinding <> nil) and (findSemanticBinding^.node <> node) do
    findSemanticBinding := findSemanticBinding^.next
end;

procedure rememberResolvedSymbol(node: astNode; resolvedSymbol: symbolIndex);
var
  binding: semanticBinding;
begin
  if (node = nil) or (resolvedSymbol = 0) then
    exit;

  binding := findSemanticBinding(node);
  if binding = nil then
  begin
    New(binding);
    binding^.node := node;
    binding^.next := semanticBindings;
    semanticBindings := binding
  end;
  binding^.resolvedSymbol := resolvedSymbol
end;

procedure clearSemanticInfo;
var
  currentBinding, nextBinding: semanticBinding;
begin
  currentBinding := semanticBindings;
  while currentBinding <> nil do
  begin
    nextBinding := currentBinding^.next;
    Dispose(currentBinding);
    currentBinding := nextBinding
  end;
  semanticBindings := nil
end;

function hasResolvedSymbol(node: astNode): boolean;
begin
  hasResolvedSymbol := findSemanticBinding(node) <> nil
end;

function resolvedSymbolOf(node: astNode): symbolIndex;
var
  binding: semanticBinding;
begin
  binding := findSemanticBinding(node);
  if binding = nil then
    resolvedSymbolOf := 0
  else
    resolvedSymbolOf := binding^.resolvedSymbol
end;

procedure analyzeDeclaration(node: astNode; var sema: semanticContext; var errorCount: integer); forward;
procedure analyzeExpression(node: astNode; var sema: semanticContext; var errorCount: integer); forward;
procedure analyzeStatement(node: astNode; var sema: semanticContext; var errorCount: integer); forward;
procedure analyzeBlock(node: astNode; var sema: semanticContext; var errorCount: integer); forward;

procedure analyzeIdentifierReference(node: astNode; identifierUseIsExpression: boolean;
                                     var errorCount: integer);
var
  resolvedSymbol: symbolIndex;
begin
  resolvedSymbol := lookupSymbol(node^.identifierText);
  if resolvedSymbol = 0 then
    reportCompilerError(ERR_UNDECLARED_IDENTIFIER, nodeSourceContext(node), errorCount)
  else
  begin
    rememberResolvedSymbol(node, resolvedSymbol);
    setNodeType(node, getDeclarationType(resolvedSymbol));
    if identifierUseIsExpression and (getDeclarationKind(resolvedSymbol) = proc) then
      reportCompilerError(ERR_PROCEDURE_IDENTIFIER_IN_EXPRESSION, nodeSourceContext(node), errorCount)
  end
end;

procedure analyzeExpression(node: astNode; var sema: semanticContext; var errorCount: integer);
var
  childNode, leftNode, rightNode: astNode;
  selectorNode, caseArmNode, whenNode, resultNode, elseNode, firstResultNode: astNode;
begin
  if node = nil then
    exit;

  case node^.kind of
    astIdentifierReference:
      analyzeIdentifierReference(node, true, errorCount);
    astNumberLiteral:
      begin
        setNodeType(node, typeInteger);
        exit
      end;
    astCharLiteral:
      begin
        setNodeType(node, typeChar);
        exit
      end;
    astBooleanLiteral:
      begin
        setNodeType(node, typeBoolean);
        exit
      end;
    astUnaryExpression:
      begin
        childNode := node^.firstChild;
        while childNode <> nil do
        begin
          analyzeExpression(childNode, sema, errorCount);
          childNode := childNode^.nextSibling
        end;
        if isArithmeticUnaryOperator(node^.operatorSymbol) then
        begin
          requireIntegerExpression(node^.firstChild,
                                   ERR_ARITHMETIC_OPERATOR_REQUIRES_INTEGER_OPERANDS,
                                   errorCount);
          setNodeType(node, typeInteger)
        end
        else if isBooleanUnaryOperator(node^.operatorSymbol) then
        begin
          requireBooleanOperand(node^.firstChild, errorCount);
          setNodeType(node, typeBoolean)
        end
      end;
    astBinaryExpression:
      begin
        childNode := node^.firstChild;
        while childNode <> nil do
        begin
          analyzeExpression(childNode, sema, errorCount);
          childNode := childNode^.nextSibling
        end;
        leftNode := node^.firstChild;
        rightNode := nil;
        if leftNode <> nil then
          rightNode := leftNode^.nextSibling;
        if isRelationalOperator(node^.operatorSymbol) then
        begin
          if hasNodeType(leftNode) and hasNodeType(rightNode) and
             (getNodeType(leftNode) <> getNodeType(rightNode)) then
            reportCompilerError(ERR_RELATIONAL_OPERANDS_MUST_HAVE_MATCHING_TYPES,
                                nodeSourceContext(node), errorCount);
          if isOrderingRelationalOperator(node^.operatorSymbol) then
          begin
            requireOrderedExpression(leftNode, ERR_ORDERING_OPERATOR_REQUIRES_INTEGER_OPERANDS,
                                     errorCount);
            requireOrderedExpression(rightNode, ERR_ORDERING_OPERATOR_REQUIRES_INTEGER_OPERANDS,
                                     errorCount)
          end;
          setNodeType(node, typeBoolean)
        end
        else
        begin
          if isArithmeticBinaryOperator(node^.operatorSymbol) then
          begin
            requireIntegerExpression(leftNode, ERR_ARITHMETIC_OPERATOR_REQUIRES_INTEGER_OPERANDS,
                                     errorCount);
            requireIntegerExpression(rightNode, ERR_ARITHMETIC_OPERATOR_REQUIRES_INTEGER_OPERANDS,
                                     errorCount)
          end
          else if isBooleanBinaryOperator(node^.operatorSymbol) then
          begin
            requireBooleanOperand(leftNode, errorCount);
            requireBooleanOperand(rightNode, errorCount);
            setNodeType(node, typeBoolean)
          end;
          if isArithmeticBinaryOperator(node^.operatorSymbol) then
            setNodeType(node, typeInteger)
        end
      end;
    astCaseExpression:
      begin
        selectorNode := nil;
        caseArmNode := node^.firstChild;
        elseNode := node^.lastChild;
        firstResultNode := nil;

        if node^.operatorSymbol = casesym then
        begin
          selectorNode := node^.firstChild;
          if selectorNode <> nil then
          begin
            analyzeExpression(selectorNode, sema, errorCount);
            caseArmNode := selectorNode^.nextSibling
          end
        end;

        while caseArmNode <> nil do
        begin
          if caseArmNode^.kind <> astCaseArm then
            break;
          whenNode := caseArmNode^.firstChild;
          resultNode := nil;
          if whenNode <> nil then
            resultNode := whenNode^.nextSibling;
          analyzeExpression(whenNode, sema, errorCount);
          analyzeExpression(resultNode, sema, errorCount);
          if selectorNode <> nil then
            requireMatchingSwitchLabelType(selectorNode, whenNode, errorCount)
          else
            if (whenNode <> nil) and
               ((not hasNodeType(whenNode)) or (getNodeType(whenNode) <> typeBoolean)) then
              reportCompilerError(ERR_CASE_WHEN_CONDITION_MUST_BE_BOOLEAN,
                                  nodeSourceContext(whenNode), errorCount);
          if firstResultNode = nil then
            firstResultNode := resultNode
          else
            requireMatchingCaseResultType(firstResultNode, resultNode, errorCount);
          caseArmNode := caseArmNode^.nextSibling
        end;

        if (elseNode <> nil) and (elseNode^.kind <> astCaseArm) then
        begin
          analyzeExpression(elseNode, sema, errorCount);
          if firstResultNode = nil then
            firstResultNode := elseNode
          else
            requireMatchingCaseResultType(firstResultNode, elseNode, errorCount)
        end;

        if (firstResultNode <> nil) and hasNodeType(firstResultNode) then
          setNodeType(node, getNodeType(firstResultNode))
      end;
    astCaseArm:
      begin
        childNode := node^.firstChild;
        while childNode <> nil do
        begin
          analyzeExpression(childNode, sema, errorCount);
          childNode := childNode^.nextSibling
        end
      end
  else
    begin
      childNode := node^.firstChild;
      while childNode <> nil do
      begin
        analyzeExpression(childNode, sema, errorCount);
        childNode := childNode^.nextSibling
      end
    end
  end
end;

procedure analyzeDeclaration(node: astNode; var sema: semanticContext; var errorCount: integer);
var
  nestedContext: semanticContext;
  declaredSymbol: symbolIndex;
begin
  if node = nil then
    exit;

  case node^.kind of
    astConstDeclaration:
      begin
        if node^.declaredType <> node^.valueType then
          reportCompilerError(ERR_CONSTANT_TYPE_MISMATCH, nodeSourceContext(node), errorCount);
        declaredSymbol := addConstant(node^.identifierText, node^.numberValue,
                                      node^.declaredType);
        if declaredSymbol = 0 then
          reportCompilerError(ERR_SYMBOL_TABLE_OVERFLOW, nodeSourceContext(node), errorCount);
        setNodeType(node, node^.declaredType);
        rememberResolvedSymbol(node, declaredSymbol)
      end;
    astVarDeclaration:
      begin
        declaredSymbol := addVariable(node^.identifierText, sema.currentLevel, sema.nextAddress,
                                      node^.declaredType);
        if declaredSymbol = 0 then
          reportCompilerError(ERR_SYMBOL_TABLE_OVERFLOW, nodeSourceContext(node), errorCount);
        setNodeType(node, node^.declaredType);
        rememberResolvedSymbol(node, declaredSymbol)
      end;
    astProcedureDeclaration:
      begin
        if sema.currentLevel <> 0 then
        begin
          reportCompilerError(ERR_NESTED_PROCEDURES_NOT_SUPPORTED, nodeSourceContext(node), errorCount);
          reportCompilerError(ERR_PROCEDURES_GLOBAL_SCOPE_ONLY, nodeSourceContext(node), errorCount)
        end
        else
        begin
          declaredSymbol := addProcedure(node^.identifierText, sema.currentLevel);
          if declaredSymbol = 0 then
            reportCompilerError(ERR_SYMBOL_TABLE_OVERFLOW, nodeSourceContext(node), errorCount);
          rememberResolvedSymbol(node, declaredSymbol)
        end;

        if node^.firstChild <> nil then
        begin
          nestedContext.currentLevel := sema.currentLevel + 1;
          nestedContext.nextAddress := 3;
          analyzeBlock(node^.firstChild, nestedContext, errorCount)
        end
      end
  end
end;

procedure analyzeStatement(node: astNode; var sema: semanticContext; var errorCount: integer);
var
  targetNode, valueNode, conditionNode, thenOrBodyNode, elseNode, childNode, argumentNode: astNode;
  startNode, endNode, stepNode, bodyNode: astNode;
  selectorNode, caseNode, labelNode: astNode;
  resolvedSymbol: symbolIndex;
  builtinProc: builtinProcedure;
begin
  if node = nil then
    exit;

  case node^.kind of
    astCompoundStatement:
      begin
        childNode := node^.firstChild;
        while childNode <> nil do
        begin
          analyzeStatement(childNode, sema, errorCount);
          childNode := childNode^.nextSibling
        end
      end;
    astAssignmentStatement:
      begin
        targetNode := node^.firstChild;
        valueNode := nil;
        if targetNode <> nil then
          valueNode := targetNode^.nextSibling;

        if targetNode <> nil then
        begin
          resolvedSymbol := lookupSymbol(targetNode^.identifierText);
          if resolvedSymbol = 0 then
            reportCompilerError(ERR_UNDECLARED_IDENTIFIER, nodeSourceContext(targetNode), errorCount)
          else
          begin
            rememberResolvedSymbol(targetNode, resolvedSymbol);
            setNodeType(targetNode, getDeclarationType(resolvedSymbol));
            if getDeclarationKind(resolvedSymbol) <> variable then
              reportCompilerError(ERR_ASSIGNMENT_TO_CONSTANT_OR_PROCEDURE,
                                  nodeSourceContext(targetNode), errorCount)
          end
        end;

        analyzeExpression(valueNode, sema, errorCount);
        requireMatchingAssignmentTypes(targetNode, valueNode, errorCount)
      end;
    astCallStatement:
      begin
        targetNode := node^.firstChild;
        resolvedSymbol := 0;
        builtinProc := builtinNone;
        argumentNode := nil;
        if targetNode <> nil then
          argumentNode := targetNode^.nextSibling;
        if targetNode <> nil then
        begin
          resolvedSymbol := lookupSymbol(targetNode^.identifierText);
          builtinProc := builtinNone;
          if resolvedSymbol = 0 then
            reportCompilerError(ERR_UNDECLARED_IDENTIFIER, nodeSourceContext(targetNode), errorCount)
          else
          begin
            rememberResolvedSymbol(targetNode, resolvedSymbol);
            setNodeType(targetNode, getDeclarationType(resolvedSymbol));
            builtinProc := getBuiltinProcedure(resolvedSymbol);
            if getDeclarationKind(resolvedSymbol) <> proc then
              reportCompilerError(ERR_CALL_OF_CONSTANT_OR_VARIABLE,
                                  nodeSourceContext(targetNode), errorCount)
          end
        end;
        if (resolvedSymbol <> 0) and (builtinProc in [builtinWrite, builtinWriteLn]) then
        begin
          if argumentNode = nil then
            reportCompilerError(ERR_WRITE_REQUIRES_ARGUMENT,
                                nodeSourceContext(targetNode), errorCount)
          else
          begin
            analyzeExpression(argumentNode, sema, errorCount);
            requireWriteArgumentType(argumentNode, errorCount)
          end
        end
        else if (resolvedSymbol <> 0) and (builtinProc in [builtinRead, builtinReadLn]) then
        begin
          if argumentNode = nil then
            reportCompilerError(ERR_READ_REQUIRES_ARGUMENT,
                                nodeSourceContext(targetNode), errorCount)
          else
          begin
            analyzeExpression(argumentNode, sema, errorCount);
            if argumentNode^.kind <> astIdentifierReference then
              reportCompilerError(ERR_READ_ARGUMENT_MUST_BE_VARIABLE,
                                  nodeSourceContext(argumentNode), errorCount)
            else if (not hasResolvedSymbol(argumentNode)) or
                    (getDeclarationKind(resolvedSymbolOf(argumentNode)) <> variable) then
              reportCompilerError(ERR_READ_ARGUMENT_MUST_BE_VARIABLE,
                                  nodeSourceContext(argumentNode), errorCount)
            else
              requireReadArgumentType(argumentNode, errorCount)
          end
        end
        else
        begin
          if argumentNode <> nil then
            reportCompilerError(ERR_PROCEDURE_ARGUMENTS_NOT_YET_SUPPORTED,
                                nodeSourceContext(argumentNode), errorCount);
          while argumentNode <> nil do
          begin
            analyzeExpression(argumentNode, sema, errorCount);
            argumentNode := argumentNode^.nextSibling
          end
        end
      end;
    astIfStatement:
      begin
        conditionNode := node^.firstChild;
        thenOrBodyNode := nil;
        elseNode := nil;
        if conditionNode <> nil then
          thenOrBodyNode := conditionNode^.nextSibling;
        if thenOrBodyNode <> nil then
          elseNode := thenOrBodyNode^.nextSibling;
        analyzeExpression(conditionNode, sema, errorCount);
        requireBooleanExpression(conditionNode, errorCount);
        analyzeStatement(thenOrBodyNode, sema, errorCount);
        analyzeStatement(elseNode, sema, errorCount)
      end;
    astWhileStatement:
      begin
        conditionNode := node^.firstChild;
        thenOrBodyNode := nil;
        if conditionNode <> nil then
          thenOrBodyNode := conditionNode^.nextSibling;
        analyzeExpression(conditionNode, sema, errorCount);
        requireBooleanExpression(conditionNode, errorCount);
        analyzeStatement(thenOrBodyNode, sema, errorCount)
      end;
    astRepeatStatement:
      begin
        thenOrBodyNode := node^.firstChild;
        conditionNode := nil;
        if thenOrBodyNode <> nil then
          conditionNode := thenOrBodyNode^.nextSibling;
        analyzeStatement(thenOrBodyNode, sema, errorCount);
        analyzeExpression(conditionNode, sema, errorCount);
        requireBooleanExpression(conditionNode, errorCount)
      end;
    astForStatement:
      begin
        targetNode := node^.firstChild;
        startNode := nil;
        endNode := nil;
        stepNode := nil;
        bodyNode := nil;
        if targetNode <> nil then
          startNode := targetNode^.nextSibling;
        if startNode <> nil then
          endNode := startNode^.nextSibling;
        if endNode <> nil then
          stepNode := endNode^.nextSibling;
        if stepNode <> nil then
          bodyNode := stepNode^.nextSibling;

        if targetNode <> nil then
        begin
          resolvedSymbol := lookupSymbol(targetNode^.identifierText);
          if resolvedSymbol = 0 then
            reportCompilerError(ERR_UNDECLARED_IDENTIFIER, nodeSourceContext(targetNode), errorCount)
          else
          begin
            rememberResolvedSymbol(targetNode, resolvedSymbol);
            setNodeType(targetNode, getDeclarationType(resolvedSymbol));
            if (getDeclarationKind(resolvedSymbol) <> variable) or
               (getDeclarationType(resolvedSymbol) <> typeInteger) then
              reportCompilerError(ERR_FOR_COUNTER_MUST_BE_INTEGER_VARIABLE,
                                  nodeSourceContext(targetNode), errorCount)
          end
        end;

        analyzeExpression(startNode, sema, errorCount);
        analyzeExpression(endNode, sema, errorCount);
        analyzeExpression(stepNode, sema, errorCount);
        requireIntegerExpression(startNode, ERR_FOR_RANGE_MUST_BE_INTEGER, errorCount);
        requireIntegerExpression(endNode, ERR_FOR_RANGE_MUST_BE_INTEGER, errorCount);
        requireIntegerExpression(stepNode, ERR_FOR_RANGE_MUST_BE_INTEGER, errorCount);
        analyzeStatement(bodyNode, sema, errorCount)
      end;
    astSwitchStatement:
      begin
        selectorNode := node^.firstChild;
        caseNode := nil;
        if selectorNode <> nil then
          caseNode := selectorNode^.nextSibling;

        analyzeExpression(selectorNode, sema, errorCount);
        while caseNode <> nil do
        begin
          if caseNode^.kind = astSwitchCaseArm then
          begin
            labelNode := caseNode^.firstChild;
            bodyNode := nil;
            if labelNode <> nil then
              bodyNode := labelNode^.nextSibling;
            analyzeExpression(labelNode, sema, errorCount);
            requireMatchingSwitchLabelType(selectorNode, labelNode, errorCount);
            analyzeStatement(bodyNode, sema, errorCount)
          end
          else
            analyzeStatement(caseNode, sema, errorCount);
          caseNode := caseNode^.nextSibling
        end
      end
  else
    analyzeExpression(node, sema, errorCount)
  end
end;

procedure analyzeBlock(node: astNode; var sema: semanticContext; var errorCount: integer);
var
  scopeMarker: symbolIndex;
  childNode: astNode;
begin
  if node = nil then
    exit;

  scopeMarker := markScope;
  childNode := node^.firstChild;
  while childNode <> nil do
  begin
    case childNode^.kind of
      astConstDeclaration, astVarDeclaration, astProcedureDeclaration:
        analyzeDeclaration(childNode, sema, errorCount);
      astCompoundStatement,
      astAssignmentStatement,
      astCallStatement,
      astIfStatement,
      astWhileStatement,
      astRepeatStatement,
      astForStatement,
      astSwitchStatement:
        analyzeStatement(childNode, sema, errorCount)
    else
      analyzeExpression(childNode, sema, errorCount)
    end;
    childNode := childNode^.nextSibling
  end;
  restoreScope(scopeMarker)
end;

procedure analyzeAst(rootNode: astNode; var errorCount: integer);
var
  sema: semanticContext;
begin
  if rootNode = nil then
  begin
    emitDiagnostic(debug, '[SEMA] no AST to analyze');
    exit
  end;

  clearSemanticInfo;
  initializeSymbolTable;
  sema.currentLevel := 0;
  sema.nextAddress := 3;

  if rootNode^.kind = astProgram then
    analyzeBlock(rootNode^.firstChild, sema, errorCount)
  else
    analyzeBlock(rootNode, sema, errorCount)
end;

initialization
  semanticBindings := nil;

finalization
  clearSemanticInfo;

end.
