MODULE Linker;
IMPORT Files, Strings, E := ErrorMsg, M := Machine, Utf8, SYSTEM;

CONST
  version = 1;
  (** Object file mark *)
  objFileMark = ORD('A') + 256 * (ORD('R') + 256 * (ORD('M') + 256 * version));
  objHeaderSize = 32;
  maxStrPool = 256;
  maxReloc = 512;

TYPE
  LONGINT = M.LONGINT;

VAR
  objFile: Files.File;
  exeFile: Files.File;
  objRider: Files.Rider;
  exeRider: Files.Rider;
  codeLen: INTEGER; (** Length of the machine code in bytes, read from the .obj file *)
  entryOffset: INTEGER; (** Module entry offset in bytes within code, read from .obj header *)
  cstringLen: INTEGER; (** Total size of merged string pool in object *)
  relocN: INTEGER;
  relocOff: ARRAY maxReloc OF INTEGER;
  relocIdx: ARRAY maxReloc OF INTEGER;
  gdRelocN: INTEGER; (** Number of global-data ADRP relocations *)
  gdRelocOff: ARRAY maxReloc OF INTEGER; (** Byte offsets of those ADRPs within code *)
  strOff: ARRAY maxStrPool OF INTEGER; (** Offset of str i within cstring blob *)
  codeBuf: ARRAY 64000 OF CHAR;
  (** UTF-16LE code units + UTF-16 NUL for each literal; byte-indexed for Mach-O __cstring *)
  cstringBlob: ARRAY 16384 OF BYTE;
  cstringRawLen: INTEGER;
  cstringAlignedLen: INTEGER; (** cstringRawLen rounded up to 4 (kept for back-compat math) *)
  nPoolStr: INTEGER;
  (** Mach-O __TEXT segment size, in bytes, computed dynamically from codeLen
      + cstringRawLen and rounded up to a 4 KB page. Drives __DATA / __LINKEDIT
      file/VM offsets and the page distance encoded in global-data ADRPs. *)
  textSize: INTEGER;

(** Outputs 1 byte to the file. *)
PROCEDURE Byte(x: BYTE);
BEGIN
  Files.Write(exeRider, x)
END Byte;

(** Outputs 2 bytes to the file. Little-endian.*)
PROCEDURE Word(x: INTEGER);
BEGIN
  Byte(x MOD 100H);
  Byte(x DIV 100H MOD 100H)
END Word;

(** Outputs a double word = 4 bytes to the file. Little-endian.*)
PROCEDURE DWord(x: INTEGER);
BEGIN
  Byte(x MOD 100H);
  Byte(x DIV 100H MOD 100H);
  Byte(x DIV 10000H MOD 100H);
  Byte(x DIV 1000000H MOD 100H)
END DWord;

(** Outputs a quadruple word = 8 bytes to the file. Little-endian.*)
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

(** Outputs a set as 4 bytes to the file. Little-endian.*)
PROCEDURE Set(x: SET);
BEGIN
  DWord(ORD(x))
END Set;

(** Outputs string to the file (one byte per character) and then
    zero-bytes until total of n bytes is reached.
    If n is smaller than the string, the string is not truncated. *)
PROCEDURE String(s: ARRAY OF CHAR; n: INTEGER);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    Byte(ORD(s[i]));
    INC(i)
  END;
  WHILE i < n DO
    Byte(0);
    INC(i)
  END
END String;

(** Outputs n zero bytes to the file. *)
PROCEDURE Zeros(n: INTEGER);
BEGIN
  WHILE n > 0 DO
    Byte(0);
    DEC(n)
  END
END Zeros;

