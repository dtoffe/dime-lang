{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-22

  Abstract syntax tree support for the parser pipeline.  This unit owns AST node
  kinds, node allocation helpers, tree ownership/freeing, and traversal
  utilities.  It does not parse source text, perform semantic checks, or
  generate code. }
unit astree;

{$mode objfpc}

interface

uses
  diagnostics, tokens, typetable;

type
  { Minimal AST node kinds for the grammar currently parsed by parser.pas.
    Expected child layouts are:
      astProgram               program name, block child
      astBlock                 declarations/statements in source order
      astProcedureDeclaration  nested block as child
      astAssignmentStatement   target identifier, value expression
      astCallStatement         callee identifier reference, followed by an optional argument expression
      astIfStatement           condition, then-body statement sequence, optional else-body (including nested elsif as if-nodes)
      astWhileStatement        condition, body statement sequence
      astRepeatStatement       body statement sequence, condition
      astForStatement          counter identifier, start expression, end expression, step expression, body statement sequence
      astSwitchStatement       selector identifier, switch-case arms, optional else-body compound statement
      astSwitchCaseArm         label literal, body statement sequence
      astBinaryExpression      left operand, right operand, including relational operators
      astUnaryExpression       operand
      astCompoundStatement     block body or control-structure statement sequence children in source order }
  astNodeKind = (
    astProgram,
    astBlock,
    astConstDeclaration,
    astVarDeclaration,
    astProcedureDeclaration,
    astCompoundStatement,
    astAssignmentStatement,
    astCallStatement,
    astIfStatement,
    astWhileStatement,
    astRepeatStatement,
    astForStatement,
    astSwitchStatement,
    astSwitchCaseArm,
    astBinaryExpression,
    astUnaryExpression,
    astIdentifierReference,
    astNumberLiteral,
    astCharLiteral,
    astBooleanLiteral
  );

  astNode = ^astNodeRecord;
  astVisitProc = procedure(node: astNode; context: pointer);

  astNodeRecord = record
    kind: astNodeKind;
    source: sourceContext;
    sourceLine: integer;
    sourceColumn: integer;
    identifierText: identifier;
    numberValue: integer;
    declaredType: typeValue;
    valueType: typeValue;
    hasResolvedType: boolean;
    resolvedType: typeValue;
    operatorSymbol: symbol;
    firstChild: astNode;
    lastChild: astNode;
    nextSibling: astNode
  end;

function newAstNode(kind: astNodeKind; const source: sourceContext): astNode;
function newProgramNode(const programIdentifier: identifier;
                        const source: sourceContext): astNode;
function newBlockNode(const source: sourceContext): astNode;
function newConstDeclarationNode(const declarationIdentifier: identifier;
                                 declarationValue: integer;
                                 declaredType: typeValue;
                                 valueType: typeValue;
                                 const source: sourceContext): astNode;
function newVarDeclarationNode(const declarationIdentifier: identifier;
                               declaredType: typeValue;
                               const source: sourceContext): astNode;
function newProcedureDeclarationNode(const declarationIdentifier: identifier;
                                     const source: sourceContext): astNode;
function newCompoundStatementNode(const source: sourceContext): astNode;
function newAssignmentStatementNode(const source: sourceContext): astNode;
function newCallStatementNode(const source: sourceContext): astNode;
function newIfStatementNode(const source: sourceContext): astNode;
function newWhileStatementNode(const source: sourceContext): astNode;
function newRepeatStatementNode(const source: sourceContext): astNode;
function newForStatementNode(const source: sourceContext): astNode;
function newSwitchStatementNode(const source: sourceContext): astNode;
function newSwitchCaseArmNode(const source: sourceContext): astNode;
function newBinaryExpressionNode(expressionOperator: symbol;
                                 const source: sourceContext): astNode;
function newUnaryExpressionNode(expressionOperator: symbol;
                                const source: sourceContext): astNode;
function newIdentifierReferenceNode(const identifierName: identifier;
                                    const source: sourceContext): astNode;
function newIdentifierNode(const identifierName: identifier;
                           const source: sourceContext): astNode; deprecated 'Use newIdentifierReferenceNode';
function newNumberLiteralNode(literalValue: integer;
                              const source: sourceContext): astNode;
function newCharLiteralNode(literalValue: integer;
                            const source: sourceContext): astNode;
