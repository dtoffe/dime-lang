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
This file contains the compiler.
}

{$modeSwitch nonlocalgoto+}

program compiler {(input,output)};
{PL/0 compiler with code generation}

{label 99;}

uses
  SysUtils;

const norw = 11;    {no. of reserved words}
    txmax = 100;    {length of identifier table}
    nmax = 14;      {max. no. of digits in numbers}
    al = 10;        {length of identifiers}
    amax = 2047;    {maximum address}
    levmax = 3;     {maximum depth of block nesting}
    cxmax = 200;    {size of code array}

type symbol =
        (nul, ident, number, plus, minus, times, slash, oddsym,
        eql, neq, lss, leq, gtr, geq, lparen, rparen, comma, semicolon,
        period, becomes, beginsym, endsym, ifsym, thensym,
        whilesym, dosym, callsym, constsym, varsym, procsym);
    alfa = packed array [1 .. al] of char;
    objkind = (constant, variable, proc);
    symset = set of symbol;
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

var ch: char;           {last character read}
    sym: symbol;        {last symbol read}
    id: alfa;           {last identifier read}
    num: integer;       {last number read}
    cc: integer;        {character count}
    ll: integer;        {line length}
    kk, err: integer;
    cx: integer;        {code allocation index}
    line: array [1..81] of char;
    a: alfa;
    code: array [0..cxmax] of instruction;
    word: array [1..norw] of alfa;
    wsym: array [1..norw] of symbol;
    ssym: array [char] of symbol;
    mnemonic: array [fct] of
                packed array [1 .. 5] of char;
    declbegsys, statbegsys, facbegsys: symset;
    table: array [0..txmax] of
              record name: alfa;
                case kind: objkind of
                  constant: (val: integer);
                  variable, proc: (level, adr: integer)
              end ;

    inputFile, outputFile: Text;
    inputFileName, outputFileName: string;
    i: integer;

procedure cleanExit;
begin
    writeln;
    close(inputFile);
    close(outputFile);
    halt
end {cleanExit} ;

procedure error (n: integer);
begin
    writeln (' ****', ' ': cc - 1, '↑', n:2);
    err := err + 1;
    case n of 
         1: writeln (' Use = instead of :=.');
         2: writeln (' = must be followed by a number.');
         3: writeln (' Identifier must be followed by =.');
         4: writeln (' "const", "var", "procedure" must be followed by an identifier.');
         5: writeln (' Semicolon or comma missing.');
         6: writeln (' Incorrect symbol after procedure declaration.');
         7: writeln (' Statement expected.');
         8: writeln (' Incorrect symbol after statement part in block.');
         9: writeln (' Period expected.');
        10: writeln (' Semicolon between statements is missing.');
        11: writeln (' Undeclared identifier.');
        12: writeln (' Assignment to constant or procedure is not allowed.');
        13: writeln (' Assignment operator := expected.');
        14: writeln (' "call" must be followed by an identifier.');
        15: writeln (' Call of a constant or a variable is meaningless.');
        16: writeln (' "then" expected.');
        17: writeln (' Semicolon or "end" expected.');
        18: writeln (' "do" expected.');
        19: writeln (' Incorrect symbol following statement.');
        20: writeln (' Relational operator expected.');
        21: writeln (' Expression must not contain a procedure identifier.');
        22: writeln (' Right parenthesis missing.');
        23: writeln (' The preceding factor cannot be followed by this symbol.');
        24: writeln (' An expression cannot begin with this symbol.');
        30: writeln (' This number is too large.');
        //31: writeln (' .'); // Not included in code or error messages
        32: writeln (' Only three levels of nesting are supported.')
    end;
    // cleanExit() { goto 99 }
end {error} ;

procedure getsym;
    var i, j, k: integer;

    procedure getch;
    begin
        if cc = ll then
        begin
            if eof(inputfile) then
            begin
                write(' PROGRAM INCOMPLETE');
                cleanExit() { goto 99 }
            end ;
            ll := 0;
            cc := 0;
            write(cx:5, ' ');
            while not eoln(inputFile) do
            begin
                ll := ll + 1;
                read(inputFile, ch);
                //write(ch);
                line[ll] := ch
            end ;
            writeln;
            ll := ll + 1;
            read(inputFile, line[ll])
        end ;
        cc := cc + 1;
        ch := line[cc]
     end {getch} ;

