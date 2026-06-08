{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-06-07

  AST-to-HLIR lowering support for the structured frontend pipeline.

  This unit walks the semantically analyzed AST and builds a structured HLIR
  program image.  It preserves source-level routine, statement, and expression
  shape rather than flattening control flow or storage effects.  It does not
  perform semantic checks, CFG construction, stack-frame assignment, or TAC/LIR
  lowering. }
unit asttohlir;

{$mode objfpc}

interface

uses
  astree, hlir;

procedure lowerAstToHirProgram(rootNode: astNode;
                               var programData: hirProgramRecord;
                               var errorCount: integer);

implementation

uses
  semantics, symboltable, tokens, typetable;

function nextRoutineId(var state: hirState): integer;
begin
  state.nextRoutineId := state.nextRoutineId + 1;
  nextRoutineId := state.nextRoutineId
end;

function nextDeclarationId(var state: hirState): integer;
begin
  state.nextDeclarationId := state.nextDeclarationId + 1;
  nextDeclarationId := state.nextDeclarationId
end;

function nextStatementId(var state: hirState): integer;
begin
  state.nextStatementId := state.nextStatementId + 1;
  nextStatementId := state.nextStatementId
end;

function nextExpressionId(var state: hirState): integer;
begin
  state.nextExpressionId := state.nextExpressionId + 1;
  nextExpressionId := state.nextExpressionId
end;

function nextSwitchArmId(var state: hirState): integer;
begin
  state.nextSwitchArmId := state.nextSwitchArmId + 1;
  nextSwitchArmId := state.nextSwitchArmId
end;

function nextCaseArmId(var state: hirState): integer;
begin
  state.nextCaseArmId := state.nextCaseArmId + 1;
  nextCaseArmId := state.nextCaseArmId
end;

function routineBlockNode(node: astNode): astNode;
begin
  routineBlockNode := node^.firstChild;
  while (routineBlockNode <> nil) and
        (routineBlockNode^.kind = astVarDeclaration) do
    routineBlockNode := routineBlockNode^.nextSibling
end;

function nodeTypeRef(node: astNode): hirTypeRef;
begin
  if (node <> nil) and hasNodeType(node) then
    nodeTypeRef := makeHirTypeRef(getNodeType(node))
  else if node <> nil then
    nodeTypeRef := makeHirTypeRef(node^.declaredType)
  else
    nodeTypeRef := makeHirTypeRef(typeInteger)
end;

function symbolRefFromNode(node: astNode): hirSymbolRef;
var
  resolvedSymbol: symbolIndex;
  identifierName: identifier;
  declaredType: typeValue;
  declaredKind: declarationKind;
begin
  FillChar(symbolRefFromNode, SizeOf(symbolRefFromNode), 0);
  declaredType := typeInteger;
  declaredKind := variable;
  FillChar(identifierName, SizeOf(identifierName), ' ');

  if (node <> nil) and hasResolvedSymbol(node) then
  begin
    resolvedSymbol := resolvedSymbolOf(node);
    declaredType := getDeclarationType(resolvedSymbol);
    declaredKind := getDeclarationKind(resolvedSymbol);
    identifierName := getDeclarationIdentifier(resolvedSymbol);
    symbolRefFromNode := makeHirSymbolRef(resolvedSymbol,
                                          identifierName,
                                          declaredKind,
                                          declaredType)
  end
  else if node <> nil then
    symbolRefFromNode := makeHirSymbolRef(0,
                                          identifierName,
                                          declaredKind,
                                          declaredType)
end;

function newHirDeclaration(var state: hirState;
                           kind: hirDeclarationKind;
                           node: astNode): hirDeclaration;
begin
  New(newHirDeclaration);
  FillChar(newHirDeclaration^, SizeOf(newHirDeclaration^), 0);
  newHirDeclaration^.id := nextDeclarationId(state);
  newHirDeclaration^.kind := kind;
  if node <> nil then
  begin
    newHirDeclaration^.source := node^.source;
    newHirDeclaration^.symbolInfo := symbolRefFromNode(node);
  end
end;

function newHirStatement(var state: hirState;
                         kind: hirStatementKind;
                         node: astNode): hirStatement;
begin
  New(newHirStatement);
  FillChar(newHirStatement^, SizeOf(newHirStatement^), 0);
  newHirStatement^.id := nextStatementId(state);
  newHirStatement^.kind := kind;
  if node <> nil then
    newHirStatement^.source := node^.source
