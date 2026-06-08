{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-06-07

  High-level IR definitions for the structured frontend pipeline.

  This unit defines the core data model for a typed, statement-oriented IR that
  matches the language surface currently accepted by parser.pas and
  semantics.pas.  AST-to-HLIR lowering now lives in asttohlir.pas, while
  validation passes and lowering to TAC/LIR remain future work.

  The design goal is to keep frontend intent explicit:
  - procedures/functions remain structured routines
  - statements remain statement-shaped
  - expressions remain typed and source-like
  - built-ins remain explicit call targets instead of backend magic

  Known gaps and next steps:
  - Current concrete type modeling only covers integer, boolean, and char.
    Strings, arrays, records, sets, enums, and subranges should extend
    hirTypeRef before HLIR becomes the default frontend output.
  - Assignment targets are currently modeled as direct symbol-backed lvalues.
    Field access, indexing, dereference, and by-reference parameter access
    will need a richer lvalue/access-path model.
  - There is no control-flow graph here by design.  HLIR should stay structured
    and lower into block-based LIR/TAC later.
  - Calls keep builtin/read/write identity at the HLIR level.  Intrinsic and
    calling-convention lowering should happen below this layer.
  - Memory ownership helpers are intentionally absent for now.  As HLIR becomes
    a longer-lived compiler stage, this layer will likely need constructors/free
    routines similar in spirit to astree.pas. }
unit hlir;

{$mode objfpc}

interface

uses
  diagnostics, tokens, typetable, symboltable;

