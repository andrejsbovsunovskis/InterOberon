MODULE Array2;
IMPORT Out;
VAR
  a: ARRAY 20 OF INTEGER;
  b: ARRAY 5 OF CHAR;
  i, j, n, tmp: INTEGER;
BEGIN
  (* 1. LEN of array = 20 *)
  Out.Int(LEN(a), 0); Out.Ln;

  (* 2. Fill and reverse an array *)
  n := 8;
  FOR i := 0 TO n - 1 DO
    a[i] := (i + 1) * 10
  END;
  (* Reverse *)
  FOR i := 0 TO n DIV 2 - 1 DO
    j := n - 1 - i;
    tmp := a[i];
    a[i] := a[j];
    a[j] := tmp
  END;
  (* Print reversed *)
  FOR i := 0 TO n - 1 DO
    Out.Int(a[i], 0); Out.Char(' ')
  END;
  Out.Ln;

  (* 3. Bubble sort *)
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

  (* 4. Array of chars *)
  b[0] := 'H'; b[1] := 'E'; b[2] := 'L'; b[3] := 'L'; b[4] := 'O';
  FOR i := 0 TO LEN(b) - 1 DO
    Out.Char(b[i])
  END;
  Out.Ln;

  (* 5. Sum of first N elements *)
  FOR i := 0 TO 9 DO
    a[i] := i + 1
  END;
  tmp := 0;
  FOR i := 0 TO 9 DO
    tmp := tmp + a[i]
  END;
  Out.Int(tmp, 0); Out.Ln;

  (* 6. Find max in array *)
  a[0] := 34; a[1] := 12; a[2] := 89; a[3] := 7; a[4] := 56;
  tmp := a[0];
  FOR i := 1 TO 4 DO
    IF a[i] > tmp THEN tmp := a[i] END
  END;
  Out.Int(tmp, 0); Out.Ln;

  (* 7. Find min in array *)
  tmp := a[0];
  FOR i := 1 TO 4 DO
    IF a[i] < tmp THEN tmp := a[i] END
  END;
  Out.Int(tmp, 0); Out.Ln;

  (* 8. Count elements > 30 *)
  tmp := 0;
  FOR i := 0 TO 4 DO
    IF a[i] > 30 THEN INC(tmp) END
  END;
  Out.Int(tmp, 0); Out.Ln
END Array2.