(** Outputs first 32 bytes - the Mach-O header to the file. *)
PROCEDURE Header;
BEGIN
  (* FEED-FACF Magic Number, little-endian *)
  Byte(0CFH); Byte(0FAH); Byte(0EDH); Byte(0FEH);
  (* CPU Type = ARM64 *)
  DWord(100000CH);
  (* CPU Subtype = ARM64_ALL *)
  DWord(0);
  (* File Type = MH_EXECUTE *)
  DWord(2);
  (* Number of Load Commands *)
  DWord(16);
  (* Size of Load Commands in bytes *)
  DWord(744-16+152); (* 152 is data segment command *)
  (* Flags = {NOUNDEFS, DYLDLINK, TWOLEVEL, PIE} *)
  Set({0, 2, 7, 21});
  (* Reserved = 0 *)
  DWord(0)
END Header;

PROCEDURE Command0;
BEGIN
  (* Command LC_SEGMENT_64 *)
  DWord(19H);
  (* Command Size in bytes *)
  DWord(72);
  (* Segment Name *)
  String('__PAGEZERO', 16);
  (* VM Address *)
  QWord(0);
  (* VM Size *)
  QWord(1000000H * 100H); (* 4 GB *)
  (* File Offset *)
  QWord(0);
  (* File Size *)
  QWord(0);
  (* Maximum VM Protection *)
  DWord(0);
  (* Initial VM Protection *)
  DWord(0);
  (* Number of Sections *)
  DWord(0);
  (* Flags *)
  Set({})
END Command0;

PROCEDURE Command1;

  PROCEDURE Section0;
  BEGIN
    (* Section Name *)
    String('__text', 16);
    (* Segment Name *)
    String('__TEXT', 16);
    (* Address *)
    QWord(1000000H * 100H + 2000H);
    (* Size in bytes — pure instructions only *)
    QWord(codeLen);
    (* Offset *)
    DWord(2000H);
    (* Alignment = 2^2 = 4 *)
    DWord(2);
    (* Relocations Offset *)
    DWord(0);
    (* Number of Relocations *)
    DWord(0);
    (* Flags = S_ATTR_SOME_INSTRUCTIONS + S_ATTR_PURE_INSTRUCTIONS *)
    Set({10, 31});
    (* Reserved *)
    DWord(0);
    DWord(0);
    DWord(0)
  END Section0;

  PROCEDURE Section1;
  BEGIN
    (* Section Name: holds the literal pool (UTF-16LE strings, NUL-terminated) *)
    String('__cstring', 16);
    (* Segment Name *)
    String('__TEXT', 16);
    (* Address *)
    QWord(1000000H * 100H + 2000H + codeLen);
    (* Size in bytes — exact length of the string blob, no trailing padding *)
    QWord(cstringRawLen);
    (* Offset *)
    DWord(2000H + codeLen);
    (* Alignment = 2^1 = 2 (UTF-16 code units) *)
    DWord(1);
    (* Relocations Offset *)
    DWord(0);
    (* Number of Relocations *)
    DWord(0);
    (* Flags: section type S_CSTRING_LITERALS = 2 in low 8 bits *)
    DWord(2);
    (* Reserved *)
    DWord(0);
    DWord(0);
    DWord(0)
  END Section1;

BEGIN (* Command1 *)
  (* Command LC_SEGMENT_64 *)
  DWord(19H);
  (* Command Size in bytes *)
  DWord(232);
  (* Segment Name *)
  String('__TEXT', 16);
  (* VM Address *)
  QWord(1000000H * 100H); (* 4 GB *)
  (* VM Size: dynamic, 4 KB-page-aligned, computed in ComputeLayout *)
  QWord(textSize);
  (* File Offset *)
  QWord(0);
  (* File Size *)
  QWord(textSize);
  (* Maximum VM Protection = VM_PROT_READ, VM_PROT_EXECUTE *)
  Set({0, 2});
  (* Initial VM Protection = VM_PROT_READ, VM_PROT_EXECUTE *)
  Set({0, 2});
  (* Number of Sections *)
  DWord(2);
  (* Flags *)
  Set({});
  (* Sections *)
  Section0;
  Section1
END Command1;