type
  hirProgram = ^hirProgramRecord;
  hirRoutine = ^hirRoutineRecord;
  hirDeclaration = ^hirDeclarationRecord;
  hirStatement = ^hirStatementRecord;
  hirExpression = ^hirExpressionRecord;
  hirSwitchArm = ^hirSwitchArmRecord;
  hirSwitchLabel = ^hirSwitchLabelRecord;
  hirCaseArm = ^hirCaseArmRecord;

  hirRoutineKind = (hirRoutineProgram, hirRoutineProcedure, hirRoutineFunction);
  hirDeclarationKind = (hirDeclConstant, hirDeclVariable, hirDeclParameter);
  hirCallTargetKind = (hirCallUserRoutine, hirCallBuiltin);
  hirCaseMode = (hirCaseSimple, hirCaseSearched);

  hirStatementKind = (
    hirStmtCompound,
    hirStmtAssignment,
    hirStmtCall,
    hirStmtReturn,
    hirStmtBreak,
    hirStmtContinue,
    hirStmtIf,
    hirStmtWhile,
    hirStmtRepeat,
    hirStmtFor,
    hirStmtSwitch
  );

  hirExpressionKind = (
    hirExprIntegerLiteral,
    hirExprBooleanLiteral,
    hirExprCharLiteral,
    hirExprSymbol,
    hirExprUnary,
    hirExprBinary,
    hirExprCall,
    hirExprCase
  );

  hirUnaryOperator = (
    hirUnaryNegate,
    hirUnaryNot
  );

  hirBinaryOperator = (
    hirBinaryAdd,
    hirBinarySub,
    hirBinaryMul,
    hirBinaryDiv,
    hirBinaryEq,
    hirBinaryNe,
    hirBinaryLt,
    hirBinaryLe,
    hirBinaryGt,
    hirBinaryGe,
    hirBinaryAnd,
    hirBinaryOr,
    hirBinaryXor
  );

  { hirTypeRef intentionally starts simple.  The current language has only
    builtin scalar types, but the record leaves room for future user-defined
    type identity without forcing LIR/backend concerns into the frontend IR. }
  hirTypeRef = record
    scalarType: typeValue;
    userTypeName: identifier;
    hasUserDefinedName: boolean
  end;

  { Symbol references keep the semantic binding visible in HLIR.  Builtin
    routines use builtinKind when declarationKind = proc. }
  hirSymbolRef = record
    symbol: symbolIndex;
    name: identifier;
    declarationKind: declarationKind;
    builtinKind: builtinProcedure;
    valueType: hirTypeRef
  end;

  hirState = record
    nextRoutineId: integer;
    nextDeclarationId: integer;
    nextStatementId: integer;
    nextExpressionId: integer;
    nextSwitchArmId: integer;
    nextCaseArmId: integer
  end;

  hirDeclarationRecord = record
    id: integer;
    kind: hirDeclarationKind;
    source: sourceContext;
    symbolInfo: hirSymbolRef;
    constantValue: integer;
    nextSibling: hirDeclaration
  end;

  { Calls are shared by call-statements and call-expressions.  For the current
    grammar the target is always an identifier-resolved routine/builtin, not an
    arbitrary expression. }
  hirCallSite = record
    targetKind: hirCallTargetKind;
    targetSymbol: hirSymbolRef;
    firstArgument: hirExpression;
    lastArgument: hirExpression;
    argumentCount: integer
  end;

  hirSwitchLabelRecord = record
    source: sourceContext;
    valueType: hirTypeRef;
    value: integer;
    nextSibling: hirSwitchLabel
  end;

  hirSwitchArmRecord = record
    id: integer;
    source: sourceContext;
    firstLabel: hirSwitchLabel;
    lastLabel: hirSwitchLabel;
    labelCount: integer;
    body: hirStatement;
    nextSibling: hirSwitchArm
  end;

  hirCaseArmRecord = record
    id: integer;
    source: sourceContext;
    whenExpression: hirExpression;
    resultExpression: hirExpression;
    nextSibling: hirCaseArm
  end;

  hirExpressionRecord = record
    id: integer;
    kind: hirExpressionKind;
    source: sourceContext;
    valueType: hirTypeRef;
    nextSibling: hirExpression;

    { Literal payloads reuse integer storage:
      - integer literal: raw integer value
      - boolean literal: 0 or 1
      - char literal: Ord(character) }
    literalValue: integer;

    symbolInfo: hirSymbolRef;
    unaryOperator: hirUnaryOperator;
    binaryOperator: hirBinaryOperator;

    operand: hirExpression;
    leftOperand: hirExpression;
    rightOperand: hirExpression;

    callSite: hirCallSite;

    caseMode: hirCaseMode;
    selectorExpression: hirExpression;
    firstCaseArm: hirCaseArm;
    lastCaseArm: hirCaseArm;
    elseExpression: hirExpression
  end;

  { Statements keep explicit structured shape rather than flattening into
    blocks or jumps.  Several fields are only meaningful for specific kinds:
    - hirStmtAssignment: targetSymbol + valueExpression
    - hirStmtCall: callSite
    - hirStmtReturn: valueExpression
    - hirStmtIf: conditionExpression + thenBody + elseBody
    - hirStmtWhile: conditionExpression + body
    - hirStmtRepeat: body + conditionExpression
    - hirStmtFor: targetSymbol + start/end/step expressions + body
    - hirStmtSwitch: selectorExpression + switch arms + elseBody
    - hirStmtCompound: firstChild/lastChild }
  hirStatementRecord = record
    id: integer;
    kind: hirStatementKind;
    source: sourceContext;
    nextSibling: hirStatement;

    firstChild: hirStatement;
    lastChild: hirStatement;

    targetSymbol: hirSymbolRef;
    callSite: hirCallSite;

    conditionExpression: hirExpression;
    valueExpression: hirExpression;
    startExpression: hirExpression;
    endExpression: hirExpression;
    stepExpression: hirExpression;
    selectorExpression: hirExpression;

    body: hirStatement;
    thenBody: hirStatement;
    elseBody: hirStatement;

    firstSwitchArm: hirSwitchArm;
    lastSwitchArm: hirSwitchArm
  end;

  hirRoutineRecord = record
    id: integer;
    kind: hirRoutineKind;
    source: sourceContext;
    name: identifier;
    symbol: symbolIndex;
    returnType: hirTypeRef;
    hasReturnValue: boolean;

    firstParameter: hirDeclaration;
    lastParameter: hirDeclaration;
    parameterCount: integer;

    firstLocal: hirDeclaration;
    lastLocal: hirDeclaration;
    localCount: integer;

    body: hirStatement;
    nextSibling: hirRoutine
  end;

  hirProgramRecord = record
    source: sourceContext;
    name: identifier;
    symbol: symbolIndex;
    state: hirState;

    firstGlobal: hirDeclaration;
    lastGlobal: hirDeclaration;
    globalCount: integer;

    firstRoutine: hirRoutine;
    lastRoutine: hirRoutine;
    routineCount: integer;

    entryRoutine: hirRoutine
  end;

