{
From the book Algorithms + Data Structures = Programs, by Niklaus Wirth (1976)

Chapter 5, page 337

Program 5.6 PL/O Compiler with Code Generation

OCRed, cleaned, fixed, formatted, converted to modern Free Pascal
and tested by Daniel Toffetti.
Formatted with PTop (https://wiki.freepascal.org/PTop)


NOTE: This is a modified version of the original Program 5.6, changing
the code generation so that the code is emitted directly to a file, and
moving p-code interpretation to a separate program that reads the p-code
from the file and executes it.
This file contains the p-code interpreter.
}

program pcodeint;

uses
    SysUtils, diagnostics;

const
    maxNestingLevel = 1;    {the language has only global and procedure-local lexical scopes}
    maxAddress = 2047;      {maximum address}
    codeMaxIndex = 200;     {maximum code array index}
    maxProcedureParameters = 8;
    maxEncodedCallMetadata = ((maxProcedureParameters + 1) * (maxNestingLevel + 1)) - 1;

type
    opcode = (lit, opr, lod, sto, cal, int, jmp, jpc); {functions}
    pCodeInstruction = packed record
                    operation: opcode;                  {virtual machine opcode}
                    lexicalLevel: 0..maxEncodedCallMetadata; {static-link distance or encoded call metadata}
                    argument: 0..maxAddress;            {opcode-specific operand}
                  end ;
{   LIT 0,a  :  load constant a
    OPR 0,a  :  execute operation a
    LOD l,a  :  load variable l,a
    STO l,a  :  store variable l,a
    CAL l,a  :  call procedure a at level l
    INT 0,a  :  increment t-register by a
    JMP 0,a  :  jump to a
    JPC 0,a  :  jump conditional to a      }

var 
    pCode: array [0..codeMaxIndex] of pCodeInstruction; {loaded p-code image}

    pCodeFile: Text;
    pCodeFileName: string;
    verbosity: diagnosticVerbosity;

{Converts an opcode enum into the mnemonic used by compiler listings.}
function opcodeToString(instructionOpcode: opcode): string;
begin
    case instructionOpcode of
        lit: opcodeToString := 'LIT';
        opr: opcodeToString := 'OPR';
        lod: opcodeToString := 'LOD';
        sto: opcodeToString := 'STO';
        cal: opcodeToString := 'CAL';
        int: opcodeToString := 'INT';
        jmp: opcodeToString := 'JMP';
        jpc: opcodeToString := 'JPC';
    end
end {opcodeToString} ;

{Writes a p-code loader trace entry.}
procedure traceLoad(messageText: string);
begin
    emitDiagnostic(debug, '[LOAD] ' + messageText)
end {traceLoad} ;

{Writes an execution-step trace entry.}
procedure traceStep(messageText: string);
begin
    emitDiagnostic(debug, '[STEP] ' + messageText)
end {traceStep} ;

{Writes a store-operation trace entry.}
procedure traceStore(messageText: string);
begin
    emitDiagnostic(debug, '[STOR] ' + messageText)
end {traceStore} ;

{Loads p-code instructions from the input file into memory.}
procedure loadPCodeFile;

var
    pCodeLine: string;
    instructionIndex, conversionStatus: Integer;
    opcodeText, lexicalLevelText, argumentText: string;
    lineIndexWidth: Integer; {width of the leading decimal instruction index}

begin
    instructionIndex := 0;
    while not EOF(pCodeFile) and (instructionIndex < codeMaxIndex) do
    begin
        {Read one fixed-width listing line from the compiler output.}
        readln(pCodeFile, pCodeLine);

        if Trim(pCodeLine) = '' then
            continue;

        {Skip the decimal instruction number prefix before the opcode columns.}
        lineIndexWidth := 0;
        while (lineIndexWidth < length(pCodeLine)) and
              (pCodeLine[lineIndexWidth+1] >= '0') and
              (pCodeLine[lineIndexWidth+1] <= '9') do
            lineIndexWidth := lineIndexWidth + 1;

        {The compiler writes opcode, lexical level, and argument in fixed columns.}
        opcodeText := copy(pCodeLine, lineIndexWidth + 1, 5);
        lexicalLevelText := copy(pCodeLine, lineIndexWidth + 1 + 5, 3);
        argumentText := copy(pCodeLine, lineIndexWidth + 1 + 5 + 3, 5);

        traceLoad(Format('%4d %-5s %3s %5s',
                         [instructionIndex,
                          TrimRight(opcodeText),
                          Trim(lexicalLevelText),
                          Trim(argumentText)]));
        {Decode the mnemonic and numeric operands into the in-memory instruction record.}
        case opcodeText of
            'LIT  ' : pCode[instructionIndex].operation := lit;
            'OPR  ' : pCode[instructionIndex].operation := opr;
            'LOD  ' : pCode[instructionIndex].operation := lod;
            'STO  ' : pCode[instructionIndex].operation := sto;
            'CAL  ' : pCode[instructionIndex].operation := cal;
            'INT  ' : pCode[instructionIndex].operation := int;
            'JMP  ' : pCode[instructionIndex].operation := jmp;
            'JPC  ' : pCode[instructionIndex].operation := jpc;
        end;

        Val(lexicalLevelText, pCode[instructionIndex].lexicalLevel, conversionStatus);
        if conversionStatus <> 0 then
            reportRuntimeError(ERROR_PCODEINT_INVALID_L_VALUE);

        Val(argumentText, pCode[instructionIndex].argument, conversionStatus);
        if conversionStatus <> 0 then
            reportRuntimeError(ERROR_PCODEINT_INVALID_A_VALUE);

        {Advance to the next instruction slot.}
        instructionIndex := instructionIndex + 1;

    end;

    {The full p-code listing has now been consumed.}
    Close(pCodeFile);

    emitDiagnostic(status, STATUS_PCODE_READING_COMPLETE + IntToStr(instructionIndex));

end;

{Executes the loaded p-code program on the stack-based PL/0 virtual machine.}
procedure executePCode;

    const stackMaxSize = 500;
          argumentStackMaxSize = stackMaxSize;
    var programCounter, basePointer, stackTop: integer; {PC, base pointer, and top-of-stack index}
        instructionRegister: pCodeInstruction; {instruction currently being executed}
        runtimeStack: array [1..stackMaxSize] of integer; {shared operand stack and activation records}
        argumentStack: array [1..argumentStackMaxSize] of integer;
        argumentStackTop, callArgumentCount, argumentIndex: integer;

    {Finds the base pointer for an enclosing lexical scope.
     The VM still supports walking outward by arbitrary distances as legacy
     machinery, although the current compiler emits only lexical levels 0 and 1.}
    function findBase(lexicalLevelsOutward: integer): integer;
        var enclosingBasePointer: integer;
    begin enclosingBasePointer := basePointer; {follow static links outward from the current frame}
        while lexicalLevelsOutward > 0 do
            begin
                enclosingBasePointer := runtimeStack[enclosingBasePointer];
                lexicalLevelsOutward := lexicalLevelsOutward - 1
            end ;
        findBase := enclosingBasePointer
     end {findBase} ;

    procedure consumeInputLineRemainder;
    var currentChar: char;
    begin
        while not eof(input) do
        begin
            read(input, currentChar);
            if (currentChar = #10) or (currentChar = #13) then
                break
        end
    end;

    function readInputTokenOrHalt(consumeLineRemainder: boolean): string;
    var currentChar: char;
        tokenTerminator: char;
    begin
        readInputTokenOrHalt := '';
        tokenTerminator := #0;

        while not eof(input) do
        begin
            read(input, currentChar);
            if currentChar > ' ' then
            begin
                readInputTokenOrHalt := currentChar;
                break
            end
        end;

        if readInputTokenOrHalt = '' then
        begin
            reportRuntimeError(ERROR_PCODEINT_INPUT_EXHAUSTED);
            halt(1)
        end;

        while not eof(input) do
        begin
            read(input, currentChar);
            if currentChar <= ' ' then
            begin
              tokenTerminator := currentChar;
              break
            end;
            readInputTokenOrHalt := readInputTokenOrHalt + currentChar
        end;

        if consumeLineRemainder and
           (tokenTerminator <> #10) and
           (tokenTerminator <> #13) then
            consumeInputLineRemainder
    end;

    function readIntegerValueOrHalt: integer;
    var inputToken: string;
        parsedValue, conversionStatus: integer;
    begin
        inputToken := readInputTokenOrHalt(false);
        Val(inputToken, parsedValue, conversionStatus);
        if conversionStatus <> 0 then
        begin
            reportRuntimeError(ERROR_PCODEINT_INVALID_INTEGER_INPUT);
            halt(1)
        end;
        readIntegerValueOrHalt := parsedValue
    end;

    function readIntegerLineValueOrHalt: integer;
    var inputToken: string;
        parsedValue, conversionStatus: integer;
    begin
        inputToken := readInputTokenOrHalt(true);
        Val(inputToken, parsedValue, conversionStatus);
        if conversionStatus <> 0 then
        begin
            reportRuntimeError(ERROR_PCODEINT_INVALID_INTEGER_INPUT);
            halt(1)
        end;
        readIntegerLineValueOrHalt := parsedValue
    end;

    function readCharacterValueOrHalt: integer;
    var inputToken: string;
    begin
        inputToken := readInputTokenOrHalt(false);
        if length(inputToken) <> 1 then
        begin
            reportRuntimeError(ERROR_PCODEINT_INVALID_CHARACTER_INPUT);
            halt(1)
        end;
        readCharacterValueOrHalt := ord(inputToken[1])
    end;

    function readCharacterLineValueOrHalt: integer;
    var inputToken: string;
    begin
        inputToken := readInputTokenOrHalt(true);
        if length(inputToken) <> 1 then
        begin
            reportRuntimeError(ERROR_PCODEINT_INVALID_CHARACTER_INPUT);
            halt(1)
        end;
        readCharacterLineValueOrHalt := ord(inputToken[1])
    end;

    function readBooleanValueOrHalt: integer;
    var inputToken: string;
    begin
        inputToken := readInputTokenOrHalt(false);
        if inputToken = '0' then
            readBooleanValueOrHalt := 0
        else if inputToken = '1' then
            readBooleanValueOrHalt := 1
        else
        begin
            reportRuntimeError(ERROR_PCODEINT_INVALID_BOOLEAN_INPUT);
            halt(1)
        end
    end;

    function readBooleanLineValueOrHalt: integer;
    var inputToken: string;
    begin
        inputToken := readInputTokenOrHalt(true);
        if inputToken = '0' then
            readBooleanLineValueOrHalt := 0
        else if inputToken = '1' then
            readBooleanLineValueOrHalt := 1
        else
        begin
            reportRuntimeError(ERROR_PCODEINT_INVALID_BOOLEAN_INPUT);
            halt(1)
        end
    end;

begin
    emitDiagnostic(status, STATUS_PCODEINT_START);
    stackTop := 0; basePointer := 1; programCounter := 0;
    argumentStackTop := 0;
    runtimeStack[1] := 0; runtimeStack[2] := 0; runtimeStack[3] := 0;
    {Frame layout: static link, dynamic link, return address.}
    repeat
        instructionRegister := pCode[programCounter];
        traceStep(Format('pc=%d bp=%d sp=%d %s %d %d',
                         [programCounter,
                          basePointer,
                          stackTop,
                          opcodeToString(instructionRegister.operation),
                          instructionRegister.lexicalLevel,
                          instructionRegister.argument]));
        programCounter := programCounter + 1;
        with instructionRegister do
        case operation of
            lit: begin stackTop := stackTop+1; runtimeStack[stackTop] := argument
                 end ;
            opr: case argument of {operator}
                 0: begin {return from the current procedure activation}
                        stackTop := basePointer-1;
                        programCounter := runtimeStack[stackTop+3];
                        basePointer := runtimeStack[stackTop+2]
                    end ;
                 1: runtimeStack[stackTop] := -runtimeStack[stackTop];
                 2: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := runtimeStack[stackTop] + runtimeStack[stackTop+1]
                    end ;
                 3: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := runtimeStack[stackTop] - runtimeStack[stackTop+1]
                    end ;
                 4: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := runtimeStack[stackTop] * runtimeStack[stackTop+1]
                    end ;
                 5: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := runtimeStack[stackTop] div runtimeStack[stackTop+1]
                    end ;
                 8: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord(runtimeStack[stackTop]=runtimeStack[stackTop+1])
                    end ;
                 9: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord(runtimeStack[stackTop]<>runtimeStack[stackTop+1])
                    end ;
                10: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord(runtimeStack[stackTop]<runtimeStack[stackTop+1])
                    end ;
                11: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord(runtimeStack[stackTop]>=runtimeStack[stackTop+1])
                    end ;
                12: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord(runtimeStack[stackTop]>runtimeStack[stackTop+1])
                    end ;
                13: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord(runtimeStack[stackTop]<=runtimeStack[stackTop+1])
                    end ;
                14: runtimeStack[stackTop] := ord(runtimeStack[stackTop] = 0);
                15: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord((runtimeStack[stackTop] <> 0) and
                                                       (runtimeStack[stackTop+1] <> 0))
                    end ;
                16: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord((runtimeStack[stackTop] <> 0) or
                                                       (runtimeStack[stackTop+1] <> 0))
                    end ;
                17: begin stackTop := stackTop-1;
                        runtimeStack[stackTop] := ord((runtimeStack[stackTop] <> 0) xor
                                                       (runtimeStack[stackTop+1] <> 0))
                    end ;
                18: begin
                        write(runtimeStack[stackTop]);
                        stackTop := stackTop - 1
                    end ;
                19: begin
                        write(chr(runtimeStack[stackTop]));
                        stackTop := stackTop - 1
                    end ;
                20: begin
                        stackTop := stackTop + 1;
                        runtimeStack[stackTop] := readIntegerValueOrHalt
                    end ;
                21: begin
                        stackTop := stackTop + 1;
                        runtimeStack[stackTop] := readCharacterValueOrHalt
                    end ;
                22: begin
                        stackTop := stackTop + 1;
                        runtimeStack[stackTop] := readBooleanValueOrHalt
                    end ;
                23: begin
                        writeln(runtimeStack[stackTop]);
                        stackTop := stackTop - 1
                    end ;
                24: begin
                        writeln(chr(runtimeStack[stackTop]));
                        stackTop := stackTop - 1
                    end ;
                25: begin
                        stackTop := stackTop + 1;
                        runtimeStack[stackTop] := readIntegerLineValueOrHalt
                    end ;
                26: begin
                        stackTop := stackTop + 1;
                        runtimeStack[stackTop] := readCharacterLineValueOrHalt
                    end ;
                27: begin
                        stackTop := stackTop + 1;
                        runtimeStack[stackTop] := readBooleanLineValueOrHalt
                    end ;
                28: begin
                        if argumentStackTop >= argumentStackMaxSize then
                        begin
                            reportRuntimeError('Procedure call argument stack overflow.');
                            halt(1)
                        end;
                        argumentStackTop := argumentStackTop + 1;
                        argumentStack[argumentStackTop] := runtimeStack[stackTop];
                        stackTop := stackTop - 1
                    end ;
                end ;
            lod: begin stackTop := stackTop+1;
                    runtimeStack[stackTop] := runtimeStack[findBase(lexicalLevel)+argument]
                 end ;
            sto: begin
                    runtimeStack[findBase(lexicalLevel)+argument] := runtimeStack[stackTop];
                    traceStore(Format('level=%d addr=%d abs=%d value=%d',
                                      [lexicalLevel,
                                       argument,
                                       findBase(lexicalLevel) + argument,
                                       runtimeStack[stackTop]]));
                    stackTop := stackTop-1
                 end ;
            cal: begin {build a new activation record and jump to the callee}
                    callArgumentCount := lexicalLevel div (maxNestingLevel + 1);
                    runtimeStack[stackTop+1] := findBase(lexicalLevel mod (maxNestingLevel + 1));
                    runtimeStack[stackTop+2] := basePointer;
                    runtimeStack[stackTop+3] := programCounter;
                    if callArgumentCount > argumentStackTop then
                    begin
                        reportRuntimeError('Procedure call argument stack underflow.');
                        halt(1)
                    end;
                    basePointer := stackTop+1;
                    for argumentIndex := 1 to callArgumentCount do
                        runtimeStack[basePointer + 2 + argumentIndex] :=
                            argumentStack[argumentStackTop - callArgumentCount + argumentIndex];
                    argumentStackTop := argumentStackTop - callArgumentCount;
                    programCounter := argument
                 end ;
            int: stackTop := stackTop+argument;
            jmp: programCounter := argument;
            jpc: begin
                    if runtimeStack[stackTop] = 0 then
                        programCounter := argument;
                    stackTop := stackTop-1
                 end
        end {with, case}
    until programCounter = 0;
    emitDiagnostic(status, STATUS_PCODEINT_END);
end {executePCode} ;

begin {main program}
    if ParamCount < 1 then
    begin
        writeln('Usage: pcodeint <pcode-file> [quiet|all]');
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

    pCodeFileName := ParamStr(1);
    Assign(pCodeFile, pCodeFileName);
    Reset(pCodeFile);
    loadPCodeFile();
    executePCode();
end.
