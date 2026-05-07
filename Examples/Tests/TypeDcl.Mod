MODULE TypeDcl;
IMPORT Out;

CONST N = 5;

TYPE
  MyInt = INTEGER;
  Vec = ARRAY N OF INTEGER;

VAR
  x: MyInt;
  a: Vec;
  i: INTEGER;

PROCEDURE DoubleInt(n: MyInt): MyInt;
RETURN n * 2 END DoubleInt;

PROCEDURE ScaleVec(VAR v: Vec; factor: MyInt);
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO N - 1 DO v[i] := v[i] * factor END
END ScaleVec;

BEGIN
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
  END
END TypeDcl.
