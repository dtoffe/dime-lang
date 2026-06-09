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
procedure dumpHir(const outputFileName: string; const programData: hirProgramRecord);

function makeHirTypeRef(scalarType: typeValue): hirTypeRef;
function makeHirSymbolRef(symbol: symbolIndex;
                          const name: identifier;
                          declaredKind: declarationKind;
                          valueType: typeValue): hirSymbolRef;

function hirCaseModeFromSymbol(caseModeSymbol: symbol; out mode: hirCaseMode): boolean;
function hirUnaryOperatorFromSymbol(operatorSymbol: symbol; out op: hirUnaryOperator): boolean;
function hirBinaryOperatorFromSymbol(operatorSymbol: symbol; out op: hirBinaryOperator): boolean;

implementation

uses
  SysUtils;

function identifierToString(const identifierName: identifier): string;
var
  characterIndex: integer;
begin
  identifierToString := '';
  for characterIndex := Low(identifierName) to High(identifierName) do
    identifierToString := identifierToString + identifierName[characterIndex];
  identifierToString := TrimRight(identifierToString)
end;

function hirTypeToString(const typeRef: hirTypeRef): string;
begin
  if typeRef.hasUserDefinedName then
    hirTypeToString := identifierToString(typeRef.userTypeName)
  else
    case typeRef.scalarType of
      typeInteger:
        hirTypeToString := 'integer';
      typeBoolean:
        hirTypeToString := 'boolean';
    else
      hirTypeToString := 'char'
    end
end;

function hirRoutineKindToString(kind: hirRoutineKind): string;
begin
  case kind of
    hirRoutineProgram:
      hirRoutineKindToString := 'program';
    hirRoutineProcedure:
      hirRoutineKindToString := 'procedure';
  else
    hirRoutineKindToString := 'function'
  end
end;

function hirDeclarationKindToString(kind: hirDeclarationKind): string;
begin
  case kind of
    hirDeclConstant:
      hirDeclarationKindToString := 'const';
    hirDeclVariable:
      hirDeclarationKindToString := 'var';
  else
    hirDeclarationKindToString := 'param'
  end
end;

function hirStatementKindToString(kind: hirStatementKind): string;
begin
  case kind of
    hirStmtCompound:
      hirStatementKindToString := 'compound';
    hirStmtAssignment:
      hirStatementKindToString := 'assign';
    hirStmtCall:
      hirStatementKindToString := 'call';
    hirStmtReturn:
      hirStatementKindToString := 'return';
    hirStmtBreak:
      hirStatementKindToString := 'break';
    hirStmtContinue:
      hirStatementKindToString := 'continue';
    hirStmtIf:
      hirStatementKindToString := 'if';
    hirStmtWhile:
      hirStatementKindToString := 'while';
    hirStmtRepeat:
      hirStatementKindToString := 'repeat';
    hirStmtFor:
      hirStatementKindToString := 'for';
  else
    hirStatementKindToString := 'switch'
  end
end;

function hirExpressionKindToString(kind: hirExpressionKind): string;
begin
  case kind of
    hirExprIntegerLiteral:
      hirExpressionKindToString := 'int_lit';
    hirExprBooleanLiteral:
      hirExpressionKindToString := 'bool_lit';
    hirExprCharLiteral:
      hirExpressionKindToString := 'char_lit';
    hirExprSymbol:
      hirExpressionKindToString := 'symbol';
    hirExprUnary:
      hirExpressionKindToString := 'unary';
    hirExprBinary:
      hirExpressionKindToString := 'binary';
    hirExprCall:
      hirExpressionKindToString := 'call';
  else
    hirExpressionKindToString := 'case'
  end
end;

function hirUnaryOperatorToString(op: hirUnaryOperator): string;
begin
  case op of
    hirUnaryNegate:
      hirUnaryOperatorToString := 'neg';
  else
    hirUnaryOperatorToString := 'not'
  end
end;

