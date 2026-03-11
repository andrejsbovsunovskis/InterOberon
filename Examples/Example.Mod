MODULE Example;
IMPORT Out;
VAR
  a, b, c, d: INTEGER;
BEGIN
  (* INC *)
  a := 3;
  INC(a);          (* a = 4 *)
  Out.Int(a, 0); Out.Ln;

  (* DEC *)
  b := 7;
  DEC(b);          (* b = 6 *)
  Out.Int(b, 0); Out.Ln;

  (* INC with step *)
  c := 10;
  INC(c, 5);       (* c = 15 *)
  Out.Int(c, 0); Out.Ln;

  (* DEC with step *)
  d := 20;
  DEC(d, 3);       (* d = 17 *)
  Out.Int(d, 0); Out.Ln;

  (* ABS *)
  a := -5;
  a := ABS(a);     (* a = 5 *)
  Out.Int(a, 0); Out.Ln;

  (* ODD with odd number *)
  b := 3;
  IF ODD(b) THEN Out.Char('Y') ELSE Out.Char('N') END; Out.Ln;

  (* ODD with even number *)
  b := 4;
  IF ODD(b) THEN Out.Char('Y') ELSE Out.Char('N') END; Out.Ln
END Example.