{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-22

  Symbol table support for semantic analysis and code generation.  This unit owns symbol storage,
  scope save/restore, declaration insertion, identifier lookup, and accessors
  for declaration metadata used by later passes. }
unit symboltable;

interface

uses
  diagnostics, tokens, typetable;

const
  symbolTableMax = 100;      {length of identifier table}

type
  declarationKind = (constant, variable, proc);
  builtinProcedure = (builtinNone, builtinRead, builtinWrite);
  symbolIndex = 0..symbolTableMax;

procedure initializeSymbolTable;
function markScope: symbolIndex;
procedure restoreScope(scopeMarker: symbolIndex);
function addConstant(const declarationIdentifier: identifier;
                     declarationValue: integer;
                     declaredType: typeValue): symbolIndex;
function addVariable(const declarationIdentifier: identifier;
                     declarationLevelValue: integer;
                     var nextAddress: integer;
                     declaredType: typeValue): symbolIndex;
function addProcedure(const declarationIdentifier: identifier;
                      declarationLevelValue: integer): symbolIndex;
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
function getBuiltinProcedure(index: symbolIndex): builtinProcedure;
function builtinProcedureName(procKind: builtinProcedure): string;

implementation

uses
  SysUtils;

type
  symbolTableEntry = record
    identifier: identifier; {sentinel slot 0 is used by lookupSymbol}
    case declarationType: declarationKind of
      constant: (constantValue: integer);
      variable, proc: (declarationLevel, address: integer)
      {for variables, address is the stack slot; for procedures, the entry point}
  end;

var
  tableTop: symbolIndex;
  tableEntries: array [symbolIndex] of symbolTableEntry;
  entryTypes: array [symbolIndex] of typeValue;
  entryVisible: array [symbolIndex] of boolean;
  entryBuiltinProcedures: array [symbolIndex] of builtinProcedure;

function identifierFromString(const text: string): identifier;
var
  characterIndex: integer;
begin
  FillChar(identifierFromString, SizeOf(identifierFromString), ' ');
  for characterIndex := 1 to Length(text) do
  begin
    if characterIndex > maxIdentLength then
      break;
    identifierFromString[characterIndex] := text[characterIndex]
  end
end;

procedure predeclareBuiltinProcedure(const procedureName: string);
begin
  if addProcedure(identifierFromString(procedureName), 0) = 0 then
    exit;
  if SameText(procedureName, 'read') then
    entryBuiltinProcedures[tableTop] := builtinRead
  else if SameText(procedureName, 'write') then
    entryBuiltinProcedures[tableTop] := builtinWrite
end;

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
  tableTop := 0;
  entryVisible[0] := false;
  entryBuiltinProcedures[0] := builtinNone;
  predeclareBuiltinProcedure('read');
  predeclareBuiltinProcedure('write')
end;

function markScope: symbolIndex;
begin
  markScope := tableTop
end;

procedure restoreScope(scopeMarker: symbolIndex);
var
  entryIndex: symbolIndex;
begin
  for entryIndex := scopeMarker + 1 to tableTop do
    entryVisible[entryIndex] := false
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
    entryTypes[tableTop] := declaredType;
    entryVisible[tableTop] := true;
    entryBuiltinProcedures[tableTop] := builtinNone;
    declarationType := constant;
    constantValue := declarationValue
  end;
  addConstant := tableTop
end;

function addVariable(const declarationIdentifier: identifier;
                     declarationLevelValue: integer;
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
    entryTypes[tableTop] := declaredType;
    entryVisible[tableTop] := true;
    entryBuiltinProcedures[tableTop] := builtinNone;
    declarationType := variable;
    declarationLevel := declarationLevelValue;
    address := nextAddress
  end;
  nextAddress := nextAddress + 1;
  addVariable := tableTop
end;

function addProcedure(const declarationIdentifier: identifier;
                      declarationLevelValue: integer): symbolIndex;
begin
  if not tryReserveEntry then
  begin
    addProcedure := 0;
    exit
  end;
  with tableEntries[tableTop] do
  begin
    identifier := declarationIdentifier;
    entryTypes[tableTop] := typeInteger;
    entryVisible[tableTop] := true;
    entryBuiltinProcedures[tableTop] := builtinNone;
    declarationType := proc;
    declarationLevel := declarationLevelValue;
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
  while (searchIndex > 0) and
        ((not entryVisible[searchIndex]) or
         (tableEntries[searchIndex].identifier <> declarationIdentifier)) do
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
  getDeclarationType := entryTypes[index]
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

function getBuiltinProcedure(index: symbolIndex): builtinProcedure;
begin
  getBuiltinProcedure := entryBuiltinProcedures[index]
end;

function builtinProcedureName(procKind: builtinProcedure): string;
begin
  case procKind of
    builtinRead:
      builtinProcedureName := 'read';
    builtinWrite:
      builtinProcedureName := 'write';
  else
    builtinProcedureName := ''
  end
end;

end.