function hirBinaryOperatorToString(op: hirBinaryOperator): string;
begin
  case op of
    hirBinaryAdd:
      hirBinaryOperatorToString := 'add';
    hirBinarySub:
      hirBinaryOperatorToString := 'sub';
    hirBinaryMul:
      hirBinaryOperatorToString := 'mul';
    hirBinaryDiv:
      hirBinaryOperatorToString := 'div';
    hirBinaryEq:
      hirBinaryOperatorToString := 'eq';
    hirBinaryNe:
      hirBinaryOperatorToString := 'ne';
    hirBinaryLt:
      hirBinaryOperatorToString := 'lt';
    hirBinaryLe:
      hirBinaryOperatorToString := 'le';
    hirBinaryGt:
      hirBinaryOperatorToString := 'gt';
    hirBinaryGe:
      hirBinaryOperatorToString := 'ge';
    hirBinaryAnd:
      hirBinaryOperatorToString := 'and';
    hirBinaryOr:
      hirBinaryOperatorToString := 'or';
  else
    hirBinaryOperatorToString := 'xor'
  end
end;

function hirCaseModeToString(mode: hirCaseMode): string;
begin
  case mode of
    hirCaseSimple:
      hirCaseModeToString := 'simple';
  else
    hirCaseModeToString := 'searched'
  end
end;

function hirSymbolRefToString(const symbolRef: hirSymbolRef): string;
begin
  hirSymbolRefToString := identifierToString(symbolRef.name) +
                          '#' + IntToStr(symbolRef.symbol) +
                          ':' + hirTypeToString(symbolRef.valueType);
  if symbolRef.builtinKind <> builtinNone then
    hirSymbolRefToString := hirSymbolRefToString +
                            ' builtin=' + builtinProcedureName(symbolRef.builtinKind)
end;

function indentString(depth: integer): string;
begin
  indentString := StringOfChar(' ', depth * 2)
end;

procedure dumpExpression(var outputFile: Text; expressionNode: hirExpression; depth: integer); forward;

procedure dumpCallSite(var outputFile: Text; const prefix: string;
                       const callSite: hirCallSite; depth: integer);
var
  argumentNode: hirExpression;
  argumentIndex: integer;
begin
  if callSite.targetKind = hirCallBuiltin then
    writeln(outputFile, indentString(depth), prefix,
            ' builtin target=', hirSymbolRefToString(callSite.targetSymbol),
            ' argc=', callSite.argumentCount)
  else
    writeln(outputFile, indentString(depth), prefix,
            ' target=', hirSymbolRefToString(callSite.targetSymbol),
            ' argc=', callSite.argumentCount);

  argumentNode := callSite.firstArgument;
  argumentIndex := 0;
  while argumentNode <> nil do
  begin
    writeln(outputFile, indentString(depth + 1), 'arg ', argumentIndex);
    dumpExpression(outputFile, argumentNode, depth + 2);
    argumentNode := argumentNode^.nextSibling;
    argumentIndex := argumentIndex + 1
  end
end;

procedure dumpCaseArm(var outputFile: Text; caseArmNode: hirCaseArm; depth: integer);
begin
  while caseArmNode <> nil do
  begin
    writeln(outputFile, indentString(depth), 'casearm ', caseArmNode^.id);
    writeln(outputFile, indentString(depth + 1), 'when');
    dumpExpression(outputFile, caseArmNode^.whenExpression, depth + 2);
    writeln(outputFile, indentString(depth + 1), 'result');
    dumpExpression(outputFile, caseArmNode^.resultExpression, depth + 2);
    caseArmNode := caseArmNode^.nextSibling
  end
end;

