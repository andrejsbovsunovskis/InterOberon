MODULE InclExcl;
IMPORT Out;
VAR
  g: SET;
  gls: LONGSET;
  li: LONGINT;

PROCEDURE DoLocal;
VAR s: SET;
BEGIN
  s := {};
  INCL(s, 3);
  Out.Int(ORD(s), 0); Out.Ln;
  EXCL(s, 3);
  Out.Int(ORD(s), 0); Out.Ln
END DoLocal;

PROCEDURE Touch(VAR t: SET);
BEGIN
  INCL(t, 5)
END Touch;

PROCEDURE TouchLong(VAR ls: LONGSET);
BEGIN
  INCL(ls, 6)
END TouchLong;

BEGIN
  DoLocal;
  g := {};
  Touch(g);
  Out.Int(ORD(g), 0); Out.Ln;
  gls := {};
  TouchLong(gls);
  li := ORD(gls);
  Out.Int(SHORT(li), 0); Out.Ln
END InclExcl.
