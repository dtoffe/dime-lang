{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-22

  P-code generation support for the compiler pipeline.  This unit owns instruction
  types, opcode mnemonics, the generated program image, emit/patch helpers,
  trace listing, and final program-image output.  It does not parse source
  text or perform semantic checks. }
unit pcode;

{$mode objfpc}

interface

uses
  astree;

procedure initializePCode(const outputFileName: string);
procedure cleanupPCode;
procedure generatePCodeProgram(rootNode: astNode; var errorCount: integer);
procedure traceGeneratedPCode(blockStartIndex: integer);
procedure writePCodeImage;

implementation

uses
  SysUtils, diagnostics, semantics, symboltable, tokens, typetable;

const
  codeMaxIndex = 200;        {maximum code array index}
  maxEncodedCallMetadata = ((maxProcedureParameters + 1) *
                            (maxLexicalNestingLevel + 1)) - 1;

type
  opcode = (lit, opr, lod, sto, cal, int, jmp, jpc); {functions}
  pCodeInstruction = packed record
    operation: opcode;                              {virtual machine opcode}
    lexicalLevel: 0..maxEncodedCallMetadata;        {static-link distance or encoded call metadata}
    argument: 0..maxNumericValue;                   {opcode-specific operand}
  end;

var
  codeIndex: integer;       {index of the next instruction to emit}
  pCodeImage: array [0..codeMaxIndex] of pCodeInstruction; {generated program image}
  opcodeMnemonics: array [opcode] of packed array [1 .. 5] of char;
  pCodeFile: Text;
  pCodeFileName: string;
  outputInstructionIndex: integer;
  loopContinueCount: integer;
  loopContinueTargetKnown: array [1..codeMaxIndex] of boolean;
  loopContinueTargetAddress: array [1..codeMaxIndex] of integer;
  loopContinuePendingCounts: array [1..codeMaxIndex] of integer;
  loopContinuePendingJumps: array [1..codeMaxIndex, 1..codeMaxIndex] of integer;

type
  pCodeContext = record
    currentLevel: integer;
    parameterCount: integer;
    currentRoutineIsFunction: boolean;
    currentReturnType: typeValue;
  end;

function reserveJump(jumpOpcode: opcode): integer; forward;
function currentCodeIndex: integer; forward;

function opcodeMnemonicToString(instructionOpcode: opcode): string;
var
  characterIndex: integer;
begin
  opcodeMnemonicToString := '';
  for characterIndex := 1 to 5 do
    opcodeMnemonicToString := opcodeMnemonicToString + opcodeMnemonics[instructionOpcode][characterIndex];
  opcodeMnemonicToString := TrimRight(opcodeMnemonicToString)
end;

procedure traceInstruction(messageText: string);
begin
  emitDiagnostic(debug, '[EMIT] ' + messageText)
end;

procedure closePCodeFileAndHalt;
begin
  writeln;
  close(pCodeFile);
  halt
end;

procedure initializePCode(const outputFileName: string);
begin
  pCodeFileName := outputFileName;
  Assign(pCodeFile, pCodeFileName);
  Rewrite(pCodeFile);
  opcodeMnemonics[lit] := 'LIT  ';
  opcodeMnemonics[opr] := 'OPR  ';
  opcodeMnemonics[lod] := 'LOD  ';
  opcodeMnemonics[sto] := 'STO  ';
  opcodeMnemonics[cal] := 'CAL  ';
  opcodeMnemonics[int] := 'INT  ';
  opcodeMnemonics[jmp] := 'JMP  ';
  opcodeMnemonics[jpc] := 'JPC  ';
  codeIndex := 0;
  loopContinueCount := 0
end;

procedure cleanupPCode;
begin
  close(pCodeFile)
end;

