MODULE Array4;
IMPORT Out;
VAR
  m: ARRAY 3, 4 OF INTEGER;
  b: ARRAY 2, 3, 2 OF INTEGER;
  i, j, k, sum: INTEGER;
BEGIN
  (* 1. Fill 3x4 matrix with comma syntax *)
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      m[i, j] := i * 10 + j
    END
  END;

  (* 2. Print matrix *)
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      Out.Int(m[i, j], 0);
      Out.Char(' ')
    END;
    Out.Ln
  END;

  (* 3. Sum all elements *)
  sum := 0;
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      sum := sum + m[i, j]
    END
  END;
  Out.Int(sum, 0); Out.Ln;

  (* 4. Constant indices with comma syntax *)
  m[0, 0] := 99;
  m[2, 3] := 77;
  Out.Int(m[0, 0], 0); Out.Ln;
  Out.Int(m[2, 3], 0); Out.Ln;

  (* 5. Mixed syntax: declare with commas, index with brackets or commas *)
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        b[i, j, k] := i * 100 + j * 10 + k
      END
    END
  END;

  (* 6. Print 3D array — mix bracket and comma styles *)
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        Out.Int(b[i][j][k], 0);
        Out.Char(' ')
      END
    END;
    Out.Ln
  END;

  (* 7. Sum 3D array with comma syntax *)
  sum := 0;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        sum := sum + b[i, j, k]
      END
    END
  END;
  Out.Int(sum, 0); Out.Ln
END Array4.