PROCEDURE Command2;
VAR dataVmAddr: LONGINT;

  PROCEDURE Section0;
  BEGIN
    (* Section Name *)
    String('__data', 16);
    (* Segment Name *)
    String('__DATA', 16);
    (* Address *)
    QWord(dataVmAddr);
    (* Size in bytes *)
    QWord(0(*dataLen*));
    (* Offset *)
    DWord(textSize);
    (* Alignment = 2^0 = 1 *)
    DWord(0);
    (* Relocations Offset *)
    DWord(0);
    (* Number of Relocations *)
    DWord(0);
    (* Flags = S_REGULAR *)
    Set({});
    (* Reserved *)
    DWord(0);
    DWord(0);
    DWord(0)
  END Section0;

BEGIN (* Command2 *)
  dataVmAddr := 1000000H;
  dataVmAddr := dataVmAddr * 100H + textSize;
  (* Command LC_SEGMENT_64 *)
  DWord(19H);
  (* Command Size in bytes *)
  DWord(152);
  (* Segment Name *)
  String('__DATA', 16);
  (* VM Address: __TEXT vmaddr + textSize *)
  QWord(dataVmAddr);
  (* VM Size *)
  QWord(4000H); (* 16 KB *)
  (* File Offset *)
  QWord(textSize);
  (* File Size *)
  QWord(4000H); (* 16 KB *)
  (* Maximum VM Protection = VM_PROT_READ, VM_PROT_WRITE *)
  Set({0, 1});
  (* Initial VM Protection = VM_PROT_READ, VM_PROT_WRITE *)
  Set({0, 1});
  (* Number of Sections *)
  DWord(1);
  (* Flags *)
  Set({});
  (* Sections *)
  Section0
END Command2;

PROCEDURE Command3;
VAR linkeditVmAddr: LONGINT;
BEGIN
  linkeditVmAddr := 1000000H;
  linkeditVmAddr := linkeditVmAddr * 100H + textSize + 4000H;
  (* Command LC_SEGMENT_64 *)
  DWord(19H);
  (* Command Size in bytes *)
  DWord(72);
  (* Segment Name *)
  String('__LINKEDIT', 16);
  (* VM Address: __DATA vmaddr + 4000H *)
  QWord(linkeditVmAddr);
  (* VM Size *)
  QWord(4000H); (* 16 KB *)
  (* File Offset: end of __DATA = textSize + 4000H *)
  QWord(textSize + 4000H);
  (* File Size *)
  QWord(176);
  (* Maximum VM Protection *)
  DWord(1);
  (* Initial VM Protection *)
  DWord(1);
  (* Number of Sections *)
  DWord(0);
  (* Flags *)
  Set({})
END Command3;

PROCEDURE Command4;
VAR linkeditOff: INTEGER;
BEGIN
  linkeditOff := textSize + 4000H;
  (* Command LC_DYLD_CHAINED_FIXUPS *)
  (*DWord(34H);*) (* FIXME 34 00 00 80, what is 8 for? *)
  Byte(34H); Byte(0); Byte(0); Byte(80H);
  (* Command Size in bytes *)
  DWord(16);
  (* Data Offset = start of __LINKEDIT *)
  DWord(linkeditOff);
  (* Data Size *)
  DWord(56)
END Command4;

PROCEDURE Command5;
VAR linkeditOff: INTEGER;
BEGIN
  linkeditOff := textSize + 4000H;
  (* Command LC_DYLD_EXPORTS_TRIE *)
  (*DWord(33H);*) (* FIXME what is 8 for? *)
  Byte(33H); Byte(0); Byte(0); Byte(80H);
  (* Command Size in bytes *)
  DWord(16);
  (* Data Offset *)
  DWord(linkeditOff + 56);
  (* Data Size *)
  DWord(48)
END Command5;

