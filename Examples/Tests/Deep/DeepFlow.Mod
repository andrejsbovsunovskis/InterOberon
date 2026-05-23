MODULE DeepFlow;
IMPORT Out;

VAR res: INTEGER;

PROCEDURE CasePart;
VAR x, y: INTEGER;
BEGIN
  x := 2;
  CASE x OF
    0: y := 10 |
    1: y := 20 |
    2: y := 30
  END;
  Out.Int(y, 0); Out.Ln;
  x := 5;
  CASE x OF
    1: y := 1 |
    2: y := 2 |
    5: y := 7
  END;
  Out.Int(y, 0); Out.Ln
END CasePart;

PROCEDURE ForPart;
VAR i, s: INTEGER;
BEGIN
  s := 0;
  FOR i := 1 TO 5 DO s := s + i END;
  Out.Int(s, 0); Out.Ln;
  s := 0;
  FOR i := 1 TO 0 DO s := 1 END;
  Out.Int(s, 0); Out.Ln;
  s := 0;
  FOR i := 0 TO 4 BY 2 DO s := s + i END;
  Out.Int(s, 0); Out.Ln
END ForPart;

PROCEDURE RepeatPart;
VAR n: INTEGER;
BEGIN
  n := 0;
  REPEAT
    INC(n)
  UNTIL n = 4;
  Out.Int(n, 0); Out.Ln
END RepeatPart;

PROCEDURE WhilePart;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE i # 3 DO INC(i) END;
  Out.Int(i, 0); Out.Ln
END WhilePart;

PROCEDURE BoolPart;
VAR a, b: INTEGER;
BEGIN
  a := 0; b := 1;
  IF a # 0 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF (a = 0) OR (b = 1) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF (a = 1) & (b = 1) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END BoolPart;

BEGIN
  CasePart;
  ForPart;
  RepeatPart;
  WhilePart;
  BoolPart
END DeepFlow.