procedure emitInstruction(instructionOpcode: opcode; instructionLevel, instructionArgument: integer);
begin
  if codeIndex > codeMaxIndex then
  begin
    emitDiagnostic(error, STATUS_PROGRAM_TOO_LONG);
    closePCodeFileAndHalt()
  end;
  with pCodeImage[codeIndex] do
  begin
    operation := instructionOpcode;
    lexicalLevel := instructionLevel;
    argument := instructionArgument
  end;
  codeIndex := codeIndex + 1
end;

procedure emitLoadConst(const constantValue: integer);
begin
  emitInstruction(lit, 0, constantValue)
end;

procedure emitLoadVar(lexicalLevel, address: integer);
begin
  emitInstruction(lod, lexicalLevel, address)
end;

procedure emitStoreVar(lexicalLevel, address: integer);
begin
  emitInstruction(sto, lexicalLevel, address)
end;

procedure emitArgumentPush;
begin
  emitInstruction(opr, 0, 28)
end;

procedure emitCall(lexicalLevel, parameterCount, address: integer);
begin
  emitInstruction(cal,
                  parameterCount * (maxLexicalNestingLevel + 1) + lexicalLevel,
                  address)
end;

procedure emitBuiltinProcedureNotImplemented(procKind: builtinProcedure;
                                             callSource: sourceContext;
                                             var errorCount: integer);
begin
  emitDiagnostic(debug, '[EMIT] built-in procedure recognized: ' +
                        builtinProcedureName(procKind));
  reportCompilerError(ERR_BUILTIN_PROCEDURE_NOT_YET_IMPLEMENTED, callSource, errorCount)
end;

procedure emitBinaryOp(operationCode: integer);
begin
  emitInstruction(opr, 0, operationCode)
end;

procedure emitUnaryOp(operationCode: integer);
begin
  emitInstruction(opr, 0, operationCode)
end;

procedure emitWriteValue(argumentType: typeValue; appendNewline: boolean);
begin
  if argumentType = typeChar then
  begin
    if appendNewline then
      emitInstruction(opr, 0, 24)
    else
      emitInstruction(opr, 0, 19)
  end
  else
  begin
    if appendNewline then
      emitInstruction(opr, 0, 23)
    else
      emitInstruction(opr, 0, 18)
  end
end;

procedure emitReadValue(argumentType: typeValue; consumeLineRemainder: boolean);
begin
  case argumentType of
    typeInteger:
      if consumeLineRemainder then
        emitInstruction(opr, 0, 25)
      else
        emitInstruction(opr, 0, 20);
    typeChar:
      if consumeLineRemainder then
        emitInstruction(opr, 0, 26)
      else
        emitInstruction(opr, 0, 21);
    typeBoolean:
      if consumeLineRemainder then
        emitInstruction(opr, 0, 27)
      else
        emitInstruction(opr, 0, 22)
  end
end;

function emitConditionalJump: integer;
begin
  emitConditionalJump := reserveJump(jpc)
end;

procedure emitJump(targetAddress: integer);
begin
  emitInstruction(jmp, 0, targetAddress)
end;

procedure emitBlockAllocation(localSlotCount: integer);
begin
  emitInstruction(int, 0, localSlotCount)
end;

procedure emitReturn;
begin
  emitInstruction(opr, 0, 0)
end;

procedure emitReturnValue;
begin
  emitInstruction(opr, 0, 29)
end;

function reserveJump(jumpOpcode: opcode): integer;
begin
  reserveJump := codeIndex;
  emitInstruction(jumpOpcode, 0, 0)
end;

procedure patchInstructionArgument(instructionIndex, newArgument: integer);
begin
  pCodeImage[instructionIndex].argument := newArgument
end;

procedure patchJumpToCurrent(instructionIndex: integer);
begin
  patchInstructionArgument(instructionIndex, currentCodeIndex)
end;

procedure pushLoopContinueTargetKnown(targetAddress: integer);
begin
  loopContinueCount := loopContinueCount + 1;
  loopContinueTargetKnown[loopContinueCount] := true;
  loopContinueTargetAddress[loopContinueCount] := targetAddress;
  loopContinuePendingCounts[loopContinueCount] := 0