PROCEDURE Command6;
VAR linkeditOff: INTEGER;
BEGIN
  linkeditOff := textSize + 4000H;
  (* Command LC_SYMTAB *)
  DWord(2);
  (* Command Size in bytes *)
  DWord(24);
  (* Symbol Table Offset, 8 bytes contain the procedure starts table, Seg. 13 *)
  DWord(linkeditOff + 56 + 48 + 8); (* linkedit + 112 *)
  (* Number of Symbols *)
  DWord(2);
  (* String Table Offset *)
  DWord(linkeditOff + 56 + 48 + 8 + 32); (* linkedit + 144 *)
  (* String Table Size *)
  DWord(32)
END Command6;

PROCEDURE Command7;
BEGIN
  (* Command LC_DYSYMTAB *)
  DWord(0BH);
  (* Command Size in bytes *)
  DWord(80);

  (* LocSymbol Index *)
  DWord(0);
  (* LocSymbol Number *)
  DWord(0);

  (* Defined ExtSymbol Index *)
  DWord(0);
  (* Defined ExtSymbol Number *)
  DWord(2);

  (* Undefined ExtSymbol Index *)
  DWord(2);
  (* Undefined ExtSymbol Number *)
  DWord(0);

  (* TOC (Table of Contents) Offset *)
  DWord(0);
  (* TOC Entries *)
  DWord(0);

  (* Module Table Offset *)
  DWord(0);
  (* Module Table Entries *)
  DWord(0);

  (* ExtRef Table Offset *)
  DWord(0);
  (* ExtRef Table Entries *)
  DWord(0);

  (* IndSym Table Offset *)
  DWord(0);
  (* IndSym Table Entries *)
  DWord(0);

  (* ExtReloc Table Offset *)
  DWord(0);
  (* ExtReloc Table Entries *)
  DWord(0);

  (* LocReloc Table Offset *)
  DWord(0);
  (* LocReloc Table Entries *)
  DWord(0)
END Command7;

PROCEDURE Command8;
BEGIN
  (* Command LC_LOAD_DYLINKER *)
  DWord(0EH);
  (* Command Size in bytes *)
  DWord(32);
  (* String Offset *)
  DWord(12);
  (* Name *)
  String('/usr/lib/dyld', 20)
END Command8;

PROCEDURE Command9;
BEGIN
  (* Command LC_UUID *)
  DWord(1BH);
  (* Command Size in bytes *)
  DWord(24);
  (* UUID, 16 bytes, TODO generate random *)
  Word(09A45H); Word(0ADB9H); Word(02E6CH); Word(09B32H);
  Word(0E48AH); Word(06EECH); Word(07BCDH); Word(0EC6DH)
END Command9;

PROCEDURE Command10;
BEGIN
  (* Command LC_BUILD_VERSION *)
  DWord(32H);
  (* Command Size in bytes *)
  DWord(32);
  (* Platform = MacOS *)
  DWord(1);
  (* Minimum OS Version = 15.0.0 *)
  DWord(0F0000H);
  (* SDK Version, 0 = undefined *)
  DWord(0);
  (* Tool Count - number of elements in the array below *)
  DWord(1);

  (* Array of Tools, 1 element *)
  (* Tool Type = linker ld *)
  DWord(3);
  (* Tool Version = 1115.7.3 *)
  DWord(45B0703H)
END Command10;

PROCEDURE Command11;
BEGIN
  (* Command LC_SOURCE_VERSION *)
  DWord(2AH);
  (* Command Size in bytes *)
  DWord(16);
  (* Version = 0.0 *)
  QWord(0)
END Command11;

PROCEDURE Command12;
BEGIN
  (* Command LC_MAIN *)
  Byte(28H); Byte(0); Byte(0); Byte(80H);
  (* Command Size in bytes *)
  DWord(24);
  (* Entry Offset = start of __TEXT + module BEGIN offset *)
  QWord(2000H + entryOffset);
  (* Initial Stack Size, may be 0 *)
  QWord(0)
END Command12;

