{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-06-05

  Three-address-code intermediate representation definitions and low-level
  state management. This unit owns the current TAC image, issues temporary and
  label identifiers, appends procedures, basic blocks, and instructions, and can
  dump the generated IR for inspection. It deliberately stays data-only: flat
  records, fixed arrays, and counts. It does not know about AST nodes, parsing,
  register allocation, stack slots, or target-code emission. }
unit tacir;

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
  tacInstructionIndex = 0..maxTacInstructions;
  tacBasicBlockIndex = 0..maxTacBasicBlocks;
  tacProcedureIndex = 0..maxTacProcedures;
  tacTemporaryId = 0..maxTacInstructions;
  tacLabelId = 0..maxTacInstructions;

  tacInstructionKind = (
    irNoOp,
    irLoadConst,
    irCopy,
    irUnaryOp,
    irBinaryOp,
    irGoto,
    irGotoIfZero,
    irLabel,
    irLoadVar,
    irStoreVar,
    irCallProc,
    irBuiltinRead,
    irBuiltinWrite,
    irReturn
  );

  { TAC operands describe values only. Labels stay on branch/label
    instructions so backend layout decisions remain separate. }
  tacOperandKind = (
    irOperandNone,
    irOperandConst,
    irOperandSymbol,
    irOperandTemp
  );

  tacOperand = record
    kind: tacOperandKind;
    valueType: typeValue;
    case tacOperandKind of
      irOperandNone:
        ();
      irOperandConst:
        (constantValue: integer);
      irOperandSymbol:
        (symbol: symbolIndex; name: identifier);
      irOperandTemp:
        (temporaryId: tacTemporaryId)
  end;

  tacInstruction = record
    kind: tacInstructionKind;
    resultOperand: tacOperand;
    leftOperand: tacOperand;
    rightOperand: tacOperand;
    operatorSymbol: symbol;
    targetLabel: tacLabelId;
    procedureSymbol: symbolIndex;
    procedureName: identifier;
    builtinProcedureKind: builtinProcedure;
    callArgumentCount: integer;
    callArguments: array [1..maxTacOperandsPerCall] of tacOperand
  end;

  tacBasicBlock = record
    labelId: tacLabelId;
    firstInstruction: tacInstructionIndex;
    instructionCount: integer
  end;

  tacTemporaryInfo = record
    temporaryId: tacTemporaryId;
    valueType: typeValue
  end;

  tacFrameInfo = record
    parameterCount: integer;
    localCount: integer;
    temporaryCount: integer
  end;

  tacProcedure = record
    name: identifier;
    symbol: symbolIndex;
    hasReturnValue: boolean;
    returnType: typeValue;
    parameterCount: integer;
    parameters: array [1..maxProcedureParameters] of tacOperand;
    localCount: integer;
    locals: array [1..symbolTableMax] of tacOperand;
    temporaries: array [1..maxTacInstructions] of tacTemporaryInfo;
    frameInfo: tacFrameInfo;
    basicBlockCount: integer;
    basicBlocks: array [1..maxTacBasicBlocks] of tacBasicBlock;
    labelBlockIndex: array [1..maxTacInstructions] of tacBasicBlockIndex;
    instructionCount: integer;
    instructions: array [1..maxTacInstructions] of tacInstruction;
    labelCount: integer
  end;

  tacProgram = record
    procedureCount: integer;
    procedures: array [1..maxTacProcedures] of tacProcedure;
    basicBlockCount: integer;
    instructionCount: integer;
    temporaryCount: integer;
    labelCount: integer;
    overflow: boolean
  end;

procedure initializeTacIr;
function tacIrOverflowed: boolean;
procedure getTacProgram(var targetProgram: tacProgram);

function makeTacNoneOperand: tacOperand;
function makeTacConstOperand(const constantValue: integer; valueType: typeValue): tacOperand;
function makeTacSymbolOperand(symbol: symbolIndex; const name: identifier;
                              valueType: typeValue): tacOperand;
function makeTacTempOperand(temporaryId: tacTemporaryId; valueType: typeValue): tacOperand;

function newTacTemporary(valueType: typeValue): tacOperand;
function newTacLabel: tacLabelId;

function newTacInstruction(kind: tacInstructionKind): tacInstruction;
function appendTacProcedure(const procedureName: identifier;
                            procedureSymbol: symbolIndex): tacProcedureIndex;
procedure setTacProcedureReturnType(procedureIndex: tacProcedureIndex;
                                    valueType: typeValue;
                                    hasReturnValue: boolean);
procedure addTacProcedureParameter(procedureIndex: tacProcedureIndex;
                                   parameterSymbol: symbolIndex);
procedure addTacProcedureLocal(procedureIndex: tacProcedureIndex;
                               localSymbol: symbolIndex);
function appendTacBasicBlock(blockLabelId: tacLabelId): tacBasicBlockIndex;
function appendTacInstruction(const instruction: tacInstruction): tacInstructionIndex;
procedure setTacCallArgument(var instruction: tacInstruction; argumentIndex: integer;
                             const argument: tacOperand);
