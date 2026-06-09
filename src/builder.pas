{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-31

  Build pipeline orchestration for the command-line compiler.  This unit owns
  the flow from source file to generated intermediate and p-code images while
  keeping parsing, semantic analysis, TAC lowering, and p-code generation in
  their own units. }
unit builder;

{$mode objfpc}

interface

procedure buildFile(const inputFileName: string);

implementation

uses
  SysUtils, diagnostics, astree, parser, semantics, llir, llircgen, pcode;

procedure dumpAstIfVerbose(rootNode: astNode);
begin
  if getDiagnosticVerbosity = diagnostics.all then
    dumpAstPreOrder(rootNode)
end;

procedure buildFile(const inputFileName: string);
var
  programNode: astNode;
  errorCount: integer;
begin
  errorCount := 0;
  programNode := nil;

  emitDiagnostic(status, STATUS_COMPILER_PROCESSING_FILE + inputFileName);
  parseFile(inputFileName, programNode, errorCount);

  if errorCount = 0 then
  begin
    analyzeAst(programNode, errorCount);
    dumpAstIfVerbose(programNode)
  end;

  if errorCount = 0 then
  begin
    generateLlirProgram(programNode, errorCount);
    if errorCount = 0 then
      dumpLlir(ChangeFileExt(inputFileName, '.tac'));

    if errorCount <> 0 then
    begin
      emitDiagnostic(status, STATUS_COMPILER_ERRORS);
      freeAst(programNode);
      exit
    end;

    initializePCode(ChangeFileExt(inputFileName, '.pcode'));
    generatePCodeProgram(programNode, errorCount);
    if errorCount = 0 then
    begin
      emitDiagnostic(status, STATUS_COMPILER_SUCCESS);
      traceGeneratedPCode(0);
      writePCodeImage
    end
    else
      emitDiagnostic(status, STATUS_COMPILER_ERRORS);
    cleanupPCode
  end
  else
    emitDiagnostic(status, STATUS_COMPILER_ERRORS);

  freeAst(programNode)
end;

end.