PROCEDURE Command13;
BEGIN
  (* Command LC_LOAD_DYLIB *)
  DWord(0CH);
  (* Command Size in bytes *)
  DWord(56);
  (* String Offset *)
  DWord(24);
  (* Time Stamp = 1970-01-01 00:00:02 *)
  DWord(2);
  (* Current Version = 1351.0.0 *)
  DWord(5470000H);
  (* Compatibility Version *)
  DWord(10000H);
  (* Name *)
  String('/usr/lib/libSystem.B.dylib', 32)
END Command13;

PROCEDURE Command14;
BEGIN
  (* Command LC_FUNCTION_STARTS *)
  DWord(26H);
  (* Command Size in bytes *)
  DWord(16);
  (* Data Offset *)
  DWord(textSize + 4000H + 104);
  (* Data Size *)
  DWord(8)
END Command14;

PROCEDURE Command15;
BEGIN
  (* Command LC_DATA_IN_CODE *)
  DWord(29H);
  (* Command Size in bytes *)
  DWord(16);
  (* Data Offset *)
  DWord(textSize + 4000H + 112);
  (* Data Size *)
  DWord(0)
END Command15;

(** Outputs Mach-O commands to the file. *)
PROCEDURE Commands;
BEGIN
  Command0;
  Command1;
  Command2;
  Command3;
  Command4;
  Command5;
  Command6;
  Command7;
  Command8;
  Command9;
  Command10;
  Command11;
  Command12;
  Command13;
  Command14;
  Command15
END Commands;

(** Outputs 56 bytes to the file. *)
PROCEDURE ChainedFixups;
BEGIN
  (* Fixups Version *)
  DWord(0);
  (* Starts Offset *)
  DWord(20H);
  (* Imports Offset *)
  DWord(30H);
  (* Symbols Offset *)
  DWord(30H);
  (* Imports Count *)
  DWord(0);
  (* Imports Format *)
  DWord(1);
  (* Symbols Format *)
  DWord(0);

  (* Starts in Image *)
  (* Segment Count *)
  DWord(0);
  (* Segment Info Offset - DWord array (empty) *)

  (* Starts in Segment *)
  (* Size *)
  DWord(3);
  (* Page Size *)
  DWord(0);
  (* Pointer Format *)
  DWord(0);
  (* Segment Offset *)
  DWord(0);
  (* Maximum Valid Pointer *)
  DWord(0);
  (* Page Count *)
  Word(0);
  (* Page Start - DWord array *)
  Word(0)
END ChainedFixups;

(** Outputs 48 bytes to the file. *)
PROCEDURE ExportsTrie;
BEGIN
  Byte(0);   Byte(1);   Byte(5FH); Byte(0);
  Byte(12H); Byte(0);   Byte(0);   Byte(0);

  Byte(0);   Byte(2);   Byte(0);   Byte(0);
  Byte(0);   Byte(3);   Byte(0);   Byte(9CH);
  Byte(7FH); Byte(0);   Byte(0);   Byte(2);

  String('_mh_execute_header', 0);
  Byte(0);   Byte(9);

  String('start', 0);
  Byte(0);   Byte(0DH); Byte(0)
END ExportsTrie;

PROCEDURE FunctionStarts;
BEGIN
  Byte(9CH); Byte(7FH); Word(0); DWord(0)
END FunctionStarts;

PROCEDURE SymbolTable;
BEGIN
  (* Proper Symbol Table *)
  DWord(2);   DWord(10010FH); DWord(0);     DWord(1);
  DWord(16H); DWord(10FH);    DWord(3F9CH); DWord(1);

  (* Name Strings *)
  Byte(20H); Byte(0);
  String('__mh_execute_header', 0); Byte(0);
  String('_start', 0); DWord(0)
END SymbolTable;

PROCEDURE GetWord(VAR buf: ARRAY OF CHAR; off: INTEGER): INTEGER;
RETURN ORD(buf[off]) + ORD(buf[off + 1]) * 100H +
       ORD(buf[off + 2]) * 10000H + ORD(buf[off + 3]) * 1000000H