function newBooleanLiteralNode(literalValue: boolean;
                               const source: sourceContext): astNode;
procedure setNodeType(node: astNode; resolvedType: typeValue);
function hasNodeType(node: astNode): boolean;
function getNodeType(node: astNode): typeValue;

procedure appendChild(parentNode, childNode: astNode);
procedure appendDeclarationNode(listOwnerNode, declarationNode: astNode);
procedure appendStatementNode(listOwnerNode, statementNode: astNode);
procedure appendExpressionChild(parentExpressionNode, childExpressionNode: astNode);
procedure appendCalleeNode(callNode, calleeNode: astNode);
procedure appendCallArgumentNode(callNode, argumentNode: astNode);
procedure freeAst(rootNode: astNode);
procedure walkAstPreOrder(rootNode: astNode; visit: astVisitProc; context: pointer);
procedure dumpAstPreOrder(rootNode: astNode);

implementation

uses
  SysUtils;

function identifierToString(const identifierName: identifier): string;
var
  characterIndex: integer;
begin
  identifierToString := '';
  for characterIndex := Low(identifierName) to High(identifierName) do
    identifierToString := identifierToString + identifierName[characterIndex];
  identifierToString := TrimRight(identifierToString)
end;

function astNodeKindToString(kind: astNodeKind): string;
begin
  case kind of
    astProgram: astNodeKindToString := 'Program';
    astBlock: astNodeKindToString := 'Block';
    astConstDeclaration: astNodeKindToString := 'ConstDecl';
    astVarDeclaration: astNodeKindToString := 'VarDecl';
    astProcedureDeclaration: astNodeKindToString := 'ProcDecl';
    astCompoundStatement: astNodeKindToString := 'CompoundStmt';
    astAssignmentStatement: astNodeKindToString := 'AssignStmt';
    astCallStatement: astNodeKindToString := 'CallStmt';
    astIfStatement: astNodeKindToString := 'IfStmt';
    astWhileStatement: astNodeKindToString := 'WhileStmt';
    astRepeatStatement: astNodeKindToString := 'RepeatStmt';
    astForStatement: astNodeKindToString := 'ForStmt';
    astSwitchStatement: astNodeKindToString := 'SwitchStmt';
    astSwitchCaseArm: astNodeKindToString := 'SwitchCaseArm';
    astBinaryExpression: astNodeKindToString := 'BinaryExpr';
    astUnaryExpression: astNodeKindToString := 'UnaryExpr';
    astIdentifierReference: astNodeKindToString := 'IdentifierRef';
    astNumberLiteral: astNodeKindToString := 'NumberLiteral';
    astCharLiteral: astNodeKindToString := 'CharLiteral';
    astBooleanLiteral: astNodeKindToString := 'BooleanLiteral'
  end
end;

function astNodeSummary(node: astNode): string;
begin
  astNodeSummary := astNodeKindToString(node^.kind);
  case node^.kind of
    astProgram, astConstDeclaration, astVarDeclaration, astProcedureDeclaration, astIdentifierReference:
      astNodeSummary := astNodeSummary + ' ' + identifierToString(node^.identifierText);
    astNumberLiteral:
      astNodeSummary := astNodeSummary + ' ' + IntToStr(node^.numberValue);
    astCharLiteral:
      astNodeSummary := astNodeSummary + ' ' + IntToStr(node^.numberValue);
    astBooleanLiteral:
      if node^.numberValue = 0 then
        astNodeSummary := astNodeSummary + ' false'
      else
        astNodeSummary := astNodeSummary + ' true';
    astBinaryExpression, astUnaryExpression:
      astNodeSummary := astNodeSummary + ' op=' + IntToStr(Ord(node^.operatorSymbol))
  end;
  if node^.hasResolvedType then
    case node^.resolvedType of
      typeInteger:
        astNodeSummary := astNodeSummary + ' :integer';
      typeBoolean:
        astNodeSummary := astNodeSummary + ' :boolean';
      typeChar:
        astNodeSummary := astNodeSummary + ' :char'
    end;
  astNodeSummary := astNodeSummary +
                    Format(' @%d:%d', [node^.sourceLine, node^.sourceColumn])
end;

