{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-21

  Command-line entry point for the parser front-end.  This program parses
  command-line arguments, configures diagnostic verbosity, and invokes
  parser.pas on the requested source file. }
program dimec;

uses
    SysUtils,
    builder,
    diagnostics;

var
    verbosity: diagnosticVerbosity;

begin
    if ParamCount < 1 then
    begin
        writeln('Usage: dimec <source-file> [quiet|all]');
        halt(1)
    end;

    if ParamCount >= 2 then
    begin
        if not tryParseDiagnosticVerbosity(ParamStr(2), verbosity) then
        begin
            writeln('Invalid diagnostic verbosity: ', ParamStr(2));
            writeln('Valid verbosity values: quiet, all');
            halt(1)
        end;
        setDiagnosticVerbosity(verbosity)
    end;

    buildFile(ParamStr(1))
end.
