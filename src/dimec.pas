program dimec;

uses
    SysUtils,
    compiler,
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

    compileFile(ParamStr(1))
end.
