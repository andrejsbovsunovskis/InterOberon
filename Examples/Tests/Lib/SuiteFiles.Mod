MODULE SuiteFiles;
IMPORT Out, Files;

VAR
  f: Files.File;
  r, r2: Files.Rider;
  i: INTEGER;
  s: ARRAY 16 OF CHAR;
  res: INTEGER;

BEGIN
  f := Files.New('SuiteFiles.bin');
  Files.Set(r, f, 0);
  Files.WriteInt(r, 1234);
  Files.WriteString(r, 'ok');
  Files.WriteNum(r, 42);
  Files.Register(f);
  Files.Close(f);

  f := Files.Old('SuiteFiles.bin');
  IF f # NIL THEN
    Files.Set(r2, f, 0);
    Files.ReadInt(r2, i);
    Out.String('Int='); Out.Int(i, 0); Out.Ln;
    Files.ReadString(r2, s);
    Out.String('Str='); Out.String(s); Out.Ln;
    Files.ReadNum(r2, i);
    Out.String('Num='); Out.Int(i, 0); Out.Ln;
    Out.String('Len='); Out.Int(Files.Length(f), 0); Out.Ln;
    Files.Close(f)
  ELSE Out.String('Old failed'); Out.Ln
  END;

  Files.Delete('SuiteFiles.bin', res);
  Out.String('Del='); Out.Int(res, 0); Out.Ln
END SuiteFiles.