end;

procedure pushLoopContinueTargetPending;
begin
  loopContinueCount := loopContinueCount + 1;
  loopContinueTargetKnown[loopContinueCount] := false;
  loopContinueTargetAddress[loopContinueCount] := 0;
  loopContinuePendingCounts[loopContinueCount] := 0
end;

procedure patchCurrentLoopContinueTarget(targetAddress: integer);
var
  pendingIndex: integer;
begin
  if loopContinueCount = 0 then
    exit;

  loopContinueTargetKnown[loopContinueCount] := true;
  loopContinueTargetAddress[loopContinueCount] := targetAddress;
  pendingIndex := 1;
  while pendingIndex <= loopContinuePendingCounts[loopContinueCount] do
  begin
    patchInstructionArgument(loopContinuePendingJumps[loopContinueCount, pendingIndex],
                             targetAddress);
    pendingIndex := pendingIndex + 1
  end;
  loopContinuePendingCounts[loopContinueCount] := 0
end;

procedure popLoopContinueTarget;
begin
  if loopContinueCount > 0 then
    loopContinueCount := loopContinueCount - 1
end;

procedure emitContinueJump;
begin
  if loopContinueCount = 0 then
    exit;

  if loopContinueTargetKnown[loopContinueCount] then
    emitJump(loopContinueTargetAddress[loopContinueCount])
  else
  begin
    loopContinuePendingCounts[loopContinueCount] :=
      loopContinuePendingCounts[loopContinueCount] + 1;
    loopContinuePendingJumps[loopContinueCount,
                             loopContinuePendingCounts[loopContinueCount]] := reserveJump(jmp)
  end
end;

function currentCodeIndex: integer;
begin
  currentCodeIndex := codeIndex
end;

function currentCodeAddress: integer;
begin
  currentCodeAddress := currentCodeIndex
end;

function blockLocalAllocation(blockNode: astNode; parameterCount: integer): integer;
var
  childNode: astNode;
begin
  blockLocalAllocation := 3 + parameterCount; {activation header plus copied parameters}
  if blockNode = nil then
    exit;

  childNode := blockNode^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind = astVarDeclaration then
      blockLocalAllocation := blockLocalAllocation + 1;
    childNode := childNode^.nextSibling
  end
end;

function routineBlockNode(node: astNode): astNode;
begin
  routineBlockNode := node^.firstChild;
  while (routineBlockNode <> nil) and
        (routineBlockNode^.kind = astVarDeclaration) do
    routineBlockNode := routineBlockNode^.nextSibling
end;

procedure generateBlockBody(blockNode: astNode; var context: pCodeContext; var errorCount: integer); forward;
procedure generateProcedureDeclaration(node: astNode; var context: pCodeContext; var errorCount: integer); forward;
procedure generateFunctionDeclaration(node: astNode; var context: pCodeContext; var errorCount: integer); forward;

procedure generateExpression(node: astNode; var context: pCodeContext; var errorCount: integer); forward;
procedure generateStatement(node: astNode; var context: pCodeContext; var errorCount: integer); forward;
procedure generateBlock(node: astNode; var context: pCodeContext; var errorCount: integer); forward;

procedure generateCaseExpression(node: astNode; var context: pCodeContext; var errorCount: integer);
var
  selectorNode, caseArmNode, whenNode, resultNode: astNode;
  endJumpIndices: array [1..codeMaxIndex] of integer;
  endJumpCount: integer;
  skipJumpIndex: integer;
