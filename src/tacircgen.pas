{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-31

  AST-to-TAC lowering support for the compiler pipeline. This unit walks the
  semantically analyzed AST and uses tacir as a low-level service to build a
  symbolic three-address-code image. It owns structural translation only:
  expression trees become temporaries, and control-flow nodes become labels and
  conditional/unconditional jumps. It does not parse source text, perform
  semantic checks, allocate registers, assign stack slots, or emit target code. }
unit tacircgen;

{$mode objfpc}

interface

uses
  astree;

procedure generateTacIrProgram(rootNode: astNode; var errorCount: integer);

implementation

uses
  semantics, symboltable, tacir, tokens, typetable;

var
  currentLoweredFunctionSymbol: symbolIndex;

function routineBlockNode(node: astNode): astNode;
begin
  routineBlockNode := node^.firstChild;
  while (routineBlockNode <> nil) and
        (routineBlockNode^.kind = astVarDeclaration) do
    routineBlockNode := routineBlockNode^.nextSibling
end;

function nodeValueType(node: astNode): typeValue;
begin
  if (node <> nil) and hasNodeType(node) then
    nodeValueType := getNodeType(node)
  else
    nodeValueType := typeInteger
end;

function symbolOperandFromNode(node: astNode): tacOperand;
begin
  if (node <> nil) and hasResolvedSymbol(node) then
    symbolOperandFromNode := makeTacSymbolOperand(resolvedSymbolOf(node),
                                                 node^.identifierText,
                                                 nodeValueType(node))
  else
    symbolOperandFromNode := makeTacNoneOperand
end;

procedure appendLabel(labelId: tacLabelId);
var
  instruction: tacInstruction;
begin
  appendTacBasicBlock(labelId);
  instruction := newTacInstruction(irLabel);
  instruction.targetLabel := labelId;
  appendTacInstruction(instruction)
end;

procedure appendGoto(labelId: tacLabelId);
var
  instruction: tacInstruction;
begin
  instruction := newTacInstruction(irGoto);
  instruction.targetLabel := labelId;
  appendTacInstruction(instruction)
end;

procedure appendGotoIfZero(const conditionOperand: tacOperand; labelId: tacLabelId);
var
  instruction: tacInstruction;
begin
  instruction := newTacInstruction(irGotoIfZero);
  instruction.leftOperand := conditionOperand;
  instruction.targetLabel := labelId;
  appendTacInstruction(instruction)
end;

function lowerExpression(node: astNode; var errorCount: integer): tacOperand; forward;
procedure lowerCallStatement(node: astNode; var errorCount: integer); forward;
procedure lowerStatement(node: astNode; var errorCount: integer); forward;
procedure lowerBlock(node: astNode; var errorCount: integer); forward;

function lowerIdentifierReference(node: astNode): tacOperand;
var
  instruction: tacInstruction;
  resolvedSymbol: symbolIndex;
begin
  lowerIdentifierReference := makeTacNoneOperand;
  if (node = nil) or not hasResolvedSymbol(node) then
    exit;

  resolvedSymbol := resolvedSymbolOf(node);
  case getDeclarationKind(resolvedSymbol) of
    constant:
      begin
        lowerIdentifierReference := newTacTemporary(getDeclarationType(resolvedSymbol));
        instruction := newTacInstruction(irLoadConst);
        instruction.resultOperand := lowerIdentifierReference;
        instruction.leftOperand := makeTacConstOperand(getConstantValue(resolvedSymbol),
                                                       getDeclarationType(resolvedSymbol));
        appendTacInstruction(instruction)
      end;
    variable:
      begin
        lowerIdentifierReference := newTacTemporary(getDeclarationType(resolvedSymbol));
        instruction := newTacInstruction(irLoadVar);
        instruction.resultOperand := lowerIdentifierReference;
        instruction.leftOperand := makeTacSymbolOperand(resolvedSymbol,
                                                       node^.identifierText,
                                                       getDeclarationType(resolvedSymbol));
        appendTacInstruction(instruction)
      end;
    proc:
      {procedure-in-expression is rejected during semantics}
  end
end;

function lowerLiteral(node: astNode): tacOperand;
var
  instruction: tacInstruction;
