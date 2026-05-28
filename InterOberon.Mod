MODULE InterOberon;
IMPORT Files, Strings, Args, Env, Out, Parser, Linker, S := Scanner,
  Lang, E := ErrorMsg, M := Machine, Platform;

CONST
  maxModules = 64;
  maxImps = 32;
  maxName = 64;
  maxPath = 256;
  maxStdlibMods = 8;
  maxHomeRoots = 8;

VAR
  (** All user modules participating in this build. modNames[0] is the root. *)
  modNames: ARRAY maxModules, maxName OF CHAR;
  modPaths: ARRAY maxModules, maxPath OF CHAR;
  modDirs:  ARRAY maxModules, maxPath OF CHAR;
  nMods: INTEGER;

  (** Lib module names for localised import fallback. *)
  stdlibMods: ARRAY maxStdlibMods, maxName OF CHAR;
  nStdlibMods: INTEGER;

  (** Roots for Lib/ and Langs/ lookup. *)
  homeRoots: ARRAY maxHomeRoots, maxPath OF CHAR;
  nHomeRoots: INTEGER;

  (** Per-module import list: canonical names and graph indices. *)
  modImpN: ARRAY maxModules OF INTEGER;
  modImps: ARRAY maxModules, maxImps, maxName OF CHAR;
  modImpIdx: ARRAY maxModules, maxImps OF INTEGER;
  modIsLib: ARRAY maxModules OF BOOLEAN;
  needCompile: ARRAY maxModules OF BOOLEAN;

  topoOrder: ARRAY maxModules OF INTEGER;
  modLinkerIdx: ARRAY maxModules OF INTEGER;
  topoCount: INTEGER;
  visiting:  ARRAY maxModules OF BOOLEAN;
  visited:   ARRAY maxModules OF BOOLEAN;

  (** CLI flags / parsed command. *)
  exactFlag, noExtWarn, noAssert, forceFlag, buildLibFlag, verboseFlag: BOOLEAN;
  cmdMod, cmdProc: ARRAY maxName OF CHAR;
  rootArg: ARRAY maxPath OF CHAR;

PROCEDURE Usage;
VAR s: ARRAY 256 OF CHAR;
BEGIN
  Args.Get(0, s);
  Out.String('InterOberon compiler, 2022-2026'); Out.Ln; Out.Ln;
  Out.String('Usage:'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' [options] <Source[.ext]> [Command]'); Out.Ln;
  Out.String('  '); Out.String(s); Out.String(' [options] <Mod.Proc>'); Out.Ln; Out.Ln;
  Out.String('Options:'); Out.Ln;
  Out.String('  -o <file | dir/>  Executable path (default: ./<RootMod>)'); Out.Ln;
  Out.String('  --build-dir <d/> Object/symbol output (default: _Build/)'); Out.Ln;
  Out.String('  -f, --force       Recompile all modules'); Out.Ln;
  Out.String('  --build-lib       Populate Lib/_Build/ from Lib/ sources'); Out.Ln;
  Out.String('  --verbose         Print module build/up-to-date messages'); Out.Ln;
  Out.String('  -c                Compile to .obj/.sym only (no link)'); Out.Ln;
  Out.String('  -l                Link a single .obj only'); Out.Ln;
  Out.String('  --cmd <Mod.Proc>  Specify program command'); Out.Ln;
  Out.String('  --exact           Use source path as-is (no extension search)'); Out.Ln;
  Out.String('  --no-ext-warn     Suppress duplicate-extension warning'); Out.Ln;
  Out.String('  --no-assert       Omit code generation for ASSERT'); Out.Ln;
  Out.String('  -h, --help        Show this help'); Out.Ln; Out.Ln;
  Out.String('Environment:'); Out.Ln;
  Out.String('  INTEROBERON_ROOT  Colon-separated install roots that hold'); Out.Ln;
  Out.String('                    Lib/ and Langs/.  CWD and the directory'); Out.Ln;
  Out.String('                    of the running compiler are always tried.'); Out.Ln
END Usage;

(** Splits 'dir/foo.Mod' into dir 'dir/' and base 'foo.Mod' (ext kept). *)
PROCEDURE SplitPath(path: ARRAY OF CHAR; VAR dir, base: ARRAY OF CHAR);
VAR i, last: INTEGER;
BEGIN
  last := -1;
  i := 0;
  WHILE path[i] # 0X DO
    IF path[i] = '/' THEN last := i END;
    INC(i)
  END;
  IF last >= 0 THEN
    i := 0;
    WHILE i <= last DO dir[i] := path[i]; INC(i) END;
    dir[i] := 0X;
    i := 0;
    WHILE path[last + 1 + i] # 0X DO base[i] := path[last + 1 + i]; INC(i) END;
    base[i] := 0X
  ELSE
    dir[0] := 0X;
    Strings.Copy(path, base)
  END
END SplitPath;

(** Strip the longest extension from name (chars after last '.'); writes plain base. *)
PROCEDURE StripExt(name: ARRAY OF CHAR; VAR plain: ARRAY OF CHAR);
VAR i, last: INTEGER;
BEGIN
  last := -1;
  i := 0;
  WHILE name[i] # 0X DO
    IF name[i] = '.' THEN last := i END;
    INC(i)
  END;
  IF last >= 0 THEN
    i := 0;
    WHILE i < last DO plain[i] := name[i]; INC(i) END;
    plain[i] := 0X
  ELSE
    Strings.Copy(name, plain)
  END
