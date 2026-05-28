MODULE SuiteFiles;
IMPORT Out, Files;

VAR
  f: Files.File;
  r, r2: Files.Rider;
  i, got: INTEGER;
  li, ln: LONGINT;
  si: SHORTINT;
  b: BYTE;
  s, name: ARRAY 64 OF CHAR;
  st: SET;
  res: INTEGER;
  dt: LONGINT;
  buf: ARRAY 8 OF BYTE;

BEGIN
  f := Files.New('SuiteFiles.bin');
  Files.Set(r, f, 0);
  Files.WriteInt(r, 1234);
  Files.WriteShortInt(r, -123);
  Files.WriteString(r, 'привет');
  Files.WriteString(r, 'ok');
  ln := 5000;
  Files.WriteNum(r, ln);
  ln := -10000;
  Files.WriteNum(r, ln);
  li := 10000000000;
  Files.WriteLInt(r, li);
  b := 171;
  Files.Write(r, b);
  st := {1, 3, 5};
  Files.WriteTinySet(r, st);
  st := {2, 7, 15};
  Files.WriteShortSet(r, st);
  st := {0, 31};
  Files.WriteSet(r, st);
  st := {10, 20};
  Files.WriteLongSet(r, st);
  Files.Register(f);
  Files.GetName(f, name);
  dt := Files.DateModified(f);
  Files.Truncate(f, 40);
  Files.Close(f);

  f := Files.Old('SuiteFiles.bin');
  IF f # NIL THEN
    Files.Set(r2, f, 0);
    Files.ReadInt(r2, i);
    Out.String('Int='); Out.Int(i, 0); Out.Ln;
    Files.ReadShortInt(r2, si);
    i := si;
    Out.String('SInt='); Out.Int(i, 0); Out.Ln;
    Files.ReadString(r2, s);
    Out.String('Str1='); Out.String(s); Out.Ln;
    Files.ReadString(r2, s);
    Out.String('Str2='); Out.String(s); Out.Ln;
    Files.ReadNum(r2, ln);
    Out.String('Num1='); Out.Int(ln, 0); Out.Ln;
    Files.ReadNum(r2, ln);
    Out.String('Num2='); Out.Int(ln, 0); Out.Ln;
    Files.ReadLInt(r2, li);
    Out.String('LInt='); Out.Int(li, 0); Out.Ln;
    Files.Read(r2, b);
    Out.String('Byte='); Out.Int(ORD(b), 0); Out.Ln;
    Files.ReadTinySet(r2, st);
    i := 0;
    IF 1 IN st THEN INC(i) END;
    IF 3 IN st THEN INC(i, 10) END;
    IF 5 IN st THEN INC(i, 100) END;
    Out.String('Tiny='); Out.Int(i, 0); Out.Ln;
    Files.ReadShortSet(r2, st);
    i := 0;
    IF 2 IN st THEN INC(i) END;
    IF 7 IN st THEN INC(i, 10) END;
    IF 15 IN st THEN INC(i, 100) END;
    Out.String('Short='); Out.Int(i, 0); Out.Ln;
    Files.ReadSet(r2, st);
    i := 0;
    IF 0 IN st THEN INC(i) END;
    IF 31 IN st THEN INC(i, 10) END;
    Out.String('Set='); Out.Int(i, 0); Out.Ln;
    Files.ReadLongSet(r2, st);
    i := 0;
    IF 10 IN st THEN INC(i) END;
    IF 20 IN st THEN INC(i, 10) END;
    Out.String('Long='); Out.Int(i, 0); Out.Ln;
    got := Files.ReadBytes(r2, buf, 0, 4);
    Out.String('Extra='); Out.Int(got, 0); Out.Ln;
    Out.String('Len='); Out.Int(Files.Length(f), 0); Out.Ln;
    Out.String('Name='); Out.String(name); Out.Ln;
    IF dt # 0 THEN Out.String('Date=ok') ELSE Out.String('Date=0') END;
    Out.Ln;
    Files.Close(f)
  ELSE Out.String('Old failed'); Out.Ln
  END;

  Files.Delete('SuiteFiles.bin', res);
  Out.String('Del='); Out.Int(res, 0); Out.Ln
END SuiteFiles.
