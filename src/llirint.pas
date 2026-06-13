{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-06-09

  LLIR interpreter. This standalone program reads the textual .llir image
  dumped by llir, reconstructs the target-neutral LLIR summaries and
  procedure-scoped units, and executes them directly. It stays intentionally
  close to the staged LLIR model: variables remain symbolic, temporaries are
  numeric slots, labels are symbolic jump targets, and procedure calls use a
  small return-address stack. }
program llirint;

{$mode objfpc}
{$H+}

uses
  SysUtils, Classes, diagnostics, tokens;

const
  maxTacInstructions = 500;
  maxTacProcedures = 64;
  maxTacLabels = 500;
  maxTacTemporaries = 500;
  maxTacVariables = 200;
  maxTacMemoryCells = 1000;
  maxCallDepth = 64;

type
  llirRuntimeInstructionKind = (
    rtNoOp,
    rtAdd,
    rtSub,
    rtMul,
    rtDiv,
    rtMod,
    rtNeg,
    rtCmpEq,
    rtCmpNe,
    rtCmpLt,
    rtCmpLe,
    rtCmpGt,
    rtCmpGe,
    rtJump,
    rtBranchTrue,
    rtBranchFalse,
    rtArg,
    rtCall,
    rtResult,
    rtIntrinsicCall,
    rtAddrGlobal,
    rtLoadConst,
    rtCopy,
    rtAddrLocal,
    rtAddrParam,
    rtFieldAddr,
    rtIndexAddr,
    rtLoadAddr,
    rtStoreAddr,
    rtGoto,
    rtLabel,
    rtLoadVar,
    rtStoreVar,
    rtReturn
  );

  llirRuntimeOperandKind = (
    rtOperandNone,
    rtOperandImmediate,
    rtOperandLocal,
    rtOperandParameter,
    rtOperandTemporary,
    rtOperandGlobal,
    rtOperandLabel,
    rtOperandProcedure,
    rtOperandIntrinsic
  );

  llirRuntimeOperand = record
    kind: llirRuntimeOperandKind;
    valueType: string;
    name: string;
    value: integer;
    temporaryId: integer
  end;

  llirRuntimeInstruction = record
    kind: llirRuntimeInstructionKind;
    resultOperand: llirRuntimeOperand;
    leftOperand: llirRuntimeOperand;
    rightOperand: llirRuntimeOperand;
    targetOperand: llirRuntimeOperand;
    positionIndex: integer;
    operatorText: string;
    callArgumentCount: integer;
    callArguments: array [1..maxProcedureParameters] of llirRuntimeOperand
  end;

  llirRuntimeProcedure = record
    name: string;
    parameterCount: integer;
    parameters: array [1..maxProcedureParameters] of llirRuntimeOperand;
    instructionCount: integer;
    instructions: array [1..maxTacInstructions] of llirRuntimeInstruction;
    labelTargets: array [1..maxTacLabels] of integer
  end;

  llirRuntimeVariable = record
    name: string;
    address: integer;
    value: integer
  end;

  llirRuntimeMemoryCell = record
    address: integer;
    value: integer
  end;

  llirReturnAddress = record
    procedureIndex: integer;
    instructionIndex: integer;
    resultOperand: llirRuntimeOperand;
    calleeProcedureIndex: integer
  end;

var
  llirFile: Text;
  llirFileName: string;
  verbosity: diagnosticVerbosity;
  procedures: array [1..maxTacProcedures] of llirRuntimeProcedure;
  procedureCount: integer;
  variables: array [1..maxTacVariables] of llirRuntimeVariable;
  variableCount: integer;
  nextVariableAddress: integer;
  memoryCells: array [1..maxTacMemoryCells] of llirRuntimeMemoryCell;
  memoryCellCount: integer;
  temporaries: array [1..maxTacTemporaries] of integer;
  returnStack: array [1..maxCallDepth] of llirReturnAddress;
  returnStackTop: integer;
function makeNoneOperand: llirRuntimeOperand;
begin
  makeNoneOperand.kind := rtOperandNone;
  makeNoneOperand.valueType := '';
  makeNoneOperand.name := '';
  makeNoneOperand.value := 0;
  makeNoneOperand.temporaryId := 0
end;

function startsWith(const text, prefix: string): boolean;
begin
  startsWith := Copy(text, 1, Length(prefix)) = prefix
end;

function tokenValue(const token, key: string): string;
begin
  tokenValue := '';
  if startsWith(token, key + '=') then
    tokenValue := Copy(token, Length(key) + 2, Length(token))
end;

procedure splitLine(const line: string; tokens: TStrings);
begin
  tokens.Clear;
  ExtractStrings([' '], [], PChar(line), tokens)
end;

function parseIntegerOrHalt(const text, errorMessage: string): integer;
var
  conversionStatus: integer;