END StripExt;

PROCEDURE FileExists(path: ARRAY OF CHAR): BOOLEAN;
VAR f: Files.File;
BEGIN f := Files.Old(path)
RETURN f # NIL END FileExists;

(** Try extensions; returns first found path. Counts how many of the candidate
    extensions exist (used for duplicate warning). *)
(** Returns true iff two existing file paths denote the same file content
    (case-insensitive filesystems make `.Mod` and `.mod` resolve to the same
    inode). We just compare lengths as a cheap proxy. *)
PROCEDURE SameFile(a, b: ARRAY OF CHAR): BOOLEAN;
VAR fa, fb: Files.File;
  same: BOOLEAN;
BEGIN
  fa := Files.Old(a); fb := Files.Old(b);
  same := (fa # NIL) & (fb # NIL) & (Files.Length(fa) = Files.Length(fb))
RETURN same END SameFile;

PROCEDURE TryExts(dir, plain: ARRAY OF CHAR;
    VAR foundPath: ARRAY OF CHAR; VAR nMatches: INTEGER): BOOLEAN;
VAR p: ARRAY maxPath OF CHAR;
  exts: ARRAY 4, 8 OF CHAR;
  i, found: INTEGER;
  ok: BOOLEAN;
BEGIN
  exts[0] := '.Mod'; exts[1] := '.mod'; exts[2] := '.o7'; exts[3] := '.ob';
  found := -1; nMatches := 0;
  i := 0;
  WHILE i < 4 DO
    Strings.Copy(dir, p);
    Strings.Append(plain, p);
    Strings.Append(exts[i], p);
    IF FileExists(p) THEN
      IF found < 0 THEN
        Strings.Copy(p, foundPath);
        found := i;
        nMatches := 1
      ELSIF ~SameFile(p, foundPath) THEN
        INC(nMatches)
      END
    END;
    INC(i)
  END;
  ok := found >= 0
RETURN ok END TryExts;

(** Resolve a source path:
    - If exact: must be an existing file.
    - Else: if the input has an extension and exists, use it.
            Otherwise treat the trailing identifier as plain base, search extensions. *)
PROCEDURE ResolveSource(arg: ARRAY OF CHAR; exact: BOOLEAN;
    VAR foundPath: ARRAY OF CHAR;
    VAR dir, modName: ARRAY OF CHAR): BOOLEAN;
VAR base, plain: ARRAY maxPath OF CHAR;
  nMatches: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  SplitPath(arg, dir, base);
  IF exact THEN
    Strings.Copy(arg, foundPath);
    IF FileExists(foundPath) THEN
      StripExt(base, plain);
      Strings.Copy(plain, modName);
      ok := TRUE
    END
  ELSE
    IF FileExists(arg) THEN
      Strings.Copy(arg, foundPath);
      StripExt(base, plain);
      Strings.Copy(plain, modName);
      ok := TRUE
    ELSE
      StripExt(base, plain);
      ok := TryExts(dir, plain, foundPath, nMatches);
      IF ok THEN
        Strings.Copy(plain, modName);
        IF (nMatches > 1) & ~noExtWarn THEN
          M.WriteErrorS(E.multipleExt, foundPath)
        END
      END
    END
  END;
  IF ~ok THEN M.WriteErrorS(E.fileNotFound, arg) END
RETURN ok END ResolveSource;

(** Reads the MODULE name and the IMPORT list from a source file using Scanner.
    nImports may be 0.  Returns FALSE on parse error or if not a recognized
    header.  If modTrans is provided, also captures up to S.maxTrans
    language-keyed translations of the module name from the
    (**%XX:Name*) comment immediately following the MODULE semicolon. *)
PROCEDURE ScanHeader(srcPath: ARRAY OF CHAR;
    VAR modName: ARRAY OF CHAR;
    VAR modTrans: ARRAY OF ARRAY OF CHAR;
    VAR nModTrans: INTEGER;
    VAR imps: ARRAY OF ARRAY OF CHAR;
    VAR nImps: INTEGER): BOOLEAN;
VAR sym, t, c, k: INTEGER;
  ok, langed: BOOLEAN;
  alias, name: ARRAY maxName OF CHAR;
BEGIN
  ok := FALSE;
  nImps := 0; nModTrans := 0;
  IF S.Load(srcPath) THEN
    S.Get(sym);
    langed := FALSE;
    IF sym = S.module THEN
      langed := TRUE
    ELSIF (sym = S.ident) & Lang.Identify(S.id) THEN
      langed := TRUE; S.Rewind; S.Get(sym)
    END;
    IF langed THEN
      IF sym = S.module THEN
        S.Get(sym);
        IF sym = S.ident THEN
          Strings.Copy(S.id, modName);
          S.Get(sym);
          IF sym = S.semicol THEN
            S.Get(sym);
            (* After consuming ';', S.transLang/transNames hold the
               translations from a comment like
                 MODULE In; (**%RU:Ввод%LV:Ievade*) *)
            IF S.transCount > 0 THEN
              t := 0;
              WHILE (t < S.transCount) & (nModTrans < LEN(modTrans)) DO
                (* transNames may have multiple comma-separated entries
                   for the same language; for module names we expect
                   exactly one, so we copy up to the first ',' or end. *)
                k := 0;
                WHILE (S.transNames[t, k] # 0X) & (S.transNames[t, k] # ',') &
                      (k < LEN(modTrans[0]) - 1) DO
                  modTrans[nModTrans, k] := S.transNames[t, k];
                  INC(k)
                END;
                modTrans[nModTrans, k] := 0X;
                INC(nModTrans);
                INC(t)
              END;
              c := 0; (* avoid "unused" *) c := c
            END;
            ok := TRUE;
            IF sym = S.import THEN
              S.Get(sym);
              WHILE ok & (sym = S.ident) DO
                Strings.Copy(S.id, alias);
                Strings.Copy(S.id, name);
                S.Get(sym);
                IF sym = S.becomes THEN
                  S.Get(sym);
                  IF sym = S.ident THEN
                    Strings.Copy(S.id, name);
                    S.Get(sym)
                  ELSE ok := FALSE
                  END
                END;
                IF ok & (nImps < LEN(imps)) THEN
                  Strings.Copy(name, imps[nImps]);
                  INC(nImps)
                END;
                IF ok & (sym = S.comma) THEN S.Get(sym) END
              END
            END
          END
        END
      END
    END
  END
RETURN ok END ScanHeader;

(** Returns TRUE if name is a built-in module known to the compiler
    proper (i.e. resolved entirely inside SymTable, with no .obj/.sym
    file).  In and Out used to live here but now ship as ordinary
    sources under Lib/, so SYSTEM is the only remaining intrinsic. *)
PROCEDURE IsBuiltinModule(name: ARRAY OF CHAR): BOOLEAN;
RETURN name = 'SYSTEM' END IsBuiltinModule;

PROCEDURE FindModule(name: ARRAY OF CHAR): INTEGER;
VAR i: INTEGER;
BEGIN i := 0;
  WHILE (i < nMods) & (modNames[i] # name) DO INC(i) END;
  IF i >= nMods THEN i := -1 END
RETURN i END FindModule;

PROCEDURE FindModuleByPath(path: ARRAY OF CHAR): INTEGER;
VAR i: INTEGER;
BEGIN i := 0;
  WHILE (i < nMods) & (modPaths[i] # path) DO INC(i) END;
  IF i >= nMods THEN i := -1 END
RETURN i END FindModuleByPath;

PROCEDURE PathIsLib(path: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := (path[0] = 'L') & (path[1] = 'i') & (path[2] = 'b') & (path[3] = '/');
  IF ~ok THEN
    i := 0;
    WHILE (path[i] # 0X) & ~ok DO
      IF (path[i] = '/') & (path[i + 1] = 'L') & (path[i + 2] = 'i') & (path[i + 3] = 'b') &
         (path[i + 4] = '/') THEN ok := TRUE END;
      INC(i)
    END
  END
RETURN ok END PathIsLib;

PROCEDURE InitLibCacheDir;
VAR cache: ARRAY maxPath OF CHAR;
  r: INTEGER;
  done: BOOLEAN;
BEGIN
  done := FALSE;
  r := 0;
  WHILE ~done & (r < nHomeRoots) DO
    IF homeRoots[r] # 0X THEN
      Strings.Copy(homeRoots[r], cache);
      Strings.Append('Lib/_Build/', cache);
      M.SetLibCacheDir(cache);
      done := TRUE
    END;
    INC(r)
  END;
  IF ~done THEN M.SetLibCacheDir('Lib/_Build/') END
END InitLibCacheDir;

PROCEDURE ModuleArtifactDir(idx: INTEGER; VAR dir: ARRAY OF CHAR);
BEGIN
  IF modIsLib[idx] THEN Strings.Copy(M.libCacheDir, dir)
  ELSE Strings.Copy(M.buildDir, dir)
  END
END ModuleArtifactDir;

PROCEDURE ObjPathFor(idx: INTEGER; VAR path: ARRAY OF CHAR);
VAR dir: ARRAY maxPath OF CHAR;
BEGIN
  ModuleArtifactDir(idx, dir);
  M.ArtifactPath(dir, modNames[idx], '.obj', path)
END ObjPathFor;

PROCEDURE ExpectedCompileFlags(): INTEGER;
VAR flags: INTEGER;
BEGIN
  flags := 0;
  IF noAssert THEN flags := flags + M.compileFlagNoAssert END
RETURN flags END ExpectedCompileFlags;

PROCEDURE ArtifactsCurrent(idx: INTEGER): BOOLEAN;
VAR dir, sym, obj: ARRAY maxPath OF CHAR;
  tSrc, tSym, tObj: INTEGER;
  expFlags: INTEGER;
BEGIN
  ModuleArtifactDir(idx, dir);
  M.ArtifactPath(dir, modNames[idx], '.sym', sym);
  M.ArtifactPath(dir, modNames[idx], '.obj', obj);
  tSrc := M.FileModTime(modPaths[idx]);
  tSym := M.FileModTime(sym);
  tObj := M.FileModTime(obj);
  expFlags := ExpectedCompileFlags();
RETURN (tSrc > 0) & (tSym >= tSrc) & (tObj >= tSrc) &
       M.SymMarkOk(sym) & M.ObjArtifactOk(obj, expFlags) END ArtifactsCurrent;

PROCEDURE MarkNeedsCompile;
VAR i, j, dep, changed: INTEGER;
BEGIN
  i := 0;
  WHILE i < nMods DO
    needCompile[i] := forceFlag OR ~ArtifactsCurrent(i);
    INC(i)
  END;
  changed := 1;
  WHILE changed # 0 DO
    changed := 0;
    i := 0;
    WHILE i < nMods DO
      j := 0;
      WHILE j < modImpN[i] DO
        dep := modImpIdx[i, j];
        IF (dep >= 0) & needCompile[dep] & ~needCompile[i] THEN
          needCompile[i] := TRUE;
          changed := 1
        END;
        INC(j)
      END;
      INC(i)
    END
  END
END MarkNeedsCompile;

(** Append a search root to homeRoots, deduplicating by literal
    string match.  Silently truncates anything past maxHomeRoots. *)
PROCEDURE AddHomeRoot(root: ARRAY OF CHAR);
VAR i: INTEGER; dup: BOOLEAN;
BEGIN
  dup := FALSE;
  i := 0;
  WHILE i < nHomeRoots DO
    IF homeRoots[i] = root THEN dup := TRUE END;
    INC(i)
  END;
  IF ~dup & (nHomeRoots < maxHomeRoots) THEN
    Strings.Copy(root, homeRoots[nHomeRoots]);
    INC(nHomeRoots)
  END
END AddHomeRoot;

(** Build the install-root search list and publish the Langs/ search
    list to Lang.Mod.  Conceptually mirrors Go's GOROOT discovery: an
    optional environment variable overrides the default, otherwise we
    fall back to the directory of the running binary so the compiler
    works no matter what the user's CWD is. *)
PROCEDURE InitHomeRoots;
VAR envPath, appDir, root: ARRAY maxPath OF CHAR;
  i, j: INTEGER;
BEGIN
  nHomeRoots := 0;
  (* 1. $INTEROBERON_ROOT -- colon-separated list of directories. *)
  Env.GetByName('INTEROBERON_ROOT', envPath);
  IF envPath[0] # 0X THEN
    i := 0;
    WHILE envPath[i] # 0X DO
      j := 0;
      WHILE (envPath[i] # 0X) & (envPath[i] # ':') & (j < LEN(root) - 2) DO
        root[j] := envPath[i]; INC(i); INC(j)
      END;
      IF (j > 0) & (root[j - 1] # '/') THEN root[j] := '/'; INC(j) END;
      root[j] := 0X;
      IF j > 0 THEN AddHomeRoot(root) END;
      IF envPath[i] = ':' THEN INC(i) END
    END
  END;
  (* 2. CWD -- for running from the source tree (Lib/, Langs/ siblings). *)
  AddHomeRoot('');
  (* 3. <AppDir> -- where Lib/ and Langs/ live when installed. *)
  Env.GetAppDir(appDir);
  IF appDir[0] # 0X THEN AddHomeRoot(appDir) END;
  (* Publish the Langs/ search list to Lang.Mod so language-file lookup
     works the same way as stdlib source lookup. *)
  Lang.ResetSearchRoots;
  i := 0;
  WHILE i < nHomeRoots DO
    Strings.Copy(homeRoots[i], root);
    Strings.Append('Langs/', root);
    Lang.AddSearchRoot(root);
    INC(i)
  END;
  InitLibCacheDir
END InitHomeRoots;

(** Iterate home roots, trying TryExts in '<root>Lib/' for each.
    Returns the first hit; sets foundRoot to the Lib/ directory that
    matched (so callers recursing into the same dir keep using it). *)
PROCEDURE TryStdlibExts(plain: ARRAY OF CHAR;
    VAR foundPath, foundRoot: ARRAY OF CHAR;
    VAR nMatches: INTEGER): BOOLEAN;
VAR i, m: INTEGER;
  libDir, cand: ARRAY maxPath OF CHAR;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  i := 0;
  WHILE ~ok & (i < nHomeRoots) DO
    Strings.Copy(homeRoots[i], libDir);
    Strings.Append('Lib/', libDir);
    IF TryExts(libDir, plain, cand, m) THEN
      Strings.Copy(cand, foundPath);
      Strings.Copy(libDir, foundRoot);
      nMatches := m;
      ok := TRUE
    END;
    INC(i)
  END
RETURN ok END TryStdlibExts;

(** Tries to find a stdlib source file whose canonical or translated
    MODULE name equals `target`.  Returns TRUE and sets foundPath,
    foundRoot, canonical if a match is found; canonical is the on-disk
    name (e.g. 'In' for a Russian source importing 'Ввод'). *)
PROCEDURE FindStdlibByTrans(target: ARRAY OF CHAR;
    VAR foundPath, foundRoot, canonical: ARRAY OF CHAR): BOOLEAN;
VAR r, k, n, nMatches, j: INTEGER;
  libDir, candPath, candMod: ARRAY maxPath OF CHAR;
  trans: ARRAY 8, maxName OF CHAR;
  imps: ARRAY maxImps, maxName OF CHAR;
  nImps: INTEGER;
  ok, match: BOOLEAN;
BEGIN
  ok := FALSE;
  r := 0;
  WHILE ~ok & (r < nHomeRoots) DO
    Strings.Copy(homeRoots[r], libDir);
    Strings.Append('Lib/', libDir);
    k := 0;
    WHILE ~ok & (k < nStdlibMods) DO
      IF TryExts(libDir, stdlibMods[k], candPath, nMatches) THEN
        IF ScanHeader(candPath, candMod, trans, n, imps, nImps) THEN
          match := candMod = target;
          j := 0;
          WHILE ~match & (j < n) DO
            IF trans[j] = target THEN match := TRUE END;
            INC(j)
          END;
          IF match THEN
            Strings.Copy(candPath, foundPath);
            Strings.Copy(libDir, foundRoot);
            Strings.Copy(stdlibMods[k], canonical);
            ok := TRUE
          END
        END
      END;
      INC(k)
    END;
    INC(r)
  END
RETURN ok END FindStdlibByTrans;

(** Recursively scans a source's imports, adding each user module to the
    build set, looking up adjacent files in the same directory.  Returns
    FALSE on errors or when the dependency closure exceeds maxModules. *)
PROCEDURE Discover(srcPath, dir: ARRAY OF CHAR; VAR myIdx: INTEGER): BOOLEAN;
VAR modName: ARRAY maxName OF CHAR;
  imps: ARRAY maxImps, maxName OF CHAR;
  modTrans: ARRAY 8, maxName OF CHAR;
  nImps, nModTrans, i, depIdx, nMatches: INTEGER;
  depPath, depDir, depMod, depCanon: ARRAY maxPath OF CHAR;
  ok: BOOLEAN;
BEGIN
  myIdx := FindModuleByPath(srcPath);
  IF myIdx >= 0 THEN
    ok := TRUE
  ELSE
  ok := ScanHeader(srcPath, modName, modTrans, nModTrans, imps, nImps);
  IF ~ok THEN
    M.WriteErrorS(E.fileNotLoaded, srcPath)
  ELSIF nMods >= maxModules THEN
    M.WriteError(E.outOfMemory);
    ok := FALSE
  ELSE
    myIdx := nMods;
    Strings.Copy(modName, modNames[myIdx]);
    Strings.Copy(srcPath, modPaths[myIdx]);
    Strings.Copy(dir, modDirs[myIdx]);
    modIsLib[myIdx] := PathIsLib(srcPath);
    IF ~modIsLib[myIdx] THEN M.RegisterUserModule(modName) END;
    modImpN[myIdx] := 0;
    INC(nMods);
    i := 0;
    WHILE ok & (i < nImps) DO
      IF ~IsBuiltinModule(imps[i]) THEN
        depIdx := -1;
        Strings.Copy(imps[i], depCanon);
        IF TryExts(dir, imps[i], depPath, nMatches) THEN
          depIdx := FindModuleByPath(depPath);
          IF depIdx < 0 THEN
            Strings.Copy(dir, depDir);
            IF (nMatches > 1) & ~noExtWarn THEN
              M.WriteErrorS(E.multipleExt, depPath)
            END;
            IF ~Discover(depPath, depDir, depIdx) THEN ok := FALSE END
          ELSIF (~modIsLib[myIdx]) & PathIsLib(modPaths[depIdx]) &
                ~SameFile(depPath, modPaths[depIdx]) THEN
            depIdx := FindModuleByPath(depPath);
            IF depIdx < 0 THEN
              Strings.Copy(dir, depDir);
              IF ~Discover(depPath, depDir, depIdx) THEN ok := FALSE END
            END
          END
        END;
        IF ok & (depIdx < 0) & TryStdlibExts(imps[i], depPath, depDir, nMatches) THEN
          depIdx := FindModuleByPath(depPath);
          IF depIdx < 0 THEN
            IF (nMatches > 1) & ~noExtWarn THEN
              M.WriteErrorS(E.multipleExt, depPath)
            END;
            IF ~Discover(depPath, depDir, depIdx) THEN ok := FALSE END
          END
        END;
        IF ok & (depIdx < 0) & FindStdlibByTrans(imps[i], depPath, depDir, depMod) THEN
          depIdx := FindModuleByPath(depPath);
          IF depIdx < 0 THEN
            IF ~Discover(depPath, depDir, depIdx) THEN ok := FALSE END
          END
        END;
        IF ok & (depIdx < 0) THEN
          Strings.Copy(dir, depPath);
          Strings.Append(imps[i], depPath);
          IF ~ResolveSource(depPath, FALSE, depPath, depDir, depMod) THEN ok := FALSE END
        END;
        IF ok & (depIdx >= 0) THEN
          Strings.Copy(modNames[depIdx], depCanon)
        END;
        IF ok & (depIdx >= 0) & (modImpN[myIdx] < maxImps) THEN
          modImpIdx[myIdx, modImpN[myIdx]] := depIdx;
          Strings.Copy(depCanon, modImps[myIdx, modImpN[myIdx]]);
          INC(modImpN[myIdx])
        END
      END;
      INC(i)
    END;
    IF ok & (modName # 'Heap') & (modName # 'Kernel') THEN
      depIdx := FindModule('Heap');
      IF depIdx < 0 THEN
        IF TryStdlibExts('Heap', depPath, depDir, nMatches) THEN
          IF ~Discover(depPath, depDir, depIdx) THEN ok := FALSE END
        ELSE
          ok := FALSE;
          M.WriteErrorS(E.fileNotLoaded, 'Heap')
        END
      END;
      IF ok & (depIdx >= 0) & (modImpN[myIdx] < maxImps) THEN
        modImpIdx[myIdx, modImpN[myIdx]] := depIdx;
        Strings.Copy('Heap', modImps[myIdx, modImpN[myIdx]]);
        INC(modImpN[myIdx])
      END
    END;
    IF ok & (modName # 'Kernel') & (modName # 'Heap') & (modName # 'Utf8')
        & (modName # 'Platform') & (modName # 'In') & (modName # 'Out') THEN
      depIdx := FindModule('Kernel');
      IF depIdx < 0 THEN
        IF TryStdlibExts('Kernel', depPath, depDir, nMatches) THEN
          IF ~Discover(depPath, depDir, depIdx) THEN ok := FALSE END
        ELSE
          ok := FALSE;
          M.WriteErrorS(E.fileNotLoaded, 'Kernel')
        END
      END;
      IF ok & (depIdx >= 0) & (modImpN[myIdx] < maxImps) THEN
        modImpIdx[myIdx, modImpN[myIdx]] := depIdx;
        Strings.Copy('Kernel', modImps[myIdx, modImpN[myIdx]]);
        INC(modImpN[myIdx])
      END
    END
  END
  END
RETURN ok END Discover;

(** DFS-based topological sort with cycle detection. *)
PROCEDURE Visit(idx: INTEGER): BOOLEAN;
VAR i, depIdx: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  IF visiting[idx] THEN
    M.WriteErrorS(E.importCycle, modNames[idx]);
    ok := FALSE
  ELSIF ~visited[idx] THEN
    visiting[idx] := TRUE;
    i := 0;
    WHILE ok & (i < modImpN[idx]) DO
      depIdx := modImpIdx[idx, i];
      IF depIdx >= 0 THEN
        IF ~Visit(depIdx) THEN ok := FALSE END
      END;
      INC(i)
    END;
    visiting[idx] := FALSE;
    visited[idx] := TRUE;
    topoOrder[topoCount] := idx;
    INC(topoCount)
  END
RETURN ok END Visit;

PROCEDURE TopoSort(): BOOLEAN;
VAR i: INTEGER;
  ok: BOOLEAN;
BEGIN
  i := 0;
  WHILE i < nMods DO visiting[i] := FALSE; visited[i] := FALSE; INC(i) END;
  topoCount := 0;
  ok := TRUE;
  i := 0;
  WHILE ok & (i < nMods) DO
    IF ~visited[i] THEN
      IF ~Visit(i) THEN ok := FALSE END
    END;
    INC(i)
  END
RETURN ok END TopoSort;

PROCEDURE CompileOne(idx: INTEGER): BOOLEAN;
VAR mname: ARRAY maxName OF CHAR;
  dir: ARRAY maxPath OF CHAR;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  IF ~needCompile[idx] THEN
    IF verboseFlag THEN M.WriteS2(E.compileOk1, modNames[idx], E.compileSkip) END;
    ok := TRUE
  ELSE
    ModuleArtifactDir(idx, dir);
    M.SetArtifactDir(dir);
    M.SetCompilingFromLib(modIsLib[idx]);
    IF Parser.Load(modPaths[idx]) THEN
      IF Parser.Compile() THEN
        Parser.GetModName(mname);
        IF verboseFlag THEN M.WriteS2(E.compileOk1, mname, E.compileOk2) END;
        ok := TRUE
      ELSE
        M.WriteError(E.compileFail)
      END
    ELSE
      M.WriteErrorS(E.fileNotLoaded, modPaths[idx])
    END
  END
RETURN ok END CompileOne;

(** Parse a 'Mod.Proc' or just 'Proc' command spec into cmdMod/cmdProc. *)
PROCEDURE ParseCmdSpec(spec: ARRAY OF CHAR): BOOLEAN;
VAR i, dot: INTEGER;
  ok: BOOLEAN;
BEGIN
  dot := -1; i := 0;
  WHILE spec[i] # 0X DO
    IF spec[i] = '.' THEN dot := i END;
    INC(i)
  END;
  ok := TRUE;
  IF dot > 0 THEN
    i := 0;
    WHILE i < dot DO cmdMod[i] := spec[i]; INC(i) END;
    cmdMod[i] := 0X;
    i := dot + 1;
    WHILE spec[i] # 0X DO cmdProc[i - dot - 1] := spec[i]; INC(i) END;
    cmdProc[i - dot - 1] := 0X;
    IF (cmdMod[0] = 0X) OR (cmdProc[0] = 0X) THEN ok := FALSE END
  ELSIF dot < 0 THEN
    cmdMod[0] := 0X;
    Strings.Copy(spec, cmdProc)
  ELSE ok := FALSE
  END
RETURN ok END ParseCmdSpec;

(** Returns TRUE if name "looks like" a Mod.Proc spec (capital identifier with
    one '.' separating two identifiers).  Used to detect single-token form. *)
PROCEDURE LooksLikeQualified(s: ARRAY OF CHAR): BOOLEAN;
VAR i, lastSlash, lastDot: INTEGER;
  ok: BOOLEAN;
BEGIN
  lastSlash := -1; lastDot := -1; i := 0;
  WHILE s[i] # 0X DO
    IF (s[i] = '/') OR (s[i] = '\') THEN lastSlash := i
    ELSIF s[i] = '.' THEN lastDot := i
    END;
    INC(i)
  END;
  ok := (lastDot > lastSlash + 1) & (lastDot > 0);
  IF ok THEN
    IF (s[lastDot + 1] < 'A') OR (s[lastDot + 1] > 'Z') THEN ok := FALSE END
  END
RETURN ok END LooksLikeQualified;

(** Resolves the current cmdMod/cmdProc against the discovered module set.
    If cmdMod is empty (short form like 'Run'), the procedure must live in
    the single root module supplied on the CLI. *)
PROCEDURE ResolveCommand(rootIdx: INTEGER): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  ok := TRUE;
  IF cmdProc[0] = 0X THEN
    (* No command -> just init chain *)
  ELSIF cmdMod[0] = 0X THEN
    IF rootIdx >= 0 THEN
      Strings.Copy(modNames[rootIdx], cmdMod)
    ELSE
      M.WriteError(E.cmdAmbiguous);
      ok := FALSE
    END
  ELSE
    IF FindModule(cmdMod) < 0 THEN
      M.WriteError(E.noModuleForCmd);
      ok := FALSE
    END
  END
RETURN ok END ResolveCommand;

(** Run the full multi-module build: discover -> topo -> compile -> link. *)
PROCEDURE BuildLibCache(): INTEGER;
VAR k, idx, i, res: INTEGER;
  depPath, depDir: ARRAY maxPath OF CHAR;
  nMatches: INTEGER;
  ok: BOOLEAN;
  savedForce: BOOLEAN;
BEGIN
  nMods := 0;
  M.ResetUserModules;
  savedForce := forceFlag;
  forceFlag := TRUE;
  ok := TRUE;
  k := 0;
  WHILE ok & (k < nStdlibMods) DO
    IF TryStdlibExts(stdlibMods[k], depPath, depDir, nMatches) THEN
      IF FindModuleByPath(depPath) < 0 THEN
        IF ~Discover(depPath, depDir, idx) THEN ok := FALSE END
      END
    END;
    INC(k)
  END;
  IF ok THEN ok := TopoSort() END;
  IF ok THEN
    ok := M.EnsureLibCacheDir();
    IF ~ok THEN M.WriteErrorS(E.cantCreateFile, M.libCacheDir) END
  END;
  IF ok THEN
    MarkNeedsCompile;
    Parser.ResetCanonical;
    i := 0;
    WHILE i < nMods DO
      Parser.RegisterCanonical(modNames[i]); INC(i)
    END;
    i := 0;
    WHILE ok & (i < topoCount) DO
      IF ~CompileOne(topoOrder[i]) THEN ok := FALSE END;
      INC(i)
    END
  END;
  forceFlag := savedForce;
  IF ok THEN res := 0 ELSE res := 1 END
RETURN res END BuildLibCache;

PROCEDURE BuildAndLink(noLink: BOOLEAN): INTEGER;
VAR i, j, k, gIdx, rootIdx, res: INTEGER;
  ok: BOOLEAN;
  rootPath, rootDir, rootMod, depName: ARRAY maxPath OF CHAR;
  exeName: ARRAY maxPath OF CHAR;
BEGIN
  nMods := 0;
  M.ResetUserModules;
  ok := ResolveSource(rootArg, exactFlag, rootPath, rootDir, rootMod);
  IF ok THEN
    ok := Discover(rootPath, rootDir, rootIdx)
  END;
  IF ok THEN ok := TopoSort() END;
  IF ok THEN ok := ResolveCommand(rootIdx) END;
  IF ok THEN
    ok := M.EnsureBuildDir();
    IF ~ok THEN M.WriteErrorS(E.cantCreateFile, M.buildDir) END
  END;
  IF ok THEN
    MarkNeedsCompile;
    i := 0;
    WHILE ok & (i < nMods) DO
      IF needCompile[i] & modIsLib[i] THEN ok := M.EnsureLibCacheDir() END;
      INC(i)
    END;
    IF ~ok THEN M.WriteErrorS(E.cantCreateFile, M.libCacheDir) END
  END;
  IF ok THEN
    (* Publish every discovered module's canonical name so the parser /
       symbol table can resolve translated imports (e.g. 'Ввод' -> 'In')
       by peeking at the matching .sym file. *)
    Parser.ResetCanonical;
    Parser.SetNoAssert(noAssert);
    i := 0;
    WHILE i < nMods DO
      Parser.RegisterCanonical(modNames[i]); INC(i)
    END;
    i := 0;
    WHILE ok & (i < topoCount) DO
      IF ~CompileOne(topoOrder[i]) THEN ok := FALSE END;
      INC(i)
    END
  END;
  IF ok & ~noLink & (M.outExeDir[0] # 0X) THEN
    ok := M.EnsureDir(M.outExeDir);
    IF ~ok THEN M.WriteErrorS(E.cantCreateFile, M.outExeDir) END
  END;
  IF ok & ~noLink THEN
    Linker.Reset;
    i := 0;
    WHILE ok & (i < topoCount) DO
      ObjPathFor(topoOrder[i], exeName);
      IF ~Linker.AddModulePath(exeName) THEN ok := FALSE
      ELSE modLinkerIdx[topoOrder[i]] := i
      END;
      INC(i)
    END;
    i := 0;
    WHILE ok & (i < topoCount) DO
      gIdx := topoOrder[i];
      j := 0;
      WHILE ok & (j < Linker.ImportCount(i)) DO
        Linker.ImportName(i, j, depName);
        k := 0;
        WHILE k < modImpN[gIdx] DO
          IF modImps[gIdx, k] = depName THEN
            Linker.SetImportBind(i, j, modLinkerIdx[modImpIdx[gIdx, k]]);
            k := modImpN[gIdx]
          END;
          INC(k)
        END;
        INC(j)
      END;
      INC(i)
    END;
    IF ok & (cmdProc[0] # 0X) THEN
      IF ~Linker.SetCommand(cmdMod, cmdProc) THEN ok := FALSE END
    END;
    IF ok THEN
      IF M.outExe[0] # 0X THEN
        Strings.Copy(M.outExe, exeName)
      ELSIF M.outExeDir[0] # 0X THEN
        Strings.Copy(M.outExeDir, exeName);
        Strings.Append(modNames[rootIdx], exeName)
      ELSE
        Strings.Copy(modNames[rootIdx], exeName)
      END;
      IF ~Linker.LinkAll(exeName) THEN
        M.WriteError(E.linkFail);
        ok := FALSE
      END
    END
  END;
  IF ok THEN res := 0 ELSE res := 1 END
RETURN res END BuildAndLink;

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
VAR a, opt: ARRAY 256 OF CHAR;
  code, i, n: INTEGER;
  noLink, helped, gotRoot, gotCmd, done: BOOLEAN;
  positional: ARRAY 4, 256 OF CHAR;
  nPos: INTEGER;
BEGIN
  exactFlag := FALSE;
  noExtWarn := FALSE;
  noAssert := FALSE;
  forceFlag := FALSE;
  buildLibFlag := FALSE;
  verboseFlag := FALSE;
  cmdMod[0] := 0X; cmdProc[0] := 0X;
  noLink := FALSE; helped := FALSE; gotCmd := FALSE; done := FALSE;
  code := 0; nPos := 0;
  n := Args.Count();
  i := 1;
  WHILE ~done & (i <= n) DO
    Args.Get(i, a);
    IF (a = '-h') OR (a = '--help') THEN
      Usage; helped := TRUE; INC(i)
    ELSIF a = '--exact' THEN
      exactFlag := TRUE; INC(i)
    ELSIF a = '--no-ext-warn' THEN
      noExtWarn := TRUE; INC(i)
    ELSIF a = '--no-assert' THEN
      noAssert := TRUE; INC(i)
    ELSIF a = '-o' THEN
      INC(i);
      IF i <= n THEN Args.Get(i, opt); M.SetOutDir(opt); INC(i) END
    ELSIF (a = '-f') OR (a = '--force') THEN
      forceFlag := TRUE; INC(i)
    ELSIF a = '--build-lib' THEN
      buildLibFlag := TRUE; INC(i)
    ELSIF a = '--verbose' THEN
      verboseFlag := TRUE; INC(i)
    ELSIF a = '--build-dir' THEN
      INC(i);
      IF i <= n THEN Args.Get(i, opt); M.SetBuildDir(opt); INC(i) END
    ELSIF a = '-c' THEN
      noLink := TRUE; INC(i)
    ELSIF a = '-l' THEN
      code := LinkOnly(i); done := TRUE
    ELSIF a = '--cmd' THEN
      INC(i);
      IF i <= n THEN
        Args.Get(i, opt);
        IF ~ParseCmdSpec(opt) THEN M.WriteError(E.badCmdSpec); code := 1 END;
        gotCmd := TRUE; INC(i)
      END
    ELSE
      IF nPos < 4 THEN Strings.Copy(a, positional[nPos]); INC(nPos) END;
      INC(i)
    END
  END;

  IF ~done & ~helped & (code = 0) THEN
    gotRoot := FALSE;
    IF nPos = 1 THEN
      IF LooksLikeQualified(positional[0]) & ~exactFlag & ~FileExists(positional[0]) THEN
        IF ~ParseCmdSpec(positional[0]) THEN
          M.WriteError(E.badCmdSpec); code := 1
        ELSE
          (* cmdMod here may include directory components — keep them in
             rootArg for source resolution; strip them for the linker. *)
          Strings.Copy(cmdMod, rootArg);
          SplitPath(cmdMod, opt, a);
          Strings.Copy(a, cmdMod);
          gotRoot := TRUE; gotCmd := TRUE
        END
      ELSE
        Strings.Copy(positional[0], rootArg); gotRoot := TRUE
      END
    ELSIF nPos = 2 THEN
      Strings.Copy(positional[0], rootArg); gotRoot := TRUE;
      IF ~gotCmd THEN
        IF ~ParseCmdSpec(positional[1]) THEN M.WriteError(E.badCmdSpec); code := 1
        ELSE gotCmd := TRUE
        END
      END
    ELSIF nPos = 0 THEN
      IF ~buildLibFlag THEN Usage; helped := TRUE END
    ELSE
      Usage; code := 1
    END;

    IF ~helped & (code = 0) THEN
      IF buildLibFlag THEN code := BuildLibCache()
      ELSIF gotRoot THEN code := BuildAndLink(noLink)
      END
    END
  END;
  IF code # 0 THEN Platform.ExitOS(code) END
END Main;

BEGIN
  nStdlibMods := 0;
  Strings.Copy('Utf8',     stdlibMods[nStdlibMods]); INC(nStdlibMods);
  Strings.Copy('Platform', stdlibMods[nStdlibMods]); INC(nStdlibMods);
  Strings.Copy('Heap',     stdlibMods[nStdlibMods]); INC(nStdlibMods);
  Strings.Copy('Kernel',   stdlibMods[nStdlibMods]); INC(nStdlibMods);
  Strings.Copy('Out',      stdlibMods[nStdlibMods]); INC(nStdlibMods);
  Strings.Copy('In',       stdlibMods[nStdlibMods]); INC(nStdlibMods);
  Strings.Copy('Strings',  stdlibMods[nStdlibMods]); INC(nStdlibMods);
  Strings.Copy('Files',    stdlibMods[nStdlibMods]); INC(nStdlibMods);
  InitHomeRoots;
  Main
END InterOberon.
