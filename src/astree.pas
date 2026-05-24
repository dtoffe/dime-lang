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
      astProgram               block
      astBlock                 declarations/statements in source order
      astProcedureDeclaration  nested block as child
      astAssignmentStatement   target identifier, value expression
      astCallStatement         callee identifier
      astIfStatement           condition, then-statement
      astWhileStatement        condition, body statement
      astCondition             one child for odd, two children for relational operators
      astBinaryExpression      left operand, right operand
      astUnaryExpression       operand
      astCompoundStatement     statement children in source order }
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
    astCondition,
    astBinaryExpression,
    astUnaryExpression,
    astIdentifierReference,
    astNumberLiteral
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
    hasResolvedType: boolean;
    resolvedType: typeValue;
    operatorSymbol: symbol;
    firstChild: astNode;
    lastChild: astNode;
    nextSibling: astNode
  end;

function newAstNode(kind: astNodeKind; const source: sourceContext): astNode;
function newProgramNode(const source: sourceContext): astNode;
function newBlockNode(const source: sourceContext): astNode;
function newConstDeclarationNode(const declarationIdentifier: identifier;
                                 declarationValue: integer;
                                 declaredType: typeValue;
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
function newConditionNode(conditionOperator: symbol;
                          const source: sourceContext): astNode;
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
procedure setNodeType(node: astNode; resolvedType: typeValue);
function hasNodeType(node: astNode): boolean;
function getNodeType(node: astNode): typeValue;

procedure appendChild(parentNode, childNode: astNode);
procedure appendDeclarationNode(listOwnerNode, declarationNode: astNode);
procedure appendStatementNode(listOwnerNode, statementNode: astNode);
procedure appendExpressionChild(parentExpressionNode, childExpressionNode: astNode);
procedure appendArgumentNode(callNode, argumentNode: astNode);
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
    astCondition: astNodeKindToString := 'Condition';
    astBinaryExpression: astNodeKindToString := 'BinaryExpr';
    astUnaryExpression: astNodeKindToString := 'UnaryExpr';
    astIdentifierReference: astNodeKindToString := 'IdentifierRef';
    astNumberLiteral: astNodeKindToString := 'NumberLiteral'
  end
end;

function astNodeSummary(node: astNode): string;
begin
  astNodeSummary := astNodeKindToString(node^.kind);
  case node^.kind of
    astConstDeclaration, astVarDeclaration, astProcedureDeclaration, astIdentifierReference:
      astNodeSummary := astNodeSummary + ' ' + identifierToString(node^.identifierText);
    astNumberLiteral:
      astNodeSummary := astNodeSummary + ' ' + IntToStr(node^.numberValue);
    astCondition, astBinaryExpression, astUnaryExpression:
      astNodeSummary := astNodeSummary + ' op=' + IntToStr(Ord(node^.operatorSymbol))
  end;
  if node^.hasResolvedType then
    case node^.resolvedType of
      typeInteger:
        astNodeSummary := astNodeSummary + ' :integer';
      typeBoolean:
        astNodeSummary := astNodeSummary + ' :boolean'
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
  newAstNode^.hasResolvedType := false;
  newAstNode^.resolvedType := typeInteger;
  newAstNode^.operatorSymbol := nul;
  newAstNode^.firstChild := nil;
  newAstNode^.lastChild := nil;
  newAstNode^.nextSibling := nil
end;

function newProgramNode(const source: sourceContext): astNode;
begin
  newProgramNode := newAstNode(astProgram, source)
end;

function newBlockNode(const source: sourceContext): astNode;
begin
  newBlockNode := newAstNode(astBlock, source)
end;

function newConstDeclarationNode(const declarationIdentifier: identifier;
                                 declarationValue: integer;
                                 declaredType: typeValue;
                                 const source: sourceContext): astNode;
begin
  newConstDeclarationNode := newAstNode(astConstDeclaration, source);
  newConstDeclarationNode^.identifierText := declarationIdentifier;
  newConstDeclarationNode^.numberValue := declarationValue;
  newConstDeclarationNode^.declaredType := declaredType
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

function newConditionNode(conditionOperator: symbol;
                          const source: sourceContext): astNode;
begin
  newConditionNode := newAstNode(astCondition, source);
  newConditionNode^.operatorSymbol := conditionOperator
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

procedure appendArgumentNode(callNode, argumentNode: astNode);
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