begin
  Val(text, parseIntegerOrHalt, conversionStatus);
  if conversionStatus <> 0 then
  begin
    reportRuntimeError(errorMessage);
    halt(1)
  end
end;

function parseLabelId(const labelText: string): integer;
begin
  if (labelText <> '') and (labelText[1] = 'L') then
    parseLabelId := parseIntegerOrHalt(Copy(labelText, 2, Length(labelText)),
                                       'Invalid TAC label identifier.')
  else
    parseLabelId := 0
end;

function parseOperand(const operandText: string): llirRuntimeOperand;
var
  separatorIndex, slashIndex, openIndex, closeIndex: integer;
  atomText, typeText, payloadText: string;
begin
  parseOperand := makeNoneOperand;
  if (operandText = '') or (operandText = '_') then
    exit;

  separatorIndex := Pos(':', operandText);
  if separatorIndex > 0 then
  begin
    atomText := Copy(operandText, 1, separatorIndex - 1);
    typeText := Copy(operandText, separatorIndex + 1, Length(operandText))
  end
  else
  begin
    atomText := operandText;
    typeText := ''
  end;

  slashIndex := Pos('/', typeText);
  if slashIndex > 0 then
    typeText := Copy(typeText, 1, slashIndex - 1);
  parseOperand.valueType := typeText;

  openIndex := Pos('[', atomText);
  closeIndex := Pos(']', atomText);
  if (openIndex = 0) or (closeIndex = 0) then
  begin
    openIndex := Pos('(', atomText);
    closeIndex := Pos(')', atomText)
  end;
  if (openIndex > 0) and (closeIndex > openIndex) then
    payloadText := Copy(atomText, openIndex + 1, closeIndex - openIndex - 1)
  else
    payloadText := '';

  if startsWith(atomText, 'imm(') then
  begin
    parseOperand.kind := rtOperandImmediate;
    parseOperand.value := parseIntegerOrHalt(payloadText,
                                             'Invalid TAC constant operand.')
  end
  else if startsWith(atomText, 'temp[') and (Length(payloadText) > 1) and
          (payloadText[1] = 't') then
  begin
    parseOperand.kind := rtOperandTemporary;
    parseOperand.temporaryId := parseIntegerOrHalt(Copy(payloadText, 2, Length(payloadText)),
                                                   'Invalid TAC temporary operand.')
  end
  else if startsWith(atomText, 'local[') then
  begin
    parseOperand.kind := rtOperandLocal;
    parseOperand.name := payloadText
  end
  else if startsWith(atomText, 'param[') then
  begin
    parseOperand.kind := rtOperandParameter;
    parseOperand.name := payloadText
  end
  else if startsWith(atomText, 'global[') then
  begin
    parseOperand.kind := rtOperandGlobal;
    parseOperand.name := payloadText
  end
  else if startsWith(atomText, 'label[') then
  begin
    parseOperand.kind := rtOperandLabel;
    parseOperand.value := parseLabelId(payloadText)
  end
  else if startsWith(atomText, 'proc[') then
  begin
    parseOperand.kind := rtOperandProcedure;
    parseOperand.name := payloadText
  end
  else if startsWith(atomText, 'intrinsic[') then
  begin
    parseOperand.kind := rtOperandIntrinsic;
    parseOperand.name := payloadText
  end
  else
  begin
    parseOperand.kind := rtOperandGlobal;
    parseOperand.name := atomText
  end
end;

function instructionKindFromText(const kindText: string): llirRuntimeInstructionKind;
begin
  if kindText = 'add' then
    instructionKindFromText := rtAdd
  else if kindText = 'sub' then
    instructionKindFromText := rtSub
  else if kindText = 'mul' then
    instructionKindFromText := rtMul
  else if kindText = 'div' then
    instructionKindFromText := rtDiv
  else if kindText = 'mod' then
    instructionKindFromText := rtMod
  else if kindText = 'neg' then
    instructionKindFromText := rtNeg
  else if kindText = 'cmp_eq' then
    instructionKindFromText := rtCmpEq
  else if kindText = 'cmp_ne' then
    instructionKindFromText := rtCmpNe
  else if kindText = 'cmp_lt' then
    instructionKindFromText := rtCmpLt
  else if kindText = 'cmp_le' then
    instructionKindFromText := rtCmpLe
  else if kindText = 'cmp_gt' then
    instructionKindFromText := rtCmpGt
  else if kindText = 'cmp_ge' then
    instructionKindFromText := rtCmpGe
  else if kindText = 'jump' then
    instructionKindFromText := rtJump
  else if kindText = 'brtrue' then
    instructionKindFromText := rtBranchTrue
  else if kindText = 'brfalse' then
    instructionKindFromText := rtBranchFalse
  else if kindText = 'arg' then
    instructionKindFromText := rtArg
  else if kindText = 'call' then
    instructionKindFromText := rtCall
  else if kindText = 'result' then
    instructionKindFromText := rtResult
  else if kindText = 'intrinsic_call' then
    instructionKindFromText := rtIntrinsicCall
  else if kindText = 'addr_global' then
    instructionKindFromText := rtAddrGlobal
  else if kindText = 'copy' then
    instructionKindFromText := rtCopy
  else if kindText = 'addr_local' then
    instructionKindFromText := rtAddrLocal
  else if kindText = 'addr_param' then
    instructionKindFromText := rtAddrParam
  else if kindText = 'field_addr' then
    instructionKindFromText := rtFieldAddr
  else if kindText = 'index_addr' then
    instructionKindFromText := rtIndexAddr
  else if kindText = 'load_addr' then
    instructionKindFromText := rtLoadAddr
  else if kindText = 'store_addr' then
    instructionKindFromText := rtStoreAddr
  else if kindText = 'load' then
    instructionKindFromText := rtLoadVar
  else if kindText = 'store' then
    instructionKindFromText := rtStoreVar
  else if kindText = 'return' then
    instructionKindFromText := rtReturn
  else
    instructionKindFromText := rtNoOp
