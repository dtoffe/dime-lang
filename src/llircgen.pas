{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-06-09

  HLIR-to-LLIR lowering support for the compiler pipeline. This unit walks the
  structured high-level IR and uses llir as a low-level service to build the
  current normalized LLIR backend image. It owns structural lowering only:
  expressions become temporaries, and structured control flow becomes labels and
  jumps. It does not parse source text, perform semantic checks, allocate
  registers, assign final stack slots, or emit target code. }
unit llircgen;

{$mode objfpc}

interface

uses
  hlir;

procedure generateLlirProgram(const programData: hirProgramRecord;
                              var errorCount: integer);

implementation

uses
  llir, symboltable, typetable;

var
  currentLoweredFunctionSymbol: symbolIndex;
  loopBreakLabels: array [1..maxTacInstructions] of llirLabelId;
  loopBreakLabelCount: integer;
  loopContinueLabels: array [1..maxTacInstructions] of llirLabelId;
  loopContinueLabelCount: integer;

function hirScalarType(const typeRef: hirTypeRef): typeValue;
begin
  hirScalarType := typeRef.scalarType
end;

function symbolOperandFromRef(const symbolRef: hirSymbolRef): llirOperand;
begin
  if symbolRef.symbol = 0 then
    symbolOperandFromRef := makeTacNoneOperand
  else
    symbolOperandFromRef := makeTacSymbolOperand(symbolRef.symbol,
                                                 symbolRef.name,
                                                 hirScalarType(symbolRef.valueType))
end;

function storageOperandFromRef(const symbolRef: hirSymbolRef): llirOperand;
begin
  storageOperandFromRef := makeTacNoneOperand;
  if symbolRef.symbol = 0 then
    exit;

  if not (getDeclarationKind(symbolRef.symbol) in [variable, func]) then
    exit;

  storageOperandFromRef := makeTacSymbolOperand(symbolRef.symbol,
                                                symbolRef.name,
                                                hirScalarType(symbolRef.valueType))
end;

procedure recordRoutineLocals(const routineNode: hirRoutine; procedureIndex: llirProcedureIndex);
var
  declarationNode: hirDeclaration;
begin
  if (routineNode = nil) or (procedureIndex = 0) then
    exit;

  declarationNode := routineNode^.firstLocal;
  while declarationNode <> nil do
  begin
    if (declarationNode^.kind = hirDeclVariable) and
       (declarationNode^.symbolInfo.symbol <> 0) then
      addTacProcedureLocal(procedureIndex, declarationNode^.symbolInfo.symbol);
    declarationNode := declarationNode^.nextSibling
  end
end;

procedure recordProgramGlobalsAsLocals(const programData: hirProgramRecord;
                                       procedureIndex: llirProcedureIndex);
var
  declarationNode: hirDeclaration;
begin
  if procedureIndex = 0 then
    exit;

  declarationNode := programData.firstGlobal;
  while declarationNode <> nil do
  begin
    if (declarationNode^.kind = hirDeclVariable) and
       (declarationNode^.symbolInfo.symbol <> 0) then
      addTacProcedureLocal(procedureIndex, declarationNode^.symbolInfo.symbol);
    declarationNode := declarationNode^.nextSibling
  end
end;

procedure describeRoutine(procedureIndex: llirProcedureIndex; routineNode: hirRoutine);
var
  declarationNode: hirDeclaration;
begin
  if (routineNode = nil) or (procedureIndex = 0) then
    exit;

  setTacProcedureReturnType(procedureIndex,
                            hirScalarType(routineNode^.returnType),
                            routineNode^.hasReturnValue);

  declarationNode := routineNode^.firstParameter;
  while declarationNode <> nil do
  begin
    if declarationNode^.symbolInfo.symbol <> 0 then
      addTacProcedureParameter(procedureIndex, declarationNode^.symbolInfo.symbol);
    declarationNode := declarationNode^.nextSibling
  end;

  recordRoutineLocals(routineNode, procedureIndex)
end;

procedure appendLabel(labelId: llirLabelId);
begin
  appendTacBasicBlock(labelId)
