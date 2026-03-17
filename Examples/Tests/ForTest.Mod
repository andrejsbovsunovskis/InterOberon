MODULE ForTest;
IMPORT Out;
VAR i, sum, n: INTEGER;
BEGIN
  (* 1. Simple FOR 0 TO 5 *)
  FOR i := 0 TO 5 DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;

  (* 2. FOR with BY 2 *)
  FOR i := 0 TO 10 BY 2 DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;

  (* 3. FOR downward BY -1 *)
  FOR i := 5 TO 0 BY -1 DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;

  (* 4. FOR with sum *)
  sum := 0;
  FOR i := 1 TO 100 DO
    sum := sum + i
  END;
  Out.Int(sum, 0); Out.Ln;

  (* 5. FOR with variable end *)
  n := 3;
  FOR i := 1 TO n DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;

  (* 6. Empty FOR (start > end) *)
  sum := 99;
  FOR i := 10 TO 5 DO
    sum := 0
  END;
  Out.Int(sum, 0); Out.Ln;

  (* 7. FOR single iteration *)
  FOR i := 7 TO 7 DO
    Out.Int(i, 0)
  END;
  Out.Ln
END ForTest.
