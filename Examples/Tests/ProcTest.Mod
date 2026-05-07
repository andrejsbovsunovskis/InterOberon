MODULE ProcTest;
IMPORT Out;
VAR g, h: INTEGER;

PROCEDURE Hello;
BEGIN
  Out.Int(42, 0); Out.Ln
END Hello;

PROCEDURE Add(a, b: INTEGER);
BEGIN
  Out.Int(a + b, 0); Out.Ln
END Add;

PROCEDURE Triple(x: INTEGER);
VAR r: INTEGER;
BEGIN
  r := x * 3;
  Out.Int(r, 0); Out.Ln
END Triple;

PROCEDURE Swap(VAR a, b: INTEGER);
VAR t: INTEGER;
BEGIN
  t := a;
  a := b;
  b := t
END Swap;

PROCEDURE PrintGlobal;
BEGIN
  Out.Int(g, 0); Out.Ln
END PrintGlobal;

BEGIN
  (* 1. No-arg procedure *)
  Hello;

  (* 2. Two args *)
  Add(10, 20);

  (* 3. Local variable *)
  Triple(7);

  (* 4. VAR parameters *)
  g := 100; h := 200;
  Swap(g, h);
  Out.Int(g, 0); Out.Ln;
  Out.Int(h, 0); Out.Ln;

  (* 5. Multiple calls *)
  Add(1, 2);
  Add(3, 4);
  Triple(10)
END ProcTest.