begin {getsym}
    while (ch = ' ') or (ch = chr(10)) or (ch = chr(13)) do
        getch;
    if ch in ['A'..'Z'] then
    begin {identifier or reserved word}
        k := 0;
        repeat
            if k < al then
            begin
                k := k + 1;
                a[k] := ch
            end ;
            getch
        until not (ch in ['A'..'Z', '0'..'9']);
        if k >= kk then
            kk := k
        else
            repeat
                a[kk] := ' ';
                kk := kk - 1
            until kk = k;
        id := a;
        i := 1;
        j := norw;
        repeat
            k := (i + j) div 2;
            if id <= word[k] then
                j := k - 1;
            if id >= word[k] then
                i := k + 1
        until i > j;
        if i-1 > j then
            sym := wsym[k]
        else
            sym := ident
    end
    else
    if ch in ['0'..'9'] then
    begin {number}
        k := 0;
        num := 0;
        sym := number;
        repeat
            num := 10 * num + (ord(ch) - ord('0'));
            k := k + 1;
            getch
        until not (ch in ['0'..'9']);
        if k > nmax then
            error (30)
    end
    else
    if ch = ':' then
    begin
        getch;
        if ch = '=' then
        begin
            sym := becomes;
            getch
        end
        else
            sym := nul;
    end
    else
    begin
        sym := ssym[ch];
        getch
    end;
    // Following output is added for debugging
    write(sym, ' ');
    if sym = ident then
        writeln(id)
    else if sym = number then
        writeln(num)
    else
        writeln
end {getsym} ;

procedure gen(x: fct; y, z: integer);
begin
    if cx > cxmax then
    begin
        write(' PROGRAM TOO LONG');
        {goto 99}
        cleanExit()
    end ;
    with code[cx] do
    begin
        f := x;
        l := y;
        a := z
    end ;
    cx := cx + 1
end {gen} ;

procedure test (s1, s2: symset; n: integer);
begin
    if not (sym in s1) then
    begin
        error(n);
        s1 := s1 + s2;
        while not (sym in s1) do
            getsym
    end
end {test} ;

