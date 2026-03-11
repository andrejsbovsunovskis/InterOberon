MODULE Generator;
IMPORT Strings, Files, M := Machine, E := ErrorMsg;

CONST
  (** Output RISC machine code marks **)
  version = 1;
  (** Machine code file mark (first 4 bytes of .obj file) *)
  fileMark = ORD('A') + 256 * (ORD('R') + 256 * (ORD('M') + 256 * version));

  (** Special registers **)
  SP* = 31; (** Stack pointer register *)

VAR
  outFile: Files.File; (** Output file *)
  outR: Files.Rider;

  codeFile: Files.File; (** Temporary file (buffer) for machine code output *)
  codeR: Files.Rider;

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

  n := (794H * 10000H + (shift DIV 16) * 200000H + imm) * 20H + r;
  n := -7FFFFFFFH - 1 + n;

  DWord(n)
END MovK;

(** MOVZ x{r}, #{imm}, LSL #{shift} *)
PROCEDURE MovZ*(r, imm, shift: INTEGER);
VAR n: INTEGER;
BEGIN
  ASSERT(imm MOD 10000H = imm);
  ASSERT((shift = 0) OR (shift = 16) OR (shift = 32) OR (shift = 48));

  n := (294H * 10000H + (shift DIV 16) * 200000H + imm) * 20H + r;
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

(** MOV w{r}, #{imm}
     Load arbitrary 32-bit immediate into W register. *)
PROCEDURE MovImm*(r, imm: INTEGER);
VAR w0, w1, zc, nc: INTEGER;
BEGIN
  w0 := imm MOD 10000H;
  w1 := ASR(imm, 16) MOD 10000H;

  zc := 0; nc := 0;
  IF w0 = 0 THEN INC(zc) ELSIF w0 = 0FFFFH THEN INC(nc) END;
  IF w1 = 0 THEN INC(zc) ELSIF w1 = 0FFFFH THEN INC(nc) END;

  IF nc > zc THEN (* start from all ones *)
    MovN(r, 0FFFFH - w0, 0);
    IF w1 # 0FFFFH THEN MovK(r, w1, 16) END
  ELSE (* start from all zeros *)
    MovZ(r, w0, 0);
    IF w1 # 0 THEN MovK(r, w1, 16) END
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

(** ADRP w{r}, #{imm} *)
PROCEDURE Adrp*(r, imm: INTEGER);
VAR n, immlo, immhi: INTEGER;
BEGIN
  immlo := imm MOD 4;
  immhi := imm DIV 4;
  n := ((immlo * 20H + 10H) * 80000H + immhi) * 20H + r;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for op=ADRP *)
  DWord(n)
END Adrp;

(** ADD x{r1}, x{r2}, #{imm} *)
PROCEDURE AddImm*(r1, r2, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  ASSERT(imm MOD 1000H = imm);
  n := ((22H * 2000H + imm) * 20H + r2) * 20H + r1;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for sf=64bit *)
  DWord(n)
END AddImm;

(** SUB x{r1}, x{r2}, #{imm} *)
PROCEDURE SubImm*(r1, r2, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  ASSERT(imm MOD 1000H = imm);
  n := ((0A2H * 2000H + imm) * 20H + r2) * 20H + r1;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for sf=64bit *)
  DWord(n)
END SubImm;

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
VAR n: INTEGER;
BEGIN
  n := 54000001H;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit *)
  DWord(n)
END Svc;

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

(** ADD x{rd}, x{rn}, x{rm} *)
PROCEDURE Add*(rd, rn, rm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 0BH * 1000000H + rm * 10000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for sf=64bit *)
  DWord(n)
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

(** CMP x{rn}, #{imm} - encoded as SUBS xzr, x{rn}, #{imm} *)
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

(** Random-access read of a 4-byte instruction from codeFile. *)
PROCEDURE ReadWord*(pos: INTEGER): INTEGER;
VAR r: Files.Rider;
  b0, b1, b2, b3: BYTE;
BEGIN
  Files.Set(r, codeFile, pos);
  Files.Read(r, b0); Files.Read(r, b1);
  Files.Read(r, b2); Files.Read(r, b3);
  RETURN b0 + b1 * 100H + b2 * 10000H + b3 * 1000000H
END ReadWord;

(** Random-access write of a 4-byte instruction to codeFile. *)
PROCEDURE WriteWord*(pos, instr: INTEGER);
VAR r: Files.Rider;
BEGIN
  Files.Set(r, codeFile, pos);
  Files.Write(r, instr MOD 100H);
  Files.Write(r, instr DIV 100H  MOD 100H);
  Files.Write(r, instr DIV 10000H  MOD 100H);
  Files.Write(r, instr DIV 1000000H MOD 100H)
END WriteWord;

(** Emit B.cond as a linked-list node.
    cond     = ARM64 condition code (0..15).
    listPrev = byte offset of previous list head (0 = none), stored as imm19.
    Returns byte offset of this instruction (use as new list head). *)
PROCEDURE BCond*(cond, listPrev: INTEGER): INTEGER;
VAR here, n: INTEGER;
BEGIN
  here := Files.Pos(codeR);
  n := 54000000H + (listPrev DIV 4 MOD 80000H) * 20H + cond;
  DWord(n);
  RETURN here
END BCond;

(** Emit B.cond with a real signed instruction-word offset (for CBJump). *)
PROCEDURE BCondReal*(cond, offset: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 54000000H + (offset MOD 80000H) * 20H + cond;
  DWord(n)
END BCondReal;

(** Emit unconditional B with a real signed instruction-word offset. *)
PROCEDURE B*(offset: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 14000000H + (offset MOD 4000000H);
  DWord(n)
END B;

(** Backpatch B.cond at pos: rewrite imm19 with (target-pos)/4, preserve cond. *)
PROCEDURE PatchBCond*(pos, target: INTEGER);
VAR instr, cond, imm19: INTEGER;
BEGIN
  instr := ReadWord(pos);
  cond  := instr MOD 10H;
  imm19 := (target - pos) DIV 4;
  WriteWord(pos, 54000000H + (imm19 MOD 80000H) * 20H + cond)
END PatchBCond;

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

PROCEDURE Here*(): INTEGER;
RETURN Files.Pos(codeR) END Here;

PROCEDURE Init*;
BEGIN
END Init;

PROCEDURE Open*(modName: ARRAY OF CHAR);
VAR s: ARRAY 256 OF CHAR;
BEGIN
  codeFile := Files.New('');
  Files.Set(codeR, codeFile, 0);

  Strings.Copy(modName, s); Strings.Append('.obj', s);
  outFile := Files.New(s);
  IF outFile # NIL THEN
    Files.Set(outR, outFile, 0);
    Files.WriteInt(outR, fileMark)
  ELSE M.WriteErrorS(E.cantCreateFile, s)
  END
END Open;

PROCEDURE Close*;
VAR R: Files.Rider;
  x: BYTE;
BEGIN
  Files.Set(R, codeFile, 0);
  Files.Read(R, x);
  WHILE ~R.eof DO
    Files.Write(outR, x);
    Files.Read(R, x)
  END;
  Files.Register(outFile)
END Close;

END Generator.