end;

function newHirExpression(var state: hirState;
                          kind: hirExpressionKind;
                          node: astNode): hirExpression;
begin
  New(newHirExpression);
  FillChar(newHirExpression^, SizeOf(newHirExpression^), 0);
  newHirExpression^.id := nextExpressionId(state);
  newHirExpression^.kind := kind;
  if node <> nil then
  begin
    newHirExpression^.source := node^.source;
    newHirExpression^.valueType := nodeTypeRef(node)
  end
end;

function newHirRoutine(var state: hirState;
                       kind: hirRoutineKind;
                       node: astNode): hirRoutine;
begin
  New(newHirRoutine);
  FillChar(newHirRoutine^, SizeOf(newHirRoutine^), 0);
  newHirRoutine^.id := nextRoutineId(state);
  newHirRoutine^.kind := kind;
  if node <> nil then
  begin
    newHirRoutine^.source := node^.source;
    newHirRoutine^.name := node^.identifierText;
    if hasResolvedSymbol(node) then
      newHirRoutine^.symbol := resolvedSymbolOf(node);
    newHirRoutine^.returnType := nodeTypeRef(node);
    newHirRoutine^.hasReturnValue := kind = hirRoutineFunction
  end
  else
    newHirRoutine^.returnType := makeHirTypeRef(typeInteger)
end;

function newHirSwitchArm(var state: hirState; node: astNode): hirSwitchArm;
begin
  New(newHirSwitchArm);
  FillChar(newHirSwitchArm^, SizeOf(newHirSwitchArm^), 0);
  newHirSwitchArm^.id := nextSwitchArmId(state);
  if node <> nil then
    newHirSwitchArm^.source := node^.source
end;

function newHirSwitchLabel(node: astNode): hirSwitchLabel;
begin
  New(newHirSwitchLabel);
  FillChar(newHirSwitchLabel^, SizeOf(newHirSwitchLabel^), 0);
  if node <> nil then
  begin
    newHirSwitchLabel^.source := node^.source;
    newHirSwitchLabel^.valueType := nodeTypeRef(node);
    newHirSwitchLabel^.value := node^.numberValue
  end
end;

function newHirCaseArm(var state: hirState; node: astNode): hirCaseArm;
begin
  New(newHirCaseArm);
  FillChar(newHirCaseArm^, SizeOf(newHirCaseArm^), 0);
  newHirCaseArm^.id := nextCaseArmId(state);
  if node <> nil then
    newHirCaseArm^.source := node^.source
end;

procedure appendProgramGlobal(var programData: hirProgramRecord;
                              declarationNode: hirDeclaration);
begin
  if declarationNode = nil then
    exit;

  if programData.firstGlobal = nil then
    programData.firstGlobal := declarationNode
  else
    programData.lastGlobal^.nextSibling := declarationNode;
  programData.lastGlobal := declarationNode;
  programData.globalCount := programData.globalCount + 1
end;

procedure appendProgramRoutine(var programData: hirProgramRecord;
                               routineNode: hirRoutine);
begin
  if routineNode = nil then
    exit;

  if programData.firstRoutine = nil then
    programData.firstRoutine := routineNode
  else
    programData.lastRoutine^.nextSibling := routineNode;
  programData.lastRoutine := routineNode;
  programData.routineCount := programData.routineCount + 1
end;

procedure appendRoutineParameter(routineNode: hirRoutine;
                                 declarationNode: hirDeclaration);
begin
  if (routineNode = nil) or (declarationNode = nil) then
    exit;

  if routineNode^.firstParameter = nil then
    routineNode^.firstParameter := declarationNode
  else
    routineNode^.lastParameter^.nextSibling := declarationNode;
  routineNode^.lastParameter := declarationNode;
  routineNode^.parameterCount := routineNode^.parameterCount + 1
end;

procedure appendRoutineLocal(routineNode: hirRoutine;
                             declarationNode: hirDeclaration);
begin
  if (routineNode = nil) or (declarationNode = nil) then
    exit;

  if routineNode^.firstLocal = nil then
    routineNode^.firstLocal := declarationNode
  else
    routineNode^.lastLocal^.nextSibling := declarationNode;
  routineNode^.lastLocal := declarationNode;
  routineNode^.localCount := routineNode^.localCount + 1
end;

