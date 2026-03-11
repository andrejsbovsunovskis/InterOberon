MODULE Emitter;
IMPORT ST := SymTable, S := Scanner, G := Generator, E := ErrorMsg, Files, Strings, M := Machine;

CONST
  maxGenReg = 28; (** Max number of general-purpose registers (x0..x28) *)

  (** Values of Item.mode **)
  (** Some of Object Classes from SymTable are also valid *)
  Reg*  = 10;
  Cond* = 12; (** Condition expression result *)

  SP = G.SP;

  (** ARM64 condition codes *)
  EQ = 0;  (** Equal          *)
  NE = 1;  (** Not equal      *)
  GE = 10; (** Signed >=      *)
  LT = 11; (** Signed <       *)
  GT = 12; (** Signed >       *)
  LE = 13; (** Signed <=      *)
  AL = 14; (** Always (true)  *)
  NV = 15; (** Never  (false) *)

TYPE
  (** Item is a temporary object that exists during statement parsing.
        |  mode |     a     |     b     |      r      |
        |  Reg  |     -     |     -     | register No |
        | Const |   value   |     -     |      -      |
        |  Var  |  address  |     -     |      -      |
        | Cond  |    false/true List?   |  cond code  |
  *)
  Item* = RECORD
    mode*: INTEGER; (** See constants above, also Object Classes *)
    type*: ST.Type;
    a*, b*, r*: INTEGER (** Meaning of a, b, r according to the table above *)
  END;

VAR
  RH: INTEGER; (** Number of the highest free register *)

  cmpNeeded: BOOLEAN;

(** Item Constructors **)

PROCEDURE MakeConstItem*(VAR x: Item; type: ST.Type; val: INTEGER);
BEGIN
  x.mode := ST.Const;
  x.type := type;
  x.a := val
END MakeConstItem;

PROCEDURE MakeItem*(VAR x: Item; obj: ST.Object);
BEGIN
  x.mode := obj.class;
  x.type := obj.type;
  x.a := obj.val
END MakeItem;

(** Load in registers **)

(** Occupy register RH *)
PROCEDURE IncR;
BEGIN
  IF RH < maxGenReg THEN
    INC(RH)
  ELSE
    S.Mark(E.regOverflow)
  END
END IncR;

