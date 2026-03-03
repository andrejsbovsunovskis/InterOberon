MODULE Generator;
IMPORT Strings, Files, M := Machine, E := ErrorMsg;

CONST
  (** Output RISC machine code marks **)
  version = 1;
  (** Machine code file mark (first 4 bytes of .obj file) *)
  fileMark = ORD('A') + 256 * (ORD('R') + 256 * (ORD('M') + 256 * version));

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

(** Generates code that terminates the program. *)
PROCEDURE Exit*;
BEGIN
  Word(00000H); Word(0D280H);
  Word(00030H); Word(0D280H);
  Word(00001H); Word(0D400H)
END Exit;

(** MOV x{r}, #{imm} *)
PROCEDURE MovImm*(r, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := (294H * 10000H + imm MOD 10000H) * 20H + r;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for 64-bit *)
  DWord(n)
END MovImm;

(** MOV w{r}, #{imm} *)
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

(** MOV x{r1}, x{r2}, #{imm} *)
PROCEDURE AddImm*(r1, r2, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := ((22H * 2000H + imm MOD 1000H) * 20H + r2) * 20H + r1;
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
VAR n: INTEGER;
BEGIN
  n := 54000001H;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit *)
  DWord(n)
END Svc;

(** SUB SP, SP, #{imm} *)
PROCEDURE SubImmSP*(imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 51000000H + imm * 400H + 3FFH;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END SubImmSP;

(** ADD SP, SP, #{imm} *)
PROCEDURE AddImmSP*(imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 11000000H + imm * 400H + 3FFH;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END AddImmSP;

(** STRB w{rt}, [x{rn}, #{imm}] *)
PROCEDURE Strb*(rt, rn, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 39000000H + imm * 400H + rn * 20H + rt;
  DWord(n)
END Strb;

(** MOV x{rd}, x{rn}  —  encoded as ADD x{rd}, x{rn}, #0 *)
PROCEDURE MovReg*(rd, rn: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 11000000H + rn * 20H + rd;
  n := -7FFFFFFFH - 1 + n;
  DWord(n)
END MovReg;

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