procedure dumpExpression(var outputFile: Text; expressionNode: hirExpression; depth: integer);
begin
  if expressionNode = nil then
  begin
    writeln(outputFile, indentString(depth), 'expr <nil>');
    exit
  end;

  write(outputFile, indentString(depth), 'expr ', expressionNode^.id,
        ' ', hirExpressionKindToString(expressionNode^.kind),
        ' type=', hirTypeToString(expressionNode^.valueType));
  case expressionNode^.kind of
    hirExprIntegerLiteral,
    hirExprBooleanLiteral,
    hirExprCharLiteral:
      writeln(outputFile, ' value=', expressionNode^.literalValue);
    hirExprSymbol:
      writeln(outputFile, ' symbol=', hirSymbolRefToString(expressionNode^.symbolInfo));
    hirExprUnary:
      begin
        writeln(outputFile, ' op=', hirUnaryOperatorToString(expressionNode^.unaryOperator));
        dumpExpression(outputFile, expressionNode^.operand, depth + 1)
      end;
    hirExprBinary:
      begin
        writeln(outputFile, ' op=', hirBinaryOperatorToString(expressionNode^.binaryOperator));
        dumpExpression(outputFile, expressionNode^.leftOperand, depth + 1);
        dumpExpression(outputFile, expressionNode^.rightOperand, depth + 1)
      end;
    hirExprCall:
      begin
        writeln(outputFile);
        dumpCallSite(outputFile, 'call', expressionNode^.callSite, depth + 1)
      end;
    hirExprCase:
      begin
        writeln(outputFile, ' mode=', hirCaseModeToString(expressionNode^.caseMode));
        if expressionNode^.selectorExpression <> nil then
        begin
          writeln(outputFile, indentString(depth + 1), 'selector');
          dumpExpression(outputFile, expressionNode^.selectorExpression, depth + 2)
        end;
        dumpCaseArm(outputFile, expressionNode^.firstCaseArm, depth + 1);
        writeln(outputFile, indentString(depth + 1), 'else');
        dumpExpression(outputFile, expressionNode^.elseExpression, depth + 2)
      end
  end
end;

procedure dumpSwitchLabels(var outputFile: Text; labelNode: hirSwitchLabel; depth: integer);
begin
  while labelNode <> nil do
  begin
    writeln(outputFile, indentString(depth), 'label value=', labelNode^.value,
            ' type=', hirTypeToString(labelNode^.valueType));
    labelNode := labelNode^.nextSibling
  end
end;

procedure dumpStatement(var outputFile: Text; statementNode: hirStatement; depth: integer); forward;

procedure dumpSwitchArms(var outputFile: Text; armNode: hirSwitchArm; depth: integer);
begin
  while armNode <> nil do
  begin
    writeln(outputFile, indentString(depth), 'arm ', armNode^.id,
            ' labels=', armNode^.labelCount);
    dumpSwitchLabels(outputFile, armNode^.firstLabel, depth + 1);
    writeln(outputFile, indentString(depth + 1), 'body');
    dumpStatement(outputFile, armNode^.body, depth + 2);
    armNode := armNode^.nextSibling
  end
end;

procedure dumpStatement(var outputFile: Text; statementNode: hirStatement; depth: integer);
var
  childNode: hirStatement;
begin
  if statementNode = nil then
  begin
    writeln(outputFile, indentString(depth), 'stmt <nil>');
    exit
  end;

  writeln(outputFile, indentString(depth), 'stmt ', statementNode^.id,
          ' ', hirStatementKindToString(statementNode^.kind));
  case statementNode^.kind of
    hirStmtCompound:
      begin
        childNode := statementNode^.firstChild;
        while childNode <> nil do
        begin
          dumpStatement(outputFile, childNode, depth + 1);
          childNode := childNode^.nextSibling
        end
      end;
    hirStmtAssignment:
      begin
        writeln(outputFile, indentString(depth + 1), 'target ',
                hirSymbolRefToString(statementNode^.targetSymbol));
        writeln(outputFile, indentString(depth + 1), 'value');
        dumpExpression(outputFile, statementNode^.valueExpression, depth + 2)
      end;
    hirStmtCall:
      dumpCallSite(outputFile, 'call', statementNode^.callSite, depth + 1);
    hirStmtReturn:
      dumpExpression(outputFile, statementNode^.valueExpression, depth + 1);
    hirStmtIf:
      begin
        writeln(outputFile, indentString(depth + 1), 'condition');
        dumpExpression(outputFile, statementNode^.conditionExpression, depth + 2);
        writeln(outputFile, indentString(depth + 1), 'then');
        dumpStatement(outputFile, statementNode^.thenBody, depth + 2);
        if statementNode^.elseBody <> nil then
        begin
          writeln(outputFile, indentString(depth + 1), 'else');
          dumpStatement(outputFile, statementNode^.elseBody, depth + 2)
        end
      end;
    hirStmtWhile:
      begin
        writeln(outputFile, indentString(depth + 1), 'condition');
        dumpExpression(outputFile, statementNode^.conditionExpression, depth + 2);
        writeln(outputFile, indentString(depth + 1), 'body');
        dumpStatement(outputFile, statementNode^.body, depth + 2)
      end;
    hirStmtRepeat:
      begin
        writeln(outputFile, indentString(depth + 1), 'body');
        dumpStatement(outputFile, statementNode^.body, depth + 2);
        writeln(outputFile, indentString(depth + 1), 'until');
        dumpExpression(outputFile, statementNode^.conditionExpression, depth + 2)
      end;
    hirStmtFor:
      begin
        writeln(outputFile, indentString(depth + 1), 'counter ',
                hirSymbolRefToString(statementNode^.targetSymbol));
        writeln(outputFile, indentString(depth + 1), 'start');
        dumpExpression(outputFile, statementNode^.startExpression, depth + 2);
        writeln(outputFile, indentString(depth + 1), 'end');
        dumpExpression(outputFile, statementNode^.endExpression, depth + 2);
        writeln(outputFile, indentString(depth + 1), 'step');
        dumpExpression(outputFile, statementNode^.stepExpression, depth + 2);
        writeln(outputFile, indentString(depth + 1), 'body');
        dumpStatement(outputFile, statementNode^.body, depth + 2)
      end;
    hirStmtSwitch:
      begin
        writeln(outputFile, indentString(depth + 1), 'selector');
        dumpExpression(outputFile, statementNode^.selectorExpression, depth + 2);
        dumpSwitchArms(outputFile, statementNode^.firstSwitchArm, depth + 1);
        if statementNode^.elseBody <> nil then
        begin
          writeln(outputFile, indentString(depth + 1), 'else');
          dumpStatement(outputFile, statementNode^.elseBody, depth + 2)
        end
      end
  end
