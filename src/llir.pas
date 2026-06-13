{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-06-05

  Lower-level IR definitions and state management for the current normalized
  LLIR-based backend representation. This unit owns the current LLIR image,
  issues temporary and label identifiers, appends procedures, basic blocks, and
  instructions, and can dump the generated IR for inspection. It deliberately
  stays data-only: flat records, fixed arrays, and counts. It does not know
  about AST nodes, parsing, register allocation, stack slots, frame offsets, or
  target-code emission. }
unit llir;

{$mode objfpc}

interface

uses
  tokens, typetable, symboltable;

const
  maxTacInstructions = 500;
  maxTacBasicBlocks = 100;
  maxTacProcedures = 64;
  maxTacOperandsPerCall = maxProcedureParameters;

type
  llirInstructionIndex = 0..maxTacInstructions;
  llirBasicBlockIndex = 0..maxTacBasicBlocks;
  llirProcedureIndex = 0..maxTacProcedures;
  llirTemporaryId = 0..maxTacInstructions;
  llirLabelId = 0..maxTacInstructions;
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

  llirInstructionKind = (
    irNoOp,
    irAdd,
    irSub,
    irMul,
    irDiv,
    irMod,
    irNeg,
    irCmpEq,
    irCmpNe,
    irCmpLt,
    irCmpLe,
    irCmpGt,
    irCmpGe,
    irJump,
    irBranchTrue,
    irBranchFalse,
    irArg,
    irCall,
    irResult,
    irIntrinsicCall,
    irAddrGlobal,
    irLoadConst,
    irCopy,
    irAddrLocal,
    irAddrParam,
    irFieldAddr,
    irIndexAddr,
    irLoadAddr,
    irStoreAddr,
    irGoto,
    irLabel,
    irLoadVar,
    irStoreVar,
    irReturn
  );

  llirOperandKind = (
    irOperandNone,
    irOperandImmediate,
    irOperandLocal,
    irOperandParameter,
    irOperandTemporary,
    irOperandGlobal,
    irOperandLabel,
    irOperandProcedure,
    irOperandIntrinsic
  );

  llirOperandSize = (
    irSizeNone,
    irSizeByte,
    irSizeWord,
    irSizeDWord,
    irSizeQWord,
    irSizeAddress
  );

  llirOperand = record
    kind: llirOperandKind;
    valueType: typeValue;
    size: llirOperandSize;
    symbol: symbolIndex;
    name: identifier;
    intrinsicKind: llirIntrinsicKind;
    case llirOperandKind of
      irOperandNone:
        ();
      irOperandImmediate:
        (constantValue: integer);
      irOperandTemporary:
        (temporaryId: llirTemporaryId);
      irOperandLabel:
        (labelId: llirLabelId)
  end;

  llirInstruction = record
    kind: llirInstructionKind;
    resultOperand: llirOperand;
    leftOperand: llirOperand;
    rightOperand: llirOperand;
    targetOperand: llirOperand;
    positionIndex: integer;
    operatorSymbol: symbol;
    callArgumentCount: integer;
    callArguments: array [1..maxTacOperandsPerCall] of llirOperand
  end;

  llirBasicBlock = record
    labelId: llirLabelId;
    firstInstruction: llirInstructionIndex;
    instructionCount: integer
  end;

  llirTemporaryInfo = record
    temporaryId: llirTemporaryId;
    valueType: typeValue;
    size: llirOperandSize
  end;

  llirProcedure = record
    name: identifier;
    symbol: symbolIndex;
    hasReturnValue: boolean;
    returnType: typeValue;
    parameterCount: integer;
    parameters: array [1..maxProcedureParameters] of llirOperand;
    localCount: integer;
    locals: array [1..symbolTableMax] of llirOperand;
    temporaryCount: integer;
    temporaries: array [1..maxTacInstructions] of llirTemporaryInfo;
    basicBlockCount: integer;
    basicBlocks: array [1..maxTacBasicBlocks] of llirBasicBlock;
    labelBlockIndex: array [1..maxTacInstructions] of llirBasicBlockIndex;
    instructionCount: integer;
    instructions: array [1..maxTacInstructions] of llirInstruction;
    labelCount: integer
  end;

  llirProgram = record
    globalCount: integer;
    globals: array [1..symbolTableMax] of llirOperand;
    procedureCount: integer;
    procedures: array [1..maxTacProcedures] of llirProcedure;
    basicBlockCount: integer;
    instructionCount: integer;
    temporaryCount: integer;
    labelCount: integer;
    overflow: boolean
  end;

procedure initializeLlir;
function llirOverflowed: boolean;
procedure getLlirProgram(var targetProgram: llirProgram);

function makeTacNoneOperand: llirOperand;
function makeTacConstOperand(const constantValue: integer; valueType: typeValue): llirOperand;
function makeTacSymbolOperand(symbol: symbolIndex; const name: identifier;
                              valueType: typeValue): llirOperand;