END GetWord;

PROCEDURE PutWord(VAR buf: ARRAY OF CHAR; off: INTEGER; w: INTEGER);
BEGIN
  buf[off] := CHR(w MOD 100H);
  buf[off + 1] := CHR(w DIV 100H MOD 100H);
  buf[off + 2] := CHR(w DIV 10000H MOD 100H);
  buf[off + 3] := CHR(w DIV 1000000H MOD 100H)
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

PROCEDURE PatchStringRelocs;
VAR i, off, idx, imm, rd: INTEGER;
  w: INTEGER;
  textBase, instrVA, tgtVA: LONGINT;
BEGIN
  (* __text section VM address — must match Command1 Section0; use LONGINT to avoid 32-bit overflow. *)
  textBase := 1000000H;
  textBase := textBase * 100H + 2000H;
  i := 0;
  WHILE i < relocN DO
    off := relocOff[i];
    idx := relocIdx[i];
    IF (idx >= 0) & (idx < nPoolStr) & (off >= 0) & (off + 8 <= codeLen) THEN
      instrVA := textBase + off;
      tgtVA := textBase + (codeLen + strOff[idx]);
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

(** Append decoded UTF-16 string u (0X-terminated) to cstringBlob
    as little-endian WCHARs + UTF-16 NUL. *)
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

PROCEDURE ReadObjFile(): BOOLEAN;
VAR mark, clen, slen, rlen, gdlen: INTEGER;
  si, j, i, bi: INTEGER;
  padB, rb: BYTE;
  ok: BOOLEAN;
  u8: ARRAY 2048 OF Utf8.SHORTCHAR;
  u16: ARRAY 512 OF CHAR;
BEGIN
  ok := TRUE;
  Files.Set(objRider, objFile, 0);
  Files.ReadInt(objRider, mark);
  IF mark # objFileMark THEN ok := FALSE END;
  IF ok THEN
    Files.ReadInt(objRider, entryOffset);
    Files.ReadInt(objRider, clen);
    Files.ReadInt(objRider, slen);
    Files.ReadInt(objRider, rlen);
    Files.ReadInt(objRider, gdlen);
    WHILE Files.Pos(objRider) < objHeaderSize DO Files.Read(objRider, padB) END;
    IF (clen > LEN(codeBuf)) OR (clen < 0) THEN ok := FALSE END
  END;
  IF ok THEN
    i := 0;
    WHILE i < clen DO
      Files.Read(objRider, rb);
      codeBuf[i] := CHR(rb);
      INC(i)
    END;
    codeLen := clen;
    cstringRawLen := 0;
    Files.ReadInt(objRider, nPoolStr);
    si := 0;
    WHILE si < nPoolStr DO
      strOff[si] := cstringRawLen;
      (* One literal: UTF-8 bytes until 0X, then decode to UTF-16LE in blob *)
      j := 0;
      REPEAT
        Files.Read(objRider, rb);
        IF rb # 0 THEN
          IF j < LEN(u8) - 1 THEN
            bi := SYSTEM.VAL(INTEGER, rb);
            u8[j] := Utf8.ShortChr(bi); INC(j)
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
      INC(si)
    END;
    cstringAlignedLen := cstringRawLen;
    WHILE cstringAlignedLen MOD 4 # 0 DO INC(cstringAlignedLen) END;
    Files.ReadInt(objRider, relocN);
    IF relocN > maxReloc THEN ok := FALSE END;
    IF ok THEN
      i := 0;
      WHILE i < relocN DO
        Files.ReadInt(objRider, relocOff[i]);
        Files.ReadInt(objRider, relocIdx[i]);
        INC(i)
      END;
      Files.ReadInt(objRider, gdRelocN);
      IF gdRelocN > maxReloc THEN ok := FALSE END;
      IF ok THEN
        i := 0;
        WHILE i < gdRelocN DO
          Files.ReadInt(objRider, gdRelocOff[i]);
          INC(i)
        END
      END
    END
  END;
