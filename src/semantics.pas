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

function nodeSourceContext(node: astNode): sourceContext;
begin
  nodeSourceContext := node^.source
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
procedure analyzeCondition(node: astNode; var sema: semanticContext; var errorCount: integer); forward;
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
  childNode: astNode;
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
    astBooleanLiteral:
      begin
        setNodeType(node, typeBoolean);
        exit
      end;
    astBinaryExpression,
    astUnaryExpression:
      begin
        childNode := node^.firstChild;
        while childNode <> nil do
        begin
          analyzeExpression(childNode, sema, errorCount);
          childNode := childNode^.nextSibling
        end;
        setNodeType(node, typeInteger)
      end
  else
    begin
      childNode := node^.firstChild;
      while childNode <> nil do
      begin
        analyzeExpression(childNode, sema, errorCount);
        childNode := childNode^.nextSibling
      end;
      if node^.kind = astCondition then
        setNodeType(node, typeBoolean)
    end
  end
end;

procedure analyzeCondition(node: astNode; var sema: semanticContext; var errorCount: integer);
var
  childNode: astNode;
begin
  if node = nil then
    exit;

  childNode := node^.firstChild;
  while childNode <> nil do
  begin
    analyzeExpression(childNode, sema, errorCount);
    childNode := childNode^.nextSibling
  end;
  setNodeType(node, typeBoolean)
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
  targetNode, valueNode, conditionNode, thenOrBodyNode, childNode: astNode;
  resolvedSymbol: symbolIndex;
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

        analyzeExpression(valueNode, sema, errorCount)
      end;
    astCallStatement:
      begin
        targetNode := node^.firstChild;
        if targetNode <> nil then
        begin
          resolvedSymbol := lookupSymbol(targetNode^.identifierText);
          if resolvedSymbol = 0 then
            reportCompilerError(ERR_UNDECLARED_IDENTIFIER, nodeSourceContext(targetNode), errorCount)
          else
          begin
            rememberResolvedSymbol(targetNode, resolvedSymbol);
            setNodeType(targetNode, getDeclarationType(resolvedSymbol));
            if getDeclarationKind(resolvedSymbol) <> proc then
              reportCompilerError(ERR_CALL_OF_CONSTANT_OR_VARIABLE,
                                  nodeSourceContext(targetNode), errorCount)
          end
        end
      end;
    astIfStatement:
      begin
        conditionNode := node^.firstChild;
        thenOrBodyNode := nil;
        if conditionNode <> nil then
          thenOrBodyNode := conditionNode^.nextSibling;
        analyzeCondition(conditionNode, sema, errorCount);
        analyzeStatement(thenOrBodyNode, sema, errorCount)
      end;
    astWhileStatement:
      begin
        conditionNode := node^.firstChild;
        thenOrBodyNode := nil;
        if conditionNode <> nil then
          thenOrBodyNode := conditionNode^.nextSibling;
        analyzeCondition(conditionNode, sema, errorCount);
        analyzeStatement(thenOrBodyNode, sema, errorCount)
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
      astWhileStatement:
        analyzeStatement(childNode, sema, errorCount);
      astCondition:
        analyzeCondition(childNode, sema, errorCount);
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