procedure dumpTacIr(const outputFileName: string);

implementation

uses
  SysUtils;

var
  currentProgram: tacProgram;
  currentProcedure: tacProcedureIndex;
  currentBasicBlock: tacBasicBlockIndex;

function instructionEndsBasicBlock(kind: tacInstructionKind): boolean;
begin
  instructionEndsBasicBlock := kind in [irGoto, irGotoIfZero, irReturn]
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

procedure bindLabelToCurrentBlock(labelId: tacLabelId);
begin
  if (labelId = 0) or not currentProcedureHasOpenBlock then
    exit;

  currentProgram.procedures[currentProcedure].labelBlockIndex[labelId] := currentBasicBlock;
  if currentProgram.procedures[currentProcedure].basicBlocks[currentBasicBlock].labelId = 0 then
    currentProgram.procedures[currentProcedure].basicBlocks[currentBasicBlock].labelId := labelId
end;

function createTacBasicBlock(blockLabelId: tacLabelId): tacBasicBlockIndex;
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

function instructionKindToString(kind: tacInstructionKind): string;
begin
  case kind of
    irNoOp: instructionKindToString := 'noop';
    irLoadConst: instructionKindToString := 'load_const';
    irCopy: instructionKindToString := 'copy';
    irUnaryOp: instructionKindToString := 'unary';
    irBinaryOp: instructionKindToString := 'binary';
    irGoto: instructionKindToString := 'goto';
    irGotoIfZero: instructionKindToString := 'goto_if_zero';
    irLabel: instructionKindToString := 'label';
    irLoadVar: instructionKindToString := 'load_var';
    irStoreVar: instructionKindToString := 'store_var';
    irCallProc: instructionKindToString := 'call_proc';
    irBuiltinRead: instructionKindToString := 'builtin_read';
    irBuiltinWrite: instructionKindToString := 'builtin_write';
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

function builtinProcedureToString(procKind: builtinProcedure): string;
begin
  case procKind of
    builtinNone: builtinProcedureToString := 'none';
    builtinRead: builtinProcedureToString := 'read';
    builtinReadLn: builtinProcedureToString := 'readln';
    builtinWrite: builtinProcedureToString := 'write';
    builtinWriteLn: builtinProcedureToString := 'writeln'
  end
end;

function operandToString(const operand: tacOperand): string;
begin
  case operand.kind of
    irOperandNone:
      operandToString := '_';
    irOperandConst:
      operandToString := '#' + IntToStr(operand.constantValue) + ':' +
                         typeToString(operand.valueType);
    irOperandSymbol:
      operandToString := identifierToString(operand.name) + ':' +
                         typeToString(operand.valueType);
    irOperandTemp:
      operandToString := 't' + IntToStr(operand.temporaryId) + ':' +
                         typeToString(operand.valueType)
  end
end;

procedure initializeTacIr;
begin
  FillChar(currentProgram, SizeOf(currentProgram), 0);
  currentProcedure := 0;
  currentBasicBlock := 0
end;

function tacIrOverflowed: boolean;
begin
  tacIrOverflowed := currentProgram.overflow
end;

procedure getTacProgram(var targetProgram: tacProgram);
begin
  targetProgram := currentProgram
end;

function makeTacNoneOperand: tacOperand;
begin
  FillChar(makeTacNoneOperand, SizeOf(makeTacNoneOperand), 0);
  makeTacNoneOperand.kind := irOperandNone;
  makeTacNoneOperand.valueType := typeInteger
end;

function makeTacConstOperand(const constantValue: integer; valueType: typeValue): tacOperand;
begin
  FillChar(makeTacConstOperand, SizeOf(makeTacConstOperand), 0);
  makeTacConstOperand.kind := irOperandConst;
  makeTacConstOperand.valueType := valueType;
  makeTacConstOperand.constantValue := constantValue
end;

function makeTacSymbolOperand(symbol: symbolIndex; const name: identifier;
                              valueType: typeValue): tacOperand;
begin
  FillChar(makeTacSymbolOperand, SizeOf(makeTacSymbolOperand), 0);
  makeTacSymbolOperand.kind := irOperandSymbol;
  makeTacSymbolOperand.valueType := valueType;
  makeTacSymbolOperand.symbol := symbol;
  makeTacSymbolOperand.name := name
end;

function makeTacTempOperand(temporaryId: tacTemporaryId; valueType: typeValue): tacOperand;
begin
  FillChar(makeTacTempOperand, SizeOf(makeTacTempOperand), 0);
  makeTacTempOperand.kind := irOperandTemp;
  makeTacTempOperand.valueType := valueType;
  makeTacTempOperand.temporaryId := temporaryId
end;

