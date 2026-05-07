MODULE SuiteByteShift;
IMPORT Out;

PROCEDURE BytePart;
VAR b1, b2: BYTE; i: INTEGER;
BEGIN
  b1 := 42;
  Out.Int(ORD(b1), 0); Out.Ln;
  b1 := 10; b2 := 20;
  i := ORD(b1) + ORD(b2);
  Out.Int(i, 0); Out.Ln;
  b1 := 255;
  i := ORD(b1);
  Out.Int(i, 0); Out.Ln;
  i := 100;
  b1 := i;
  Out.Int(ORD(b1), 0); Out.Ln;
  b1 := 12;
  i := ORD(b1) * 10;
  Out.Int(i, 0); Out.Ln;
  b1 := 50; b2 := 30;
  IF b1 > b2 THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;
  b1 := 200; i := 100;
  IF b1 > i THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  b1 := 0;
  Out.Int(ORD(b1), 0); Out.Ln;
  b1 := 5; b2 := 3;
  i := (ORD(b1) + ORD(b2)) * 2;
  Out.Int(i, 0); Out.Ln;
  b1 := 99;
  INC(b1);
  Out.Int(ORD(b1), 0); Out.Ln
END BytePart;

PROCEDURE ShiftPart;
VAR a, b, res: INTEGER;
BEGIN
  res := LSL(1, 4);
  Out.Int(res, 0); Out.Ln;
  res := LSL(3, 8);
  Out.Int(res, 0); Out.Ln;
  res := ASR(256, 4);
  Out.Int(res, 0); Out.Ln;
  res := ASR(1024, 3);
  Out.Int(res, 0); Out.Ln;
  res := ASR(-16, 2);
  Out.Int(res, 0); Out.Ln;
  a := 5;
  res := LSL(a, 3);
  Out.Int(res, 0); Out.Ln;
  a := 80;
  res := ASR(a, 2);
  Out.Int(res, 0); Out.Ln;
  res := ASR(LSL(7, 5), 5);
  Out.Int(res, 0); Out.Ln;
  res := LSL(42, 0);
  Out.Int(res, 0); Out.Ln;
  res := ASR(99, 0);
  Out.Int(res, 0); Out.Ln;
  a := 1; b := 10;
  res := LSL(a, b);
  Out.Int(res, 0); Out.Ln;
  a := 2048; b := 5;
  res := ASR(a, b);
  Out.Int(res, 0); Out.Ln;
  a := 256;
  res := ROR(a, 4);
  Out.Int(res, 0); Out.Ln;
  res := LSL(1, 20);
  Out.Int(res, 0); Out.Ln;
  res := ASR(1048576, 20);
  Out.Int(res, 0); Out.Ln;
  res := LSL(LSL(1, 3), 2);
  Out.Int(res, 0); Out.Ln;
  Out.Char('O'); Out.Char('K'); Out.Ln
END ShiftPart;

BEGIN
  BytePart; ShiftPart
END SuiteByteShift.