begin
  lowerLiteral := newTacTemporary(nodeValueType(node));
  instruction := newTacInstruction(irLoadConst);
  instruction.resultOperand := lowerLiteral;
  instruction.leftOperand := makeTacConstOperand(node^.numberValue, nodeValueType(node));
  appendTacInstruction(instruction)
end;

function lowerUnaryExpression(node: astNode; var errorCount: integer): tacOperand;
var
  operand: tacOperand;
  instruction: tacInstruction;
begin
  operand := lowerExpression(node^.firstChild, errorCount);
  lowerUnaryExpression := newTacTemporary(nodeValueType(node));
  instruction := newTacInstruction(irUnaryOp);
  instruction.resultOperand := lowerUnaryExpression;
  instruction.leftOperand := operand;
  instruction.operatorSymbol := node^.operatorSymbol;
  appendTacInstruction(instruction)
end;

function lowerBinaryExpression(node: astNode; var errorCount: integer): tacOperand;
var
  leftNode, rightNode: astNode;
  leftOperand, rightOperand: tacOperand;
  instruction: tacInstruction;
begin
  leftNode := node^.firstChild;
  rightNode := nil;
  if leftNode <> nil then
    rightNode := leftNode^.nextSibling;

  leftOperand := lowerExpression(leftNode, errorCount);
  rightOperand := lowerExpression(rightNode, errorCount);
  lowerBinaryExpression := newTacTemporary(nodeValueType(node));

  instruction := newTacInstruction(irBinaryOp);
  instruction.resultOperand := lowerBinaryExpression;
  instruction.leftOperand := leftOperand;
  instruction.rightOperand := rightOperand;
  instruction.operatorSymbol := node^.operatorSymbol;
  appendTacInstruction(instruction)
end;

function lowerCaseExpression(node: astNode; var errorCount: integer): tacOperand;
var
  selectorNode, caseArmNode, whenNode, resultNode: astNode;
  selectorOperand, conditionOperand, whenOperand, branchOperand: tacOperand;
  resultOperand: tacOperand;
  nextLabel, endLabel: tacLabelId;
  instruction: tacInstruction;
begin
  selectorNode := nil;
  caseArmNode := node^.firstChild;
  selectorOperand := makeTacNoneOperand;
  if node^.operatorSymbol = casesym then
  begin
    selectorNode := node^.firstChild;
    if selectorNode <> nil then
    begin
      selectorOperand := lowerExpression(selectorNode, errorCount);
      caseArmNode := selectorNode^.nextSibling
    end
  end;

  resultOperand := newTacTemporary(nodeValueType(node));
  endLabel := newTacLabel;
  while (caseArmNode <> nil) and (caseArmNode^.kind = astCaseArm) do
  begin
    whenNode := caseArmNode^.firstChild;
    resultNode := nil;
    if whenNode <> nil then
      resultNode := whenNode^.nextSibling;

    if selectorNode <> nil then
    begin
      whenOperand := lowerExpression(whenNode, errorCount);
      conditionOperand := newTacTemporary(typeBoolean);
      instruction := newTacInstruction(irBinaryOp);
      instruction.resultOperand := conditionOperand;
      instruction.leftOperand := selectorOperand;
      instruction.rightOperand := whenOperand;
      instruction.operatorSymbol := eql;
      appendTacInstruction(instruction)
    end
    else
      conditionOperand := lowerExpression(whenNode, errorCount);

    nextLabel := newTacLabel;
    appendGotoIfZero(conditionOperand, nextLabel);
    branchOperand := lowerExpression(resultNode, errorCount);
    instruction := newTacInstruction(irCopy);
    instruction.resultOperand := resultOperand;
    instruction.leftOperand := branchOperand;
    appendTacInstruction(instruction);
    appendGoto(endLabel);
    appendLabel(nextLabel);
    caseArmNode := caseArmNode^.nextSibling
  end;

  branchOperand := lowerExpression(caseArmNode, errorCount);
  instruction := newTacInstruction(irCopy);
  instruction.resultOperand := resultOperand;
  instruction.leftOperand := branchOperand;
  appendTacInstruction(instruction);
  appendLabel(endLabel);
  lowerCaseExpression := resultOperand
