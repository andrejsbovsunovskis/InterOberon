MODULE NestProc;
IMPORT Out;
VAR g: INTEGER;

PROCEDURE Outer;

  PROCEDURE Inner;
  BEGIN
    Out.Int(g, 0); Out.Ln
  END Inner;

BEGIN
  Inner
END Outer;

PROCEDURE Math;

  PROCEDURE Double(x: INTEGER);
  BEGIN
    Out.Int(x * 2, 0); Out.Ln
  END Double;

  PROCEDURE Square(x: INTEGER);
  VAR r: INTEGER;
  BEGIN
    r := x * x;
    Out.Int(r, 0); Out.Ln
  END Square;

BEGIN
  Double(7);
  Square(5)
END Math;

PROCEDURE Deep;

  PROCEDURE Mid;

    PROCEDURE Bot;
    BEGIN
      Out.Int(g, 0); Out.Ln
    END Bot;

  BEGIN
    Bot
  END Mid;

BEGIN
  Mid
END Deep;

PROCEDURE WithLocal;
VAR a: INTEGER;

  PROCEDURE Show;
  BEGIN
    Out.Int(g, 0); Out.Ln
  END Show;

BEGIN
  a := 10;
  g := a;
  Show
END WithLocal;

PROCEDURE Siblings;

  PROCEDURE A(x: INTEGER);
  BEGIN
    Out.Int(x, 0); Out.Ln
  END A;

  PROCEDURE B;
  BEGIN
    A(55);
    A(66)
  END B;

BEGIN
  B
END Siblings;

PROCEDURE CallOuter(n: INTEGER);

  PROCEDURE Step;
  BEGIN
    Out.Int(g, 0); Out.Ln;
    DEC(g);
    IF g > 0 THEN CallOuter(g) END
  END Step;

BEGIN
  Step
END CallOuter;

PROCEDURE UseConst;
CONST c = 77;

  PROCEDURE Inner;
  BEGIN
    Out.Int(c, 0); Out.Ln
  END Inner;

  PROCEDURE Deeper;
  CONST d = 88;

    PROCEDURE Bot;
    BEGIN
      Out.Int(c + d, 0); Out.Ln
    END Bot;

  BEGIN
    Bot
  END Deeper;

BEGIN
  Inner;
  Deeper
END UseConst;

BEGIN
  (* 1. Nested proc accessing global *)
  g := 42;
  Outer;

  (* 2. Nested procs with params and locals *)
  Math;

  (* 3. Three levels deep *)
  g := 99;
  Deep;

  (* 4. Outer has locals, inner uses global *)
  WithLocal;

  (* 5. Sibling nested procs calling each other *)
  Siblings;

  (* 6. Nested proc calls enclosing proc *)
  g := 3;
  CallOuter(g);

  (* 7. Nested procs accessing outer constants *)
  UseConst
END NestProc.