begin
  selectorNode := nil;
  caseArmNode := node^.firstChild;
  if node^.operatorSymbol = casesym then
  begin
    selectorNode := node^.firstChild;
    if selectorNode <> nil then
      caseArmNode := selectorNode^.nextSibling
  end;

  endJumpCount := 0;
  while (caseArmNode <> nil) and (caseArmNode^.kind = astCaseArm) do
  begin
    whenNode := caseArmNode^.firstChild;
    resultNode := nil;
    if whenNode <> nil then
      resultNode := whenNode^.nextSibling;

    if selectorNode <> nil then
    begin
      generateExpression(selectorNode, context, errorCount);
      generateExpression(whenNode, context, errorCount);
      emitBinaryOp(8)
    end
    else
      generateExpression(whenNode, context, errorCount);

    skipJumpIndex := emitConditionalJump;
    generateExpression(resultNode, context, errorCount);
    endJumpCount := endJumpCount + 1;
    endJumpIndices[endJumpCount] := reserveJump(jmp);
    patchJumpToCurrent(skipJumpIndex);
    caseArmNode := caseArmNode^.nextSibling
  end;

  generateExpression(caseArmNode, context, errorCount);

  while endJumpCount > 0 do
  begin
    patchJumpToCurrent(endJumpIndices[endJumpCount]);
    endJumpCount := endJumpCount - 1
  end
end;

procedure generateExpression(node: astNode; var context: pCodeContext; var errorCount: integer);
var
  leftNode, rightNode, operandNode, argumentNode: astNode;
  resolvedSymbol: symbolIndex;
  argumentCount: integer;
begin
  if node = nil then
    exit;

  case node^.kind of
    astIdentifierReference:
      begin
        if not hasResolvedSymbol(node) then
          exit;
        resolvedSymbol := resolvedSymbolOf(node);
        case getDeclarationKind(resolvedSymbol) of
          constant:
            emitLoadConst(getConstantValue(resolvedSymbol));
          variable:
            emitLoadVar(lexicalLevelDistance(context.currentLevel,
                                             getDeclarationLevel(resolvedSymbol),
                                             node^.source, errorCount),
                        getAddress(resolvedSymbol));
          proc, func:
            {routine identifier usage without a call is rejected during semantics}
        end
      end;
    astNumberLiteral,
    astCharLiteral,
    astBooleanLiteral:
      emitLoadConst(node^.numberValue);
    astUnaryExpression:
      begin
        operandNode := node^.firstChild;
        generateExpression(operandNode, context, errorCount);
        if node^.operatorSymbol = minus then
          emitUnaryOp(1)
        else if node^.operatorSymbol = notsym then
          emitUnaryOp(14)
      end;
    astBinaryExpression:
      begin
        leftNode := node^.firstChild;
        rightNode := nil;
        if leftNode <> nil then
          rightNode := leftNode^.nextSibling;
        generateExpression(leftNode, context, errorCount);
        generateExpression(rightNode, context, errorCount);
        case node^.operatorSymbol of
          plus: emitBinaryOp(2);
          minus: emitBinaryOp(3);
          times: emitBinaryOp(4);
          slash: emitBinaryOp(5);
          eql: emitBinaryOp(8);
          neq: emitBinaryOp(9);
          lss: emitBinaryOp(10);
          geq: emitBinaryOp(11);
          gtr: emitBinaryOp(12);
          leq: emitBinaryOp(13);
          andsym: emitBinaryOp(15);
          orsym: emitBinaryOp(16);
          xorsym: emitBinaryOp(17);
        end
      end;
    astCallExpression:
      begin
        leftNode := node^.firstChild;
        argumentNode := nil;
        if leftNode <> nil then
          argumentNode := leftNode^.nextSibling;
        if hasResolvedSymbol(leftNode) then
        begin
          resolvedSymbol := resolvedSymbolOf(leftNode);
          argumentCount := 0;
          while argumentNode <> nil do
          begin
            generateExpression(argumentNode, context, errorCount);
            emitArgumentPush;
            argumentCount := argumentCount + 1;
            argumentNode := argumentNode^.nextSibling
          end;
          emitCall(lexicalLevelDistance(context.currentLevel,
                                        getDeclarationLevel(resolvedSymbol),
                                        leftNode^.source, errorCount),
                   argumentCount,
                   getAddress(resolvedSymbol))
        end
      end;
    astCaseExpression:
      generateCaseExpression(node, context, errorCount)
  end