procedure initializeHirState(var state: hirState);
procedure initializeHirProgram(var programData: hirProgramRecord);

function makeHirTypeRef(scalarType: typeValue): hirTypeRef;
function makeHirSymbolRef(symbol: symbolIndex;
                          const name: identifier;
                          declaredKind: declarationKind;
                          valueType: typeValue): hirSymbolRef;

function hirCaseModeFromSymbol(caseModeSymbol: symbol; out mode: hirCaseMode): boolean;
function hirUnaryOperatorFromSymbol(operatorSymbol: symbol; out op: hirUnaryOperator): boolean;
function hirBinaryOperatorFromSymbol(operatorSymbol: symbol; out op: hirBinaryOperator): boolean;

implementation

procedure initializeHirState(var state: hirState);
begin
  FillChar(state, SizeOf(state), 0)
end;

procedure initializeHirProgram(var programData: hirProgramRecord);
begin
  FillChar(programData, SizeOf(programData), 0);
  initializeHirState(programData.state)
end;

function makeHirTypeRef(scalarType: typeValue): hirTypeRef;
begin
  FillChar(makeHirTypeRef, SizeOf(makeHirTypeRef), 0);
  makeHirTypeRef.scalarType := scalarType
end;

function makeHirSymbolRef(symbol: symbolIndex;
                          const name: identifier;
                          declaredKind: declarationKind;
                          valueType: typeValue): hirSymbolRef;
begin
  FillChar(makeHirSymbolRef, SizeOf(makeHirSymbolRef), 0);
  makeHirSymbolRef.symbol := symbol;
  makeHirSymbolRef.name := name;
  makeHirSymbolRef.declarationKind := declaredKind;
  makeHirSymbolRef.builtinKind := builtinNone;
  if symbol <> 0 then
    makeHirSymbolRef.builtinKind := getBuiltinProcedure(symbol);
  makeHirSymbolRef.valueType := makeHirTypeRef(valueType)
end;

function hirCaseModeFromSymbol(caseModeSymbol: symbol; out mode: hirCaseMode): boolean;
begin
  hirCaseModeFromSymbol := true;
  if caseModeSymbol = casesym then
    mode := hirCaseSimple
  else if caseModeSymbol = whensym then
    mode := hirCaseSearched
  else
    hirCaseModeFromSymbol := false
end;

function hirUnaryOperatorFromSymbol(operatorSymbol: symbol; out op: hirUnaryOperator): boolean;
begin
  hirUnaryOperatorFromSymbol := true;
  if operatorSymbol = minus then
    op := hirUnaryNegate
  else if operatorSymbol = notsym then
    op := hirUnaryNot
  else
    hirUnaryOperatorFromSymbol := false
end;

function hirBinaryOperatorFromSymbol(operatorSymbol: symbol; out op: hirBinaryOperator): boolean;
begin
  hirBinaryOperatorFromSymbol := true;
  case operatorSymbol of
    plus:
      op := hirBinaryAdd;
    minus:
      op := hirBinarySub;
    times:
      op := hirBinaryMul;
    slash:
      op := hirBinaryDiv;
    eql:
      op := hirBinaryEq;
    neq:
      op := hirBinaryNe;
    lss:
      op := hirBinaryLt;
    leq:
      op := hirBinaryLe;
    gtr:
      op := hirBinaryGt;
    geq:
      op := hirBinaryGe;
    andsym:
      op := hirBinaryAnd;
    orsym:
      op := hirBinaryOr;
    xorsym:
      op := hirBinaryXor
  else
    hirBinaryOperatorFromSymbol := false
  end
end;

end.
