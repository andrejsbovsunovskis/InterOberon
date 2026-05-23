MODULE SuiteArr;
IMPORT Out;

PROCEDURE ArrayTestPart;
CONST N = 10;
VAR a: ARRAY N OF INTEGER; i, sum: INTEGER;
BEGIN
  FOR i := 0 TO N - 1 DO
    a[i] := (i + 1) * (i + 1)
  END;
  FOR i := 0 TO LEN(a) - 1 DO
    Out.Int(a[i], 5)
  END;
  Out.Ln;
  sum := 0;
  FOR i := 0 TO N - 1 DO
    sum := sum + a[i]
  END;
  Out.Int(sum, 0);
  Out.Ln
END ArrayTestPart;

PROCEDURE Array2Part;
VAR
  a: ARRAY 20 OF INTEGER;
  b: ARRAY 5 OF CHAR;
  i, j, n, tmp: INTEGER;
BEGIN
  Out.Int(LEN(a), 0); Out.Ln;
  n := 8;
  FOR i := 0 TO n - 1 DO
    a[i] := (i + 1) * 10
  END;
  FOR i := 0 TO n DIV 2 - 1 DO
    j := n - 1 - i;
    tmp := a[i];
    a[i] := a[j];
    a[j] := tmp
  END;
  FOR i := 0 TO n - 1 DO
    Out.Int(a[i], 0); Out.Char(' ')
  END;
  Out.Ln;
  a[0] := 5; a[1] := 3; a[2] := 8; a[3] := 1; a[4] := 9;
  a[5] := 2; a[6] := 7; a[7] := 4; a[8] := 6; a[9] := 0;
  n := 10;
  FOR i := 0 TO n - 2 DO
    FOR j := 0 TO n - 2 - i DO
      IF a[j] > a[j + 1] THEN
        tmp := a[j];
        a[j] := a[j + 1];
        a[j + 1] := tmp
      END
    END
  END;
  FOR i := 0 TO n - 1 DO
    Out.Int(a[i], 0); Out.Char(' ')
  END;
  Out.Ln;
  b[0] := 'H'; b[1] := 'E'; b[2] := 'L'; b[3] := 'L'; b[4] := 'O';
  FOR i := 0 TO LEN(b) - 1 DO
    Out.Char(b[i])
  END;
  Out.Ln;
  FOR i := 0 TO 9 DO
    a[i] := i + 1
  END;
  tmp := 0;
  FOR i := 0 TO 9 DO
    tmp := tmp + a[i]
  END;
  Out.Int(tmp, 0); Out.Ln;
  a[0] := 34; a[1] := 12; a[2] := 89; a[3] := 7; a[4] := 56;
  tmp := a[0];
  FOR i := 1 TO 4 DO
    IF a[i] > tmp THEN tmp := a[i] END
  END;
  Out.Int(tmp, 0); Out.Ln;
  tmp := a[0];
  FOR i := 1 TO 4 DO
    IF a[i] < tmp THEN tmp := a[i] END
  END;
  Out.Int(tmp, 0); Out.Ln;
  tmp := 0;
  FOR i := 0 TO 4 DO
    IF a[i] > 30 THEN INC(tmp) END
  END;
  Out.Int(tmp, 0); Out.Ln
END Array2Part;

PROCEDURE Array5Part;
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
  FOR i := 0 TO 4 DO ab[i] := i * 10 END;
  sum := 0;
  FOR i := 0 TO 4 DO sum := sum + ab[i] END;
  Out.Int(sum, 0); Out.Ln;
  as[0] := 100; as[1] := 200; as[2] := -300; as[3] := 400;
  sum := 0;
  FOR i := 0 TO 3 DO sum := sum + as[i] END;
  Out.Int(sum, 0); Out.Ln;
  ai[0] := 100000; ai[1] := 200000; ai[2] := -50000;
  sum := 0;
  FOR i := 0 TO 2 DO sum := sum + ai[i] END;
  Out.Int(sum, 0); Out.Ln;
  al[0] := 100000; al[1] := 200000; al[2] := 300000;
  lsum := 0;
  FOR i := 0 TO 2 DO lsum := lsum + al[i] END;
  Out.Int(SHORT(lsum), 0); Out.Ln;
  ar[0] := FLT(10);
  ar[1] := FLT(20);
  ar[2] := FLT(30);
  Out.Int(FLOOR(ar[0] + ar[1] + ar[2]), 0); Out.Ln;
  aset[0] := {0, 1};
  aset[1] := {2, 3};
  aset[2] := {4};
  Out.Int(ORD(aset[0] + aset[1] + aset[2]), 0); Out.Ln;
  abool[0] := TRUE;
  abool[1] := FALSE;
  abool[2] := TRUE;
  abool[3] := FALSE;
  sum := 0;
  FOR i := 0 TO 3 DO
    IF abool[i] THEN INC(sum) END
  END;
  Out.Int(sum, 0); Out.Ln;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      ms[i, j] := SHORT(i * 10 + j)
    END
  END;
  sum := 0;
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      sum := sum + ms[i, j]
    END
  END;
  Out.Int(sum, 0); Out.Ln;
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
  ab[2] := 77;
  as[1] := -999;
  Out.Int(ab[2], 0); Out.Ln;
  Out.Int(as[1], 0); Out.Ln
END Array5Part;

BEGIN
  ArrayTestPart;
  Array2Part;
  Array5Part
END SuiteArr.
