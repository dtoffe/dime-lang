{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-31

  Build pipeline orchestration for the command-line compiler.  This unit owns
  the flow from source file to generated p-code image while keeping parsing,
  semantic analysis, and code generation in their own units. }
unit builder;

interface

procedure buildFile(const inputFileName: string);

implementation

uses
  SysUtils, diagnostics, astree, parser, semantics, codegen;

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
    initializeCodegen(ChangeFileExt(inputFileName, '.pcode'));
    generateProgram(programNode, errorCount);
    if errorCount = 0 then
    begin
      emitDiagnostic(status, STATUS_COMPILER_SUCCESS);
      traceGeneratedCode(0);
      writeProgramImage
    end
    else
      emitDiagnostic(status, STATUS_COMPILER_ERRORS);
    cleanupCodegen
  end
  else
    emitDiagnostic(status, STATUS_COMPILER_ERRORS);

  freeAst(programNode)
end;

end.
