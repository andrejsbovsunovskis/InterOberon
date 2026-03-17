MODULE IfTest;
IMPORT Out;
VAR a, b, res: INTEGER;
BEGIN
  (* --- 1. Simple IF, condition TRUE  => 1 --- *)
  a := 5; res := 0;
  IF a > 3 THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 2. Simple IF, condition FALSE  => 0 --- *)
  a := 2; res := 0;
  IF a > 3 THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 3. IF-ELSE, TRUE branch  => 100 --- *)
  a := 10;
  IF a = 10 THEN res := 100 ELSE res := 200 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 4. IF-ELSE, FALSE branch  => 200 --- *)
  a := 9;
  IF a = 10 THEN res := 100 ELSE res := 200 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 5. IF-ELSIF, first branch  => 10 --- *)
  a := 1;
  IF a = 1 THEN res := 10
  ELSIF a = 2 THEN res := 20
  ELSIF a = 3 THEN res := 30
  END;
  Out.Int(res, 0); Out.Ln;

  (* --- 6. IF-ELSIF, second branch  => 20 --- *)
  a := 2;
  IF a = 1 THEN res := 10
  ELSIF a = 2 THEN res := 20
  ELSIF a = 3 THEN res := 30
  END;
  Out.Int(res, 0); Out.Ln;

  (* --- 7. IF-ELSIF, third branch  => 30 --- *)
  a := 3;
  IF a = 1 THEN res := 10
  ELSIF a = 2 THEN res := 20
  ELSIF a = 3 THEN res := 30
  END;
  Out.Int(res, 0); Out.Ln;

  (* --- 8. IF-ELSIF-ELSE, none match  => 99 --- *)
  a := 99;
  IF a = 1 THEN res := 10
  ELSIF a = 2 THEN res := 20
  ELSIF a = 3 THEN res := 30
  ELSE res := 99
  END;
  Out.Int(res, 0); Out.Ln;

  (* --- 9. Nested IF inside THEN  => 1 --- *)
  a := 5; b := 7; res := 0;
  IF a < 10 THEN
    IF b > 5 THEN res := 1 ELSE res := 2 END
  ELSE
    res := 3
  END;
  Out.Int(res, 0); Out.Ln;

  (* --- 10. Nested IF inside ELSE  => 2 --- *)
  a := 15; b := 3; res := 0;
  IF a < 10 THEN
    res := 1
  ELSE
    IF b < 5 THEN res := 2 ELSE res := 3 END
  END;
  Out.Int(res, 0); Out.Ln;

  (* --- 11. IF with AND, both TRUE  => 1 --- *)
  a := 4; b := 8; res := 0;
  IF (a > 2) & (b > 6) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 12. IF with AND, second FALSE  => 0 --- *)
  a := 4; b := 5; res := 0;
  IF (a > 2) & (b > 6) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 13. IF with OR, first TRUE  => 1 --- *)
  a := 1; b := 0; res := 0;
  IF (a > 0) OR (b > 0) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 14. IF with OR, second TRUE  => 1 --- *)
  a := 0; b := 1; res := 0;
  IF (a > 0) OR (b > 0) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 15. IF with OR, both FALSE  => 0 --- *)
  a := 0; b := 0; res := 0;
  IF (a > 0) OR (b > 0) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 16. IF inside WHILE: count even a in [0,4]  => 3 --- *)
  a := 0; res := 0;
  WHILE a < 5 DO
    IF a MOD 2 = 0 THEN res := res + 1 END;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* --- 17. Chained ELSIF in loop: 1+2+4+8+16  => 31 --- *)
  b := 0; a := 1;
  WHILE a <= 5 DO
    IF a = 1 THEN b := b + 1
    ELSIF a = 2 THEN b := b + 2
    ELSIF a = 3 THEN b := b + 4
    ELSIF a = 4 THEN b := b + 8
    ELSE b := b + 16
    END;
    a := a + 1
  END;
  Out.Int(b, 0); Out.Ln;

  (* --- 18. IF boundary (a=0, a>=0)  => 1 --- *)
  a := 0;
  IF a >= 0 THEN res := 1 ELSE res := 2 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 19. Negation ~(a=3) where a=5  => 7 --- *)
  a := 5; res := 0;
  IF ~(a = 3) THEN res := 7 END;
  Out.Int(res, 0); Out.Ln;

  (* --- 20. 4-way ELSIF, a=50 matches 3rd  => 2 --- *)
  a := 50;
  IF a < 0 THEN res := -1
  ELSIF a = 0 THEN res := 0
  ELSIF a < 10 THEN res := 1
  ELSIF a < 100 THEN res := 2
  ELSE res := 3
  END;
  Out.Int(res, 0); Out.Ln;

  (* done *)
  Out.Char('O'); Out.Char('K'); Out.Ln
END IfTest.