end;

function lowerExpression(node: astNode; var errorCount: integer): tacOperand;
var
  instruction: tacInstruction;
begin
  lowerExpression := makeTacNoneOperand;
  if node = nil then
    exit;

  case node^.kind of
    astIdentifierReference:
      lowerExpression := lowerIdentifierReference(node);
    astNumberLiteral,
    astCharLiteral,
    astBooleanLiteral:
      lowerExpression := lowerLiteral(node);
    astUnaryExpression:
      lowerExpression := lowerUnaryExpression(node, errorCount);
    astBinaryExpression:
      lowerExpression := lowerBinaryExpression(node, errorCount);
    astCallExpression:
      begin
        lowerCallStatement(node, errorCount);
        if hasResolvedSymbol(node^.firstChild) then
        begin
          lowerExpression := newTacTemporary(nodeValueType(node));
          instruction := newTacInstruction(irLoadVar);
          instruction.resultOperand := lowerExpression;
          instruction.leftOperand := makeTacSymbolOperand(
            resolvedSymbolOf(node^.firstChild),
            node^.firstChild^.identifierText,
            nodeValueType(node));
          appendTacInstruction(instruction)
        end
      end;
    astCaseExpression:
      lowerExpression := lowerCaseExpression(node, errorCount)
  end
end;

procedure lowerAssignmentStatement(node: astNode; var errorCount: integer);
var
  targetNode, valueNode: astNode;
  valueOperand: tacOperand;
  instruction: tacInstruction;
begin
  targetNode := node^.firstChild;
  valueNode := nil;
  if targetNode <> nil then
    valueNode := targetNode^.nextSibling;

  valueOperand := lowerExpression(valueNode, errorCount);
  instruction := newTacInstruction(irStoreVar);
  instruction.resultOperand := symbolOperandFromNode(targetNode);
  instruction.leftOperand := valueOperand;
  appendTacInstruction(instruction)
end;

procedure lowerCallStatement(node: astNode; var errorCount: integer);
var
  calleeNode, argumentNode: astNode;
  argumentOperand: tacOperand;
  parameterOperand: tacOperand;
  resolvedSymbol: symbolIndex;
  procKind: builtinProcedure;
  instruction, storeInstruction: tacInstruction;
  argumentIndex: integer;
  parameterSymbol: symbolIndex;
begin
  calleeNode := node^.firstChild;
  argumentNode := nil;
  if calleeNode <> nil then
    argumentNode := calleeNode^.nextSibling;

  if (calleeNode = nil) or not hasResolvedSymbol(calleeNode) then
    exit;

  resolvedSymbol := resolvedSymbolOf(calleeNode);
  if not (getDeclarationKind(resolvedSymbol) in [proc, func]) then
    exit;

  if getDeclarationKind(resolvedSymbol) = proc then
    procKind := getBuiltinProcedure(resolvedSymbol)
  else
    procKind := builtinNone;
  if procKind in [builtinWrite, builtinWriteLn] then
  begin
    argumentOperand := lowerExpression(argumentNode, errorCount);
    instruction := newTacInstruction(irBuiltinWrite);
    instruction.builtinProcedureKind := procKind;
    instruction.leftOperand := argumentOperand;
    appendTacInstruction(instruction)
  end
  else if procKind in [builtinRead, builtinReadLn] then
  begin
    instruction := newTacInstruction(irBuiltinRead);
    instruction.builtinProcedureKind := procKind;
    instruction.resultOperand := symbolOperandFromNode(argumentNode);
    appendTacInstruction(instruction)
  end
  else
  begin
    instruction := newTacInstruction(irCallProc);
    instruction.procedureSymbol := resolvedSymbol;
    instruction.procedureName := calleeNode^.identifierText;
    argumentIndex := 1;
    while argumentNode <> nil do
    begin
      argumentOperand := lowerExpression(argumentNode, errorCount);
      parameterSymbol := getProcedureParameterSymbol(resolvedSymbol, argumentIndex);
      if parameterSymbol <> 0 then
      begin
        parameterOperand := makeTacSymbolOperand(
          parameterSymbol,
          getDeclarationIdentifier(parameterSymbol),
          getProcedureParameterType(resolvedSymbol, argumentIndex));
        storeInstruction := newTacInstruction(irStoreVar);
        storeInstruction.resultOperand := parameterOperand;
        storeInstruction.leftOperand := argumentOperand;
        appendTacInstruction(storeInstruction)
      end;
      setTacCallArgument(instruction, argumentIndex, argumentOperand);
      argumentIndex := argumentIndex + 1;
      argumentNode := argumentNode^.nextSibling
    end;
    appendTacInstruction(instruction)
  end