function makeTacTempOperand(temporaryId: llirTemporaryId; valueType: typeValue): llirOperand;
function makeTacLabelOperand(labelId: llirLabelId): llirOperand;
function makeTacProcedureOperand(symbol: symbolIndex; const name: identifier): llirOperand;
function makeTacIntrinsicOperand(intrinsicKind: llirIntrinsicKind): llirOperand;
function makeTacAddressTempOperand(temporaryId: llirTemporaryId): llirOperand;
function llirIntrinsicForReadType(valueType: typeValue): llirIntrinsicKind;
function llirIntrinsicForWriteType(valueType: typeValue): llirIntrinsicKind;

function newTacTemporary(valueType: typeValue): llirOperand;
function newTacAddressTemporary: llirOperand;
function newTacLabel: llirLabelId;

function newTacInstruction(kind: llirInstructionKind): llirInstruction;
function appendTacProcedure(const procedureName: identifier;
                            procedureSymbol: symbolIndex): llirProcedureIndex;
procedure setTacProcedureReturnType(procedureIndex: llirProcedureIndex;
                                    valueType: typeValue;
                                    hasReturnValue: boolean);
procedure addTacProcedureParameter(procedureIndex: llirProcedureIndex;
                                   parameterSymbol: symbolIndex);
procedure addTacProcedureLocal(procedureIndex: llirProcedureIndex;
                               localSymbol: symbolIndex);
procedure addTacGlobal(globalSymbol: symbolIndex);
function appendTacBasicBlock(blockLabelId: llirLabelId): llirBasicBlockIndex;
function appendTacInstruction(const instruction: llirInstruction): llirInstructionIndex;
procedure setTacCallArgument(var instruction: llirInstruction; argumentIndex: integer;
                             const argument: llirOperand);
procedure dumpLlir(const outputFileName: string);

implementation

uses
  SysUtils;

var
  currentProgram: llirProgram;
  currentProcedure: llirProcedureIndex;
  currentBasicBlock: llirBasicBlockIndex;

function instructionEndsBasicBlock(kind: llirInstructionKind): boolean;
begin
  instructionEndsBasicBlock := kind in [irJump, irBranchTrue, irBranchFalse,
                                        irGoto, irReturn]
end;

function currentProcedureHasOpenBlock: boolean;
begin
  currentProcedureHasOpenBlock := (currentProcedure <> 0) and (currentBasicBlock <> 0)
end;

function currentBlockInstructionCount: integer;
begin
  if currentProcedureHasOpenBlock then
    currentBlockInstructionCount :=
      currentProgram.procedures[currentProcedure].basicBlocks[currentBasicBlock].instructionCount
  else
    currentBlockInstructionCount := 0
end;

function isStorageOperandKind(kind: llirOperandKind): boolean;
begin
  isStorageOperandKind := kind in [irOperandLocal, irOperandParameter, irOperandGlobal]
end;

function isValueOperandKind(kind: llirOperandKind): boolean;
begin
  isValueOperandKind := kind in [irOperandImmediate, irOperandTemporary]
end;

function isAddressValueOperand(const operand: llirOperand): boolean;
begin
  isAddressValueOperand := (operand.kind = irOperandTemporary) and
                           (operand.size = irSizeAddress)
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

function intrinsicParameterType(kind: llirIntrinsicKind; parameterIndex: integer): typeValue;
begin
  intrinsicParameterType := typeInteger;
  if parameterIndex <> 1 then
    exit;

  case kind of
    irIntrinsicWriteChar:
      intrinsicParameterType := typeChar;
    irIntrinsicWriteString:
      intrinsicParameterType := typeChar;
  else
    intrinsicParameterType := typeInteger
  end
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

function validateTacIntrinsicCall(const instruction: llirInstruction): boolean;
var
  argumentIndex, expectedCount: integer;
  kind: llirIntrinsicKind;
begin
  kind := instruction.targetOperand.intrinsicKind;
  validateTacIntrinsicCall := (kind <> irIntrinsicNone) and
                              (intrinsicSideEffect(kind) = irSideEffectIO);
  if not validateTacIntrinsicCall then
    exit;

  expectedCount := intrinsicParameterCount(kind);
  validateTacIntrinsicCall := instruction.callArgumentCount = expectedCount;
  if not validateTacIntrinsicCall then
    exit;

  if intrinsicHasReturnValue(kind) then
    validateTacIntrinsicCall := instruction.resultOperand.kind = irOperandTemporary
  else
    validateTacIntrinsicCall := instruction.resultOperand.kind = irOperandNone;
  if not validateTacIntrinsicCall then
    exit;

  if intrinsicHasReturnValue(kind) and
     (instruction.resultOperand.valueType <> intrinsicReturnType(kind)) then
  begin
    validateTacIntrinsicCall := false;
    exit
  end;

  for argumentIndex := 1 to instruction.callArgumentCount do
  begin
    validateTacIntrinsicCall := isValueOperandKind(instruction.callArguments[argumentIndex].kind);
    if not validateTacIntrinsicCall then
      exit;
    if not intrinsicAcceptsValueType(kind,
                                     instruction.callArguments[argumentIndex].valueType) then
    begin
      validateTacIntrinsicCall := false;
      exit
    end
  end
end;

function instructionUsesStorageOperands(kind: llirInstructionKind): boolean;
begin
  instructionUsesStorageOperands := kind in [irAddrLocal, irAddrParam, irAddrGlobal,
                                             irLoadVar, irStoreVar]
end;

