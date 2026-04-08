MODULE CaseNest;
IMPORT Out;
VAR x, y, res: INTEGER;
BEGIN
  (* 1. Nested CASE *)
  x := 2; y := 3;
  CASE x OF
    1: CASE y OF
         1: res := 11
       | 2: res := 12
       | 3: res := 13
       END
  | 2: CASE y OF
         1: res := 21
       | 2: res := 22
       | 3: res := 23
       END
  | 3: res := 30
  END;
  Out.Int(res, 0); Out.Ln;

  (* 2. Inner CASE in first branch *)
  x := 1; y := 2;
  CASE x OF
    1: CASE y OF
         1: res := 100
       | 2: res := 200
       END
  | 2: res := 999
  END;
  Out.Int(res, 0); Out.Ln;

  (* 3. Inner CASE in last branch *)
  x := 3; y := 1;
  CASE x OF
    1: res := 0
  | 2: res := 0
  | 3: CASE y OF
         1: res := 31
       | 2: res := 32
       END
  END;
  Out.Int(res, 0); Out.Ln;

  (* 4. Triple nesting *)
  x := 1; y := 2;
  CASE x OF
    1: CASE y OF
         1: res := 0
       | 2: CASE x + y OF
              3: res := 123
            | 4: res := 124
            END
       END
  | 2: res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 5. Nested CASE with ranges *)
  x := 5; y := 15;
  CASE x OF
    1..5: CASE y OF
            1..10: res := 1
          | 11..20: res := 2
          END
  | 6..10: res := 3
  END;
  Out.Int(res, 0); Out.Ln;

  (* 6. Nested CASE inside FOR *)
  FOR x := 1 TO 3 DO
    CASE x OF
      1: CASE x + 10 OF
           11: Out.Char('A')
         | 12: Out.Char('?')
         END
    | 2: CASE x * 2 OF
           4: Out.Char('B')
         | 5: Out.Char('?')
         END
    | 3: Out.Char('C')
    END
  END;
  Out.Ln
END CaseNest.
