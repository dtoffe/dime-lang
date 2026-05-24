{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-22

  Symbol table support for semantic analysis and code generation.  This unit owns symbol storage,
  scope save/restore, declaration insertion, identifier lookup, and accessors
  for declaration metadata used by later passes. }
unit symtable;

interface

uses
  diagnostics, tokens;

const
  symbolTableMax = 100;      {length of identifier table}

type
  typeValue = (typeInteger);
  declarationKind = (constant, variable, proc);
  symbolIndex = 0..symbolTableMax;

procedure initializeSymbolTable;
function markScope: symbolIndex;
procedure restoreScope(scopeMarker: symbolIndex);
function addConstant(const declarationIdentifier: identifier;
                     declarationValue: integer;
                     declaredType: typeValue): symbolIndex;
function addVariable(const declarationIdentifier: identifier;
                     declarationLevel: integer;
                     var nextAddress: integer;
                     declaredType: typeValue): symbolIndex;
function addProcedure(const declarationIdentifier: identifier;
                      declarationLevel: integer): symbolIndex;
function lookupSymbol(const declarationIdentifier: identifier): symbolIndex;
function lexicalLevelDistance(currentLevel, targetDeclarationLevel: integer;
                              const sourceContext: sourceContext;
                              var errorCount: integer): integer;
function getDeclarationKind(index: symbolIndex): declarationKind;
function getDeclarationType(index: symbolIndex): typeValue;
function getDeclarationLevel(index: symbolIndex): integer;
function getAddress(index: symbolIndex): integer;
procedure setAddress(index: symbolIndex; newAddress: integer);
function getConstantValue(index: symbolIndex): integer;

implementation

uses
  SysUtils;

type
  symbolTableEntry = record
    identifier: identifier; {sentinel slot 0 is used by lookupSymbol}
    declaredType: typeValue;
    case declarationType: declarationKind of
      constant: (constantValue: integer);
      variable, proc: (declarationLevel, address: integer)
      {for variables, address is the stack slot; for procedures, the entry point}
  end;

var
  tableTop: symbolIndex;
  tableEntries: array [symbolIndex] of symbolTableEntry;

function tryReserveEntry: boolean;
begin
  if tableTop >= symbolTableMax then
    tryReserveEntry := false
  else
  begin
    tableTop := tableTop + 1;
    tryReserveEntry := true
  end
end;

procedure initializeSymbolTable;
begin
  tableTop := 0
end;

function markScope: symbolIndex;
begin
  markScope := tableTop
end;

procedure restoreScope(scopeMarker: symbolIndex);
begin
  tableTop := scopeMarker
end;

function addConstant(const declarationIdentifier: identifier;
                     declarationValue: integer;
                     declaredType: typeValue): symbolIndex;
begin
  if not tryReserveEntry then
  begin
    addConstant := 0;
    exit
  end;
  with tableEntries[tableTop] do
  begin
    identifier := declarationIdentifier;
    tableEntries[tableTop].declaredType := declaredType;
    declarationType := constant;
    constantValue := declarationValue
  end;
  addConstant := tableTop
end;

function addVariable(const declarationIdentifier: identifier;
                     declarationLevel: integer;
                     var nextAddress: integer;
                     declaredType: typeValue): symbolIndex;
begin
  if not tryReserveEntry then
  begin
    addVariable := 0;
    exit
  end;
  with tableEntries[tableTop] do
  begin
    identifier := declarationIdentifier;
    tableEntries[tableTop].declaredType := declaredType;
    declarationType := variable;
    tableEntries[tableTop].declarationLevel := declarationLevel;
    address := nextAddress
  end;
  nextAddress := nextAddress + 1;
  addVariable := tableTop
end;

function addProcedure(const declarationIdentifier: identifier;
                      declarationLevel: integer): symbolIndex;
begin
  if not tryReserveEntry then
  begin
    addProcedure := 0;
    exit
  end;
  with tableEntries[tableTop] do
  begin
    identifier := declarationIdentifier;
    declaredType := typeInteger;
    declarationType := proc;
    tableEntries[tableTop].declarationLevel := declarationLevel;
    address := 0
  end;
  addProcedure := tableTop
end;

function lookupSymbol(const declarationIdentifier: identifier): symbolIndex;
var
  searchIndex: symbolIndex;
begin
  tableEntries[0].identifier := declarationIdentifier;
  searchIndex := tableTop;
  while tableEntries[searchIndex].identifier <> declarationIdentifier do
    searchIndex := searchIndex - 1;
  lookupSymbol := searchIndex
end;

function lexicalLevelDistance(currentLevel, targetDeclarationLevel: integer;
                              const sourceContext: sourceContext;
                              var errorCount: integer): integer;
begin
  lexicalLevelDistance := currentLevel - targetDeclarationLevel;
  if (lexicalLevelDistance < 0) or (lexicalLevelDistance > 1) then
  begin
    reportCompilerError(ERR_PROCEDURES_GLOBAL_SCOPE_ONLY, sourceContext, errorCount);
    lexicalLevelDistance := 0
  end
end;

function getDeclarationKind(index: symbolIndex): declarationKind;
begin
  getDeclarationKind := tableEntries[index].declarationType
end;

function getDeclarationType(index: symbolIndex): typeValue;
begin
  getDeclarationType := tableEntries[index].declaredType
end;

function getDeclarationLevel(index: symbolIndex): integer;
begin
  getDeclarationLevel := tableEntries[index].declarationLevel
end;

function getAddress(index: symbolIndex): integer;
begin
  getAddress := tableEntries[index].address
end;

procedure setAddress(index: symbolIndex; newAddress: integer);
begin
  tableEntries[index].address := newAddress
end;

function getConstantValue(index: symbolIndex): integer;
begin
  getConstantValue := tableEntries[index].constantValue
end;

end.