function validateTacInstruction(const instruction: llirInstruction): boolean;
begin
  validateTacInstruction := true;
  case instruction.kind of
    irAdd,
    irSub,
    irMul,
    irDiv,
    irMod,
    irCmpEq,
    irCmpNe,
    irCmpLt,
    irCmpLe,
    irCmpGt,
    irCmpGe:
      validateTacInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isValueOperandKind(instruction.leftOperand.kind) and
                                isValueOperandKind(instruction.rightOperand.kind);
    irNeg:
      validateTacInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isValueOperandKind(instruction.leftOperand.kind) and
                                (instruction.rightOperand.kind = irOperandNone);
    irJump:
      validateTacInstruction := instruction.targetOperand.kind = irOperandLabel;
    irBranchTrue,
    irBranchFalse:
      validateTacInstruction := isValueOperandKind(instruction.leftOperand.kind) and
                                (instruction.targetOperand.kind = irOperandLabel);
    irArg:
      validateTacInstruction := (instruction.resultOperand.kind = irOperandNone) and
                                isValueOperandKind(instruction.leftOperand.kind) and
                                (instruction.rightOperand.kind = irOperandNone) and
                                (instruction.targetOperand.kind = irOperandNone) and
                                (instruction.positionIndex >= 0) and
                                (instruction.positionIndex < maxTacOperandsPerCall);
    irCall:
      validateTacInstruction := (instruction.targetOperand.kind = irOperandProcedure) and
                                (instruction.resultOperand.kind = irOperandNone) and
                                (instruction.leftOperand.kind = irOperandNone) and
                                (instruction.rightOperand.kind = irOperandNone);
    irResult:
      validateTacInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                (instruction.leftOperand.kind = irOperandNone) and
                                (instruction.rightOperand.kind = irOperandNone) and
                                (instruction.targetOperand.kind = irOperandNone);
    irIntrinsicCall:
      begin
        validateTacInstruction := instruction.targetOperand.kind = irOperandIntrinsic;
        if validateTacInstruction then
          validateTacInstruction := (instruction.resultOperand.kind = irOperandNone) and
                                    (instruction.leftOperand.kind = irOperandNone) and
                                    (instruction.rightOperand.kind = irOperandNone)
      end;
    irAddrGlobal:
      validateTacInstruction := isAddressValueOperand(instruction.resultOperand) and
                                (instruction.leftOperand.kind = irOperandGlobal);
    irLoadConst:
      validateTacInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                (instruction.leftOperand.kind = irOperandImmediate);
    irCopy:
      validateTacInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isValueOperandKind(instruction.leftOperand.kind) and
                                (instruction.rightOperand.kind = irOperandNone);
    irAddrLocal:
      validateTacInstruction := isAddressValueOperand(instruction.resultOperand) and
                                (instruction.leftOperand.kind = irOperandLocal);
    irAddrParam:
      validateTacInstruction := isAddressValueOperand(instruction.resultOperand) and
                                (instruction.leftOperand.kind = irOperandParameter);
    irFieldAddr:
      validateTacInstruction := isAddressValueOperand(instruction.resultOperand) and
                                isAddressValueOperand(instruction.leftOperand) and
                                isValueOperandKind(instruction.rightOperand.kind);
    irIndexAddr:
      validateTacInstruction := isAddressValueOperand(instruction.resultOperand) and
                                isAddressValueOperand(instruction.leftOperand) and
                                isValueOperandKind(instruction.rightOperand.kind) and
                                isValueOperandKind(instruction.targetOperand.kind);
    irLoadAddr:
      validateTacInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isAddressValueOperand(instruction.leftOperand);
    irStoreAddr:
      validateTacInstruction := isAddressValueOperand(instruction.resultOperand) and
                                isValueOperandKind(instruction.leftOperand.kind);
    irGoto:
      validateTacInstruction := instruction.targetOperand.kind = irOperandLabel;
    irLoadVar:
      validateTacInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isStorageOperandKind(instruction.leftOperand.kind);
    irStoreVar:
      validateTacInstruction := isStorageOperandKind(instruction.resultOperand.kind) and
                                isValueOperandKind(instruction.leftOperand.kind);
    irReturn,
    irNoOp,
    irLabel:
      validateTacInstruction := true
  end;

  if validateTacInstruction then
    if not instructionUsesStorageOperands(instruction.kind) then
      validateTacInstruction := not isStorageOperandKind(instruction.leftOperand.kind) and
                                not isStorageOperandKind(instruction.rightOperand.kind) and
                                not isStorageOperandKind(instruction.targetOperand.kind)
end;

procedure bindLabelToCurrentBlock(labelId: llirLabelId);
begin
  if (labelId = 0) or not currentProcedureHasOpenBlock then
    exit;

  currentProgram.procedures[currentProcedure].labelBlockIndex[labelId] := currentBasicBlock;
  if currentProgram.procedures[currentProcedure].basicBlocks[currentBasicBlock].labelId = 0 then
    currentProgram.procedures[currentProcedure].basicBlocks[currentBasicBlock].labelId := labelId
end;

