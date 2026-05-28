MODULE Machine;
IMPORT Out, Lang, Platform, Utf8, Strings, Files, SYSTEM;

CONST
  (** Target-architecture properties.  Currently the InterOberon
      backend is ARM64-only, so these are hard-wired.  When/if a
      32-bit target is added, flip these two constants and the rest
      of the compiler (SymTable's adrIntType, Parser's LONG/SHORT
      handling for ADRINT) will follow automatically. *)
  Is64Bit* = TRUE;
  WordSize* = 8;

  symFileMark* = ORD('S') + 256 * (ORD('Y') + 256 * (ORD('M') + 256 * 1));
  objFileMark* = ORD('A') + 256 * (ORD('R') + 256 * (ORD('M') + 256 * 1));
  objHeaderBytes* = 40;
  objCompileFlagsOff* = 36;
  compileFlagNoAssert* = 1;

TYPE
  LONGINT* = SYSTEM.INT64;
  LONGREAL* = SYSTEM.REAL64;
  SHORTCHAR = Utf8.SHORTCHAR;

VAR
  maxLongInt*, minLongInt*: LONGINT;
  buildDir*, libCacheDir*, outDir*, outExe*, outExeDir*: ARRAY 256 OF CHAR;
  compilingFromLib*: BOOLEAN;
  userModN: INTEGER;
  userMods: ARRAY 64, 32 OF CHAR;

(** Run a command in the OS. For chmod and signing the executable. *)
PROCEDURE Exec*(command: ARRAY OF CHAR): INTEGER;
VAR z: ARRAY 4096 OF SHORTCHAR;
BEGIN
  Utf8.Encode(command, z);
RETURN Platform.System(z) END Exec;

(** Gets localized error text by error code. *)
PROCEDURE GetErrorText*(n: INTEGER; VAR s: ARRAY OF CHAR);
BEGIN
  Lang.GetErrorText(n, s);
  IF s = '' THEN s := 'Unknown error' END
END GetErrorText;