procedure appendStatementChild(parentStatement, childStatement: hirStatement);
begin
  if (parentStatement = nil) or (childStatement = nil) then
    exit;

  if parentStatement^.firstChild = nil then
    parentStatement^.firstChild := childStatement
  else
    parentStatement^.lastChild^.nextSibling := childStatement;
  parentStatement^.lastChild := childStatement
end;

procedure appendCallArgument(var callSite: hirCallSite; argumentExpression: hirExpression);
begin
  if argumentExpression = nil then
    exit;

  if callSite.firstArgument = nil then
    callSite.firstArgument := argumentExpression
  else
    callSite.lastArgument^.nextSibling := argumentExpression;
  callSite.lastArgument := argumentExpression;
  callSite.argumentCount := callSite.argumentCount + 1
end;

procedure appendSwitchArm(statementNode: hirStatement; armNode: hirSwitchArm);
begin
  if (statementNode = nil) or (armNode = nil) then
    exit;

  if statementNode^.firstSwitchArm = nil then
    statementNode^.firstSwitchArm := armNode
  else
    statementNode^.lastSwitchArm^.nextSibling := armNode;
  statementNode^.lastSwitchArm := armNode
end;

procedure appendSwitchLabel(armNode: hirSwitchArm; labelNode: hirSwitchLabel);
begin
  if (armNode = nil) or (labelNode = nil) then
    exit;

  if armNode^.firstLabel = nil then
    armNode^.firstLabel := labelNode
  else
    armNode^.lastLabel^.nextSibling := labelNode;
  armNode^.lastLabel := labelNode;
  armNode^.labelCount := armNode^.labelCount + 1
end;

procedure appendCaseArm(expressionNode: hirExpression; armNode: hirCaseArm);
begin
  if (expressionNode = nil) or (armNode = nil) then
    exit;

  if expressionNode^.firstCaseArm = nil then
    expressionNode^.firstCaseArm := armNode
  else
    expressionNode^.lastCaseArm^.nextSibling := armNode;
  expressionNode^.lastCaseArm := armNode
end;

function callSiteFromCallNode(var state: hirState; callNode: astNode;
                              var errorCount: integer): hirCallSite; forward;
function lowerExpression(var state: hirState; node: astNode;
                         var errorCount: integer): hirExpression; forward;
function lowerStatement(var state: hirState; node: astNode;
                        var errorCount: integer): hirStatement; forward;
function lowerStatementSequence(var state: hirState; firstNode: astNode;
                                var errorCount: integer): hirStatement; forward;

function lowerDeclaration(var state: hirState; node: astNode): hirDeclaration;
begin
  lowerDeclaration := nil;
  if node = nil then
    exit;

  case node^.kind of
    astConstDeclaration:
      begin
        lowerDeclaration := newHirDeclaration(state, hirDeclConstant, node);
        lowerDeclaration^.constantValue := node^.numberValue
      end;
    astVarDeclaration:
      lowerDeclaration := newHirDeclaration(state, hirDeclVariable, node)
  end
end;

procedure collectRoutineParameters(var state: hirState; routineNodeAst: astNode;
                                   routineNode: hirRoutine);
var
  childNode: astNode;
  parameterDecl: hirDeclaration;
begin
  if (routineNodeAst = nil) or (routineNode = nil) then
    exit;

  childNode := routineNodeAst^.firstChild;
  while (childNode <> nil) and (childNode^.kind = astVarDeclaration) do
  begin
    parameterDecl := newHirDeclaration(state, hirDeclParameter, childNode);
    appendRoutineParameter(routineNode, parameterDecl);
    childNode := childNode^.nextSibling
  end
end;

procedure collectBlockLocalDeclarations(var state: hirState; blockNode: astNode;
                                        routineNode: hirRoutine);
var
  childNode: astNode;
  localDecl: hirDeclaration;
begin
  if (blockNode = nil) or (routineNode = nil) then
    exit;

  childNode := blockNode^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind in [astConstDeclaration, astVarDeclaration] then
    begin
      localDecl := lowerDeclaration(state, childNode);
      appendRoutineLocal(routineNode, localDecl)
    end
    else if childNode^.kind in [astProcedureDeclaration, astFunctionDeclaration,
                                astCompoundStatement, astAssignmentStatement,
                                astCallStatement, astReturnStatement,
                                astBreakStatement, astContinueStatement,
                                astIfStatement, astWhileStatement,
                                astRepeatStatement, astForStatement,
                                astSwitchStatement] then
      break;
    childNode := childNode^.nextSibling
  end