function createTacBasicBlock(blockLabelId: llirLabelId): llirBasicBlockIndex;
begin
  createTacBasicBlock := 0;
  if currentProcedure = 0 then
  begin
    currentProgram.overflow := true;
    exit
  end;

  if currentProgram.basicBlockCount >= maxTacBasicBlocks then
  begin
    currentProgram.overflow := true;
    exit
  end;

  with currentProgram.procedures[currentProcedure] do
  begin
    if basicBlockCount >= maxTacBasicBlocks then
    begin
      currentProgram.overflow := true;
      exit
    end;

    basicBlockCount := basicBlockCount + 1;
    createTacBasicBlock := basicBlockCount;
    basicBlocks[createTacBasicBlock].labelId := blockLabelId;
    basicBlocks[createTacBasicBlock].firstInstruction := 0;
    basicBlocks[createTacBasicBlock].instructionCount := 0
  end;

  currentProgram.basicBlockCount := currentProgram.basicBlockCount + 1;
  currentBasicBlock := createTacBasicBlock
end;

function identifierToString(const identifierName: identifier): string;
var
  characterIndex: integer;
begin
  identifierToString := '';
  for characterIndex := Low(identifierName) to High(identifierName) do
    identifierToString := identifierToString + identifierName[characterIndex];
  identifierToString := TrimRight(identifierToString)
end;

function instructionKindToString(kind: llirInstructionKind): string;
begin
  case kind of
    irNoOp: instructionKindToString := 'noop';
    irAdd: instructionKindToString := 'add';
    irSub: instructionKindToString := 'sub';
    irMul: instructionKindToString := 'mul';
    irDiv: instructionKindToString := 'div';
    irMod: instructionKindToString := 'mod';
    irNeg: instructionKindToString := 'neg';
    irCmpEq: instructionKindToString := 'cmp_eq';
    irCmpNe: instructionKindToString := 'cmp_ne';
    irCmpLt: instructionKindToString := 'cmp_lt';
    irCmpLe: instructionKindToString := 'cmp_le';
    irCmpGt: instructionKindToString := 'cmp_gt';
    irCmpGe: instructionKindToString := 'cmp_ge';
    irJump: instructionKindToString := 'jump';
    irBranchTrue: instructionKindToString := 'brtrue';
    irBranchFalse: instructionKindToString := 'brfalse';
    irArg: instructionKindToString := 'arg';
    irCall: instructionKindToString := 'call';
    irResult: instructionKindToString := 'result';
    irIntrinsicCall: instructionKindToString := 'intrinsic_call';
    irAddrGlobal: instructionKindToString := 'addr_global';
    irLoadConst: instructionKindToString := 'load_const';
    irCopy: instructionKindToString := 'copy';
    irAddrLocal: instructionKindToString := 'addr_local';
    irAddrParam: instructionKindToString := 'addr_param';
    irFieldAddr: instructionKindToString := 'field_addr';
    irIndexAddr: instructionKindToString := 'index_addr';
    irLoadAddr: instructionKindToString := 'load_addr';
    irStoreAddr: instructionKindToString := 'store_addr';
    irGoto: instructionKindToString := 'goto';
    irLabel: instructionKindToString := 'label';
    irLoadVar: instructionKindToString := 'load';
    irStoreVar: instructionKindToString := 'store';
    irReturn: instructionKindToString := 'return'
  end
end;

function typeToString(valueType: typeValue): string;
begin
  case valueType of
    typeInteger: typeToString := 'integer';
    typeBoolean: typeToString := 'boolean';
    typeChar: typeToString := 'char'
  end
end;

function typeToOperandSize(valueType: typeValue): llirOperandSize;
begin
  case valueType of
    typeBoolean, typeChar:
      typeToOperandSize := irSizeByte;
    typeInteger:
      typeToOperandSize := irSizeDWord
  end
end;

function operandSizeToString(size: llirOperandSize): string;
begin
  case size of
    irSizeByte: operandSizeToString := 'byte';
    irSizeWord: operandSizeToString := 'word';
    irSizeDWord: operandSizeToString := 'dword';
    irSizeQWord: operandSizeToString := 'qword';
    irSizeAddress: operandSizeToString := 'address';
  else
    operandSizeToString := 'none'
  end
end;

function procedureReturnTypeToString(hasReturnValue: boolean;
                                     returnType: typeValue): string;
begin
  if hasReturnValue then
    procedureReturnTypeToString := typeToString(returnType)
  else
    procedureReturnTypeToString := 'none'
end;

function operatorToString(operatorSymbol: symbol): string;
begin
  case operatorSymbol of
    plus: operatorToString := '+';
    minus: operatorToString := '-';
    times: operatorToString := '*';
    slash: operatorToString := '/';
    eql: operatorToString := '=';
    neq: operatorToString := '<>';
    lss: operatorToString := '<';
    leq: operatorToString := '<=';
    gtr: operatorToString := '>';
    geq: operatorToString := '>=';
    andsym: operatorToString := 'and';
    orsym: operatorToString := 'or';
    xorsym: operatorToString := 'xor';
    notsym: operatorToString := 'not'
  else
    operatorToString := ''
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

function routineOwnsSymbol(routineSymbol, operandSymbol: symbolIndex): boolean;
begin
  routineOwnsSymbol := false;
  if (routineSymbol = 0) or (operandSymbol = 0) then
    exit;
  if getDeclarationKind(operandSymbol) <> variable then
    exit;

  routineOwnsSymbol := getDeclarationLevel(operandSymbol) =
                       getDeclarationLevel(routineSymbol) + 1
