# Dime Programming Language

![Dime banner](/docs/Banner.png)

Dime Is Wirthian Enough.

Dime is a two-nickel's worth programming language, inspired in the languages designed by Niklaus Wirth.

This project starts from the PL/0 compiler, p-code machine and interpreter described by Niklaus Wirth in his 1976 book Algorithms + Data Structures = Programs.

The idea is to design a language that hopefully will be close to Extended Pascal ISO 10206, while adding features cherrypicked from all the other Wirthian languages (and others, like Ada, Eiffel, Unicon, etc.).

The design of the language will reflect on Wirth's philosophy, keeping it simple and efficient, with an LL(1) grammar and no surprises.

## Project Docs

- [Changelog](CHANGELOG.md)
- [Roadmap](ROADMAP.md)
- [Release Checklist](RELEASING.md)

## Example program: Fizzbuzz

This is the classic fizzbuzz program, you can find the source code in [examples/programs/fizzbuzz.pl0](examples/programs/fizzbuzz.pl0).

```pascal
program fizzbuzz;

const max: integer = 100, three: integer = 3, five: integer = 5,
      cf: char = 'F', cb: char = 'B', cn: char = 'N', cc: char = ':';

var n: integer, fizz: boolean, buzz: boolean,
    cnorm: integer, cfizz: integer, cbuzz: integer, cfb: integer,
    sumcnt: integer;

procedure printsummary;
begin
    write(cn); write(cc); writeln(cnorm);
    write(cf); write(cc); writeln(cfizz);
    write(cb); write(cc); writeln(cbuzz);
    write(cf); write(cb); write(cc); writeln(cfb);
end;

begin
    n := 1;
    cnorm := 0;
    cfizz := 0;
    cbuzz := 0;
    cfb := 0;
    sumcnt := 0;
    while n <= max do
        fizz := n / three * three = n;
        buzz := n / five * five = n;
        if fizz and buzz then
            write(cf);
            writeln(cb);
            cfb := cfb + 1;
        elsif fizz then
            writeln(cf);
            cfizz := cfizz + 1;
        elsif buzz then
            writeln(cb);
            cbuzz := cbuzz + 1;
        else
            writeln(n);
            cnorm := cnorm + 1;
        endif;
        n := n + 1;
    endwhile;
    printsummary();
end.
```
