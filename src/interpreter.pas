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
    levmax = 3;     {maximum depth of block nesting}
    amax = 2047;    {maximum address}
    cxmax = 200;    {size of code array}

type
    fct = (lit, opr, lod, sto, cal, int, jmp, jpc); {functions}
    instruction = packed record
                    f: fct;          {function code}
                    l: 0..levmax;    {level}
                    a: 0..amax;      {displacement address}
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
    code: array [0..cxmax] of instruction;

    inputFile: Text;
    inputFileName: string;

procedure readCode;

var
    line: string;
    i, status: Integer;
    f_str, l_str, a_str: string;
    index: Integer;

begin
    i := 0;
    while not EOF(inputFile) and (i < cxmax) do
    begin
        // Read one line from the file
        readln(inputFile, line);

        if (line = '') or (line = ' ') then
            continue;

        // Extract the index first (up to the first non-digit)
        index := 0;
        while (index < length(line)) and (line[index+1] >= '0') and (line[index+1] <= '9') do
            index := index + 1;

        // Extract the f, l, and a values based on their fixed widths
        f_str := copy(line, index + 1, 5);
        l_str := copy(line, index + 1 + 5, 3);
        a_str := copy(line, index + 1 + 5 + 3, 5);

writeln(f_str, ' ', l_str, ' ', a_str);
        // Convert the extracted strings to integers
        case f_str of
            'LIT  ' : code[i].f := lit;
            'OPR  ' : code[i].f := opr;
            'LOD  ' : code[i].f := lod;
            'STO  ' : code[i].f := sto;
            'CAL  ' : code[i].f := cal;
            'INT  ' : code[i].f := int;
            'JMP  ' : code[i].f := jmp;
            'JPC  ' : code[i].f := jpc;
        end;

        Val(l_str, code[i].l, status);
        if status <> 0 then
            writeln('Error converting l-value');

        Val(a_str, code[i].a, status);
        if status <> 0 then
            writeln('Error converting a-value');

        // Increment the counter for the next record
        i := i + 1;

    end;

    // Close the file
    Close(inputFile);

    writeln('Reading complete.');
    writeln('Records loaded: ', i);

end;

procedure interpret;
    const stacksize = 500;
    var p, b, t: integer; {program-, base-, topstack-registers}
        i: instruction; {instruction register}
        s: array [1..stacksize] of integer; {datastore}

    function base(l: integer): integer;
        var b1: integer;
    begin b1 := b; {find base l levels down}
        while l > 0 do
            begin b1 := s[b1]; l := l-1
            end ;
        base := b1
     end {base} ;

begin writeln(' START PL/0');
    t := 0; b := 1; p := 0;
    s[1] := 0; s[2] := 0; s[3] := 0;
    repeat
        i := code[p];
        writeln(i.f, ' ', i.l, ' ', i.a);
        p := p + 1;
        with i do
        case f of
            lit: begin t := t+1; s[t] := a
                 end ;
            opr: case a of {operator}
                 0: begin {return}
                        t := b-1; p := s[t+3]; b := s[t+2]
                    end ;
                 1: s[t] := -s[t];
                 2: begin t := t-1; s[t] := s[t] + s[t+1]
                    end ;
                 3: begin t := t-1; s[t] := s[t] - s[t+1]
                    end ;
                 4: begin t := t-1; s[t] := s[t] * s[t+1]
                    end ;
                 5: begin t := t-1; s[t] := s[t] div s[t+1]
                    end ;
                 6: s[t] := ord(odd(s[t]));
                 8: begin t := t-1; s[t] := ord(s[t]=s[t+1])
                    end ;
                 9: begin t := t-1; s[t] := ord(s[t]<>s[t+1])
                    end ;
                10: begin t := t-1; s[t] := ord(s[t]<s[t+1])
                    end ;
                11: begin t := t-1; s[t] := ord(s[t]>=s[t+1])
                    end ;
                12: begin t := t-1; s[t] := ord(s[t]>s[t+1])
                    end ;
                13: begin t := t-1; s[t] := ord(s[t]<=s[t+1])
                    end ;
                end ;
            lod: begin t := t+1; s[t] := s[base(l)+a]
                 end ;
            sto: begin s[base(l)+a] := s[t]; writeln(s[t]); t := t-1
                 end ;
            cal: begin {generate new block mark}
                    s[t+1] := base(l); s[t+2] := b; s[t+3] := p;
                    b := t+1; p := a
                 end ;
            int: t := t+a;
            jmp: p := a;
            jpc: begin if s[t] = 0 then p := a; t := t-1
                 end
        end {with, case}
    until p = 0;
    write(' END PL/0');
end {interpret} ;

begin {main program}
    inputFileName := ParamStr(1);
    Assign(inputFile, inputFileName);
    Reset(inputFile);
    readCode();
    interpret();
end .