end;

procedure appendGoto(labelId: llirLabelId);
var
  instruction: llirInstruction;
begin
  instruction := newTacInstruction(irJump);
  instruction.targetOperand := makeTacLabelOperand(labelId);
  appendTacInstruction(instruction)
end;

procedure appendGotoIfZero(const conditionOperand: llirOperand; labelId: llirLabelId);
var
  instruction: llirInstruction;
begin
  instruction := newTacInstruction(irBranchFalse);
  instruction.leftOperand := conditionOperand;
  instruction.targetOperand := makeTacLabelOperand(labelId);
  appendTacInstruction(instruction)
end;

procedure appendProcedureEnter;
var
  instruction: llirInstruction;
begin
  instruction := newTacInstruction(irEnterFrame);
  instruction.leftOperand := makeTacConstOperand(0, typeInteger);
  appendTacInstruction(instruction)
end;

procedure appendProcedureLeaveAndReturn;
var
  instruction: llirInstruction;
begin
  instruction := newTacInstruction(irLeaveFrame);
  appendTacInstruction(instruction);
  instruction := newTacInstruction(irReturn);
  appendTacInstruction(instruction)
end;

function loadSymbolValue(const symbolRef: hirSymbolRef): llirOperand;
var
  instruction: llirInstruction;
begin
  loadSymbolValue := newTacTemporary(hirScalarType(symbolRef.valueType));
  instruction := newTacInstruction(irLoadVar);
  instruction.resultOperand := loadSymbolValue;
  instruction.leftOperand := symbolOperandFromRef(symbolRef);
  appendTacInstruction(instruction)
end;

procedure appendIntrinsicCall(intrinsicKind: llirIntrinsicKind;
                              const resultOperand: llirOperand;
                              const argumentOperands: array of llirOperand);
var
  instruction: llirInstruction;
  argumentIndex: integer;
begin
  instruction := newTacInstruction(irIntrinsicCall);
  instruction.resultOperand := resultOperand;
  instruction.targetOperand := makeTacIntrinsicOperand(intrinsicKind);
  for argumentIndex := 0 to High(argumentOperands) do
    setTacCallArgument(instruction, argumentIndex + 1, argumentOperands[argumentIndex]);
  appendTacInstruction(instruction)
end;

procedure appendCallArgument(argumentIndex: integer; const argumentOperand: llirOperand);
var
  instruction: llirInstruction;
begin
  instruction := newTacInstruction(irArg);
  instruction.positionIndex := argumentIndex;
  instruction.leftOperand := argumentOperand;
  appendTacInstruction(instruction)
end;

procedure pushLoopBreakLabel(labelId: llirLabelId);
begin
  loopBreakLabelCount := loopBreakLabelCount + 1;
  loopBreakLabels[loopBreakLabelCount] := labelId
end;

procedure popLoopBreakLabel;
begin
  if loopBreakLabelCount > 0 then
    loopBreakLabelCount := loopBreakLabelCount - 1
end;

function currentLoopBreakLabel: llirLabelId;
begin
  if loopBreakLabelCount > 0 then
    currentLoopBreakLabel := loopBreakLabels[loopBreakLabelCount]
  else
    currentLoopBreakLabel := 0
end;

procedure pushLoopContinueLabel(labelId: llirLabelId);
begin
  loopContinueLabelCount := loopContinueLabelCount + 1;
  loopContinueLabels[loopContinueLabelCount] := labelId
end;

procedure popLoopContinueLabel;
begin
  if loopContinueLabelCount > 0 then
    loopContinueLabelCount := loopContinueLabelCount - 1
end;

function currentLoopContinueLabel: llirLabelId;
begin
  if loopContinueLabelCount > 0 then
    currentLoopContinueLabel := loopContinueLabels[loopContinueLabelCount]
  else
    currentLoopContinueLabel := 0
end;

function lowerExpression(expressionNode: hirExpression; var errorCount: integer): llirOperand; forward;
function lowerCall(const callSite: hirCallSite; resultType: typeValue;
                   expectsResult: boolean; var errorCount: integer): llirOperand; forward;
