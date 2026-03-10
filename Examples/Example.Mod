MODULE Example;
IMPORT Out;
VAR
  a, b, c: INTEGER;
  y: BOOLEAN;
BEGIN
  (* Out.Char *)
  Out.Char('A'); Out.Ln;       (* 41 0A *)

  (* Neg at runtime: a := 5; b := -a  =>  b = -5 = 0xFB *)
  a := 5;
  b := 0 - a;
  Out.Int(b, 0); Out.Ln;       (* FB 0A *)

  (* Mul: 3 * 7 = 21 = 0x15 *)
  a := 3; b := 7;
  c := a * b;
  Out.Int(c, 0); Out.Ln;       (* 15 0A *)

  (* Div: 20 DIV 3 = 6 = 0x06 *)
  a := 20; b := 3;
  c := a DIV b;
  Out.Int(c, 0); Out.Ln;       (* 06 0A *)

  (* Mod: 20 MOD 3 = 2 = 0x02 *)
  c := a MOD b;
  Out.Int(c, 0); Out.Ln;       (* 02 0A *)

  a := 17;
  b := 5;

  c := a MOD b;
  y := a > b;

  Out.Int(ORD(y), 0); Out.Ln
END Example.