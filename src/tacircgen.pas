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

function lowerExpression(node: astNode; var errorCount: integer): tacOperand;
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
      lowerExpression := lowerBinaryExpression(node, errorCount)
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
  resolvedSymbol: symbolIndex;
  procKind: builtinProcedure;
  instruction: tacInstruction;
begin
  calleeNode := node^.firstChild;
  argumentNode := nil;
  if calleeNode <> nil then
    argumentNode := calleeNode^.nextSibling;

  if (calleeNode = nil) or not hasResolvedSymbol(calleeNode) then
    exit;

  resolvedSymbol := resolvedSymbolOf(calleeNode);
  if getDeclarationKind(resolvedSymbol) <> proc then
    exit;

  procKind := getBuiltinProcedure(resolvedSymbol);
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
    if argumentNode <> nil then
    begin
      argumentOperand := lowerExpression(argumentNode, errorCount);
      setTacCallArgument(instruction, 1, argumentOperand)
    end;
    appendTacInstruction(instruction)
  end
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
    astIfStatement:
      lowerIfStatement(node, errorCount);
    astWhileStatement:
      lowerWhileStatement(node, errorCount);
    astRepeatStatement:
      lowerRepeatStatement(node, errorCount)
  end
end;

procedure lowerProcedureDeclaration(node: astNode; var errorCount: integer);
var
  procedureSymbol: symbolIndex;
begin
  if (node = nil) or (node^.firstChild = nil) then
    exit;

  procedureSymbol := 0;
  if hasResolvedSymbol(node) then
    procedureSymbol := resolvedSymbolOf(node);
  appendTacProcedure(node^.identifierText, procedureSymbol);
  appendLabel(newTacLabel);
  lowerBlock(node^.firstChild, errorCount)
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
                           astCallStatement, astIfStatement, astWhileStatement,
                           astRepeatStatement] then
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
      lowerProcedureDeclaration(childNode, errorCount);
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
