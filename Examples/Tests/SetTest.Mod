MODULE SetTest;
IMPORT Out;
VAR s, t: SET; i, res: INTEGER;
BEGIN
  (* 1. Empty set literal {} = 0 *)
  s := {};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 2. Singleton {0} = 1 *)
  s := {0};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 3. Singleton {3} = 8 *)
  s := {3};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 4. Multiple elements {0, 1, 2} = 7 *)
  s := {0, 1, 2};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 5. Range {0..3} = 15 *)
  s := {0..3};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 6. Range {4..7} = 240 *)
  s := {4..7};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 7. Union {0,1} + {2,3} = {0..3} = 15 *)
  s := {0, 1} + {2, 3};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 8. Intersection {0,1,2} * {1,2,3} = {1,2} = 6 *)
  s := {0, 1, 2} * {1, 2, 3};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 9. Difference {0,1,2,3} - {1,3} = {0,2} = 5 *)
  s := {0, 1, 2, 3} - {1, 3};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 10. Symmetric difference {0,1,2} / {1,2,3} = {0,3} = 9 *)
  s := {0, 1, 2} / {1, 2, 3};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 11. IN operator: 2 IN {1,2,3} = TRUE → 1 *)
  IF 2 IN {1, 2, 3} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  (* 12. IN operator: 5 IN {1,2,3} = FALSE → 0 *)
  IF 5 IN {1, 2, 3} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  (* 13. INCL: start with {}, INCL 3 → {3} = 8 *)
  s := {};
  INCL(s, 3);
  Out.Int(ORD(s), 0); Out.Ln;

  (* 14. EXCL: start with {0..3}, EXCL 1 → {0,2,3} = 13 *)
  s := {0..3};
  EXCL(s, 1);
  Out.Int(ORD(s), 0); Out.Ln;

  (* 15. Set equality: {1,2} = {1,2} → 1 *)
  IF {1, 2} = {1, 2} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  (* 16. Set inequality: {1,2} # {1,3} → 1 *)
  IF {1, 2} # {1, 3} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  (* 17. Variable union: s := {0,1}, t := {2,3}, s+t = 15 *)
  s := {0, 1}; t := {2, 3};
  s := s + t;
  Out.Int(ORD(s), 0); Out.Ln;

  (* 18. Variable intersection: s := {1,2,3}, t := {2,3,4}, s*t = {2,3} = 12 *)
  s := {1, 2, 3}; t := {2, 3, 4};
  s := s * t;
  Out.Int(ORD(s), 0); Out.Ln;

  (* 19. Variable IN: i := 2, 2 IN {0..4} → 1 *)
  i := 2;
  IF i IN {0..4} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  (* 20. INCL multiple: {} + INCL 0, INCL 2, INCL 4 → {0,2,4} = 21 *)
  s := {};
  INCL(s, 0);
  INCL(s, 2);
  INCL(s, 4);
  Out.Int(ORD(s), 0); Out.Ln;

  (* 21. EXCL from full low bits: {0..7} EXCL 0, EXCL 7 → {1..6} = 126 *)
  s := {0..7};
  EXCL(s, 0);
  EXCL(s, 7);
  Out.Int(ORD(s), 0); Out.Ln;

  (* 22. Variable difference: {0..4} - {1,3} = {0,2,4} = 21 *)
  s := {0..4}; t := {1, 3};
  s := s - t;
  Out.Int(ORD(s), 0); Out.Ln;

  (* 23. Variable symmetric diff: {0,1,2} / {1,2,3} = {0,3} = 9 *)
  s := {0, 1, 2}; t := {1, 2, 3};
  s := s / t;
  Out.Int(ORD(s), 0); Out.Ln;

  (* 24. Loop with IN: count elements in {1,3,5,7} from 0..9 → 4 *)
  s := {1, 3, 5, 7};
  res := 0; i := 0;
  WHILE i < 10 DO
    IF i IN s THEN res := res + 1 END;
    i := i + 1
  END;
  Out.Int(res, 0); Out.Ln
END SetTest.