end;

procedure readGlobalSummary(const tokens: TStrings); forward;

function beginProcedure(const tokens: TStrings): integer;
begin
  if procedureCount >= maxTacProcedures then
  begin
    reportRuntimeError('Too many TAC procedures.');
    halt(1)
  end;
  if tokens.Count < 3 then
  begin
    reportRuntimeError('Invalid TAC procedure header.');
    halt(1)
  end;

  procedureCount := procedureCount + 1;
  procedures[procedureCount].name := tokens[2];
  procedures[procedureCount].parameterCount := 0;
  procedures[procedureCount].instructionCount := 0;
  FillChar(procedures[procedureCount].labelTargets,
           SizeOf(procedures[procedureCount].labelTargets), 0);
  beginProcedure := procedureCount
end;

procedure readProcedureParameter(procedureIndex: integer; const tokens: TStrings);
begin
  if (procedureIndex < 1) or (procedureIndex > procedureCount) then
    exit;
  if tokens.Count < 3 then
    exit;
  if procedures[procedureIndex].parameterCount >= maxProcedureParameters then
  begin
    reportRuntimeError('Too many TAC procedure parameters.');
    halt(1)
  end;

  procedures[procedureIndex].parameterCount :=
    procedures[procedureIndex].parameterCount + 1;
  procedures[procedureIndex].parameters[procedures[procedureIndex].parameterCount] :=
    parseOperand(tokens[2])
end;

procedure readLabelMap(procedureIndex: integer; const tokens: TStrings);
var
  tokenIndex, labelId, firstInstruction: integer;
  valueText: string;
begin
  if (procedureIndex < 1) or (procedureIndex > procedureCount) then
    exit;
  if tokens.Count < 3 then
    exit;

  labelId := 0;
  firstInstruction := 0;
  if (Length(tokens[1]) > 1) and (tokens[1][1] = 'L') then
    labelId := parseLabelId(tokens[1]);
  for tokenIndex := 2 to tokens.Count - 1 do
  begin
    valueText := tokenValue(tokens[tokenIndex], 'first');
    if valueText <> '' then
      firstInstruction := parseIntegerOrHalt(valueText,
                                             'Invalid TAC label map first instruction.')
  end;

  if (labelId >= 1) and (labelId <= maxTacLabels) then
    procedures[procedureIndex].labelTargets[labelId] := firstInstruction
end;

procedure readBlockSummary(procedureIndex: integer; const tokens: TStrings);
var
  tokenIndex, firstInstruction: integer;
  valueText: string;
  blockLabels: array [1..maxTacLabels] of integer;
  blockLabelCount: integer;
begin
  if (procedureIndex < 1) or (procedureIndex > procedureCount) then
  begin
    reportRuntimeError('TAC block found outside procedure.');
    halt(1)
  end;
  if tokens.Count < 3 then
    exit;

  firstInstruction := 0;
  blockLabelCount := 0;
  for tokenIndex := 2 to tokens.Count - 1 do
  begin
    valueText := tokenValue(tokens[tokenIndex], 'label');
    if valueText <> '' then
    begin
      blockLabelCount := blockLabelCount + 1;
      blockLabels[blockLabelCount] := parseLabelId(valueText)
    end;

    valueText := tokenValue(tokens[tokenIndex], 'alias');
    if valueText <> '' then
    begin
      blockLabelCount := blockLabelCount + 1;
      blockLabels[blockLabelCount] := parseLabelId(valueText)
    end;

    valueText := tokenValue(tokens[tokenIndex], 'first');
    if valueText <> '' then
      firstInstruction := parseIntegerOrHalt(valueText,
                                             'Invalid TAC block first instruction.')
  end;

  for tokenIndex := 1 to blockLabelCount do
    if (blockLabels[tokenIndex] >= 1) and (blockLabels[tokenIndex] <= maxTacLabels) then
      procedures[procedureIndex].labelTargets[blockLabels[tokenIndex]] := firstInstruction
