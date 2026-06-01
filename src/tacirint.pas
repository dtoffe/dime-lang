{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-31

  TAC IR interpreter. This standalone program reads the textual .tac image
  dumped by tacir, reconstructs the flat symbolic instruction stream, and
  executes it directly. It is intentionally close to the staged TAC model:
  variables remain symbolic, temporaries are numeric slots, labels are symbolic
  jump targets, and procedure calls use a small return-address stack. }
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
    rtOperandConst,
    rtOperandSymbol,
    rtOperandTemp
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
    operatorText: string;
    targetLabel: integer;
    procedureName: string;
    builtinName: string
  end;

  tacRuntimeProcedure = record
    name: string;
    firstInstruction: integer;
    instructionCount: integer
  end;

  tacRuntimeVariable = record
    name: string;
    value: integer
  end;

var
  tacFile: Text;
  tacFileName: string;
  verbosity: diagnosticVerbosity;
  instructions: array [1..maxTacInstructions] of tacRuntimeInstruction;
  instructionCount: integer;
  procedures: array [1..maxTacProcedures] of tacRuntimeProcedure;
  procedureCount: integer;
  labelTargets: array [1..maxTacLabels] of integer;
  temporaries: array [1..maxTacTemporaries] of integer;
  variables: array [1..maxTacVariables] of tacRuntimeVariable;
  variableCount: integer;
  returnStack: array [1..maxCallDepth] of integer;
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
  separatorIndex: integer;
  atomText, typeText: string;
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

  parseOperand.valueType := typeText;
  if (atomText <> '') and (atomText[1] = '#') then
  begin
    parseOperand.kind := rtOperandConst;
    parseOperand.value := parseIntegerOrHalt(Copy(atomText, 2, Length(atomText)),
                                             'Invalid TAC constant operand.')
  end
  else if (Length(atomText) > 1) and (atomText[1] = 't') and
          (atomText[2] in ['0'..'9']) then
  begin
    parseOperand.kind := rtOperandTemp;
    parseOperand.temporaryId := parseIntegerOrHalt(Copy(atomText, 2, Length(atomText)),
                                                   'Invalid TAC temporary operand.')
  end
  else
  begin
    parseOperand.kind := rtOperandSymbol;
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
  else if kindText = 'load_var' then
    instructionKindFromText := rtLoadVar
  else if kindText = 'store_var' then
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

procedure readProcedureSummary(const tokens: TStrings);
begin
  if procedureCount >= maxTacProcedures then
  begin
    reportRuntimeError('Too many TAC procedures.');
    halt(1)
  end;

  procedureCount := procedureCount + 1;
  procedures[procedureCount].name := tokens[2];
  procedures[procedureCount].instructionCount :=
    parseIntegerOrHalt(tokenValue(tokens[4], 'instructions'),
                       'Invalid TAC procedure instruction count.')
end;

procedure parseInstructionLine(const tokens: TStrings);
var
  tokenIndex, instructionIndex, labelId: integer;
  valueText: string;
begin
  if tokens.Count < 2 then
    exit;

  instructionIndex := parseIntegerOrHalt(tokens[0], 'Invalid TAC instruction index.');
  if (instructionIndex < 1) or (instructionIndex > maxTacInstructions) then
  begin
    reportRuntimeError('TAC instruction index out of range.');
    halt(1)
  end;

  if instructionIndex > instructionCount then
    instructionCount := instructionIndex;

  instructions[instructionIndex].kind := instructionKindFromText(tokens[1]);
  instructions[instructionIndex].resultOperand := makeNoneOperand;
  instructions[instructionIndex].leftOperand := makeNoneOperand;
  instructions[instructionIndex].rightOperand := makeNoneOperand;
  instructions[instructionIndex].operatorText := '';
  instructions[instructionIndex].targetLabel := 0;
  instructions[instructionIndex].procedureName := '';
  instructions[instructionIndex].builtinName := '';

  for tokenIndex := 2 to tokens.Count - 1 do
  begin
    valueText := tokenValue(tokens[tokenIndex], 'result');
    if valueText <> '' then
      instructions[instructionIndex].resultOperand := parseOperand(valueText);

    valueText := tokenValue(tokens[tokenIndex], 'left');
    if valueText <> '' then
      instructions[instructionIndex].leftOperand := parseOperand(valueText);

    valueText := tokenValue(tokens[tokenIndex], 'right');
    if valueText <> '' then
      instructions[instructionIndex].rightOperand := parseOperand(valueText);

    valueText := tokenValue(tokens[tokenIndex], 'op');
    if valueText <> '' then
      instructions[instructionIndex].operatorText := valueText;

    valueText := tokenValue(tokens[tokenIndex], 'label');
    if valueText <> '' then
      instructions[instructionIndex].targetLabel := parseLabelId(valueText);

    valueText := tokenValue(tokens[tokenIndex], 'proc');
    if valueText <> '' then
      instructions[instructionIndex].procedureName := valueText;

    valueText := tokenValue(tokens[tokenIndex], 'builtin');
    if valueText <> '' then
      instructions[instructionIndex].builtinName := valueText
  end;

  if instructions[instructionIndex].kind = rtLabel then
  begin
    labelId := instructions[instructionIndex].targetLabel;
    if (labelId >= 1) and (labelId <= maxTacLabels) then
      labelTargets[labelId] := instructionIndex
  end