end;

procedure generateStatement(node: astNode; var context: pCodeContext; var errorCount: integer);
var
  firstChildNode, secondChildNode, childNode: astNode;
  thirdChildNode, fourthChildNode, fifthChildNode: astNode;
  switchCaseNode: astNode;
  resolvedSymbol: symbolIndex;
  procKind: builtinProcedure;
  conditionalJumpIndex, loopStartAddress, loopExitJumpIndex, elseSkipJumpIndex: integer;
  switchEndJumpIndices: array [1..codeMaxIndex] of integer;
  switchBodyJumpIndices: array [1..codeMaxIndex] of integer;
  switchEndJumpCount: integer;
  switchBodyJumpCount: integer;
  elseEntryJumpIndex: integer;
  argumentCount: integer;
begin
  if node = nil then
    exit;

  case node^.kind of
    astCompoundStatement:
      begin
        childNode := node^.firstChild;
        while childNode <> nil do
        begin
          generateStatement(childNode, context, errorCount);
          childNode := childNode^.nextSibling
        end
      end;
    astAssignmentStatement:
      begin
        firstChildNode := node^.firstChild;
        secondChildNode := nil;
        if firstChildNode <> nil then
          secondChildNode := firstChildNode^.nextSibling;
        generateExpression(secondChildNode, context, errorCount);
        if hasResolvedSymbol(firstChildNode) then
        begin
          resolvedSymbol := resolvedSymbolOf(firstChildNode);
          if getDeclarationKind(resolvedSymbol) = variable then
            emitStoreVar(lexicalLevelDistance(context.currentLevel,
                                              getDeclarationLevel(resolvedSymbol),
                                              firstChildNode^.source, errorCount),
                         getAddress(resolvedSymbol))
        end
      end;
    astCallStatement:
      begin
        firstChildNode := node^.firstChild;
        secondChildNode := nil;
        if firstChildNode <> nil then
          secondChildNode := firstChildNode^.nextSibling;
        if hasResolvedSymbol(firstChildNode) then
        begin
          resolvedSymbol := resolvedSymbolOf(firstChildNode);
          if getDeclarationKind(resolvedSymbol) = proc then
          begin
            procKind := getBuiltinProcedure(resolvedSymbol);
            if procKind = builtinNone then
            begin
              argumentCount := 0;
              while secondChildNode <> nil do
              begin
                generateExpression(secondChildNode, context, errorCount);
                emitArgumentPush;
                argumentCount := argumentCount + 1;
                secondChildNode := secondChildNode^.nextSibling
              end;
              emitCall(lexicalLevelDistance(context.currentLevel,
                                            getDeclarationLevel(resolvedSymbol),
                                            firstChildNode^.source, errorCount),
                       argumentCount,
                       getAddress(resolvedSymbol))
            end
            else if procKind in [builtinWrite, builtinWriteLn] then
            begin
              generateExpression(secondChildNode, context, errorCount);
              if hasNodeType(secondChildNode) then
                emitWriteValue(getNodeType(secondChildNode), procKind = builtinWriteLn)
            end
            else if procKind in [builtinRead, builtinReadLn] then
            begin
              if hasResolvedSymbol(secondChildNode) and hasNodeType(secondChildNode) then
              begin
                emitReadValue(getNodeType(secondChildNode), procKind = builtinReadLn);
                resolvedSymbol := resolvedSymbolOf(secondChildNode);
                emitStoreVar(lexicalLevelDistance(context.currentLevel,
                                                  getDeclarationLevel(resolvedSymbol),
                                                  secondChildNode^.source, errorCount),
                             getAddress(resolvedSymbol))
              end
            end
            else
              emitBuiltinProcedureNotImplemented(procKind, firstChildNode^.source, errorCount)
          end
        end
      end;
    astReturnStatement:
      begin
        firstChildNode := node^.firstChild;
        generateExpression(firstChildNode, context, errorCount);
        emitReturnValue
      end;
    astContinueStatement:
      emitContinueJump;
    astIfStatement:
      begin
        firstChildNode := node^.firstChild;
        secondChildNode := nil;
        childNode := nil;
        if firstChildNode <> nil then
          secondChildNode := firstChildNode^.nextSibling;
        if secondChildNode <> nil then
          childNode := secondChildNode^.nextSibling;
        generateExpression(firstChildNode, context, errorCount);
        conditionalJumpIndex := emitConditionalJump;
        generateStatement(secondChildNode, context, errorCount);
        if childNode <> nil then
        begin
          elseSkipJumpIndex := reserveJump(jmp);
          patchJumpToCurrent(conditionalJumpIndex);
          generateStatement(childNode, context, errorCount);
          patchJumpToCurrent(elseSkipJumpIndex)
        end
        else
          patchJumpToCurrent(conditionalJumpIndex)
      end;
    astWhileStatement:
      begin
        loopStartAddress := currentCodeAddress;
        firstChildNode := node^.firstChild;
        secondChildNode := nil;
        if firstChildNode <> nil then
          secondChildNode := firstChildNode^.nextSibling;
        generateExpression(firstChildNode, context, errorCount);
        loopExitJumpIndex := emitConditionalJump;
        pushLoopContinueTargetKnown(loopStartAddress);
        generateStatement(secondChildNode, context, errorCount);
        popLoopContinueTarget;
        emitJump(loopStartAddress);
        patchJumpToCurrent(loopExitJumpIndex)
      end;
    astRepeatStatement:
      begin
        loopStartAddress := currentCodeAddress;
        firstChildNode := node^.firstChild;
        secondChildNode := nil;
        if firstChildNode <> nil then
          secondChildNode := firstChildNode^.nextSibling;
        pushLoopContinueTargetPending;
        generateStatement(firstChildNode, context, errorCount);
        patchCurrentLoopContinueTarget(currentCodeAddress);
        popLoopContinueTarget;
        generateExpression(secondChildNode, context, errorCount);
        loopExitJumpIndex := emitConditionalJump;
        patchInstructionArgument(loopExitJumpIndex, loopStartAddress)
      end;
    astForStatement:
      begin
        firstChildNode := node^.firstChild;
        secondChildNode := nil;
        thirdChildNode := nil;
        fourthChildNode := nil;
        fifthChildNode := nil;
        if firstChildNode <> nil then
          secondChildNode := firstChildNode^.nextSibling;
        if secondChildNode <> nil then
          thirdChildNode := secondChildNode^.nextSibling;
        if thirdChildNode <> nil then
          fourthChildNode := thirdChildNode^.nextSibling;
        if fourthChildNode <> nil then
          fifthChildNode := fourthChildNode^.nextSibling;

        generateExpression(secondChildNode, context, errorCount);
        if hasResolvedSymbol(firstChildNode) then
        begin
          resolvedSymbol := resolvedSymbolOf(firstChildNode);
          emitStoreVar(lexicalLevelDistance(context.currentLevel,
                                            getDeclarationLevel(resolvedSymbol),
                                            firstChildNode^.source, errorCount),
                       getAddress(resolvedSymbol))
        end;

        loopStartAddress := currentCodeAddress;
        generateExpression(firstChildNode, context, errorCount);
        generateExpression(thirdChildNode, context, errorCount);
        emitBinaryOp(13);
        loopExitJumpIndex := emitConditionalJump;
        pushLoopContinueTargetPending;
        generateStatement(fifthChildNode, context, errorCount);
        patchCurrentLoopContinueTarget(currentCodeAddress);
        popLoopContinueTarget;
        generateExpression(firstChildNode, context, errorCount);
        generateExpression(fourthChildNode, context, errorCount);
        emitBinaryOp(2);
        if hasResolvedSymbol(firstChildNode) then
        begin
          resolvedSymbol := resolvedSymbolOf(firstChildNode);
          emitStoreVar(lexicalLevelDistance(context.currentLevel,
                                            getDeclarationLevel(resolvedSymbol),
                                            firstChildNode^.source, errorCount),
                       getAddress(resolvedSymbol))
        end;
        emitJump(loopStartAddress);
        patchJumpToCurrent(loopExitJumpIndex)
      end;
    astSwitchStatement:
      begin
        firstChildNode := node^.firstChild;
        switchCaseNode := nil;
        if firstChildNode <> nil then
          switchCaseNode := firstChildNode^.nextSibling;
        switchEndJumpCount := 0;
        switchBodyJumpCount := 0;
        elseEntryJumpIndex := -1;

        while switchCaseNode <> nil do
        begin
          if switchCaseNode^.kind = astSwitchCaseArm then
          begin
            thirdChildNode := switchCaseNode^.lastChild;
            secondChildNode := switchCaseNode^.firstChild;
            while (secondChildNode <> nil) and (secondChildNode <> thirdChildNode) do
            begin
              generateExpression(firstChildNode, context, errorCount);
              generateExpression(secondChildNode, context, errorCount);
              emitBinaryOp(8);
              conditionalJumpIndex := emitConditionalJump;
              switchBodyJumpCount := switchBodyJumpCount + 1;
              switchBodyJumpIndices[switchBodyJumpCount] := reserveJump(jmp);
              patchJumpToCurrent(conditionalJumpIndex);
              secondChildNode := secondChildNode^.nextSibling
            end
          end;
          switchCaseNode := switchCaseNode^.nextSibling
        end;

        elseEntryJumpIndex := reserveJump(jmp);

        switchCaseNode := nil;
        if firstChildNode <> nil then
          switchCaseNode := firstChildNode^.nextSibling;
        switchBodyJumpCount := 1;
        while switchCaseNode <> nil do
        begin
          if switchCaseNode^.kind = astSwitchCaseArm then
          begin
            thirdChildNode := switchCaseNode^.lastChild;
            secondChildNode := switchCaseNode^.firstChild;
            while (secondChildNode <> nil) and (secondChildNode <> thirdChildNode) do
            begin
              patchJumpToCurrent(switchBodyJumpIndices[switchBodyJumpCount]);
              switchBodyJumpCount := switchBodyJumpCount + 1;
              secondChildNode := secondChildNode^.nextSibling
            end;
            generateStatement(thirdChildNode, context, errorCount);
            switchEndJumpCount := switchEndJumpCount + 1;
            switchEndJumpIndices[switchEndJumpCount] := reserveJump(jmp)
          end
          else
          begin
            patchJumpToCurrent(elseEntryJumpIndex);
            elseEntryJumpIndex := -1;
            generateStatement(switchCaseNode, context, errorCount)
          end;
          switchCaseNode := switchCaseNode^.nextSibling
        end;

        if elseEntryJumpIndex >= 0 then
          patchJumpToCurrent(elseEntryJumpIndex);

        while switchEndJumpCount > 0 do
        begin
          patchJumpToCurrent(switchEndJumpIndices[switchEndJumpCount]);
          switchEndJumpCount := switchEndJumpCount - 1
        end
      end
  end