end;

procedure parseInstructionLine(procedureIndex: integer; const tokens: TStrings);
var
  tokenIndex, instructionIndex, argumentIndex: integer;
  valueText: string;
begin
  if tokens.Count < 2 then
    exit;
  if (procedureIndex < 1) or (procedureIndex > procedureCount) then
  begin
    reportRuntimeError('TAC instruction found outside procedure.');
    halt(1)
  end;

  instructionIndex := parseIntegerOrHalt(tokens[0], 'Invalid TAC instruction index.');
  if (instructionIndex < 1) or (instructionIndex > maxTacInstructions) then
  begin
    reportRuntimeError('TAC instruction index out of range.');
    halt(1)
  end;

  if instructionIndex > procedures[procedureIndex].instructionCount then
    procedures[procedureIndex].instructionCount := instructionIndex;

  procedures[procedureIndex].instructions[instructionIndex].kind :=
    instructionKindFromText(tokens[1]);
  procedures[procedureIndex].instructions[instructionIndex].resultOperand := makeNoneOperand;
  procedures[procedureIndex].instructions[instructionIndex].leftOperand := makeNoneOperand;
  procedures[procedureIndex].instructions[instructionIndex].rightOperand := makeNoneOperand;
  procedures[procedureIndex].instructions[instructionIndex].targetOperand := makeNoneOperand;
  procedures[procedureIndex].instructions[instructionIndex].positionIndex := 0;
  procedures[procedureIndex].instructions[instructionIndex].operatorText := '';
  procedures[procedureIndex].instructions[instructionIndex].callArgumentCount := 0;
  for argumentIndex := 1 to maxProcedureParameters do
    procedures[procedureIndex].instructions[instructionIndex].callArguments[argumentIndex] :=
      makeNoneOperand;

  for tokenIndex := 2 to tokens.Count - 1 do
  begin
    valueText := tokenValue(tokens[tokenIndex], 'result');
    if valueText <> '' then
      procedures[procedureIndex].instructions[instructionIndex].resultOperand :=
        parseOperand(valueText);

    valueText := tokenValue(tokens[tokenIndex], 'left');
    if valueText <> '' then
      procedures[procedureIndex].instructions[instructionIndex].leftOperand :=
        parseOperand(valueText);

    valueText := tokenValue(tokens[tokenIndex], 'right');
    if valueText <> '' then
      procedures[procedureIndex].instructions[instructionIndex].rightOperand :=
        parseOperand(valueText);

    valueText := tokenValue(tokens[tokenIndex], 'op');
    if valueText <> '' then
      procedures[procedureIndex].instructions[instructionIndex].operatorText := valueText;

    valueText := tokenValue(tokens[tokenIndex], 'target');
    if valueText <> '' then
      procedures[procedureIndex].instructions[instructionIndex].targetOperand :=
        parseOperand(valueText);

    valueText := tokenValue(tokens[tokenIndex], 'index');
    if valueText <> '' then
      procedures[procedureIndex].instructions[instructionIndex].positionIndex :=
        parseIntegerOrHalt(valueText, 'Invalid TAC argument index.');

    for argumentIndex := 1 to maxProcedureParameters do
    begin
      valueText := tokenValue(tokens[tokenIndex], 'arg' + IntToStr(argumentIndex));
      if valueText <> '' then
      begin
        procedures[procedureIndex].instructions[instructionIndex].callArguments[argumentIndex] :=
          parseOperand(valueText);
        if procedures[procedureIndex].instructions[instructionIndex].callArgumentCount <
           argumentIndex then
          procedures[procedureIndex].instructions[instructionIndex].callArgumentCount :=
            argumentIndex
      end
    end
  end;

end;

procedure loadTacFile;
var
  llirLine: string;
  tokens: TStringList;
  currentProcedureIndex: integer;
  instructionTotal: integer;
begin
  currentProcedureIndex := 0;
  instructionTotal := 0;
  tokens := TStringList.Create;
  try
    while not EOF(llirFile) do
    begin
      ReadLn(llirFile, llirLine);
      splitLine(Trim(llirLine), tokens);
      if tokens.Count = 0 then
        continue;

      if tokens[0] = 'globals' then
        continue
      else if tokens[0] = 'global' then
        readGlobalSummary(tokens)
      else if tokens[0] = 'procedures' then
        continue
      else if tokens[0] = 'proc' then
        currentProcedureIndex := beginProcedure(tokens)
      else if tokens[0] = 'param' then
        readProcedureParameter(currentProcedureIndex, tokens)
      else if (tokens[0] = 'local') or (tokens[0] = 'temp') then
        continue
      else if tokens[0] = 'block' then
        readBlockSummary(currentProcedureIndex, tokens)
      else if tokens[0] = 'labelmap' then
        readLabelMap(currentProcedureIndex, tokens)
      else if tokens[0] = 'endproc' then
        currentProcedureIndex := 0
      else if tokens[0][1] in ['0'..'9'] then
      begin
        parseInstructionLine(currentProcedureIndex, tokens);
        instructionTotal := instructionTotal + 1
      end
    end
  finally
    tokens.Free
  end;

  Close(llirFile);
  emitDiagnostic(status, STATUS_PCODE_READING_COMPLETE + IntToStr(instructionTotal))
