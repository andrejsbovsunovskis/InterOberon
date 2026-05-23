MODULE DeepExpr;
IMPORT SYSTEM, Out;

VAR res: INTEGER; b: BYTE;

PROCEDURE ValPart;
BEGIN
  IF SYSTEM.VAL(BYTE, 300) = 44 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF SYSTEM.VAL(INTEGER, -1) = -1 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END ValPart;

PROCEDURE AdrPart;
VAR x: INTEGER; a: ARRAY 4 OF INTEGER; d: LONGINT;
BEGIN
  x := 42;
  IF SYSTEM.ADR(x) # 0 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  a[0] := 1; a[1] := 2;
  IF SYSTEM.ADR(a) = SYSTEM.ADR(a[0]) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  d := SYSTEM.ADR(a[1]) - SYSTEM.ADR(a[0]);
  IF d = 1 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END AdrPart;

PROCEDURE ChrOrdPart;
VAR c: CHAR; i: INTEGER;
BEGIN
  c := 65X;
  i := ORD(c);
  Out.Int(i, 0); Out.Ln;
  IF CHR(i) = c THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END ChrOrdPart;

BEGIN
  ValPart;
  AdrPart;
  ChrOrdPart
END DeepExpr.