PROCEDURE Load(VAR x: Item);
VAR op, q, addr: INTEGER;
BEGIN
  IF x.mode # Reg THEN
    IF x.mode = ST.Const THEN
      G.MovImm(RH, x.a)
    ELSIF x.mode = ST.Var THEN
      G.Adrp(RH, 2); (* ADRP RH, 2 *)
      G.LdrImm(RH, RH, x.a, x.type.size); (* LDR* {RH}, [x{RH}, #{x.a}] *)
      cmpNeeded := TRUE
    END;
    x.mode := Reg;
    x.r := RH;
    IncR
  END
END Load;

PROCEDURE LoadAddr(VAR x: Item);
BEGIN
  IF x.mode = ST.Var THEN
    (*Put1(Add, RH, MP, x.a);*)
    x.r := RH;
    IncR
  ELSE S.Mark(E.badVarPar)
  END;
  x.mode := Reg
END LoadAddr;

PROCEDURE LoadCond(VAR x: Item);
BEGIN
  IF x.mode # Cond THEN
    IF x.type.form = ST.Bool THEN
      IF x.mode = ST.Const THEN
        IF x.a = 0 THEN x.r := NV ELSE x.r := AL END
      ELSE Load(x);
        G.CmpImm(x.r, 0);
        x.r := NE;
        DEC(RH)
      END
    ELSE S.Mark(E.expBool)
    END;
    x.mode := Cond;
    x.a := 0; x.b := 0 (* For FixLink to work properly in IF/ELSE *)
  END
END LoadCond;

(** Standard Functions **)

(** Ordinal number. x := ORD(x) *)
PROCEDURE Ord*(VAR x: Item);
BEGIN
  IF x.mode IN {ST.Var, ST.Const, Reg} THEN Load(x)
  ELSE S.Mark(E.incompatible)
  END
END Ord;

(** Absolute value. x := ABS(x) *)
PROCEDURE AbsVal*(VAR x: Item);
BEGIN
  IF x.mode = ST.Const THEN
    IF x.a < 0 THEN x.a := -x.a END
  ELSE (* x -- Var or Reg *)
    Load(x);
    IF x.type.size = 4 THEN G.Sxtw(x.r, x.r) END;
    G.CmpImm(x.r, 0);
    G.CSNeg(x.r, x.r, x.r, GE)
  END
END AbsVal;

(** Odd test. x := ODD(x), result is 0 or 1 *)
PROCEDURE OddVal*(VAR x: Item);
BEGIN
  IF x.mode = ST.Const THEN
    x.a := ABS(x.a) MOD 2
  ELSE
    Load(x);
    G.AndImm1(x.r, x.r)
  END
END OddVal;

(** INC/DEC. obj := obj +/- n. sub=TRUE means DEC. *)
PROCEDURE IncDecVar*(VAR obj, n: Item; sub: BOOLEAN);
VAR addr, size: INTEGER;
BEGIN
  IF obj.mode # ST.Var THEN S.Mark(E.badVarPar)
  ELSE
    addr := obj.a; size := obj.type.size;
    Load(obj);
    IF n.mode = ST.Const THEN
      IF sub THEN G.AddImm(obj.r, obj.r, -n.a)
      ELSE G.AddImm(obj.r, obj.r, n.a)
      END
    ELSE
      Load(n);
      IF sub THEN G.Sub(obj.r, obj.r, n.r)
      ELSE G.Add(obj.r, obj.r, n.r)
      END;
      DEC(RH)
    END;
    G.Adrp(RH, 2);
    G.StrImm(obj.r, RH, addr, size);
    DEC(RH)
  END
END IncDecVar;

(** Operations **)

(** Negation. x := -x *)
PROCEDURE Neg*(VAR x: Item);
BEGIN
  IF x.mode = ST.Const THEN
    IF x.a # S.minInt THEN x.a := -x.a
    ELSE S.Mark(E.intOverflow)
    END
  ELSE (* x -- Var or Reg *)
    Load(x);
    G.Neg(x.r, x.r)
  END
END Neg;

(** Addition or subtraction. x := x op y *)
PROCEDURE AddOp*(op: INTEGER; VAR x, y: Item);
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    IF op = S.plus THEN
      IF (y.a >= 0) & (S.maxInt - y.a >= x.a) OR
         (y.a < 0) & (S.minInt - y.a <= x.a)
      THEN INC(x.a, y.a)
      ELSE S.Mark(E.intOverflow)
      END
    ELSE (* op = S.minus *)
      IF (y.a >= 0) & (S.minInt + y.a <= x.a) OR
         (y.a < 0) & (S.maxInt + y.a >= x.a)
      THEN DEC(x.a, y.a)
      ELSE S.Mark(E.intOverflow)
      END
    END
  ELSIF y.mode = ST.Const THEN (* x -- Reg or Var *)
    Load(x); (* x -- Reg, y -- Const *)
    IF op = S.plus THEN
      G.AddImm(x.r, x.r, y.a)
    ELSE (* op = S.minus *)
      G.AddImm(x.r, x.r, -y.a)
    END
  ELSIF x.mode = ST.Const THEN (* y -- Reg or Var *)
    Load(y); (* x -- Const, y -- Reg *)
    IF op = S.minus THEN Neg(y) END;
    G.AddImm(y.r, y.r, x.a);
    x := y
  ELSE
    Load(x); Load(y); (* x -- Reg, y -- Reg *)
    IF op = S.plus THEN
      G.Add(x.r, x.r, y.r)
    ELSE (* op = S.minus *)
      G.Sub(x.r, x.r, y.r)
    END;
    DEC(RH)
  END
END AddOp;

PROCEDURE Negated(code: INTEGER): INTEGER;
BEGIN
  (* ARM64 condition pairs differ only in bit 0 *)
  IF ODD(code) THEN DEC(code) ELSE INC(code) END
RETURN code END Negated;

(** Maps a relational operator token to the ARM64 condition code *)
PROCEDURE RelCond(op: INTEGER): INTEGER;
VAR code: INTEGER;
BEGIN
  IF    op = S.eql THEN code := EQ
  ELSIF op = S.neq THEN code := NE
  ELSIF op = S.lss THEN code := LT
  ELSIF op = S.leq THEN code := LE
  ELSIF op = S.gtr THEN code := GT
  ELSE                   code := GE
  END
RETURN code END RelCond;

PROCEDURE Not*(VAR x: Item);
VAR t: INTEGER;
BEGIN
  LoadCond(x);
  x.r := Negated(x.r);
  t := x.a; x.a := x.b; x.b := t
END Not;

(** Multiplication or division (or MOD). x := x op y *)
PROCEDURE MulOp*(op: INTEGER; VAR x, y: Item);
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    IF op = S.times THEN
      IF (y.a = 0) OR (S.maxInt DIV ABS(y.a) >= ABS(x.a)) THEN x.a := x.a * y.a
      ELSE S.Mark(E.intOverflow)
      END
    ELSIF op = S.div THEN
      IF y.a > 0 THEN x.a := x.a DIV y.a
      ELSE S.Mark(E.badDiv)
      END
    ELSE (* op = S.mod *)
      IF y.a > 0 THEN x.a := x.a MOD y.a
      ELSE S.Mark(E.badDiv)
      END
    END
  ELSIF y.mode = ST.Const THEN (* x -- Reg or Var *)
    Load(x); (* x -- Reg; use RH as scratch for constant *)
    IF op = S.times THEN
      G.MovImm(RH, y.a);
      G.Mul(x.r, x.r, RH)
    ELSIF y.a <= 0 THEN S.Mark(E.badDiv)
    ELSIF op = S.div THEN
      G.MovImm(RH, y.a);
      G.Div(x.r, x.r, RH)
    ELSE (* op = S.mod: RH = divisor, RH+1 = quotient *)
      G.MovImm(RH, y.a);
      G.Div(RH + 1, x.r, RH);
      G.Msub(x.r, RH + 1, RH, x.r)
    END
  ELSIF x.mode = ST.Const THEN (* y -- Reg or Var *)
    Load(y); (* x -- Const, y -- Reg *)
    IF op = S.times THEN
      G.MovImm(RH, x.a);
      G.Mul(y.r, y.r, RH)
    ELSE
      Load(x); (* x -- Reg, y -- Reg, y.r < x.r *)
      IF op = S.div THEN
        G.Div(y.r, x.r, y.r)
      ELSE (* op = S.mod: RH = quotient scratch *)
        G.Div(RH, x.r, y.r);
        G.Msub(y.r, RH, y.r, x.r)
      END;
      DEC(RH)
    END;
    x := y
  ELSE
    Load(x); Load(y); (* x -- Reg, y -- Reg *)
    IF op = S.times THEN
      G.Mul(x.r, x.r, y.r)
    ELSIF op = S.div THEN
      G.Div(x.r, x.r, y.r)
    ELSE (* op = S.mod: RH = quotient scratch *)
      G.Div(RH, x.r, y.r);
      G.Msub(x.r, RH, y.r, x.r)
    END;
    DEC(RH)
  END
END MulOp;

PROCEDURE SetCond(VAR x: Item; code: INTEGER);
BEGIN
  x.mode := Cond; x.r := code;
  x.a := 0; x.b := 0 (* False- and True-lists respectively *)
END SetCond;

PROCEDURE IntRel*(op: INTEGER; VAR x, y: Item);
BEGIN
  IF y.mode = ST.Const THEN
    Load(x);
    IF x.type.size = 4 THEN G.Sxtw(x.r, x.r) END;
    G.CmpImm(x.r, y.a);
    DEC(RH)
  ELSE
    Load(x);
    IF x.type.size = 4 THEN G.Sxtw(x.r, x.r) END;
    Load(y);
    IF y.type.size = 4 THEN G.Sxtw(y.r, y.r) END;
    G.Cmp(x.r, y.r);
    DEC(RH, 2)
  END;
  SetCond(x, RelCond(op))
END IntRel;

PROCEDURE Assign*(VAR x, y: Item);
VAR size, q: INTEGER;
BEGIN
  IF ~ST.TypesCompatible(x.type, y.type) THEN
    S.Mark(E.incompatible)
  ELSIF x.mode # ST.Var THEN
    S.Mark(E.assignConst(*?*))
  ELSE (* x -- Var, y -- Const, Var or Reg *)
    Load(y); (* x -- Var, y -- Reg *)
    G.Adrp(RH, 2); (* ADRP RH, 2 *)
    G.StrImm(y.r, RH, x.a, x.type.size); (* STR* w{y.r}, [x{RH}, #{x.a}] *)
    DEC(RH)
  END
END Assign;

(** Jumps *)

PROCEDURE NextL(VAR L: INTEGER);
VAR instr, imm19: INTEGER;
BEGIN
  (* L = byte offset of a B.cond whose imm19 encodes byte offset of prev element *)
  instr := G.ReadWord(L);
  imm19 := (instr DIV 20H) MOD 80000H;
  IF imm19 >= 40000H THEN DEC(imm19, 80000H) END; (* sign-extend 19 bits *)
  L := imm19 * 4
END NextL;

PROCEDURE FixLinkWith(L, target: INTEGER);
VAR prevL: INTEGER;
BEGIN
  WHILE L # 0 DO
    prevL := L;
    NextL(L);
    G.PatchBCond(prevL, target)
  END
END FixLinkWith;

PROCEDURE FixLink*(L: INTEGER);
BEGIN
  FixLinkWith(L, G.Here())
END FixLink;

PROCEDURE Fixup*(VAR x: Item);
BEGIN FixLink(x.a)
END Fixup;

PROCEDURE CFJump*(VAR x: Item);
BEGIN
  LoadCond(x);
  (* Emit B.cond(Negated(x.r)), chain x.a false-list; fix x.b true-list to here *)
  FixLink(x.b);
  x.b := 0; (* Required because of And1 *)
  x.a := G.BCond(Negated(x.r), x.a)
END CFJump;

PROCEDURE FJump*(VAR L: INTEGER);
BEGIN
  (* Emit B.cond(AL) — always taken; chain previous L *)
  L := G.BCond(14 (* AL *), L)
END FJump;

PROCEDURE BJump*(L: INTEGER);
BEGIN
  G.B((L - G.Here()) DIV 4)
END BJump;

PROCEDURE CBJump*(VAR x: Item; L: INTEGER);
VAR here: INTEGER;
BEGIN
  LoadCond(x);
  here := G.Here();
  (* Emit B.cond(Negated(x.r)) backward to L — loop while condition FALSE *)
  G.BCondReal(Negated(x.r), (L - here) DIV 4);
  (* x.b = true-list: condition TRUE elsewhere → exit → land after this instr *)
  FixLink(x.b);
  (* x.a = false-list: condition FALSE elsewhere → also loop back to L *)
  FixLinkWith(x.a, L)
END CBJump;

PROCEDURE MergeLists(L1, L2: INTEGER): INTEGER;
VAR L, prevL, instr, cond: INTEGER;
BEGIN
  IF L1 = 0 THEN L1 := L2
  ELSIF L2 # 0 THEN
    (* Walk to tail of L1 (element with imm19 = 0) *)
    L := L1;
    REPEAT prevL := L; NextL(L) UNTIL L = 0;
    (* Splice: make tail of L1 point to head of L2 *)
    instr := G.ReadWord(prevL);
    cond  := instr MOD 10H;
    G.WriteWord(prevL, 54000000H + (L2 DIV 4 MOD 80000H) * 20H + cond)
  END
RETURN L1 END MergeLists;

(** x := x & *)
PROCEDURE And1*(VAR x: Item);
BEGIN
  LoadCond(x);
  CFJump(x)
END And1;

(** x := x & y *)
PROCEDURE And2*(VAR x, y: Item);
BEGIN
  LoadCond(y);
  x.a := MergeLists(y.a, x.a);
  x.b := y.b; x.r := y.r
END And2;

(** x := x OR *)
PROCEDURE Or1*(VAR x: Item);
BEGIN
  LoadCond(x);
  (* Emit B.cond(x.r): if TRUE jump forward → true-list; chain x.b *)
  FixLink(x.a);
  x.a := 0;
  x.b := G.BCond(x.r, x.b)
END Or1;

(** x := x OR y *)
PROCEDURE Or2*(VAR x, y: Item);
BEGIN
  LoadCond(y);
  x.b := MergeLists(y.b, x.b);
  x.a := y.a; x.r := y.r
END Or2;

(** Procedure Calls *)

(** Value of parameters are stored in registers
    before a procedure call *)
PROCEDURE ValueParam*(VAR x: Item);
BEGIN Load(x)
END ValueParam;

(** VAR-parameters are stored in registers as pointers
    before a procedure call *)
PROCEDURE VarParam*(VAR x: Item);
BEGIN LoadAddr(x)
END VarParam;

(** Called before Actual Parameters. *)
PROCEDURE PrepCall*(VAR x: Item; VAR rx: INTEGER);
END PrepCall;

(** Called after Actual Parameters *)
PROCEDURE Call*(VAR x: Item; rx: INTEGER);
VAR skipNeg, loop1, exitLoop1, loop2, exitLoop2: INTEGER;
BEGIN
  (* x.a is a fake call number, not an offset *)
  IF x.a = 5 (* Out.Char *) THEN
    (* On entry: w0 = c (CHAR value) *)
    G.AddImm(SP, SP, -16);   (* sp := sp - 16 *)
    G.StrImm(0, SP, 0, 1);   (* STRB w0, [sp, #0] *)
    G.MovImm(0, 1);          (* x0 := 1 (stdout) *)
    G.Mov(1, SP);            (* x1 := sp *)
    G.MovImm(2, 1);          (* x2 := 1 (length) *)
    G.MovImm(16, 4);         (* x16 := write syscall *)
    G.Svc(0);
    G.AddImm(SP, SP, 16)     (* sp := sp + 16 *)
  ELSIF x.a = 6 (* Out.Int *) THEN
    (* Print integer as decimal text.
       On entry: w0 = i, w1 = n (ignored).
       Scratch registers: x9=value, x10=divisor, x11=digit, x12=mod scratch, x13=div scratch *)
    G.AddImm(SP, SP, -16);    (* sp := sp - 16 *)

    (* x9 := sign-extend w0 to 64-bit *)
    G.Sxtw(9, 0);             (* SXTW x9, w0 *)

    (* IF i < 0 THEN print '-'; i := -i END *)
    G.CmpImm(9, 0);           (* CMP x9, #0 *)
    skipNeg := G.BCond(10 (* GE *), 0);  (* B.GE skipNeg — skip if i >= 0 *)

    G.MovImm(11, 2DH);        (* w11 := '-' *)
    G.StrImm(11, SP, 0, 1);   (* STRB w11, [sp, #0] *)
    G.MovImm(0, 1);           (* x0 := 1 (stdout) *)
    G.Mov(1, SP);             (* x1 := sp *)
    G.MovImm(2, 1);           (* x2 := 1 *)
    G.MovImm(16, 4);          (* x16 := write syscall *)
    G.Svc(0);
    G.Neg(9, 9);              (* NEG x9, x9 *)

    FixLink(skipNeg);         (* skipNeg: *)

    (* x := 1 *)
    G.MovImm(10, 1);          (* x10 := 1 *)

    (* WHILE x <= i DIV 10 DO x := x * 10 END *)
    loop1 := G.Here();
    G.MovImm(11, 10);         (* x11 := 10 *)
    G.Div(12, 9, 11);         (* x12 := x9 DIV 10 *)
    G.Cmp(10, 12);            (* CMP x10, x12 *)
    exitLoop1 := G.BCond(12 (* GT *), 0);  (* B.GT exitLoop1 *)
    G.MovImm(11, 10);         (* x11 := 10 *)
    G.Mul(10, 10, 11);        (* x10 := x10 * 10 *)
    G.B((loop1 - G.Here()) DIV 4);  (* B loop1 *)
    FixLink(exitLoop1);       (* exitLoop1: *)

    (* WHILE x # 0 DO Out.Char(CHR(i DIV x MOD 10 + 30H)); x := x DIV 10 END *)
    loop2 := G.Here();
    G.CmpImm(10, 0);          (* CMP x10, #0 *)
    exitLoop2 := G.BCond(0 (* EQ *), 0);  (* B.EQ exitLoop2 *)

    G.Div(11, 9, 10);         (* x11 := x9 DIV x10 *)
    G.MovImm(12, 10);         (* x12 := 10 *)
    G.Div(13, 11, 12);        (* x13 := x11 DIV 10 *)
    G.Msub(11, 13, 12, 11);   (* x11 := x11 - x13*10  =  (i DIV x) MOD 10 *)
    G.AddImm(11, 11, 30H);    (* x11 := x11 + 0x30  — ASCII digit *)

    G.StrImm(11, SP, 0, 1);   (* STRB w11, [sp, #0] *)
    G.MovImm(0, 1);           (* x0 := 1 (stdout) *)
    G.Mov(1, SP);             (* x1 := sp *)
    G.MovImm(2, 1);           (* x2 := 1 *)
    G.MovImm(16, 4);          (* x16 := write syscall *)
    G.Svc(0);

    G.MovImm(12, 10);         (* x12 := 10 *)
    G.Div(10, 10, 12);        (* x10 := x10 DIV 10 *)
    G.B((loop2 - G.Here()) DIV 4);  (* B loop2 *)
    FixLink(exitLoop2);       (* exitLoop2: *)

    G.AddImm(SP, SP, 16)      (* sp := sp + 16 *)
  ELSIF x.a = 7 (* Out.Ln *) THEN
    (* sp must stay 16-byte aligned -> reserve 16 bytes *)
    G.AddImm(SP, SP, -16);    (* sp := sp - 16 *)

    G.MovImm(3, 0AH);        (* w3 := 0x0A *)
    G.StrImm(3, SP, 0, 1);   (* STRB w3, [sp,#0] *)

    G.MovImm(0, 1);          (* x0 := 1 (stdout) *)
    G.Mov(1, SP);            (* x1 := sp (address of byte) *)
    G.MovImm(2, 1);          (* x2 := 1 (length) *)

    G.MovImm(16, 4);         (* x16 := write syscall number *)
    G.Svc(0);

    G.AddImm(SP, SP, 16)     (* sp := sp + 16 *)
  END;
  RH := 0 (* Do it only if x is a proper procedure *)
END Call;

(** - **)

(** Generates code that terminates the program. *)
PROCEDURE Exit*;
BEGIN
  G.Exit
END Exit;

END Emitter.