end;

function findVariable(variableName: string): integer;
var
  variableIndex: integer;
begin
  findVariable := 0;
  for variableIndex := 1 to variableCount do
    if variables[variableIndex].name = variableName then
    begin
      findVariable := variableIndex;
      exit
    end
end;

function ensureVariable(variableName: string): integer;
begin
  ensureVariable := findVariable(variableName);
  if ensureVariable <> 0 then
    exit;

  if variableCount >= maxTacVariables then
  begin
    reportRuntimeError('Too many TAC runtime variables.');
    halt(1)
  end;

  variableCount := variableCount + 1;
  variables[variableCount].name := variableName;
  variables[variableCount].address := nextVariableAddress;
  variables[variableCount].value := 0;
  nextVariableAddress := nextVariableAddress + 1;
  ensureVariable := variableCount
end;

procedure readGlobalSummary(const tokens: TStrings);
var
  operand: llirRuntimeOperand;
begin
  if tokens.Count < 3 then
    exit;

  operand := parseOperand(tokens[2]);
  if operand.kind = rtOperandGlobal then
    ensureVariable(operand.name)
end;

function findMemoryCell(address: integer): integer;
var
  memoryIndex: integer;
begin
  findMemoryCell := 0;
  for memoryIndex := 1 to memoryCellCount do
    if memoryCells[memoryIndex].address = address then
    begin
      findMemoryCell := memoryIndex;
      exit
    end
end;

function ensureMemoryCell(address: integer): integer;
begin
  ensureMemoryCell := findMemoryCell(address);
  if ensureMemoryCell <> 0 then
    exit;

  if memoryCellCount >= maxTacMemoryCells then
  begin
    reportRuntimeError('Too many TAC runtime memory cells.');
    halt(1)
  end;

  memoryCellCount := memoryCellCount + 1;
  memoryCells[memoryCellCount].address := address;
  memoryCells[memoryCellCount].value := 0;
  ensureMemoryCell := memoryCellCount
end;

function addressValue(const operand: llirRuntimeOperand): integer;
var
  variableIndex: integer;
begin
  case operand.kind of
    rtOperandImmediate:
      addressValue := operand.value;
    rtOperandTemporary:
      addressValue := temporaries[operand.temporaryId];
    rtOperandLocal,
    rtOperandParameter,
    rtOperandGlobal:
      begin
        variableIndex := ensureVariable(operand.name);
        addressValue := variables[variableIndex].address
      end
  else
    addressValue := 0
  end
end;

function loadMemory(address: integer): integer;
begin
  loadMemory := memoryCells[ensureMemoryCell(address)].value
end;

procedure storeMemory(address, value: integer);
begin
  memoryCells[ensureMemoryCell(address)].value := value
end;

function operandValue(const operand: llirRuntimeOperand): integer;
var
  variableIndex: integer;
begin
  case operand.kind of
    rtOperandImmediate:
      operandValue := operand.value;
    rtOperandTemporary:
      operandValue := temporaries[operand.temporaryId];
    rtOperandLocal,
    rtOperandParameter,
    rtOperandGlobal:
      begin
        variableIndex := ensureVariable(operand.name);
        operandValue := loadMemory(variables[variableIndex].address);
        variables[variableIndex].value := operandValue
      end
  else
    operandValue := 0
  end
end;

function variableValueByName(const variableName: string): integer;
var
  variableIndex: integer;
begin
  variableIndex := ensureVariable(variableName);
  variableValueByName := loadMemory(variables[variableIndex].address);
  variables[variableIndex].value := variableValueByName
end;

procedure assignOperand(const operand: llirRuntimeOperand; value: integer);
var
  variableIndex: integer;
begin
  case operand.kind of
    rtOperandTemporary:
      temporaries[operand.temporaryId] := value;
    rtOperandLocal,
    rtOperandParameter,
    rtOperandGlobal:
      begin
        variableIndex := ensureVariable(operand.name);
        variables[variableIndex].value := value;
        storeMemory(variables[variableIndex].address, value)
      end
  end
end;

procedure initializeRuntimeState;
begin
  variableCount := 0;
  nextVariableAddress := 1;
  memoryCellCount := 0;
  FillChar(temporaries, SizeOf(temporaries), 0);
  returnStackTop := 0
