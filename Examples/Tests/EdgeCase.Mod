MODULE EdgeCase;
IMPORT Out;
VAR
  i, j: INTEGER;
  a: ARRAY 5 OF INTEGER;
  s: SET;
BEGIN
  (* 1. Max positive int: 2147483647 *)
  i := 2147483647;
  Out.Int(i, 0); Out.Ln;

  (* 2. Min negative int: -2147483648 *)
  i := -2147483647;
  i := i - 1;
  Out.Int(i, 0); Out.Ln;

  (* 3. Zero DIV positive = 0 *)
  i := 0 DIV 7;
  Out.Int(i, 0); Out.Ln;

  (* 4. Zero MOD positive = 0 *)
  i := 0 MOD 7;
  Out.Int(i, 0); Out.Ln;

  (* 5. FOR loop with zero iterations *)
  j := 0;
  FOR i := 1 TO 0 DO
    j := 1
  END;
  Out.Int(j, 0); Out.Ln;

  (* 6. Single element array *)
  a[3] := 777;
  Out.Int(a[3], 0); Out.Ln;

  (* 7. Empty set operations *)
  s := {};
  s := s + {};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 8. Full set {0..31} *)
  s := {0..31};
  IF 0 IN s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 9. Set element 31 (highest) *)
  s := {};
  INCL(s, 31);
  IF 31 IN s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 10. WHILE with no iterations *)
  i := 10; j := 0;
  WHILE i < 5 DO
    j := 1;
    i := i + 1
  END;
  Out.Int(j, 0); Out.Ln;

  (* 11. REPEAT runs at least once *)
  i := 100; j := 0;
  REPEAT
    j := j + 1;
    i := i - 1
  UNTIL i <= 99;
  Out.Int(j, 0); Out.Ln;

  (* 12. Nested IF all FALSE → ELSE *)
  i := 99;
  IF i = 1 THEN j := 1
  ELSIF i = 2 THEN j := 2
  ELSIF i = 3 THEN j := 3
  ELSE j := -1
  END;
  Out.Int(j, 0); Out.Ln;

  (* 13. Multiply by -1 *)
  i := 42;
  i := i * (-1);
  Out.Int(i, 0); Out.Ln;

  (* 14. Double negation *)
  i := -(-55);
  Out.Int(i, 0); Out.Ln;

  (* 15. Array boundary: last element *)
  a[4] := 999;
  Out.Int(a[4], 0); Out.Ln
END EdgeCase.