end;

function classifySymbolOperand(symbol: symbolIndex): llirOperandKind;
var
  routineSymbol: symbolIndex;
begin
  classifySymbolOperand := irOperandGlobal;
  if symbol = 0 then
    exit;

  case getDeclarationKind(symbol) of
    constant:
      classifySymbolOperand := irOperandImmediate;
    variable:
      begin
        if getDeclarationLevel(symbol) = 0 then
          classifySymbolOperand := irOperandGlobal
        else
        begin
          routineSymbol := 0;
          if currentProcedure <> 0 then
            routineSymbol := currentProgram.procedures[currentProcedure].symbol;
          if routineOwnsSymbol(routineSymbol, symbol) and
             isProcedureParameterSymbol(routineSymbol, symbol) then
            classifySymbolOperand := irOperandParameter
          else
            classifySymbolOperand := irOperandLocal
        end
      end;
    func:
      classifySymbolOperand := irOperandGlobal;
    proc:
      if getBuiltinProcedure(symbol) <> builtinNone then
        classifySymbolOperand := irOperandIntrinsic
      else
        classifySymbolOperand := irOperandProcedure
  end
end;

function operandToString(const operand: llirOperand): string;
begin
  case operand.kind of
    irOperandNone:
      operandToString := '_';
    irOperandImmediate:
      operandToString := 'imm(' + IntToStr(operand.constantValue) + '):' +
                         typeToString(operand.valueType) + '/' +
                         operandSizeToString(operand.size);
    irOperandLocal:
      operandToString := 'local[' + identifierToString(operand.name) + ']:' +
                         typeToString(operand.valueType) + '/' +
                         operandSizeToString(operand.size);
    irOperandParameter:
      operandToString := 'param[' + identifierToString(operand.name) + ']:' +
                         typeToString(operand.valueType) + '/' +
                         operandSizeToString(operand.size);
    irOperandTemporary:
      operandToString := 'temp[t' + IntToStr(operand.temporaryId) + ']:' +
                         typeToString(operand.valueType) + '/' +
                         operandSizeToString(operand.size);
    irOperandGlobal:
      operandToString := 'global[' + identifierToString(operand.name) + ']:' +
                         typeToString(operand.valueType) + '/' +
                         operandSizeToString(operand.size);
    irOperandLabel:
      operandToString := 'label[L' + IntToStr(operand.labelId) + ']:' +
                         operandSizeToString(operand.size);
    irOperandProcedure:
      operandToString := 'proc[' + identifierToString(operand.name) + ']:' +
                         operandSizeToString(operand.size);
    irOperandIntrinsic:
      operandToString := 'intrinsic[' +
                         intrinsicKindToString(operand.intrinsicKind) + ']:' +
                         operandSizeToString(operand.size)
  end
end;

procedure initializeLlir;
begin
  FillChar(currentProgram, SizeOf(currentProgram), 0);
  currentProcedure := 0;
  currentBasicBlock := 0
end;

function llirOverflowed: boolean;
begin
  llirOverflowed := currentProgram.overflow
end;

procedure getLlirProgram(var targetProgram: llirProgram);
begin
  targetProgram := currentProgram
end;

function makeTacNoneOperand: llirOperand;
begin
  FillChar(makeTacNoneOperand, SizeOf(makeTacNoneOperand), 0);
  makeTacNoneOperand.kind := irOperandNone;
  makeTacNoneOperand.valueType := typeInteger;
  makeTacNoneOperand.size := irSizeNone;
  makeTacNoneOperand.intrinsicKind := irIntrinsicNone
end;

function makeTacConstOperand(const constantValue: integer; valueType: typeValue): llirOperand;
begin
  FillChar(makeTacConstOperand, SizeOf(makeTacConstOperand), 0);
  makeTacConstOperand.kind := irOperandImmediate;
  makeTacConstOperand.valueType := valueType;
  makeTacConstOperand.size := typeToOperandSize(valueType);
  makeTacConstOperand.intrinsicKind := irIntrinsicNone;
  makeTacConstOperand.constantValue := constantValue
end;

function makeTacSymbolOperand(symbol: symbolIndex; const name: identifier;
                              valueType: typeValue): llirOperand;
begin
  FillChar(makeTacSymbolOperand, SizeOf(makeTacSymbolOperand), 0);
  makeTacSymbolOperand.kind := classifySymbolOperand(symbol);
  makeTacSymbolOperand.valueType := valueType;
  makeTacSymbolOperand.size := typeToOperandSize(valueType);
  makeTacSymbolOperand.symbol := symbol;
  makeTacSymbolOperand.name := name;
  makeTacSymbolOperand.intrinsicKind := irIntrinsicNone
end;

function makeTacTempOperand(temporaryId: llirTemporaryId; valueType: typeValue): llirOperand;
begin
  FillChar(makeTacTempOperand, SizeOf(makeTacTempOperand), 0);
  makeTacTempOperand.kind := irOperandTemporary;
  makeTacTempOperand.valueType := valueType;
  makeTacTempOperand.size := typeToOperandSize(valueType);
  makeTacTempOperand.intrinsicKind := irIntrinsicNone;
  makeTacTempOperand.temporaryId := temporaryId
