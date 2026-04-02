MODULE InterOberon;
IMPORT Parser, Args, Out, Linker, E := ErrorMsg, M := Machine, Platform;

TYPE
  LONGINT = M.LONGINT;

PROCEDURE Usage;
VAR s: ARRAY 256 OF CHAR;
BEGIN
  Args.Get(0, s);
  Out.String('InterOberon compiler, 2022-2026'); Out.Ln; Out.Ln;
  Out.String('Usage:'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' [-o <dir/ | file>] <moduleName>'); Out.Ln;
  Out.String('    Compile and link'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' [-o <dir/ | file>] -c <moduleName>'); Out.Ln;
  Out.String('    Compile module to .obj and .sym files'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' [-o <dir/ | file>] -l <moduleName>'); Out.Ln;
  Out.String('    Link .obj file to executable'); Out.Ln
END Usage;

PROCEDURE CompileAndLink(argBase: INTEGER): INTEGER;
VAR s: ARRAY 256 OF CHAR;
  mname: ARRAY 64 OF CHAR;
  res: INTEGER;
BEGIN
  res := 0;
  Args.Get(argBase, s);
  IF Parser.Load(s) THEN
    IF Parser.Compile() THEN
      Parser.GetModName(mname);
      M.WriteS2(E.compileOk1, mname, E.compileOk2); Out.Ln;
      IF ~Linker.Link(mname) THEN
        M.WriteError(E.linkFail);
        res := 1
      END
    ELSE
      M.WriteError(E.compileFail);
      res := 1
    END
  ELSE
    M.WriteError(E.fileNotLoaded);
    res := 1
  END
RETURN res END CompileAndLink;

PROCEDURE CompileOnly(argBase: INTEGER): INTEGER;
VAR s: ARRAY 256 OF CHAR;
  mname: ARRAY 64 OF CHAR;
  res: INTEGER;
BEGIN
  res := 0;
  Args.Get(argBase + 1, s);
  IF Parser.Load(s) THEN
    IF Parser.Compile() THEN
      Parser.GetModName(mname);
      M.WriteS2(E.compileOk1, mname, E.compileOk2)
    ELSE
      M.WriteError(E.compileFail);
      res := 1
    END
  ELSE
    M.WriteError(E.fileNotLoaded);
    res := 1
  END
RETURN res END CompileOnly;

PROCEDURE LinkOnly(argBase: INTEGER): INTEGER;
VAR s: ARRAY 256 OF CHAR;
  res: INTEGER;
BEGIN
  res := 0;
  Args.Get(argBase + 1, s);
  IF ~Linker.Link(s) THEN
    M.WriteError(E.linkFail);
    res := 1
  END
RETURN res END LinkOnly;

PROCEDURE Main;
VAR opt: ARRAY 64 OF CHAR;
  code, argBase, nargs: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE; code := 0; argBase := 1;
  nargs := Args.Count();
  IF nargs >= 1 THEN Args.Get(1, opt) ELSE opt := '' END;

  IF (opt = '-h') OR (opt = '--help') THEN
    Usage; ok := TRUE
  ELSE
    (* Parse -o option *)
    IF opt = '-o' THEN
      IF nargs >= 3 THEN
        Args.Get(2, opt);
        M.SetOutDir(opt);
        INC(argBase, 2);
        DEC(nargs, 2)
      END
    END;
    (* Dispatch *)
    IF (nargs = 1) & (opt[0] # '-') THEN
      code := CompileAndLink(argBase); ok := TRUE
    ELSIF nargs = 2 THEN
      Args.Get(argBase, opt);
      IF opt = '-c' THEN
        code := CompileOnly(argBase); ok := TRUE
      ELSIF opt = '-l' THEN
        code := LinkOnly(argBase); ok := TRUE
      END
    END
  END;
  IF ~ok THEN Usage; code := 1 END;
  IF code # 0 THEN Platform.ExitOS(code) END
END Main;

BEGIN
  Main
END InterOberon.
