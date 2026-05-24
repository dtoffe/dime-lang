{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-21

  Defines lexical symbols and token payload types shared by the lexer, parser,
  and later passes.  This unit owns token names, identifier/string storage
  limits, and the token record shape.  It should not scan source text or assign
  meaning to identifiers. }

unit tokens;

{$mode objfpc}

interface

const
    maxIdentLength = 10;
    maxNumericValue = 2047;
    maxLexicalNestingLevel = 1;

type
    { Lexical symbols produced by lexer.pas.  Reserved words are represented by
      their own symbols, while user names use ident and carry identValue in the
      token record.

      This list is intentionally limited to the symbols supported by the
      current compiler/grammar.  Future roadmap symbols should be added back
      only when the lexer and parser implement them. }
    symbol =
        (nul, ident, number, plus, minus, times, slash,
        eql, neq, lss, leq, gtr, geq, lparen, rparen, comma, semicolon,
        period, colon, becomes, beginsym, endsym, ifsym, thensym,
        whilesym, dosym, callsym, constsym, varsym, procsym, integersym);
    symbolSet = set of symbol;

    identifier = packed array [1 .. maxIdentLength] of char;

    { A token is the lexer output consumed by the parser.  Payload fields are
      meaningful only for matching token kinds:
        identValue    ident
        numberValue   number
      line and column identify the start of the token for diagnostics and AST
      source locations. }
    token = record
                    kind: symbol;
                    identValue: identifier;
                    numberValue: integer;
                    line: integer;
                    column: integer;
                end;

implementation

end.
