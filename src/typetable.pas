{ Copyright (c) 2026 Alejandro Daniel Toffetti
  License: MIT. See LICENSE in the project root.
  Date: 2026-05-24

  Simple type table definitions shared by the parser, AST, symbol table, and
  later passes.  This unit currently models only scalar built-in types and is
  intentionally minimal until structured types are introduced. }
unit typetable;

{$mode objfpc}

interface

type
  typeValue = (typeInteger, typeBoolean);

implementation

end.
