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
  tokens, typetable, symboltable, llirintrinsics;

const
  maxLlirInstructions = 500;
  maxLlirBasicBlocks = 100;
  maxLlirProcedures = 64;
  maxLlirOperandsPerCall = maxProcedureParameters;

type
  llirInstructionIndex = 0..maxLlirInstructions;
  llirBasicBlockIndex = 0..maxLlirBasicBlocks;
  llirProcedureIndex = 0..maxLlirProcedures;
  llirTemporaryId = 0..maxLlirInstructions;
  llirLabelId = 0..maxLlirInstructions;

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
    irCall,
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
    irSizeBits8,
    irSizeBits16,
    irSizeBits32,
    irSizeBits64,
    irSizePointer
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
    operatorSymbol: symbol;
    callArgumentCount: integer;
    callArguments: array [1..maxLlirOperandsPerCall] of llirOperand
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
    temporaries: array [1..maxLlirInstructions] of llirTemporaryInfo;
    basicBlockCount: integer;
    basicBlocks: array [1..maxLlirBasicBlocks] of llirBasicBlock;
    labelBlockIndex: array [1..maxLlirInstructions] of llirBasicBlockIndex;
    instructionCount: integer;
    instructions: array [1..maxLlirInstructions] of llirInstruction;
    labelCount: integer
  end;

  llirProgram = record
    globalCount: integer;
    globals: array [1..symbolTableMax] of llirOperand;
    procedureCount: integer;
    procedures: array [1..maxLlirProcedures] of llirProcedure;
    basicBlockCount: integer;
    instructionCount: integer;
    temporaryCount: integer;
    labelCount: integer;
    overflow: boolean
  end;

procedure initializeLlir;
function llirOverflowed: boolean;
procedure getLlirProgram(var targetProgram: llirProgram);

function makeLlirNoneOperand: llirOperand;
function makeLlirConstOperand(const constantValue: integer; valueType: typeValue): llirOperand;
function makeLlirSymbolOperand(symbol: symbolIndex; const name: identifier;
                              valueType: typeValue): llirOperand;
function makeLlirTempOperand(temporaryId: llirTemporaryId; valueType: typeValue): llirOperand;
function makeLlirLabelOperand(labelId: llirLabelId): llirOperand;
function makeLlirProcedureOperand(symbol: symbolIndex; const name: identifier): llirOperand;
function makeLlirIntrinsicOperand(intrinsicKind: llirIntrinsicKind): llirOperand;
function makeLlirAddressTempOperand(temporaryId: llirTemporaryId): llirOperand;

function newLlirTemporary(valueType: typeValue): llirOperand;
function newLlirAddressTemporary: llirOperand;
function newLlirLabel: llirLabelId;

function newLlirInstruction(kind: llirInstructionKind): llirInstruction;
function appendLlirProcedure(const procedureName: identifier;
                            procedureSymbol: symbolIndex): llirProcedureIndex;
procedure setLlirProcedureReturnType(procedureIndex: llirProcedureIndex;
                                    valueType: typeValue;
                                    hasReturnValue: boolean);
procedure addLlirProcedureParameter(procedureIndex: llirProcedureIndex;
                                   parameterSymbol: symbolIndex);
procedure addLlirProcedureLocal(procedureIndex: llirProcedureIndex;
                               localSymbol: symbolIndex);
