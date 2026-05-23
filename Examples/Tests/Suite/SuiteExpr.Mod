MODULE SuiteExpr;
(* Expressions and builtins: integer/real ops, FLT/FLOOR in calls. *)
IMPORT Out;

PROCEDURE IntExprPart;
VAR a, b, c, i: INTEGER;
BEGIN
  a := 3; b := 4;
  Out.Int(a + b, 0); Out.Ln;
  Out.Int(a * b - 2, 0); Out.Ln;
  Out.Int(2 + 3 * 4, 0); Out.Ln;
  Out.Int(-(-55), 0); Out.Ln;
  c := (a + b) * 2;
  Out.Int(c, 0); Out.Ln;
  i := 10;
  INC(i);
  Out.Int(i, 0); Out.Ln;
  DEC(i, 3);
  Out.Int(i, 0); Out.Ln;
  IF ODD(7) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  Out.Int(ORD('A'), 0); Out.Ln;
  Out.Int(ORD(CHR(66)), 0); Out.Ln
END IntExprPart;

PROCEDURE RealExprPart;
VAR r, s: REAL; i: INTEGER;
BEGIN
  r := FLT(3) + FLT(4);
  Out.Int(FLOOR(r), 0); Out.Ln;
  r := 1.5;
  i := FLOOR(r);
  Out.Int(FLOOR(r - FLT(i)), 0); Out.Ln;
  Out.Int(FLOOR((r - FLT(i)) * 10.0), 0); Out.Ln;
  r := 1.5;
  i := FLOOR(r);
  s := r - FLT(i);
  r := s * 10.0;
  Out.Int(FLOOR(r), 0); Out.Ln;
  r := 0.5 * 6.0;
  Out.Int(FLOOR(r), 0); Out.Ln;
  IF FLT(3) > FLT(2) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END RealExprPart;

PROCEDURE RealCallPart;
VAR r: REAL; i: INTEGER;

  PROCEDURE Floor10(x: REAL): INTEGER;
  BEGIN RETURN FLOOR(x * 10.0) END Floor10;

BEGIN
  Out.Int(Floor10(0.7), 0); Out.Ln;
  r := 1.5;
  i := FLOOR(r);
  Out.Int(Floor10((r - FLT(i))), 0); Out.Ln;
  Out.RealFix(FLT(3), 0, 1); Out.Ln;
  Out.RealFix((1.5 - FLT(1)) * 10.0, 0, 1); Out.Ln
END RealCallPart;

PROCEDURE ConstSubPart;
VAR c: LONGINT;
BEGIN
  c := 200000;
  c := c - 10000H;
  Out.Int(c, 0); Out.Ln
END ConstSubPart;

BEGIN
  IntExprPart;
  RealExprPart;
  RealCallPart;
  ConstSubPart
END SuiteExpr.
