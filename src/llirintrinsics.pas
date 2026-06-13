{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-06-13

  Shared target-neutral intrinsic metadata for LLIR. This unit defines the
  intrinsic identifiers and their contract-level typing/arity rules without
  choosing how any backend realizes them. The LLIR interpreter may execute
  these intrinsics directly as a testing backend, while later native backends
  may lower the same identifiers to syscalls or runtime helpers. }
unit llirintrinsics;

{$mode objfpc}

interface

uses
  typetable;

type
  llirIntrinsicKind = (
    irIntrinsicNone,
    irIntrinsicReadInt,
    irIntrinsicReadChar,
    irIntrinsicWriteInt,
    irIntrinsicWriteChar,
    irIntrinsicWriteString,
    irIntrinsicWriteLn,
    irIntrinsicReadLn
  );

  llirIntrinsicSideEffect = (
    irSideEffectNone,
    irSideEffectIO
  );

function llirIntrinsicForReadType(valueType: typeValue): llirIntrinsicKind;
function llirIntrinsicForWriteType(valueType: typeValue): llirIntrinsicKind;
function intrinsicParameterCount(kind: llirIntrinsicKind): integer;
function intrinsicHasReturnValue(kind: llirIntrinsicKind): boolean;
function intrinsicReturnType(kind: llirIntrinsicKind): typeValue;
function intrinsicSideEffect(kind: llirIntrinsicKind): llirIntrinsicSideEffect;
function intrinsicAcceptsValueType(kind: llirIntrinsicKind; valueType: typeValue): boolean;
function intrinsicKindToString(kind: llirIntrinsicKind): string;
function intrinsicKindFromString(const name: string): llirIntrinsicKind;

implementation

uses
  SysUtils;

function llirIntrinsicForReadType(valueType: typeValue): llirIntrinsicKind;
begin
  if valueType = typeChar then
    llirIntrinsicForReadType := irIntrinsicReadChar
  else
    llirIntrinsicForReadType := irIntrinsicReadInt
end;

function llirIntrinsicForWriteType(valueType: typeValue): llirIntrinsicKind;
begin
  if valueType = typeChar then
    llirIntrinsicForWriteType := irIntrinsicWriteChar
  else
    llirIntrinsicForWriteType := irIntrinsicWriteInt
end;

function intrinsicParameterCount(kind: llirIntrinsicKind): integer;
begin
  case kind of
    irIntrinsicWriteInt,
    irIntrinsicWriteChar,
    irIntrinsicWriteString:
      intrinsicParameterCount := 1;
  else
    intrinsicParameterCount := 0
  end
end;

function intrinsicHasReturnValue(kind: llirIntrinsicKind): boolean;
begin
  intrinsicHasReturnValue := kind in [irIntrinsicReadInt, irIntrinsicReadChar]
end;

function intrinsicReturnType(kind: llirIntrinsicKind): typeValue;
begin
  case kind of
    irIntrinsicReadChar:
      intrinsicReturnType := typeChar;
  else
    intrinsicReturnType := typeInteger
  end
end;

function intrinsicSideEffect(kind: llirIntrinsicKind): llirIntrinsicSideEffect;
begin
  if kind = irIntrinsicNone then
    intrinsicSideEffect := irSideEffectNone
  else
    intrinsicSideEffect := irSideEffectIO
end;

function intrinsicAcceptsValueType(kind: llirIntrinsicKind; valueType: typeValue): boolean;
begin
  case kind of
    irIntrinsicWriteInt:
      intrinsicAcceptsValueType := valueType in [typeInteger, typeBoolean];
    irIntrinsicWriteChar:
      intrinsicAcceptsValueType := valueType = typeChar;
    irIntrinsicWriteString:
      intrinsicAcceptsValueType := valueType = typeChar;
  else
    intrinsicAcceptsValueType := true
  end
end;

function intrinsicKindToString(kind: llirIntrinsicKind): string;
begin
  case kind of
    irIntrinsicReadInt: intrinsicKindToString := 'read_int';
    irIntrinsicReadChar: intrinsicKindToString := 'read_char';
    irIntrinsicWriteInt: intrinsicKindToString := 'write_int';
    irIntrinsicWriteChar: intrinsicKindToString := 'write_char';
    irIntrinsicWriteString: intrinsicKindToString := 'write_string';
    irIntrinsicWriteLn: intrinsicKindToString := 'writeln';
    irIntrinsicReadLn: intrinsicKindToString := 'readln';
  else
    intrinsicKindToString := 'none'
  end
end;

function intrinsicKindFromString(const name: string): llirIntrinsicKind;
begin
  if SameText(name, 'read_int') then
    intrinsicKindFromString := irIntrinsicReadInt
  else if SameText(name, 'read_char') then
    intrinsicKindFromString := irIntrinsicReadChar
  else if SameText(name, 'write_int') then
    intrinsicKindFromString := irIntrinsicWriteInt
  else if SameText(name, 'write_char') then
    intrinsicKindFromString := irIntrinsicWriteChar
  else if SameText(name, 'write_string') then
    intrinsicKindFromString := irIntrinsicWriteString
  else if SameText(name, 'writeln') then
    intrinsicKindFromString := irIntrinsicWriteLn
  else if SameText(name, 'readln') then
    intrinsicKindFromString := irIntrinsicReadLn
  else
    intrinsicKindFromString := irIntrinsicNone
end;

end.