end;

function lowerIdentifierExpression(var state: hirState; node: astNode): hirExpression;
begin
  lowerIdentifierExpression := newHirExpression(state, hirExprSymbol, node);
  lowerIdentifierExpression^.symbolInfo := symbolRefFromNode(node)
end;

function lowerLiteralExpression(var state: hirState; node: astNode): hirExpression;
begin
  case node^.kind of
    astNumberLiteral:
      lowerLiteralExpression := newHirExpression(state, hirExprIntegerLiteral, node);
    astBooleanLiteral:
      lowerLiteralExpression := newHirExpression(state, hirExprBooleanLiteral, node);
    astCharLiteral:
      lowerLiteralExpression := newHirExpression(state, hirExprCharLiteral, node)
  else
    lowerLiteralExpression := newHirExpression(state, hirExprIntegerLiteral, node)
  end;
  lowerLiteralExpression^.literalValue := node^.numberValue
end;

function lowerUnaryExpression(var state: hirState; node: astNode;
                              var errorCount: integer): hirExpression;
begin
  lowerUnaryExpression := newHirExpression(state, hirExprUnary, node);
  if not hirUnaryOperatorFromSymbol(node^.operatorSymbol,
                                    lowerUnaryExpression^.unaryOperator) then
    lowerUnaryExpression^.unaryOperator := hirUnaryNegate;
  lowerUnaryExpression^.operand := lowerExpression(state, node^.firstChild, errorCount)
end;

function lowerBinaryExpression(var state: hirState; node: astNode;
                               var errorCount: integer): hirExpression;
var
  leftNode, rightNode: astNode;
begin
  lowerBinaryExpression := newHirExpression(state, hirExprBinary, node);
  if not hirBinaryOperatorFromSymbol(node^.operatorSymbol,
                                     lowerBinaryExpression^.binaryOperator) then
    lowerBinaryExpression^.binaryOperator := hirBinaryAdd;

  leftNode := node^.firstChild;
  rightNode := nil;
  if leftNode <> nil then
    rightNode := leftNode^.nextSibling;
  lowerBinaryExpression^.leftOperand := lowerExpression(state, leftNode, errorCount);
  lowerBinaryExpression^.rightOperand := lowerExpression(state, rightNode, errorCount)
end;

function callSiteFromCallNode(var state: hirState; callNode: astNode;
                              var errorCount: integer): hirCallSite;
var
  calleeNode, argumentNode: astNode;
begin
  FillChar(callSiteFromCallNode, SizeOf(callSiteFromCallNode), 0);
  if callNode = nil then
    exit;

  calleeNode := callNode^.firstChild;
  if calleeNode = nil then
    exit;

  callSiteFromCallNode.targetSymbol := symbolRefFromNode(calleeNode);
  if callSiteFromCallNode.targetSymbol.builtinKind <> builtinNone then
    callSiteFromCallNode.targetKind := hirCallBuiltin
  else
    callSiteFromCallNode.targetKind := hirCallUserRoutine;

  argumentNode := calleeNode^.nextSibling;
  while argumentNode <> nil do
  begin
    appendCallArgument(callSiteFromCallNode,
                       lowerExpression(state, argumentNode, errorCount));
    argumentNode := argumentNode^.nextSibling
  end
end;

function lowerCaseExpression(var state: hirState; node: astNode;
                             var errorCount: integer): hirExpression;
var
  childNode, whenNode, resultNode: astNode;
  caseArmNode: hirCaseArm;
begin
  lowerCaseExpression := newHirExpression(state, hirExprCase, node);
  if not hirCaseModeFromSymbol(node^.operatorSymbol,
                               lowerCaseExpression^.caseMode) then
    lowerCaseExpression^.caseMode := hirCaseSimple;

  childNode := node^.firstChild;
  if lowerCaseExpression^.caseMode = hirCaseSimple then
  begin
    lowerCaseExpression^.selectorExpression := lowerExpression(state, childNode, errorCount);
    if childNode <> nil then
      childNode := childNode^.nextSibling
  end;

  while (childNode <> nil) and (childNode^.kind = astCaseArm) do
  begin
    caseArmNode := newHirCaseArm(state, childNode);
    whenNode := childNode^.firstChild;
    resultNode := nil;
    if whenNode <> nil then
      resultNode := whenNode^.nextSibling;
    caseArmNode^.whenExpression := lowerExpression(state, whenNode, errorCount);
    caseArmNode^.resultExpression := lowerExpression(state, resultNode, errorCount);
    appendCaseArm(lowerCaseExpression, caseArmNode);
    childNode := childNode^.nextSibling
  end;

  lowerCaseExpression^.elseExpression := lowerExpression(state, childNode, errorCount)
