MODULE DeepInts;
IMPORT Out;

VAR res: INTEGER;

PROCEDURE BytePart;
VAR b1, b2: BYTE; i: INTEGER;
BEGIN
  b1 := 50; b2 := 30;
  IF b1 > b2 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  b1 := 200; i := 100;
  IF b1 > i THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  i := ORD(b1) + ORD(b2);
  Out.Int(i, 0); Out.Ln;
  b1 := 255;
  IF ORD(b1) = 255 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END BytePart;

PROCEDURE TinyPart;
VAR a, b: SHORTINT;
BEGIN
  a := -3; b := 5;
  IF a + b = 2 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF ASR(a, 1) = -2 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END TinyPart;

PROCEDURE DivModPart;
VAR i, j: INTEGER;
BEGIN
  i := 17; j := 5;
  Out.Int(i DIV j, 0); Out.Ln;
  Out.Int(i MOD j, 0); Out.Ln;
  i := -17;
  Out.Int(i DIV 5, 0); Out.Ln;
  Out.Int(i MOD 5, 0); Out.Ln;
  i := 0; j := 99;
  Out.Int(j DIV (i + 1), 0); Out.Ln
END DivModPart;

PROCEDURE ShiftPart;
VAR i: INTEGER;
BEGIN
  i := LSL(3, 4);
  Out.Int(i, 0); Out.Ln;
  i := ASR(256, 3);
  Out.Int(i, 0); Out.Ln;
  i := ROR(0F0H, 4);
  Out.Int(i, 0); Out.Ln
END ShiftPart;

PROCEDURE OddAbsPart;
BEGIN
  IF ODD(7) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF ~ODD(8) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF ABS(-9) = 9 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END OddAbsPart;

BEGIN
  BytePart;
  TinyPart;
  DivModPart;
  ShiftPart;
  OddAbsPart
END DeepInts.
