# Dime Programming Language

![Dime banner](/docs/Banner.png)

Dime Is Wirthian Enough.

Dime is a two-nickel's worth programming language, inspired in the languages designed by Niklaus Wirth.

This project starts from the PL/0 compiler, p-code machine and interpreter described by Niklaus Wirth in his 1976 book Algorithms + Data Structures = Programs.

The idea is to design a language that hopefully will be close to Extended Pascal ISO 10206, while adding features cherrypicked from all the other Wirthian languages (and others, like Ada, Eiffel, Unicon, etc.).

The design of the language will reflect on Wirth's philosophy, keeping it simple and efficient, with an LL(1) grammar and no surprises.

## Motivation

Dime exists because the Wirthian family contains many ideas worth preserving, but none of the established descendants is quite the target of this project.

This section is intentionally opinionated. It is not meant as a dismissal of Pascal, Modula, Oberon, Ada, or Eiffel. On the contrary: Dime is being designed precisely because these languages contain too many good ideas to ignore. The problem is that, taken as complete languages and language families, they also carry tradeoffs that are awkward for a small, bootstrap-friendly, implementation-minded project.

### Pascal

Pascal is the obvious starting point because it gave the family its crisp statement syntax, readable type declarations, and approachable procedural core. But "Pascal" quickly became many Pascals: the original reports, ISO Pascal, Extended Pascal, UCSD Pascal, Turbo Pascal, Object Pascal, Delphi, and Free Pascal all overlap without being fully identical.

From Dime's point of view, Pascal has two recurring problems. First, the language family fragmented into dialects faster than it converged on one stable, small core. Second, each attempt to fix Pascal's omissions tended to grow the language in a different direction: modules here, objects there, implementation extensions somewhere else, and compatibility baggage everywhere. For example, Free Pascal supports traditional and extended records, old style Turbo Pascal objects and modern Delphi style classes, while Oberon does away with just one type of construct. Dime wants Pascal's clarity without inheriting the full dialect maze.

### Modula

Modula is compelling because it addresses many of Pascal's weaknesses, and in many ways it feels like the "Pascal, but better structured" branch of the tree. For example, Modula fixes the 'dangling else' problem, and offers better safety, relying on escape hatches via `SYSTEM` modules to access unsafe features.

The trouble is that Modula also became plural. There is early and very primitive Modula, then Modula-2 and Modula-3, in several book-defined editions and vendor implementations with specific non standard features. Moreover, while there are at least two major Pascal implementation around (Free Pascal and Delphi) and some other smaller ones, there is no mainstream Modula-2 or Modula-3 implementation widely available today. Dime wants the discipline of modules, explicit structure, and a focus on safety, but without adopting a family whose own history became dialect-heavy.

### Oberon

Oberon is attractive for the opposite reason: where Pascal and Modula often grew by addition, Oberon often improved by subtraction. Its small reports, lean syntax, and refusal to pile on features are deeply aligned with the spirit of this project.

But Oberon also demonstrates a different problem. The family split into Oberon, Oberon-2, Oberon-07, Component Pascal, Active Oberon, and other related descendants, each preserving a different answer to "what should the next minimal language include?" Some versions favor fewer features, others add methods, component models, or concurrency. Dime wants to learn from Oberon's restraint without tying itself to one already-diverged Oberon branch.

### Ada

Ada was not designed by Wirth, but it is somehow Wirthian in style, and it is important here because it solved several hard language-design problems with seriousness: packages, explicit interfaces, generics, strong typing, range checking, tasking, and careful attention to large-system engineering.

From Dime's perspective, Ada's weakness is not conceptual quality but scale. Ada is a large language with a large standard world around it. That makes it powerful, but also expensive to implement, explain, bootstrap, and keep mentally present as a compact whole. Dime is interested in Ada's discipline, not in reproducing Ada's full surface area.

### Eiffel

Eiffel matters because it keeps alive another important tradition: a language should help express program intent, not just control flow. Design by Contract, uniform object semantics, genericity, and an emphasis on software construction all make Eiffel more intellectually interesting than its popularity would suggest.

The friction, for this project, is that Eiffel is built around a much heavier object-oriented center than Dime wants. Its full model brings along substantial runtime expectations, rich class-library conventions, and some long-running type-system complications around covariance and related safety questions. Dime would rather borrow the spirit of clear contracts and semantic precision than inherit Eiffel's whole object model.

### What Dime Wants Instead

Dime is not trying to "beat" these languages. It is trying to sit at a different point in the design space:

- smaller than Ada and Eiffel
- less fragmented than the Pascal, Modula, and Oberon families became in practice
- safe but efficient, offering memory layout control and data representation strategies
- more pragmatic and approachable than the purest Oberon minimalism

In short, the project is motivated by a simple wish: keep the Wirthian taste for clarity and economy, recover the best missing pieces from later languages, and stop before the language turns into a museum of accumulated features.

While the general idea is to borrow and cherrypick features from all of them, and likely many other languages not mentioned here, at this stage there is no complete definition of the Dime language. Dime's design is a work in progress, and the language is not yet ready for public use.

## Project Docs

- [Changelog](CHANGELOG.md)
- [Roadmap](ROADMAP.md)
- [Release Checklist](RELEASING.md)
- [LLIR](docs/LLIR.md)

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
    cnorm := 0;
    cfizz := 0;
    cbuzz := 0;
    cfb := 0;
    sumcnt := 0;
    for n := 1 to max by 1 do
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
    endfor;
    printsummary();
end.
```

## Running the Toolchain

Compile a source file once:

```sh
./src/dimec examples/programs/fizzbuzz.pl0 [quiet|all]
```

That writes the current intermediate and target files beside the source:

```text
examples/programs/fizzbuzz.hlir
examples/programs/fizzbuzz.llir
examples/programs/fizzbuzz.pcode
```

Run the p-code image with the p-code interpreter:

```sh
./src/pcodeint examples/programs/fizzbuzz.pcode [quiet|all]
```

Run the LLIR image with the LLIR interpreter:

```sh
./src/llirint examples/programs/fizzbuzz.llir [quiet|all]
```
