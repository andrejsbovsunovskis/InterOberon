MODULE InTest;
IMPORT Out, In;
VAR
  c: CHAR;
  n: INTEGER;
  a, b: ARRAY 64 OF CHAR;
BEGIN
  (* In.Char: ASCII *)
  In.Char(c);
  Out.Int(ORD(c), 0); Out.Ln;

  (* In.Char: 2-byte UTF-8 (Cyrillic Я) *)
  In.Char(c);
  Out.Int(ORD(c), 0); Out.Ln;

  (* In.Char: 3-byte UTF-8 (€) *)
  In.Char(c);
  Out.Int(ORD(c), 0); Out.Ln;

  (* In.Int: leading whitespace and tab, positive *)
  In.Int(n);
  Out.Int(n, 0); Out.Ln;

  (* In.Int: negative *)
  In.Int(n);
  Out.Int(n, 0); Out.Ln;

  (* In.Int: zero with spaces *)
  In.Int(n);
  Out.Int(n, 0); Out.Ln;

  (* In.Int: multi-digit *)
  In.Int(n);
  Out.Int(n, 0); Out.Ln;

  (* In.Line: Latin, then UTF-8 line, then empty, then CR/LF line *)
  In.Line(a);
  Out.String(a); Out.Ln;
  In.Line(b);
  Out.String(b); Out.Ln;
  In.Line(a);
  Out.Char('['); Out.String(a); Out.Char(']'); Out.Ln;
  In.Line(b);
  Out.String(b); Out.Ln;

  (* Second call In.Line after first: separate logical lines *)
  In.Line(a);
  Out.String(a); Out.Ln;
  In.Line(a);
  Out.String(a); Out.Ln
END InTest.