end;

function findProcedure(const procedureName: string): integer;
var
  procedureIndex: integer;
begin
  findProcedure := 0;
  for procedureIndex := 1 to procedureCount do
    if SameText(Trim(procedures[procedureIndex].name), Trim(procedureName)) then
    begin
      findProcedure := procedureIndex;
      exit
    end
end;

function labelTarget(procedureIndex, labelId: integer): integer;
begin
  if (procedureIndex < 1) or (procedureIndex > procedureCount) then
    labelTarget := 0
  else if (labelId >= 1) and (labelId <= maxTacLabels) then
    labelTarget := procedures[procedureIndex].labelTargets[labelId]
  else
    labelTarget := 0;

  if labelTarget = 0 then
  begin
    reportRuntimeError('Unknown TAC label.');
    halt(1)
  end
end;

procedure consumeInputLineRemainder;
var
  currentChar: char;
begin
  while not eof(input) do
  begin
    read(input, currentChar);
    if (currentChar = #10) or (currentChar = #13) then
      break
  end
end;

function readInputTokenOrHalt(consumeLineRemainder: boolean): string;
var
  currentChar: char;
  tokenTerminator: char;
begin
  readInputTokenOrHalt := '';
  tokenTerminator := #0;

  while not eof(input) do
  begin
    read(input, currentChar);
    if currentChar > ' ' then
    begin
      readInputTokenOrHalt := currentChar;
      break
    end
  end;

  if readInputTokenOrHalt = '' then
  begin
    reportRuntimeError(ERROR_PCODEINT_INPUT_EXHAUSTED);
    halt(1)
  end;

  while not eof(input) do
  begin
    read(input, currentChar);
    if currentChar <= ' ' then
    begin
      tokenTerminator := currentChar;
      break
    end;
    readInputTokenOrHalt := readInputTokenOrHalt + currentChar
  end;

  if consumeLineRemainder and
     (tokenTerminator <> #10) and
     (tokenTerminator <> #13) then
    consumeInputLineRemainder
end;

function readIntegerValueOrHalt(consumeLineRemainder: boolean): integer;
var
  inputToken: string;
  conversionStatus: integer;
begin
  inputToken := readInputTokenOrHalt(consumeLineRemainder);
  Val(inputToken, readIntegerValueOrHalt, conversionStatus);
  if conversionStatus <> 0 then
  begin
    reportRuntimeError(ERROR_PCODEINT_INVALID_INTEGER_INPUT);
    halt(1)
  end
end;

function readCharacterValueOrHalt(consumeLineRemainder: boolean): integer;
var
  inputToken: string;
begin
  inputToken := readInputTokenOrHalt(consumeLineRemainder);
  if Length(inputToken) <> 1 then
  begin
    reportRuntimeError(ERROR_PCODEINT_INVALID_CHARACTER_INPUT);
    halt(1)
  end;
  readCharacterValueOrHalt := Ord(inputToken[1])
end;

function readBooleanValueOrHalt(consumeLineRemainder: boolean): integer;
var
  inputToken: string;
begin
  inputToken := readInputTokenOrHalt(consumeLineRemainder);
  if inputToken = '0' then
    readBooleanValueOrHalt := 0
  else if inputToken = '1' then
    readBooleanValueOrHalt := 1
  else
  begin
    reportRuntimeError(ERROR_PCODEINT_INVALID_BOOLEAN_INPUT);
    halt(1)
  end
end;

function readValueByIntrinsic(const intrinsicName, valueType: string): integer;
var
  consumeLineRemainder: boolean;
begin
  consumeLineRemainder := intrinsicName = 'readln';
  if intrinsicName = 'read_char' then
    readValueByIntrinsic := readCharacterValueOrHalt(consumeLineRemainder)
  else if valueType = 'boolean' then
    readValueByIntrinsic := readBooleanValueOrHalt(consumeLineRemainder)
  else
    readValueByIntrinsic := readIntegerValueOrHalt(consumeLineRemainder)
end;

procedure executeIntrinsicCall(const instruction: llirRuntimeInstruction);
var
  value: integer;
  resultValueType: string;
begin
  resultValueType := instruction.resultOperand.valueType;
  if resultValueType = '' then
    resultValueType := 'integer';

  if instruction.targetOperand.name = 'read_int' then
  begin
    value := readValueByIntrinsic('read_int', resultValueType);
    if instruction.resultOperand.kind <> rtOperandNone then
      assignOperand(instruction.resultOperand, value)
  end
  else if instruction.targetOperand.name = 'read_char' then
  begin
    value := readValueByIntrinsic('read_char', 'char');
    if instruction.resultOperand.kind <> rtOperandNone then
      assignOperand(instruction.resultOperand, value)
  end
  else if instruction.targetOperand.name = 'write_int' then
  begin
    if instruction.callArgumentCount >= 1 then
      value := operandValue(instruction.callArguments[1])
    else
      value := 0;
    Write(value)
  end
  else if instruction.targetOperand.name = 'write_char' then
  begin
    if instruction.callArgumentCount >= 1 then
      value := operandValue(instruction.callArguments[1])
    else
      value := 0;
    Write(Chr(value))
  end
  else if instruction.targetOperand.name = 'write_string' then
  begin
    reportRuntimeError('TAC write_string intrinsic is not implemented yet.');
    halt(1)
  end
  else if instruction.targetOperand.name = 'writeln' then
    WriteLn
  else if instruction.targetOperand.name = 'readln' then
    consumeInputLineRemainder
  else
  begin
    reportRuntimeError('Unknown TAC intrinsic call.');
    halt(1)
  end;

end;

procedure executeTac;
var
  currentProcedureIndex, programCounter, calleeProcedureIndex, argumentIndex: integer;
  instruction: llirRuntimeInstruction;
begin
  emitDiagnostic(status, STATUS_PCODEINT_START);
  initializeRuntimeState;
  if procedureCount = 0 then
    exit;

  currentProcedureIndex := 1;
  programCounter := 1;
  while (currentProcedureIndex <> 0) and (programCounter <> 0) do
  begin
    if (programCounter < 1) or
       (programCounter > procedures[currentProcedureIndex].instructionCount) then
    begin
      reportRuntimeError('TAC instruction pointer out of range.');
      halt(1)
    end;

    instruction := procedures[currentProcedureIndex].instructions[programCounter];
    case instruction.kind of
      rtAdd:
        begin
          assignOperand(instruction.resultOperand,
                        operandValue(instruction.leftOperand) +
                        operandValue(instruction.rightOperand));
          programCounter := programCounter + 1
        end;
      rtSub:
        begin
          assignOperand(instruction.resultOperand,
                        operandValue(instruction.leftOperand) -
                        operandValue(instruction.rightOperand));
          programCounter := programCounter + 1
        end;
      rtMul:
        begin
          assignOperand(instruction.resultOperand,
                        operandValue(instruction.leftOperand) *
                        operandValue(instruction.rightOperand));
          programCounter := programCounter + 1
        end;
      rtDiv:
        begin
          assignOperand(instruction.resultOperand,
                        operandValue(instruction.leftOperand) div
                        operandValue(instruction.rightOperand));
          programCounter := programCounter + 1
        end;
      rtMod:
        begin
          assignOperand(instruction.resultOperand,
                        operandValue(instruction.leftOperand) mod
                        operandValue(instruction.rightOperand));
          programCounter := programCounter + 1
        end;
      rtNeg:
        begin
          assignOperand(instruction.resultOperand,
                        -operandValue(instruction.leftOperand));
          programCounter := programCounter + 1
        end;
      rtCmpEq:
        begin
          assignOperand(instruction.resultOperand,
                        Ord(operandValue(instruction.leftOperand) =
                            operandValue(instruction.rightOperand)));
          programCounter := programCounter + 1
        end;
      rtCmpNe:
        begin
          assignOperand(instruction.resultOperand,
                        Ord(operandValue(instruction.leftOperand) <>
                            operandValue(instruction.rightOperand)));
          programCounter := programCounter + 1
        end;
      rtCmpLt:
        begin
          assignOperand(instruction.resultOperand,
                        Ord(operandValue(instruction.leftOperand) <
                            operandValue(instruction.rightOperand)));
          programCounter := programCounter + 1
        end;
      rtCmpLe:
        begin
          assignOperand(instruction.resultOperand,
                        Ord(operandValue(instruction.leftOperand) <=
                            operandValue(instruction.rightOperand)));
          programCounter := programCounter + 1
        end;
      rtCmpGt:
        begin
          assignOperand(instruction.resultOperand,
                        Ord(operandValue(instruction.leftOperand) >
                            operandValue(instruction.rightOperand)));
          programCounter := programCounter + 1
        end;
      rtCmpGe:
        begin
          assignOperand(instruction.resultOperand,
                        Ord(operandValue(instruction.leftOperand) >=
                            operandValue(instruction.rightOperand)));
          programCounter := programCounter + 1
        end;
      rtJump:
        programCounter := labelTarget(currentProcedureIndex, instruction.targetOperand.value);
      rtBranchTrue:
        begin
          if operandValue(instruction.leftOperand) <> 0 then
            programCounter := labelTarget(currentProcedureIndex, instruction.targetOperand.value)
          else
            programCounter := programCounter + 1
        end;
      rtBranchFalse:
        begin
          if operandValue(instruction.leftOperand) = 0 then
            programCounter := labelTarget(currentProcedureIndex, instruction.targetOperand.value)
          else
            programCounter := programCounter + 1
        end;
      rtArg:
        begin
          reportRuntimeError('Legacy TAC arg instruction is no longer supported.');
          halt(1)
        end;
      rtCall:
        begin
          calleeProcedureIndex := findProcedure(instruction.targetOperand.name);
          if calleeProcedureIndex = 0 then
          begin
            reportRuntimeError('Unknown TAC procedure.');
            halt(1)
          end;
          if returnStackTop >= maxCallDepth then
          begin
            reportRuntimeError('TAC call stack overflow.');
            halt(1)
          end;
          if instruction.callArgumentCount <> procedures[calleeProcedureIndex].parameterCount then
          begin
            reportRuntimeError('TAC call argument count does not match procedure parameters.');
            halt(1)
          end;
          for argumentIndex := 1 to instruction.callArgumentCount do
            assignOperand(procedures[calleeProcedureIndex].parameters[argumentIndex],
                          operandValue(instruction.callArguments[argumentIndex]));
          returnStackTop := returnStackTop + 1;
          returnStack[returnStackTop].procedureIndex := currentProcedureIndex;
          returnStack[returnStackTop].instructionIndex := programCounter + 1;
          returnStack[returnStackTop].resultOperand := instruction.resultOperand;
          returnStack[returnStackTop].calleeProcedureIndex := calleeProcedureIndex;
          currentProcedureIndex := calleeProcedureIndex;
          programCounter := 1
        end;
      rtResult:
        begin
          reportRuntimeError('Legacy TAC result instruction is no longer supported.');
          halt(1)
        end;
      rtIntrinsicCall:
        begin
          executeIntrinsicCall(instruction);
          programCounter := programCounter + 1
        end;
      rtLoadConst:
        begin
          assignOperand(instruction.resultOperand, operandValue(instruction.leftOperand));
          programCounter := programCounter + 1
        end;
      rtCopy:
        begin
          assignOperand(instruction.resultOperand, operandValue(instruction.leftOperand));
          programCounter := programCounter + 1
        end;
      rtAddrLocal,
      rtAddrParam,
      rtAddrGlobal:
        begin
          assignOperand(instruction.resultOperand, addressValue(instruction.leftOperand));
          programCounter := programCounter + 1
        end;
      rtFieldAddr:
        begin
          assignOperand(instruction.resultOperand,
                        addressValue(instruction.leftOperand) +
                        operandValue(instruction.rightOperand));
          programCounter := programCounter + 1
        end;
      rtIndexAddr:
        begin
          assignOperand(instruction.resultOperand,
                        addressValue(instruction.leftOperand) +
                        operandValue(instruction.rightOperand) *
                        operandValue(instruction.targetOperand));
          programCounter := programCounter + 1
        end;
      rtLoadAddr:
        begin
          assignOperand(instruction.resultOperand,
                        loadMemory(addressValue(instruction.leftOperand)));
          programCounter := programCounter + 1
        end;
      rtStoreAddr:
        begin
          storeMemory(addressValue(instruction.resultOperand),
                      operandValue(instruction.leftOperand));
          programCounter := programCounter + 1
        end;
      rtGoto:
        programCounter := labelTarget(currentProcedureIndex, instruction.targetOperand.value);
      rtLabel,
      rtNoOp:
        programCounter := programCounter + 1;
      rtLoadVar:
        begin
          assignOperand(instruction.resultOperand, operandValue(instruction.leftOperand));
          programCounter := programCounter + 1
        end;
      rtStoreVar:
        begin
          assignOperand(instruction.resultOperand, operandValue(instruction.leftOperand));
          programCounter := programCounter + 1
        end;
      rtReturn:
        begin
          if returnStackTop = 0 then
          begin
            currentProcedureIndex := 0;
            programCounter := 0
          end
          else
          begin
            if returnStack[returnStackTop].resultOperand.kind <> rtOperandNone then
              assignOperand(returnStack[returnStackTop].resultOperand,
                            variableValueByName(
                              procedures[returnStack[returnStackTop].calleeProcedureIndex].name));
            currentProcedureIndex := returnStack[returnStackTop].procedureIndex;
            programCounter := returnStack[returnStackTop].instructionIndex;
            returnStackTop := returnStackTop - 1
          end
        end
    end
  end;
  emitDiagnostic(status, STATUS_PCODEINT_END)
end;

begin
  if ParamCount < 1 then
  begin
    WriteLn('Usage: llirint <llir-file> [quiet|all]');
    halt(1)
  end;

  if ParamCount >= 2 then
  begin
    if not tryParseDiagnosticVerbosity(ParamStr(2), verbosity) then
    begin
      WriteLn('Invalid diagnostic verbosity: ', ParamStr(2));
      WriteLn('Valid verbosity values: quiet, all');
      halt(1)
    end;
    setDiagnosticVerbosity(verbosity)
  end;

  llirFileName := ParamStr(1);
  Assign(llirFile, llirFileName);
  Reset(llirFile);
  loadTacFile;
  executeTac
end.

