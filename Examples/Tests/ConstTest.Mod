MODULE ConstTest;
IMPORT Out;
CONST
  Zero = 0;
  One = 1;
  Ten = 10;
  Hundred = 100;
  Neg = -42;
  Big = 1000000;
  MaxByte = 0FFH;
  Letter = 41H;
  Sum = Ten + Hundred;
  Diff = Hundred - Ten;
  Prod = Ten * Ten;
  Quot = Hundred DIV Ten;
  Rem = Hundred MOD 7;
VAR
  x: INTEGER;
  a: ARRAY Ten OF INTEGER;
  i: INTEGER;
BEGIN
  (* 1. Simple integer const *)
  Out.Int(Ten, 0); Out.Ln;

  (* 2. Negative const *)
  Out.Int(Neg, 0); Out.Ln;

  (* 3. Zero const *)
  Out.Int(Zero, 0); Out.Ln;

  (* 4. Large const *)
  Out.Int(Big, 0); Out.Ln;

  (* 5. Hex const as integer: 0FFH = 255 *)
  Out.Int(MaxByte, 0); Out.Ln;

  (* 6. Hex const as char code: CHR(41H) = 'A' *)
  Out.Char(CHR(Letter)); Out.Ln;

  (* 7. Const expression: Sum = 110 *)
  Out.Int(Sum, 0); Out.Ln;

  (* 8. Const expression: Diff = 90 *)
  Out.Int(Diff, 0); Out.Ln;

  (* 9. Const expression: Prod = 100 *)
  Out.Int(Prod, 0); Out.Ln;

  (* 10. Const expression: Quot = 10 *)
  Out.Int(Quot, 0); Out.Ln;

  (* 11. Const expression: Rem = 2 *)
  Out.Int(Rem, 0); Out.Ln;

  (* 12. Const in assignment *)
  x := Hundred + Neg;
  Out.Int(x, 0); Out.Ln;

  (* 13. Const in comparison *)
  IF Ten < Hundred THEN Out.Int(One, 0) ELSE Out.Int(Zero, 0) END;
  Out.Ln;

  (* 14. Const as array size, fill and sum *)
  FOR i := 0 TO Ten - 1 DO
    a[i] := i + 1
  END;
  x := 0;
  FOR i := 0 TO Ten - 1 DO
    x := x + a[i]
  END;
  Out.Int(x, 0); Out.Ln;

  (* 15. Const in arithmetic expression *)
  x := (Hundred + Neg) * Ten DIV Prod;
  Out.Int(x, 0); Out.Ln
END ConstTest.