procedure block (lev, tx: integer; fsys: symset);
    var dx,             {data allocation index}
        tx0,            {initial table index}
        cx0: integer;   {initial code index}

    procedure enter(k: objkind);
    begin {enter object into table}
        tx := tx + 1;
        with table[tx] do
        begin
            name := id;
            kind := k;
            case k of
                constant:
                    begin
                        if num > amax then
                        begin
                            error (30);
                            num := 0
                        end ;
                        val := num
                    end ;
                variable:
                    begin
                        level := lev;
                        adr := dx;
                        dx := dx + 1;
                    end ;
                proc:
                    level := lev
            end
        end
    end {enter} ;

    function position(id: alfa): integer;
        var i: integer;
    begin {find indentifier id in table}
        table[0].name := id;
        i := tx;
        while table[i].name <> id do
            i := i - 1;
        position := i
    end { position} ;

    procedure constdeclaration;
    begin
        if sym = ident then
        begin
            getsym;
            if sym in [eql, becomes] then
            begin
                if sym = becomes then
                    error(1);
                getsym;
                if sym = number then
                begin
                    enter(constant);
                    getsym
                end
                else
                    error (2)
            end
            else
                error (3)
        end
        else
            error (4)
    end {constdeclaration} ;

    procedure vardeclaration;
    begin
        if sym = ident then
        begin
            enter (variable);
            getsym
        end
        else
            error (4)
    end {vardeclaration} ;

    procedure listcode;
        var i: integer;
    begin {list code generated for this block}
        for i := cx0 to cx-1 do
            with code[i] do
                writeln(i, mnemonic[f]:5, l:3, a:5);
    end {listcode} ;

    procedure statement (fsys: symset);
        var i, cx1, cx2: integer;

        procedure expression(fsys: symset);
            var addop: symbol;

            procedure term(fsys: symset);
                var mulop: symbol;

                procedure factor (fsys: symset);
                    var i: integer;
                begin
                    test(facbegsys, fsys, 24);
                    while sym in facbegsys do
                    begin
                        if sym = ident then
                        begin i := position(id);
                            if i = 0 then
                                error (11)
                            else
                                with table[i] do
                                case kind of
                                    constant: gen(lit, 0, val);
                                    variable: gen(lod, lev - level, adr);
                                    proc: error (21)
                                end ;
                                getsym
                        end
                        else
                            if sym = number then
                            begin
                                if num > amax then
                                begin
                                    error (30);
                                    num := 0
                                end ;
                                gen(lit, 0, num); getsym
                            end
                            else
                                if sym = lparen then
                                begin
                                    getsym;
                                    expression([rparen]+fsys);
                                    if sym = rparen then
                                        getsym
                                    else
                                        error (22)
                                end ;
                        test (fsys, [lparen], 23)
                    end
                end { factor} ;

            begin {term}
                factor(fsys+[times, slash]);
                while sym in [times, slash] do
                begin
                    mulop := sym;
                    getsym;
                    factor(fsys+[times, slash]);
                    if mulop = times then
                        gen(opr, 0, 4)
                    else
                        gen(opr, 0, 5)
                end
            end {term} ;

        begin {expression}
            if sym in [plus, minus] then
            begin
                addop := sym;
                getsym;
                term(fsys+[plus, minus]);
                if addop = minus then
                    gen(opr,0,1)
            end
            else
                term(fsys+[plus, minus]);
            while sym in [plus, minus] do
            begin
                addop := sym;
                getsym;
                term(fsys+[plus, minus]);
                if addop = plus then
                    gen(opr,0,2)
                else
                    gen(opr,0,3)
            end
        end {expression} ;

        procedure condition(fsys: symset);
            var relop: symbol;
        begin
            if sym = oddsym then
            begin
                getsym;
                expression(fsys);
                gen(opr,0,6)
            end
            else
            begin
                expression([eql, neq, lss, gtr, leq, geq]+fsys);
                if not (sym in [eql, neq, lss, leq, gtr, geq]) then
                    error (20)
                else
                begin
                    relop := sym;
                    getsym;
                    expression(fsys);
                    case relop of
                        eql: gen(opr,0, 8);
                        neq: gen(opr,0, 9);
                        lss: gen(opr,0,10);
                        geq: gen(opr,0,11);
                        gtr: gen(opr,0,12);
                        leq: gen(opr,0,13);
                    end
                end
            end
        end {condition} ;

    begin {statement}
        if sym = ident then
        begin
            i := position(id);
            if i = 0 then
                error (11)
            else
                if table[i].kind <> variable then
                begin {assignment to non-variable}
                    error (12);
                    i := 0
                end ;
            getsym;
            if sym = becomes then
                getsym
            else
                error (13);
            expression(fsys);
            if i <> 0 then
                with table[i] do
                    gen(sto, lev - level, adr)
        end
        else
            if sym = callsym then
            begin
                getsym;
                if sym <> ident then
                    error (14)
                else
                begin
                    i := position(id);
                    if i = 0 then
                        error (11)
                    else
                        with table[i] do
                            if kind = proc then
                                gen (cal, lev-level, adr)
                            else
                                error (15);
                    getsym
                end
            end
            else
                if sym = ifsym then
                begin
                    getsym;
                    condition([thensym, dosym]+fsys);
                    if sym = thensym then
                        getsym
                    else
                        error (16);
                    cx1 := cx;
                    gen(jpc,0,0);
                    statement(fsys);
                    code[cx1].a := cx
                end
                else
                    if sym = beginsym then
                    begin
                        getsym;
                        statement([semicolon, endsym]+fsys);
                        while sym in [semicolon]+statbegsys do
                        begin
                            if sym = semicolon then
                                getsym
                            else
                                error (10);
                            statement([semicolon, endsym]+fsys)
                        end ;
                        if sym = endsym then
                            getsym
                        else
                            error (17)
                    end
                    else
                        if sym = whilesym then
                        begin
                            cx1 := cx;
                            getsym;
                            condition([dosym]+fsys);
                            cx2 := cx;
                            gen(jpc,0,0);
                            if sym = dosym then
                                getsym
                            else
                                error (18);
                            statement(fsys);
                            gen(jmp, 0, cx1);
                            code[cx2].a := cx
                        end ;
        test(fsys, [ ], 19)
     end {statement} ;

