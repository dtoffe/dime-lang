program dimec;

uses
    SysUtils,
    compiler;

begin
    if ParamCount < 1 then
    begin
        writeln('Usage: dimec <source-file>');
        halt(1)
    end;

    compileFile(ParamStr(1))
end.
