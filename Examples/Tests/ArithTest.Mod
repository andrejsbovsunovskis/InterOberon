MODULE ArithTest;
IMPORT Out;
VAR a, b, r: INTEGER;
BEGIN
  (* 1. Addition: 3 + 7 = 10 *)
  r := 3 + 7;
  Out.Int(r, 0); Out.Ln;

  (* 2. Subtraction: 20 - 13 = 7 *)
  r := 20 - 13;
  Out.Int(r, 0); Out.Ln;

  (* 3. Multiplication: 6 * 7 = 42 *)
  r := 6 * 7;
  Out.Int(r, 0); Out.Ln;

  (* 4. DIV: 17 DIV 5 = 3 *)
  r := 17 DIV 5;
  Out.Int(r, 0); Out.Ln;

  (* 5. MOD: 17 MOD 5 = 2 *)
  r := 17 MOD 5;
  Out.Int(r, 0); Out.Ln;

  (* 6. Negation: -42 *)
  r := -42;
  Out.Int(r, 0); Out.Ln;

  (* 7. Double negation: --5 = 5 *)
  a := -5;
  r := -a;
  Out.Int(r, 0); Out.Ln;

  (* 8. Mixed expression: 2 + 3 * 4 = 14 (precedence) *)
  r := 2 + 3 * 4;
  Out.Int(r, 0); Out.Ln;

  (* 9. Parenthesized: (2 + 3) * 4 = 20 *)
  r := (2 + 3) * 4;
  Out.Int(r, 0); Out.Ln;

  (* 10. Large multiplication: 1000 * 1000 = 1000000 *)
  r := 1000 * 1000;
  Out.Int(r, 0); Out.Ln;

  (* 11. DIV large: 1000000 DIV 7 = 142857 *)
  r := 1000000 DIV 7;
  Out.Int(r, 0); Out.Ln;

  (* 12. MOD: 1000 MOD 7 = 6 *)
  r := 1000 MOD 7;
  Out.Int(r, 0); Out.Ln;

  (* 13. Zero multiplication: 0 * 999 = 0 *)
  r := 0 * 999;
  Out.Int(r, 0); Out.Ln;

  (* 14. Identity: a + 0 = a *)
  a := 77;
  r := a + 0;
  Out.Int(r, 0); Out.Ln;

  (* 15. Chained operations: ((10 - 3) * 2 + 1) DIV 3 = 5 *)
  r := ((10 - 3) * 2 + 1) DIV 3;
  Out.Int(r, 0); Out.Ln;

  (* 16. ABS of positive: ABS(42) = 42 *)
  r := ABS(42);
  Out.Int(r, 0); Out.Ln;

  (* 17. ABS of negative: ABS(-99) = 99 *)
  r := ABS(-99);
  Out.Int(r, 0); Out.Ln;

  (* 18. ABS of zero: ABS(0) = 0 *)
  r := ABS(0);
  Out.Int(r, 0); Out.Ln;

  (* 19. ODD variable: ODD(7) = TRUE → 1 *)
  a := 7;
  IF ODD(a) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 20. ODD variable: ODD(8) = FALSE → 0 *)
  a := 8;
  IF ODD(a) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 21. INC by 1: 10 → 11 *)
  a := 10;
  INC(a);
  Out.Int(a, 0); Out.Ln;

  (* 22. INC by n: 10 + 5 = 15 *)
  a := 10;
  INC(a, 5);
  Out.Int(a, 0); Out.Ln;

  (* 23. DEC by 1: 10 → 9 *)
  a := 10;
  DEC(a);
  Out.Int(a, 0); Out.Ln;

  (* 24. DEC by n: 10 - 3 = 7 *)
  a := 10;
  DEC(a, 3);
  Out.Int(a, 0); Out.Ln;

  (* 25. Complex: (a*a + b*b) where a=3,b=4 → 25 *)
  a := 3; b := 4;
  r := a * a + b * b;
  Out.Int(r, 0); Out.Ln
END ArithTest.