end;

function makeTacAddressTempOperand(temporaryId: llirTemporaryId): llirOperand;
begin
  makeTacAddressTempOperand := makeTacTempOperand(temporaryId, typeInteger);
  makeTacAddressTempOperand.size := irSizeAddress
end;

function makeTacLabelOperand(labelId: llirLabelId): llirOperand;
begin
  FillChar(makeTacLabelOperand, SizeOf(makeTacLabelOperand), 0);
  makeTacLabelOperand.kind := irOperandLabel;
  makeTacLabelOperand.valueType := typeInteger;
  makeTacLabelOperand.size := irSizeAddress;
  makeTacLabelOperand.intrinsicKind := irIntrinsicNone;
  makeTacLabelOperand.labelId := labelId
end;

function makeTacProcedureOperand(symbol: symbolIndex; const name: identifier): llirOperand;
begin
  FillChar(makeTacProcedureOperand, SizeOf(makeTacProcedureOperand), 0);
  makeTacProcedureOperand.kind := irOperandProcedure;
  makeTacProcedureOperand.valueType := typeInteger;
  makeTacProcedureOperand.size := irSizeAddress;
  makeTacProcedureOperand.symbol := symbol;
  makeTacProcedureOperand.name := name;
  makeTacProcedureOperand.intrinsicKind := irIntrinsicNone
end;

function makeTacIntrinsicOperand(intrinsicKind: llirIntrinsicKind): llirOperand;
begin
  FillChar(makeTacIntrinsicOperand, SizeOf(makeTacIntrinsicOperand), 0);
  makeTacIntrinsicOperand.kind := irOperandIntrinsic;
  makeTacIntrinsicOperand.valueType := typeInteger;
  makeTacIntrinsicOperand.size := irSizeAddress;
  makeTacIntrinsicOperand.intrinsicKind := intrinsicKind
end;

function newTacTemporary(valueType: typeValue): llirOperand;
begin
  if currentProgram.temporaryCount >= maxTacInstructions then
  begin
    currentProgram.overflow := true;
    newTacTemporary := makeTacNoneOperand;
    exit
  end;

  currentProgram.temporaryCount := currentProgram.temporaryCount + 1;
  if currentProcedure <> 0 then
    with currentProgram.procedures[currentProcedure] do
    begin
      if temporaryCount >= maxTacInstructions then
      begin
        currentProgram.overflow := true;
        newTacTemporary := makeTacNoneOperand;
        exit
      end;

      temporaryCount := temporaryCount + 1;
      temporaries[temporaryCount].temporaryId := currentProgram.temporaryCount;
      temporaries[temporaryCount].valueType := valueType;
      temporaries[temporaryCount].size := typeToOperandSize(valueType)
    end;
  newTacTemporary := makeTacTempOperand(currentProgram.temporaryCount, valueType)
end;

function newTacAddressTemporary: llirOperand;
begin
  if currentProgram.temporaryCount >= maxTacInstructions then
  begin
    currentProgram.overflow := true;
    newTacAddressTemporary := makeTacNoneOperand;
    exit
  end;

  currentProgram.temporaryCount := currentProgram.temporaryCount + 1;
  if currentProcedure <> 0 then
    with currentProgram.procedures[currentProcedure] do
    begin
      if temporaryCount >= maxTacInstructions then
      begin
        currentProgram.overflow := true;
        newTacAddressTemporary := makeTacNoneOperand;
        exit
      end;

      temporaryCount := temporaryCount + 1;
      temporaries[temporaryCount].temporaryId := currentProgram.temporaryCount;
      temporaries[temporaryCount].valueType := typeInteger;
      temporaries[temporaryCount].size := irSizeAddress
    end;
  newTacAddressTemporary := makeTacAddressTempOperand(currentProgram.temporaryCount)
end;

function newTacLabel: llirLabelId;
begin
  if currentProgram.labelCount >= maxTacInstructions then
  begin
    currentProgram.overflow := true;
    newTacLabel := 0;
    exit
  end;

  currentProgram.labelCount := currentProgram.labelCount + 1;
  if currentProcedure <> 0 then
    currentProgram.procedures[currentProcedure].labelCount :=
      currentProgram.procedures[currentProcedure].labelCount + 1;
  newTacLabel := currentProgram.labelCount
end;

function newTacInstruction(kind: llirInstructionKind): llirInstruction;
var
  argumentIndex: integer;
begin
  FillChar(newTacInstruction, SizeOf(newTacInstruction), 0);
  newTacInstruction.kind := kind;
  newTacInstruction.resultOperand := makeTacNoneOperand;
  newTacInstruction.leftOperand := makeTacNoneOperand;
  newTacInstruction.rightOperand := makeTacNoneOperand;
  newTacInstruction.targetOperand := makeTacNoneOperand;
  newTacInstruction.positionIndex := 0;
  newTacInstruction.operatorSymbol := nul;
  newTacInstruction.callArgumentCount := 0;
  for argumentIndex := 1 to maxTacOperandsPerCall do
    newTacInstruction.callArguments[argumentIndex] := makeTacNoneOperand