end;

function lowerExpression(var state: hirState; node: astNode;
                         var errorCount: integer): hirExpression;
begin
  lowerExpression := nil;
  if node = nil then
    exit;

  case node^.kind of
    astIdentifierReference:
      lowerExpression := lowerIdentifierExpression(state, node);
    astNumberLiteral,
    astBooleanLiteral,
    astCharLiteral:
      lowerExpression := lowerLiteralExpression(state, node);
    astUnaryExpression:
      lowerExpression := lowerUnaryExpression(state, node, errorCount);
    astBinaryExpression:
      lowerExpression := lowerBinaryExpression(state, node, errorCount);
    astCallExpression:
      begin
        lowerExpression := newHirExpression(state, hirExprCall, node);
        lowerExpression^.callSite := callSiteFromCallNode(state, node, errorCount)
      end;
    astCaseExpression:
      lowerExpression := lowerCaseExpression(state, node, errorCount)
  end
end;

function lowerAssignmentStatement(var state: hirState; node: astNode;
                                  var errorCount: integer): hirStatement;
var
  targetNode, valueNode: astNode;
begin
  lowerAssignmentStatement := newHirStatement(state, hirStmtAssignment, node);
  targetNode := node^.firstChild;
  valueNode := nil;
  if targetNode <> nil then
    valueNode := targetNode^.nextSibling;
  lowerAssignmentStatement^.targetSymbol := symbolRefFromNode(targetNode);
  lowerAssignmentStatement^.valueExpression := lowerExpression(state, valueNode, errorCount)
end;

function lowerCallStatement(var state: hirState; node: astNode;
                            var errorCount: integer): hirStatement;
begin
  lowerCallStatement := newHirStatement(state, hirStmtCall, node);
  lowerCallStatement^.callSite := callSiteFromCallNode(state, node, errorCount)
end;

function lowerReturnStatement(var state: hirState; node: astNode;
                              var errorCount: integer): hirStatement;
begin
  lowerReturnStatement := newHirStatement(state, hirStmtReturn, node);
  lowerReturnStatement^.valueExpression := lowerExpression(state, node^.firstChild, errorCount)
end;

function lowerIfStatement(var state: hirState; node: astNode;
                          var errorCount: integer): hirStatement;
var
  conditionNode, thenNode, elseNode: astNode;
begin
  lowerIfStatement := newHirStatement(state, hirStmtIf, node);
  conditionNode := node^.firstChild;
  thenNode := nil;
  elseNode := nil;
  if conditionNode <> nil then
    thenNode := conditionNode^.nextSibling;
  if thenNode <> nil then
    elseNode := thenNode^.nextSibling;

  lowerIfStatement^.conditionExpression := lowerExpression(state, conditionNode, errorCount);
  lowerIfStatement^.thenBody := lowerStatement(state, thenNode, errorCount);
  lowerIfStatement^.elseBody := lowerStatement(state, elseNode, errorCount)
end;

function lowerWhileStatement(var state: hirState; node: astNode;
                             var errorCount: integer): hirStatement;
var
  conditionNode, bodyNode: astNode;
begin
  lowerWhileStatement := newHirStatement(state, hirStmtWhile, node);
  conditionNode := node^.firstChild;
  bodyNode := nil;
  if conditionNode <> nil then
    bodyNode := conditionNode^.nextSibling;
  lowerWhileStatement^.conditionExpression := lowerExpression(state, conditionNode, errorCount);
  lowerWhileStatement^.body := lowerStatement(state, bodyNode, errorCount)
end;

function lowerRepeatStatement(var state: hirState; node: astNode;
                              var errorCount: integer): hirStatement;
var
  bodyNode, conditionNode: astNode;
begin
  lowerRepeatStatement := newHirStatement(state, hirStmtRepeat, node);
  bodyNode := node^.firstChild;
  conditionNode := nil;
  if bodyNode <> nil then
    conditionNode := bodyNode^.nextSibling;
  lowerRepeatStatement^.body := lowerStatement(state, bodyNode, errorCount);
  lowerRepeatStatement^.conditionExpression := lowerExpression(state, conditionNode, errorCount)
