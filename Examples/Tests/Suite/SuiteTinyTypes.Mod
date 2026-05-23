MODULE SuiteTinyTypes;
IMPORT Out;

VAR
  ti: TINYINT;
  si: SHORTINT;
  i: INTEGER;
  li: LONGINT;
  ts: TINYSET;
  ss: SHORTSET;
  s: SET;
  ls: LONGSET;
  b: BYTE;
  res: INTEGER;

BEGIN
  ti := -1; si := ti; i := si; li := i;
  Out.Int(ti, 0); Out.Ln;
  Out.Int(si, 0); Out.Ln;
  Out.Int(i, 0); Out.Ln;
  Out.Int(SHORT(li), 0); Out.Ln;

  b := 0FEH; ti := b;
  Out.Int(ti, 0); Out.Ln;

  ts := {1, 3};
  ss := ts;
  s := ss;
  ls := s;
  Out.Int(ORD(ts), 0); Out.Ln;
  Out.Int(ORD(ss), 0); Out.Ln;
  Out.Int(ORD(s), 0); Out.Ln;
  Out.Int(SHORT(ORD(ls)), 0); Out.Ln;

  INCL(ss, 4);
  ts := SHORT(ss);
  Out.Int(ORD(ts), 0); Out.Ln;

  IF 3 IN ss THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  ts := {2};
  ss := LONG(ts);
  IF ss = {2} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  INCL(ts, 5);
  Out.Int(ORD(ts), 0); Out.Ln
END SuiteTinyTypes.