procedure lowerStatement(statementNode: hirStatement; var errorCount: integer); forward;
procedure lowerRoutineBody(routineNode: hirRoutine; var errorCount: integer); forward;

function lowerSymbolReference(expressionNode: hirExpression): llirOperand;
var
  instruction: llirInstruction;
  resolvedSymbol: symbolIndex;
begin
  lowerSymbolReference := makeTacNoneOperand;
  if (expressionNode = nil) or (expressionNode^.symbolInfo.symbol = 0) then
    exit;

  resolvedSymbol := expressionNode^.symbolInfo.symbol;
  case getDeclarationKind(resolvedSymbol) of
    constant:
      begin
        lowerSymbolReference := newTacTemporary(hirScalarType(expressionNode^.valueType));
        instruction := newTacInstruction(irCopy);
        instruction.resultOperand := lowerSymbolReference;
        instruction.leftOperand := makeTacConstOperand(getConstantValue(resolvedSymbol),
                                                       hirScalarType(expressionNode^.valueType));
        appendTacInstruction(instruction)
      end;
    variable:
      begin
        lowerSymbolReference := loadSymbolValue(expressionNode^.symbolInfo)
      end;
    func:
      begin
        lowerSymbolReference := loadSymbolValue(expressionNode^.symbolInfo)
      end;
    proc:
      { procedure-in-expression is rejected before HLIR is built }
  end
end;

function lowerLiteral(expressionNode: hirExpression): llirOperand;
var
  instruction: llirInstruction;
begin
  lowerLiteral := newTacTemporary(hirScalarType(expressionNode^.valueType));
  instruction := newTacInstruction(irCopy);
  instruction.resultOperand := lowerLiteral;
  instruction.leftOperand := makeTacConstOperand(expressionNode^.literalValue,
                                                 hirScalarType(expressionNode^.valueType));
  appendTacInstruction(instruction)
end;

function comparisonOpcodeFor(op: hirBinaryOperator): llirInstructionKind;
begin
  case op of
    hirBinaryEq: comparisonOpcodeFor := irCmpEq;
    hirBinaryNe: comparisonOpcodeFor := irCmpNe;
    hirBinaryLt: comparisonOpcodeFor := irCmpLt;
    hirBinaryLe: comparisonOpcodeFor := irCmpLe;
    hirBinaryGt: comparisonOpcodeFor := irCmpGt;
    hirBinaryGe: comparisonOpcodeFor := irCmpGe;
  else
    comparisonOpcodeFor := irNoOp
  end
end;

function arithmeticOpcodeFor(op: hirBinaryOperator): llirInstructionKind;
begin
  case op of
    hirBinaryAdd: arithmeticOpcodeFor := irAdd;
    hirBinarySub: arithmeticOpcodeFor := irSub;
    hirBinaryMul: arithmeticOpcodeFor := irMul;
    hirBinaryDiv: arithmeticOpcodeFor := irDiv;
  else
    arithmeticOpcodeFor := irNoOp
  end
end;

function lowerUnaryExpression(expressionNode: hirExpression; var errorCount: integer): llirOperand;
var
  operand: llirOperand;
  instruction: llirInstruction;
  zeroOperand: llirOperand;
begin
  operand := lowerExpression(expressionNode^.operand, errorCount);
  lowerUnaryExpression := newTacTemporary(hirScalarType(expressionNode^.valueType));
  if expressionNode^.unaryOperator = hirUnaryNegate then
    instruction := newTacInstruction(irNeg)
  else
  begin
    instruction := newTacInstruction(irCmpEq);
    zeroOperand := makeTacConstOperand(0, hirScalarType(expressionNode^.operand^.valueType));
    instruction.rightOperand := zeroOperand
  end;
  instruction.resultOperand := lowerUnaryExpression;
  instruction.leftOperand := operand;
  appendTacInstruction(instruction)
end;

function lowerBinaryExpression(expressionNode: hirExpression; var errorCount: integer): llirOperand;
var
  leftOperand, rightOperand: llirOperand;
  instruction: llirInstruction;
  sumOperand, oneOperand, zeroOperand: llirOperand;
