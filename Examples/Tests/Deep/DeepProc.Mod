MODULE DeepProc;
IMPORT Out;

TYPE Fn = PROCEDURE(x: INTEGER): INTEGER;

VAR g: INTEGER; f: Fn; res: INTEGER;

PROCEDURE IncG;
BEGIN INC(g) END IncG;

PROCEDURE GetG(): INTEGER;
RETURN g END GetG;

PROCEDURE Double(x: INTEGER): INTEGER;
RETURN x * 2 END Double;

PROCEDURE Apply(fn: Fn; x: INTEGER): INTEGER;
RETURN fn(x) END Apply;

PROCEDURE NestedPart;

  PROCEDURE Inner;
  BEGIN INC(g) END Inner;

BEGIN
  g := 0;
  Inner;
  Inner;
  Out.Int(g, 0); Out.Ln
END NestedPart;

PROCEDURE VarParPart;
VAR a, b: INTEGER;

  PROCEDURE Swap(VAR x, y: INTEGER);
  VAR t: INTEGER;
  BEGIN t := x; x := y; y := t END Swap;

BEGIN
  a := 3; b := 7;
  Swap(a, b);
  Out.Int(a, 0); Out.Char(' '); Out.Int(b, 0); Out.Ln
END VarParPart;

PROCEDURE ProcTypePart;
BEGIN
  f := Double;
  Out.Int(Apply(f, 11), 0); Out.Ln;
  IF f(5) = 10 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END ProcTypePart;

BEGIN
  g := 0;
  IncG; IncG;
  Out.Int(GetG(), 0); Out.Ln;
  NestedPart;
  VarParPart;
  ProcTypePart
END DeepProc.
