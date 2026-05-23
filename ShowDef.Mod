MODULE ShowDef;
IMPORT ST := SymTable, Lang, Out, Files, Strings, Args, Env, Platform,
  M := Machine;

CONST
  maxPath = 256;
  maxName = 64;
  maxLangCode = 6;
  maxHomeRoots = 8;
  maxPrinted = 256;
  maxTransLangs = 16;
  maxMods = 64;
  maxLine = 512;

TYPE
  LangBuf = ST.LangBuf;

VAR
  homeRoots: ARRAY maxHomeRoots, maxPath OF CHAR;
  nHomeRoots: INTEGER;
  symDir: ARRAY maxPath OF CHAR;
  modArgs: ARRAY maxMods, maxPath OF CHAR;
  nMods: INTEGER;

  primaryLang: ARRAY maxLangCode OF CHAR;
  transLangs: ARRAY maxTransLangs, maxLangCode OF CHAR;
  nTransLangs: INTEGER;
  allTrans: BOOLEAN;
  listLangsOnly: BOOLEAN;

  symCodes: LangBuf;
  symNLangs: INTEGER;
  modNames: ST.Name;
  exports: ST.Object;

  printedRec: ARRAY maxPrinted OF ST.Type;
  printedN: INTEGER;

  kwDef, kwType, kwVar, kwConst, kwEnd: ARRAY 32 OF CHAR;
  kwRecord, kwPointer, kwTo, kwArray, kwOf, kwProcedure: ARRAY 32 OF CHAR;

