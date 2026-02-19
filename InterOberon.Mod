MODULE InterOberon;
IMPORT Parser, Args, Out, Risc, Linker, Lang, Platform;

PROCEDURE Usage;
VAR s: ARRAY 256 OF CHAR;
BEGIN
  Args.Get(0, s);
  Out.String('InterOberon compiler, 2022-2023'); Out.Ln; Out.Ln;
  Out.String('Usage:'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' -c <moduleName>'); Out.Ln;
  Out.String('    Compile module to .o and .sym files'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' -l <moduleName>'); Out.Ln;
  Out.String('    Link .o file to executable'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' -r <moduleName>'); Out.Ln;
  Out.String('    Run executable'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' <moduleName>'); Out.Ln;
  Out.String('    Compile, link and run (legacy mode)'); Out.Ln
END Usage;

PROCEDURE RunCompiler(): INTEGER;
VAR s: ARRAY 256 OF CHAR;
  mname: ARRAY 64 OF CHAR;
  res: INTEGER;
BEGIN
  Args.Get(1, s);
  IF Parser.Load(s) THEN
    IF Parser.Compile() THEN
      Parser.GetModName(mname);
      Lang.Write(Lang.compileOk1); Out.Char(' ');
      Out.String(mname); Out.Char(' ');
      Lang.Write(Lang.compileOk2); Out.Ln; Out.Ln;
      Lang.Write(Lang.vmStarting); Out.Ln;
      res := Risc.RunFile(mname);
      Out.Ln;
      IF res = Risc.noError THEN
        Lang.Write(Lang.vmOk); Out.Ln
      ELSIF res = Risc.cantLoad THEN
        Lang.Write(Lang.cantLoadMod); Out.Ln
      ELSE
        Lang.Write(Lang.vmHalt); Out.Char(' ');
        Out.Int(res, 0); Out.Char('.'); Out.Ln
      END
    ELSE
      Lang.Write(Lang.compileFail); Out.Ln;
      res := 1
    END
  ELSE
    Lang.Write(Lang.fileNotLoaded); Out.Ln;
    res := 1
  END
RETURN res END RunCompiler;

PROCEDURE CompileOnly(): INTEGER;
VAR s: ARRAY 256 OF CHAR;
  mname: ARRAY 64 OF CHAR;
  res: INTEGER;
BEGIN
  res := 0;
  Args.Get(2, s);
  IF Parser.Load(s) THEN
    IF Parser.Compile() THEN
      Parser.GetModName(mname);
      Lang.Write(Lang.compileOk1); Out.Char(' ');
      Out.String(mname); Out.Char(' ');
      Lang.Write(Lang.compileOk2); Out.Ln
    ELSE
      Lang.Write(Lang.compileFail); Out.Ln;
      res := 1
    END
  ELSE
    Lang.Write(Lang.fileNotLoaded); Out.Ln;
    res := 1
  END
RETURN res END CompileOnly;

PROCEDURE LinkOnly(): INTEGER;
VAR s: ARRAY 256 OF CHAR;
  res: INTEGER;
BEGIN
  res := 0;
  Args.Get(2, s);
  IF ~Linker.Link(s) THEN
    Lang.Write(Lang.linkFail); Out.Ln;
    res := 1
  END
RETURN res END LinkOnly;

PROCEDURE RunOnly(): INTEGER;
VAR s: ARRAY 256 OF CHAR;
  res: INTEGER;
BEGIN
  Args.Get(2, s);
  Lang.Write(Lang.running); Out.Char(' ');
  Out.String(s); Out.String('...'); Out.Ln;
  res := Risc.RunFile(s);
  Out.Ln;
  IF res = Risc.noError THEN
    Lang.Write(Lang.vmOk); Out.Ln
  ELSIF res = Risc.cantLoad THEN
    Lang.Write(Lang.cantLoadMod); Out.Ln
  ELSE
    Lang.Write(Lang.vmHalt); Out.Char(' ');
    Out.Int(res, 0); Out.Char('.'); Out.Ln
  END
RETURN res END RunOnly;

PROCEDURE Main;
VAR opt: ARRAY 64 OF CHAR;
  code: INTEGER;
BEGIN
  code := 0;
  IF Args.Count() = 1 THEN
    code := RunCompiler()
  ELSIF Args.Count() = 2 THEN
    Args.Get(1, opt);
    IF opt = '-c' THEN
      code := CompileOnly()
    ELSIF opt = '-l' THEN
      code := LinkOnly()
    ELSIF opt = '-r' THEN
      code := RunOnly()
    ELSE
      Usage
    END
  ELSE
    Usage
  END;
  IF code # 0 THEN Platform.ExitOS(code) END
END Main;

BEGIN
  Main
END InterOberon.