end;

function lowerForStatement(var state: hirState; node: astNode;
                           var errorCount: integer): hirStatement;
var
  counterNode, startNode, endNode, stepNode, bodyNode: astNode;
begin
  lowerForStatement := newHirStatement(state, hirStmtFor, node);
  counterNode := node^.firstChild;
  startNode := nil;
  endNode := nil;
  stepNode := nil;
  bodyNode := nil;
  if counterNode <> nil then
    startNode := counterNode^.nextSibling;
  if startNode <> nil then
    endNode := startNode^.nextSibling;
  if endNode <> nil then
    stepNode := endNode^.nextSibling;
  if stepNode <> nil then
    bodyNode := stepNode^.nextSibling;

  lowerForStatement^.targetSymbol := symbolRefFromNode(counterNode);
  lowerForStatement^.startExpression := lowerExpression(state, startNode, errorCount);
  lowerForStatement^.endExpression := lowerExpression(state, endNode, errorCount);
  lowerForStatement^.stepExpression := lowerExpression(state, stepNode, errorCount);
  lowerForStatement^.body := lowerStatement(state, bodyNode, errorCount)
end;

function lowerSwitchStatement(var state: hirState; node: astNode;
                              var errorCount: integer): hirStatement;
var
  selectorNode, childNode, labelNode, bodyNode: astNode;
  switchArmNode: hirSwitchArm;
begin
  lowerSwitchStatement := newHirStatement(state, hirStmtSwitch, node);
  selectorNode := node^.firstChild;
  lowerSwitchStatement^.selectorExpression := lowerExpression(state, selectorNode, errorCount);

  childNode := nil;
  if selectorNode <> nil then
    childNode := selectorNode^.nextSibling;
  while childNode <> nil do
  begin
    if childNode^.kind = astSwitchCaseArm then
    begin
      switchArmNode := newHirSwitchArm(state, childNode);
      bodyNode := childNode^.lastChild;
      labelNode := childNode^.firstChild;
      while (labelNode <> nil) and (labelNode <> bodyNode) do
      begin
        appendSwitchLabel(switchArmNode, newHirSwitchLabel(labelNode));
        labelNode := labelNode^.nextSibling
      end;
      switchArmNode^.body := lowerStatement(state, bodyNode, errorCount);
      appendSwitchArm(lowerSwitchStatement, switchArmNode)
    end
    else
      lowerSwitchStatement^.elseBody := lowerStatement(state, childNode, errorCount);
    childNode := childNode^.nextSibling
  end
end;

function lowerStatement(var state: hirState; node: astNode;
                        var errorCount: integer): hirStatement;
begin
  lowerStatement := nil;
  if node = nil then
    exit;

  case node^.kind of
    astCompoundStatement:
      lowerStatement := lowerStatementSequence(state, node^.firstChild, errorCount);
    astAssignmentStatement:
      lowerStatement := lowerAssignmentStatement(state, node, errorCount);
    astCallStatement:
      lowerStatement := lowerCallStatement(state, node, errorCount);
    astReturnStatement:
      lowerStatement := lowerReturnStatement(state, node, errorCount);
    astBreakStatement:
      lowerStatement := newHirStatement(state, hirStmtBreak, node);
    astContinueStatement:
      lowerStatement := newHirStatement(state, hirStmtContinue, node);
    astIfStatement:
      lowerStatement := lowerIfStatement(state, node, errorCount);
    astWhileStatement:
      lowerStatement := lowerWhileStatement(state, node, errorCount);
    astRepeatStatement:
      lowerStatement := lowerRepeatStatement(state, node, errorCount);
    astForStatement:
      lowerStatement := lowerForStatement(state, node, errorCount);
    astSwitchStatement:
      lowerStatement := lowerSwitchStatement(state, node, errorCount)
  end
end;

function lowerStatementSequence(var state: hirState; firstNode: astNode;
                                var errorCount: integer): hirStatement;
var
  childNode: astNode;
  childStatement: hirStatement;
begin
  lowerStatementSequence := newHirStatement(state, hirStmtCompound, firstNode);
  childNode := firstNode;
  while childNode <> nil do
  begin
    if childNode^.kind in [astCompoundStatement, astAssignmentStatement,
                           astCallStatement, astReturnStatement,
                           astBreakStatement, astContinueStatement,
                           astIfStatement, astWhileStatement,
                           astRepeatStatement, astForStatement,
                           astSwitchStatement] then
    begin
      childStatement := lowerStatement(state, childNode, errorCount);
      appendStatementChild(lowerStatementSequence, childStatement)
    end;
    childNode := childNode^.nextSibling
  end