function newAstNode(kind: astNodeKind; const source: sourceContext): astNode;
begin
  New(newAstNode);
  newAstNode^.kind := kind;
  newAstNode^.source := source;
  newAstNode^.sourceLine := source.line;
  newAstNode^.sourceColumn := source.column;
  FillChar(newAstNode^.identifierText, SizeOf(newAstNode^.identifierText), ' ');
  newAstNode^.numberValue := 0;
  newAstNode^.declaredType := typeInteger;
  newAstNode^.valueType := typeInteger;
  newAstNode^.hasResolvedType := false;
  newAstNode^.resolvedType := typeInteger;
  newAstNode^.operatorSymbol := nul;
  newAstNode^.firstChild := nil;
  newAstNode^.lastChild := nil;
  newAstNode^.nextSibling := nil
end;

function newProgramNode(const programIdentifier: identifier;
                        const source: sourceContext): astNode;
begin
  newProgramNode := newAstNode(astProgram, source);
  newProgramNode^.identifierText := programIdentifier
end;

function newBlockNode(const source: sourceContext): astNode;
begin
  newBlockNode := newAstNode(astBlock, source)
end;

function newConstDeclarationNode(const declarationIdentifier: identifier;
                                 declarationValue: integer;
                                 declaredType: typeValue;
                                 valueType: typeValue;
                                 const source: sourceContext): astNode;
begin
  newConstDeclarationNode := newAstNode(astConstDeclaration, source);
  newConstDeclarationNode^.identifierText := declarationIdentifier;
  newConstDeclarationNode^.numberValue := declarationValue;
  newConstDeclarationNode^.declaredType := declaredType;
  newConstDeclarationNode^.valueType := valueType
end;

function newVarDeclarationNode(const declarationIdentifier: identifier;
                               declaredType: typeValue;
                               const source: sourceContext): astNode;
begin
  newVarDeclarationNode := newAstNode(astVarDeclaration, source);
  newVarDeclarationNode^.identifierText := declarationIdentifier;
  newVarDeclarationNode^.declaredType := declaredType
end;

function newProcedureDeclarationNode(const declarationIdentifier: identifier;
                                     const source: sourceContext): astNode;
begin
  newProcedureDeclarationNode := newAstNode(astProcedureDeclaration, source);
  newProcedureDeclarationNode^.identifierText := declarationIdentifier
end;

function newCompoundStatementNode(const source: sourceContext): astNode;
begin
  newCompoundStatementNode := newAstNode(astCompoundStatement, source)
end;

function newAssignmentStatementNode(const source: sourceContext): astNode;
begin
  newAssignmentStatementNode := newAstNode(astAssignmentStatement, source)
end;

function newCallStatementNode(const source: sourceContext): astNode;
begin
  newCallStatementNode := newAstNode(astCallStatement, source)
end;

function newIfStatementNode(const source: sourceContext): astNode;
begin
  newIfStatementNode := newAstNode(astIfStatement, source)
end;

function newWhileStatementNode(const source: sourceContext): astNode;
begin
  newWhileStatementNode := newAstNode(astWhileStatement, source)
end;

function newRepeatStatementNode(const source: sourceContext): astNode;
begin
  newRepeatStatementNode := newAstNode(astRepeatStatement, source)
end;

function newForStatementNode(const source: sourceContext): astNode;
begin
  newForStatementNode := newAstNode(astForStatement, source)
end;

function newSwitchStatementNode(const source: sourceContext): astNode;
begin
  newSwitchStatementNode := newAstNode(astSwitchStatement, source)
end;

function newSwitchCaseArmNode(const source: sourceContext): astNode;
begin
  newSwitchCaseArmNode := newAstNode(astSwitchCaseArm, source)
end;

function newBinaryExpressionNode(expressionOperator: symbol;
                                 const source: sourceContext): astNode;
begin
  newBinaryExpressionNode := newAstNode(astBinaryExpression, source);
  newBinaryExpressionNode^.operatorSymbol := expressionOperator
end;

function newUnaryExpressionNode(expressionOperator: symbol;
                                const source: sourceContext): astNode;
begin
  newUnaryExpressionNode := newAstNode(astUnaryExpression, source);
  newUnaryExpressionNode^.operatorSymbol := expressionOperator
end;

function newIdentifierReferenceNode(const identifierName: identifier;
                                    const source: sourceContext): astNode;