end;

procedure lowerReturnStatement(node: astNode; var errorCount: integer);
var
  valueNode: astNode;
  valueOperand: tacOperand;
  instruction: tacInstruction;
begin
  valueNode := node^.firstChild;
  valueOperand := lowerExpression(valueNode, errorCount);

  if currentLoweredFunctionSymbol <> 0 then
  begin
    instruction := newTacInstruction(irStoreVar);
    instruction.resultOperand := makeTacSymbolOperand(currentLoweredFunctionSymbol,
                                                      getDeclarationIdentifier(currentLoweredFunctionSymbol),
                                                      nodeValueType(valueNode));
    instruction.leftOperand := valueOperand;
    appendTacInstruction(instruction)
  end;

  instruction := newTacInstruction(irReturn);
  appendTacInstruction(instruction)
end;

procedure lowerIfStatement(node: astNode; var errorCount: integer);
var
  conditionNode, thenNode, elseNode: astNode;
  conditionOperand: tacOperand;
  elseLabel, endLabel: tacLabelId;
begin
  conditionNode := node^.firstChild;
  thenNode := nil;
  elseNode := nil;
  if conditionNode <> nil then
    thenNode := conditionNode^.nextSibling;
  if thenNode <> nil then
    elseNode := thenNode^.nextSibling;

  conditionOperand := lowerExpression(conditionNode, errorCount);
  elseLabel := newTacLabel;
  appendGotoIfZero(conditionOperand, elseLabel);
  lowerStatement(thenNode, errorCount);

  if elseNode <> nil then
  begin
    endLabel := newTacLabel;
    appendGoto(endLabel);
    appendLabel(elseLabel);
    lowerStatement(elseNode, errorCount);
    appendLabel(endLabel)
  end
  else
    appendLabel(elseLabel)
end;

procedure lowerWhileStatement(node: astNode; var errorCount: integer);
var
  conditionNode, bodyNode: astNode;
  startLabel, exitLabel: tacLabelId;
  conditionOperand: tacOperand;
begin
  conditionNode := node^.firstChild;
  bodyNode := nil;
  if conditionNode <> nil then
    bodyNode := conditionNode^.nextSibling;

  startLabel := newTacLabel;
  exitLabel := newTacLabel;
  appendLabel(startLabel);
  conditionOperand := lowerExpression(conditionNode, errorCount);
  appendGotoIfZero(conditionOperand, exitLabel);
  lowerStatement(bodyNode, errorCount);
  appendGoto(startLabel);
  appendLabel(exitLabel)
end;

procedure lowerRepeatStatement(node: astNode; var errorCount: integer);
var
  bodyNode, conditionNode: astNode;
  startLabel: tacLabelId;
  conditionOperand: tacOperand;
begin
  bodyNode := node^.firstChild;
  conditionNode := nil;
  if bodyNode <> nil then
    conditionNode := bodyNode^.nextSibling;

  startLabel := newTacLabel;
  appendLabel(startLabel);
  lowerStatement(bodyNode, errorCount);
  conditionOperand := lowerExpression(conditionNode, errorCount);
  appendGotoIfZero(conditionOperand, startLabel)
end;

procedure lowerForStatement(node: astNode; var errorCount: integer);
var
  counterNode, startNode, endNode, stepNode, bodyNode: astNode;
  counterOperand, startOperand, endOperand, stepOperand: tacOperand;
  comparisonOperand, incrementOperand: tacOperand;
  startLabel, exitLabel: tacLabelId;
  instruction: tacInstruction;
