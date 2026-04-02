MODULE Array5;
IMPORT Out;
VAR
  ab: ARRAY 5 OF BYTE;
  as: ARRAY 4 OF SHORTINT;
  ai: ARRAY 3 OF INTEGER;
  al: ARRAY 3 OF LONGINT;
  ar: ARRAY 3 OF REAL;
  aset: ARRAY 3 OF SET;
  abool: ARRAY 4 OF BOOLEAN;

  ms: ARRAY 2, 3 OF SHORTINT;
  mb: ARRAY 3, 4 OF BYTE;

  i, j, sum: INTEGER;
  lsum: LONGINT;
BEGIN
  (* 1. BYTE array *)
  FOR i := 0 TO 4 DO ab[i] := i * 10 END;
  sum := 0;
  FOR i := 0 TO 4 DO sum := sum + ab[i] END;
  Out.Int(sum, 0); Out.Ln;

  (* 2. SHORTINT array *)
  as[0] := 100; as[1] := 200; as[2] := -300; as[3] := 400;
  sum := 0;
  FOR i := 0 TO 3 DO sum := sum + as[i] END;
  Out.Int(sum, 0); Out.Ln;

  (* 3. INTEGER array *)
  ai[0] := 100000; ai[1] := 200000; ai[2] := -50000;
  sum := 0;
  FOR i := 0 TO 2 DO sum := sum + ai[i] END;
  Out.Int(sum, 0); Out.Ln;

  (* 4. LONGINT array *)
  al[0] := 100000; al[1] := 200000; al[2] := 300000;
  lsum := 0;
  FOR i := 0 TO 2 DO lsum := lsum + al[i] END;
  Out.Int(SHORT(lsum), 0); Out.Ln;

  (* 5. REAL array *)
  ar[0] := FLT(10);
  ar[1] := FLT(20);
  ar[2] := FLT(30);
  Out.Int(FLOOR(ar[0] + ar[1] + ar[2]), 0); Out.Ln;

  (* 6. SET array *)
  aset[0] := {0, 1};
  aset[1] := {2, 3};
  aset[2] := {4};
  Out.Int(ORD(aset[0] + aset[1] + aset[2]), 0); Out.Ln;

  (* 7. BOOLEAN array *)
  abool[0] := TRUE;
  abool[1] := FALSE;
  abool[2] := TRUE;
  abool[3] := FALSE;
  sum := 0;
  FOR i := 0 TO 3 DO
    IF abool[i] THEN INC(sum) END
  END;
  Out.Int(sum, 0); Out.Ln;

  (* 8. 2D SHORTINT array (elemSize=2, non-power-of-2 row size=6) *)
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      ms[i, j] := i * 10 + j
    END
  END;
  sum := 0;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      sum := sum + ms[i, j]
    END
  END;
  Out.Int(sum, 0); Out.Ln;

  (* 9. 2D BYTE array (elemSize=1) *)
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      mb[i, j] := i * 4 + j
    END
  END;
  sum := 0;
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      sum := sum + mb[i, j]
    END
  END;
  Out.Int(sum, 0); Out.Ln;

  (* 10. Constant index access for each type *)
  ab[2] := 77;
  as[1] := -999;
  Out.Int(ab[2], 0); Out.Ln;
  Out.Int(as[1], 0); Out.Ln
END Array5.