end;

procedure generateProcedureDeclaration(node: astNode; var context: pCodeContext; var errorCount: integer);
var
  nestedContext: pCodeContext;
  procedureSymbol: symbolIndex;
begin
  if node = nil then
    exit;

  if not hasResolvedSymbol(node) then
    exit;

  procedureSymbol := resolvedSymbolOf(node);
  setAddress(procedureSymbol, currentCodeAddress);
  nestedContext.currentLevel := context.currentLevel + 1;
  nestedContext.parameterCount := getProcedureParameterCount(procedureSymbol);
  nestedContext.currentRoutineIsFunction := false;
  nestedContext.currentReturnType := typeInteger;
  generateBlock(routineBlockNode(node), nestedContext, errorCount)
end;

procedure generateFunctionDeclaration(node: astNode; var context: pCodeContext; var errorCount: integer);
var
  nestedContext: pCodeContext;
  functionSymbol: symbolIndex;
begin
  if node = nil then
    exit;

  if not hasResolvedSymbol(node) then
    exit;

  functionSymbol := resolvedSymbolOf(node);
  setAddress(functionSymbol, currentCodeAddress);
  nestedContext.currentLevel := context.currentLevel + 1;
  nestedContext.parameterCount := getProcedureParameterCount(functionSymbol);
  nestedContext.currentRoutineIsFunction := true;
  nestedContext.currentReturnType := getDeclarationType(functionSymbol);
  generateBlock(routineBlockNode(node), nestedContext, errorCount)
