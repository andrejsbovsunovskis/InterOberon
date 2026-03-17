MODULE WhileTest;
IMPORT Out;
VAR a, b, res: INTEGER;
BEGIN
  (* 1. Simple WHILE, no ELSIF: sum 1..5 = 15 *)
  a := 1; res := 0;
  WHILE a <= 5 DO
    res := res + a;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 2. WHILE with one ELSIF: two phases
     a=1..3 → res+1 each (3 times), a=4..6 → res+10 each (3 times)
     result = 3 + 30 = 33 *)
  a := 1; res := 0;
  WHILE a <= 3 DO
    res := res + 1;
    a := a + 1
  ELSIF a <= 6 DO
    res := res + 10;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 3. WHILE with two ELSIFs: three phases
     a=0..1 → res+1 (2x), a=2..3 → res+10 (2x), a=4..5 → res+100 (2x)
     result = 2 + 20 + 200 = 222 *)
  a := 0; res := 0;
  WHILE a < 2 DO
    res := res + 1;
    a := a + 1
  ELSIF a < 4 DO
    res := res + 10;
    a := a + 1
  ELSIF a < 6 DO
    res := res + 100;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 4. WHILE where first condition is FALSE from start,
     ELSIF runs: a=10, WHILE a<5 skips, ELSIF a<15 runs
     result = 10+11+12+13+14 = 60 *)
  a := 10; res := 0;
  WHILE a < 5 DO
    res := res + 1;
    a := a + 1
  ELSIF a < 15 DO
    res := res + a;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 5. Both WHILE and ELSIF are FALSE from start → body never runs
     result stays 99 *)
  a := 100; res := 99;
  WHILE a < 50 DO
    res := 0;
    a := a + 1
  ELSIF a < 80 DO
    res := 0;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 6. WHILE-ELSIF with compound conditions (AND/OR)
     a=1: (a>0)&(a<3) → +1, a=2: same → +1, a=3: (a>=3)OR(a=10) → +100 (once, then a=4 fails both)
     result = 1+1+100 = 102 *)
  a := 1; res := 0;
  WHILE (a > 0) & (a < 3) DO
    res := res + 1;
    a := a + 1
  ELSIF (a >= 3) OR (a = 10) DO
    res := res + 100;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 7. Nested WHILE inside WHILE-ELSIF
     Outer: a=1..2 → inner counts b=1..a, adds b
     a=1: b=1 → res+1
     a=2: b=1,2 → res+1+2
     then ELSIF a<=4: a=3,4 → res+10 each
     result = 1+1+2+10+10 = 24 *)
  a := 1; res := 0;
  WHILE a <= 2 DO
    b := 1;
    WHILE b <= a DO
      res := res + b;
      b := b + 1
    END;
    a := a + 1
  ELSIF a <= 4 DO
    res := res + 10;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 8. IF inside WHILE-ELSIF
     a=0..4: if even res+2, else res+1
     0→+2, 1→+1, 2→+2, 3→+1, 4→+2 = 8
     then ELSIF a<8: res+10 for a=5,6,7 = 30
     total = 38 *)
  a := 0; res := 0;
  WHILE a < 5 DO
    IF a MOD 2 = 0 THEN res := res + 2
    ELSE res := res + 1
    END;
    a := a + 1
  ELSIF a < 8 DO
    res := res + 10;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 9. WHILE-ELSIF re-entering first condition:
     a starts at 1, phase 1 adds, phase 2 resets to go back
     a=1,2 → res+a (WHILE a<3); a=3 → set a:=0 (ELSIF a<4);
     a=0,1,2 → res+a (WHILE a<3 again); a=3 → ELSIF, but now set a:=10 to exit
     We need to track carefully:
     Iter1: a=1→res=1,a=2→res=3 → WHILE false
     Iter2: a=3→ELSIF true→a:=0, b:=1
     Iter3: a=0→res=3,a=1→res=4,a=2→res=6 → WHILE false
     Iter4: a=3→ELSIF true→a:=10, b already 1→ b+1=2→exit
     Wait, this is tricky. Let me simplify. 
     Use b as a one-shot flag. *)
  a := 1; b := 0; res := 0;
  WHILE a < 3 DO
    res := res + a;
    a := a + 1
  ELSIF (a < 4) & (b = 0) DO
    b := 1;
    a := 0
  END;
  (* first: a=1→res=1, a=2→res=3, then ELSIF: a=3,b=0→set b=1,a=0
     second: a=0→res=3, a=1→res=4, a=2→res=6, then ELSIF: a=3 but b=1→false, exit
     result = 6 *)
  Out.Int(res, 0); Out.Ln;

  (* 10. Three ELSIFs — 4 phases
     a=0: +1 (WHILE a<1), a=1: +10 (ELSIF a<2), a=2: +100 (ELSIF a<3), a=3: +1000 (ELSIF a<4)
     result = 1111 *)
  a := 0; res := 0;
  WHILE a < 1 DO
    res := res + 1;
    a := a + 1
  ELSIF a < 2 DO
    res := res + 10;
    a := a + 1
  ELSIF a < 3 DO
    res := res + 100;
    a := a + 1
  ELSIF a < 4 DO
    res := res + 1000;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 11. WHILE-ELSIF with negation: ~(a > 5)
     a=1..5: res+1 each = 5; then ELSIF ~(a>8): a=6,7,8 → res+10 = 30
     total = 35 *)
  a := 1; res := 0;
  WHILE ~(a > 5) DO
    res := res + 1;
    a := a + 1
  ELSIF ~(a > 8) DO
    res := res + 10;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 12. Single iteration each phase
     a=0: WHILE a=0 → res:=7, a:=1; ELSIF a=1 → res:=res+3=10, a:=2
     result = 10 *)
  a := 0; res := 0;
  WHILE a = 0 DO
    res := 7;
    a := 1
  ELSIF a = 1 DO
    res := res + 3;
    a := 2
  END;
  Out.Int(res, 0); Out.Ln;

  Out.Char('O'); Out.Char('K'); Out.Ln
END WhileTest.