end;

function appendTacProcedure(const procedureName: identifier;
                            procedureSymbol: symbolIndex): llirProcedureIndex;
begin
  appendTacProcedure := 0;
  if currentProgram.procedureCount >= maxTacProcedures then
  begin
    currentProgram.overflow := true;
    exit
  end;

  currentProgram.procedureCount := currentProgram.procedureCount + 1;
  appendTacProcedure := currentProgram.procedureCount;
  currentProcedure := appendTacProcedure;
  currentBasicBlock := 0;
  with currentProgram.procedures[currentProcedure] do
  begin
    name := procedureName;
    symbol := procedureSymbol;
    hasReturnValue := false;
    returnType := typeInteger;
    parameterCount := 0;
    localCount := 0;
    temporaryCount := 0;
    basicBlockCount := 0;
    instructionCount := 0;
    labelCount := 0
  end
end;

procedure setTacProcedureReturnType(procedureIndex: llirProcedureIndex;
                                    valueType: typeValue;
                                    hasReturnValue: boolean);
begin
  if (procedureIndex < 1) or (procedureIndex > currentProgram.procedureCount) then
  begin
    currentProgram.overflow := true;
    exit
  end;

  currentProgram.procedures[procedureIndex].returnType := valueType;
  currentProgram.procedures[procedureIndex].hasReturnValue := hasReturnValue
end;

procedure addTacProcedureParameter(procedureIndex: llirProcedureIndex;
                                   parameterSymbol: symbolIndex);
begin
  if (procedureIndex < 1) or (procedureIndex > currentProgram.procedureCount) or
     (parameterSymbol = 0) then
  begin
    currentProgram.overflow := true;
    exit
  end;

  with currentProgram.procedures[procedureIndex] do
  begin
    if parameterCount >= maxProcedureParameters then
    begin
      currentProgram.overflow := true;
      exit
    end;

    parameterCount := parameterCount + 1;
    parameters[parameterCount] := makeTacSymbolOperand(
      parameterSymbol,
      getDeclarationIdentifier(parameterSymbol),
      getDeclarationType(parameterSymbol))
  end
end;

procedure addTacProcedureLocal(procedureIndex: llirProcedureIndex;
                               localSymbol: symbolIndex);
begin
  if (procedureIndex < 1) or (procedureIndex > currentProgram.procedureCount) or
     (localSymbol = 0) then
  begin
    currentProgram.overflow := true;
    exit
  end;

  with currentProgram.procedures[procedureIndex] do
  begin
    if localCount >= symbolTableMax then
    begin
      currentProgram.overflow := true;
      exit
    end;

    localCount := localCount + 1;
    locals[localCount] := makeTacSymbolOperand(
      localSymbol,
      getDeclarationIdentifier(localSymbol),
      getDeclarationType(localSymbol))
  end
end;

procedure addTacGlobal(globalSymbol: symbolIndex);
begin
  if globalSymbol = 0 then
  begin
    currentProgram.overflow := true;
    exit
  end;

  if currentProgram.globalCount >= symbolTableMax then
  begin
    currentProgram.overflow := true;
    exit
  end;

  currentProgram.globalCount := currentProgram.globalCount + 1;
  currentProgram.globals[currentProgram.globalCount] := makeTacSymbolOperand(
    globalSymbol,
    getDeclarationIdentifier(globalSymbol),
    getDeclarationType(globalSymbol))
end;

function appendTacBasicBlock(blockLabelId: llirLabelId): llirBasicBlockIndex;
begin
  if currentProcedure = 0 then
  begin
    currentProgram.overflow := true;
    appendTacBasicBlock := 0;
    exit
  end;

  if currentProcedureHasOpenBlock then
  begin
    if currentBlockInstructionCount = 0 then
    begin
      bindLabelToCurrentBlock(blockLabelId);
      appendTacBasicBlock := currentBasicBlock;
      exit
    end;
    currentBasicBlock := 0
  end;

  appendTacBasicBlock := createTacBasicBlock(0);
  bindLabelToCurrentBlock(blockLabelId)
end;

function appendTacInstruction(const instruction: llirInstruction): llirInstructionIndex;
begin
  appendTacInstruction := 0;
  if currentProcedure = 0 then
  begin
    currentProgram.overflow := true;
    exit
  end;

  if currentProgram.instructionCount >= maxTacInstructions then
  begin
    currentProgram.overflow := true;
    exit
  end;

  if not currentProcedureHasOpenBlock then
    if createTacBasicBlock(0) = 0 then
      exit;

  if not validateTacInstruction(instruction) then
  begin
    currentProgram.overflow := true;
    exit
  end;

  with currentProgram.procedures[currentProcedure] do
  begin
    if instructionCount >= maxTacInstructions then
    begin
      currentProgram.overflow := true;
      exit
    end;

    instructionCount := instructionCount + 1;
    appendTacInstruction := instructionCount;
    instructions[appendTacInstruction] := instruction
  end;

  currentProgram.instructionCount := currentProgram.instructionCount + 1;

  if currentBasicBlock <> 0 then
    with currentProgram.procedures[currentProcedure].basicBlocks[currentBasicBlock] do
    begin
      if firstInstruction = 0 then
        firstInstruction := appendTacInstruction;
      instructionCount := instructionCount + 1
    end;

  if instructionEndsBasicBlock(instruction.kind) then
    currentBasicBlock := 0