begin
  newIdentifierReferenceNode := newAstNode(astIdentifierReference, source);
  newIdentifierReferenceNode^.identifierText := identifierName
end;

function newIdentifierNode(const identifierName: identifier;
                           const source: sourceContext): astNode;
begin
  newIdentifierNode := newIdentifierReferenceNode(identifierName, source)
end;

function newNumberLiteralNode(literalValue: integer;
                              const source: sourceContext): astNode;
begin
  newNumberLiteralNode := newAstNode(astNumberLiteral, source);
  newNumberLiteralNode^.numberValue := literalValue
end;

function newCharLiteralNode(literalValue: integer;
                            const source: sourceContext): astNode;
begin
  newCharLiteralNode := newAstNode(astCharLiteral, source);
  newCharLiteralNode^.numberValue := literalValue
end;

function newBooleanLiteralNode(literalValue: boolean;
                               const source: sourceContext): astNode;
begin
  newBooleanLiteralNode := newAstNode(astBooleanLiteral, source);
  if literalValue then
    newBooleanLiteralNode^.numberValue := 1
  else
    newBooleanLiteralNode^.numberValue := 0
end;

procedure setNodeType(node: astNode; resolvedType: typeValue);
begin
  if node = nil then
    exit;

  node^.hasResolvedType := true;
  node^.resolvedType := resolvedType
end;

function hasNodeType(node: astNode): boolean;
begin
  hasNodeType := (node <> nil) and node^.hasResolvedType
end;

function getNodeType(node: astNode): typeValue;
begin
  if node = nil then
    getNodeType := typeInteger
  else
    getNodeType := node^.resolvedType
end;

procedure appendChild(parentNode, childNode: astNode);
begin
  if (parentNode = nil) or (childNode = nil) then
    exit;

  childNode^.nextSibling := nil;
  if parentNode^.firstChild = nil then
  begin
    parentNode^.firstChild := childNode;
    parentNode^.lastChild := childNode
  end
  else
  begin
    parentNode^.lastChild^.nextSibling := childNode;
    parentNode^.lastChild := childNode
  end
end;

procedure appendDeclarationNode(listOwnerNode, declarationNode: astNode);
begin
  appendChild(listOwnerNode, declarationNode)
end;

procedure appendStatementNode(listOwnerNode, statementNode: astNode);
begin
  appendChild(listOwnerNode, statementNode)
end;

procedure appendExpressionChild(parentExpressionNode, childExpressionNode: astNode);
begin
  appendChild(parentExpressionNode, childExpressionNode)
end;

procedure appendCalleeNode(callNode, calleeNode: astNode);
begin
  appendChild(callNode, calleeNode)
end;

procedure appendCallArgumentNode(callNode, argumentNode: astNode);
begin
  appendChild(callNode, argumentNode)
end;

procedure freeAst(rootNode: astNode);
var
  currentChild, nextChild: astNode;
begin
  if rootNode = nil then
    exit;

  currentChild := rootNode^.firstChild;
  while currentChild <> nil do
  begin
    nextChild := currentChild^.nextSibling;
    freeAst(currentChild);
    currentChild := nextChild
  end;
  Dispose(rootNode)
end;

procedure walkAstPreOrder(rootNode: astNode; visit: astVisitProc; context: pointer);
var
  childNode: astNode;
begin
  if (rootNode = nil) or not Assigned(visit) then
    exit;

  visit(rootNode, context);
  childNode := rootNode^.firstChild;
  while childNode <> nil do
  begin
    walkAstPreOrder(childNode, visit, context);
    childNode := childNode^.nextSibling
  end
end;

procedure dumpAstChildren(rootNode: astNode; depth: integer);
var
  childNode: astNode;
begin
  if rootNode = nil then
    exit;

  emitDiagnostic(debug, '[AST ] ' + StringOfChar(' ', depth * 2) + astNodeSummary(rootNode));
  childNode := rootNode^.firstChild;
  while childNode <> nil do
  begin
    dumpAstChildren(childNode, depth + 1);
    childNode := childNode^.nextSibling
  end
end;

procedure dumpAstPreOrder(rootNode: astNode);
var
  depth: integer;
begin
  if rootNode = nil then
    exit;

  depth := 0;
  dumpAstChildren(rootNode, depth)
end;

end.
