MODULE DeepReals;
IMPORT Out;

VAR res: INTEGER;

PROCEDURE ArithPart;
VAR x, y, z: REAL;
BEGIN
  x := 1.5; y := 2.0;
  z := x + y;
  IF z > 3.4 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  z := x * y;
  IF z > 2.9 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END ArithPart;

PROCEDURE LongPart;
VAR lr: LONGREAL; i: INTEGER; li: LONGINT;
BEGIN
  lr := 3.14;
  i := FLOOR(lr);
  Out.Int(i, 0); Out.Ln;
  li := ENTIER(lr);
  Out.Int(li, 0); Out.Ln
END LongPart;

PROCEDURE CmpPart;
VAR a, b: REAL;
BEGIN
  a := 1.0; b := 1.0;
  IF a = b THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF a # b + 1.0 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END CmpPart;

BEGIN
  ArithPart;
  LongPart;
  CmpPart
END DeepReals.
