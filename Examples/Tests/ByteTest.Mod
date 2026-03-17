MODULE ByteTest;
IMPORT Out;
VAR b1, b2: BYTE; i: INTEGER;
BEGIN
  (* 1. BYTE assignment and print: 42 *)
  b1 := 42;
  Out.Int(ORD(b1), 0); Out.Ln;

  (* 2. BYTE arithmetic (addition): 10 + 20 = 30 *)
  b1 := 10; b2 := 20;
  i := ORD(b1) + ORD(b2);
  Out.Int(i, 0); Out.Ln;

  (* 3. BYTE to INTEGER assignment: 255 *)
  b1 := 255;
  i := ORD(b1);
  Out.Int(i, 0); Out.Ln;

  (* 4. INTEGER to BYTE assignment: 100 *)
  i := 100;
  b1 := i;
  Out.Int(ORD(b1), 0); Out.Ln;

  (* 5. BYTE multiplication: 12 * 10 = 120 *)
  b1 := 12;
  i := ORD(b1) * 10;
  Out.Int(i, 0); Out.Ln;

  (* 6. BYTE comparison: 50 > 30 → 1 *)
  b1 := 50; b2 := 30;
  IF b1 > b2 THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;

  (* 7. BYTE comparison with INTEGER: 200 > 100 → 1 *)
  b1 := 200; i := 100;
  IF b1 > i THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 8. BYTE zero: 0 *)
  b1 := 0;
  Out.Int(ORD(b1), 0); Out.Ln;

  (* 9. BYTE in expression: (5 + 3) * 2 = 16 *)
  b1 := 5; b2 := 3;
  i := (ORD(b1) + ORD(b2)) * 2;
  Out.Int(i, 0); Out.Ln;

  (* 10. INC on BYTE: 99 + 1 = 100 *)
  b1 := 99;
  INC(b1);
  Out.Int(ORD(b1), 0); Out.Ln
END ByteTest.
