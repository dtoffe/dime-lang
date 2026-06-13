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
  llir, llirintrinsics, symboltable, typetable;

var
  currentLoweredFunctionSymbol: symbolIndex;
  loopBreakLabels: array [1..maxLlirInstructions] of llirLabelId;
  loopBreakLabelCount: integer;
  loopContinueLabels: array [1..maxLlirInstructions] of llirLabelId;
  loopContinueLabelCount: integer;

function hirScalarType(const typeRef: hirTypeRef): typeValue;
begin
  hirScalarType := typeRef.scalarType
end;

function symbolOperandFromRef(const symbolRef: hirSymbolRef): llirOperand;
begin
  if symbolRef.symbol = 0 then
    symbolOperandFromRef := makeLlirNoneOperand
  else
    symbolOperandFromRef := makeLlirSymbolOperand(symbolRef.symbol,
                                                 symbolRef.name,
                                                 hirScalarType(symbolRef.valueType))
end;

function storageOperandFromRef(const symbolRef: hirSymbolRef): llirOperand;
begin
  storageOperandFromRef := makeLlirNoneOperand;
  if symbolRef.symbol = 0 then
    exit;

  if not (getDeclarationKind(symbolRef.symbol) in [variable, func]) then
    exit;

  storageOperandFromRef := makeLlirSymbolOperand(symbolRef.symbol,
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
      addLlirProcedureLocal(procedureIndex, declarationNode^.symbolInfo.symbol);
    declarationNode := declarationNode^.nextSibling
  end
end;

procedure recordProgramGlobals(const programData: hirProgramRecord);
var
  declarationNode: hirDeclaration;
begin
  declarationNode := programData.firstGlobal;
  while declarationNode <> nil do
  begin
    if (declarationNode^.kind = hirDeclVariable) and
       (declarationNode^.symbolInfo.symbol <> 0) then
      addLlirGlobal(declarationNode^.symbolInfo.symbol);
    declarationNode := declarationNode^.nextSibling
  end
end;

procedure describeRoutine(procedureIndex: llirProcedureIndex; routineNode: hirRoutine);
var
  declarationNode: hirDeclaration;
begin
  if (routineNode = nil) or (procedureIndex = 0) then
    exit;

  setLlirProcedureReturnType(procedureIndex,
                            hirScalarType(routineNode^.returnType),
                            routineNode^.hasReturnValue);

  declarationNode := routineNode^.firstParameter;
  while declarationNode <> nil do
  begin
    if declarationNode^.symbolInfo.symbol <> 0 then
      addLlirProcedureParameter(procedureIndex, declarationNode^.symbolInfo.symbol);
    declarationNode := declarationNode^.nextSibling
  end;

  recordRoutineLocals(routineNode, procedureIndex)
end;

procedure appendLabel(labelId: llirLabelId);
begin
  appendLlirBasicBlock(labelId)
end;

procedure appendGoto(labelId: llirLabelId);
var
  instruction: llirInstruction;
begin
  instruction := newLlirInstruction(irJump);
  instruction.targetOperand := makeLlirLabelOperand(labelId);
  appendLlirInstruction(instruction)
end;

procedure appendGotoIfZero(const conditionOperand: llirOperand; labelId: llirLabelId);
var
  instruction: llirInstruction;
begin
  instruction := newLlirInstruction(irBranchFalse);
  instruction.leftOperand := conditionOperand;
  instruction.targetOperand := makeLlirLabelOperand(labelId);
  appendLlirInstruction(instruction)
end;

procedure appendProcedureReturn;
var
  instruction: llirInstruction;
begin
  instruction := newLlirInstruction(irReturn);
  appendLlirInstruction(instruction)
end;

function loadSymbolValue(const symbolRef: hirSymbolRef): llirOperand;
var
  instruction: llirInstruction;
begin
  loadSymbolValue := newLlirTemporary(hirScalarType(symbolRef.valueType));
  instruction := newLlirInstruction(irLoadVar);
  instruction.resultOperand := loadSymbolValue;
  instruction.leftOperand := symbolOperandFromRef(symbolRef);
  appendLlirInstruction(instruction)
end;

procedure appendIntrinsicCall(intrinsicKind: llirIntrinsicKind;
                              const resultOperand: llirOperand;
                              const argumentOperands: array of llirOperand);
var
  instruction: llirInstruction;
  argumentIndex: integer;
begin
  instruction := newLlirInstruction(irIntrinsicCall);
  instruction.resultOperand := resultOperand;
  instruction.targetOperand := makeLlirIntrinsicOperand(intrinsicKind);
  for argumentIndex := 0 to High(argumentOperands) do
    setLlirCallArgument(instruction, argumentIndex + 1, argumentOperands[argumentIndex]);
  appendLlirInstruction(instruction)
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
  lowerSymbolReference := makeLlirNoneOperand;
  if (expressionNode = nil) or (expressionNode^.symbolInfo.symbol = 0) then
    exit;

  resolvedSymbol := expressionNode^.symbolInfo.symbol;
  case getDeclarationKind(resolvedSymbol) of
    constant:
      begin
        lowerSymbolReference := newLlirTemporary(hirScalarType(expressionNode^.valueType));
        instruction := newLlirInstruction(irCopy);
        instruction.resultOperand := lowerSymbolReference;
        instruction.leftOperand := makeLlirConstOperand(getConstantValue(resolvedSymbol),
                                                        hirScalarType(expressionNode^.valueType));
        appendLlirInstruction(instruction)
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
  lowerLiteral := newLlirTemporary(hirScalarType(expressionNode^.valueType));
  instruction := newLlirInstruction(irCopy);
  instruction.resultOperand := lowerLiteral;
  instruction.leftOperand := makeLlirConstOperand(expressionNode^.literalValue,
                                                  hirScalarType(expressionNode^.valueType));
  appendLlirInstruction(instruction)
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
  lowerUnaryExpression := newLlirTemporary(hirScalarType(expressionNode^.valueType));
  if expressionNode^.unaryOperator = hirUnaryNegate then
    instruction := newLlirInstruction(irNeg)
  else
  begin
    instruction := newLlirInstruction(irCmpEq);
    zeroOperand := makeLlirConstOperand(0, hirScalarType(expressionNode^.operand^.valueType));
    instruction.rightOperand := zeroOperand
  end;
  instruction.resultOperand := lowerUnaryExpression;
  instruction.leftOperand := operand;
  appendLlirInstruction(instruction)
end;

function lowerBinaryExpression(expressionNode: hirExpression; var errorCount: integer): llirOperand;
var
  leftOperand, rightOperand: llirOperand;
  instruction: llirInstruction;
  sumOperand, oneOperand, zeroOperand: llirOperand;
begin
  leftOperand := lowerExpression(expressionNode^.leftOperand, errorCount);
  rightOperand := lowerExpression(expressionNode^.rightOperand, errorCount);
  lowerBinaryExpression := newLlirTemporary(hirScalarType(expressionNode^.valueType));

  if expressionNode^.binaryOperator in [hirBinaryAdd, hirBinarySub,
                                        hirBinaryMul, hirBinaryDiv] then
    instruction := newLlirInstruction(arithmeticOpcodeFor(expressionNode^.binaryOperator))
  else if expressionNode^.binaryOperator in [hirBinaryEq, hirBinaryNe, hirBinaryLt,
                                             hirBinaryLe, hirBinaryGt, hirBinaryGe] then
    instruction := newLlirInstruction(comparisonOpcodeFor(expressionNode^.binaryOperator))
  else if expressionNode^.binaryOperator = hirBinaryAnd then
    instruction := newLlirInstruction(irMul)
  else if expressionNode^.binaryOperator = hirBinaryOr then
  begin
    sumOperand := newLlirTemporary(typeInteger);
    instruction := newLlirInstruction(irAdd);
    instruction.resultOperand := sumOperand;
    instruction.leftOperand := leftOperand;
    instruction.rightOperand := rightOperand;
    appendLlirInstruction(instruction);

    zeroOperand := makeLlirConstOperand(0, typeInteger);
    instruction := newLlirInstruction(irCmpNe);
    instruction.resultOperand := lowerBinaryExpression;
    instruction.leftOperand := sumOperand;
    instruction.rightOperand := zeroOperand;
    appendLlirInstruction(instruction);
    exit
  end
  else if expressionNode^.binaryOperator = hirBinaryXor then
  begin
    sumOperand := newLlirTemporary(typeInteger);
    instruction := newLlirInstruction(irAdd);
    instruction.resultOperand := sumOperand;
    instruction.leftOperand := leftOperand;
    instruction.rightOperand := rightOperand;
    appendLlirInstruction(instruction);

    oneOperand := makeLlirConstOperand(1, typeInteger);
    instruction := newLlirInstruction(irCmpEq);
    instruction.resultOperand := lowerBinaryExpression;
    instruction.leftOperand := sumOperand;
    instruction.rightOperand := oneOperand;
    appendLlirInstruction(instruction);
    exit
  end
  else
    instruction := newLlirInstruction(irAdd);
  instruction.resultOperand := lowerBinaryExpression;
  instruction.leftOperand := leftOperand;
  instruction.rightOperand := rightOperand;
  appendLlirInstruction(instruction)
end;

function lowerCaseExpression(expressionNode: hirExpression; var errorCount: integer): llirOperand;
var
  selectorOperand, conditionOperand, whenOperand, branchOperand: llirOperand;
  resultOperand: llirOperand;
  nextLabel, endLabel: llirLabelId;
  instruction: llirInstruction;
  caseArmNode: hirCaseArm;
begin
  selectorOperand := makeLlirNoneOperand;
  if expressionNode^.caseMode = hirCaseSimple then
    selectorOperand := lowerExpression(expressionNode^.selectorExpression, errorCount);

  resultOperand := newLlirTemporary(hirScalarType(expressionNode^.valueType));
  endLabel := newLlirLabel;
  caseArmNode := expressionNode^.firstCaseArm;
  while caseArmNode <> nil do
  begin
    if expressionNode^.caseMode = hirCaseSimple then
    begin
      whenOperand := lowerExpression(caseArmNode^.whenExpression, errorCount);
      conditionOperand := newLlirTemporary(typeBoolean);
      instruction := newLlirInstruction(irCmpEq);
      instruction.resultOperand := conditionOperand;
      instruction.leftOperand := selectorOperand;
      instruction.rightOperand := whenOperand;
      appendLlirInstruction(instruction)
    end
    else
      conditionOperand := lowerExpression(caseArmNode^.whenExpression, errorCount);

    nextLabel := newLlirLabel;
    appendGotoIfZero(conditionOperand, nextLabel);
    branchOperand := lowerExpression(caseArmNode^.resultExpression, errorCount);
    instruction := newLlirInstruction(irCopy);
    instruction.resultOperand := resultOperand;
    instruction.leftOperand := branchOperand;
    appendLlirInstruction(instruction);
    appendGoto(endLabel);
    appendLabel(nextLabel);
    caseArmNode := caseArmNode^.nextSibling
  end;

  branchOperand := lowerExpression(expressionNode^.elseExpression, errorCount);
  instruction := newLlirInstruction(irCopy);
  instruction.resultOperand := resultOperand;
  instruction.leftOperand := branchOperand;
  appendLlirInstruction(instruction);
  appendLabel(endLabel);
  lowerCaseExpression := resultOperand
end;

function lowerExpression(expressionNode: hirExpression; var errorCount: integer): llirOperand;
begin
  lowerExpression := makeLlirNoneOperand;
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
  instruction := newLlirInstruction(irStoreVar);
  instruction.resultOperand := storageOperandFromRef(statementNode^.targetSymbol);
  instruction.leftOperand := valueOperand;
  appendLlirInstruction(instruction)
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
  lowerCall := makeLlirNoneOperand;

  if callSite.targetKind = hirCallBuiltin then
  begin
    if callSite.targetSymbol.builtinKind in [builtinWrite, builtinWriteLn] then
    begin
      if callSite.firstArgument <> nil then
      begin
        argumentOperand := lowerExpression(callSite.firstArgument, errorCount);
        appendIntrinsicCall(llirIntrinsicForWriteType(argumentOperand.valueType),
                            makeLlirNoneOperand,
                            [argumentOperand])
      end;
      if callSite.targetSymbol.builtinKind = builtinWriteLn then
        appendIntrinsicCall(irIntrinsicWriteLn, makeLlirNoneOperand, [])
    end
    else if callSite.targetSymbol.builtinKind in [builtinRead, builtinReadLn] then
    begin
      if callSite.firstArgument <> nil then
      begin
        readResult := newLlirTemporary(hirScalarType(callSite.firstArgument^.valueType));
        appendIntrinsicCall(llirIntrinsicForReadType(hirScalarType(callSite.firstArgument^.valueType)),
                            readResult,
                            []);
        storeInstruction := newLlirInstruction(irStoreVar);
        storeInstruction.resultOperand := storageOperandFromRef(callSite.firstArgument^.symbolInfo);
        storeInstruction.leftOperand := readResult;
        appendLlirInstruction(storeInstruction)
      end;
      if callSite.targetSymbol.builtinKind = builtinReadLn then
        appendIntrinsicCall(irIntrinsicReadLn, makeLlirNoneOperand, [])
    end;
    exit
  end;

  instruction := newLlirInstruction(irCall);
  instruction.targetOperand := makeLlirProcedureOperand(callSite.targetSymbol.symbol,
                                                        callSite.targetSymbol.name);
  if expectsResult then
  begin
    lowerCall := newLlirTemporary(resultType);
    instruction.resultOperand := lowerCall
  end;

  argumentIndex := 0;
  argumentNode := callSite.firstArgument;
  while argumentNode <> nil do
  begin
    argumentOperand := lowerExpression(argumentNode, errorCount);
    setLlirCallArgument(instruction, argumentIndex + 1, argumentOperand);
    argumentIndex := argumentIndex + 1;
    argumentNode := argumentNode^.nextSibling
  end;

  appendLlirInstruction(instruction)
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
  valueOperand := makeLlirNoneOperand;
  if statementNode^.valueExpression <> nil then
    valueOperand := lowerExpression(statementNode^.valueExpression, errorCount);

  if (currentLoweredFunctionSymbol <> 0) and (statementNode^.valueExpression <> nil) then
  begin
    instruction := newLlirInstruction(irStoreVar);
    instruction.resultOperand := makeLlirSymbolOperand(currentLoweredFunctionSymbol,
                                                       getDeclarationIdentifier(currentLoweredFunctionSymbol),
                                                       hirScalarType(statementNode^.valueExpression^.valueType));
    instruction.leftOperand := valueOperand;
    appendLlirInstruction(instruction)
  end;

  instruction := newLlirInstruction(irReturn);
  appendLlirInstruction(instruction)
end;

procedure lowerIfStatement(statementNode: hirStatement; var errorCount: integer);
var
  conditionOperand: llirOperand;
  elseLabel, endLabel: llirLabelId;
begin
  conditionOperand := lowerExpression(statementNode^.conditionExpression, errorCount);
  elseLabel := newLlirLabel;
  appendGotoIfZero(conditionOperand, elseLabel);
  lowerStatement(statementNode^.thenBody, errorCount);

  if statementNode^.elseBody <> nil then
  begin
    endLabel := newLlirLabel;
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
  startLabel := newLlirLabel;
  exitLabel := newLlirLabel;
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
  startLabel := newLlirLabel;
  continueLabel := newLlirLabel;
  exitLabel := newLlirLabel;
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
  instruction := newLlirInstruction(irStoreVar);
  instruction.resultOperand := counterOperand;
  instruction.leftOperand := startOperand;
  appendLlirInstruction(instruction);

  startLabel := newLlirLabel;
  continueLabel := newLlirLabel;
  exitLabel := newLlirLabel;
  appendLabel(startLabel);

  endOperand := lowerExpression(statementNode^.endExpression, errorCount);
  comparisonOperand := newLlirTemporary(typeBoolean);
  instruction := newLlirInstruction(irCmpLe);
  instruction.resultOperand := comparisonOperand;
  instruction.leftOperand := loadSymbolValue(statementNode^.targetSymbol);
  instruction.rightOperand := endOperand;
  appendLlirInstruction(instruction);
  appendGotoIfZero(comparisonOperand, exitLabel);

  pushLoopBreakLabel(exitLabel);
  pushLoopContinueLabel(continueLabel);
  lowerStatement(statementNode^.body, errorCount);
  popLoopContinueLabel;
  popLoopBreakLabel;
  appendLabel(continueLabel);

  stepOperand := lowerExpression(statementNode^.stepExpression, errorCount);
  incrementOperand := newLlirTemporary(typeInteger);
  instruction := newLlirInstruction(irAdd);
  instruction.resultOperand := incrementOperand;
  instruction.leftOperand := loadSymbolValue(statementNode^.targetSymbol);
  instruction.rightOperand := stepOperand;
  appendLlirInstruction(instruction);

  instruction := newLlirInstruction(irStoreVar);
  instruction.resultOperand := counterOperand;
  instruction.leftOperand := incrementOperand;
  appendLlirInstruction(instruction);

  appendGoto(startLabel);
  appendLabel(exitLabel)
end;

procedure lowerSwitchStatement(statementNode: hirStatement; var errorCount: integer);
var
  selectorOperand, labelOperand, comparisonOperand: llirOperand;
  nextLabel, endLabel, defaultLabel: llirLabelId;
  bodyLabels: array [1..maxLlirInstructions] of llirLabelId;
  bodyLabelCount: integer;
  instruction: llirInstruction;
  switchArmNode: hirSwitchArm;
  labelNode: hirSwitchLabel;
begin
  endLabel := newLlirLabel;
  if statementNode^.elseBody <> nil then
    defaultLabel := newLlirLabel
  else
    defaultLabel := endLabel;
  bodyLabelCount := 0;
  switchArmNode := statementNode^.firstSwitchArm;
  while switchArmNode <> nil do
  begin
    bodyLabelCount := bodyLabelCount + 1;
    bodyLabels[bodyLabelCount] := newLlirLabel;
    labelNode := switchArmNode^.firstLabel;
    while labelNode <> nil do
    begin
      selectorOperand := lowerExpression(statementNode^.selectorExpression, errorCount);
      labelOperand := makeLlirConstOperand(labelNode^.value,
                                           hirScalarType(labelNode^.valueType));
      comparisonOperand := newLlirTemporary(typeBoolean);
      instruction := newLlirInstruction(irCmpEq);
      instruction.resultOperand := comparisonOperand;
      instruction.leftOperand := selectorOperand;
      instruction.rightOperand := labelOperand;
      appendLlirInstruction(instruction);

      nextLabel := newLlirLabel;
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
  appendProcedureReturn
end;

procedure lowerRoutineDeclaration(routineNode: hirRoutine; var errorCount: integer);
var
  procedureIndex: llirProcedureIndex;
begin
  if routineNode = nil then
    exit;

  procedureIndex := appendLlirProcedure(routineNode^.name, routineNode^.symbol);
  describeRoutine(procedureIndex, routineNode);
  appendLabel(newLlirLabel);
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

  recordProgramGlobals(programData);
  procedureIndex := appendLlirProcedure(programData.name, 0);
  setLlirProcedureReturnType(procedureIndex, typeInteger, false);
  appendLabel(newLlirLabel);
  lowerRoutineBody(programData.entryRoutine, errorCount);

  routineNode := programData.firstRoutine;
  while routineNode <> nil do
  begin
    lowerRoutineDeclaration(routineNode, errorCount);
    routineNode := routineNode^.nextSibling
  end
end;

end.

