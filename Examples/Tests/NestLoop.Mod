MODULE NestLoop;
IMPORT Out;
VAR i, j, sum: INTEGER;
BEGIN
  (* 1. Nested FOR: multiplication table check 3x3 *)
  FOR i := 1 TO 3 DO
    FOR j := 1 TO 3 DO
      Out.Int(i * j, 0)
    END;
    Out.Ln
  END;

  (* 2. Sum of nested loops: sum(i*j) for i=1..4, j=1..4 *)
  sum := 0;
  FOR i := 1 TO 4 DO
    FOR j := 1 TO 4 DO
      sum := sum + i * j
    END
  END;
  Out.Int(sum, 0); Out.Ln;

  (* 3. Triangle pattern using nested FOR *)
  FOR i := 1 TO 5 DO
    FOR j := 1 TO i DO
      Out.Char('*')
    END;
    Out.Ln
  END;

  (* 4. While inside FOR *)
  FOR i := 1 TO 3 DO
    j := i;
    WHILE j > 0 DO
      Out.Char('.');
      j := j - 1
    END;
    Out.Ln
  END;

  (* 5. FOR with step 3 *)
  FOR i := 0 TO 20 BY 3 DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;

  (* 6. Countdown with REPEAT inside FOR *)
  FOR i := 3 TO 1 BY -1 DO
    j := i;
    REPEAT
      Out.Int(j, 0);
      j := j - 1
    UNTIL j = 0;
    Out.Char(' ')
  END;
  Out.Ln;

  (* 7. Sum of squares 1..10 = 385 *)
  sum := 0;
  FOR i := 1 TO 10 DO
    sum := sum + i * i
  END;
  Out.Int(sum, 0); Out.Ln;

  (* 8. Fibonacci-like: compute 8th number *)
  i := 1; j := 1;
  sum := 0;
  WHILE sum < 6 DO
    sum := sum + 1;
    j := i + j;
    i := j - i
  END;
  Out.Int(j, 0); Out.Ln
END NestLoop.
