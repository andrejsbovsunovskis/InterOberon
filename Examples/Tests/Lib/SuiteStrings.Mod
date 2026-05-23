MODULE SuiteStrings;
IMPORT Out, Strings;

VAR
  a, b: ARRAY 32 OF CHAR;
  i: INTEGER;

BEGIN
  a := 'Hello'; Strings.Cap(a);
  Out.String('Cap: '); Out.String(a); Out.Ln;

  b := 'World';
  Strings.Append('!', b);
  Out.String('Append: '); Out.String(b); Out.Ln;

  a := 'abcdef';
  Strings.Insert('XY', 2, a);
  Out.String('Insert: '); Out.String(a); Out.Ln;

  Strings.Delete(a, 2, 3);
  Out.String('Delete: '); Out.String(a); Out.Ln;

  Strings.Replace('ZZ', 1, a);
  Out.String('Replace: '); Out.String(a); Out.Ln;

  Strings.Extract(a, 1, 2, b);
  Out.String('Extract: '); Out.String(b); Out.Ln;

  i := Strings.Pos('bc', 'abbcde', 0);
  Out.String('Pos bc='); Out.Int(i, 0); Out.Ln;

  i := Strings.Pos('z', 'abbcde', 0);
  Out.String('Pos z='); Out.Int(i, 0); Out.Ln;

  Out.String('Len empty='); Out.Int(Strings.Length(''), 0); Out.Ln
END SuiteStrings.