end;

procedure dumpDeclarations(var outputFile: Text; declarationNode: hirDeclaration; depth: integer);
begin
  while declarationNode <> nil do
  begin
    write(outputFile, indentString(depth), 'decl ', declarationNode^.id,
          ' ', hirDeclarationKindToString(declarationNode^.kind),
          ' ', hirSymbolRefToString(declarationNode^.symbolInfo));
    if declarationNode^.kind = hirDeclConstant then
      writeln(outputFile, ' value=', declarationNode^.constantValue)
    else
      writeln(outputFile);
    declarationNode := declarationNode^.nextSibling
  end
end;

procedure dumpRoutine(var outputFile: Text; routineNode: hirRoutine; depth: integer);
begin
  while routineNode <> nil do
  begin
    writeln(outputFile, indentString(depth), 'routine ', routineNode^.id,
            ' ', hirRoutineKindToString(routineNode^.kind),
            ' ', identifierToString(routineNode^.name),
            ' symbol=', routineNode^.symbol,
            ' return=', hirTypeToString(routineNode^.returnType),
            ' params=', routineNode^.parameterCount,
            ' locals=', routineNode^.localCount);
    if routineNode^.firstParameter <> nil then
    begin
      writeln(outputFile, indentString(depth + 1), 'parameters');
      dumpDeclarations(outputFile, routineNode^.firstParameter, depth + 2)
    end;
    if routineNode^.firstLocal <> nil then
    begin
      writeln(outputFile, indentString(depth + 1), 'locals');
      dumpDeclarations(outputFile, routineNode^.firstLocal, depth + 2)
    end;
    writeln(outputFile, indentString(depth + 1), 'body');
    dumpStatement(outputFile, routineNode^.body, depth + 2);
    routineNode := routineNode^.nextSibling
  end
end;

procedure dumpHir(const outputFileName: string; const programData: hirProgramRecord);
var
  outputFile: Text;
begin
  Assign(outputFile, outputFileName);
  Rewrite(outputFile);
  writeln(outputFile, 'hlir program ', identifierToString(programData.name),
          ' symbol=', programData.symbol,
          ' globals=', programData.globalCount,
          ' routines=', programData.routineCount,
          ' entry=', programData.entryRoutine <> nil);
  if programData.firstGlobal <> nil then
  begin
    writeln(outputFile, 'globals');
    dumpDeclarations(outputFile, programData.firstGlobal, 1)
  end;
  writeln(outputFile, 'entry');
  dumpRoutine(outputFile, programData.entryRoutine, 1);
  if programData.firstRoutine <> nil then
  begin
    writeln(outputFile, 'routines');
    dumpRoutine(outputFile, programData.firstRoutine, 1)
  end;
  Close(outputFile)
end;

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