begin
  leftOperand := lowerExpression(expressionNode^.leftOperand, errorCount);
  rightOperand := lowerExpression(expressionNode^.rightOperand, errorCount);
  lowerBinaryExpression := newTacTemporary(hirScalarType(expressionNode^.valueType));

  if expressionNode^.binaryOperator in [hirBinaryAdd, hirBinarySub,
                                        hirBinaryMul, hirBinaryDiv] then
    instruction := newTacInstruction(arithmeticOpcodeFor(expressionNode^.binaryOperator))
  else if expressionNode^.binaryOperator in [hirBinaryEq, hirBinaryNe, hirBinaryLt,
                                             hirBinaryLe, hirBinaryGt, hirBinaryGe] then
    instruction := newTacInstruction(comparisonOpcodeFor(expressionNode^.binaryOperator))
  else if expressionNode^.binaryOperator = hirBinaryAnd then
    instruction := newTacInstruction(irMul)
  else if expressionNode^.binaryOperator = hirBinaryOr then
  begin
    sumOperand := newTacTemporary(typeInteger);
    instruction := newTacInstruction(irAdd);
    instruction.resultOperand := sumOperand;
    instruction.leftOperand := leftOperand;
    instruction.rightOperand := rightOperand;
    appendTacInstruction(instruction);

    zeroOperand := makeTacConstOperand(0, typeInteger);
    instruction := newTacInstruction(irCmpNe);
    instruction.resultOperand := lowerBinaryExpression;
    instruction.leftOperand := sumOperand;
    instruction.rightOperand := zeroOperand;
    appendTacInstruction(instruction);
    exit
  end
  else if expressionNode^.binaryOperator = hirBinaryXor then
  begin
    sumOperand := newTacTemporary(typeInteger);
    instruction := newTacInstruction(irAdd);
    instruction.resultOperand := sumOperand;
    instruction.leftOperand := leftOperand;
    instruction.rightOperand := rightOperand;
    appendTacInstruction(instruction);

    oneOperand := makeTacConstOperand(1, typeInteger);
    instruction := newTacInstruction(irCmpEq);
    instruction.resultOperand := lowerBinaryExpression;
    instruction.leftOperand := sumOperand;
    instruction.rightOperand := oneOperand;
    appendTacInstruction(instruction);
    exit
  end
  else
    instruction := newTacInstruction(irAdd);
  instruction.resultOperand := lowerBinaryExpression;
  instruction.leftOperand := leftOperand;
  instruction.rightOperand := rightOperand;
  appendTacInstruction(instruction)
end;

function lowerCaseExpression(expressionNode: hirExpression; var errorCount: integer): llirOperand;
var
  selectorOperand, conditionOperand, whenOperand, branchOperand: llirOperand;
  resultOperand: llirOperand;
  nextLabel, endLabel: llirLabelId;
  instruction: llirInstruction;
  caseArmNode: hirCaseArm;
begin
  selectorOperand := makeTacNoneOperand;
  if expressionNode^.caseMode = hirCaseSimple then
    selectorOperand := lowerExpression(expressionNode^.selectorExpression, errorCount);

  resultOperand := newTacTemporary(hirScalarType(expressionNode^.valueType));
  endLabel := newTacLabel;
  caseArmNode := expressionNode^.firstCaseArm;
  while caseArmNode <> nil do
  begin
    if expressionNode^.caseMode = hirCaseSimple then
    begin
      whenOperand := lowerExpression(caseArmNode^.whenExpression, errorCount);
      conditionOperand := newTacTemporary(typeBoolean);
      instruction := newTacInstruction(irCmpEq);
      instruction.resultOperand := conditionOperand;
      instruction.leftOperand := selectorOperand;
      instruction.rightOperand := whenOperand;
      appendTacInstruction(instruction)
    end
    else
      conditionOperand := lowerExpression(caseArmNode^.whenExpression, errorCount);

    nextLabel := newTacLabel;
    appendGotoIfZero(conditionOperand, nextLabel);
    branchOperand := lowerExpression(caseArmNode^.resultExpression, errorCount);
    instruction := newTacInstruction(irCopy);
    instruction.resultOperand := resultOperand;
    instruction.leftOperand := branchOperand;
    appendTacInstruction(instruction);
    appendGoto(endLabel);
    appendLabel(nextLabel);
    caseArmNode := caseArmNode^.nextSibling
  end;

  branchOperand := lowerExpression(expressionNode^.elseExpression, errorCount);
  instruction := newTacInstruction(irCopy);
  instruction.resultOperand := resultOperand;
  instruction.leftOperand := branchOperand;
  appendTacInstruction(instruction);
  appendLabel(endLabel);
  lowerCaseExpression := resultOperand