end;

procedure setTacCallArgument(var instruction: llirInstruction; argumentIndex: integer;
                             const argument: llirOperand);
begin
  if (argumentIndex < 1) or (argumentIndex > maxTacOperandsPerCall) then
  begin
    currentProgram.overflow := true;
    exit
  end;

  instruction.callArguments[argumentIndex] := argument;
  if instruction.callArgumentCount < argumentIndex then
    instruction.callArgumentCount := argumentIndex
end;

procedure dumpTacInstruction(var outputFile: Text; instructionIndex: integer;
                             const instruction: llirInstruction);
var
  argumentIndex: integer;
begin
  write(outputFile, instructionIndex:4, ' ', instructionKindToString(instruction.kind));
  if instruction.resultOperand.kind <> irOperandNone then
    write(outputFile, ' result=', operandToString(instruction.resultOperand));
  if instruction.leftOperand.kind <> irOperandNone then
    write(outputFile, ' left=', operandToString(instruction.leftOperand));
  if instruction.rightOperand.kind <> irOperandNone then
    write(outputFile, ' right=', operandToString(instruction.rightOperand));
  if instruction.targetOperand.kind <> irOperandNone then
    write(outputFile, ' target=', operandToString(instruction.targetOperand));
  if instruction.positionIndex <> 0 then
    write(outputFile, ' index=', instruction.positionIndex);
  if (instruction.kind = irArg) and (instruction.positionIndex = 0) then
    write(outputFile, ' index=0');
  if instruction.operatorSymbol <> nul then
    write(outputFile, ' op=', operatorToString(instruction.operatorSymbol));
  for argumentIndex := 1 to instruction.callArgumentCount do
    write(outputFile, ' arg', argumentIndex, '=',
          operandToString(instruction.callArguments[argumentIndex]));
  writeln(outputFile)
end;

procedure dumpLlir(const outputFileName: string);
var
  outputFile: Text;
  procedureIndex, itemIndex, instructionIndex, blockLastInstruction, labelIndex: integer;
begin
  Assign(outputFile, outputFileName);
  Rewrite(outputFile);
  writeln(outputFile, 'llir program');
  writeln(outputFile, 'globals ', currentProgram.globalCount);
  for itemIndex := 1 to currentProgram.globalCount do
    writeln(outputFile, 'global ', itemIndex, ' ',
            operandToString(currentProgram.globals[itemIndex]));
  writeln(outputFile, 'procedures ', currentProgram.procedureCount);
  for procedureIndex := 1 to currentProgram.procedureCount do
    with currentProgram.procedures[procedureIndex] do
    begin
      writeln(outputFile, 'proc ', procedureIndex, ' ',
              identifierToString(name),
              ' return=', procedureReturnTypeToString(hasReturnValue, returnType),
              ' params=', parameterCount,
              ' locals=', localCount,
              ' temps=', temporaryCount,
              ' blocks=', basicBlockCount,
              ' labels=', labelCount,
              ' instructions=', instructionCount);
      for itemIndex := 1 to parameterCount do
        writeln(outputFile, '  param ', itemIndex, ' ',
                operandToString(parameters[itemIndex]));
      for itemIndex := 1 to localCount do
        writeln(outputFile, '  local ', itemIndex, ' ',
                operandToString(locals[itemIndex]));
      for itemIndex := 1 to temporaryCount do
        writeln(outputFile, '  temp ', itemIndex, ' ',
                operandToString(makeTacTempOperand(temporaries[itemIndex].temporaryId,
                                                   temporaries[itemIndex].valueType)));
      for itemIndex := 1 to basicBlockCount do
        with basicBlocks[itemIndex] do
        begin
          if labelId <> 0 then
          begin
            write(outputFile, '  block ', itemIndex,
                  ' label=L', labelId);
            for labelIndex := Low(labelBlockIndex) to High(labelBlockIndex) do
              if (labelIndex <> labelId) and
                 (labelBlockIndex[labelIndex] = itemIndex) then
                write(outputFile, ' alias=L', labelIndex);
            writeln(outputFile,
                    ' first=', firstInstruction,
                    ' count=', instructionCount)
          end
          else
            writeln(outputFile, '  block ', itemIndex,
                    ' first=', firstInstruction,
                    ' count=', instructionCount);
          if instructionCount > 0 then
          begin
            blockLastInstruction := firstInstruction + instructionCount - 1;
            for instructionIndex := firstInstruction to blockLastInstruction do
              dumpTacInstruction(outputFile, instructionIndex,
                                 instructions[instructionIndex])
          end
        end;
      for labelIndex := Low(labelBlockIndex) to High(labelBlockIndex) do
        if labelBlockIndex[labelIndex] <> 0 then
          writeln(outputFile, '  labelmap L', labelIndex,
                  ' block=', labelBlockIndex[labelIndex],
                  ' first=',
                  basicBlocks[labelBlockIndex[labelIndex]].firstInstruction);
      writeln(outputFile, 'endproc')
    end;
  Close(outputFile)
end;

initialization
  initializeLlir;

end.
