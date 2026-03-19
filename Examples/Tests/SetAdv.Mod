MODULE SetAdv;
IMPORT Out;
VAR s, t: SET; i, res: INTEGER;
BEGIN
  (* 1. Set complement: -{0..31} should be empty for 32-bit *)
  s := {0..31};
  t := -s;
  Out.Int(ORD(t), 0); Out.Ln;

  (* 2. Building set incrementally with INCL *)
  s := {};
  INCL(s, 0); INCL(s, 2); INCL(s, 4);
  Out.Int(ORD(s), 0); Out.Ln;
  (* Expected: 2^0 + 2^2 + 2^4 = 1 + 4 + 16 = 21 *)

  (* 3. Removing with EXCL *)
  EXCL(s, 2);
  Out.Int(ORD(s), 0); Out.Ln;
  (* Expected: 1 + 16 = 17 *)

  (* 4. IN with variable element *)
  i := 4;
  IF i IN s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 5. IN with element not present *)
  i := 2;
  IF i IN s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 6. Set with single range {5..5} = {5} = 32 *)
  s := {5..5};
  Out.Int(ORD(s), 0); Out.Ln;

  (* 7. Union of disjoint sets *)
  s := {0, 1} + {10, 11};
  Out.Int(ORD(s), 0); Out.Ln;
  (* 1 + 2 + 1024 + 2048 = 3075 *)

  (* 8. Set built in loop *)
  s := {};
  FOR i := 0 TO 7 DO
    IF ODD(i) THEN INCL(s, i) END
  END;
  Out.Int(ORD(s), 0); Out.Ln;
  (* Odd positions: 1,3,5,7 → 2+8+32+128 = 170 *)

  (* 9. Count elements in set *)
  s := {2, 5, 7, 11, 13};
  res := 0;
  FOR i := 0 TO 31 DO
    IF i IN s THEN res := res + 1 END
  END;
  Out.Int(res, 0); Out.Ln;
  (* 5 elements *)

  (* 10. XOR (symmetric difference) *)
  s := {1, 2, 3, 4};
  t := {3, 4, 5, 6};
  s := s / t;
  Out.Int(ORD(s), 0); Out.Ln;
  (* {1,2,5,6} = 2+4+32+64 = 102 *)

  (* 11. Self-intersection = identity *)
  s := {1, 3, 5};
  s := s * s;
  Out.Int(ORD(s), 0); Out.Ln;
  (* {1,3,5} = 2+8+32 = 42 *)

  (* 12. Self-difference = empty *)
  s := {1, 3, 5};
  s := s - s;
  Out.Int(ORD(s), 0); Out.Ln
  (* {} = 0 *)
END SetAdv.