end;

function lowerExpression(expressionNode: hirExpression; var errorCount: integer): llirOperand;
begin
  lowerExpression := makeTacNoneOperand;
  if expressionNode = nil then
    exit;

  case expressionNode^.kind of
    hirExprSymbol:
      lowerExpression := lowerSymbolReference(expressionNode);
    hirExprIntegerLiteral,
    hirExprBooleanLiteral,
    hirExprCharLiteral:
      lowerExpression := lowerLiteral(expressionNode);
    hirExprUnary:
      lowerExpression := lowerUnaryExpression(expressionNode, errorCount);
    hirExprBinary:
      lowerExpression := lowerBinaryExpression(expressionNode, errorCount);
    hirExprCall:
      lowerExpression := lowerCall(expressionNode^.callSite,
                                   hirScalarType(expressionNode^.valueType),
                                   true,
                                   errorCount);
    hirExprCase:
      lowerExpression := lowerCaseExpression(expressionNode, errorCount)
  end
end;

procedure lowerAssignmentStatement(statementNode: hirStatement; var errorCount: integer);
var
  valueOperand: llirOperand;
  instruction: llirInstruction;
begin
  valueOperand := lowerExpression(statementNode^.valueExpression, errorCount);
  instruction := newTacInstruction(irStoreVar);
  instruction.resultOperand := storageOperandFromRef(statementNode^.targetSymbol);
  instruction.leftOperand := valueOperand;
  appendTacInstruction(instruction)
end;

function lowerCall(const callSite: hirCallSite; resultType: typeValue;
                   expectsResult: boolean; var errorCount: integer): llirOperand;
var
  argumentOperand: llirOperand;
  instruction, storeInstruction: llirInstruction;
  argumentIndex: integer;
  readResult: llirOperand;
  argumentNode: hirExpression;
begin
  lowerCall := makeTacNoneOperand;

  if callSite.targetKind = hirCallBuiltin then
  begin
    if callSite.targetSymbol.builtinKind in [builtinWrite, builtinWriteLn] then
    begin
      if callSite.firstArgument <> nil then
      begin
        argumentOperand := lowerExpression(callSite.firstArgument, errorCount);
        appendIntrinsicCall(llirIntrinsicForWriteType(argumentOperand.valueType),
                            makeTacNoneOperand,
                            [argumentOperand])
      end;
      if callSite.targetSymbol.builtinKind = builtinWriteLn then
        appendIntrinsicCall(irIntrinsicWriteLn, makeTacNoneOperand, [])
    end
    else if callSite.targetSymbol.builtinKind in [builtinRead, builtinReadLn] then
    begin
      if callSite.firstArgument <> nil then
      begin
        readResult := newTacTemporary(hirScalarType(callSite.firstArgument^.valueType));
        appendIntrinsicCall(llirIntrinsicForReadType(hirScalarType(callSite.firstArgument^.valueType)),
                            readResult,
                            []);
        storeInstruction := newTacInstruction(irStoreVar);
        storeInstruction.resultOperand := storageOperandFromRef(callSite.firstArgument^.symbolInfo);
        storeInstruction.leftOperand := readResult;
        appendTacInstruction(storeInstruction)
      end;
      if callSite.targetSymbol.builtinKind = builtinReadLn then
        appendIntrinsicCall(irIntrinsicReadLn, makeTacNoneOperand, [])
    end;
    exit
  end;

  instruction := newTacInstruction(irCall);
  instruction.targetOperand := makeTacProcedureOperand(callSite.targetSymbol.symbol,
                                                       callSite.targetSymbol.name);
  if expectsResult then
    lowerCall := newTacTemporary(resultType);

  argumentIndex := 0;
  argumentNode := callSite.firstArgument;
  while argumentNode <> nil do
  begin
    argumentOperand := lowerExpression(argumentNode, errorCount);
    appendCallArgument(argumentIndex, argumentOperand);
    argumentIndex := argumentIndex + 1;
    argumentNode := argumentNode^.nextSibling
  end;

  appendTacInstruction(instruction);
  if lowerCall.kind <> irOperandNone then
  begin
    instruction := newTacInstruction(irResult);
    instruction.resultOperand := lowerCall;
    appendTacInstruction(instruction)
  end