procedure addLlirGlobal(globalSymbol: symbolIndex);
function appendLlirBasicBlock(blockLabelId: llirLabelId): llirBasicBlockIndex;
function appendLlirInstruction(const instruction: llirInstruction): llirInstructionIndex;
procedure setLlirCallArgument(var instruction: llirInstruction; argumentIndex: integer;
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
                           (operand.size = irSizePointer)
end;

function validateLlirIntrinsicCall(const instruction: llirInstruction): boolean;
var
  argumentIndex, expectedCount: integer;
  kind: llirIntrinsicKind;
begin
  kind := instruction.targetOperand.intrinsicKind;
  validateLlirIntrinsicCall := (kind <> irIntrinsicNone) and
                               (intrinsicSideEffect(kind) = irSideEffectIO);
  if not validateLlirIntrinsicCall then
    exit;

  expectedCount := intrinsicParameterCount(kind);
  validateLlirIntrinsicCall := instruction.callArgumentCount = expectedCount;
  if not validateLlirIntrinsicCall then
    exit;

  if intrinsicHasReturnValue(kind) then
    validateLlirIntrinsicCall := instruction.resultOperand.kind = irOperandTemporary
  else
    validateLlirIntrinsicCall := instruction.resultOperand.kind = irOperandNone;
  if not validateLlirIntrinsicCall then
    exit;

  for argumentIndex := 1 to instruction.callArgumentCount do
  begin
    validateLlirIntrinsicCall := isValueOperandKind(instruction.callArguments[argumentIndex].kind);
    if not validateLlirIntrinsicCall then
      exit;
    if not intrinsicAcceptsValueType(kind,
                                     instruction.callArguments[argumentIndex].valueType) then
    begin
      validateLlirIntrinsicCall := false;
      exit
    end
  end
end;

function instructionUsesStorageOperands(kind: llirInstructionKind): boolean;
begin
  instructionUsesStorageOperands := kind in [irAddrLocal, irAddrParam, irAddrGlobal,
                                             irLoadVar, irStoreVar]
end;

function validateLlirInstruction(const instruction: llirInstruction): boolean;
var
  argumentIndex: integer;
begin
  validateLlirInstruction := true;
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
      validateLlirInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isValueOperandKind(instruction.leftOperand.kind) and
                                isValueOperandKind(instruction.rightOperand.kind);
    irNeg:
      validateLlirInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isValueOperandKind(instruction.leftOperand.kind) and
                                (instruction.rightOperand.kind = irOperandNone);
    irJump:
      validateLlirInstruction := instruction.targetOperand.kind = irOperandLabel;
    irBranchTrue,
    irBranchFalse:
      validateLlirInstruction := isValueOperandKind(instruction.leftOperand.kind) and
                                (instruction.targetOperand.kind = irOperandLabel);
    irCall:
      begin
        validateLlirInstruction := (instruction.targetOperand.kind = irOperandProcedure) and
                                  (instruction.leftOperand.kind = irOperandNone) and
                                  (instruction.rightOperand.kind = irOperandNone) and
                                  ((instruction.resultOperand.kind = irOperandNone) or
                                   (instruction.resultOperand.kind = irOperandTemporary));
        if validateLlirInstruction then
          for argumentIndex := 1 to instruction.callArgumentCount do
          begin
            validateLlirInstruction :=
              isValueOperandKind(instruction.callArguments[argumentIndex].kind);
            if not validateLlirInstruction then
              exit
          end
      end;
    irIntrinsicCall:
      begin
        validateLlirInstruction := instruction.targetOperand.kind = irOperandIntrinsic;
        if validateLlirInstruction then
          validateLlirInstruction := (instruction.leftOperand.kind = irOperandNone) and
                                    (instruction.rightOperand.kind = irOperandNone);
        if validateLlirInstruction then
          validateLlirInstruction := validateLlirIntrinsicCall(instruction)
      end;
    irAddrGlobal:
      validateLlirInstruction := isAddressValueOperand(instruction.resultOperand) and
                                (instruction.leftOperand.kind = irOperandGlobal);
    irLoadConst:
      validateLlirInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                (instruction.leftOperand.kind = irOperandImmediate);
    irCopy:
      validateLlirInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isValueOperandKind(instruction.leftOperand.kind) and
                                (instruction.rightOperand.kind = irOperandNone);
    irAddrLocal:
      validateLlirInstruction := isAddressValueOperand(instruction.resultOperand) and
                                (instruction.leftOperand.kind = irOperandLocal);
    irAddrParam:
      validateLlirInstruction := isAddressValueOperand(instruction.resultOperand) and
                                (instruction.leftOperand.kind = irOperandParameter);
    irFieldAddr:
      validateLlirInstruction := isAddressValueOperand(instruction.resultOperand) and
                                isAddressValueOperand(instruction.leftOperand) and
                                isValueOperandKind(instruction.rightOperand.kind);
    irIndexAddr:
      validateLlirInstruction := isAddressValueOperand(instruction.resultOperand) and
                                isAddressValueOperand(instruction.leftOperand) and
                                isValueOperandKind(instruction.rightOperand.kind) and
                                isValueOperandKind(instruction.targetOperand.kind);
    irLoadAddr:
      validateLlirInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isAddressValueOperand(instruction.leftOperand);
    irStoreAddr:
      validateLlirInstruction := isAddressValueOperand(instruction.resultOperand) and
                                isValueOperandKind(instruction.leftOperand.kind);
    irGoto:
      validateLlirInstruction := instruction.targetOperand.kind = irOperandLabel;
    irLoadVar:
      validateLlirInstruction := (instruction.resultOperand.kind = irOperandTemporary) and
                                isStorageOperandKind(instruction.leftOperand.kind);
    irStoreVar:
      validateLlirInstruction := isStorageOperandKind(instruction.resultOperand.kind) and
                                isValueOperandKind(instruction.leftOperand.kind);
    irReturn,
    irNoOp,
    irLabel:
      validateLlirInstruction := true
  end;

  if validateLlirInstruction then
    if not instructionUsesStorageOperands(instruction.kind) then
      validateLlirInstruction := not isStorageOperandKind(instruction.leftOperand.kind) and
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

function createLlirBasicBlock(blockLabelId: llirLabelId): llirBasicBlockIndex;
begin
  createLlirBasicBlock := 0;
  if currentProcedure = 0 then
  begin
    currentProgram.overflow := true;
    exit
  end;

  if currentProgram.basicBlockCount >= maxLlirBasicBlocks then
  begin
    currentProgram.overflow := true;
    exit
  end;

  with currentProgram.procedures[currentProcedure] do
  begin
    if basicBlockCount >= maxLlirBasicBlocks then
    begin
      currentProgram.overflow := true;
      exit
    end;

    basicBlockCount := basicBlockCount + 1;
    createLlirBasicBlock := basicBlockCount;
    basicBlocks[createLlirBasicBlock].labelId := blockLabelId;
    basicBlocks[createLlirBasicBlock].firstInstruction := 0;
    basicBlocks[createLlirBasicBlock].instructionCount := 0
  end;

  currentProgram.basicBlockCount := currentProgram.basicBlockCount + 1;
  currentBasicBlock := createLlirBasicBlock
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
    irCall: instructionKindToString := 'call';
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
      typeToOperandSize := irSizeBits8;
    typeInteger:
      typeToOperandSize := irSizeBits32
  end
end;

function operandSizeToString(size: llirOperandSize): string;
begin
  case size of
    irSizeBits8: operandSizeToString := 'bits8';
    irSizeBits16: operandSizeToString := 'bits16';
    irSizeBits32: operandSizeToString := 'bits32';
    irSizeBits64: operandSizeToString := 'bits64';
    irSizePointer: operandSizeToString := 'pointer';
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

function makeLlirNoneOperand: llirOperand;
begin
  FillChar(makeLlirNoneOperand, SizeOf(makeLlirNoneOperand), 0);
  makeLlirNoneOperand.kind := irOperandNone;
  makeLlirNoneOperand.valueType := typeInteger;
  makeLlirNoneOperand.size := irSizeNone;
  makeLlirNoneOperand.intrinsicKind := irIntrinsicNone
end;

function makeLlirConstOperand(const constantValue: integer; valueType: typeValue): llirOperand;
begin
  FillChar(makeLlirConstOperand, SizeOf(makeLlirConstOperand), 0);
  makeLlirConstOperand.kind := irOperandImmediate;
  makeLlirConstOperand.valueType := valueType;
  makeLlirConstOperand.size := typeToOperandSize(valueType);
  makeLlirConstOperand.intrinsicKind := irIntrinsicNone;
  makeLlirConstOperand.constantValue := constantValue
end;

function makeLlirSymbolOperand(symbol: symbolIndex; const name: identifier;
                              valueType: typeValue): llirOperand;
begin
  FillChar(makeLlirSymbolOperand, SizeOf(makeLlirSymbolOperand), 0);
  makeLlirSymbolOperand.kind := classifySymbolOperand(symbol);
  makeLlirSymbolOperand.valueType := valueType;
  makeLlirSymbolOperand.size := typeToOperandSize(valueType);
  makeLlirSymbolOperand.symbol := symbol;
  makeLlirSymbolOperand.name := name;
  makeLlirSymbolOperand.intrinsicKind := irIntrinsicNone
end;

function makeLlirTempOperand(temporaryId: llirTemporaryId; valueType: typeValue): llirOperand;
begin
  FillChar(makeLlirTempOperand, SizeOf(makeLlirTempOperand), 0);
  makeLlirTempOperand.kind := irOperandTemporary;
  makeLlirTempOperand.valueType := valueType;
  makeLlirTempOperand.size := typeToOperandSize(valueType);
  makeLlirTempOperand.intrinsicKind := irIntrinsicNone;
  makeLlirTempOperand.temporaryId := temporaryId
end;

function makeLlirAddressTempOperand(temporaryId: llirTemporaryId): llirOperand;
begin
  makeLlirAddressTempOperand := makeLlirTempOperand(temporaryId, typeInteger);
  makeLlirAddressTempOperand.size := irSizePointer
end;

function makeLlirLabelOperand(labelId: llirLabelId): llirOperand;
begin
  FillChar(makeLlirLabelOperand, SizeOf(makeLlirLabelOperand), 0);
  makeLlirLabelOperand.kind := irOperandLabel;
  makeLlirLabelOperand.valueType := typeInteger;
  makeLlirLabelOperand.size := irSizePointer;
  makeLlirLabelOperand.intrinsicKind := irIntrinsicNone;
  makeLlirLabelOperand.labelId := labelId
end;

function makeLlirProcedureOperand(symbol: symbolIndex; const name: identifier): llirOperand;
begin
  FillChar(makeLlirProcedureOperand, SizeOf(makeLlirProcedureOperand), 0);
  makeLlirProcedureOperand.kind := irOperandProcedure;
  makeLlirProcedureOperand.valueType := typeInteger;
  makeLlirProcedureOperand.size := irSizePointer;
  makeLlirProcedureOperand.symbol := symbol;
  makeLlirProcedureOperand.name := name;
  makeLlirProcedureOperand.intrinsicKind := irIntrinsicNone
end;

function makeLlirIntrinsicOperand(intrinsicKind: llirIntrinsicKind): llirOperand;
begin
  FillChar(makeLlirIntrinsicOperand, SizeOf(makeLlirIntrinsicOperand), 0);
  makeLlirIntrinsicOperand.kind := irOperandIntrinsic;
  makeLlirIntrinsicOperand.valueType := typeInteger;
  makeLlirIntrinsicOperand.size := irSizePointer;
  makeLlirIntrinsicOperand.intrinsicKind := intrinsicKind
end;

function newLlirTemporary(valueType: typeValue): llirOperand;
begin
  if currentProgram.temporaryCount >= maxLlirInstructions then
  begin
    currentProgram.overflow := true;
    newLlirTemporary := makeLlirNoneOperand;
    exit
  end;

  currentProgram.temporaryCount := currentProgram.temporaryCount + 1;
  if currentProcedure <> 0 then
    with currentProgram.procedures[currentProcedure] do
    begin
      if temporaryCount >= maxLlirInstructions then
      begin
        currentProgram.overflow := true;
        newLlirTemporary := makeLlirNoneOperand;
        exit
      end;

      temporaryCount := temporaryCount + 1;
      temporaries[temporaryCount].temporaryId := currentProgram.temporaryCount;
      temporaries[temporaryCount].valueType := valueType;
      temporaries[temporaryCount].size := typeToOperandSize(valueType)
    end;
  newLlirTemporary := makeLlirTempOperand(currentProgram.temporaryCount, valueType)
end;

function newLlirAddressTemporary: llirOperand;
begin
  if currentProgram.temporaryCount >= maxLlirInstructions then
  begin
    currentProgram.overflow := true;
    newLlirAddressTemporary := makeLlirNoneOperand;
    exit
  end;

  currentProgram.temporaryCount := currentProgram.temporaryCount + 1;
  if currentProcedure <> 0 then
    with currentProgram.procedures[currentProcedure] do
    begin
      if temporaryCount >= maxLlirInstructions then
      begin
        currentProgram.overflow := true;
        newLlirAddressTemporary := makeLlirNoneOperand;
        exit
      end;

      temporaryCount := temporaryCount + 1;
      temporaries[temporaryCount].temporaryId := currentProgram.temporaryCount;
      temporaries[temporaryCount].valueType := typeInteger;
      temporaries[temporaryCount].size := irSizePointer
    end;
  newLlirAddressTemporary := makeLlirAddressTempOperand(currentProgram.temporaryCount)
end;

function newLlirLabel: llirLabelId;
begin
  if currentProgram.labelCount >= maxLlirInstructions then
  begin
    currentProgram.overflow := true;
    newLlirLabel := 0;
    exit
  end;

  currentProgram.labelCount := currentProgram.labelCount + 1;
  if currentProcedure <> 0 then
    currentProgram.procedures[currentProcedure].labelCount :=
      currentProgram.procedures[currentProcedure].labelCount + 1;
  newLlirLabel := currentProgram.labelCount
end;

function newLlirInstruction(kind: llirInstructionKind): llirInstruction;
var
  argumentIndex: integer;
begin
  FillChar(newLlirInstruction, SizeOf(newLlirInstruction), 0);
  newLlirInstruction.kind := kind;
  newLlirInstruction.resultOperand := makeLlirNoneOperand;
  newLlirInstruction.leftOperand := makeLlirNoneOperand;
  newLlirInstruction.rightOperand := makeLlirNoneOperand;
  newLlirInstruction.targetOperand := makeLlirNoneOperand;
  newLlirInstruction.operatorSymbol := nul;
  newLlirInstruction.callArgumentCount := 0;
  for argumentIndex := 1 to maxLlirOperandsPerCall do
    newLlirInstruction.callArguments[argumentIndex] := makeLlirNoneOperand
end;

function appendLlirProcedure(const procedureName: identifier;
                            procedureSymbol: symbolIndex): llirProcedureIndex;
begin
  appendLlirProcedure := 0;
  if currentProgram.procedureCount >= maxLlirProcedures then
  begin
    currentProgram.overflow := true;
    exit
  end;

  currentProgram.procedureCount := currentProgram.procedureCount + 1;
  appendLlirProcedure := currentProgram.procedureCount;
  currentProcedure := appendLlirProcedure;
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

procedure setLlirProcedureReturnType(procedureIndex: llirProcedureIndex;
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

procedure addLlirProcedureParameter(procedureIndex: llirProcedureIndex;
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
    parameters[parameterCount] := makeLlirSymbolOperand(
      parameterSymbol,
      getDeclarationIdentifier(parameterSymbol),
      getDeclarationType(parameterSymbol))
  end
end;

procedure addLlirProcedureLocal(procedureIndex: llirProcedureIndex;
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
    locals[localCount] := makeLlirSymbolOperand(
      localSymbol,
      getDeclarationIdentifier(localSymbol),
      getDeclarationType(localSymbol))
  end
end;

procedure addLlirGlobal(globalSymbol: symbolIndex);
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
  currentProgram.globals[currentProgram.globalCount] := makeLlirSymbolOperand(
    globalSymbol,
    getDeclarationIdentifier(globalSymbol),
    getDeclarationType(globalSymbol))
end;

function appendLlirBasicBlock(blockLabelId: llirLabelId): llirBasicBlockIndex;
begin
  if currentProcedure = 0 then
  begin
    currentProgram.overflow := true;
    appendLlirBasicBlock := 0;
    exit
  end;

  if currentProcedureHasOpenBlock then
  begin
      if currentBlockInstructionCount = 0 then
      begin
        bindLabelToCurrentBlock(blockLabelId);
      appendLlirBasicBlock := currentBasicBlock;
      exit
    end;
    currentBasicBlock := 0
  end;

  appendLlirBasicBlock := createLlirBasicBlock(0);
  bindLabelToCurrentBlock(blockLabelId)
end;

function appendLlirInstruction(const instruction: llirInstruction): llirInstructionIndex;
begin
  appendLlirInstruction := 0;
  if currentProcedure = 0 then
  begin
    currentProgram.overflow := true;
    exit
  end;

  if currentProgram.instructionCount >= maxLlirInstructions then
  begin
    currentProgram.overflow := true;
    exit
  end;

  if not currentProcedureHasOpenBlock then
    if createLlirBasicBlock(0) = 0 then
      exit;

  if not validateLlirInstruction(instruction) then
  begin
    currentProgram.overflow := true;
    exit
  end;

  with currentProgram.procedures[currentProcedure] do
  begin
    if instructionCount >= maxLlirInstructions then
    begin
      currentProgram.overflow := true;
      exit
    end;

    instructionCount := instructionCount + 1;
    appendLlirInstruction := instructionCount;
    instructions[appendLlirInstruction] := instruction
  end;

  currentProgram.instructionCount := currentProgram.instructionCount + 1;

  if currentBasicBlock <> 0 then
    with currentProgram.procedures[currentProcedure].basicBlocks[currentBasicBlock] do
    begin
      if firstInstruction = 0 then
        firstInstruction := appendLlirInstruction;
      instructionCount := instructionCount + 1
    end;

  if instructionEndsBasicBlock(instruction.kind) then
    currentBasicBlock := 0
end;

procedure setLlirCallArgument(var instruction: llirInstruction; argumentIndex: integer;
                             const argument: llirOperand);
begin
  if (argumentIndex < 1) or (argumentIndex > maxLlirOperandsPerCall) then
  begin
    currentProgram.overflow := true;
    exit
  end;

  instruction.callArguments[argumentIndex] := argument;
  if instruction.callArgumentCount < argumentIndex then
    instruction.callArgumentCount := argumentIndex
end;

procedure dumpLlirInstruction(var outputFile: Text; instructionIndex: integer;
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
                operandToString(makeLlirTempOperand(temporaries[itemIndex].temporaryId,
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
              dumpLlirInstruction(outputFile, instructionIndex,
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
