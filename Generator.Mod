MODULE Generator;
IMPORT Strings, Files, ST := SymTable, M := Machine, E := ErrorMsg;

CONST
  (** Output RISC machine code marks **)
  version = 1;
  (** Machine code file mark (first 4 bytes of .obj file) *)
  fileMark = ORD('A') + 256 * (ORD('R') + 256 * (ORD('M') + 256 * version));

  objHeaderBytes* = 40;
  maxStrReloc = 512;
  maxDataPageReloc = 1024;
  maxImports* = 32;
  maxExports* = 256;
  maxExtCallReloc = 1024;
  maxName* = 64;

  (** Special registers **)
  SP* = 31; (** Stack pointer register, also zero register *)

TYPE
  LONGINT = M.LONGINT;

VAR
  outFile: Files.File; (** Output file *)
  outR: Files.Rider;

  codeFile: Files.File; (** Temporary file (buffer) for machine code output *)
  codeR: Files.Rider; (** ARM64 instructions must land on positions divisible by 4 *)

  entryWordOffset: INTEGER; (** Module init proc offset in 32-bit words within code *)
  varSize*: INTEGER; (** Total bytes of module-level variables in __DATA *)
  modName: ARRAY maxName OF CHAR;

  (** String-pool ADRP+ADD: code offset in words, strPool index (LoadStringAddr). *)
  strRelocN: INTEGER;
  strRelocOff: ARRAY maxStrReloc OF INTEGER;
  strRelocIdx: ARRAY maxStrReloc OF INTEGER;

  (** Own __DATA page ADRP relocations: code offset in words (LoadDataPage). *)
  dataPageRelocN: INTEGER;
  dataPageRelocOff: ARRAY maxDataPageReloc OF INTEGER;

  (** Imported __DATA page ADRP: code offset in words, import index. *)
  impDataPageRelocN: INTEGER;
  impDataPageRelocOff: ARRAY maxDataPageReloc OF INTEGER;
  impDataPageRelocImp: ARRAY maxDataPageReloc OF INTEGER;

  (** Imported user modules in declaration order. *)
  importN*: INTEGER;
  importNames: ARRAY maxImports, maxName OF CHAR;

  (** Exported procedures: name, code offset in words, isCmd (0 = proc, 1 = command). *)
  exportN*: INTEGER;
  exportNames: ARRAY maxExports, maxName OF CHAR;
  exportOff: ARRAY maxExports OF INTEGER;
  exportIsCmd: ARRAY maxExports OF BOOLEAN;

  (** Cross-module BL (CallExt): code offset in words, import index, proc name. *)
  extCallRelocN: INTEGER;
  extCallRelocOff: ARRAY maxExtCallReloc OF INTEGER;
  extCallRelocImp: ARRAY maxExtCallReloc OF INTEGER;
  extCallRelocName: ARRAY maxExtCallReloc, maxName OF CHAR;

  compileFlags: INTEGER;

(** Current code position, in words from the start of code segment. *)
PROCEDURE Here*(): INTEGER;
RETURN Files.Pos(codeR) DIV 4 END Here;

(** Current code position, in bytes from the start of code segment. *)
PROCEDURE HereBytes*(): INTEGER;
RETURN Files.Pos(codeR) END HereBytes;

(** Outputs 1 byte. *)
PROCEDURE Byte*(x: BYTE);
BEGIN
  Files.Write(codeR, x)
END Byte;

(** Outputs 2 bytes. Little-endian.*)
PROCEDURE Word*(x: INTEGER);
BEGIN
  Files.Write(codeR, x MOD 100H);
  Files.Write(codeR, x DIV 100H MOD 100H)
END Word;

(** Outputs a double word = 4 bytes. Little-endian.*)
PROCEDURE DWord*(x: INTEGER);
BEGIN
  Files.Write(codeR, x MOD 100H);
  Files.Write(codeR, x DIV 100H MOD 100H);
  Files.Write(codeR, x DIV 10000H MOD 100H);
  Files.Write(codeR, x DIV 1000000H MOD 100H)
END DWord;

(** Outputs a set as 4 bytes. Little-endian.*)
PROCEDURE Set(x: SET);
BEGIN
  DWord(ORD(x))
END Set;

