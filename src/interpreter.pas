{
From the book Algorithms + Data Structures = Programs, by Niklaus Wirth (1976)

Chapter 5, page 337

Program 5.6 PL/O Compiler with Code Generation

OCRed, cleaned, fixed, formatted, converted to modern Free Pascal
and tested by Daniel Toffetti.
Formatted with PTop (https://wiki.freepascal.org/PTop)


NOTE: This is a modified version of the original Program 5.6, changing
the code generation so that the code is emitted directly to a file, and
moving the interpreter to a separate program that reads the p-code from
the file and executes it.
This file contains the interpreter.
}

program interpreter;

const
    maxNestingLevel = 3;    {maximum depth of block nesting}
    maxAddress = 2047;      {maximum address}
    codeMaxIndex = 200;     {maximum code array index}

type
    opcode = (lit, opr, lod, sto, cal, int, jmp, jpc); {functions}
    pCodeInstruction = packed record
                    operation: opcode;             {function code}
                    lexicalLevel: 0..maxNestingLevel;    {level}
                    argument: 0..maxAddress;             {displacement address}
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
    pCode: array [0..codeMaxIndex] of pCodeInstruction;

    pCodeFile: Text;
    pCodeFileName: string;

procedure readCode;

var
    pCodeLine: string;
    instructionIndex, conversionStatus: Integer;
    opcodeText, lexicalLevelText, argumentText: string;
    lineIndexWidth: Integer;

begin
    instructionIndex := 0;
    while not EOF(pCodeFile) and (instructionIndex < codeMaxIndex) do
    begin
        // Read one line from the file
        readln(pCodeFile, pCodeLine);

        if (pCodeLine = '') or (pCodeLine = ' ') then
            continue;

        // Extract the index first (up to the first non-digit)
        lineIndexWidth := 0;
        while (lineIndexWidth < length(pCodeLine)) and
              (pCodeLine[lineIndexWidth+1] >= '0') and
              (pCodeLine[lineIndexWidth+1] <= '9') do
            lineIndexWidth := lineIndexWidth + 1;

        // Extract the f, l, and a values based on their fixed widths
        opcodeText := copy(pCodeLine, lineIndexWidth + 1, 5);
        lexicalLevelText := copy(pCodeLine, lineIndexWidth + 1 + 5, 3);
        argumentText := copy(pCodeLine, lineIndexWidth + 1 + 5 + 3, 5);

writeln(opcodeText, ' ', lexicalLevelText, ' ', argumentText);
        // Convert the extracted strings to integers
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
            writeln('Error converting l-value');

        Val(argumentText, pCode[instructionIndex].argument, conversionStatus);
        if conversionStatus <> 0 then
            writeln('Error converting a-value');

        // Increment the counter for the next record
        instructionIndex := instructionIndex + 1;

    end;

    // Close the file
    Close(pCodeFile);

    writeln('Reading complete.');
    writeln('Records loaded: ', instructionIndex);

end;

procedure interpret;

    const stackMaxSize = 500;
    var programCounter, basePointer, stackTop: integer; {program-, base-, topstack-registers}
        instructionRegister: pCodeInstruction; {instruction register}
        runtimeStack: array [1..stackMaxSize] of integer; {datastore}

    function base(lexicalLevelsOutward: integer): integer;
        var enclosingBasePointer: integer;
    begin enclosingBasePointer := basePointer; {find base l levels down}
        while lexicalLevelsOutward > 0 do
            begin
                enclosingBasePointer := runtimeStack[enclosingBasePointer];
                lexicalLevelsOutward := lexicalLevelsOutward - 1
            end ;
        base := enclosingBasePointer
     end {base} ;

begin writeln(' START PL/0');
    stackTop := 0; basePointer := 1; programCounter := 0;
    runtimeStack[1] := 0; runtimeStack[2] := 0; runtimeStack[3] := 0;
    repeat
        instructionRegister := pCode[programCounter];
        writeln(instructionRegister.operation, ' ', instructionRegister.lexicalLevel,
                ' ', instructionRegister.argument);
        programCounter := programCounter + 1;
        with instructionRegister do
        case operation of
            lit: begin stackTop := stackTop+1; runtimeStack[stackTop] := argument
                 end ;
            opr: case argument of {operator}
                 0: begin {return}
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
                 6: runtimeStack[stackTop] := ord(odd(runtimeStack[stackTop]));
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
                end ;
            lod: begin stackTop := stackTop+1;
                    runtimeStack[stackTop] := runtimeStack[base(lexicalLevel)+argument]
                 end ;
            sto: begin
                    runtimeStack[base(lexicalLevel)+argument] := runtimeStack[stackTop];
                    writeln(runtimeStack[stackTop]);
                    stackTop := stackTop-1
                 end ;
            cal: begin {generate new block mark}
                    runtimeStack[stackTop+1] := base(lexicalLevel);
                    runtimeStack[stackTop+2] := basePointer;
                    runtimeStack[stackTop+3] := programCounter;
                    basePointer := stackTop+1;
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
    write(' END PL/0');
end {interpret} ;

begin {main program}
    pCodeFileName := ParamStr(1);
    Assign(pCodeFile, pCodeFileName);
    Reset(pCodeFile);
    readCode();
    interpret();
end .