begin
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

  counterOperand := symbolOperandFromNode(counterNode);
  startOperand := lowerExpression(startNode, errorCount);
  instruction := newTacInstruction(irStoreVar);
  instruction.resultOperand := counterOperand;
  instruction.leftOperand := startOperand;
  appendTacInstruction(instruction);

  startLabel := newTacLabel;
  exitLabel := newTacLabel;
  appendLabel(startLabel);

  endOperand := lowerExpression(endNode, errorCount);
  comparisonOperand := newTacTemporary(typeBoolean);
  instruction := newTacInstruction(irBinaryOp);
  instruction.resultOperand := comparisonOperand;
  instruction.leftOperand := lowerIdentifierReference(counterNode);
  instruction.rightOperand := endOperand;
  instruction.operatorSymbol := leq;
  appendTacInstruction(instruction);
  appendGotoIfZero(comparisonOperand, exitLabel);

  lowerStatement(bodyNode, errorCount);

  stepOperand := lowerExpression(stepNode, errorCount);
  incrementOperand := newTacTemporary(typeInteger);
  instruction := newTacInstruction(irBinaryOp);
  instruction.resultOperand := incrementOperand;
  instruction.leftOperand := lowerIdentifierReference(counterNode);
  instruction.rightOperand := stepOperand;
  instruction.operatorSymbol := plus;
  appendTacInstruction(instruction);

  instruction := newTacInstruction(irStoreVar);
  instruction.resultOperand := counterOperand;
  instruction.leftOperand := incrementOperand;
  appendTacInstruction(instruction);

  appendGoto(startLabel);
  appendLabel(exitLabel)
end;

procedure lowerSwitchStatement(node: astNode; var errorCount: integer);
var
  selectorNode, switchCaseNode, labelNode, bodyNode: astNode;
  selectorOperand, labelOperand, comparisonOperand: tacOperand;
  nextLabel, endLabel, defaultLabel: tacLabelId;
  bodyLabels: array [1..maxTacInstructions] of tacLabelId;
  bodyLabelCount: integer;
  instruction: tacInstruction;
begin
  selectorNode := node^.firstChild;
  switchCaseNode := nil;
  if selectorNode <> nil then
    switchCaseNode := selectorNode^.nextSibling;

  endLabel := newTacLabel;
  if (node^.lastChild <> nil) and (node^.lastChild^.kind <> astSwitchCaseArm) then
    defaultLabel := newTacLabel
  else
    defaultLabel := endLabel;
  bodyLabelCount := 0;
  while switchCaseNode <> nil do
  begin
    if switchCaseNode^.kind = astSwitchCaseArm then
    begin
      labelNode := switchCaseNode^.firstChild;
      bodyNode := nil;
      if labelNode <> nil then
        bodyNode := labelNode^.nextSibling;

      selectorOperand := lowerIdentifierReference(selectorNode);
      labelOperand := lowerExpression(labelNode, errorCount);
      comparisonOperand := newTacTemporary(typeBoolean);
      instruction := newTacInstruction(irBinaryOp);
      instruction.resultOperand := comparisonOperand;
      instruction.leftOperand := selectorOperand;
      instruction.rightOperand := labelOperand;
      instruction.operatorSymbol := eql;
      appendTacInstruction(instruction);

      bodyLabelCount := bodyLabelCount + 1;
      bodyLabels[bodyLabelCount] := newTacLabel;
      nextLabel := newTacLabel;
      appendGotoIfZero(comparisonOperand, nextLabel);
      appendGoto(bodyLabels[bodyLabelCount]);
      appendLabel(nextLabel)
    end;
    switchCaseNode := switchCaseNode^.nextSibling
  end;

  appendGoto(defaultLabel);

  switchCaseNode := nil;
  if selectorNode <> nil then
    switchCaseNode := selectorNode^.nextSibling;
  bodyLabelCount := 1;
  while switchCaseNode <> nil do
  begin
    if switchCaseNode^.kind = astSwitchCaseArm then
    begin
      labelNode := switchCaseNode^.firstChild;
      bodyNode := nil;
      if labelNode <> nil then
        bodyNode := labelNode^.nextSibling;
      appendLabel(bodyLabels[bodyLabelCount]);
      bodyLabelCount := bodyLabelCount + 1;
      lowerStatement(bodyNode, errorCount);
      if switchCaseNode^.operatorSymbol = breaksym then
        appendGoto(endLabel)
    end
    else
    begin
      appendLabel(defaultLabel);
      lowerStatement(switchCaseNode, errorCount)
    end;
    switchCaseNode := switchCaseNode^.nextSibling
  end;

  appendLabel(endLabel)