function newTacTemporary(valueType: typeValue): tacOperand;
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
      if frameInfo.temporaryCount >= maxTacInstructions then
      begin
        currentProgram.overflow := true;
        newTacTemporary := makeTacNoneOperand;
        exit
      end;

      frameInfo.temporaryCount := frameInfo.temporaryCount + 1;
      temporaries[frameInfo.temporaryCount].temporaryId := currentProgram.temporaryCount;
      temporaries[frameInfo.temporaryCount].valueType := valueType
    end;
  newTacTemporary := makeTacTempOperand(currentProgram.temporaryCount, valueType)
end;

function newTacLabel: tacLabelId;
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

function newTacInstruction(kind: tacInstructionKind): tacInstruction;
var
  argumentIndex: integer;
begin
  FillChar(newTacInstruction, SizeOf(newTacInstruction), 0);
  newTacInstruction.kind := kind;
  newTacInstruction.resultOperand := makeTacNoneOperand;
  newTacInstruction.leftOperand := makeTacNoneOperand;
  newTacInstruction.rightOperand := makeTacNoneOperand;
  newTacInstruction.operatorSymbol := nul;
  newTacInstruction.targetLabel := 0;
  newTacInstruction.procedureSymbol := 0;
  FillChar(newTacInstruction.procedureName, SizeOf(newTacInstruction.procedureName), ' ');
  newTacInstruction.builtinProcedureKind := builtinNone;
  newTacInstruction.callArgumentCount := 0;
  for argumentIndex := 1 to maxTacOperandsPerCall do
    newTacInstruction.callArguments[argumentIndex] := makeTacNoneOperand
end;

function appendTacProcedure(const procedureName: identifier;
                            procedureSymbol: symbolIndex): tacProcedureIndex;
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
    basicBlockCount := 0;
    instructionCount := 0;
    labelCount := 0;
    frameInfo.parameterCount := 0;
    frameInfo.localCount := 0;
    frameInfo.temporaryCount := 0
  end
end;

procedure setTacProcedureReturnType(procedureIndex: tacProcedureIndex;
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

procedure addTacProcedureParameter(procedureIndex: tacProcedureIndex;
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
      getDeclarationType(parameterSymbol));
    frameInfo.parameterCount := parameterCount
  end
end;

procedure addTacProcedureLocal(procedureIndex: tacProcedureIndex;
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
      getDeclarationType(localSymbol));
    frameInfo.localCount := localCount
  end
end;

function appendTacBasicBlock(blockLabelId: tacLabelId): tacBasicBlockIndex;
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

function appendTacInstruction(const instruction: tacInstruction): tacInstructionIndex;
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

procedure setTacCallArgument(var instruction: tacInstruction; argumentIndex: integer;
                             const argument: tacOperand);
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
                             const instruction: tacInstruction);
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
  if instruction.operatorSymbol <> nul then
    write(outputFile, ' op=', operatorToString(instruction.operatorSymbol));
  if instruction.targetLabel <> 0 then
    write(outputFile, ' label=L', instruction.targetLabel);
  if instruction.procedureSymbol <> 0 then
    write(outputFile, ' proc=', identifierToString(instruction.procedureName));
  if instruction.builtinProcedureKind <> builtinNone then
    write(outputFile, ' builtin=', builtinProcedureToString(instruction.builtinProcedureKind));
  for argumentIndex := 1 to instruction.callArgumentCount do
    write(outputFile, ' arg', argumentIndex, '=',
          operandToString(instruction.callArguments[argumentIndex]));
  writeln(outputFile)
end;

procedure dumpTacIr(const outputFileName: string);
var
  outputFile: Text;
  procedureIndex, itemIndex, instructionIndex, blockLastInstruction, labelIndex: integer;
begin
  Assign(outputFile, outputFileName);
  Rewrite(outputFile);
  writeln(outputFile, 'tac program');
  writeln(outputFile, 'procedures ', currentProgram.procedureCount);
  for procedureIndex := 1 to currentProgram.procedureCount do
    with currentProgram.procedures[procedureIndex] do
    begin
      writeln(outputFile, 'proc ', procedureIndex, ' ',
              identifierToString(name),
              ' return=', procedureReturnTypeToString(hasReturnValue, returnType),
              ' params=', parameterCount,
              ' locals=', localCount,
              ' temps=', frameInfo.temporaryCount,
              ' blocks=', basicBlockCount,
              ' labels=', labelCount,
              ' instructions=', instructionCount);
      for itemIndex := 1 to parameterCount do
        writeln(outputFile, '  param ', itemIndex, ' ',
                operandToString(parameters[itemIndex]));
      for itemIndex := 1 to localCount do
        writeln(outputFile, '  local ', itemIndex, ' ',
                operandToString(locals[itemIndex]));
      writeln(outputFile, '  frame params=', frameInfo.parameterCount,
              ' locals=', frameInfo.localCount,
              ' temps=', frameInfo.temporaryCount);
      for itemIndex := 1 to basicBlockCount do
        with basicBlocks[itemIndex] do
        begin
          if labelId <> 0 then
          begin
            write(outputFile, '  block ', itemIndex,
                  ' label=L', labelId);
            for labelIndex := 1 to labelCount do
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
      for labelIndex := 1 to labelCount do
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
  initializeTacIr;

end.
