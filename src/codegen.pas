{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-22

  P-code generation support for the parser pipeline.  This unit owns instruction
  types, opcode mnemonics, the generated program image, emit/patch helpers,
  trace listing, and final program-image output.  It does not parse source
  text or perform semantic checks. }
unit codegen;

interface

uses
  astree;

procedure initializeCodegen(const outputFileName: string);
procedure cleanupCodegen;
procedure generateProgram(rootNode: astNode; var errorCount: integer);
procedure traceGeneratedCode(blockStartIndex: integer);
procedure writeProgramImage;

implementation

uses
  SysUtils, diagnostics, semantics, symboltable, tokens;

const
  codeMaxIndex = 200;        {maximum code array index}

type
  opcode = (lit, opr, lod, sto, cal, int, jmp, jpc); {functions}
  pCodeInstruction = packed record
    operation: opcode;                              {virtual machine opcode}
    lexicalLevel: 0..maxLexicalNestingLevel;        {static-link distance}
    argument: 0..maxNumericValue;                   {opcode-specific operand}
  end;

var
  codeIndex: integer;       {index of the next instruction to emit}
  pCode: array [0..codeMaxIndex] of pCodeInstruction; {generated program image}
  opcodeMnemonics: array [opcode] of packed array [1 .. 5] of char;
  pCodeFile: Text;
  pCodeFileName: string;
  outputInstructionIndex: integer;

type
  codegenContext = record
    currentLevel: integer;
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

procedure closeCodegenFileAndHalt;
begin
  writeln;
  close(pCodeFile);
  halt
end;

procedure initializeCodegen(const outputFileName: string);
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
  codeIndex := 0
end;

procedure cleanupCodegen;
begin
  close(pCodeFile)
end;

procedure emitInstruction(instructionOpcode: opcode; instructionLevel, instructionArgument: integer);
begin
  if codeIndex > codeMaxIndex then
  begin
    emitDiagnostic(error, STATUS_PROGRAM_TOO_LONG);
    closeCodegenFileAndHalt()
  end;
  with pCode[codeIndex] do
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

procedure emitCall(lexicalLevel, address: integer);
begin
  emitInstruction(cal, lexicalLevel, address)
end;

procedure emitBinaryOp(operationCode: integer);
begin
  emitInstruction(opr, 0, operationCode)
end;

procedure emitUnaryOp(operationCode: integer);
begin
  emitInstruction(opr, 0, operationCode)
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

function reserveJump(jumpOpcode: opcode): integer;
begin
  reserveJump := codeIndex;
  emitInstruction(jumpOpcode, 0, 0)
end;

procedure patchInstructionArgument(instructionIndex, newArgument: integer);
begin
  pCode[instructionIndex].argument := newArgument
end;

procedure patchJumpToCurrent(instructionIndex: integer);
begin
  patchInstructionArgument(instructionIndex, currentCodeIndex)
end;

function currentCodeIndex: integer;
begin
  currentCodeIndex := codeIndex
end;

function currentCodeAddress: integer;
begin
  currentCodeAddress := currentCodeIndex
end;

function blockLocalAllocation(blockNode: astNode): integer;
var
  childNode: astNode;
begin
  blockLocalAllocation := 3; {static link, dynamic link, return address}
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

procedure generateBlockBody(blockNode: astNode; var context: codegenContext; var errorCount: integer); forward;
procedure generateProcedureDeclaration(node: astNode; var context: codegenContext; var errorCount: integer); forward;

procedure generateExpression(node: astNode; var context: codegenContext; var errorCount: integer); forward;
procedure generateCondition(node: astNode; var context: codegenContext; var errorCount: integer); forward;
procedure generateStatement(node: astNode; var context: codegenContext; var errorCount: integer); forward;
procedure generateBlock(node: astNode; var context: codegenContext; var errorCount: integer); forward;

procedure generateExpression(node: astNode; var context: codegenContext; var errorCount: integer);
var
  leftNode, rightNode, operandNode: astNode;
  resolvedSymbol: symbolIndex;
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
          proc:
            {procedure-in-expression is rejected during semantics}
        end
      end;
    astNumberLiteral:
      emitLoadConst(node^.numberValue);
    astUnaryExpression:
      begin
        operandNode := node^.firstChild;
        generateExpression(operandNode, context, errorCount);
        if node^.operatorSymbol = minus then
          emitUnaryOp(1)
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
        end
      end
  end
end;

procedure generateCondition(node: astNode; var context: codegenContext; var errorCount: integer);
var
  leftNode, rightNode: astNode;