begin {block}
    dx := 3;
    tx0 := tx;
    table[tx].adr := cx;
    gen(jmp,0,0);
    if lev > levmax then
        error (32);
    repeat
        if sym = constsym then
        begin
            getsym;
            repeat
                constdeclaration;
                while sym = comma do
                begin
                    getsym;
                    constdeclaration
                end ;
                if sym = semicolon then
                    getsym
                else
                    error (5)
            until sym <> ident
        end ;
        if sym = varsym then
        begin
            getsym;
            repeat
                vardeclaration;
                while sym = comma do
                begin
                    getsym;
                    vardeclaration
                end ;
                if sym = semicolon then
                    getsym
                else
                    error (5)
            until sym <> ident;
        end ;
        while sym = procsym do
        begin
            getsym;
            if sym = ident then
            begin
                enter(proc);
                getsym
            end
            else
                error (4);
            if sym = semicolon then
                getsym
            else
                error (5);
            block(lev+1, tx, [semicolon]+fsys);
            if sym = semicolon then
            begin
                getsym;
                test(statbegsys+[ident, procsym], fsys, 6)
            end
            else
                error (5)
        end ;
        test(statbegsys+[ident], declbegsys, 7)
    until not(sym in declbegsys);
    code[table[tx0].adr].a := cx;
    with table[tx0] do
    begin
        adr := cx; {start adr of code}
    end ;
    cx0 := cx;
    gen(int, 0, dx);
    statement([semicolon, endsym]+fsys);
    gen(opr, 0, 0); {return}
    test(fsys, [ ], 8);
    listcode;
end {block} ;

begin {main program}
    inputFileName := ParamStr(1);
    Assign(inputFile, inputFileName);
    Reset(inputFile);

    outputFileName := ChangeFileExt(inputFileName, '.pcode');
    //outputFileName := ExtractFileName(outputFileName);
    Assign(outputFile, outputFileName);
    Rewrite(outputFile);
    
    writeln('Processing file: ', inputFileName);
    for ch := 'A' to ';' do
        ssym[ch] := nul;
    word[ 1] := 'BEGIN     ';
    word[ 2] := 'CALL      ';
    word[ 3] := 'CONST     ';
    word[ 4] := 'DO        ';
    word[ 5] := 'END       ';
    word[ 6] := 'IF        ';
    word[ 7] := 'ODD       ';
    word[ 8] := 'PROCEDURE ';
    word[ 9] := 'THEN      ';
    word[10] := 'VAR       ';
    word[11] := 'WHILE     ';
    wsym[ 1] := beginsym;
    wsym[ 2] := callsym;
    wsym[ 3] := constsym;
    wsym[ 4] := dosym;
    wsym[ 5] := endsym;
    wsym[ 6] := ifsym;
    wsym[ 7] := oddsym;
    wsym[ 8] := procsym;
    wsym[ 9] := thensym;
    wsym[10] := varsym;
    wsym[11] := whilesym;
    ssym['+'] := plus;
    ssym['-'] := minus;
    ssym['*'] := times;
    ssym['/'] := slash;
    ssym['('] := lparen;
    ssym[')'] := rparen;
    ssym['='] := eql;
    ssym[','] := comma;
    ssym['.'] := period;
    ssym['#'] := neq;  { non ASCII ≠ "crossed equal symbol" in the book }
    ssym['<'] := lss;
    ssym['>'] := gtr;
    ssym['{'] := leq;  { non ASCII "less than or equal symbol" <=, ≤ in the book }
    ssym['}'] := geq;  { non ASCII "greater than or equal symbol" >=, ≥ in the book }
    ssym[';'] := semicolon;
    mnemonic[lit] := 'LIT  ';
    mnemonic[opr] := 'OPR  ';
    mnemonic[lod] := 'LOD  ';
    mnemonic[sto] := 'STO  ';
    mnemonic[cal] := 'CAL  ';
    mnemonic[int] := 'INT  ';
    mnemonic[jmp] := 'JMP  ';
    mnemonic[jpc] := 'JPC  ';
    declbegsys := [constsym, varsym, procsym];
    statbegsys := [beginsym, callsym, ifsym, whilesym];
    facbegsys := [ident, number, lparen];
    { page(output);  standard library feature of old Pascals to clear screen }
    err := 0;
    cc := 0;
    cx := 0;
    ll := 0;
    ch := ' ';
    kk := al;
    getsym;
    block(0, 0, [period]+declbegsys+statbegsys);
    if sym <> period then
        error (9);
    if err = 0 then
    begin
        write(' PL/O PROGRAM COMPILED SUCCESSFULLY');
        for i := 0 to cxmax do
            with code[i] do
                writeln(outputFile, i, mnemonic[f]:5, l:3, a:5);
    end
    else
        write(' ERRORS IN PL/O PROGRAM');
    {99: writeln}
    cleanExit()
end .
