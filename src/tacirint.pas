{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-06-05

  TAC IR interpreter. This standalone program reads the textual .tac image
  dumped by tacir, reconstructs procedure-scoped TAC units, and executes them
  directly. It stays intentionally close to the staged TAC model: variables
  remain symbolic, temporaries are numeric slots, labels are symbolic jump
  targets, and procedure calls use a small return-address stack. }
program tacirint;

{$mode objfpc}
{$H+}

uses
  SysUtils, Classes, diagnostics;

const
  maxTacInstructions = 500;
  maxTacProcedures = 64;
  maxTacLabels = 500;
  maxTacTemporaries = 500;
  maxTacVariables = 200;
  maxCallDepth = 64;

type
  tacRuntimeInstructionKind = (
    rtNoOp,
    rtLoadConst,
    rtCopy,
    rtUnaryOp,
    rtBinaryOp,
    rtGoto,
    rtGotoIfZero,
    rtLabel,
    rtLoadVar,
    rtStoreVar,
    rtCallProc,
    rtBuiltinRead,
    rtBuiltinWrite,
    rtReturn
  );

  tacRuntimeOperandKind = (
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

  tacRuntimeOperand = record
    kind: tacRuntimeOperandKind;
    valueType: string;
    name: string;
    value: integer;
    temporaryId: integer
  end;

  tacRuntimeInstruction = record
    kind: tacRuntimeInstructionKind;
    resultOperand: tacRuntimeOperand;
    leftOperand: tacRuntimeOperand;
    rightOperand: tacRuntimeOperand;
    targetOperand: tacRuntimeOperand;
    operatorText: string;
  end;

  tacRuntimeProcedure = record
    name: string;
    instructionCount: integer;
    instructions: array [1..maxTacInstructions] of tacRuntimeInstruction;
    labelTargets: array [1..maxTacLabels] of integer
  end;

  tacRuntimeVariable = record
    name: string;
    value: integer
  end;

  tacReturnAddress = record
    procedureIndex: integer;
    instructionIndex: integer
  end;

var
  tacFile: Text;
  tacFileName: string;
  verbosity: diagnosticVerbosity;
  procedures: array [1..maxTacProcedures] of tacRuntimeProcedure;
  procedureCount: integer;
  variables: array [1..maxTacVariables] of tacRuntimeVariable;
  variableCount: integer;
  temporaries: array [1..maxTacTemporaries] of integer;
  returnStack: array [1..maxCallDepth] of tacReturnAddress;
  returnStackTop: integer;

function makeNoneOperand: tacRuntimeOperand;
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

function parseOperand(const operandText: string): tacRuntimeOperand;
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

function instructionKindFromText(const kindText: string): tacRuntimeInstructionKind;
begin
  if kindText = 'load_const' then
    instructionKindFromText := rtLoadConst
  else if kindText = 'copy' then
    instructionKindFromText := rtCopy
  else if kindText = 'unary' then
    instructionKindFromText := rtUnaryOp
  else if kindText = 'binary' then
    instructionKindFromText := rtBinaryOp
  else if kindText = 'goto' then
    instructionKindFromText := rtGoto
  else if kindText = 'goto_if_zero' then
    instructionKindFromText := rtGotoIfZero
  else if kindText = 'label' then
    instructionKindFromText := rtLabel
  else if (kindText = 'load') or (kindText = 'load_var') then
    instructionKindFromText := rtLoadVar
  else if (kindText = 'store') or (kindText = 'store_var') then
    instructionKindFromText := rtStoreVar
  else if kindText = 'call_proc' then
    instructionKindFromText := rtCallProc
  else if kindText = 'builtin_read' then
    instructionKindFromText := rtBuiltinRead
  else if kindText = 'builtin_write' then
    instructionKindFromText := rtBuiltinWrite
  else if kindText = 'return' then
    instructionKindFromText := rtReturn
  else
    instructionKindFromText := rtNoOp
end;

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
  procedures[procedureCount].instructionCount := 0;
  FillChar(procedures[procedureCount].labelTargets,
           SizeOf(procedures[procedureCount].labelTargets), 0);
  beginProcedure := procedureCount
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
  tokenIndex, instructionIndex: integer;
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
  procedures[procedureIndex].instructions[instructionIndex].operatorText := '';

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
        parseOperand(valueText)
  end;

end;

procedure loadTacFile;
var
  tacLine: string;
  tokens: TStringList;
  currentProcedureIndex: integer;
  instructionTotal: integer;
begin
  currentProcedureIndex := 0;
  instructionTotal := 0;
  tokens := TStringList.Create;
  try
    while not EOF(tacFile) do
    begin
      ReadLn(tacFile, tacLine);
      splitLine(Trim(tacLine), tokens);
      if tokens.Count = 0 then
        continue;

      if tokens[0] = 'proc' then
        currentProcedureIndex := beginProcedure(tokens)
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

  Close(tacFile);
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
  variables[variableCount].value := 0;
  ensureVariable := variableCount
end;

function operandValue(const operand: tacRuntimeOperand): integer;
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
        operandValue := variables[variableIndex].value
      end
  else
    operandValue := 0
  end
end;

procedure assignOperand(const operand: tacRuntimeOperand; value: integer);
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
        variables[variableIndex].value := value
      end
  end
end;

function findProcedure(const procedureName: string): integer;
var
  procedureIndex: integer;
begin
  findProcedure := 0;
  for procedureIndex := 1 to procedureCount do
    if procedures[procedureIndex].name = procedureName then
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

function applyUnaryOperator(const operatorText: string; operand: integer): integer;
begin
  if operatorText = '-' then
    applyUnaryOperator := -operand
  else if operatorText = 'not' then
    applyUnaryOperator := Ord(operand = 0)
  else
    applyUnaryOperator := operand
end;

function applyBinaryOperator(const operatorText: string; leftValue, rightValue: integer): integer;
begin
  if operatorText = '+' then
    applyBinaryOperator := leftValue + rightValue
  else if operatorText = '-' then
    applyBinaryOperator := leftValue - rightValue
  else if operatorText = '*' then
    applyBinaryOperator := leftValue * rightValue
  else if operatorText = '/' then
    applyBinaryOperator := leftValue div rightValue
  else if operatorText = '=' then
    applyBinaryOperator := Ord(leftValue = rightValue)
  else if operatorText = '<>' then
    applyBinaryOperator := Ord(leftValue <> rightValue)
  else if operatorText = '<' then
    applyBinaryOperator := Ord(leftValue < rightValue)
  else if operatorText = '<=' then
    applyBinaryOperator := Ord(leftValue <= rightValue)
  else if operatorText = '>' then
    applyBinaryOperator := Ord(leftValue > rightValue)
  else if operatorText = '>=' then
    applyBinaryOperator := Ord(leftValue >= rightValue)
  else if operatorText = 'and' then
    applyBinaryOperator := Ord((leftValue <> 0) and (rightValue <> 0))
  else if operatorText = 'or' then
    applyBinaryOperator := Ord((leftValue <> 0) or (rightValue <> 0))
  else if operatorText = 'xor' then
    applyBinaryOperator := Ord((leftValue <> 0) xor (rightValue <> 0))
  else
    applyBinaryOperator := 0
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

function readValueByType(const valueType, builtinName: string): integer;
var
  consumeLineRemainder: boolean;
begin
  consumeLineRemainder := builtinName = 'readln';
  if valueType = 'char' then
    readValueByType := readCharacterValueOrHalt(consumeLineRemainder)
  else if valueType = 'boolean' then
    readValueByType := readBooleanValueOrHalt(consumeLineRemainder)
  else
    readValueByType := readIntegerValueOrHalt(consumeLineRemainder)
end;

procedure executeBuiltinWrite(const instruction: tacRuntimeInstruction);
var
  value: integer;
begin
  value := operandValue(instruction.leftOperand);
  if instruction.leftOperand.valueType = 'char' then
  begin
    if instruction.targetOperand.name = 'writeln' then
      WriteLn(Chr(value))
    else
      Write(Chr(value))
  end
  else
  begin
    if instruction.targetOperand.name = 'writeln' then
      WriteLn(value)
    else
      Write(value)
  end
end;

procedure executeTac;
var
  currentProcedureIndex, programCounter, calleeProcedureIndex: integer;
  instruction: tacRuntimeInstruction;
begin
  emitDiagnostic(status, STATUS_PCODEINT_START);
  variableCount := 0;
  FillChar(temporaries, SizeOf(temporaries), 0);
  returnStackTop := 0;
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
      rtUnaryOp:
        begin
          assignOperand(instruction.resultOperand,
                        applyUnaryOperator(instruction.operatorText,
                                           operandValue(instruction.leftOperand)));
          programCounter := programCounter + 1
        end;
      rtBinaryOp:
        begin
          assignOperand(instruction.resultOperand,
                        applyBinaryOperator(instruction.operatorText,
                                            operandValue(instruction.leftOperand),
                                            operandValue(instruction.rightOperand)));
          programCounter := programCounter + 1
        end;
      rtGoto:
        programCounter := labelTarget(currentProcedureIndex, instruction.targetOperand.value);
      rtGotoIfZero:
        begin
          if operandValue(instruction.leftOperand) = 0 then
            programCounter := labelTarget(currentProcedureIndex, instruction.targetOperand.value)
          else
            programCounter := programCounter + 1
        end;
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
      rtCallProc:
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
          returnStackTop := returnStackTop + 1;
          returnStack[returnStackTop].procedureIndex := currentProcedureIndex;
          returnStack[returnStackTop].instructionIndex := programCounter + 1;
          currentProcedureIndex := calleeProcedureIndex;
          programCounter := 1
        end;
      rtBuiltinRead:
        begin
          assignOperand(instruction.resultOperand,
                        readValueByType(instruction.resultOperand.valueType,
                                        instruction.targetOperand.name));
          programCounter := programCounter + 1
        end;
      rtBuiltinWrite:
        begin
          executeBuiltinWrite(instruction);
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
    WriteLn('Usage: tacirint <tac-file> [quiet|all]');
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

  tacFileName := ParamStr(1);
  Assign(tacFile, tacFileName);
  Reset(tacFile);
  loadTacFile;
  executeTac
end.
