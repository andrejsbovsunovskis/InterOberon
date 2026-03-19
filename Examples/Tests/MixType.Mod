MODULE MixType;
IMPORT Out;
VAR
  si: SHORTINT;
  i: INTEGER;
  li: LONGINT;
  b: BYTE;
  r: REAL;
  s: SET;
  ls: LONGSET;
BEGIN
  (* 1. SHORTINT to INTEGER *)
  si := 127;
  i := si;
  Out.Int(i, 0); Out.Ln;

  (* 2. INTEGER to LONGINT *)
  i := 999999;
  li := i;
  Out.Int(li, 0); Out.Ln;

  (* 3. BYTE to INTEGER via ORD *)
  b := 200;
  i := ORD(b);
  Out.Int(i, 0); Out.Ln;

  (* 4. Integer to REAL and back *)
  i := 42;
  r := FLT(i);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 5. SHORTINT arithmetic *)
  si := 50;
  si := si + 30;
  Out.Int(si, 0); Out.Ln;

  (* 6. SHORTINT negative *)
  si := -100;
  Out.Int(si, 0); Out.Ln;

  (* 7. LONGINT large value *)
  li := 2000000;
  Out.Int(li, 0); Out.Ln;

  (* 8. LONGINT arithmetic *)
  li := 500000;
  li := li * 4;
  Out.Int(li, 0); Out.Ln;

  (* 9. BYTE max value 255 *)
  b := 255;
  Out.Int(ORD(b), 0); Out.Ln;

  (* 10. BYTE min value 0 *)
  b := 0;
  Out.Int(ORD(b), 0); Out.Ln;

  (* 11. SET to LONGSET *)
  s := {1, 5, 10};
  ls := s;
  IF 5 IN ls THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 12. LONGSET basic ops *)
  ls := {};
  INCL(ls, 5);
  INCL(ls, 10);
  IF 5 IN ls THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 13. REAL arithmetic *)
  r := FLT(100);
  r := r / FLT(3);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 14. REAL negative *)
  r := -FLT(7);
  r := r + FLT(10);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 15. Multiple type interactions *)
  si := 10;
  i := si;
  li := i;
  li := li * 100;
  Out.Int(li, 0); Out.Ln
END MixType.
