MODULE CompTest;
IMPORT Out;
VAR a, b: INTEGER;
BEGIN
  (* 1. Equal: 5 = 5 → 1 *)
  a := 5; b := 5;
  IF a = b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 2. Not equal: 5 # 3 → 1 *)
  a := 5; b := 3;
  IF a # b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 3. Less than: 3 < 5 → 1 *)
  a := 3; b := 5;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 4. Less or equal: 5 <= 5 → 1 *)
  a := 5; b := 5;
  IF a <= b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 5. Greater than: 7 > 3 → 1 *)
  a := 7; b := 3;
  IF a > b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 6. Greater or equal: 5 >= 5 → 1 *)
  a := 5; b := 5;
  IF a >= b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 7. Not less than: 3 < 5 but inverted → 0 *)
  a := 5; b := 3;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 8. Negative comparison: -5 < 0 → 1 *)
  a := -5; b := 0;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 9. Negative vs positive: -10 < 10 → 1 *)
  a := -10; b := 10;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 10. Both negative: -2 > -5 → 1 *)
  a := -2; b := -5;
  IF a > b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 11. Zero comparisons: 0 = 0 → 1 *)
  IF 0 = 0 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 12. 0 # 1 → 1 *)
  IF 0 # 1 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 13. Chained: a < b with expressions *)
  a := 2 * 3;
  b := 3 * 3;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 14. Equal with expressions: 2*5 = 10 → 1 *)
  IF 2 * 5 = 10 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 15. Complex condition: (a > 0) & (a < 100) where a=50 → 1 *)
  a := 50;
  IF (a > 0) & (a < 100) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END CompTest.