end;

procedure lowerCallStatement(statementNode: hirStatement; var errorCount: integer);
begin
  lowerCall(statementNode^.callSite, typeInteger, false, errorCount)
end;

procedure lowerReturnStatement(statementNode: hirStatement; var errorCount: integer);
var
  valueOperand: llirOperand;
  instruction: llirInstruction;
begin
  valueOperand := makeTacNoneOperand;
  if statementNode^.valueExpression <> nil then
    valueOperand := lowerExpression(statementNode^.valueExpression, errorCount);

  if (currentLoweredFunctionSymbol <> 0) and (statementNode^.valueExpression <> nil) then
  begin
    instruction := newTacInstruction(irStoreVar);
    instruction.resultOperand := makeTacSymbolOperand(currentLoweredFunctionSymbol,
                                                      getDeclarationIdentifier(currentLoweredFunctionSymbol),
                                                      hirScalarType(statementNode^.valueExpression^.valueType));
    instruction.leftOperand := valueOperand;
    appendTacInstruction(instruction)
  end;

  instruction := newTacInstruction(irLeaveFrame);
  appendTacInstruction(instruction);
  instruction := newTacInstruction(irReturn);
  appendTacInstruction(instruction)
end;

procedure lowerIfStatement(statementNode: hirStatement; var errorCount: integer);
var
  conditionOperand: llirOperand;
  elseLabel, endLabel: llirLabelId;
begin
  conditionOperand := lowerExpression(statementNode^.conditionExpression, errorCount);
  elseLabel := newTacLabel;
  appendGotoIfZero(conditionOperand, elseLabel);
  lowerStatement(statementNode^.thenBody, errorCount);

  if statementNode^.elseBody <> nil then
  begin
    endLabel := newTacLabel;
    appendGoto(endLabel);
    appendLabel(elseLabel);
    lowerStatement(statementNode^.elseBody, errorCount);
    appendLabel(endLabel)
  end
  else
    appendLabel(elseLabel)
end;

procedure lowerWhileStatement(statementNode: hirStatement; var errorCount: integer);
var
  startLabel, exitLabel: llirLabelId;
  conditionOperand: llirOperand;
begin
  startLabel := newTacLabel;
  exitLabel := newTacLabel;
  appendLabel(startLabel);
  conditionOperand := lowerExpression(statementNode^.conditionExpression, errorCount);
  appendGotoIfZero(conditionOperand, exitLabel);
  pushLoopBreakLabel(exitLabel);
  pushLoopContinueLabel(startLabel);
  lowerStatement(statementNode^.body, errorCount);
  popLoopContinueLabel;
  popLoopBreakLabel;
  appendGoto(startLabel);
  appendLabel(exitLabel)
end;

procedure lowerRepeatStatement(statementNode: hirStatement; var errorCount: integer);
var
  startLabel, continueLabel, exitLabel: llirLabelId;
  conditionOperand: llirOperand;
