{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-22

  Symbol table support for semantic analysis and code generation.  This unit owns symbol storage,
  scope save/restore, declaration insertion, identifier lookup, and accessors
  for declaration metadata used by later passes. }
unit symboltable;

{$mode objfpc}

interface

uses
  diagnostics, tokens, typetable;

const
  symbolTableMax = 100;      {length of identifier table}

type
  declarationKind = (constant, variable, proc, func);
  builtinProcedure = (builtinNone, builtinRead, builtinReadLn,
                      builtinWrite, builtinWriteLn);
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
function addFunction(const declarationIdentifier: identifier;
                     declarationLevelValue: integer;
                     declaredType: typeValue): symbolIndex;
function addProcedureParameter(index: symbolIndex;
                               parameterType: typeValue;
                               parameterSymbol: symbolIndex): boolean;
function lookupSymbol(const declarationIdentifier: identifier): symbolIndex;
function lexicalLevelDistance(currentLevel, targetDeclarationLevel: integer;
                              const sourceContext: sourceContext;
                              var errorCount: integer): integer;
function getDeclarationKind(index: symbolIndex): declarationKind;
function getDeclarationType(index: symbolIndex): typeValue;
function getDeclarationIdentifier(index: symbolIndex): identifier;
function getDeclarationLevel(index: symbolIndex): integer;
function getAddress(index: symbolIndex): integer;
procedure setAddress(index: symbolIndex; newAddress: integer);
function getConstantValue(index: symbolIndex): integer;
function getBuiltinProcedure(index: symbolIndex): builtinProcedure;
function builtinProcedureName(procKind: builtinProcedure): string;
function getProcedureParameterCount(index: symbolIndex): integer;
function getProcedureParameterType(index: symbolIndex;
                                   parameterIndex: integer): typeValue;
function getProcedureParameterSymbol(index: symbolIndex;
                                     parameterIndex: integer): symbolIndex;
function isProcedureParameterSymbol(index, parameterSymbol: symbolIndex): boolean;

implementation

uses
  SysUtils;

type
  symbolTableEntry = record
    identifier: identifier; {sentinel slot 0 is used by lookupSymbol}
    case declarationType: declarationKind of
      constant: (constantValue: integer);
      variable, proc, func: (declarationLevel, address: integer)
      {for variables, address is the stack slot; for routines, the entry point}
  end;

var
  tableTop: symbolIndex;
  tableEntries: array [symbolIndex] of symbolTableEntry;
  entryTypes: array [symbolIndex] of typeValue;
  entryVisible: array [symbolIndex] of boolean;
  entryBuiltinProcedures: array [symbolIndex] of builtinProcedure;
  entryProcedureParameterCount: array [symbolIndex] of integer;
  entryProcedureParameterTypes: array [symbolIndex, 1..maxProcedureParameters] of typeValue;
  entryProcedureParameterSymbols: array [symbolIndex, 1..maxProcedureParameters] of symbolIndex;

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
  else if SameText(procedureName, 'readln') then
    entryBuiltinProcedures[tableTop] := builtinReadLn
  else if SameText(procedureName, 'write') then
    entryBuiltinProcedures[tableTop] := builtinWrite
  else if SameText(procedureName, 'writeln') then
    entryBuiltinProcedures[tableTop] := builtinWriteLn
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
  entryProcedureParameterCount[0] := 0;
  predeclareBuiltinProcedure('read');
  predeclareBuiltinProcedure('readln');
  predeclareBuiltinProcedure('write');
  predeclareBuiltinProcedure('writeln')
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
    entryProcedureParameterCount[tableTop] := 0;
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
    entryProcedureParameterCount[tableTop] := 0;
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
    entryProcedureParameterCount[tableTop] := 0;
    declarationType := proc;
    declarationLevel := declarationLevelValue;
    address := 0
  end;
  addProcedure := tableTop
end;

function addFunction(const declarationIdentifier: identifier;
                     declarationLevelValue: integer;
                     declaredType: typeValue): symbolIndex;
begin
  if not tryReserveEntry then
  begin
    addFunction := 0;
    exit
  end;
  with tableEntries[tableTop] do
  begin
    identifier := declarationIdentifier;
    entryTypes[tableTop] := declaredType;
    entryVisible[tableTop] := true;
    entryBuiltinProcedures[tableTop] := builtinNone;
    entryProcedureParameterCount[tableTop] := 0;
    declarationType := func;
    declarationLevel := declarationLevelValue;
    address := 0
  end;
  addFunction := tableTop
end;

function addProcedureParameter(index: symbolIndex;
                               parameterType: typeValue;
                               parameterSymbol: symbolIndex): boolean;
var
  nextParameterIndex: integer;
begin
  addProcedureParameter := false;
  if (index = 0) or not (getDeclarationKind(index) in [proc, func]) then
    exit;

  nextParameterIndex := entryProcedureParameterCount[index] + 1;
  if nextParameterIndex > maxProcedureParameters then
    exit;

  entryProcedureParameterCount[index] := nextParameterIndex;
  entryProcedureParameterTypes[index, nextParameterIndex] := parameterType;
  entryProcedureParameterSymbols[index, nextParameterIndex] := parameterSymbol;
  addProcedureParameter := true
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

function getDeclarationIdentifier(index: symbolIndex): identifier;
begin
  getDeclarationIdentifier := tableEntries[index].identifier
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
    builtinReadLn:
      builtinProcedureName := 'readln';
    builtinWrite:
      builtinProcedureName := 'write';
    builtinWriteLn:
      builtinProcedureName := 'writeln';
  else
    builtinProcedureName := ''
  end
end;

function getProcedureParameterCount(index: symbolIndex): integer;
begin
  getProcedureParameterCount := entryProcedureParameterCount[index]
end;

function getProcedureParameterType(index: symbolIndex;
                                   parameterIndex: integer): typeValue;
begin
  if (parameterIndex < 1) or
     (parameterIndex > entryProcedureParameterCount[index]) then
    getProcedureParameterType := typeInteger
  else
    getProcedureParameterType := entryProcedureParameterTypes[index, parameterIndex]
end;

function getProcedureParameterSymbol(index: symbolIndex;
                                     parameterIndex: integer): symbolIndex;
begin
  if (parameterIndex < 1) or
     (parameterIndex > entryProcedureParameterCount[index]) then
    getProcedureParameterSymbol := 0
  else
    getProcedureParameterSymbol := entryProcedureParameterSymbols[index, parameterIndex]
end;

function isProcedureParameterSymbol(index, parameterSymbol: symbolIndex): boolean;
var
  parameterIndex: integer;
begin
  isProcedureParameterSymbol := false;
  if (index = 0) or (parameterSymbol = 0) then
    exit;

  for parameterIndex := 1 to entryProcedureParameterCount[index] do
    if entryProcedureParameterSymbols[index, parameterIndex] = parameterSymbol then
    begin
      isProcedureParameterSymbol := true;
      exit
    end
end;

end.
