MODULE SuiteArrayMD;
IMPORT Out;

PROCEDURE Array3Part;
VAR
  m: ARRAY 3 OF ARRAY 4 OF INTEGER;
  b: ARRAY 2 OF ARRAY 3 OF ARRAY 2 OF INTEGER;
  i, j, k, sum: INTEGER;
BEGIN
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      m[i][j] := i * 10 + j
    END
  END;
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      Out.Int(m[i][j], 0);
      Out.Char(' ')
    END;
    Out.Ln
  END;
  sum := 0;
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      sum := sum + m[i][j]
    END
  END;
  Out.Int(sum, 0); Out.Ln;
  m[0][0] := 99;
  m[2][3] := 77;
  Out.Int(m[0][0], 0); Out.Ln;
  Out.Int(m[2][3], 0); Out.Ln;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        b[i][j][k] := i * 100 + j * 10 + k
      END
    END
  END;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        Out.Int(b[i][j][k], 0);
        Out.Char(' ')
      END
    END;
    Out.Ln
  END;
  sum := 0;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        sum := sum + b[i][j][k]
      END
    END
  END;
  Out.Int(sum, 0); Out.Ln
END Array3Part;

PROCEDURE Array4Part;
VAR
  m: ARRAY 3, 4 OF INTEGER;
  b: ARRAY 2, 3, 2 OF INTEGER;
  i, j, k, sum: INTEGER;
BEGIN
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      m[i, j] := i * 10 + j
    END
  END;
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      Out.Int(m[i, j], 0);
      Out.Char(' ')
    END;
    Out.Ln
  END;
  sum := 0;
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO
      sum := sum + m[i, j]
    END
  END;
  Out.Int(sum, 0); Out.Ln;
  m[0, 0] := 99;
  m[2, 3] := 77;
  Out.Int(m[0, 0], 0); Out.Ln;
  Out.Int(m[2, 3], 0); Out.Ln;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        b[i, j, k] := i * 100 + j * 10 + k
      END
    END
  END;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        Out.Int(b[i][j][k], 0);
        Out.Char(' ')
      END
    END;
    Out.Ln
  END;
  sum := 0;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 1 DO
        sum := sum + b[i, j, k]
      END
    END
  END;
  Out.Int(sum, 0); Out.Ln
END Array4Part;

BEGIN
  Array3Part; Array4Part
END SuiteArrayMD.
