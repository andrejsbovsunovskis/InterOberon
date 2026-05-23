MODULE InFull;
IMPORT Out, In, SYSTEM;

VAR
  c: CHAR;
  i: INTEGER;
  h: LONGINT;
  r: REAL;
  lr: LONGREAL;
  name: ARRAY 32 OF CHAR;
  str:  ARRAY 64 OF CHAR;
  line: ARRAY 64 OF CHAR;
  short: ARRAY 8 OF CHAR;

BEGIN
  Out.String('--- Char ---'); Out.Ln;
  In.Char(c); Out.Int(ORD(c), 0); Out.Ln;

  Out.String('--- Int / LongInt ---'); Out.Ln;
  In.LongInt(h); Out.Int(h, 0); Out.Ln;
  In.LongInt(h); Out.Int(h, 0); Out.Ln;
  In.LongInt(h); Out.Int(h, 0); Out.Ln;
  In.Int(i);    Out.Int(i, 0); Out.Ln;
  In.Int(i);    Out.Int(i, 0); Out.Ln;

  Out.String('--- Name ---'); Out.Ln;
  In.Name(name); Out.String(name); Out.Ln;
  In.Name(name); Out.String(name); Out.Ln;
  In.Name(short); Out.String(short); Out.Ln;

  Out.String('--- String (single/double quotes) ---'); Out.Ln;
  In.String(str); Out.String(str); Out.Ln;
  In.String(str); Out.String(str); Out.Ln;

  Out.String('--- Line ---'); Out.Ln;
  In.Line(line); Out.String(line); Out.Ln;
  In.Line(line); Out.String(line); Out.Ln;
  In.Line(short); Out.String(short); Out.Ln;
  In.Line(line); Out.String(line); Out.Ln;
  In.Line(line); Out.String(line); Out.Ln;

  Out.String('--- Real / LongReal ---'); Out.Ln;
  In.Real(r); Out.RealFix(r, 0, 2); Out.Ln;
  In.Real(r); Out.RealFix(r, 0, 1); Out.Ln;
  In.LongReal(lr); Out.RealFix(SYSTEM.VAL(REAL, lr), 0, 2); Out.Ln;
  Out.Int(FLOOR(lr), 0); Out.Ln;

  Out.String('--- sticky Done ---'); Out.Ln;
  In.String(str);
  IF In.Done THEN Out.String('still done') ELSE Out.String('not done') END;
  Out.Ln;

  In.Int(i);
  IF In.Done THEN Out.Int(i, 0) ELSE Out.String('skipped') END;
  Out.Ln;

  In.Open;
  IF In.Done THEN Out.String('reopened') ELSE Out.String('still broken') END;
  Out.Ln
END InFull.