begin
  startLabel := newTacLabel;
  continueLabel := newTacLabel;
  exitLabel := newTacLabel;
  appendLabel(startLabel);
  pushLoopBreakLabel(exitLabel);
  pushLoopContinueLabel(continueLabel);
  lowerStatement(statementNode^.body, errorCount);
  popLoopContinueLabel;
  appendLabel(continueLabel);
  conditionOperand := lowerExpression(statementNode^.conditionExpression, errorCount);
  popLoopBreakLabel;
  appendGotoIfZero(conditionOperand, startLabel);
  appendLabel(exitLabel)
end;

procedure lowerForStatement(statementNode: hirStatement; var errorCount: integer);
var
  counterOperand, startOperand, endOperand, stepOperand: llirOperand;
  comparisonOperand, incrementOperand: llirOperand;
  startLabel, continueLabel, exitLabel: llirLabelId;
  instruction: llirInstruction;
begin
  counterOperand := storageOperandFromRef(statementNode^.targetSymbol);
  startOperand := lowerExpression(statementNode^.startExpression, errorCount);
  instruction := newTacInstruction(irStoreVar);
  instruction.resultOperand := counterOperand;
  instruction.leftOperand := startOperand;
  appendTacInstruction(instruction);

  startLabel := newTacLabel;
  continueLabel := newTacLabel;
  exitLabel := newTacLabel;
  appendLabel(startLabel);

  endOperand := lowerExpression(statementNode^.endExpression, errorCount);
  comparisonOperand := newTacTemporary(typeBoolean);
  instruction := newTacInstruction(irCmpLe);
  instruction.resultOperand := comparisonOperand;
  instruction.leftOperand := loadSymbolValue(statementNode^.targetSymbol);
  instruction.rightOperand := endOperand;
  appendTacInstruction(instruction);
  appendGotoIfZero(comparisonOperand, exitLabel);

  pushLoopBreakLabel(exitLabel);
  pushLoopContinueLabel(continueLabel);
  lowerStatement(statementNode^.body, errorCount);
  popLoopContinueLabel;
  popLoopBreakLabel;
  appendLabel(continueLabel);

  stepOperand := lowerExpression(statementNode^.stepExpression, errorCount);
  incrementOperand := newTacTemporary(typeInteger);
  instruction := newTacInstruction(irAdd);
  instruction.resultOperand := incrementOperand;
  instruction.leftOperand := loadSymbolValue(statementNode^.targetSymbol);
  instruction.rightOperand := stepOperand;
  appendTacInstruction(instruction);

  instruction := newTacInstruction(irStoreVar);
  instruction.resultOperand := counterOperand;
  instruction.leftOperand := incrementOperand;
  appendTacInstruction(instruction);

  appendGoto(startLabel);
  appendLabel(exitLabel)
end;

procedure lowerSwitchStatement(statementNode: hirStatement; var errorCount: integer);
var
  selectorOperand, labelOperand, comparisonOperand: llirOperand;
  nextLabel, endLabel, defaultLabel: llirLabelId;
  bodyLabels: array [1..maxTacInstructions] of llirLabelId;
  bodyLabelCount: integer;
  instruction: llirInstruction;
  switchArmNode: hirSwitchArm;
  labelNode: hirSwitchLabel;
begin
  endLabel := newTacLabel;
  if statementNode^.elseBody <> nil then
    defaultLabel := newTacLabel
  else
    defaultLabel := endLabel;
  bodyLabelCount := 0;
  switchArmNode := statementNode^.firstSwitchArm;
  while switchArmNode <> nil do
  begin
    bodyLabelCount := bodyLabelCount + 1;
    bodyLabels[bodyLabelCount] := newTacLabel;
    labelNode := switchArmNode^.firstLabel;
    while labelNode <> nil do
    begin
      selectorOperand := lowerExpression(statementNode^.selectorExpression, errorCount);
      labelOperand := makeTacConstOperand(labelNode^.value,
                                          hirScalarType(labelNode^.valueType));
      comparisonOperand := newTacTemporary(typeBoolean);
      instruction := newTacInstruction(irCmpEq);
      instruction.resultOperand := comparisonOperand;
      instruction.leftOperand := selectorOperand;
      instruction.rightOperand := labelOperand;
      appendTacInstruction(instruction);

      nextLabel := newTacLabel;
      appendGotoIfZero(comparisonOperand, nextLabel);
      appendGoto(bodyLabels[bodyLabelCount]);
      appendLabel(nextLabel);
      labelNode := labelNode^.nextSibling
    end;
    switchArmNode := switchArmNode^.nextSibling
  end;

  appendGoto(defaultLabel);

  switchArmNode := statementNode^.firstSwitchArm;
  bodyLabelCount := 1;
  while switchArmNode <> nil do
  begin
    appendLabel(bodyLabels[bodyLabelCount]);
    bodyLabelCount := bodyLabelCount + 1;
    lowerStatement(switchArmNode^.body, errorCount);
    appendGoto(endLabel);
    switchArmNode := switchArmNode^.nextSibling
  end;

  if statementNode^.elseBody <> nil then
  begin
    appendLabel(defaultLabel);
    lowerStatement(statementNode^.elseBody, errorCount)
  end;

  appendLabel(endLabel)