(** Outputs string to the file (one byte per character). *)
PROCEDURE String(s: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    Byte(ORD(s[i]));
    INC(i)
  END
END String;

(** Returns log2(size) for encoding purposes. *)
PROCEDURE SizeToLog(size: INTEGER): INTEGER;
BEGIN
  IF    size = 1 THEN size := 0 (* BOOLEAN *)
  ELSIF size = 2 THEN size := 1 (* CHAR *)
  ELSIF size = 4 THEN size := 2 (* INTEGER *)
  ELSIF size = 8 THEN size := 3 (* LONGINT / pointer *)
  ELSE ASSERT(FALSE)
  END
RETURN size END SizeToLog;

(** Generates code that terminates the program. *)
PROCEDURE Exit*;
BEGIN
  Word(00000H); Word(0D280H);
  Word(00030H); Word(0D280H);
  Word(00001H); Word(0D400H)
END Exit;

(** MOVK x{r}, #{imm}, #{shift} *)
PROCEDURE MovK*(r, imm, shift: INTEGER);
VAR n: INTEGER;
BEGIN
  ASSERT(imm MOD 10000H = imm);
  ASSERT((shift = 0) OR (shift = 16) OR (shift = 32) OR (shift = 48));

  (* MOVK Xr, #imm, LSL#shift  = 0xF2800000 | (hw<<21) | (imm16<<5) | Rd *)
  n := 72800000H + (shift DIV 16) * 200000H + imm * 20H + r;
  n := -7FFFFFFFH - 1 + n;

  DWord(n)
END MovK;

(** MOVZ x{r}, #{imm}, LSL #{shift} *)
PROCEDURE MovZ*(r, imm, shift: INTEGER);
VAR n: INTEGER;
BEGIN
  ASSERT(imm MOD 10000H = imm);
  ASSERT((shift = 0) OR (shift = 16) OR (shift = 32) OR (shift = 48));

  (* 0xD2800000 | (hw<<21) | (imm16<<5) | Rd; pre-subtract 0x80000000 for DWord signed layout *)
  n := 52800000H + (shift DIV 16) * 200000H + imm * 20H + r;
  n := -7FFFFFFFH - 1 + n;

  DWord(n)
END MovZ;

(** MOVN x{r}, #{imm}, LSL #{shift} *)
PROCEDURE MovN*(r, imm, shift: INTEGER);
VAR n: INTEGER;
BEGIN
  ASSERT(imm MOD 10000H = imm);
  ASSERT((shift = 0) OR (shift = 16) OR (shift = 32) OR (shift = 48));

  (* 0x92800000 | (hw << 21) | (imm16 << 5) | Rd *)
  n := 12800000H + (shift DIV 16) * 200000H + imm * 20H + r;
  n := -7FFFFFFFH - 1 + n;

  DWord(n)
END MovN;

(** Load arbitrary LONGINT immediate into X-register.
    All paths use X-register (sf=1) encoding for correct 64-bit results.
    Compact paths (1–2 insns) for values whose upper 32 bits are uniform. *)
PROCEDURE MovImm*(r: INTEGER; val: LONGINT);
VAR q: LONGINT;
  v0, v1, v2, v3, zc, nc: INTEGER;
BEGIN
  v0 := M.SHORT(val MOD 10000H);
  q := val DIV 10000H;
  v1 := M.SHORT(q MOD 10000H);
  q := q DIV 10000H;
  v2 := M.SHORT(q MOD 10000H);
  q := q DIV 10000H;
  v3 := M.SHORT(q MOD 10000H);

  IF (v2 = 0) & (v3 = 0) THEN
    (* Upper 32 bits are 0: MOVZ + optional MOVK (1–2 insns) *)
    MovZ(r, v0, 0);
    IF v1 # 0 THEN MovK(r, v1, 16) END
  ELSIF (v2 = 0FFFFH) & (v3 = 0FFFFH) THEN
    (* Upper 32 bits are all 1s: MOVN + optional MOVK (1–2 insns) *)
    MovN(r, 0FFFFH - v0, 0);
    IF v1 # 0FFFFH THEN MovK(r, v1, 16) END
  ELSE
    (* General 64-bit: MOVZ/MOVN + up to 3x MOVK (2–4 insns) *)
    zc := 0; nc := 0;
    IF v0 = 0 THEN INC(zc) ELSIF v0 = 0FFFFH THEN INC(nc) END;
    IF v1 = 0 THEN INC(zc) ELSIF v1 = 0FFFFH THEN INC(nc) END;
    IF v2 = 0 THEN INC(zc) ELSIF v2 = 0FFFFH THEN INC(nc) END;
    IF v3 = 0 THEN INC(zc) ELSIF v3 = 0FFFFH THEN INC(nc) END;
    IF nc > zc THEN
      MovN(r, 0FFFFH - v0, 0);
      IF v1 # 0FFFFH THEN MovK(r, v1, 16) END;
      IF v2 # 0FFFFH THEN MovK(r, v2, 32) END;
      IF v3 # 0FFFFH THEN MovK(r, v3, 48) END
    ELSE
      MovZ(r, v0, 0);
      IF v1 # 0 THEN MovK(r, v1, 16) END;
      IF v2 # 0 THEN MovK(r, v2, 32) END;
      IF v3 # 0 THEN MovK(r, v3, 48) END
    END
  END
END MovImm;

(** MOV w{r}, #{imm} !FIXME unused, is it 16 bit or 32 bit? !TODO rename*)
PROCEDURE MovHImm*(r, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := (294H * 10000H + imm MOD 10000H) * 20H + r;
  (* Keep highest bit 0 for 32-bit operand *)
  DWord(n)
END MovHImm;

(** ADRP x{r}, page
    page is the intended target page offset from the start of the __text
    section (e.g. 2 to reach __DATA which sits two 4K pages after code).
    ARM64 ADRP encodes a PC-relative page offset, so we must subtract the
    page index of the current instruction within __text. Otherwise, as
    soon as generated code crosses a 4K boundary, all subsequent ADRP's
    would resolve to the wrong page (one off per crossed boundary). *)
PROCEDURE Adrp*(r, page: INTEGER);
VAR n, imm, immlo, immhi: INTEGER;
BEGIN
  imm := page - HereBytes() DIV 1000H;
  immlo := imm MOD 4;
  immhi := imm DIV 4 MOD 80000H;
  n := ((immlo * 20H + 10H) * 80000H + immhi) * 20H + r;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for op=ADRP *)
  DWord(n)
END Adrp;

(** ADR Xd, offset — PC-relative address. offset is in bytes. *)
PROCEDURE Adr*(rd, offset: INTEGER);
VAR immlo, immhi: INTEGER;
BEGIN
  immlo := offset MOD 4;
  immhi := offset DIV 4;
  DWord(((immlo * 20H + 10H) * 80000H + (immhi MOD 80000H)) * 20H + rd)
END Adr;

(** ADD/SUB immediate. *)
PROCEDURE AddImm*(r1, r2, imm: INTEGER);
VAR n, shift, op: INTEGER;
BEGIN
  IF imm < 0 THEN op := 0A2H; imm := -imm ELSE op := 22H END;
  IF (imm # 0) & (imm MOD 1000H = 0) THEN
    imm := imm DIV 1000H;
    shift := 1000H
  ELSE
    shift := 0
  END;
  ASSERT((0 <= imm) & (imm < 1000H));
  n := ((op * 2000H + shift + imm) * 20H + r2) * 20H + r1;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for sf=64bit *)
  DWord(n)
END AddImm;

(** STR w{r1}, [x{r2}] *)
PROCEDURE StrH*(r1, r2: INTEGER);
VAR n, Rm, option, S: INTEGER;
BEGIN
  Rm := 0;
  option := 0;
  S := 0;
  n := ((((1C8H * 20H + Rm) * 8 + option) * 2 + S) * 80H + r2) * 20H + r1;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit *)
  DWord(n)
END StrH;

(** SVC {a}, a is ignored for now. *)
PROCEDURE Svc*(a: INTEGER);
VAR w: INTEGER;
BEGIN
  w := -738197503; (* 0xD4000001 — do not fold via 54000001H under fob *)
  Files.WriteInt(codeR, w)
END Svc;

(** Generates code that terminates the program with exit code `code`. *)
PROCEDURE ExitCode*(code: INTEGER);
BEGIN
  MovImm(0, code);
  MovImm(16, 1);
  Svc(0)
END ExitCode;

(** STR* {rt}, [x{rn}, #{imm}]
     size must be 0..3 (1, 2, 4 or 8 bytes). *)
PROCEDURE StrImm*(rt, rn, imm, size: INTEGER);
VAR n: INTEGER;
BEGIN
  size := SizeToLog(size);
  ASSERT(LSL(ASR(imm, size), size) = imm); (* No bits will be left out *)

  imm := ASR(imm, size);
  ASSERT(imm MOD 1000H = imm);

  n := (size * 40H + 39H) * 1000000H + imm * 400H + rn * 20H + rt;
  DWord(n)
END StrImm;

(** LDR* {rt}, [x{rn}, #{imm}]
     size must be 0..3 (1, 2, 4 or 8 bytes). *)
PROCEDURE LdrImm*(rt, rn, imm, size: INTEGER);
VAR n: INTEGER;
BEGIN
  size := SizeToLog(size);
  ASSERT(LSL(ASR(imm, size), size) = imm); (* No bits will be left out *)

  imm := ASR(imm, size);
  ASSERT(imm MOD 1000H = imm);

  n := (size * 40H + 39H) * 1000000H + 400000H + imm * 400H + rn * 20H + rt;
  DWord(n)
END LdrImm;

(** LDR* {rt}, [x{rn}, x{rm}]
     Register offset load. size = 1, 2, 4 or 8 bytes. *)
PROCEDURE LdrReg*(rt, rn, rm, size: INTEGER);
VAR n: INTEGER;
BEGIN
  size := SizeToLog(size);
  (* LDR Xt, [Xn, Xm] = size:11 | 111000 | 01 | 1 | Rm | 011 | 0 | 10 | Rn | Rt *)
  n := (size * 40H + 38H) * 1000000H + 600000H + rm * 10000H + 6800H + rn * 20H + rt;
  DWord(n)
END LdrReg;

(** STR* {rt}, [x{rn}, x{rm}]
     Register offset store. size = 1, 2, 4 or 8 bytes. *)
PROCEDURE StrReg*(rt, rn, rm, size: INTEGER);
VAR n: INTEGER;
BEGIN
  size := SizeToLog(size);
  (* STR Xt, [Xn, Xm] = size:11 | 111000 | 00 | 1 | Rm | 011 | 0 | 10 | Rn | Rt *)
  n := (size * 40H + 38H) * 1000000H + 200000H + rm * 10000H + 6800H + rn * 20H + rt;
  DWord(n)
END StrReg;

(** ADD x{rd}, x{rn}, x{rm}, LSL #{shift} *)
PROCEDURE AddLsl*(rd, rn, rm, shift: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 0BH * 1000000H + rm * 10000H + shift * 400H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for sf=64bit *)
  DWord(n)
END AddLsl;

(** ADD x{rd}, x{rn}, x{rm} *)
PROCEDURE Add*(rd, rn, rm: INTEGER);
BEGIN AddLsl(rd, rn, rm, 0)
END Add;

(** SUB x{rd}, x{rn}, x{rm} *)
PROCEDURE Sub*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 4BH * 1000000H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for sf=64bit *)
  DWord(n)
END Sub;

(** NEG x{rd}, x{rm} - encoded as SUB x{rd}, xzr, x{rm} *)
PROCEDURE Neg*(rd, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 4BH * 1000000H + rm * 10000H + 1FH * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit → 0xCB000000 *)
  DWord(n)
END Neg;

(** MUL x{rd}, x{rn}, x{rm} - encoded as MADD x{rd}, x{rn}, x{rm}, xzr *)
PROCEDURE Mul*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 1BH * 1000000H + rm * 10000H + 1FH * 400H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit → 0x9B000000 *)
  DWord(n)
END Mul;

(** MADD x{rd}, x{rn}, x{rm}, x{ra} — rd := ra + rn * rm *)
PROCEDURE Madd*(rd, rn, rm, ra: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 1BH * 1000000H + rm * 10000H + ra * 400H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Madd;

(** SDIV x{rd}, x{rn}, x{rm} *)
PROCEDURE Div*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 1AC00C00H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit → 0x9AC00C00 *)
  DWord(n)
END Div;

(** MSUB x{rd}, x{rn}, x{rm}, x{ra} - rd := ra - rn * rm *)
PROCEDURE Msub*(rd, rn, rm, ra: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 1B008000H + rm * 10000H + ra * 400H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit → 0x9B008000 *)
  DWord(n)
END Msub;

(** CMP x{rn}, #{imm}. *)
PROCEDURE CmpImm*(rn, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  ASSERT(imm MOD 1000H = imm);
  n := 71000000H + imm * 400H + rn * 20H + 1FH;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit → 0xF1000000 *)
  DWord(n)
END CmpImm;

(** CMP x{rn}, x{rm} - encoded as SUBS xzr, x{rn}, x{rm} *)
PROCEDURE Cmp*(rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 6BH * 1000000H + rm * 10000H + rn * 20H + 1FH;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit → 0xEB000000 *)
  DWord(n)
END Cmp;

(** MOV x{rd}, x{rn} - encoded as ADD x{rd}, x{rn}, #0 *)
PROCEDURE Mov*(rd, rn: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 11000000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit *)
  DWord(n)
END Mov;

(** Random-access read of a 4-byte instruction from codeFile.
    pos is the word offset. *)
PROCEDURE ReadWord*(pos: INTEGER): INTEGER;
VAR r: Files.Rider;
  b0, b1, b2, b3: BYTE;
BEGIN
  Files.Set(r, codeFile, pos * 4);
  Files.Read(r, b0); Files.Read(r, b1);
  Files.Read(r, b2); Files.Read(r, b3);
  RETURN b0 + b1 * 100H + b2 * 10000H + b3 * 1000000H
END ReadWord;

(** Random-access write of a 4-byte instruction to codeFile.
    pos is the word offset. *)
PROCEDURE WriteWord*(pos, instr: INTEGER);
VAR r: Files.Rider;
BEGIN
  Files.Set(r, codeFile, pos * 4);
  Files.Write(r, instr MOD 100H);
  Files.Write(r, instr DIV 100H  MOD 100H);
  Files.Write(r, instr DIV 10000H  MOD 100H);
  Files.Write(r, instr DIV 1000000H MOD 100H)
END WriteWord;

(** Emit B.cond with a signed word offset (for CBJump).
    cond   = ARM64 condition code (0..15).
    offset = word offset of previous list head (0 = none), stored as imm19. *)
PROCEDURE BCond*(cond, offset: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 54000000H + (offset MOD 80000H) * 20H + cond;
  DWord(n)
END BCond;

(** Emit unconditional B (branch) with a real signed word offset. *)
PROCEDURE B*(offset: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 14000000H + (offset MOD 4000000H);
  DWord(n)
END B;

(** Backpatch unconditional B at word position pos to jump to target. *)
PROCEDURE PatchB*(pos, target: INTEGER);
VAR imm26: INTEGER;
BEGIN
  imm26 := target - pos;
  WriteWord(pos, 14000000H + (imm26 MOD 4000000H))
END PatchB;

(** Returns the sign-extended immediate 19-bit value stored
    in B.Cond instruction.
    pos = offset (in words) of the instruction. *)
PROCEDURE ImmFromBCond*(pos: INTEGER): INTEGER;
VAR instr, imm19: INTEGER;
BEGIN
  instr := ReadWord(pos);
  imm19 := (instr DIV 20H) MOD 80000H;
  IF imm19 >= 40000H THEN DEC(imm19, 80000H) END (* sign-extend 19 bits *)
RETURN imm19 END ImmFromBCond;

(** Backpatches B.cond at pos by rewriting imm19 with (target - pos),
    preserving cond. *)
PROCEDURE PatchBCond*(pos, target: INTEGER);
VAR instr, cond, imm19: INTEGER;
BEGIN
  instr := ReadWord(pos);
  cond  := instr MOD 10H;
  imm19 := target - pos;
  WriteWord(pos, 54000000H + (imm19 MOD 80000H) * 20H + cond)
END PatchBCond;

(** STP Xt1, Xt2, [Xn, #imm]! — Store Pair, pre-index.
    imm must be a multiple of 8. *)
PROCEDURE Stp*(rt1, rt2, rn, imm: INTEGER);
VAR imm7, n: INTEGER;
BEGIN
  imm7 := imm DIV 8;
  n := 29800000H + (imm7 MOD 80H) * 8000H + rt2 * 400H + rn * 20H + rt1;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Stp;

(** LDP Xt1, Xt2, [Xn], #imm — Load Pair, post-index.
    imm must be a multiple of 8. *)
PROCEDURE Ldp*(rt1, rt2, rn, imm: INTEGER);
VAR imm7, n: INTEGER;
BEGIN
  imm7 := imm DIV 8;
  n := 28C00000H + (imm7 MOD 80H) * 8000H + rt2 * 400H + rn * 20H + rt1;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Ldp;

(** LDP Xt1, Xt2, [Xn, #{imm}] — offset, base unchanged. imm is a multiple of 8. *)
(** BL offset — Branch with Link. offset is a signed word offset. *)
PROCEDURE Bl*(offset: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 14000000H + (offset MOD 4000000H);
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Bl;

(** Backpatch BL at word position pos to jump to target. *)
PROCEDURE PatchBl*(pos, target: INTEGER);
VAR imm26: INTEGER;
BEGIN
  imm26 := target - pos;
  WriteWord(pos, -7FFFFFFFH - 1 + 14000000H + (imm26 MOD 4000000H))
END PatchBl;

(** Returns the sign-extended immediate 26-bit value stored in BL
    instruction at word position pos. Used to walk a fixup chain whose
    links are encoded in the BL's own imm26 field. *)
PROCEDURE ImmFromBl*(pos: INTEGER): INTEGER;
VAR instr, imm26: INTEGER;
BEGIN
  instr := ReadWord(pos);
  imm26 := instr MOD 4000000H;
  IF imm26 >= 2000000H THEN DEC(imm26, 4000000H) END (* sign-extend 26 bits *)
RETURN imm26 END ImmFromBl;

(** RET — Return to address in x30 (LR). *)
PROCEDURE Ret*;
BEGIN
  DWord(565F03C0H + (-7FFFFFFFH - 1)) (* 0xD65F03C0 *)
END Ret;

(** BLR Xn — Branch with Link to Register. *)
PROCEDURE Blr*(rn: INTEGER);
BEGIN
  (* BLR Xn = 0xD63F0000 | (Rn << 5) *)
  DWord(563F0000H + rn * 20H + (-7FFFFFFFH - 1))
END Blr;

PROCEDURE Sxtb*(rd, rn: INTEGER);
VAR n: INTEGER;
BEGIN
  (* SXTB Xd, Wn = SBFM Xd, Xn, #0, #7 *)
  n := 13401C00H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Sxtb;

PROCEDURE Sxth*(rd, rn: INTEGER);
VAR n: INTEGER;
BEGIN
  (* SXTH Xd, Wn = SBFM Xd, Xn, #0, #15: sign-extend 16→64 bit
     Encoding: 0x93403C00 | (Rn << 5) | Rd *)
  n := 13403C00H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Sxth;

PROCEDURE Sxtw*(rd, rn: INTEGER);
VAR n: INTEGER;
BEGIN
  (* SXTW Xd, Wn = SBFM Xd, Xn, #0, #31: sign-extend 32→64 bit
     Encoding: 0x93407C00 | (Rn << 5) | Rd *)
  n := 13407C00H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Sxtw;

PROCEDURE CSNeg*(rd, rn, rm, cond: INTEGER);
VAR n: INTEGER;
BEGIN
  (* CSNEG Xd, Xn, Xm, cond: Rd = (cond) ? Rn : -Rm
     Encoding: 1 1 0 | 11010100 | Rm[20:16] | cond[15:12] | 01 | Rn[9:5] | Rd[4:0] *)
  n := 5A800400H + rm * 10000H + cond * 1000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END CSNeg;

(** AND X{rd}, X{rn}, #1
     Generic AndImm is not used, because it is a tricky instruction. *)
PROCEDURE AndImm1*(rd, rn: INTEGER);
VAR n: INTEGER;
BEGIN
  (* AND Xd, Xn, #1
     Encoding: 1 00100100 1 000000 000000 Rn[9:5] Rd[4:0] = 0x92400000 | Rn<<5 | Rd *)
  n := 12400000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END AndImm1;

(** ASR x{rd}, x{rn}, #{shift} — arithmetic shift right immediate *)
PROCEDURE AsrImm*(rd, rn, shift: INTEGER);
VAR n: INTEGER;
BEGIN
  (* SBFM Xd, Xn, #shift, #63
     Encoding: 0x9340FC00 | (shift << 16) | (Rn << 5) | Rd *)
  n := 1340FC00H + shift * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END AsrImm;

(** ASRV x{rd}, x{rn}, x{rm} — arithmetic shift right *)
PROCEDURE Asr*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 1AC02800H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Asr;

(** LSLV x{rd}, x{rn}, x{rm} — logical shift left *)
PROCEDURE Lsl*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 1AC02000H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Lsl;

(** RORV x{rd}, x{rn}, x{rm} — rotate right *)
PROCEDURE Ror*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 1AC02C00H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Ror;

(** ORR x{rd}, x{rn}, x{rm} — bitwise OR *)
PROCEDURE Orr*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 2A000000H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* 0xAA000000 *)
  DWord(n)
END Orr;

(** AND x{rd}, x{rn}, x{rm} — bitwise AND *)
PROCEDURE And*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 0A000000H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* 0x8A000000 *)
  DWord(n)
END And;

(** EOR x{rd}, x{rn}, x{rm} — bitwise XOR *)
PROCEDURE Eor*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 4A000000H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* 0xCA000000 *)
  DWord(n)
END Eor;

(** BIC x{rd}, x{rn}, x{rm} — bitwise AND NOT (bit clear) *)
PROCEDURE Bic*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 0A200000H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* 0x8A200000 *)
  DWord(n)
END Bic;

(** MVN x{rd}, x{rm} — bitwise NOT, encoded as ORN xd, xzr, xm *)
PROCEDURE Mvn*(rd, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 2A200000H + rm * 10000H + 1FH * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* 0xAA200000 *)
  DWord(n)
END Mvn;

(** TST x{rn}, x{rm} — test bits, encoded as ANDS xzr, xrn, xrm *)
PROCEDURE Tst*(rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 6A000000H + rm * 10000H + rn * 20H + 1FH;
  n := -7FFFFFFFH - 1 + n; (* 0xEA000000 *)
  DWord(n)
END Tst;

(** ---- Floating-point instructions (single-precision) ---- *)

(** FADD Sd, Sn, Sm *)
PROCEDURE FAdd*(fd, fn, fm: INTEGER);
BEGIN DWord(1E202800H + fm * 10000H + fn * 20H + fd)
END FAdd;

(** FSUB Sd, Sn, Sm *)
PROCEDURE FSub*(fd, fn, fm: INTEGER);
BEGIN DWord(1E203800H + fm * 10000H + fn * 20H + fd)
END FSub;

(** FMUL Sd, Sn, Sm *)
PROCEDURE FMul*(fd, fn, fm: INTEGER);
BEGIN DWord(1E200800H + fm * 10000H + fn * 20H + fd)
END FMul;

(** FDIV Sd, Sn, Sm *)
PROCEDURE FDiv*(fd, fn, fm: INTEGER);
BEGIN DWord(1E201800H + fm * 10000H + fn * 20H + fd)
END FDiv;

(** FCMP Sn, Sm — sets NZCV flags *)
PROCEDURE FCmp*(fn, fm: INTEGER);
BEGIN DWord(1E202000H + fm * 10000H + fn * 20H)
END FCmp;

(** FNEG Sd, Sn *)
PROCEDURE FNeg*(fd, fn: INTEGER);
BEGIN DWord(1E214000H + fn * 20H + fd)
END FNeg;

(** SCVTF Sd, Wn — signed 32-bit integer to single-precision float *)
PROCEDURE Scvtf*(fd, rn: INTEGER);
BEGIN DWord(1E220000H + rn * 20H + fd)
END Scvtf;

(** FCVTZS Wd, Sn — single-precision float to signed 32-bit integer *)
PROCEDURE Fcvtzs*(rd, fn: INTEGER);
BEGIN DWord(1E380000H + fn * 20H + rd)
END Fcvtzs;

(** FCVTMS Wd, Sn — single-precision float to signed 32-bit integer,
    rounding toward minus infinity *)
PROCEDURE Fcvtms*(rd, fn: INTEGER);
BEGIN DWord(1E300000H + fn * 20H + rd)
END Fcvtms;

(** FCVTMS Wd, Dn — double to signed 32-bit integer, round toward -inf *)
PROCEDURE FcvtmsWfromD*(rd, fn: INTEGER);
BEGIN DWord(1E700000H + fn * 20H + rd)
END FcvtmsWfromD;

(** CSINC Xd, Xn, Xm, cond — Rd = (cond) ? Rn : Rm+1
    Used as CSET Xd, cond via CSINC Xd, xzr, xzr, Negated(cond) *)
PROCEDURE CSInc*(rd, rn, rm, cond: INTEGER);
VAR n: INTEGER;
BEGIN
  (* CSINC Xd, Xn, Xm, cond
     Encoding: 1 0 0 11010100 Rm[20:16] cond[15:12] 01 Rn[9:5] Rd[4:0]
     = 0x9A800400 | Rm<<16 | cond<<12 | Rn<<5 | Rd *)
  n := 1A800400H + rm * 10000H + cond * 1000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END CSInc;

(** ADCS Wd, Wn, Wm — add with carry, sets flags *)
PROCEDURE Adcs*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 3AH * 1000000H + rm * 10000H + rn * 20H + rd;
  DWord(n)
END Adcs;

(** SBCS Wd, Wn, Wm — subtract with borrow, sets flags *)
PROCEDURE Sbcs*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 7AH * 1000000H + rm * 10000H + rn * 20H + rd;
  DWord(n)
END Sbcs;

(** UMULL Xd, Wn, Wm — unsigned multiply, low 32 bits in Wd *)
PROCEDURE Umull*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 9BA08000H + rm * 10000H + SP * 400H + rn * 20H + rd;
  DWord(n)
END Umull;

(** BRK #imm16 — breakpoint trap *)
PROCEDURE Brk*(imm: INTEGER);
BEGIN
  DWord(0D4200000H + (imm MOD 10000H) * 20H)
END Brk;

(** CBZ Xn, offset — compare and branch if zero *)
PROCEDURE Cbz*(rn, offset: INTEGER);
VAR n: INTEGER;
BEGIN
  (* CBZ Xt, label: 1 011010 0 imm19 Rt
     = 0xB4000000 | (imm19<<5) | Rt *)
  n := 34000000H + (offset MOD 80000H) * 20H + rn;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END Cbz;

(** TBZ Xn, #bit, offset — test bit and branch if zero *)
PROCEDURE Tbz*(rn, bit, offset: INTEGER);
VAR n, b5, b40: INTEGER;
BEGIN
  (* TBZ b5 0110110 b40 imm14 Rt *)
  b5 := bit DIV 32;
  b40 := bit MOD 32;
  n := 36000000H + b5 * 80000000H + b40 * 80000H + (offset MOD 4000H) * 20H + rn;
  DWord(n)
END Tbz;

(** FMOV Sd, Wn — move bits from GPR to FPR *)
PROCEDURE FMovWtoS*(fd, rn: INTEGER);
BEGIN DWord(1E270000H + rn * 20H + fd)
END FMovWtoS;

(** FMOV Wd, Sn — move bits from FPR to GPR *)
PROCEDURE FMovStoW*(rd, fn: INTEGER);
BEGIN DWord(1E260000H + fn * 20H + rd)
END FMovStoW;

(** FMOV Sd, Sn — move single-precision float between FPRs *)
PROCEDURE FMovS*(fd, fn: INTEGER);
BEGIN DWord(1E204000H + fn * 20H + fd)
END FMovS;

(** LDR St, [Xn, #imm] — load single-precision float from memory *)
PROCEDURE FLdrImm*(ft, rn, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  imm := imm DIV 4;
  ASSERT(imm MOD 1000H = imm);
  n := 3D400000H + imm * 400H + rn * 20H + ft;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END FLdrImm;

(** STR St, [Xn, #imm] — store single-precision float to memory *)
PROCEDURE FStrImm*(ft, rn, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  imm := imm DIV 4;
  ASSERT(imm MOD 1000H = imm);
  n := 3D000000H + imm * 400H + rn * 20H + ft;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END FStrImm;

PROCEDURE DAdd*(fd, fn, fm: INTEGER);
BEGIN DWord(1E602800H + fm * 10000H + fn * 20H + fd)
END DAdd;

PROCEDURE DSub*(fd, fn, fm: INTEGER);
BEGIN DWord(1E603800H + fm * 10000H + fn * 20H + fd)
END DSub;

PROCEDURE DMul*(fd, fn, fm: INTEGER);
BEGIN DWord(1E600800H + fm * 10000H + fn * 20H + fd)
END DMul;

PROCEDURE DDiv*(fd, fn, fm: INTEGER);
BEGIN DWord(1E601800H + fm * 10000H + fn * 20H + fd)
END DDiv;

PROCEDURE DCmp*(fn, fm: INTEGER);
BEGIN DWord(1E602000H + fm * 10000H + fn * 20H)
END DCmp;

PROCEDURE DNeg*(fd, fn: INTEGER);
BEGIN DWord(1E614000H + fn * 20H + fd)
END DNeg;

PROCEDURE ScvtfD*(fd, rn: INTEGER);
BEGIN DWord(9E620000H + rn * 20H + fd)
END ScvtfD;

PROCEDURE FcvtmsD*(rd, fn: INTEGER);
BEGIN DWord(9E700000H + fn * 20H + rd)
END FcvtmsD;

PROCEDURE FcvtSD*(fd, fn: INTEGER);
BEGIN DWord(1E22C000H + fn * 20H + fd)
END FcvtSD;

PROCEDURE FcvtDS*(fd, fn: INTEGER);
BEGIN DWord(1E624000H + fn * 20H + fd)
END FcvtDS;

PROCEDURE FMovXtoD*(fd, rn: INTEGER);
BEGIN DWord(9E670000H + rn * 20H + fd)
END FMovXtoD;

PROCEDURE FMovDtoX*(rd, fn: INTEGER);
BEGIN DWord(9E660000H + fn * 20H + rd)
END FMovDtoX;

PROCEDURE FMovD*(fd, fn: INTEGER);
BEGIN DWord(1E604000H + fn * 20H + fd)
END FMovD;

PROCEDURE DLdrImm*(ft, rn, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  imm := imm DIV 8;
  ASSERT(imm MOD 1000H = imm);
  n := 7D400000H + imm * 400H + rn * 20H + ft;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END DLdrImm;

PROCEDURE DStrImm*(ft, rn, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  imm := imm DIV 8;
  ASSERT(imm MOD 1000H = imm);
  n := 7C000000H + imm * 400H + rn * 20H + ft;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END DStrImm;

(** Emit placeholder BL; importIdx indexes importNames, procName for linker. *)
PROCEDURE CallExt*(importIdx: INTEGER; procName: ARRAY OF CHAR);
BEGIN
  IF extCallRelocN < maxExtCallReloc THEN
    extCallRelocOff[extCallRelocN] := Here();
    extCallRelocImp[extCallRelocN] := importIdx;
    Strings.Copy(procName, extCallRelocName[extCallRelocN]);
    INC(extCallRelocN)
  END;
  DWord(14000000H + (-7FFFFFFFH - 1)) (* BL with imm26 = 0; linker patches *)
END CallExt;

PROCEDURE LoadStringAddr*(reg, strIdx: INTEGER);
VAR pos: INTEGER;
BEGIN
  IF strRelocN < maxStrReloc THEN
    pos := Here();
    Adrp(reg, 0);
    AddImm(reg, reg, 0);
    strRelocOff[strRelocN] := pos;
    strRelocIdx[strRelocN] := strIdx;
    INC(strRelocN)
  END
END LoadStringAddr;

(** Emit ADRP+ADD placeholders for own __DATA page (linker patches both). *)
PROCEDURE LoadDataPage*(reg: INTEGER);
VAR pos: INTEGER;
BEGIN
  pos := Here();
  Adrp(reg, 0);
  AddImm(reg, reg, 0);
  IF dataPageRelocN < maxDataPageReloc THEN
    dataPageRelocOff[dataPageRelocN] := pos;
    INC(dataPageRelocN)
  END
END LoadDataPage;

(** Emit ADRP+ADD for imported __DATA; importIdx indexes importNames. *)
PROCEDURE LoadExtDataPage*(reg, importIdx: INTEGER);
VAR pos: INTEGER;
BEGIN
  pos := Here();
  Adrp(reg, 0);
  AddImm(reg, reg, 0);
  IF impDataPageRelocN < maxDataPageReloc THEN
    impDataPageRelocOff[impDataPageRelocN] := pos;
    impDataPageRelocImp[impDataPageRelocN] := importIdx;
    INC(impDataPageRelocN)
  END
END LoadExtDataPage;

PROCEDURE SetCompileFlags*(flags: INTEGER);
BEGIN compileFlags := flags END SetCompileFlags;

PROCEDURE Open*(name: ARRAY OF CHAR);
VAR s: ARRAY 256 OF CHAR;
BEGIN
  codeFile := Files.New('');
  Files.Set(codeR, codeFile, 0);

  Strings.Copy(name, modName);
  entryWordOffset := 0;
  varSize := 0;
  strRelocN := 0;
  dataPageRelocN := 0;
  impDataPageRelocN := 0;
  importN := 0;
  exportN := 0;
  extCallRelocN := 0;

  Strings.Copy(M.outDir, s);
  Strings.Append(name, s);Strings.Append('.obj', s);
  outFile := Files.New(s);
  IF outFile # NIL THEN
    Files.Set(outR, outFile, 0);
    Files.WriteInt(outR, fileMark);
    Files.WriteInt(outR, 0) (* placeholder for entry byte offset *)
  ELSE M.WriteErrorS(E.cantCreateFile, s)
  END
END Open;

(** Record module init proc offset in words. *)
PROCEDURE SetEntry*(offsetInWords: INTEGER);
BEGIN entryWordOffset := offsetInWords
END SetEntry;

PROCEDURE SetVarSize*(bytes: INTEGER);
BEGIN varSize := bytes
END SetVarSize;

(** Add imported module name. Returns its import index. *)
PROCEDURE AddImport*(name: ARRAY OF CHAR): INTEGER;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i < importN) & (importNames[i] # name) DO INC(i) END;
  IF (i = importN) & (importN < maxImports) THEN
    Strings.Copy(name, importNames[importN]);
    INC(importN)
  END
RETURN i END AddImport;

(** Record export; isCmd FALSE (0) = procedure, TRUE (1) = command. *)
PROCEDURE AddExport*(name: ARRAY OF CHAR; offWords: INTEGER; isCmd: BOOLEAN);
BEGIN
  IF exportN < maxExports THEN
    Strings.Copy(name, exportNames[exportN]);
    exportOff[exportN] := offWords;
    exportIsCmd[exportN] := isCmd;
    INC(exportN)
  END
END AddExport;

PROCEDURE Init*;
BEGIN
END Init;

(** Write NUL-terminated UTF-8 string. *)
PROCEDURE WriteCStr(VAR R: Files.Rider; s: ARRAY OF CHAR);
VAR zero: BYTE;
BEGIN
  Files.WriteString(R, s);
  zero := 0; Files.Write(R, zero)
END WriteCStr;

PROCEDURE CopyAll(VAR R, dst: Files.Rider; src: Files.File);
VAR x: BYTE;
BEGIN
  Files.Set(R, src, 0);
  Files.Read(R, x);
  WHILE ~R.eof DO Files.Write(dst, x); Files.Read(R, x) END
END CopyAll;

(** Writes .obj: header, meta, code, strpool, str/data/extCall/impData relocs. *)
PROCEDURE Close*;
VAR srcR: Files.Rider;
  codeLen, strpLen, strRelocLen, dataPageRelocLen, metaLen, extCallRelocLen, impDataPageRelocLen, i: INTEGER;
  startPos: INTEGER;
BEGIN
  codeLen := Files.Length(codeFile);

  Files.Set(outR, outFile, 0);
  WHILE Files.Pos(outR) < objHeaderBytes DO Files.Write(outR, 0) END;

  startPos := Files.Pos(outR);
  WriteCStr(outR, modName);
  Files.WriteInt(outR, varSize);
  Files.WriteInt(outR, importN);
  i := 0;
  WHILE i < importN DO WriteCStr(outR, importNames[i]); INC(i) END;
  Files.WriteInt(outR, exportN);
  i := 0;
  WHILE i < exportN DO
    WriteCStr(outR, exportNames[i]);
    Files.WriteInt(outR, exportOff[i]);
    Files.Write(outR, ORD(exportIsCmd[i]));
    INC(i)
  END;
  metaLen := Files.Pos(outR) - startPos;

  CopyAll(srcR, outR, codeFile);

  startPos := Files.Pos(outR);
  ST.WriteStrpSection(outR);
  strpLen := Files.Pos(outR) - startPos;

  startPos := Files.Pos(outR);
  Files.WriteInt(outR, strRelocN);
  i := 0;
  WHILE i < strRelocN DO
    Files.WriteInt(outR, strRelocOff[i]);
    Files.WriteInt(outR, strRelocIdx[i]);
    INC(i)
  END;
  strRelocLen := Files.Pos(outR) - startPos;

  startPos := Files.Pos(outR);
  Files.WriteInt(outR, dataPageRelocN);
  i := 0;
  WHILE i < dataPageRelocN DO
    Files.WriteInt(outR, dataPageRelocOff[i]);
    INC(i)
  END;
  dataPageRelocLen := Files.Pos(outR) - startPos;

  startPos := Files.Pos(outR);
  Files.WriteInt(outR, extCallRelocN);
  i := 0;
  WHILE i < extCallRelocN DO
    Files.WriteInt(outR, extCallRelocOff[i]);
    Files.WriteInt(outR, extCallRelocImp[i]);
    WriteCStr(outR, extCallRelocName[i]);
    INC(i)
  END;
  extCallRelocLen := Files.Pos(outR) - startPos;

  startPos := Files.Pos(outR);
  Files.WriteInt(outR, impDataPageRelocN);
  i := 0;
  WHILE i < impDataPageRelocN DO
    Files.WriteInt(outR, impDataPageRelocOff[i]);
    Files.WriteInt(outR, impDataPageRelocImp[i]);
    INC(i)
  END;
  impDataPageRelocLen := Files.Pos(outR) - startPos;

  Files.Set(outR, outFile, 0);
  Files.WriteInt(outR, fileMark);
  Files.WriteInt(outR, entryWordOffset);
  Files.WriteInt(outR, codeLen);
  Files.WriteInt(outR, strpLen);
  Files.WriteInt(outR, strRelocLen);
  Files.WriteInt(outR, dataPageRelocLen);
  Files.WriteInt(outR, metaLen);
  Files.WriteInt(outR, extCallRelocLen);
  Files.WriteInt(outR, impDataPageRelocLen);
  Files.WriteInt(outR, compileFlags);

  Files.Register(outFile)
END Close;

END Generator.
