MODULE Linker;
IMPORT Files, Strings, E := ErrorMsg, M := Machine, Utf8, SYSTEM;

CONST
  version = 1;
  objFileMark = ORD('A') + 256 * (ORD('R') + 256 * (ORD('M') + 256 * version));
  objHeaderSize = 40;
  maxStrPool = 1024;
  maxReloc = 4096;
  maxModules* = 64;
  maxImports = 32;
  maxExports = 256;
  maxName = 64;
  maxCodeBytes = 256000;
  maxCstring = 65536;
  exitInsnBytes = 12;

TYPE
  LONGINT = M.LONGINT;

  (** All instruction-level offsets (initOff, exportOff, *RelocOff)
      are in 32-bit words from the start of the module's code; the
      linker multiplies by 4 at the patch site to index codeBuf and
      compute Mach-O VAs. Layout fields (codeBase, codeLen, dataBase)
      stay in bytes. *)
  ModuleSlot* = POINTER TO ModuleSlotDesc;
  ModuleSlotDesc* = RECORD
    name*: ARRAY maxName OF CHAR;
    initOff*: INTEGER; (** word offset of init proc within this module's code *)
    varSize*: INTEGER;

    nImports*: INTEGER;
    importNames*: ARRAY maxImports, maxName OF CHAR;
    importIdx*: ARRAY maxImports OF INTEGER; (** index into modules array, -1 if absent *)

    nExports*: INTEGER;
    exportNames*: ARRAY maxExports, maxName OF CHAR;
    exportOff*: ARRAY maxExports OF INTEGER; (** in words *)
    exportIsCmd*: ARRAY maxExports OF BOOLEAN;

    codeLen*: INTEGER;  (** bytes *)
    codeBase*: INTEGER; (** byte offset within merged code *)
    dataBase*: INTEGER; (** byte offset within __DATA *)
    strBase*: INTEGER;  (** index of first local string in global pool *)

    nStrPool*: INTEGER;

    nStrReloc*: INTEGER;
    strRelocOff*: ARRAY maxReloc OF INTEGER; (** in words *)
    strRelocIdx*: ARRAY maxReloc OF INTEGER; (** local string index *)

    nDataPageReloc*: INTEGER;
    dataPageRelocOff*: ARRAY maxReloc OF INTEGER; (** in words *)

    nImpDataPageReloc*: INTEGER;
    impDataPageRelocOff*: ARRAY maxReloc OF INTEGER; (** in words *)
    impDataPageRelocImp*: ARRAY maxReloc OF INTEGER;

    (** Cross-module BL relocs (CallExt). *)
    nExtCallReloc*: INTEGER;
    extCallRelocOff*: ARRAY maxReloc OF INTEGER; (** in words *)
    extCallRelocImp*: ARRAY maxReloc OF INTEGER;
    extCallRelocName*: ARRAY maxReloc, maxName OF CHAR
  END;

VAR
  modules: ARRAY maxModules OF ModuleSlot;
  modObjPath: ARRAY maxModules, 256 OF CHAR;
  importBind: ARRAY maxModules, maxImports OF INTEGER;
  nModules: INTEGER;
  cmdModIdx: INTEGER; (** -1 if no command *)
  cmdExportIdx: INTEGER; (** index into modules[cmdModIdx].exportNames *)
  bootstrapLen: INTEGER;

  exeFile: Files.File;
  exeRider: Files.Rider;

  codeBuf: ARRAY maxCodeBytes OF CHAR; (** merged code *)
  codeLen: INTEGER;
  cstringBlob: ARRAY maxCstring OF BYTE;
  cstringRawLen: INTEGER;
  cstringAlignedLen: INTEGER;
  strOff: ARRAY maxStrPool OF INTEGER; (** global string -> byte offset in cstringBlob *)
  globStrCount: INTEGER;

  textSize: INTEGER;
  totalDataPages: INTEGER; (** number of 4KB pages for __DATA segment *)

PROCEDURE Byte(x: BYTE);
BEGIN Files.Write(exeRider, x)
END Byte;

PROCEDURE Word(x: INTEGER);
BEGIN
  Byte(x MOD 100H);
  Byte(x DIV 100H MOD 100H)
END Word;

PROCEDURE DWord(x: INTEGER);
BEGIN
  Byte(x MOD 100H);
  Byte(x DIV 100H MOD 100H);
  Byte(x DIV 10000H MOD 100H);
  Byte(x DIV 1000000H MOD 100H)
END DWord;

PROCEDURE QWord(x: LONGINT);
BEGIN
  Byte(x MOD 100H);
  Byte(x DIV 100H MOD 100H);
  Byte(x DIV 10000H MOD 100H);
  Byte(x DIV 1000000H MOD 100H);
  Byte(x DIV 1000000H DIV 100H MOD 100H);
  Byte(x DIV 1000000H DIV 10000H MOD 100H);
  Byte(x DIV 1000000H DIV 1000000H MOD 100H);
  Byte(x DIV 1000000H DIV 1000000H DIV 100H MOD 100H)
END QWord;

PROCEDURE Set(x: SET);
BEGIN DWord(ORD(x))
END Set;

PROCEDURE String(s: ARRAY OF CHAR; n: INTEGER);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO Byte(ORD(s[i])); INC(i) END;
  WHILE i < n DO Byte(0); INC(i) END
END String;

PROCEDURE Zeros(n: INTEGER);
BEGIN
  WHILE n > 0 DO Byte(0); DEC(n) END
END Zeros;

PROCEDURE GetWord(VAR buf: ARRAY OF CHAR; off: INTEGER): INTEGER;
RETURN ORD(buf[off]) + ORD(buf[off + 1]) * 100H +
       ORD(buf[off + 2]) * 10000H + ORD(buf[off + 3]) * 1000000H
END GetWord;

PROCEDURE PutWord(VAR buf: ARRAY OF CHAR; off: INTEGER; w: INTEGER);
VAR u: LONGINT;
BEGIN
  u := M.LONG(w);
  IF u < 0 THEN u := u + M.LONG(7FFFFFFFH) + M.LONG(7FFFFFFFH) + 2 END;
  buf[off] := CHR(M.SHORT(u MOD 100H));
  buf[off + 1] := CHR(M.SHORT((u DIV 100H) MOD 100H));
  buf[off + 2] := CHR(M.SHORT((u DIV 10000H) MOD 100H));
  buf[off + 3] := CHR(M.SHORT((u DIV 1000000H) MOD 100H))
END PutWord;

PROCEDURE EncodeAdrp(rd, imm: INTEGER): INTEGER;
VAR n, immlo, immhi: INTEGER;
BEGIN
  immlo := imm MOD 4;
  immhi := imm DIV 4 MOD 80000H;
  n := ((immlo * 20H + 10H) * 80000H + immhi) * 20H + rd;
  n := -7FFFFFFFH - 1 + n
RETURN n END EncodeAdrp;

PROCEDURE EncodeAddImm(rd, rn, imm: INTEGER): INTEGER;
VAR n: INTEGER;
BEGIN
  ASSERT(imm MOD 1000H = imm);
  n := ((22H * 2000H + imm) * 20H + rn) * 20H + rd;
  n := -7FFFFFFFH - 1 + n
RETURN n END EncodeAddImm;

PROCEDURE EncodeBl(imm26: INTEGER): INTEGER;
VAR n: INTEGER;
BEGIN
  n := 14000000H + (imm26 MOD 4000000H);
  n := -7FFFFFFFH - 1 + n
RETURN n END EncodeBl;

(** Read NUL-terminated UTF-8 string. *)
PROCEDURE ReadCStr(VAR R: Files.Rider; VAR s: ARRAY OF CHAR);
VAR i: INTEGER;
  b: BYTE;
  u8: ARRAY 1024 OF Utf8.SHORTCHAR;
BEGIN
  i := 0;
  Files.Read(R, b);
  WHILE (~R.eof) & (b # 0) DO
    IF i < LEN(u8) - 1 THEN
      u8[i] := Utf8.ShortChr(SYSTEM.VAL(INTEGER, b)); INC(i)
    END;
    Files.Read(R, b)
  END;
  u8[i] := 0X;
  Utf8.Decode(u8, s)
END ReadCStr;

PROCEDURE AppendUcs2StrToBlob(VAR u: ARRAY OF CHAR);
VAR t, w: INTEGER;
BEGIN
  t := 0;
  WHILE (u[t] # 0X) & (cstringRawLen + 2 <= LEN(cstringBlob)) DO
    w := ORD(u[t]);
    cstringBlob[cstringRawLen] := SYSTEM.VAL(BYTE, w MOD 100H); INC(cstringRawLen);
    cstringBlob[cstringRawLen] := SYSTEM.VAL(BYTE, w DIV 100H MOD 100H); INC(cstringRawLen);
    INC(t)
  END;
  IF cstringRawLen + 2 <= LEN(cstringBlob) THEN
    cstringBlob[cstringRawLen] := 0; INC(cstringRawLen);
    cstringBlob[cstringRawLen] := 0; INC(cstringRawLen)
  END
END AppendUcs2StrToBlob;

(** Reads one .obj file into modules[idx]. *)
PROCEDURE ReadObj(idx: INTEGER; objName: ARRAY OF CHAR): BOOLEAN;
VAR objFile: Files.File;
  R: Files.Rider;
  m: ModuleSlot;
  mark, codeBytes, strpLen, strRelocLen, dataPageRelocLen, metaLen, extCallRelocLen, impDataPageRelocLen: INTEGER;
  i, j, importN, exportN, off, ival: INTEGER;
  rb, padB, isCmd: BYTE;
  u8: ARRAY 2048 OF Utf8.SHORTCHAR;
  u16: ARRAY 1024 OF CHAR;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  objFile := Files.Old(objName);
  IF objFile # NIL THEN
    Files.Set(R, objFile, 0);
    Files.ReadInt(R, mark);
    IF mark = objFileMark THEN
      NEW(m); modules[idx] := m;
      Files.ReadInt(R, m.initOff);
      Files.ReadInt(R, codeBytes);
      Files.ReadInt(R, strpLen);
      Files.ReadInt(R, strRelocLen);
      Files.ReadInt(R, dataPageRelocLen);
      Files.ReadInt(R, metaLen);
      Files.ReadInt(R, extCallRelocLen);
      Files.ReadInt(R, impDataPageRelocLen);
      WHILE Files.Pos(R) < objHeaderSize DO Files.Read(R, padB) END;
      m.codeLen := codeBytes;

      (* Metadata: module name, varSize, imports, exports *)
      ReadCStr(R, m.name);
      Files.ReadInt(R, m.varSize);
      Files.ReadInt(R, importN); m.nImports := importN;
      i := 0;
      WHILE i < importN DO ReadCStr(R, m.importNames[i]); INC(i) END;
      Files.ReadInt(R, exportN); m.nExports := exportN;
      i := 0;
      WHILE i < exportN DO
        ReadCStr(R, m.exportNames[i]);
        Files.ReadInt(R, m.exportOff[i]);
        Files.Read(R, isCmd); m.exportIsCmd[i] := isCmd # 0;
        INC(i)
      END;

      (* Code (stored as 1 byte per byte). Will be relocated to its
         codeBase later by the linker. *)
      i := 0;
      WHILE i < codeBytes DO
        Files.Read(R, rb);
        m.codeBase := m.codeBase; (* keep alive *)
        codeBuf[i] := CHR(rb); (* temporarily into shared buf for early use *)
        INC(i)
      END;
      (* String pool: each literal is UTF-8 + NUL terminator, decoded
         to UTF-16LE in the global cstringBlob and registered with a
         per-module start index (m.strBase) computed below. *)
      Files.ReadInt(R, m.nStrPool);
      m.strBase := globStrCount;
      i := 0;
      WHILE i < m.nStrPool DO
        IF globStrCount < LEN(strOff) THEN
          strOff[globStrCount] := cstringRawLen
        END;
        j := 0;
        REPEAT
          Files.Read(R, rb);
          IF rb # 0 THEN
            IF j < LEN(u8) - 1 THEN
              u8[j] := Utf8.ShortChr(SYSTEM.VAL(INTEGER, rb)); INC(j)
            END
          END
        UNTIL rb = 0;
        u8[j] := 0X;
        Utf8.Decode(u8, u16);
        IF Utf8.Done THEN AppendUcs2StrToBlob(u16)
        ELSE
          IF cstringRawLen + 2 <= LEN(cstringBlob) THEN
            cstringBlob[cstringRawLen] := 0; INC(cstringRawLen);
            cstringBlob[cstringRawLen] := 0; INC(cstringRawLen)
          END
        END;
        INC(globStrCount);
        INC(i)
      END;

      Files.ReadInt(R, m.nStrReloc);
      i := 0;
      WHILE i < m.nStrReloc DO
        Files.ReadInt(R, m.strRelocOff[i]);
        Files.ReadInt(R, m.strRelocIdx[i]);
        INC(i)
      END;

      Files.ReadInt(R, m.nDataPageReloc);
      i := 0;
      WHILE i < m.nDataPageReloc DO
        Files.ReadInt(R, m.dataPageRelocOff[i]);
        INC(i)
      END;

      Files.ReadInt(R, m.nExtCallReloc);
      i := 0;
      WHILE i < m.nExtCallReloc DO
        Files.ReadInt(R, m.extCallRelocOff[i]);
        Files.ReadInt(R, m.extCallRelocImp[i]);
        ReadCStr(R, m.extCallRelocName[i]);
        INC(i)
      END;

      IF impDataPageRelocLen > 0 THEN
        Files.ReadInt(R, m.nImpDataPageReloc);
        i := 0;
        WHILE i < m.nImpDataPageReloc DO
          Files.ReadInt(R, m.impDataPageRelocOff[i]);
          Files.ReadInt(R, m.impDataPageRelocImp[i]);
          INC(i)
        END
      ELSE
        m.nImpDataPageReloc := 0
      END;

      ok := TRUE
    END
  END
RETURN ok END ReadObj;

(** Re-read code bytes per-module into the merged buffer at the right
    base offset.  Done in a second pass after layout. *)
PROCEDURE LoadCodeAt(objName: ARRAY OF CHAR; m: ModuleSlot): BOOLEAN;
VAR objFile: Files.File;
  R: Files.Rider;
  mark, codeBytes, strpLen, strRelocLen, dataPageRelocLen, metaLen, extCallRelocLen, impDataPageRelocLen: INTEGER;
  i: INTEGER;
  rb, padB: BYTE;
  ok: BOOLEAN;
  s: ARRAY maxName OF CHAR;
  iv, n: INTEGER;
BEGIN
  ok := FALSE;
  objFile := Files.Old(objName);
  IF objFile # NIL THEN
    Files.Set(R, objFile, 0);
      Files.ReadInt(R, mark);
      IF mark = objFileMark THEN
        Files.ReadInt(R, iv); (* initOff *)
        Files.ReadInt(R, codeBytes);
        Files.ReadInt(R, strpLen);
        Files.ReadInt(R, strRelocLen);
        Files.ReadInt(R, dataPageRelocLen);
        Files.ReadInt(R, metaLen);
        Files.ReadInt(R, extCallRelocLen);
        Files.ReadInt(R, impDataPageRelocLen);
        WHILE Files.Pos(R) < objHeaderSize DO Files.Read(R, padB) END;
      (* Skip metadata block *)
      i := 0;
      WHILE i < metaLen DO Files.Read(R, padB); INC(i) END;
      (* Read code into merged buffer at m.codeBase *)
      i := 0;
      WHILE i < codeBytes DO
        Files.Read(R, rb);
        codeBuf[m.codeBase + i] := CHR(rb);
        INC(i)
      END;
      ok := TRUE
    END
  END
RETURN ok END LoadCodeAt;

PROCEDURE FindModuleByName(name: ARRAY OF CHAR): INTEGER;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i < nModules) & (modules[i].name # name) DO INC(i) END;
  IF i = nModules THEN i := -1 END
RETURN i END FindModuleByName;

PROCEDURE FindExport(m: ModuleSlot; name: ARRAY OF CHAR): INTEGER;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i < m.nExports) & (m.exportNames[i] # name) DO INC(i) END;
  IF i = m.nExports THEN i := -1 END
RETURN i END FindExport;

(** Compute layout: bootstrap size, per-module codeBase / dataBase / strBase. *)
PROCEDURE Layout(hasCmd: BOOLEAN);
VAR i, db: INTEGER;
BEGIN
  bootstrapLen := 4 * nModules;
  IF hasCmd THEN INC(bootstrapLen, 4) END;
  INC(bootstrapLen, exitInsnBytes);
  WHILE bootstrapLen MOD 16 # 0 DO INC(bootstrapLen, 4) END; (* pad to 16B *)

  modules[0].codeBase := bootstrapLen;
  i := 1;
  WHILE i < nModules DO
    modules[i].codeBase := modules[i-1].codeBase + modules[i-1].codeLen;
    INC(i)
  END;
  IF nModules > 0 THEN
    codeLen := modules[nModules-1].codeBase + modules[nModules-1].codeLen
  ELSE codeLen := bootstrapLen
  END;

  (* Pack module globals back-to-back in __DATA; ADRP+ADD carry page+lo12. *)
  db := 0;
  i := 0;
  WHILE i < nModules DO
    modules[i].dataBase := db;
    INC(db, modules[i].varSize);
    INC(i)
  END;
  IF db > 0 THEN totalDataPages := (db + 0FFFH) DIV 1000H
  ELSE totalDataPages := 0
  END
END Layout;

(** Resolve each module's importNames against the loaded modules. *)
PROCEDURE ResolveImports;
VAR i, j, tgt: INTEGER;
BEGIN
  i := 0;
  WHILE i < nModules DO
    j := 0;
    WHILE j < modules[i].nImports DO
      tgt := importBind[i, j];
      IF tgt < 0 THEN tgt := FindModuleByName(modules[i].importNames[j]) END;
      modules[i].importIdx[j] := tgt;
      INC(j)
    END;
    INC(i)
  END
END ResolveImports;

(** Patch a single module's string ADRP+ADD pairs to point to merged cstring. *)
PROCEDURE PatchStringRelocs(m: ModuleSlot);
VAR i, off, idx, imm, rd, w, globIdx: INTEGER;
  textBase, instrVA, tgtVA: LONGINT;
BEGIN
  textBase := 1000000H;
  textBase := textBase * 100H + 2000H;
  i := 0;
  WHILE i < m.nStrReloc DO
    off := m.codeBase + m.strRelocOff[i] * 4;
    idx := m.strRelocIdx[i];
    globIdx := m.strBase + idx;
    IF (globIdx >= 0) & (globIdx < globStrCount) & (off + 8 <= codeLen) THEN
      instrVA := textBase + off;
      tgtVA := textBase + (codeLen + strOff[globIdx]);
      imm := M.SHORT((tgtVA DIV 1000H) - (instrVA DIV 1000H));
      w := GetWord(codeBuf, off);
      rd := w MOD 20H;
      PutWord(codeBuf, off, EncodeAdrp(rd, imm));
      imm := M.SHORT(tgtVA MOD 1000H);
      w := GetWord(codeBuf, off + 4);
      rd := w MOD 20H;
      PutWord(codeBuf, off + 4, EncodeAddImm(rd, rd, imm))
    END;
    INC(i)
  END
END PatchStringRelocs;

(** Patch own-module __DATA ADRP+ADD from LoadDataPage. *)
PROCEDURE PatchDataPageRelocs(m: ModuleSlot);
VAR i, off, imm, rd, w, lo, dataPage, instrPage, modPageOff: INTEGER;
BEGIN
  dataPage := textSize DIV 1000H - 2;
  modPageOff := m.dataBase DIV 1000H;
  lo := m.dataBase MOD 1000H;
  i := 0;
  WHILE i < m.nDataPageReloc DO
    off := m.codeBase + m.dataPageRelocOff[i] * 4;
    IF (off + 8 <= codeLen) THEN
      instrPage := off DIV 1000H;
      imm := dataPage + modPageOff - instrPage;
      w := GetWord(codeBuf, off);
      rd := w MOD 20H;
      PutWord(codeBuf, off, EncodeAdrp(rd, imm));
      w := GetWord(codeBuf, off + 4);
      rd := w MOD 20H;
      PutWord(codeBuf, off + 4, EncodeAddImm(rd, rd, lo))
    END;
    INC(i)
  END
END PatchDataPageRelocs;

(** Patch cross-module BL placeholders (CallExt). *)
PROCEDURE PatchExtCallRelocs(m: ModuleSlot): BOOLEAN;
VAR i, off, imp, tgtMod, expIdx, tgtAbs, srcAbs, imm26, instr: INTEGER;
  ok: BOOLEAN;
  pname: ARRAY maxName OF CHAR;
BEGIN
  ok := TRUE;
  i := 0;
  WHILE ok & (i < m.nExtCallReloc) DO
    off := m.codeBase + m.extCallRelocOff[i] * 4;
    imp := m.extCallRelocImp[i];
    Strings.Copy(m.extCallRelocName[i], pname);
    IF (imp >= 0) & (imp < m.nImports) THEN
      tgtMod := m.importIdx[imp];
      IF tgtMod >= 0 THEN
        expIdx := FindExport(modules[tgtMod], pname);
        IF expIdx >= 0 THEN
          tgtAbs := modules[tgtMod].codeBase + modules[tgtMod].exportOff[expIdx] * 4;
          srcAbs := off;
          imm26 := (tgtAbs - srcAbs) DIV 4;
          PutWord(codeBuf, off, EncodeBl(imm26))
        ELSE ok := FALSE
        END
      ELSE ok := FALSE
      END
    ELSE ok := FALSE
    END;
    INC(i)
  END
RETURN ok END PatchExtCallRelocs;

(** Patch imported __DATA ADRP+ADD from LoadExtDataPage. *)
PROCEDURE PatchImpDataPageRelocs(m: ModuleSlot);
VAR i, off, imm, rd, w, lo, dataPage, instrPage, modPageOff, imp, tgtMod: INTEGER;
BEGIN
  dataPage := textSize DIV 1000H - 2;
  i := 0;
  WHILE i < m.nImpDataPageReloc DO
    imp := m.impDataPageRelocImp[i];
    IF (imp >= 0) & (imp < m.nImports) THEN
      tgtMod := m.importIdx[imp];
      IF tgtMod >= 0 THEN
        modPageOff := modules[tgtMod].dataBase DIV 1000H;
        lo := modules[tgtMod].dataBase MOD 1000H;
        off := m.codeBase + m.impDataPageRelocOff[i] * 4;
        IF (off + 8 <= codeLen) THEN
          instrPage := off DIV 1000H;
          imm := dataPage + modPageOff - instrPage;
          w := GetWord(codeBuf, off);
          rd := w MOD 20H;
          PutWord(codeBuf, off, EncodeAdrp(rd, imm));
          w := GetWord(codeBuf, off + 4);
          rd := w MOD 20H;
          PutWord(codeBuf, off + 4, EncodeAddImm(rd, rd, lo))
        END
      END
    END;
    INC(i)
  END
END PatchImpDataPageRelocs;

(** Generate the bootstrap that runs before any module body:
    BL into each module's init proc in topological order, optionally
    BL into the user-specified command, then exit syscall.  Inserted
    at the start of merged code (offset 0).  Padding to 16-byte
    alignment keeps subsequent module code 4-byte aligned. *)
PROCEDURE EmitBootstrap;
VAR pos, i, target, imm26: INTEGER;
  exit0, exit1, exit2: INTEGER;
BEGIN
  pos := 0;
  i := 0;
  WHILE i < nModules DO
    target := modules[i].codeBase + modules[i].initOff * 4;
    imm26 := (target - pos) DIV 4;
    PutWord(codeBuf, pos, EncodeBl(imm26));
    INC(pos, 4);
    INC(i)
  END;
  IF cmdModIdx >= 0 THEN
    target := modules[cmdModIdx].codeBase + modules[cmdModIdx].exportOff[cmdExportIdx] * 4;
    imm26 := (target - pos) DIV 4;
    PutWord(codeBuf, pos, EncodeBl(imm26));
    INC(pos, 4)
  END;
  (* exit(0): MOVZ X0,#0; MOVZ X16,#1; SVC #0
     Reuse the encoding from Generator.Exit but inline here.
     MOVZ X0, #0 = 0xD2800000; MOVZ X16, #1 = 0xD2800030; SVC = 0xD4000001 *)
  PutWord(codeBuf, pos, -763363328); (* MOVZ X0, #0 = 0xD2800000 *)
  INC(pos, 4);
  PutWord(codeBuf, pos, -763363280); (* MOVZ X16, #1 = 0xD2800030 *)
  INC(pos, 4);
  PutWord(codeBuf, pos, -738197503); (* SVC #0 = 0xD4000001 *)
  INC(pos, 4);
  WHILE pos < bootstrapLen DO
    PutWord(codeBuf, pos, -7FFFFFFFH - 1 + 14000000H); (* B .+0 padding nop-like *)
    INC(pos, 4)
  END
END EmitBootstrap;

(** Mach-O header / load commands / linkedit blob.  Largely the same
    as the previous single-module layout; __DATA size now scales with
    nModules. *)
PROCEDURE Header;
BEGIN
  Byte(0CFH); Byte(0FAH); Byte(0EDH); Byte(0FEH);
  DWord(100000CH);
  DWord(0);
  DWord(2);
  DWord(16);
  DWord(744-16+152);
  Set({0, 2, 7, 21});
  DWord(0)
END Header;

PROCEDURE Command0;
BEGIN
  DWord(19H); DWord(72);
  String('__PAGEZERO', 16);
  QWord(0); QWord(1000000H * 100H); QWord(0); QWord(0);
  DWord(0); DWord(0); DWord(0); Set({})
END Command0;

PROCEDURE Command1;

  PROCEDURE Section0;
  BEGIN
    String('__text', 16); String('__TEXT', 16);
    QWord(1000000H * 100H + 2000H);
    QWord(codeLen);
    DWord(2000H); DWord(2);
    DWord(0); DWord(0);
    Set({10, 31});
    DWord(0); DWord(0); DWord(0)
  END Section0;

  PROCEDURE Section1;
  BEGIN
    String('__cstring', 16); String('__TEXT', 16);
    QWord(1000000H * 100H + 2000H + codeLen);
    QWord(cstringRawLen);
    DWord(2000H + codeLen); DWord(1);
    DWord(0); DWord(0);
    DWord(2);
    DWord(0); DWord(0); DWord(0)
  END Section1;

BEGIN
  DWord(19H); DWord(232);
  String('__TEXT', 16);
  QWord(1000000H * 100H);
  QWord(textSize);
  QWord(0); QWord(textSize);
  Set({0, 2}); Set({0, 2});
  DWord(2); Set({});
  Section0; Section1
END Command1;

PROCEDURE Command2;
VAR dataVmAddr: LONGINT;
  dataSegBytes: INTEGER;

  PROCEDURE Section0;
  BEGIN
    String('__data', 16); String('__DATA', 16);
    QWord(dataVmAddr);
    QWord(0);
    DWord(textSize); DWord(0);
    DWord(0); DWord(0);
    Set({});
    DWord(0); DWord(0); DWord(0)
  END Section0;

BEGIN
  dataSegBytes := totalDataPages * 1000H;
  IF dataSegBytes < 4000H THEN dataSegBytes := 4000H END;
  WHILE dataSegBytes MOD 4000H # 0 DO INC(dataSegBytes) END;
  dataVmAddr := 1000000H;
  dataVmAddr := dataVmAddr * 100H + textSize;
  DWord(19H); DWord(152);
  String('__DATA', 16);
  QWord(dataVmAddr);
  QWord(dataSegBytes);
  QWord(textSize);
  QWord(dataSegBytes);
  Set({0, 1}); Set({0, 1});
  DWord(1); Set({});
  Section0
END Command2;

PROCEDURE Command3;
VAR linkeditVmAddr: LONGINT;
  dataSegBytes: INTEGER;
BEGIN
  dataSegBytes := totalDataPages * 1000H;
  IF dataSegBytes < 4000H THEN dataSegBytes := 4000H END;
  WHILE dataSegBytes MOD 4000H # 0 DO INC(dataSegBytes) END;
  linkeditVmAddr := 1000000H;
  linkeditVmAddr := linkeditVmAddr * 100H + textSize + dataSegBytes;
  DWord(19H); DWord(72);
  String('__LINKEDIT', 16);
  QWord(linkeditVmAddr); QWord(4000H);
  QWord(textSize + dataSegBytes); QWord(176);
  DWord(1); DWord(1);
  DWord(0); Set({})
END Command3;

PROCEDURE LinkeditOff(): INTEGER;
VAR dataSegBytes: INTEGER;
BEGIN
  dataSegBytes := totalDataPages * 1000H;
  IF dataSegBytes < 4000H THEN dataSegBytes := 4000H END;
  WHILE dataSegBytes MOD 4000H # 0 DO INC(dataSegBytes) END
RETURN textSize + dataSegBytes END LinkeditOff;

PROCEDURE Command4;
BEGIN
  Byte(34H); Byte(0); Byte(0); Byte(80H);
  DWord(16);
  DWord(LinkeditOff());
  DWord(56)
END Command4;

PROCEDURE Command5;
BEGIN
  Byte(33H); Byte(0); Byte(0); Byte(80H);
  DWord(16);
  DWord(LinkeditOff() + 56);
  DWord(48)
END Command5;

PROCEDURE Command6;
BEGIN
  DWord(2);
  DWord(24);
  DWord(LinkeditOff() + 56 + 48 + 8);
  DWord(2);
  DWord(LinkeditOff() + 56 + 48 + 8 + 32);
  DWord(32)
END Command6;

PROCEDURE Command7;
BEGIN
  DWord(0BH); DWord(80);
  DWord(0); DWord(0);
  DWord(0); DWord(2);
  DWord(2); DWord(0);
  DWord(0); DWord(0);
  DWord(0); DWord(0);
  DWord(0); DWord(0);
  DWord(0); DWord(0);
  DWord(0); DWord(0);
  DWord(0); DWord(0)
END Command7;

PROCEDURE Command8;
BEGIN
  DWord(0EH); DWord(32);
  DWord(12);
  String('/usr/lib/dyld', 20)
END Command8;

PROCEDURE Command9;
BEGIN
  DWord(1BH); DWord(24);
  Word(09A45H); Word(0ADB9H); Word(02E6CH); Word(09B32H);
  Word(0E48AH); Word(06EECH); Word(07BCDH); Word(0EC6DH)
END Command9;

PROCEDURE Command10;
BEGIN
  DWord(32H); DWord(32);
  DWord(1);
  DWord(0F0000H);
  DWord(0); DWord(1);
  DWord(3); DWord(45B0703H)
END Command10;

PROCEDURE Command11;
BEGIN
  DWord(2AH); DWord(16); QWord(0)
END Command11;

PROCEDURE Command12;
BEGIN
  Byte(28H); Byte(0); Byte(0); Byte(80H);
  DWord(24);
  QWord(2000H);
  QWord(0)
END Command12;

PROCEDURE Command13;
BEGIN
  DWord(0CH); DWord(56);
  DWord(24); DWord(2);
  DWord(5470000H); DWord(10000H);
  String('/usr/lib/libSystem.B.dylib', 32)
END Command13;

PROCEDURE Command14;
BEGIN
  DWord(26H); DWord(16);
  DWord(LinkeditOff() + 104);
  DWord(8)
END Command14;

PROCEDURE Command15;
BEGIN
  DWord(29H); DWord(16);
  DWord(LinkeditOff() + 112);
  DWord(0)
END Command15;

PROCEDURE Commands;
BEGIN
  Command0; Command1; Command2; Command3; Command4; Command5;
  Command6; Command7; Command8; Command9; Command10; Command11;
  Command12; Command13; Command14; Command15
END Commands;

PROCEDURE ChainedFixups;
BEGIN
  DWord(0); DWord(20H); DWord(30H); DWord(30H);
  DWord(0); DWord(1); DWord(0);
  DWord(0);
  DWord(3); DWord(0); DWord(0); DWord(0); DWord(0);
  Word(0); Word(0)
END ChainedFixups;

PROCEDURE ExportsTrie;
BEGIN
  Byte(0); Byte(1); Byte(5FH); Byte(0);
  Byte(12H); Byte(0); Byte(0); Byte(0);
  Byte(0); Byte(2); Byte(0); Byte(0);
  Byte(0); Byte(3); Byte(0); Byte(9CH);
  Byte(7FH); Byte(0); Byte(0); Byte(2);
  String('_mh_execute_header', 0); Byte(0); Byte(9);
  String('start', 0); Byte(0); Byte(0DH); Byte(0)
END ExportsTrie;

PROCEDURE FunctionStarts;
BEGIN
  Byte(9CH); Byte(7FH); Word(0); DWord(0)
END FunctionStarts;

PROCEDURE SymbolTable;
BEGIN
  DWord(2);   DWord(10010FH); DWord(0);     DWord(1);
  DWord(16H); DWord(10FH);    DWord(3F9CH); DWord(1);
  Byte(20H); Byte(0);
  String('__mh_execute_header', 0); Byte(0);
  String('_start', 0); DWord(0)
END SymbolTable;

PROCEDURE ComputeLayout;
VAR n: INTEGER;
BEGIN
  n := 2000H + codeLen + cstringRawLen;
  WHILE n MOD 4000H # 0 DO INC(n) END;
  IF n < 4000H THEN n := 4000H END;
  textSize := n
END ComputeLayout;

PROCEDURE EmitCodeAndCString;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE i < codeLen DO
    Files.Write(exeRider, ORD(codeBuf[i]));
    INC(i)
  END;
  i := 0;
  WHILE i < cstringRawLen DO
    Byte(cstringBlob[i]);
    INC(i)
  END
END EmitCodeAndCString;

PROCEDURE Output;
VAR dataSegBytes: INTEGER;
BEGIN
  Header;
  Commands;

  Zeros(2000H - Files.Pos(exeRider));

  EmitCodeAndCString;
  Zeros(textSize - Files.Pos(exeRider));

  dataSegBytes := totalDataPages * 1000H;
  IF dataSegBytes < 4000H THEN dataSegBytes := 4000H END;
  WHILE dataSegBytes MOD 4000H # 0 DO INC(dataSegBytes) END;
  Zeros(dataSegBytes);

  ChainedFixups;
  ExportsTrie;
  FunctionStarts;
  SymbolTable
END Output;

PROCEDURE ChmodAndSign(exeName: ARRAY OF CHAR): BOOLEAN;
VAR s: ARRAY 1024 OF CHAR;
  err: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  s := 'chmod +x ';
  Strings.Append(exeName, s);
  err := M.Exec(s);
  IF err # 0 THEN
    M.WriteError(E.chmodFailed)
  ELSE
    s := 'codesign -s - -f --timestamp=none ';
    Strings.Append(exeName, s);
    err := M.Exec(s);
    IF err # 0 THEN
      M.WriteError(E.signFailed)
    ELSE
      ok := TRUE
    END
  END
RETURN ok END ChmodAndSign;

PROCEDURE Reset*;
VAR i, j: INTEGER;
BEGIN
  i := 0;
  WHILE i < maxModules DO
    modules[i] := NIL;
    modObjPath[i] := '';
    j := 0;
    WHILE j < maxImports DO importBind[i, j] := -1; INC(j) END;
    INC(i)
  END;
  nModules := 0;
  globStrCount := 0;
  cstringRawLen := 0;
  cmdModIdx := -1;
  cmdExportIdx := -1
END Reset;

(** Bind import slot impIdx of linker module modIdx to target module index. *)
PROCEDURE SetImportBind*(modIdx, impIdx, targetIdx: INTEGER);
BEGIN
  IF (modIdx >= 0) & (modIdx < maxModules) & (impIdx >= 0) & (impIdx < maxImports) THEN
    importBind[modIdx, impIdx] := targetIdx
  END
END SetImportBind;

PROCEDURE ImportCount*(modIdx: INTEGER): INTEGER;
VAR n: INTEGER;
BEGIN
  IF (modIdx >= 0) & (modIdx < nModules) & (modules[modIdx] # NIL) THEN
    n := modules[modIdx].nImports
  ELSE n := 0
  END
RETURN n END ImportCount;

PROCEDURE ImportName*(modIdx, impIdx: INTEGER; VAR name: ARRAY OF CHAR);
BEGIN
  name[0] := 0X;
  IF (modIdx >= 0) & (modIdx < nModules) & (modules[modIdx] # NIL) &
     (impIdx >= 0) & (impIdx < modules[modIdx].nImports) THEN
    Strings.Copy(modules[modIdx].importNames[impIdx], name)
  END
END ImportName;

(** Add a module's .obj file by full path. *)
PROCEDURE AddModulePath*(objPath: ARRAY OF CHAR): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  ok := FALSE;
  IF nModules < maxModules THEN
    Strings.Copy(objPath, modObjPath[nModules]);
    IF ReadObj(nModules, objPath) THEN
      INC(nModules); ok := TRUE
    ELSE
      M.WriteErrorS(E.cantOpenObj, objPath)
    END
  END
RETURN ok END AddModulePath;

(** Set the program command (M.P).  modName must be one of the modules
    added via AddModule; procName must be an exported parameter-less,
    no-result procedure of that module.  Returns FALSE on lookup
    failure. *)
PROCEDURE SetCommand*(modName, procName: ARRAY OF CHAR): BOOLEAN;
VAR midx, eidx: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  midx := FindModuleByName(modName);
  IF midx < 0 THEN
    M.WriteError(E.noModuleForCmd)
  ELSE
    eidx := FindExport(modules[midx], procName);
    IF eidx < 0 THEN
      M.WriteError(E.cmdNotFound)
    ELSIF ~modules[midx].exportIsCmd[eidx] THEN
      M.WriteError(E.cmdHasParams)
    ELSE
      cmdModIdx := midx;
      cmdExportIdx := eidx;
      ok := TRUE
    END
  END
RETURN ok END SetCommand;

(** Drives the actual link: layout, code load, reloc patching,
    bootstrap emission, Mach-O write, codesign. *)
PROCEDURE LinkAll*(exeName: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
  ok: BOOLEAN;
  objName: ARRAY 256 OF CHAR;
BEGIN
  ok := TRUE;
  IF nModules = 0 THEN ok := FALSE END;

  IF ok THEN
    Layout(cmdModIdx >= 0);
    IF codeLen > LEN(codeBuf) THEN
      M.WriteError(E.invalidObjFile);
      ok := FALSE
    END
  END;

  IF ok THEN
    ResolveImports;
    i := 0;
    WHILE ok & (i < nModules) DO
      Strings.Copy(modObjPath[i], objName);
      IF ~LoadCodeAt(objName, modules[i]) THEN
        M.WriteErrorS(E.cantOpenObj, objName);
        ok := FALSE
      END;
      INC(i)
    END
  END;

  IF ok THEN
    EmitBootstrap;
    ComputeLayout;
    i := 0;
    WHILE ok & (i < nModules) DO
      PatchStringRelocs(modules[i]);
      PatchDataPageRelocs(modules[i]);
      PatchImpDataPageRelocs(modules[i]);
      IF ~PatchExtCallRelocs(modules[i]) THEN ok := FALSE END;
      INC(i)
    END
  END;

  IF ok THEN
    cstringAlignedLen := cstringRawLen;
    WHILE cstringAlignedLen MOD 4 # 0 DO INC(cstringAlignedLen) END;
    exeFile := Files.New(exeName);
    Files.Set(exeRider, exeFile, 0);
    Output;
    Files.Register(exeFile);
    ok := ChmodAndSign(exeName);
    IF ok THEN M.WriteS(E.linkComplete, exeName) END
  END
RETURN ok END LinkAll;

(** Add a module by name, searching build dir then lib cache. *)
PROCEDURE AddModule*(modName: ARRAY OF CHAR): BOOLEAN;
VAR path: ARRAY 256 OF CHAR;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  IF M.FindObjFile(modName, path) THEN ok := AddModulePath(path)
  ELSE M.WriteErrorS(E.cantOpenObj, modName)
  END
RETURN ok END AddModule;

(** Backwards-compatible shim used by single-module callers. *)
PROCEDURE Link*(modName: ARRAY OF CHAR): BOOLEAN;
VAR exeName: ARRAY 256 OF CHAR;
  ok: BOOLEAN;
BEGIN
  Reset;
  ok := AddModule(modName);
  IF ok THEN
    IF M.outExe[0] # 0X THEN
      Strings.Copy(M.outExe, exeName)
    ELSIF M.outExeDir[0] # 0X THEN
      Strings.Copy(M.outExeDir, exeName);
      Strings.Append(modName, exeName)
    ELSE
      Strings.Copy(modName, exeName)
    END;
    ok := LinkAll(exeName)
  END
RETURN ok END Link;

BEGIN
  Reset
END Linker.