end;

procedure lowerStatement(node: astNode; var errorCount: integer);
var
  childNode: astNode;
begin
  if node = nil then
    exit;

  case node^.kind of
    astCompoundStatement:
      begin
        childNode := node^.firstChild;
        while childNode <> nil do
        begin
          lowerStatement(childNode, errorCount);
          childNode := childNode^.nextSibling
        end
      end;
    astAssignmentStatement:
      lowerAssignmentStatement(node, errorCount);
    astCallStatement:
      lowerCallStatement(node, errorCount);
    astReturnStatement:
      lowerReturnStatement(node, errorCount);
    astIfStatement:
      lowerIfStatement(node, errorCount);
    astWhileStatement:
      lowerWhileStatement(node, errorCount);
    astRepeatStatement:
      lowerRepeatStatement(node, errorCount);
    astForStatement:
      lowerForStatement(node, errorCount);
    astSwitchStatement:
      lowerSwitchStatement(node, errorCount)
  end
end;

procedure lowerProcedureDeclaration(node: astNode; var errorCount: integer);
var
  procedureSymbol: symbolIndex;
begin
  if node = nil then
    exit;

  procedureSymbol := 0;
  if hasResolvedSymbol(node) then
    procedureSymbol := resolvedSymbolOf(node);
  appendTacProcedure(node^.identifierText, procedureSymbol);
  appendLabel(newTacLabel);
  currentLoweredFunctionSymbol := 0;
  lowerBlock(routineBlockNode(node), errorCount)
end;

procedure lowerFunctionDeclaration(node: astNode; var errorCount: integer);
var
  functionSymbol: symbolIndex;
begin
  if node = nil then
    exit;

  functionSymbol := 0;
  if hasResolvedSymbol(node) then
    functionSymbol := resolvedSymbolOf(node);
  appendTacProcedure(node^.identifierText, functionSymbol);
  appendLabel(newTacLabel);
  currentLoweredFunctionSymbol := functionSymbol;
  lowerBlock(routineBlockNode(node), errorCount);
  currentLoweredFunctionSymbol := 0
end;

procedure lowerBlockBody(blockNode: astNode; var errorCount: integer);
var
  childNode: astNode;
  instruction: tacInstruction;
begin
  if blockNode = nil then
    exit;

  childNode := blockNode^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind in [astCompoundStatement, astAssignmentStatement,
                           astCallStatement, astReturnStatement,
                           astIfStatement, astWhileStatement,
                           astRepeatStatement, astForStatement, astSwitchStatement] then
      lowerStatement(childNode, errorCount);
    childNode := childNode^.nextSibling
  end;

  instruction := newTacInstruction(irReturn);
  appendTacInstruction(instruction)
end;

procedure lowerBlock(node: astNode; var errorCount: integer);
var
  childNode: astNode;
begin
  if node = nil then
    exit;

  lowerBlockBody(node, errorCount);

  childNode := node^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind = astProcedureDeclaration then
      lowerProcedureDeclaration(childNode, errorCount)
    else if childNode^.kind = astFunctionDeclaration then
      lowerFunctionDeclaration(childNode, errorCount);
    childNode := childNode^.nextSibling
  end
end;

procedure generateTacIrProgram(rootNode: astNode; var errorCount: integer);
var
  programBlock: astNode;
begin
  if rootNode = nil then
    exit;

  initializeTacIr;
  currentLoweredFunctionSymbol := 0;
  if rootNode^.kind = astProgram then
  begin
    appendTacProcedure(rootNode^.identifierText, 0);
    appendLabel(newTacLabel);
    programBlock := rootNode^.firstChild
  end
  else
  begin
    appendTacProcedure(rootNode^.identifierText, 0);
    appendLabel(newTacLabel);
    programBlock := rootNode
  end;

  lowerBlock(programBlock, errorCount)
end;

end.