begin
  if node = nil then
    exit;

  leftNode := node^.firstChild;
  rightNode := nil;
  if leftNode <> nil then
    rightNode := leftNode^.nextSibling;

  generateExpression(leftNode, context, errorCount);
  generateExpression(rightNode, context, errorCount);
  case node^.operatorSymbol of
    eql: emitBinaryOp(8);
    neq: emitBinaryOp(9);
    lss: emitBinaryOp(10);
    geq: emitBinaryOp(11);
    gtr: emitBinaryOp(12);
    leq: emitBinaryOp(13);
  end
end;

procedure generateStatement(node: astNode; var context: codegenContext; var errorCount: integer);
var
  firstChildNode, secondChildNode, childNode: astNode;
  resolvedSymbol: symbolIndex;
  conditionalJumpIndex, loopStartAddress, loopExitJumpIndex: integer;
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
        if hasResolvedSymbol(firstChildNode) then
        begin
          resolvedSymbol := resolvedSymbolOf(firstChildNode);
          if getDeclarationKind(resolvedSymbol) = proc then
            emitCall(lexicalLevelDistance(context.currentLevel,
                                          getDeclarationLevel(resolvedSymbol),
                                          firstChildNode^.source, errorCount),
                     getAddress(resolvedSymbol))
        end
      end;
    astIfStatement:
      begin
        firstChildNode := node^.firstChild;
        secondChildNode := nil;
        if firstChildNode <> nil then
          secondChildNode := firstChildNode^.nextSibling;
        generateCondition(firstChildNode, context, errorCount);
        conditionalJumpIndex := emitConditionalJump;
        generateStatement(secondChildNode, context, errorCount);
        patchJumpToCurrent(conditionalJumpIndex)
      end;
    astWhileStatement:
      begin
        loopStartAddress := currentCodeAddress;
        firstChildNode := node^.firstChild;
        secondChildNode := nil;
        if firstChildNode <> nil then
          secondChildNode := firstChildNode^.nextSibling;
        generateCondition(firstChildNode, context, errorCount);
        loopExitJumpIndex := emitConditionalJump;
        generateStatement(secondChildNode, context, errorCount);
        emitJump(loopStartAddress);
        patchJumpToCurrent(loopExitJumpIndex)
      end
  end
end;

procedure generateProcedureDeclaration(node: astNode; var context: codegenContext; var errorCount: integer);
var
  nestedContext: codegenContext;
  procedureSymbol: symbolIndex;
begin
  if (node = nil) or (node^.firstChild = nil) then
    exit;

  if not hasResolvedSymbol(node) then
    exit;

  procedureSymbol := resolvedSymbolOf(node);
  setAddress(procedureSymbol, currentCodeAddress);
  nestedContext.currentLevel := context.currentLevel + 1;
  generateBlock(node^.firstChild, nestedContext, errorCount)
end;

procedure generateBlockBody(blockNode: astNode; var context: codegenContext; var errorCount: integer);
var
  childNode: astNode;
begin
  if blockNode = nil then
    exit;

  emitBlockAllocation(blockLocalAllocation(blockNode));

  childNode := blockNode^.firstChild;
  while childNode <> nil do
  begin
    if childNode^.kind in [astCompoundStatement, astAssignmentStatement,
                           astCallStatement, astIfStatement, astWhileStatement] then
      generateStatement(childNode, context, errorCount);
    childNode := childNode^.nextSibling
  end;

  emitReturn
end;

procedure generateBlock(node: astNode; var context: codegenContext; var errorCount: integer);
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
      generateProcedureDeclaration(childNode, context, errorCount);
    childNode := childNode^.nextSibling
  end;

  if procedureSkipJumpIndex >= 0 then
    patchJumpToCurrent(procedureSkipJumpIndex);

  generateBlockBody(node, context, errorCount)
end;

procedure generateProgram(rootNode: astNode; var errorCount: integer);
var
  context: codegenContext;
begin
  if rootNode = nil then
    exit;

  context.currentLevel := 0;
  if rootNode^.kind = astProgram then
    generateBlock(rootNode^.firstChild, context, errorCount)
  else
    generateBlock(rootNode, context, errorCount)
end;

procedure traceGeneratedCode(blockStartIndex: integer);
var
  instructionIndex: integer;
begin
  for instructionIndex := blockStartIndex to codeIndex-1 do
    with pCode[instructionIndex] do
      traceInstruction(Format('%4d %-5s %3d %5d',
                              [instructionIndex,
                               opcodeMnemonicToString(operation),
                               lexicalLevel,
                               argument]))
end;

procedure writeProgramImage;
begin
  for outputInstructionIndex := 0 to codeIndex - 1 do
    with pCode[outputInstructionIndex] do
      writeln(pCodeFile, outputInstructionIndex,
              opcodeMnemonics[operation]:5, lexicalLevel:3, argument:5)
end;

end.