end;

procedure lowerStatement(statementNode: hirStatement; var errorCount: integer);
var
  childNode: hirStatement;
begin
  if statementNode = nil then
    exit;

  case statementNode^.kind of
    hirStmtCompound:
      begin
        childNode := statementNode^.firstChild;
        while childNode <> nil do
        begin
          lowerStatement(childNode, errorCount);
          childNode := childNode^.nextSibling
        end
      end;
    hirStmtAssignment:
      lowerAssignmentStatement(statementNode, errorCount);
    hirStmtCall:
      lowerCallStatement(statementNode, errorCount);
    hirStmtReturn:
      lowerReturnStatement(statementNode, errorCount);
    hirStmtBreak:
      appendGoto(currentLoopBreakLabel);
    hirStmtContinue:
      appendGoto(currentLoopContinueLabel);
    hirStmtIf:
      lowerIfStatement(statementNode, errorCount);
    hirStmtWhile:
      lowerWhileStatement(statementNode, errorCount);
    hirStmtRepeat:
      lowerRepeatStatement(statementNode, errorCount);
    hirStmtFor:
      lowerForStatement(statementNode, errorCount);
    hirStmtSwitch:
      lowerSwitchStatement(statementNode, errorCount)
  end
end;

procedure lowerRoutineBody(routineNode: hirRoutine; var errorCount: integer);
begin
  if routineNode = nil then
    exit;

  lowerStatement(routineNode^.body, errorCount);
  appendProcedureLeaveAndReturn
end;

procedure lowerRoutineDeclaration(routineNode: hirRoutine; var errorCount: integer);
var
  procedureIndex: llirProcedureIndex;
begin
  if routineNode = nil then
    exit;

  procedureIndex := appendTacProcedure(routineNode^.name, routineNode^.symbol);
  describeRoutine(procedureIndex, routineNode);
  appendLabel(newTacLabel);
  appendProcedureEnter;
  if routineNode^.hasReturnValue then
    currentLoweredFunctionSymbol := routineNode^.symbol
  else
    currentLoweredFunctionSymbol := 0;
  lowerRoutineBody(routineNode, errorCount);
  currentLoweredFunctionSymbol := 0
end;

procedure generateLlirProgram(const programData: hirProgramRecord;
                              var errorCount: integer);
var
  procedureIndex: llirProcedureIndex;
  routineNode: hirRoutine;
begin
  initializeLlir;
  currentLoweredFunctionSymbol := 0;
  loopBreakLabelCount := 0;
  loopContinueLabelCount := 0;

  procedureIndex := appendTacProcedure(programData.name, 0);
  setTacProcedureReturnType(procedureIndex, typeInteger, false);
  recordProgramGlobalsAsLocals(programData, procedureIndex);
  appendLabel(newTacLabel);
  appendProcedureEnter;
  lowerRoutineBody(programData.entryRoutine, errorCount);

  routineNode := programData.firstRoutine;
  while routineNode <> nil do
  begin
    lowerRoutineDeclaration(routineNode, errorCount);
    routineNode := routineNode^.nextSibling
  end
end;

end.