end;

function lowerRoutine(var state: hirState; routineNodeAst: astNode;
                      var errorCount: integer): hirRoutine;
var
  blockNode: astNode;
begin
  lowerRoutine := nil;
  if routineNodeAst = nil then
    exit;

  if routineNodeAst^.kind = astProcedureDeclaration then
    lowerRoutine := newHirRoutine(state, hirRoutineProcedure, routineNodeAst)
  else if routineNodeAst^.kind = astFunctionDeclaration then
    lowerRoutine := newHirRoutine(state, hirRoutineFunction, routineNodeAst);

  if lowerRoutine = nil then
    exit;

  collectRoutineParameters(state, routineNodeAst, lowerRoutine);
  blockNode := routineBlockNode(routineNodeAst);
  collectBlockLocalDeclarations(state, blockNode, lowerRoutine);
  if blockNode <> nil then
    lowerRoutine^.body := lowerStatementSequence(state, blockNode^.firstChild, errorCount)
  else
    lowerRoutine^.body := lowerStatementSequence(state, nil, errorCount)
end;

procedure collectProgramGlobals(var state: hirState; blockNode: astNode;
                                var programData: hirProgramRecord);
var
  childNode: astNode;
  declarationNode: hirDeclaration;
begin
  if blockNode = nil then
    exit;

  childNode := blockNode^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind in [astConstDeclaration, astVarDeclaration] then
    begin
      declarationNode := lowerDeclaration(state, childNode);
      appendProgramGlobal(programData, declarationNode)
    end
    else if childNode^.kind in [astProcedureDeclaration, astFunctionDeclaration,
                                astCompoundStatement, astAssignmentStatement,
                                astCallStatement, astReturnStatement,
                                astBreakStatement, astContinueStatement,
                                astIfStatement, astWhileStatement,
                                astRepeatStatement, astForStatement,
                                astSwitchStatement] then
      break;
    childNode := childNode^.nextSibling
  end
end;

procedure collectProgramRoutines(var state: hirState; blockNode: astNode;
                                 var programData: hirProgramRecord;
                                 var errorCount: integer);
var
  childNode: astNode;
begin
  if blockNode = nil then
    exit;

  childNode := blockNode^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind in [astProcedureDeclaration, astFunctionDeclaration] then
      appendProgramRoutine(programData, lowerRoutine(state, childNode, errorCount));
    childNode := childNode^.nextSibling
  end
end;

function newProgramEntryRoutine(var state: hirState; rootNode, blockNode: astNode;
                                var errorCount: integer): hirRoutine;
begin
  New(newProgramEntryRoutine);
  FillChar(newProgramEntryRoutine^, SizeOf(newProgramEntryRoutine^), 0);
  newProgramEntryRoutine^.id := nextRoutineId(state);
  newProgramEntryRoutine^.kind := hirRoutineProgram;
  if rootNode <> nil then
  begin
    newProgramEntryRoutine^.source := rootNode^.source;
    newProgramEntryRoutine^.name := rootNode^.identifierText
  end;
  newProgramEntryRoutine^.returnType := makeHirTypeRef(typeInteger);
  newProgramEntryRoutine^.hasReturnValue := false;
  if blockNode <> nil then
    newProgramEntryRoutine^.body := lowerStatementSequence(state, blockNode^.firstChild, errorCount)
end;

procedure lowerAstToHirProgram(rootNode: astNode;
                               var programData: hirProgramRecord;
                               var errorCount: integer);
var
  programBlock: astNode;
begin
  initializeHirProgram(programData);
  if rootNode = nil then
    exit;

  programData.source := rootNode^.source;
  programData.name := rootNode^.identifierText;
  if hasResolvedSymbol(rootNode) then
    programData.symbol := resolvedSymbolOf(rootNode);

  if rootNode^.kind = astProgram then
    programBlock := rootNode^.firstChild
  else
    programBlock := rootNode;

  collectProgramGlobals(programData.state, programBlock, programData);
  programData.entryRoutine := newProgramEntryRoutine(programData.state,
                                                     rootNode,
                                                     programBlock,
                                                     errorCount);
  collectProgramRoutines(programData.state, programBlock, programData, errorCount)
end;

end.