end;

procedure assignProcedureStarts;
var
  procedureIndex, nextInstruction: integer;
begin
  nextInstruction := 1;
  for procedureIndex := 1 to procedureCount do
  begin
    procedures[procedureIndex].firstInstruction := nextInstruction;
    nextInstruction := nextInstruction + procedures[procedureIndex].instructionCount
  end
end;

procedure loadTacFile;
var
  tacLine: string;
  tokens: TStringList;
begin
  tokens := TStringList.Create;
  try
    while not EOF(tacFile) do
    begin
      ReadLn(tacFile, tacLine);
      splitLine(Trim(tacLine), tokens);
      if tokens.Count = 0 then
        continue;

      if tokens[0] = 'proc' then
        readProcedureSummary(tokens)
      else if tokens[0][1] in ['0'..'9'] then
        parseInstructionLine(tokens)
    end
  finally
    tokens.Free
  end;

  Close(tacFile);
  assignProcedureStarts;
  emitDiagnostic(status, STATUS_PCODE_READING_COMPLETE + IntToStr(instructionCount))
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
    rtOperandConst:
      operandValue := operand.value;
    rtOperandTemp:
      operandValue := temporaries[operand.temporaryId];
    rtOperandSymbol:
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
    rtOperandTemp:
      temporaries[operand.temporaryId] := value;
    rtOperandSymbol:
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

function labelTarget(labelId: integer): integer;
begin
  if (labelId >= 1) and (labelId <= maxTacLabels) then
    labelTarget := labelTargets[labelId]
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
    if instruction.builtinName = 'writeln' then
      WriteLn(Chr(value))
    else
      Write(Chr(value))
  end
  else
  begin
    if instruction.builtinName = 'writeln' then
      WriteLn(value)
    else
      Write(value)
  end
end;

procedure executeTac;
var
  programCounter, procedureIndex: integer;
  instruction: tacRuntimeInstruction;
begin
  emitDiagnostic(status, STATUS_PCODEINT_START);
  variableCount := 0;
  FillChar(temporaries, SizeOf(temporaries), 0);
  returnStackTop := 0;
  if procedureCount = 0 then
    exit;

  programCounter := procedures[1].firstInstruction;
  while programCounter <> 0 do
  begin
    instruction := instructions[programCounter];
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
        programCounter := labelTarget(instruction.targetLabel);
      rtGotoIfZero:
        begin
          if operandValue(instruction.leftOperand) = 0 then
            programCounter := labelTarget(instruction.targetLabel)
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
          procedureIndex := findProcedure(instruction.procedureName);
          if procedureIndex = 0 then
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
          returnStack[returnStackTop] := programCounter + 1;
          programCounter := procedures[procedureIndex].firstInstruction
        end;
      rtBuiltinRead:
        begin
          assignOperand(instruction.resultOperand,
                        readValueByType(instruction.resultOperand.valueType,
                                        instruction.builtinName));
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
            programCounter := 0
          else
          begin
            programCounter := returnStack[returnStackTop];
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