PROCEDURE AddHomeRoot(root: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  IF nHomeRoots < maxHomeRoots THEN
    Strings.Copy(root, homeRoots[nHomeRoots]);
    i := 0;
    WHILE homeRoots[nHomeRoots, i] # 0X DO INC(i) END;
    IF (i > 0) & (homeRoots[nHomeRoots, i - 1] # '/') THEN
      homeRoots[nHomeRoots, i] := '/';
      homeRoots[nHomeRoots, i + 1] := 0X
    END;
    INC(nHomeRoots)
  END
END AddHomeRoot;

PROCEDURE InitHomeRoots;
VAR envPath, appDir, root: ARRAY maxPath OF CHAR;
  i, j: INTEGER;
BEGIN
  nHomeRoots := 0;
  Env.GetByName('INTEROBERON_HOME', envPath);
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
  AddHomeRoot('');
  Env.GetAppDir(appDir);
  IF appDir[0] # 0X THEN AddHomeRoot(appDir) END;
  Lang.ResetSearchRoots;
  i := 0;
  WHILE i < nHomeRoots DO
    Strings.Copy(homeRoots[i], root);
    Strings.Append('Langs/', root);
    Lang.AddSearchRoot(root);
    INC(i)
  END
END InitHomeRoots;

PROCEDURE FileExists(path: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Files.Old(path) # NIL END FileExists;

PROCEDURE AppendSymName(dir, plain: ARRAY OF CHAR; VAR path: ARRAY OF CHAR);
BEGIN
  Strings.Copy(dir, path);
  Strings.Append(plain, path);
  Strings.Append('.sym', path)
END AppendSymName;

PROCEDURE LangCodeEq(i: INTEGER; code: ARRAY OF CHAR): BOOLEAN;
VAR j: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  j := 0;
  WHILE ok & (code[j] # 0X) DO
    IF symCodes[i, j] # code[j] THEN ok := FALSE END;
    INC(j)
  END;
  IF ok & (symCodes[i, j] # 0X) THEN ok := FALSE END;
  RETURN ok
END LangCodeEq;

PROCEDURE LangInSym(code: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  i := 0;
  WHILE (i < symNLangs) & ~ok DO
    IF LangCodeEq(i, code) THEN ok := TRUE END;
    INC(i)
  END;
  RETURN ok
END LangInSym;

PROCEDURE TrySymAt(path: ARRAY OF CHAR; VAR found: ARRAY OF CHAR): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  IF FileExists(path) THEN
    Strings.Copy(path, found);
    ok := TRUE
  ELSE ok := FALSE
  END;
  RETURN ok
END TrySymAt;

PROCEDURE MatchModSym(path: ARRAY OF CHAR; modname: ARRAY OF CHAR): BOOLEAN;
VAR n: ST.Name;
  ok: BOOLEAN;
BEGIN
  ok := ST.PeekSymModuleNames(path, n) & ST.NameMatches(n, modname);
  RETURN ok
END MatchModSym;

PROCEDURE FindSymFile(modname: ARRAY OF CHAR; VAR found: ARRAY OF CHAR): BOOLEAN;
VAR path, plain, dir: ARRAY maxPath OF CHAR;
  i: INTEGER;
  ok, slash: BOOLEAN;
BEGIN
  ok := FALSE;
  slash := FALSE;
  i := 0;
  WHILE modname[i] # 0X DO
    IF modname[i] = '/' THEN slash := TRUE END;
    INC(i)
  END;
  IF slash THEN
    Strings.Copy(modname, path);
    IF TrySymAt(path, found) THEN ok := TRUE
    ELSE
      Strings.Append('.sym', path);
      ok := TrySymAt(path, found)
    END
  ELSE
    Strings.Copy(modname, plain);
    AppendSymName('', plain, path);
    IF TrySymAt(path, found) THEN ok := TRUE END;
    IF ~ok THEN
      AppendSymName('_Build/', plain, path);
      ok := TrySymAt(path, found)
    END;
    IF ~ok & (symDir[0] # 0X) THEN
      AppendSymName(symDir, plain, path);
      ok := TrySymAt(path, found)
    END;
    i := 0;
    WHILE ~ok & (i < nHomeRoots) DO
      AppendSymName(homeRoots[i], plain, path);
      IF TrySymAt(path, found) THEN ok := TRUE END;
      IF ~ok THEN
        Strings.Copy(homeRoots[i], dir);
        Strings.Append('_Build/', dir);
        AppendSymName(dir, plain, path);
        ok := TrySymAt(path, found)
      END;
      IF ~ok THEN
        Strings.Copy(homeRoots[i], dir);
        Strings.Append('bin/', dir);
        AppendSymName(dir, plain, path);
        ok := TrySymAt(path, found)
      END;
      INC(i)
    END;
    i := 0;
    WHILE ~ok & (i < nHomeRoots) DO
      Strings.Copy(homeRoots[i], dir);
      Strings.Append('_Build/', dir);
      AppendSymName(dir, plain, path);
      IF TrySymAt(path, found) & MatchModSym(path, modname) THEN
        Strings.Copy(path, found);
        ok := TRUE
      END;
      IF ~ok THEN
        Strings.Copy(homeRoots[i], dir);
        AppendSymName(dir, plain, path);
        IF TrySymAt(path, found) & MatchModSym(path, modname) THEN
          Strings.Copy(path, found);
          ok := TRUE
        END
      END;
      INC(i)
    END
  END;
  RETURN ok
END FindSymFile;

PROCEDURE LoadKw;
BEGIN
  Lang.FindKeywordKey('DEFINITION', kwDef);
  IF kwDef = '' THEN kwDef := 'DEFINITION' END;
  Lang.FindKeywordKey('TYPE', kwType);
  IF kwType = '' THEN kwType := 'TYPE' END;
  Lang.FindKeywordKey('VAR', kwVar);
  IF kwVar = '' THEN kwVar := 'VAR' END;
  Lang.FindKeywordKey('CONST', kwConst);
  IF kwConst = '' THEN kwConst := 'CONST' END;
  Lang.FindKeywordKey('END', kwEnd);
  IF kwEnd = '' THEN kwEnd := 'END' END;
  Lang.FindKeywordKey('RECORD', kwRecord);
  IF kwRecord = '' THEN kwRecord := 'RECORD' END;
  Lang.FindKeywordKey('POINTER', kwPointer);
  IF kwPointer = '' THEN kwPointer := 'POINTER' END;
  Lang.FindKeywordKey('TO', kwTo);
  IF kwTo = '' THEN kwTo := 'TO' END;
  Lang.FindKeywordKey('ARRAY', kwArray);
  IF kwArray = '' THEN kwArray := 'ARRAY' END;
  Lang.FindKeywordKey('OF', kwOf);
  IF kwOf = '' THEN kwOf := 'OF' END;
  Lang.FindKeywordKey('PROCEDURE', kwProcedure);
  IF kwProcedure = '' THEN kwProcedure := 'PROCEDURE' END
END LoadKw;

PROCEDURE ObjName(names: ST.Name; VAR s: ARRAY OF CHAR);
BEGIN
  ST.GetNameLang(names, primaryLang, s);
  IF s = '' THEN ST.GetName(names, s) END
END ObjName;

PROCEDURE UniName(en: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
BEGIN
  Lang.FindUniObj(en, s);
  IF s = '' THEN Strings.Copy(en, s) END
END UniName;

PROCEDURE AppendInt(n: INTEGER; VAR buf: ARRAY OF CHAR);
VAR d, part: ARRAY 16 OF CHAR;
  i, j, k: INTEGER;
  neg: BOOLEAN;
BEGIN
  IF n < 0 THEN neg := TRUE; n := -n ELSE neg := FALSE END;
  i := 0;
  IF n = 0 THEN d[0] := '0'; i := 1
  ELSE
    WHILE n # 0 DO
      d[i] := CHR(n MOD 10 + ORD('0'));
      n := n DIV 10;
      INC(i)
    END
  END;
  IF neg THEN Strings.Append('-', buf) END;
  j := 0;
  WHILE j < i DO
    k := i - 1 - j;
    part[0] := d[k]; part[1] := 0X;
    Strings.Append(part, buf);
    INC(j)
  END
END AppendInt;

PROCEDURE RecordPrinted(T: ST.Type): BOOLEAN;
VAR i: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  i := 0;
  WHILE (i < printedN) & ~ok DO
    IF printedRec[i] = T THEN ok := TRUE END;
    INC(i)
  END;
  RETURN ok
END RecordPrinted;

PROCEDURE MarkRecordPrinted(T: ST.Type);
BEGIN
  IF (T # NIL) & (printedN < maxPrinted) THEN
    printedRec[printedN] := T;
    INC(printedN)
  END
END MarkRecordPrinted;

PROCEDURE HasExportedTyp(T: ST.Type): BOOLEAN;
VAR p: ST.Object;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  p := exports;
  WHILE (p # NIL) & ~ok DO
    IF (p.class = ST.Typ) & (p.type = T) THEN ok := TRUE END;
    p := p.next
  END;
  RETURN ok
END HasExportedTyp;

PROCEDURE FormatIdent(names: ST.Name; exported: BOOLEAN; VAR buf: ARRAY OF CHAR);
VAR s: ARRAY maxName OF CHAR;
  i, j: INTEGER;
BEGIN
  ObjName(names, s);
  i := 0;
  IF ~exported THEN buf[i] := '#'; INC(i) END;
  j := 0;
  WHILE (s[j] # 0X) & (i < LEN(buf) - 1) DO buf[i] := s[j]; INC(i); INC(j) END;
  buf[i] := 0X
END FormatIdent;

PROCEDURE FormatType(T: ST.Type; briefRec: BOOLEAN; VAR buf: ARRAY OF CHAR);
VAR part, id: ARRAY maxLine OF CHAR;
  base: ST.Type;
  p: ST.Object;
  first: BOOLEAN;
BEGIN
  buf[0] := 0X;
  IF T = NIL THEN UniName('NIL', buf)
  ELSIF (T.form = ST.Bool) OR (T.form = ST.Char) OR (T.form = ST.Int) OR (T.form = ST.Set)
      OR (T.form = ST.Byte) OR (T.form = ST.Real) OR (T.form = ST.LongReal)
      OR (T.form = ST.TinyInt) OR (T.form = ST.ShortInt) OR (T.form = ST.LongInt)
      OR (T.form = ST.TinySet) OR (T.form = ST.ShortSet) OR (T.form = ST.LongSet) THEN
    IF    T.form = ST.Bool     THEN UniName('BOOLEAN', buf)
    ELSIF T.form = ST.Char     THEN UniName('CHAR', buf)
    ELSIF T.form = ST.Int      THEN UniName('INTEGER', buf)
    ELSIF T.form = ST.Set      THEN UniName('SET', buf)
    ELSIF T.form = ST.Byte     THEN UniName('BYTE', buf)
    ELSIF T.form = ST.Real     THEN UniName('REAL', buf)
    ELSIF T.form = ST.LongReal THEN UniName('LONGREAL', buf)
    ELSIF T.form = ST.TinyInt  THEN UniName('TINYINT', buf)
    ELSIF T.form = ST.ShortInt THEN UniName('SHORTINT', buf)
    ELSIF T.form = ST.LongInt  THEN UniName('LONGINT', buf)
    ELSIF T.form = ST.TinySet  THEN UniName('TINYSET', buf)
    ELSIF T.form = ST.ShortSet THEN UniName('SHORTSET', buf)
    ELSIF T.form = ST.LongSet  THEN UniName('LONGSET', buf)
    END
  ELSIF T.form = ST.Array THEN
    Strings.Copy(kwArray, buf);
    IF (T.openRank > 0) OR (T.len = 0) THEN
      Strings.Append(' ', buf);
      Strings.Append(kwOf, buf)
    ELSE
      Strings.Append(' ', buf);
      AppendInt(T.len, buf);
      Strings.Append(' ', buf);
      Strings.Append(kwOf, buf)
    END;
    FormatType(T.base, TRUE, part);
    Strings.Append(' ', buf);
    Strings.Append(part, buf)
  ELSIF T.form = ST.Pointer THEN
    Strings.Copy(kwPointer, buf);
    Strings.Append(' ', buf);
    Strings.Append(kwTo, buf);
    Strings.Append(' ', buf);
    base := T.base;
    IF (base # NIL) & (base.form = ST.Record) & briefRec
        & ~ST.DeclNamesEmpty(base.declNames) THEN
      FormatIdent(base.declNames, base.declExported, part);
      Strings.Append(part, buf)
    ELSIF base # NIL THEN
      FormatType(base, TRUE, part);
      Strings.Append(part, buf)
    END
  ELSIF T.form = ST.Record THEN
    IF briefRec & ~ST.DeclNamesEmpty(T.declNames) THEN
      FormatIdent(T.declNames, T.declExported, buf)
    ELSE
      Strings.Copy(kwRecord, buf);
      IF (T.base # NIL) & (T.base.form = ST.Record) THEN
        Strings.Append(' (', buf);
        FormatType(T.base, TRUE, part);
        Strings.Append(part, buf);
        Strings.Append(')', buf)
      END;
      IF T.dsc # NIL THEN
        Strings.Append(' ', buf);
        p := T.dsc;
        first := TRUE;
        WHILE (p # NIL) & (p.class = ST.Fld) DO
          IF ~first THEN Strings.Append(', ', buf) ELSE first := FALSE END;
          FormatIdent(p.names, p.exported, id);
          Strings.Append(id, buf);
          FormatType(p.type, TRUE, part);
          Strings.Append(': ', buf);
          Strings.Append(part, buf);
          p := p.next
        END
      END;
      Strings.Append(' ', buf);
      Strings.Append(kwEnd, buf)
    END
  ELSIF T.form = ST.Proc THEN
    IF ~briefRec THEN Strings.Copy(kwProcedure, buf) END;
    IF T.nofpars # 0 THEN
      Strings.Append(' (', buf);
      p := T.dsc;
      first := TRUE;
      WHILE p # NIL DO
        IF ~first THEN Strings.Append('; ', buf) ELSE first := FALSE END;
        IF p.class = ST.VarPar THEN
          Strings.Append(kwVar, buf);
          Strings.Append(' ', buf)
        END;
        FormatIdent(p.names, TRUE, id);
        Strings.Append(id, buf);
        FormatType(p.type, TRUE, part);
        Strings.Append(': ', buf);
        Strings.Append(part, buf);
        p := p.next
      END;
      Strings.Append(')', buf)
    END;
    IF (T.base # NIL) & (T.base.form # ST.NoTyp) THEN
      Strings.Append(': ', buf);
      FormatType(T.base, TRUE, part);
      Strings.Append(part, buf)
    END
  END
END FormatType;

PROCEDURE PrintHiddenRecord(T: ST.Type);
VAR id, ty: ARRAY maxLine OF CHAR;
BEGIN
  IF (T # NIL) & (T.form = ST.Record) & ~ST.DeclNamesEmpty(T.declNames)
      & ~HasExportedTyp(T) & ~RecordPrinted(T) THEN
    MarkRecordPrinted(T);
    Out.String('    ');
    FormatIdent(T.declNames, T.declExported, id);
    Out.String(id);
    Out.String(' = ');
    FormatType(T, FALSE, ty);
    Out.String(ty);
    Out.String(';');
    Out.Ln
  END
END PrintHiddenRecord;

PROCEDURE WalkHidden(T: ST.Type);
VAR p: ST.Object;
  base: ST.Type;
  i: INTEGER;
BEGIN
  IF T = NIL THEN
  ELSIF T.form = ST.Pointer THEN WalkHidden(T.base)
  ELSIF T.form = ST.Record THEN
    PrintHiddenRecord(T);
    p := T.dsc;
    WHILE (p # NIL) & (p.class = ST.Fld) DO WalkHidden(p.type); p := p.next END;
    base := T.base;
    IF (base # NIL) & (base.form = ST.Record) THEN WalkHidden(base) END
  ELSIF T.form = ST.Array THEN WalkHidden(T.base)
  ELSIF T.form = ST.Proc THEN
    p := T.dsc;
    WHILE p # NIL DO WalkHidden(p.type); p := p.next END;
    WalkHidden(T.base)
  END
END WalkHidden;

PROCEDURE EmitHiddenFrom(T: ST.Type);
BEGIN WalkHidden(T) END EmitHiddenFrom;

PROCEDURE TransSlot(names: ST.Name; lang: ARRAY OF CHAR; prev: ARRAY OF CHAR;
    VAR slot: ARRAY OF CHAR);
VAR cur, canon: ARRAY maxName OF CHAR;
BEGIN
  ST.GetNameLang(names, lang, cur);
  IF cur = '' THEN ST.GetName(names, canon); cur := canon END;
  IF (cur = prev) OR (cur = canon) & (prev # '') THEN slot := ''
  ELSE Strings.Copy(cur, slot)
  END
END TransSlot;

PROCEDURE UpperLang(code: ARRAY OF CHAR; VAR out: ARRAY OF CHAR);
VAR i: INTEGER;
  ch: CHAR;
BEGIN
  i := 0;
  WHILE (code[i] # 0X) & (i < LEN(out) - 1) DO
    ch := code[i];
    IF ('a' <= ch) & (ch <= 'z') THEN ch := CHR(ORD(ch) - 32) END;
    out[i] := ch;
    INC(i)
  END;
  out[i] := 0X
END UpperLang;

PROCEDURE SingleTransComment(names: ST.Name);
VAR slot, prev, ucode: ARRAY maxName OF CHAR;
  j: INTEGER;
BEGIN
  IF nTransLangs # 0 THEN
    Out.String(' (');
    Out.String('**');
    j := 0;
    WHILE j < nTransLangs DO
      Out.Char('%');
      UpperLang(transLangs[j], ucode);
      Out.String(ucode);
      Out.Char(':');
      prev := '';
      TransSlot(names, transLangs[j], prev, slot);
      IF slot = '' THEN Out.Char(',') ELSE Out.String(slot) END;
      INC(j)
    END;
    Out.String('*)')
  END
END SingleTransComment;

PROCEDURE PrintTypeDecl(p: ST.Object);
VAR id, ty: ARRAY maxLine OF CHAR;
BEGIN
  Out.String('    ');
  ObjName(p.names, id);
  Out.String(id);
  Out.String(' = ');
  FormatType(p.type, TRUE, ty);
  Out.String(ty);
  Out.String(';');
  IF nTransLangs # 0 THEN SingleTransComment(p.names) END;
  Out.Ln;
  EmitHiddenFrom(p.type)
END PrintTypeDecl;

PROCEDURE PrintVarDecl(p: ST.Object);
VAR id, ty: ARRAY maxLine OF CHAR;
BEGIN
  Out.String('    ');
  ObjName(p.names, id);
  Out.String(id);
  Out.String(': ');
  FormatType(p.type, TRUE, ty);
  Out.String(ty);
  Out.String(';');
  IF nTransLangs # 0 THEN SingleTransComment(p.names) END;
  Out.Ln
END PrintVarDecl;

PROCEDURE PrintConstDecl(p: ST.Object);
VAR id, ty: ARRAY maxLine OF CHAR;
BEGIN
  IF (p.type = NIL) OR (p.type.form = ST.Proc) THEN
  ELSE
    Out.String('    ');
    ObjName(p.names, id);
    Out.String(id);
    Out.String(' = ');
    IF p.type.form = ST.String THEN
      Out.String('""')
    ELSE
      Out.Int(M.SHORT(p.intVal), 0)
    END;
    Out.String(';');
    IF nTransLangs # 0 THEN SingleTransComment(p.names) END;
    Out.Ln
  END
END PrintConstDecl;

PROCEDURE PrintProcDecl(p: ST.Object);
VAR id, sig: ARRAY maxLine OF CHAR;
BEGIN
  Out.String('  ');
  Out.String(kwProcedure);
  Out.String(' ');
  ObjName(p.names, id);
  Out.String(id);
  FormatType(p.type, TRUE, sig);
  Out.String(sig);
  Out.String(';');
  IF nTransLangs # 0 THEN SingleTransComment(p.names) END;
  Out.Ln;
  IF p.type # NIL THEN EmitHiddenFrom(p.type) END
END PrintProcDecl;

PROCEDURE PrintTypeSection;
VAR p: ST.Object;
  any: BOOLEAN;
BEGIN
  any := FALSE;
  p := exports;
  WHILE p # NIL DO
    IF p.class = ST.Typ THEN any := TRUE END;
    p := p.next
  END;
  IF any THEN
    Out.Ln; Out.String('  '); Out.String(kwType); Out.Ln;
    p := exports;
    WHILE p # NIL DO
      IF p.class = ST.Typ THEN PrintTypeDecl(p) END;
      p := p.next
    END
  END
END PrintTypeSection;

PROCEDURE PrintConstSection;
VAR p: ST.Object;
  any: BOOLEAN;
BEGIN
  any := FALSE;
  p := exports;
  WHILE p # NIL DO
    IF (p.class = ST.Const) & ((p.type = NIL) OR (p.type.form # ST.Proc)) THEN any := TRUE END;
    p := p.next
  END;
  IF any THEN
    Out.Ln; Out.String('  '); Out.String(kwConst); Out.Ln;
    p := exports;
    WHILE p # NIL DO
      IF (p.class = ST.Const) & ((p.type = NIL) OR (p.type.form # ST.Proc)) THEN
        PrintConstDecl(p)
      END;
      p := p.next
    END
  END
END PrintConstSection;

PROCEDURE PrintVarSection;
VAR p: ST.Object;
  any: BOOLEAN;
BEGIN
  any := FALSE;
  p := exports;
  WHILE p # NIL DO
    IF p.class = ST.Var THEN any := TRUE END;
    p := p.next
  END;
  IF any THEN
    Out.Ln; Out.String('  '); Out.String(kwVar); Out.Ln;
    p := exports;
    WHILE p # NIL DO
      IF p.class = ST.Var THEN PrintVarDecl(p) END;
      p := p.next
    END
  END
END PrintVarSection;

PROCEDURE PrintProcedures;
VAR p: ST.Object;
  first: BOOLEAN;
BEGIN
  first := TRUE;
  p := exports;
  WHILE p # NIL DO
    IF (p.class = ST.Const) & (p.type # NIL) & (p.type.form = ST.Proc) THEN
      IF first THEN Out.Ln; first := FALSE END;
      PrintProcDecl(p)
    END;
    p := p.next
  END
END PrintProcedures;

PROCEDURE PrintDefinition;
VAR modName: ARRAY maxName OF CHAR;
BEGIN
  printedN := 0;
  ObjName(modNames, modName);
  Out.String(kwDef);
  Out.String(' ');
  Out.String(modName);
  Out.String('; (* Inter Oberon *)');
  Out.Ln;
  PrintTypeSection;
  PrintConstSection;
  PrintVarSection;
  PrintProcedures;
  Out.Ln;
  Out.String(kwEnd);
  Out.String(' ');
  Out.String(modName);
  Out.String('.');
  Out.Ln
END PrintDefinition;

PROCEDURE SetupTransLangs;
VAR i: INTEGER;
BEGIN
  nTransLangs := 0;
  IF allTrans THEN
    i := 0;
    WHILE i < symNLangs DO
      IF nTransLangs < maxTransLangs THEN
        Strings.Copy(symCodes[i], transLangs[nTransLangs]);
        INC(nTransLangs)
      END;
      INC(i)
    END
  END
END SetupTransLangs;

PROCEDURE ParseLangList(s: ARRAY OF CHAR);
VAR i, j, n: INTEGER;
  code: ARRAY maxLangCode OF CHAR;
BEGIN
  nTransLangs := 0;
  i := 0;
  WHILE s[i] # 0X DO
    WHILE (s[i] # 0X) & (s[i] <= ' ') DO INC(i) END;
    j := 0;
    WHILE (s[i] # 0X) & (s[i] # ',') & (j < LEN(code) - 1) DO
      code[j] := s[i]; INC(i); INC(j)
    END;
    code[j] := 0X;
    IF (j > 0) & (nTransLangs < maxTransLangs) THEN
      Strings.Copy(code, transLangs[nTransLangs]);
      INC(nTransLangs)
    END;
    IF s[i] = ',' THEN INC(i) END
  END;
  IF nTransLangs # 0 THEN Strings.Copy(transLangs[0], primaryLang) END
END ParseLangList;

PROCEDURE Usage;
VAR s: ARRAY 256 OF CHAR;
BEGIN
  Args.Get(0, s);
  Out.String('Usage: '); Out.String(s); Out.String(' [options] module ...'); Out.Ln;
  Out.Ln;
  Out.String('  module ...          One or more module names or paths to .sym'); Out.Ln;
  Out.String('  -d, --dir <path>    Extra directory to search for .sym'); Out.Ln;
  Out.String('  -l, --lang <code>   Output language (default: first in .sym)'); Out.Ln;
  Out.String('  -L, --langs         List languages from .sym and exit'); Out.Ln;
  Out.String('  -a, --all           Translation comments for all sym languages'); Out.Ln;
  Out.String('  -t, --translate <codes>  Comments for listed langs; first = output'); Out.Ln;
  Out.String('  -h, --help          This help'); Out.Ln
END Usage;

PROCEDURE RunModule(modArg: ARRAY OF CHAR): INTEGER;
VAR symPath: ARRAY maxPath OF CHAR;
  i: INTEGER;
  ok: BOOLEAN;
  code: INTEGER;
BEGIN
  code := 0;
  ok := FindSymFile(modArg, symPath);
  IF ~ok THEN
    Out.String('showdef: sym file not found: ');
    Out.String(modArg);
    Out.Ln;
    code := 1
  ELSIF listLangsOnly THEN
    IF ST.PeekSymLangs(symPath, symCodes, symNLangs) THEN
      i := 0;
      WHILE i < symNLangs DO
        Out.String(symCodes[i]); Out.Ln;
        INC(i)
      END
    ELSE code := 1 END
  ELSE
    ok := ST.LoadSymFile(symPath, modNames, exports, symCodes, symNLangs);
    IF ~ok THEN code := 1
    ELSE
      IF primaryLang[0] = 0X THEN Strings.Copy(symCodes[0], primaryLang) END;
      IF (nTransLangs > 0) & ~LangInSym(transLangs[0]) THEN
        Out.String('showdef: language not in sym file: ');
        Out.String(transLangs[0]);
        Out.Ln;
        code := 1
      ELSIF ~LangInSym(primaryLang) THEN
        Out.String('showdef: language not in sym file: ');
        Out.String(primaryLang);
        Out.Ln;
        code := 1
      ELSIF ~Lang.Load(primaryLang) THEN
        Out.String('showdef: language file not found: ');
        Out.String(primaryLang);
        Out.Ln;
        code := 1
      ELSE
        LoadKw;
        IF allTrans THEN SetupTransLangs END;
        PrintDefinition
      END
    END
  END;
  RETURN code
END RunModule;

PROCEDURE Main;
VAR a, opt: ARRAY maxPath OF CHAR;
  i, n, code, c: INTEGER;
  done: BOOLEAN;
BEGIN
  code := 0;
  symDir[0] := 0X;
  primaryLang[0] := 0X;
  allTrans := FALSE;
  listLangsOnly := FALSE;
  nTransLangs := 0;
  nMods := 0;
  InitHomeRoots;
  n := Args.Count();
  i := 1;
  done := FALSE;
  WHILE ~done & (i <= n) DO
    Args.Get(i, a);
    IF (a = '-h') OR (a = '--help') THEN Usage; code := 0; done := TRUE
    ELSIF (a = '--lang') OR (a = '-l') THEN
      INC(i);
      IF i <= n THEN Args.Get(i, primaryLang); INC(i) END
    ELSIF (a = '--langs') OR (a = '-L') THEN listLangsOnly := TRUE; INC(i)
    ELSIF (a = '--all') OR (a = '-a') THEN allTrans := TRUE; INC(i)
    ELSIF (a = '--translate') OR (a = '-t') THEN
      INC(i);
      IF i <= n THEN Args.Get(i, opt); ParseLangList(opt); INC(i) END
    ELSIF (a = '--dir') OR (a = '-d') THEN
      INC(i);
      IF i <= n THEN Args.Get(i, symDir); INC(i) END
    ELSIF nMods < maxMods THEN
      Strings.Copy(a, modArgs[nMods]);
      INC(nMods);
      INC(i)
    ELSE
      Out.String('showdef: too many modules'); Out.Ln;
      code := 1;
      done := TRUE
    END
  END;
  IF ~done & (nMods = 0) THEN Usage; code := 1; done := TRUE END;
  IF ~done THEN
    i := 0;
    WHILE i < nMods DO
      c := RunModule(modArgs[i]);
      IF c # 0 THEN code := 1 END;
      IF (i < nMods - 1) & (c = 0) THEN Out.Ln END;
      INC(i)
    END
  END;
  IF code # 0 THEN Platform.ExitOS(code) END
END Main;

BEGIN
  Main
END ShowDef.