(** Outputs compiler error: file:line:col: error: #N text *)
PROCEDURE Mark*(fname: ARRAY OF CHAR; line, col, errCode: INTEGER);
VAR s: ARRAY 256 OF CHAR;
BEGIN
  Out.String(fname); Out.Char(':');
  Out.Int(line, 0); Out.Char(':'); Out.Int(col, 0);
  Out.String(': error: #'); Out.Int(errCode, 0); Out.Char(' ');
  GetErrorText(errCode, s); Out.String(s); Out.Ln
END Mark;

(** Outputs localized compiler message (no newline). *)
PROCEDURE Write*(msg: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, s);
  Out.String(s)
END Write;

(** Outputs localized compiler message with newline. *)
PROCEDURE WriteLn*(msg: INTEGER);
BEGIN
  Write(msg); Out.Ln
END WriteLn;

(** Outputs localized compiler message with a string parameter: text s *)
PROCEDURE WriteS*(msg: INTEGER; s: ARRAY OF CHAR);
BEGIN
  Write(msg); Out.Char(' '); Out.String(s); Out.Ln
END WriteS;

(** Outputs: msg1 s msg2. E.g. "Module Example has been compiled." *)
PROCEDURE WriteS2*(msg1: INTEGER; s: ARRAY OF CHAR; msg2: INTEGER);
BEGIN
  Write(msg1); Out.Char(' '); Out.String(s);
  Out.Char(' '); WriteLn(msg2)
END WriteS2;

(** Outputs compiler error: error: #N text *)
PROCEDURE WriteError*(msg: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, s);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(s); Out.Ln
END WriteError;

(** Outputs compiler error with a string parameter: error: #N text "s". *)
PROCEDURE WriteErrorS*(msg: INTEGER; s: ARRAY OF CHAR);
VAR t: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, t);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(t);
  Out.String(' "'); Out.String(s); Out.String('".'); Out.Ln
END WriteErrorS;

(** Outputs compiler error with module and command names. *)
PROCEDURE WriteErrorCommand*(msg: INTEGER; modName, procName: ARRAY OF CHAR);
VAR t, inMod, hasNo: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, t);
  Lang.GetCompilerText(27, inMod);
  Lang.GetCompilerText(28, hasNo);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(t); Out.String('. ');
  Out.String(inMod); Out.String(' "'); Out.String(modName);
  Out.String('" '); Out.String(hasNo); Out.String(' "');
  Out.String(procName); Out.String('".'); Out.Ln
END WriteErrorCommand;

(** Outputs compiler error with an integer parameter: error: #N text n. *)
PROCEDURE WriteErrorI*(msg, n: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, s);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(s);
  Out.Char(' '); Out.Int(n, 0); Out.Char('.'); Out.Ln
END WriteErrorI;

PROCEDURE SHORT*(x: LONGINT): INTEGER;
RETURN SYSTEM.VAL(INTEGER, x) END SHORT;

PROCEDURE LONG*(x: INTEGER): LONGINT;
RETURN SYSTEM.VAL(LONGINT, x) END LONG;

PROCEDURE Pow2L(n: INTEGER): LONGINT;
VAR r: LONGINT;
BEGIN
  r := SYSTEM.VAL(LONGINT, 1);
  WHILE n > 0 DO r := r * SYSTEM.VAL(LONGINT, 2); DEC(n) END
RETURN r END Pow2L;

PROCEDURE LSL64*(x: LONGINT; n: INTEGER): LONGINT;
BEGIN
  IF n >= 64 THEN x := SYSTEM.VAL(LONGINT, 0)
  ELSIF n > 0 THEN x := x * Pow2L(n)
  END
RETURN x END LSL64;

PROCEDURE ASR64*(x: LONGINT; n: INTEGER): LONGINT;
BEGIN
  IF n >= 64 THEN
    IF x < SYSTEM.VAL(LONGINT, 0) THEN x := SYSTEM.VAL(LONGINT, -1)
    ELSE x := SYSTEM.VAL(LONGINT, 0)
    END
  ELSIF n > 0 THEN x := x DIV Pow2L(n)
  END
RETURN x END ASR64;

PROCEDURE ROR64*(x: LONGINT; n: INTEGER): LONGINT;
VAR i: INTEGER;
  bit: LONGINT;
  one, zero: LONGINT;
BEGIN
  one := SYSTEM.VAL(LONGINT, 1);
  zero := SYSTEM.VAL(LONGINT, 0);
  n := n MOD 64;
  FOR i := 1 TO n DO
    bit := x - (x DIV SYSTEM.VAL(LONGINT, 2)) * SYSTEM.VAL(LONGINT, 2);
    x := x DIV SYSTEM.VAL(LONGINT, 2);
    IF x < zero THEN x := x + Pow2L(63) END;
    IF bit # zero THEN x := x + Pow2L(63) END
  END
RETURN x END ROR64;

PROCEDURE EnsureDir*(dir: ARRAY OF CHAR): BOOLEAN;
VAR cmd: ARRAY 512 OF CHAR;
  err: INTEGER;
BEGIN
  IF dir = '' THEN err := 0
  ELSE
    Strings.Copy('mkdir -p ', cmd);
    Strings.Append(dir, cmd);
    err := Exec(cmd)
  END
RETURN err = 0 END EnsureDir;

PROCEDURE SetBuildDir*(path: ARRAY OF CHAR);
VAR n: INTEGER;
BEGIN
  Strings.Copy(path, buildDir);
  n := Strings.Length(buildDir);
  IF (n > 0) & (buildDir[n - 1] # '/') THEN
    buildDir[n] := '/'; buildDir[n + 1] := 0X
  END
END SetBuildDir;

PROCEDURE SetLibCacheDir*(path: ARRAY OF CHAR);
VAR n: INTEGER;
BEGIN
  Strings.Copy(path, libCacheDir);
  n := Strings.Length(libCacheDir);
  IF (n > 0) & (libCacheDir[n - 1] # '/') THEN
    libCacheDir[n] := '/'; libCacheDir[n + 1] := 0X
  END
END SetLibCacheDir;

PROCEDURE SetOutDir*(path: ARRAY OF CHAR);
VAR n: INTEGER;
BEGIN
  outExe := '';
  outExeDir := '';
  n := Strings.Length(path);
  IF (n > 0) & (path[n - 1] = '/') THEN
    Strings.Copy(path, outExeDir);
    n := Strings.Length(outExeDir);
    IF (n > 0) & (outExeDir[n - 1] # '/') THEN
      outExeDir[n] := '/'; outExeDir[n + 1] := 0X
    END
  ELSIF n > 0 THEN
    Strings.Copy(path, outExe)
  END
END SetOutDir;

PROCEDURE EnsureBuildDir*(): BOOLEAN;
RETURN EnsureDir(buildDir) END EnsureBuildDir;

PROCEDURE EnsureLibCacheDir*(): BOOLEAN;
RETURN EnsureDir(libCacheDir) END EnsureLibCacheDir;

(** Legacy name: ensure the active object/symbol output directory exists. *)
PROCEDURE EnsureOutDir*(): BOOLEAN;
RETURN EnsureBuildDir() END EnsureOutDir;

PROCEDURE ArtifactPath*(dir, modName, ext: ARRAY OF CHAR; VAR path: ARRAY OF CHAR);
BEGIN
  Strings.Copy(dir, path);
  Strings.Append(modName, path);
  Strings.Append(ext, path)
END ArtifactPath;

PROCEDURE SymMarkOk*(path: ARRAY OF CHAR): BOOLEAN;
VAR F: Files.File;
  R: Files.Rider;
  mark: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  F := Files.Old(path);
  IF F # NIL THEN
    Files.Set(R, F, 0);
    Files.ReadInt(R, mark);
    ok := mark = symFileMark
  END
RETURN ok END SymMarkOk;

PROCEDURE ObjMarkOk*(path: ARRAY OF CHAR): BOOLEAN;
VAR F: Files.File;
  R: Files.Rider;
  mark: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  F := Files.Old(path);
  IF F # NIL THEN
    Files.Set(R, F, 0);
    Files.ReadInt(R, mark);
    ok := mark = objFileMark
  END
RETURN ok END ObjMarkOk;

PROCEDURE ObjCompileFlags*(path: ARRAY OF CHAR): INTEGER;
VAR F: Files.File;
  R: Files.Rider;
  flags: INTEGER;
BEGIN
  flags := -1;
  F := Files.Old(path);
  IF F # NIL THEN
    Files.Set(R, F, objCompileFlagsOff);
    Files.ReadInt(R, flags)
  END
RETURN flags END ObjCompileFlags;

PROCEDURE ObjArtifactOk*(path: ARRAY OF CHAR; expectedFlags: INTEGER): BOOLEAN;
RETURN ObjMarkOk(path) & (ObjCompileFlags(path) = expectedFlags) END ObjArtifactOk;

PROCEDURE TrySymInDir(dir, modName: ARRAY OF CHAR; VAR path: ARRAY OF CHAR): BOOLEAN;
BEGIN
  ArtifactPath(dir, modName, '.sym', path);
RETURN SymMarkOk(path) END TrySymInDir;

PROCEDURE IsUserModule*(modName: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  i := 0;
  WHILE ~ok & (i < userModN) DO
    IF userMods[i] = modName THEN ok := TRUE END;
    INC(i)
  END
RETURN ok END IsUserModule;

PROCEDURE RegisterUserModule*(modName: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  IF ~IsUserModule(modName) & (userModN < LEN(userMods)) THEN
    Strings.Copy(modName, userMods[userModN]);
    INC(userModN)
  END
END RegisterUserModule;

PROCEDURE ResetUserModules*;
BEGIN userModN := 0 END ResetUserModules;

(** Locate a .sym for import. Lib importers use lib cache only. *)
PROCEDURE FindSymFile*(modName: ARRAY OF CHAR; VAR path: ARRAY OF CHAR): BOOLEAN;
VAR ok, user: BOOLEAN;
BEGIN
  ok := FALSE;
  IF compilingFromLib THEN
    IF libCacheDir # '' THEN ok := TrySymInDir(libCacheDir, modName, path) END
  ELSE
    user := IsUserModule(modName);
    IF user & (buildDir # '') THEN ok := TrySymInDir(buildDir, modName, path) END;
    IF ~ok & (libCacheDir # '') THEN ok := TrySymInDir(libCacheDir, modName, path) END;
    IF ~ok & ~user & (buildDir # '') THEN ok := TrySymInDir(buildDir, modName, path) END
  END
RETURN ok END FindSymFile;

PROCEDURE TryObjInDir(dir, modName: ARRAY OF CHAR; VAR path: ARRAY OF CHAR): BOOLEAN;
BEGIN
  ArtifactPath(dir, modName, '.obj', path);
RETURN ObjMarkOk(path) END TryObjInDir;

PROCEDURE FindObjFile*(modName: ARRAY OF CHAR; VAR path: ARRAY OF CHAR): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  ok := FALSE;
  IF buildDir # '' THEN ok := TryObjInDir(buildDir, modName, path) END;
  IF ~ok & (libCacheDir # '') THEN ok := TryObjInDir(libCacheDir, modName, path) END
RETURN ok END FindObjFile;

(** Set active .sym/.obj output directory for the module being compiled. *)
PROCEDURE SetArtifactDir*(dir: ARRAY OF CHAR);
BEGIN Strings.Copy(dir, outDir) END SetArtifactDir;

PROCEDURE SetCompilingFromLib*(fromLib: BOOLEAN);
BEGIN compilingFromLib := fromLib END SetCompilingFromLib;

PROCEDURE FileModTime*(name: ARRAY OF CHAR): INTEGER;
VAR F: Files.File;
  t, d: INTEGER;
BEGIN
  t := 0;
  F := Files.Old(name);
  IF F # NIL THEN Files.GetDate(F, t, d) END
RETURN t END FileModTime;

BEGIN
  maxLongInt := LSL64(LONG(7FFFFFFFH), 32) + LONG(7FFFFFFFH) * 2 + 1;
  minLongInt := -maxLongInt - 1;
  buildDir := '_Build/';
  libCacheDir := '';
  outDir := '_Build/';
  outExe := '';
  outExeDir := '';
  compilingFromLib := FALSE;
  userModN := 0
END Machine.