end;

procedure generateBlockBody(blockNode: astNode; var context: pCodeContext; var errorCount: integer);
var
  childNode: astNode;
begin
  if blockNode = nil then
    exit;

  emitBlockAllocation(blockLocalAllocation(blockNode, context.parameterCount));

  childNode := blockNode^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind in [astCompoundStatement, astAssignmentStatement,
                           astCallStatement, astReturnStatement,
                           astContinueStatement,
                           astIfStatement, astWhileStatement,
                           astRepeatStatement, astForStatement, astSwitchStatement] then
      generateStatement(childNode, context, errorCount);
    childNode := childNode^.nextSibling
  end;

  if context.currentRoutineIsFunction then
  begin
    emitLoadConst(0);
    emitReturnValue
  end
  else
    emitReturn
end;

procedure generateBlock(node: astNode; var context: pCodeContext; var errorCount: integer);
var
  childNode: astNode;
  procedureSkipJumpIndex: integer;
begin
  if node = nil then
    exit;

  if context.currentLevel = 0 then
    procedureSkipJumpIndex := reserveJump(jmp)
  else
    procedureSkipJumpIndex := -1;

  childNode := node^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind = astProcedureDeclaration then
      generateProcedureDeclaration(childNode, context, errorCount)
    else if childNode^.kind = astFunctionDeclaration then
      generateFunctionDeclaration(childNode, context, errorCount);
    childNode := childNode^.nextSibling
  end;

  if procedureSkipJumpIndex >= 0 then
    patchJumpToCurrent(procedureSkipJumpIndex);

  generateBlockBody(node, context, errorCount)
end;

procedure generatePCodeProgram(rootNode: astNode; var errorCount: integer);
var
  context: pCodeContext;
begin
  if rootNode = nil then
    exit;

  context.currentLevel := 0;
  context.parameterCount := 0;
  context.currentRoutineIsFunction := false;
  context.currentReturnType := typeInteger;
  if rootNode^.kind = astProgram then
    generateBlock(rootNode^.firstChild, context, errorCount)
  else
    generateBlock(rootNode, context, errorCount)
end;

procedure traceGeneratedPCode(blockStartIndex: integer);
var
  instructionIndex: integer;
begin
  for instructionIndex := blockStartIndex to codeIndex-1 do
    with pCodeImage[instructionIndex] do
      traceInstruction(Format('%4d %-5s %3d %5d',
                              [instructionIndex,
                               opcodeMnemonicToString(operation),
                               lexicalLevel,
                               argument]))
end;

procedure writePCodeImage;
begin
  for outputInstructionIndex := 0 to codeIndex - 1 do
    with pCodeImage[outputInstructionIndex] do
      writeln(pCodeFile, outputInstructionIndex,
              opcodeMnemonics[operation]:5, lexicalLevel:3, argument:5)
end;

end.