RETURN ok END ReadObjFile;

(** Choose the smallest 16 KB-page-aligned __TEXT size that fits the Mach-O
    header (always 0x2000) plus the __text and __cstring sections.
    Apple Silicon kernel maps segments at 16 KB virtual page granularity, so
    every segment vmsize/filesize must be a multiple of 0x4000 — using 4 KB
    alignment trips dyld with EFAULT/"Cannot allocate memory" at exec.
    Sets the global `textSize`. Must be called after ReadObjFile. *)
PROCEDURE ComputeLayout;
VAR n: INTEGER;
BEGIN
  n := 2000H + codeLen + cstringRawLen;
  WHILE n MOD 4000H # 0 DO INC(n) END;
  IF n < 4000H THEN n := 4000H END;
  textSize := n
END ComputeLayout;

(** Patch every recorded global-data ADRP to load the page address of the
    __DATA segment. The placeholder ADRPs were emitted by Generator with
    target page = 0; here we encode the actual page distance based on the
    chosen `textSize` (see ComputeLayout). *)
PROCEDURE PatchGlobalDataRelocs;
VAR i, off, imm, rd, w: INTEGER;
  dataPage, instrPage: INTEGER;
BEGIN
  dataPage := textSize DIV 1000H - 2;
  i := 0;
  WHILE i < gdRelocN DO
    off := gdRelocOff[i];
    IF (off >= 0) & (off + 4 <= codeLen) THEN
      instrPage := off DIV 1000H;
      imm := dataPage - instrPage;
      w := GetWord(codeBuf, off);
      rd := w MOD 20H;
      PutWord(codeBuf, off, EncodeAdrp(rd, imm))
    END;
    INC(i)
  END
END PatchGlobalDataRelocs;

PROCEDURE Output;
BEGIN
  Header;
  Commands;

  (* Zero-out until position 2000H *)
  Zeros(2000H - Files.Pos(exeRider));

  (* Machine code + literal pool (__text + __cstring sections) *)
  EmitCodeAndCString;
  (* Zero-fill rest of __TEXT segment up to textSize. *)
  Zeros(textSize - Files.Pos(exeRider));

  (* Data (global variables) *)
  Zeros(4000H); (*!TODO call something like OutputData*)

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
  (* Chmod *)
  s := 'chmod +x ';
  Strings.Append(exeName, s);
  err := M.Exec(s);
  IF err # 0 THEN
    M.WriteError(E.chmodFailed)
  ELSE
    (* Sign *)
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

(** Link single module *)
PROCEDURE Link*(modName: ARRAY OF CHAR): BOOLEAN;
VAR objName, exeName: ARRAY 256 OF CHAR;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  
  (* Prepare file names *)
  Strings.Copy(M.outDir, objName); Strings.Append(modName, objName);
  Strings.Append('.obj', objName);
  IF M.outExe[0] # 0X THEN
    Strings.Copy(M.outExe, exeName)
  ELSE
    Strings.Copy(M.outDir, exeName); Strings.Append(modName, exeName)
  END;
  
  (* Open object file *)
  objFile := Files.Old(objName);
  IF objFile # NIL THEN
    IF ReadObjFile() THEN
      ComputeLayout;
      PatchStringRelocs;
      PatchGlobalDataRelocs;
      exeFile := Files.New(exeName);
      Files.Set(exeRider, exeFile, 0);
      Output;
      Files.Register(exeFile);
      IF ChmodAndSign(exeName) THEN
        M.WriteS(E.linkComplete, exeName);
        ok := TRUE
      END
    ELSE
      M.WriteError(E.invalidObjFile)
    END
  ELSE
    M.WriteErrorS(E.cantOpenObj, objName)
  END
RETURN ok END Link;

END Linker.
