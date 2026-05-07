MODULE SuiteTypeMix;
IMPORT Out;
CONST
  N = 5;
  Zero = 0;
  One = 1;
  Ten = 10;
  Hundred = 100;
  Neg = -42;
  Big = 1000000;
  MaxByte = 0FFH;
  Letter = 41H;
  SumC = Ten + Hundred;
  Diff = Hundred - Ten;
  Prod = Ten * Ten;
  Quot = Hundred DIV Ten;
  Rem = Hundred MOD 7;
TYPE
  MyInt = INTEGER;
  Vec = ARRAY N OF INTEGER;
VAR
  si: SHORTINT;
  li: LONGINT;
  ls: LONGSET;
  i, j: INTEGER;
  s: SET;
  x: MyInt;
  a: Vec;
  cx: INTEGER;
  ca: ARRAY Ten OF INTEGER;
  b: BYTE;
  r: REAL;

PROCEDURE DoubleInt(n: MyInt): MyInt;
RETURN n * 2 END DoubleInt;

PROCEDURE ScaleVec(VAR v: Vec; factor: MyInt);
VAR k: INTEGER;
BEGIN
  FOR k := 0 TO N - 1 DO v[k] := v[k] * factor END
END ScaleVec;

BEGIN
  (* TypeTest *)
  si := 100;
  Out.Int(si, 0); Out.Ln;
  si := -1;
  Out.Int(si, 0); Out.Ln;
  si := 200;
  si := si + 50;
  Out.Int(si, 0); Out.Ln;
  si := -5;
  IF si < 0 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  li := 1000000;
  Out.Int(SHORT(li), 0); Out.Ln;
  li := -42;
  Out.Int(SHORT(li), 0); Out.Ln;
  li := 999;
  li := li * 1000;
  Out.Int(SHORT(li), 0); Out.Ln;
  ls := {};
  INCL(ls, 5);
  IF 5 IN ls THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  i := 42;
  si := SHORT(i);
  Out.Int(si, 0); Out.Ln;
  i := 777;
  li := i;
  Out.Int(SHORT(li), 0); Out.Ln;
  s := {1, 3, 5};
  ls := s;
  IF 3 IN ls THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* TypeDcl *)
  x := 42;
  Out.Int(x, 0); Out.Ln;
  Out.Int(DoubleInt(x), 0); Out.Ln;
  FOR i := 0 TO N - 1 DO
    a[i] := (i + 1) * 10
  END;
  FOR i := 0 TO N - 1 DO
    Out.Int(a[i], 0); Out.Ln
  END;
  ScaleVec(a, 3);
  FOR i := 0 TO N - 1 DO
    Out.Int(a[i], 0); Out.Ln
  END;

  (* ConstTest *)
  Out.Int(Ten, 0); Out.Ln;
  Out.Int(Neg, 0); Out.Ln;
  Out.Int(Zero, 0); Out.Ln;
  Out.Int(Big, 0); Out.Ln;
  Out.Int(MaxByte, 0); Out.Ln;
  Out.Char(CHR(Letter)); Out.Ln;
  Out.Int(SumC, 0); Out.Ln;
  Out.Int(Diff, 0); Out.Ln;
  Out.Int(Prod, 0); Out.Ln;
  Out.Int(Quot, 0); Out.Ln;
  Out.Int(Rem, 0); Out.Ln;
  cx := Hundred + Neg;
  Out.Int(cx, 0); Out.Ln;
  IF Ten < Hundred THEN Out.Int(One, 0) ELSE Out.Int(Zero, 0) END;
  Out.Ln;
  FOR i := 0 TO Ten - 1 DO
    ca[i] := i + 1
  END;
  cx := 0;
  FOR i := 0 TO Ten - 1 DO
    cx := cx + ca[i]
  END;
  Out.Int(cx, 0); Out.Ln;
  cx := (Hundred + Neg) * Ten DIV Prod;
  Out.Int(cx, 0); Out.Ln;

  (* MixType *)
  si := 127;
  i := si;
  Out.Int(i, 0); Out.Ln;
  i := 999999;
  li := i;
  Out.Int(SHORT(li), 0); Out.Ln;
  b := 200;
  i := ORD(b);
  Out.Int(i, 0); Out.Ln;
  i := 42;
  r := FLT(i);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  si := 50;
  si := si + 30;
  Out.Int(si, 0); Out.Ln;
  si := -100;
  Out.Int(si, 0); Out.Ln;
  li := 2000000;
  Out.Int(SHORT(li), 0); Out.Ln;
  li := 500000;
  li := li * 4;
  Out.Int(SHORT(li), 0); Out.Ln;
  b := 255;
  Out.Int(ORD(b), 0); Out.Ln;
  b := 0;
  Out.Int(ORD(b), 0); Out.Ln;
  s := {1, 5, 10};
  ls := s;
  IF 5 IN ls THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  ls := {};
  INCL(ls, 5);
  INCL(ls, 10);
  IF 5 IN ls THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  r := FLT(100);
  r := r / FLT(3);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := -FLT(7);
  r := r + FLT(10);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  si := 10;
  i := si;
  li := i;
  li := li * 100;
  Out.Int(SHORT(li), 0); Out.Ln
END SuiteTypeMix.
