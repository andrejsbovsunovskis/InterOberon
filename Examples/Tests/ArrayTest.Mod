MODULE ArrayTest;
IMPORT Out;
CONST
  N = 10;
VAR
  a: ARRAY N OF INTEGER;
  i, sum: INTEGER;
BEGIN
  (* Fill array with squares *)
  FOR i := 0 TO N - 1 DO
    a[i] := (i + 1) * (i + 1)
  END;

  (* Print array *)
  FOR i := 0 TO LEN(a) - 1 DO
    Out.Int(a[i], 5)
  END;
  Out.Ln;

  (* Compute sum *)
  sum := 0;
  FOR i := 0 TO N - 1 DO
    sum := sum + a[i]
  END;
  Out.Int(sum, 0);
  Out.Ln
END ArrayTest.
