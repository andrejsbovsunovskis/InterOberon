MODULE Emitter;
IMPORT ST := SymTable, S := Scanner, G := Generator, E := ErrorMsg, Files, Strings, M := Machine, SYSTEM;

CONST
  maxGenReg = 18;  (** Last general-purpose register (x18) *)
  firstCSReg = 19; (** First callee-saved register (x19) *)
  maxCSReg = 28;   (** Last callee-saved register (x28) *)

  (** Values of Item.mode **)
  (** Some of Object Classes from SymTable are also valid *)
  Reg*  = 10;
  RegI* = 11; (** Register indirect: address in register r *)
  Cond* = 12; (** Condition expression result *)

  SP = G.SP;
  FP = 29;  (** Frame pointer register *)
  LR = 30;  (** Link register *)

  (** ARM64 condition codes **)
  EQ = 0;  (** Equal         *)
  NE = 1;  (** Not equal     *)
  LO = 3;  (** Unsigned <    *)
  GE = 10; (** Signed >=     *)
  LT = 11; (** Signed <      *)
  GT = 12; (** Signed >      *)
  LE = 13; (** Signed <=     *)
  AL = 14; (** Always (true) *)
  NV = 15; (** Never (false) *)
  (** Unsigned compares for character/string byte relations *)
  HS = 2;
  HI = 8;
  LS = 9;

TYPE
  LONGINT = M.LONGINT;

  (** Item is a temporary object that exists during statement parsing.
        |  mode |     a     |     b     |      r      |
        |  Reg  |     -     |     -     | register No |
        | Const |   value   |     -     |      -      |
        |  Var  |  address  |   level   |      -      |
        |  RegI |     -     |     -     | register No |
        |  Cond |    false/true List?   |  cond code  |
  *)
  Item* = RECORD
    mode*: INTEGER; (** See constants above, also Object Classes *)
    type*: ST.Type;
    a*: LONGINT; (** Value (Const) / address (Var) / jump-list head (Cond) *)
    b*, r*: INTEGER; (** b: level / secondary; r: register / cond code *)
    rdo*: BOOLEAN (** Read-only: TRUE for non-VAR array param elements *)
  END;

VAR
  RH: INTEGER; (** Next free general-purpose register (x0..x18) *)
  SH: INTEGER; (** Next free callee-saved register (x19..x28) *)

  cmpNeeded: BOOLEAN;

(** Item Constructors **)

PROCEDURE MakeConstItem*(VAR x: Item; type: ST.Type; val: LONGINT);
BEGIN
  x.mode := ST.Const;
  x.type := type;
  x.a := val;
  x.rdo := FALSE
END MakeConstItem;

PROCEDURE MakeStringConstItem*(VAR x: Item; strIdx, charLen: INTEGER);
BEGIN
  x.mode := ST.Const;
  x.type := ST.MakeStringType(charLen);
  x.a := strIdx;
  x.rdo := FALSE
END MakeStringConstItem;

PROCEDURE MakeItem*(VAR x: Item; obj: ST.Object);
BEGIN
  x.mode := obj.class;
  x.type := obj.type;
  x.b := obj.lev;
  x.rdo := obj.readOnly;
  IF (obj.class IN {ST.Var, ST.VarPar}) & (obj.lev > 0) & (obj.lev < ST.curLev) THEN
    S.Mark(E.outerLocalAccess)
  END;
  IF obj.class = ST.Const THEN
    IF (obj.type # NIL) & (obj.type.form = ST.Proc) THEN
      x.a := obj.address
    ELSIF (obj.type # NIL) & (obj.type.form = ST.Real) THEN
      x.a := SYSTEM.VAL(INTEGER, SYSTEM.VAL(REAL, obj.realVal))
    ELSE
      x.a := obj.intVal
    END
  ELSE
    x.a := obj.address
  END;
  IF (obj.class = ST.VarPar) & (obj.type.form = ST.Array)
      & (obj.type.openRank > 0) THEN
    x.b := M.SHORT(x.a) + 8 (* address of first hidden length parameter *)
  END
END MakeItem;

(** Load in registers **)

(** Allocate the next general-purpose register *)
PROCEDURE AllocR(): INTEGER;
VAR r: INTEGER;
BEGIN
  r := RH;
  IF RH <= maxGenReg THEN
    INC(RH)
  ELSE
    S.Mark(E.regOverflow)
  END
RETURN r END AllocR;

(** Allocate a callee-saved register for long-lived values *)
PROCEDURE AllocS(): INTEGER;
VAR r: INTEGER;
BEGIN
  r := SH;
  IF SH <= maxCSReg THEN
    INC(SH)
  ELSE
    S.Mark(E.regOverflow)
  END
RETURN r END AllocS;

(** Free the last allocated callee-saved register *)
PROCEDURE FreeS;
BEGIN
  IF SH > firstCSReg THEN DEC(SH) END
END FreeS;

PROCEDURE Negated(code: INTEGER): INTEGER;
BEGIN
  (* ARM64 condition pairs differ only in bit 0 *)
  IF ODD(code) THEN DEC(code) ELSE INC(code) END
RETURN code END Negated;

(** Jumps *)

PROCEDURE FixLinkWith(L, target: INTEGER);
VAR nextL: INTEGER;
BEGIN
  WHILE L # 0 DO
    nextL := G.ImmFromBCond(L);
    G.PatchBCond(L, target);
    L := nextL
  END
END FixLinkWith;

PROCEDURE FixLink*(L: INTEGER);
BEGIN
  FixLinkWith(L, G.Here())
END FixLink;

PROCEDURE Load(VAR x: Item);
VAR op, q, addr: INTEGER;
BEGIN
  IF x.mode # Reg THEN
    IF x.mode = ST.Const THEN
      IF x.type.form = ST.String THEN
        S.Mark(E.incompatible)
      ELSIF x.type.form = ST.Real THEN
        G.MovImm(RH, x.a);
        G.FMovWtoS(RH, RH)
      ELSIF x.type.form = ST.Proc THEN
        G.Adr(RH, (M.SHORT(x.a) - G.Here()) * 4)
      ELSE
        G.MovImm(RH, x.a)
      END;
      x.r := AllocR()
    ELSIF x.mode = RegI THEN
      IF x.type.form = ST.Real THEN
        G.FLdrImm(x.r, x.r, 0)
      ELSE
        G.LdrImm(x.r, x.r, 0, x.type.size);
        IF x.type.form = ST.ShortInt THEN G.Sxth(x.r, x.r)
        ELSIF x.type.form IN {ST.Int, ST.Byte, ST.Set} THEN G.Sxtw(x.r, x.r)
        END
      END;
      cmpNeeded := TRUE
    ELSIF x.mode = ST.Var THEN
      IF x.b > 0 THEN (* local variable or value parameter *)
        IF x.type.form = ST.Real THEN
          G.FLdrImm(RH, FP, M.SHORT(x.a))
        ELSE
          G.LdrImm(RH, FP, M.SHORT(x.a), x.type.size);
          IF x.type.form = ST.ShortInt THEN G.Sxth(RH, RH)
          ELSIF x.type.form IN {ST.Int, ST.Byte, ST.Set} THEN G.Sxtw(RH, RH)
          END
        END
      ELSE (* global variable *)
        G.LoadDataPage(RH);
        IF x.type.form = ST.Real THEN
          G.FLdrImm(RH, RH, M.SHORT(x.a))
        ELSE
          G.LdrImm(RH, RH, M.SHORT(x.a), x.type.size);
          IF x.type.form = ST.ShortInt THEN G.Sxth(RH, RH)
          ELSIF x.type.form IN {ST.Int, ST.Byte, ST.Set} THEN G.Sxtw(RH, RH)
          END
        END
      END;
      cmpNeeded := TRUE;
      x.r := AllocR()
    ELSIF x.mode = ST.VarPar THEN (* VAR parameter: load address, then value *)
      G.LdrImm(RH, FP, M.SHORT(x.a), 8); (* load pointer from stack frame *)
      IF x.type.form = ST.Real THEN
        G.FLdrImm(RH, RH, 0)
      ELSE
        G.LdrImm(RH, RH, 0, x.type.size);
        IF x.type.form = ST.ShortInt THEN G.Sxth(RH, RH)
        ELSIF x.type.form IN {ST.Int, ST.Byte, ST.Set} THEN G.Sxtw(RH, RH)
        END
      END;
      cmpNeeded := TRUE;
      x.r := AllocR()
    ELSIF x.mode = Cond THEN
      FixLink(x.b);
      FixLinkWith(M.SHORT(x.a), G.Here()); (* Cond false-list *)
      (* CSINC Xd, xzr, xzr, Negated(x.r) = CSET Xd, x.r *)
      G.CSInc(RH, SP, SP, Negated(x.r));
      x.r := AllocR()
    END;
    x.mode := Reg
  END
END Load;

PROCEDURE LoadAddr(VAR x: Item);
BEGIN
  IF (x.mode = ST.Const) & (x.type.form = ST.String) THEN
    G.LoadStringAddr(RH, M.SHORT(x.a));
    x.r := RH;
    INC(RH);
    x.mode := Reg
  ELSIF x.mode = ST.Var THEN
    IF x.b > 0 THEN (* local variable *)
      G.AddImm(RH, FP, M.SHORT(x.a))
    ELSE (* global variable *)
      G.LoadDataPage(RH);
      G.AddImm(RH, RH, M.SHORT(x.a))
    END;
    x.r := AllocR()
  ELSIF x.mode = ST.VarPar THEN (* already a pointer in stack frame *)
    G.LdrImm(RH, FP, M.SHORT(x.a), 8);
    x.r := AllocR()
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
    x.a := 0; x.b := 0
  END
END LoadCond;

(** Standard Functions **)

(** Ordinal number. x := ORD(x) *)
PROCEDURE Ord*(VAR x: Item);
BEGIN
  IF x.mode IN {ST.Var, ST.VarPar, ST.Const, Reg} THEN Load(x)
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
    IF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r) END;
    G.CmpImm(x.r, 0);
    G.CSNeg(x.r, x.r, x.r, GE)
  END
END AbsVal;

(** Odd test. x := ODD(x), result is 0 or 1 *)
PROCEDURE OddVal*(VAR x: Item);
BEGIN
  IF x.mode = ST.Const THEN
    IF x.a < 0 THEN x.a := (-x.a) MOD 2 ELSE x.a := x.a MOD 2 END
  ELSE
    Load(x);
    G.AndImm1(x.r, x.r)
  END
END OddVal;

(** Arithmetic shift right. x := ASR(x, y) *)
PROCEDURE AsrVal*(VAR x, y: Item);
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    x.a := M.ASR64(x.a, M.SHORT(y.a))
  ELSE
    Load(x); Load(y);
    G.Asr(x.r, x.r, y.r);
    DEC(RH)
  END
END AsrVal;

(** Logical shift left. x := LSL(x, y) *)
PROCEDURE LslVal*(VAR x, y: Item);
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    x.a := M.LSL64(x.a, M.SHORT(y.a))
  ELSE
    Load(x); Load(y);
    G.Lsl(x.r, x.r, y.r);
    DEC(RH)
  END
END LslVal;

(** Rotate right. x := ROR(x, y) *)
PROCEDURE RorVal*(VAR x, y: Item);
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    x.a := M.ROR64(x.a, M.SHORT(y.a))
  ELSE
    Load(x); Load(y);
    G.Ror(x.r, x.r, y.r);
    DEC(RH)
  END
END RorVal;

(** FLOOR: REAL → INTEGER. Rounds toward minus infinity. *)
PROCEDURE Floor*(VAR x: Item);
BEGIN
  Load(x);
  G.Fcvtms(x.r, x.r);
  x.type := ST.intType
END Floor;

(** SHORT: type narrowing. Result type is set by caller. *)
PROCEDURE Short*(VAR x: Item);
BEGIN
  (* Constant values are just truncated *)
  IF x.mode # ST.Const THEN
    Load(x);
    IF x.type.size = 8 THEN G.Sxtw(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxth(x.r, x.r)
    END
  END
END Short;

(** LONG: type widening. Result type is set by caller. *)
PROCEDURE Long*(VAR x: Item);
BEGIN
  IF x.mode # ST.Const THEN
    Load(x);
    IF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r)
    END
  END
END Long;

(** FLT: INTEGER → REAL. *)
PROCEDURE Flt*(VAR x: Item);
BEGIN
  Load(x);
  G.Scvtf(x.r, x.r);
  x.type := ST.realType
END Flt;

(** Set Operations **)

(** Constructs a singleton set {x} = 1 << x. Converts x from Int to Set. *)
PROCEDURE Singleton*(VAR x: Item);
BEGIN
  IF x.mode = ST.Const THEN
    x.a := M.LSL64(1, M.SHORT(x.a))
  ELSE
    Load(x);
    G.MovImm(RH, 1);
    G.Lsl(x.r, RH, x.r)
  END;
  x.type := ST.setType
END Singleton;

(** Constructs a range set {x..y}. Result in x. *)
PROCEDURE SetRange*(VAR x, y: Item);
VAR mask: LONGINT;
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    IF M.SHORT(y.a) < 63 THEN mask := M.LSL64(2, M.SHORT(y.a)) - 1
    ELSE mask := -1
    END;
    x.a := mask - (M.LSL64(1, M.SHORT(x.a)) - 1)
  ELSE
    (* runtime: result = (-1 << x) AND ((2 << y) - 1)
       = ~0 << x AND (2 << y - 1) *)
    Load(x); Load(y);
    (* RH-2 = x (lo), RH-1 = y (hi) *)
    (* rd = ~0 << lo *)
    G.Mvn(RH, G.SP (* xzr = 0, so MVN gives -1 *));
    G.Lsl(x.r, RH, x.r);
    (* rd2 = (2 << hi) - 1 *)
    G.MovImm(RH, 2);
    G.Lsl(y.r, RH, y.r);
    G.AddImm(y.r, y.r, -1);
    (* result = lo_mask AND hi_mask *)
    G.And(x.r, x.r, y.r);
    DEC(RH)
  END;
  x.type := ST.setType
END SetRange;

(** Set union. x := x + y (bitwise OR) *)
PROCEDURE SetUnion*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.Orr(x.r, x.r, y.r);
  DEC(RH)
END SetUnion;

(** Set difference. x := x - y (bitwise AND NOT) *)
PROCEDURE SetDiff*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.Bic(x.r, x.r, y.r);
  DEC(RH)
END SetDiff;

(** Set intersection. x := x * y (bitwise AND) *)
PROCEDURE SetInter*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.And(x.r, x.r, y.r);
  DEC(RH)
END SetInter;

(** Set symmetric difference. x := x / y (bitwise XOR) *)
PROCEDURE SetSymDiff*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.Eor(x.r, x.r, y.r);
  DEC(RH)
END SetSymDiff;

(** Set complement. x := -x (bitwise NOT) *)
PROCEDURE SetComplement*(VAR x: Item);
BEGIN
  Load(x);
  G.Mvn(x.r, x.r)
END SetComplement;

(** Set membership test. x IN y → Bool result.
    Tests if bit x is set in y. *)
PROCEDURE InSet*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  (* mask = 1 << x *)
  G.MovImm(RH, 1);
  G.Lsl(x.r, RH, x.r);
  (* TST y, mask *)
  G.Tst(y.r, x.r);
  DEC(RH, 2);
  x.mode := Cond;
  x.r := NE; (* NE = bit was set *)
  x.a := 0; x.b := 0;
  x.type := ST.boolType
END InSet;

(** INCL/EXCL. s := s + {x} or s := s - {x}. excl=TRUE means EXCL. *)
PROCEDURE InclExclVar*(VAR s, x: Item; excl: BOOLEAN);
VAR addr, size, lev, addrReg, valReg: INTEGER;
BEGIN
  IF s.rdo THEN S.Mark(E.readOnly)
  ELSIF (s.mode = ST.VarPar) & ((s.type.form = ST.Set) OR (s.type.form = ST.LongSet)) THEN
    size := s.type.size;
    LoadAddr(s);
    addrReg := s.r;
    G.LdrImm(RH, addrReg, 0, size);
    valReg := AllocR();
    IF x.mode = ST.Const THEN
      G.MovImm(RH, M.LSL64(1, M.SHORT(x.a)));
      IF excl THEN G.Bic(valReg, valReg, RH)
      ELSE G.Orr(valReg, valReg, RH)
      END
    ELSE
      Load(x);
      G.MovImm(RH, 1);
      G.Lsl(x.r, RH, x.r);
      IF excl THEN G.Bic(valReg, valReg, x.r)
      ELSE G.Orr(valReg, valReg, x.r)
      END;
      DEC(RH)
    END;
    G.StrImm(valReg, addrReg, 0, size);
    DEC(RH, 2)
  ELSIF s.mode = ST.Var THEN
    addr := M.SHORT(s.a); size := s.type.size; lev := s.b;
    Load(s);
    IF x.mode = ST.Const THEN
      G.MovImm(RH, M.LSL64(1, M.SHORT(x.a)));
      IF excl THEN G.Bic(s.r, s.r, RH)
      ELSE G.Orr(s.r, s.r, RH)
      END
    ELSE
      Load(x);
      G.MovImm(RH, 1);
      G.Lsl(x.r, RH, x.r);
      IF excl THEN G.Bic(s.r, s.r, x.r)
      ELSE G.Orr(s.r, s.r, x.r)
      END;
      DEC(RH)
    END;
    IF lev > 0 THEN (* local variable or value parameter *)
      G.StrImm(s.r, FP, addr, size)
    ELSE (* module-level variable *)
      G.LoadDataPage(RH);
      G.StrImm(s.r, RH, addr, size)
    END;
    DEC(RH)
  ELSE
    S.Mark(E.badVarPar)
  END
END InclExclVar;

(** INC/DEC. x := x +/- n. *)
PROCEDURE IncDecVar*(VAR x, n: Item; dec: BOOLEAN);
VAR addr, size, addrReg, a: INTEGER;
BEGIN
  IF x.rdo THEN S.Mark(E.readOnly)
  ELSE
    IF dec THEN a := -M.SHORT(n.a) ELSE a := M.SHORT(n.a) END;
    IF x.mode = RegI THEN
      addrReg := x.r; size := x.type.size;
      G.LdrImm(RH, addrReg, 0, size);
      x.r := AllocR();
      x.mode := Reg;
      IF n.mode = ST.Const THEN
        G.AddImm(x.r, x.r, a)
      ELSE
        Load(n);
        IF dec THEN G.Sub(x.r, x.r, n.r)
        ELSE G.Add(x.r, x.r, n.r)
        END;
        DEC(RH)
      END;
      G.StrImm(x.r, addrReg, 0, size);
      DEC(RH, 2)
    ELSIF x.mode = ST.Var THEN
      addr := M.SHORT(x.a); size := x.type.size;
      Load(x);
      IF n.mode = ST.Const THEN
        G.AddImm(x.r, x.r, a)
      ELSE
        Load(n);
        IF dec THEN G.Sub(x.r, x.r, n.r)
        ELSE G.Add(x.r, x.r, n.r)
        END;
        DEC(RH)
      END;
      IF x.b > 0 THEN (* local variable *)
        G.StrImm(x.r, FP, addr, size)
      ELSE (* global variable *)
        G.LoadDataPage(RH);
        G.StrImm(x.r, RH, addr, size)
      END;
      DEC(RH)
    ELSE S.Mark(E.badVarPar)
    END
  END
END IncDecVar;

(** Operations **)

(** Negation. x := -x *)
PROCEDURE Neg*(VAR x: Item);
BEGIN
  IF x.mode = ST.Const THEN
    IF x.a # M.minLongInt THEN x.a := -x.a
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
      IF (y.a >= 0) & (M.maxLongInt - y.a >= x.a) OR
         (y.a < 0) & (M.minLongInt - y.a <= x.a)
      THEN INC(x.a, y.a)
      ELSE S.Mark(E.intOverflow)
      END
    ELSE (* op = S.minus *)
      IF (y.a >= 0) & (M.minLongInt + y.a <= x.a) OR
         (y.a < 0) & (M.maxLongInt + y.a >= x.a)
      THEN DEC(x.a, y.a)
      ELSE S.Mark(E.intOverflow)
      END
    END
  ELSIF y.mode = ST.Const THEN (* x -- Reg or Var *)
    Load(x); (* x -- Reg, y -- Const *)
    IF op = S.plus THEN
      G.AddImm(x.r, x.r, M.SHORT(y.a))
    ELSE (* op = S.minus *)
      G.AddImm(x.r, x.r, -M.SHORT(y.a))
    END
  ELSIF x.mode = ST.Const THEN (* y -- Reg or Var *)
    Load(y); (* x -- Const, y -- Reg *)
    IF op = S.minus THEN Neg(y) END;
    G.AddImm(y.r, y.r, M.SHORT(x.a));
    x := y
  ELSE
    Load(x); Load(y); (* x -- Reg, y -- Reg *)
    IF x.r > y.r THEN
      IF op = S.plus THEN G.Add(y.r, x.r, y.r)
      ELSE G.Sub(y.r, x.r, y.r)
      END;
      x.r := y.r
    ELSE
      IF op = S.plus THEN G.Add(x.r, x.r, y.r)
      ELSE G.Sub(x.r, x.r, y.r)
      END
    END;
    DEC(RH)
  END
END AddOp;

(** Floating-point operations **)

(** Float negation. x := -x *)
PROCEDURE FNegVal*(VAR x: Item);
BEGIN
  Load(x);
  G.FNeg(x.r, x.r)
END FNegVal;

(** Float addition or subtraction. x := x op y *)
PROCEDURE FAddOp*(op: INTEGER; VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  IF op = S.plus THEN
    G.FAdd(x.r, x.r, y.r)
  ELSE
    G.FSub(x.r, x.r, y.r)
  END;
  DEC(RH)
END FAddOp;

(** Float multiplication or division. x := x op y *)
PROCEDURE FMulOp*(op: INTEGER; VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  IF op = S.times THEN
    G.FMul(x.r, x.r, y.r)
  ELSE
    G.FDiv(x.r, x.r, y.r)
  END;
  DEC(RH)
END FMulOp;

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
  t := M.SHORT(x.a); x.a := x.b; x.b := t
END Not;

(** Returns log2(n) if n is a power of 2, or -1 otherwise. *)
PROCEDURE Log2(n: INTEGER): INTEGER;
VAR k: INTEGER;
BEGIN
  IF n <= 0 THEN k := -1
  ELSE
    k := 0;
    WHILE (k < 63) & (LSL(1, k) < n) DO INC(k) END;
    IF LSL(1, k) # n THEN k := -1 END
  END
RETURN k END Log2;

(** Multiplication or division (or MOD). x := x op y.
    DIV and MOD use floor division (toward -infinity). *)
PROCEDURE MulOp*(op: INTEGER; VAR x, y: Item);
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    IF op = S.times THEN
      IF (y.a = 0) OR (M.maxLongInt DIV ABS(y.a) >= ABS(x.a)) THEN x.a := x.a * y.a
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
    Load(x); (* x -- Reg; RH and RH+1 are then used as scratch *)
    IF op = S.times THEN
      G.MovImm(RH, y.a);
      G.Mul(x.r, x.r, RH)
    ELSIF y.a <= 0 THEN S.Mark(E.badDiv)
    ELSIF op = S.div THEN
      IF Log2(M.SHORT(y.a)) >= 0 THEN
        G.AsrImm(x.r, x.r, Log2(M.SHORT(y.a)))
      ELSE
        G.MovImm(RH, y.a);
        G.Mov(RH + 1, x.r);
        G.Div(x.r, x.r, RH);
        G.Msub(RH, x.r, RH, RH + 1);
        G.Tbz(RH, 63, 2);
        G.AddImm(x.r, x.r, -1)
      END
    ELSE (* op = S.mod *)
      G.MovImm(RH, y.a);
      G.Div(RH + 1, x.r, RH);
      G.Msub(x.r, RH + 1, RH, x.r);
      G.Tbz(x.r, 63, 2);
      G.Add(x.r, x.r, RH)
    END
  ELSIF x.mode = ST.Const THEN (* y -- Reg or Var *)
    Load(y); (* x -- Const, y -- Reg *)
    IF op = S.times THEN
      G.MovImm(RH, x.a);
      G.Mul(y.r, y.r, RH)
    ELSE
      Load(x); (* x -- Reg, y -- Reg, y.r < x.r *)
      IF op = S.div THEN
        G.Mov(RH, y.r);
        G.Div(y.r, x.r, y.r);
        G.Msub(RH, y.r, RH, x.r);
        G.Tbz(RH, 63, 2);
        G.AddImm(y.r, y.r, -1)
      ELSE (* op = S.mod *)
        G.Mov(RH + 1, y.r);
        G.Div(RH, x.r, y.r);
        G.Msub(y.r, RH, y.r, x.r);
        G.Tbz(y.r, 63, 2);
        G.Add(y.r, y.r, RH + 1)
      END;
      DEC(RH)
    END;
    x := y
  ELSE
    Load(x); Load(y); (* x -- Reg, y -- Reg *)
    IF x.r > y.r THEN
      IF op = S.times THEN G.Mul(y.r, x.r, y.r)
      ELSIF op = S.div THEN
        G.Mov(RH, y.r);
        G.Div(y.r, x.r, y.r);
        G.Msub(RH, y.r, RH, x.r);
        G.Tbz(RH, 63, 2);
        G.AddImm(y.r, y.r, -1)
      ELSE
        G.Div(RH, x.r, y.r);
        G.Mov(RH + 1, y.r);
        G.Msub(y.r, RH, y.r, x.r);
        G.Tbz(y.r, 63, 2);
        G.Add(y.r, y.r, RH + 1)
      END;
      x.r := y.r
    ELSE
      IF op = S.times THEN G.Mul(x.r, x.r, y.r)
      ELSIF op = S.div THEN
        G.Mov(RH, x.r);
        G.Div(x.r, x.r, y.r);
        G.Msub(RH, x.r, y.r, RH);
        G.Tbz(RH, 63, 2);
        G.AddImm(x.r, x.r, -1)
      ELSE
        G.Div(RH, x.r, y.r);
        G.Msub(x.r, RH, y.r, x.r);
        G.Tbz(x.r, 63, 2);
        G.Add(x.r, x.r, y.r)
      END
    END;
    DEC(RH)
  END
END MulOp;

PROCEDURE SetCond(VAR x: Item; code: INTEGER);
BEGIN
  x.mode := Cond; x.r := code;
  x.a := 0; x.b := 0
END SetCond;

PROCEDURE IntRel*(op: INTEGER; VAR x, y: Item);
BEGIN
  IF (y.mode = ST.Const) & (y.a >= 0) & (y.a < 1000H) THEN
    Load(x);
    IF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r)
    END;
    G.CmpImm(x.r, M.SHORT(y.a));
    DEC(RH)
  ELSE
    Load(x);
    IF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r)
    END;
    Load(y);
    IF y.type.size = 2 THEN G.Sxth(y.r, y.r)
    ELSIF y.type.size = 4 THEN G.Sxtw(y.r, y.r)
    END;
    G.Cmp(x.r, y.r);
    DEC(RH, 2)
  END;
  SetCond(x, RelCond(op))
END IntRel;

(** Float comparison. x rel y → Bool result *)
PROCEDURE FRel*(op: INTEGER; VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.FCmp(x.r, y.r);
  DEC(RH, 2);
  SetCond(x, RelCond(op))
END FRel;

PROCEDURE AssignCharFromString(VAR x, y: Item);
VAR r, base: INTEGER;
BEGIN
  r := AllocR();
  G.LoadStringAddr(r, M.SHORT(y.a));
  G.LdrImm(r, r, 0, 2);
  IF x.mode = ST.Var THEN
    IF x.b > 0 THEN G.StrImm(r, FP, M.SHORT(x.a), 2); DEC(RH)
    ELSE
      (* Adrp writes to register index RH without AllocR; INC so RH matches two live regs (r, base). *)
      base := RH;
      G.LoadDataPage(base);
      G.StrImm(r, base, M.SHORT(x.a), 2);
      INC(RH);
      DEC(RH, 2)
    END
  ELSE S.Mark(E.incompatible)
  END
END AssignCharFromString;

PROCEDURE RelCondU(op: INTEGER): INTEGER;
VAR code: INTEGER;
BEGIN
  IF    op = S.eql THEN code := EQ
  ELSIF op = S.neq THEN code := NE
  ELSIF op = S.lss THEN code := LO
  ELSIF op = S.leq THEN code := LS
  ELSIF op = S.gtr THEN code := HI
  ELSE                   code := HS (* unsigned >= *)
  END
RETURN code END RelCondU;

PROCEDURE CmpStrings*(op: INTEGER; VAR xa, ya: Item);
VAR pl, pr, bl, br: INTEGER;
  loop0, pNe, pEz, pBk, skipSecond, mergeEntry: INTEGER;
BEGIN
  LoadAddr(xa); pl := xa.r;
  LoadAddr(ya); pr := ya.r;
  bl := AllocR(); br := AllocR();
  loop0 := G.Here();
  G.LdrImm(bl, pl, 0, 2);
  G.LdrImm(br, pr, 0, 2);
  G.Cmp(bl, br);
  G.BCond(NE, 0);
  pNe := G.Here() - 1;
  G.CmpImm(bl, 0);
  G.BCond(EQ, 0);
  pEz := G.Here() - 1;
  G.AddImm(pl, pl, 2);
  G.AddImm(pr, pr, 2);
  G.B(0);
  pBk := G.Here() - 1;
  G.PatchB(pBk, loop0);

  (* Bytes differ: materialize 0/1 in bl; branch over NUL-equal path. *)
  G.PatchBCond(pNe, G.Here());
  IF op = S.eql THEN G.MovImm(bl, 0)
  ELSIF op = S.neq THEN G.MovImm(bl, 1)
  ELSE
    G.Cmp(bl, br);
    G.CSInc(bl, SP, SP, Negated(RelCondU(op)))
  END;
  skipSecond := G.Here();
  G.B(0);

  (* Both terminated here (logical NUL match): strings compare equal at end. *)
  G.PatchBCond(pEz, G.Here());
  IF (op = S.eql) OR (op = S.leq) OR (op = S.geq) THEN G.MovImm(bl, 1)
  ELSE G.MovImm(bl, 0)
  END;

  (* Single exit: boolean in pl; free br, bl, pr (keep pl / RH = 1). *)
  mergeEntry := G.Here();
  G.Mov(pl, bl);
  DEC(RH, 3);
  G.PatchB(skipSecond, mergeEntry);
  xa.mode := Reg;
  xa.type := ST.boolType;
  xa.r := pl;
  xa.a := 0; xa.b := 0; xa.rdo := FALSE
END CmpStrings;

PROCEDURE Assign*(VAR x, y: Item);
VAR size, q, rt: INTEGER;
BEGIN
  IF x.rdo THEN S.Mark(E.readOnly)
  ELSIF (x.type.form = ST.Char) & (y.type.form = ST.String)
      & (y.mode = ST.Const) & (y.type.len = 2) THEN
    AssignCharFromString(x, y)
  ELSIF ST.IsCharArrayType(x.type) & (y.type.form = ST.String) & (y.mode = ST.Const) THEN
    IF x.type.len < y.type.len THEN S.Mark(E.stringTooLong)
    ELSE
      LoadAddr(x);
      q := x.r;
      rt := AllocR();
      G.LoadStringAddr(rt, M.SHORT(y.a));
      size := 0;
      WHILE size < y.type.size DO
        G.LdrImm(RH, rt, size, 2);
        G.StrImm(RH, q, size, 2);
        INC(size, 2)
      END;
      DEC(RH, 2)
    END
  ELSIF (y.mode = ST.Const) & ~ST.TypesCompatible(x.type, y.type) THEN
    S.Mark(E.incompatible)
  ELSIF (y.mode # ST.Const) & ~ST.TypeAssignable(x.type, y.type) THEN
    S.Mark(E.incompatible)
  ELSIF x.mode = RegI THEN
    Load(y);
    IF x.type.form = ST.Real THEN
      G.FStrImm(y.r, x.r, 0)
    ELSE
      G.StrImm(y.r, x.r, 0, x.type.size)
    END;
    DEC(RH, 2)
  ELSIF x.mode = ST.Var THEN
    Load(y); (* x -- Var, y -- Reg *)
    IF x.b > 0 THEN (* local variable *)
      IF x.type.form = ST.Real THEN
        G.FStrImm(y.r, FP, M.SHORT(x.a))
      ELSE
        G.StrImm(y.r, FP, M.SHORT(x.a), x.type.size)
      END
    ELSE (* global variable *)
      IF x.type.form = ST.Real THEN
        G.LoadDataPage(RH);
        G.FStrImm(y.r, RH, M.SHORT(x.a))
      ELSE
        G.LoadDataPage(RH);
        G.StrImm(y.r, RH, M.SHORT(x.a), x.type.size)
      END
    END;
    DEC(RH)
  ELSIF x.mode = ST.VarPar THEN (* VAR parameter assignment *)
    Load(y);
    G.LdrImm(RH, FP, M.SHORT(x.a), 8); (* load pointer *)
    IF x.type.form = ST.Real THEN
      G.FStrImm(y.r, RH, 0)
    ELSE
      G.StrImm(y.r, RH, 0, x.type.size)
    END;
    DEC(RH)
  ELSE
    S.Mark(E.assignConst)
  END
END Assign;

(** Bounds check for an array index. For closed arrays len > 0 and the
    compare is against the constant. For open arrays len = 0 and the actual
    length is loaded at runtime from FP[lenAddr]. *)
PROCEDURE CheckIndexBounds(idxReg, len, lenAddr: INTEGER);
VAR okL, lenReg: INTEGER;
BEGIN
  IF len > 0 THEN
    IF len <= 0FFFH THEN
      G.CmpImm(idxReg, len)
    ELSE
      G.MovImm(RH, len);
      G.Cmp(idxReg, RH)
    END
  ELSE
    IF idxReg = RH THEN lenReg := RH + 1 ELSE lenReg := RH END;
    G.LdrImm(lenReg, FP, lenAddr, 8);
    G.Cmp(idxReg, lenReg)
  END;
  G.BCond(LO, 0);
  okL := G.Here() - 1;
  G.Brk(1);
  G.PatchBCond(okL, G.Here())
END CheckIndexBounds;


(** Emits code that leaves the dynamic row stride of x's current dimension
    in register RH. The stride equals the product of `numLens` hidden length
    parameters (located at FP+lenBaseAddr+8, +16, ...) multiplied by the
    innermost element size. Must be called when RH is free. *)
PROCEDURE EmitDynStride(lenBaseAddr, numLens, elemSize: INTEGER);
VAR k: INTEGER;
BEGIN
  G.LdrImm(RH, FP, lenBaseAddr + 8, 8);
  k := 2;
  WHILE k <= numLens DO
    G.LdrImm(RH + 1, FP, lenBaseAddr + k * 8, 8);
    G.Mul(RH, RH, RH + 1);
    INC(k)
  END;
  IF elemSize # 1 THEN
    G.MovImm(RH + 1, elemSize);
    G.Mul(RH, RH, RH + 1)
  END
END EmitDynStride;

(** Array indexing. x := x[y].
    x is an array variable, y is the index expression.
    Result: x.mode = RegI or Var (when index is a constant),
    x.type = element type. *)
PROCEDURE Index*(VAR x, y: Item);
VAR elemSize, shift, dynLens: INTEGER;
  dynStride: BOOLEAN;
  t: ST.Type;
BEGIN
  IF x.type.form # ST.Array THEN S.Mark(E.notArray)
  ELSE
    (* dynStride is TRUE when the inner dimension is itself open, so the
       row size must be computed at runtime from the hidden lengths of all
       remaining open inner dimensions. *)
    dynStride := (x.type.openRank > 0) & (x.type.base.form = ST.Array)
               & (x.type.base.openRank > 0);
    IF dynStride THEN
      (* Walk through the remaining OPEN array dims only; stop at the
         first closed array (size = len * base.size, statically known)
         or at the scalar element (size = sizeof(T)). The dynamic stride
         multiplier is then numLens hidden lengths * elemSize. *)
      t := x.type.base;
      WHILE (t.form = ST.Array) & (t.openRank > 0) DO t := t.base END;
      elemSize := t.size;
      dynLens := x.type.base.openRank
    ELSE
      elemSize := x.type.base.size;
      dynLens := 0
    END;
    IF (y.mode = ST.Const) & (x.mode = ST.Var) THEN
      IF (y.a < 0) OR (y.a >= x.type.len) THEN S.Mark(E.indexOutOfBounds) END;
      x.a := x.a + y.a * elemSize
    ELSIF (y.mode = ST.Const) & (x.mode = RegI) THEN
      IF x.type.openRank > 0 THEN
        IF y.a < 0 THEN S.Mark(E.indexOutOfBounds)
        ELSE
          G.MovImm(RH, y.a);
          CheckIndexBounds(RH, x.type.len, x.b)
        END;
        IF dynStride & (y.a # 0) THEN
          EmitDynStride(x.b, dynLens, elemSize);
          G.MovImm(RH + 1, y.a);
          G.Madd(x.r, RH, RH + 1, x.r)
        ELSIF y.a * elemSize # 0 THEN
          G.AddImm(x.r, x.r, M.SHORT(y.a) * elemSize)
        END
      ELSE
        IF (y.a < 0) OR (y.a >= x.type.len) THEN S.Mark(E.indexOutOfBounds) END;
        IF y.a * elemSize # 0 THEN
          G.AddImm(x.r, x.r, M.SHORT(y.a) * elemSize)
        END
      END
    ELSIF x.mode = ST.Var THEN
      Load(y);
      CheckIndexBounds(y.r, x.type.len, x.b);
      IF x.b > 0 THEN (* local array *)
        G.AddImm(RH, FP, M.SHORT(x.a))
      ELSE (* global array *)
        G.LoadDataPage(RH);
        G.AddImm(RH, RH, M.SHORT(x.a))
      END;
      shift := Log2(elemSize);
      IF shift >= 0 THEN
        G.AddLsl(y.r, RH, y.r, shift)
      ELSE
        G.MovImm(RH + 1, elemSize);
        G.Madd(y.r, y.r, RH + 1, RH)
      END;
      x.mode := RegI; (* x.mode was Var before this *)
      x.r := y.r
    ELSIF x.mode = RegI THEN
      Load(y);
      CheckIndexBounds(y.r, x.type.len, x.b);
      IF dynStride THEN
        EmitDynStride(x.b, dynLens, elemSize);
        G.Madd(x.r, y.r, RH, x.r)
      ELSE
        shift := Log2(elemSize);
        IF shift >= 0 THEN
          G.AddLsl(x.r, x.r, y.r, shift)
        ELSE
          G.MovImm(RH, elemSize);
          G.Madd(x.r, y.r, RH, x.r)
        END
      END;
      DEC(RH)
    ELSIF x.mode = ST.VarPar THEN (* VAR parameter: load pointer, then index *)
      G.LdrImm(RH, FP, M.SHORT(x.a), 8); (* load array base address *)
      x.r := AllocR();
      IF y.mode = ST.Const THEN
        IF x.type.openRank > 0 THEN
          IF y.a < 0 THEN S.Mark(E.indexOutOfBounds)
          ELSE
            G.MovImm(RH, y.a);
            CheckIndexBounds(RH, x.type.len, x.b)
          END
        ELSIF (y.a < 0) OR (y.a >= x.type.len) THEN
          S.Mark(E.indexOutOfBounds)
        END;
        IF dynStride & (y.a # 0) THEN
          EmitDynStride(x.b, dynLens, elemSize);
          G.MovImm(RH + 1, y.a);
          G.Madd(x.r, RH, RH + 1, x.r)
        ELSIF y.a * elemSize # 0 THEN
          G.AddImm(x.r, x.r, M.SHORT(y.a) * elemSize)
        END
      ELSE
        Load(y);
        CheckIndexBounds(y.r, x.type.len, x.b);
        IF dynStride THEN
          EmitDynStride(x.b, dynLens, elemSize);
          G.Madd(x.r, y.r, RH, x.r)
        ELSE
          shift := Log2(elemSize);
          IF shift >= 0 THEN
            G.AddLsl(x.r, x.r, y.r, shift)
          ELSE
            G.MovImm(RH, elemSize);
            G.Madd(x.r, y.r, RH, x.r)
          END
        END;
        DEC(RH)
      END;
      x.mode := RegI
    ELSE S.Mark(E.notArray)
    END;
    IF (x.type.openRank > 0) & (x.type.base.form = ST.Array)
        & (x.type.base.openRank > 0) THEN
      (* After descending one dim, the next dim's hidden length is 8 bytes further. *)
      x.b := x.b + 8
    END;
    x.type := x.type.base
  END
END Index;

PROCEDURE Fixup*(VAR x: Item);
BEGIN FixLink(M.SHORT(x.a))
END Fixup;

(** Conditional forward jump. *)
PROCEDURE CFJump*(VAR x: Item);
BEGIN
  LoadCond(x);
  IF x.r = AL THEN
    (* Const TRUE: condition always true, never jump to false branch *)
    FixLink(x.b);
    x.b := 0
  ELSIF x.r = NV THEN
    (* Const FALSE: always jump to false branch *)
    FixLink(x.b);
    x.b := 0;
    G.BCond(AL, M.SHORT(x.a));
    x.a := G.Here() - 1
  ELSE
    FixLink(x.b);
    x.b := 0;
    G.BCond(Negated(x.r), M.SHORT(x.a));
    x.a := G.Here() - 1
  END
END CFJump;

(** Forward jump. *)
PROCEDURE FJump*(VAR L: INTEGER);
BEGIN
  (* Emit B.cond(AL) — always taken; chain previous L *)
  G.BCond(14 (* AL *), L);
  L := G.Here() - 1
END FJump;

(** Backward jump. *)
PROCEDURE BJump*(L: INTEGER);
BEGIN
  G.B(L - G.Here())
END BJump;

(** Conditional backward jump. *)
PROCEDURE CBJump*(VAR x: Item; L: INTEGER);
VAR here: INTEGER;
BEGIN
  LoadCond(x);
  IF x.r = AL THEN
    (* Const TRUE: condition always true, exit loop (no backward jump) *)
    FixLink(x.b)
  ELSIF x.r = NV THEN
    (* Const FALSE: always loop back *)
    G.B(L - G.Here())
  ELSE
    here := G.Here();
    (* Emit B.cond(Negated(x.r)) backward to L — loop while condition FALSE *)
    G.BCond(Negated(x.r), L - here);
    (* x.b = true-list: condition TRUE elsewhere → exit → land after this instr *)
    FixLink(x.b);
    (* x.a = false-list: condition FALSE elsewhere → also loop back to L *)
    FixLinkWith(M.SHORT(x.a), L)
  END
END CBJump;

PROCEDURE MergeLists(L1, L2: INTEGER): INTEGER;
VAR L, prevL, instr, cond: INTEGER;
BEGIN
  IF L1 = 0 THEN L1 := L2
  ELSIF L2 # 0 THEN
    (* Walk to tail of L1 (element with imm19 = 0) *)
    L := L1;
    REPEAT prevL := L; L := G.ImmFromBCond(L) UNTIL L = 0;
    (* Splice: make tail of L1 point to head of L2 *)
    instr := G.ReadWord(prevL);
    cond  := instr MOD 10H;
    G.WriteWord(prevL, 54000000H + (L2 MOD 80000H) * 20H + cond)
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
  x.a := MergeLists(M.SHORT(y.a), M.SHORT(x.a));
  x.b := y.b; x.r := y.r
END And2;

(** x := x OR *)
PROCEDURE Or1*(VAR x: Item);
BEGIN
  LoadCond(x);
  IF x.r = AL THEN
    FixLink(M.SHORT(x.a));
    x.a := 0
  ELSIF x.r = NV THEN
    FixLink(M.SHORT(x.a));
    x.a := 0
  ELSE
    FixLink(M.SHORT(x.a));
    x.a := 0;
    G.BCond(x.r, x.b);
    x.b := G.Here() - 1
  END
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

PROCEDURE LoadParamLen*(VAR x: Item; address: INTEGER);
BEGIN
  x.mode := Reg;
  x.type := ST.intType;
  x.rdo := FALSE;
  x.r := AllocR();
  G.LdrImm(x.r, FP, address, 8)
END LoadParamLen;

(** Called before Actual Parameters.
    Saves live registers x0..x(RH-1) to stack if any. *)
PROCEDURE PrepCall*(VAR x: Item; VAR rx: INTEGER);
VAR i: INTEGER;
BEGIN
  rx := RH;
  IF RH > 0 THEN
    G.AddImm(SP, SP, -(((RH + 1) DIV 2) * 16));
    FOR i := 0 TO RH - 1 DO
      G.StrImm(i, SP, i * 8, 8)
    END;
    RH := 0
  END
END PrepCall;

(** Called after Actual Parameters.
    proc is the target procedure object for direct calls (used for
    forward-reference resolution). *)
PROCEDURE Call*(VAR x: Item; rx: INTEGER; proc: ST.Object);
VAR skipNeg, loop1, exitLoop1, loop2, exitLoop2, i: INTEGER;
  ocChk2, ocB0, ocChk3, ocBA0, ocWrite: INTEGER;
  osLoop, osFlushEnd, osNoFlush, osBR1, osBR2,
    osChk2, osChkSurr, os3byte,
    osNoSurrA, osNoSurrB, osNoSurrC, osNoSurrD, osNoSurrE,
    osSkipFlushWrite: INTEGER;
  icChk2, icChk3, ic1done, ic2done: INTEGER;
  iiLoop, iiSkip, iiNeg, iiDigit, iiApply: INTEGER;
  iiEnd1, iiEnd2, iiEnd3, iiEnd4, iiEnd5, iiEnd6: INTEGER;
  ilLoop, ilChk2, ilChk3, ilChk4: INTEGER;
  ilEnd1, ilEnd2, ilEnd3, ilSurrEnd, ilCrSkip: INTEGER;
BEGIN
  ASSERT(proc # NIL);
  (* x.a < 0: inline call ID; x.a >= 0: user procedure word offset *)
  IF x.a = -1 (* In.Char *) THEN
    (* On entry: x0 = ptr to CHAR (2 bytes). Read one UTF-8 char from stdin. *)
    G.Mov(9, 0);                  (* x9 := dest ptr *)
    G.AddImm(SP, SP, -16);
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 1);
    G.MovImm(16, 3); G.Svc(0);   (* read(0, SP, 1) *)
    G.LdrImm(10, SP, 0, 1);      (* x10 := first byte *)
    G.CmpImm(10, 80H);
    G.BCond(2 (* HS *), 0); icChk2 := G.Here() - 1;
    (* 1-byte: ASCII *)
    G.StrImm(10, 9, 0, 2);
    G.B(0); ic1done := G.Here() - 1;

    G.PatchBCond(icChk2, G.Here());
    G.CmpImm(10, 0E0H);
    G.BCond(2 (* HS *), 0); icChk3 := G.Here() - 1;
    (* 2-byte UTF-8: 110xxxxx 10xxxxxx *)
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 1);
    G.MovImm(16, 3); G.Svc(0);
    G.LdrImm(11, SP, 0, 1);
    G.MovImm(12, 1FH); G.And(10, 10, 12);
    G.MovImm(12, 3FH); G.And(11, 11, 12);
    G.AddLsl(10, 11, 10, 6);
    G.StrImm(10, 9, 0, 2);
    G.B(0); ic2done := G.Here() - 1;

    G.PatchBCond(icChk3, G.Here());
    (* 3-byte UTF-8: 1110xxxx 10xxxxxx 10xxxxxx *)
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 2);
    G.MovImm(16, 3); G.Svc(0);
    G.LdrImm(11, SP, 0, 1); G.LdrImm(12, SP, 1, 1);
    G.MovImm(13, 0FH);  G.And(10, 10, 13);
    G.MovImm(13, 3FH);
    G.And(11, 11, 13); G.And(12, 12, 13);
    G.AddLsl(10, 11, 10, 6);
    G.AddLsl(10, 12, 10, 6);
    G.StrImm(10, 9, 0, 2);

    G.PatchB(ic1done, G.Here());
    G.PatchB(ic2done, G.Here());
    G.AddImm(SP, SP, 16)

  ELSIF x.a = -2 (* In.Int *) THEN
    (* On entry: x0 = ptr to INTEGER (8 bytes). Read decimal integer from stdin.
       Skips leading whitespace; stops at first non-digit after digits. *)
    G.Mov(9, 0);                  (* x9 := dest ptr *)
    G.AddImm(SP, SP, -16);
    G.MovImm(10, 0);              (* x10 := accumulated result *)
    G.MovImm(11, 0);              (* x11 := sign flag (0=pos, 1=neg) *)
    (* Skip whitespace loop *)
    iiLoop := G.Here();
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 1);
    G.MovImm(16, 3); G.Svc(0);
    G.CmpImm(0, 0);
    G.BCond(0 (* EQ *), 0); iiEnd1 := G.Here() - 1;
    G.LdrImm(12, SP, 0, 1);
    G.CmpImm(12, 20H); G.BCond(0 (* EQ *), iiLoop - G.Here());
    G.CmpImm(12, 0AH); G.BCond(0 (* EQ *), iiLoop - G.Here());
    G.CmpImm(12, 0DH); G.BCond(0 (* EQ *), iiLoop - G.Here());
    G.CmpImm(12, 09H); G.BCond(0 (* EQ *), iiLoop - G.Here());
    (* Not whitespace — check for minus *)
    G.CmpImm(12, 2DH);
    G.BCond(1 (* NE *), 0); iiNeg := G.Here() - 1;
    G.MovImm(11, 1);             (* sign := negative *)
    G.B(0); iiDigit := G.Here() - 1;

    G.PatchBCond(iiNeg, G.Here());
    (* First non-whitespace char: check if digit *)
    G.CmpImm(12, 30H);
    G.BCond(3 (* LO *), 0); iiEnd2 := G.Here() - 1;
    G.CmpImm(12, 3AH);
    G.BCond(2 (* HS *), 0); iiEnd3 := G.Here() - 1;
    G.AddImm(12, 12, -30H);
    G.MovImm(13, 10);
    G.Madd(10, 10, 13, 12);

    (* Digit loop: read more digits *)
    G.PatchB(iiDigit, G.Here());
    iiDigit := G.Here();
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 1);
    G.MovImm(16, 3); G.Svc(0);
    G.CmpImm(0, 0);
    G.BCond(0 (* EQ *), 0); iiEnd4 := G.Here() - 1;
    G.LdrImm(12, SP, 0, 1);
    G.CmpImm(12, 30H);
    G.BCond(3 (* LO *), 0); iiEnd5 := G.Here() - 1;
    G.CmpImm(12, 3AH);
    G.BCond(2 (* HS *), 0); iiEnd6 := G.Here() - 1;
    G.AddImm(12, 12, -30H);
    G.MovImm(13, 10);
    G.Madd(10, 10, 13, 12);
    G.B(iiDigit - G.Here());

    (* Done: apply sign, store *)
    i := G.Here();
    G.PatchBCond(iiEnd1, i); G.PatchBCond(iiEnd2, i);
    G.PatchBCond(iiEnd3, i); G.PatchBCond(iiEnd4, i);
    G.PatchBCond(iiEnd5, i); G.PatchBCond(iiEnd6, i);
    G.CmpImm(11, 0);
    G.BCond(0 (* EQ *), 0); iiApply := G.Here() - 1;
    G.Neg(10, 10);
    G.PatchBCond(iiApply, G.Here());
    G.StrImm(10, 9, 0, 8);
    G.AddImm(SP, SP, 16)

  ELSIF x.a = -3 (* In.Line *) THEN
    (* On entry: x0 = ptr to ARRAY OF CHAR, x1 = LEN (CHAR count).
       Read UTF-8 line from stdin, decode to UTF-16LE CHARs, NUL-terminate.
       Stops at newline (consumed but not stored) or when array full. *)
    G.Mov(3, 0);                  (* x3 := array base ptr *)
    G.AddImm(4, 1, -1);          (* x4 := maxChars (LEN - 1, for NUL) *)
    G.MovImm(5, 0);              (* x5 := charIdx *)
    G.AddImm(SP, SP, -16);

    ilLoop := G.Here();
    G.Cmp(5, 4);
    G.BCond(2 (* HS *), 0); ilEnd1 := G.Here() - 1;
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 1);
    G.MovImm(16, 3); G.Svc(0);
    G.CmpImm(0, 0);
    G.BCond(0 (* EQ *), 0); ilEnd2 := G.Here() - 1;
    G.LdrImm(6, SP, 0, 1);
    G.CmpImm(6, 0AH);
    G.BCond(0 (* EQ *), 0); ilEnd3 := G.Here() - 1;
    G.CmpImm(6, 0DH);
    G.BCond(0 (* EQ *), ilLoop - G.Here()); (* skip CR, loop back *)

    G.CmpImm(6, 80H);
    G.BCond(2 (* HS *), 0); ilChk2 := G.Here() - 1;
    (* 1-byte ASCII *)
    G.AddLsl(7, 3, 5, 1);
    G.StrImm(6, 7, 0, 2);
    G.AddImm(5, 5, 1);
    G.B(ilLoop - G.Here());

    G.PatchBCond(ilChk2, G.Here());
    G.CmpImm(6, 0E0H);
    G.BCond(2 (* HS *), 0); ilChk3 := G.Here() - 1;
    (* 2-byte UTF-8 *)
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 1);
    G.MovImm(16, 3); G.Svc(0);
    G.LdrImm(7, SP, 0, 1);
    G.MovImm(8, 1FH); G.And(6, 6, 8);
    G.MovImm(8, 3FH); G.And(7, 7, 8);
    G.AddLsl(6, 7, 6, 6);
    G.AddLsl(7, 3, 5, 1);
    G.StrImm(6, 7, 0, 2);
    G.AddImm(5, 5, 1);
    G.B(ilLoop - G.Here());

    G.PatchBCond(ilChk3, G.Here());
    G.CmpImm(6, 0F0H);
    G.BCond(2 (* HS *), 0); ilChk4 := G.Here() - 1;
    (* 3-byte UTF-8 *)
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 2);
    G.MovImm(16, 3); G.Svc(0);
    G.LdrImm(7, SP, 0, 1); G.LdrImm(8, SP, 1, 1);
    G.MovImm(10, 0FH); G.And(6, 6, 10);
    G.MovImm(10, 3FH); G.And(7, 7, 10); G.And(8, 8, 10);
    G.AddLsl(6, 7, 6, 6);
    G.AddLsl(6, 8, 6, 6);
    G.AddLsl(7, 3, 5, 1);
    G.StrImm(6, 7, 0, 2);
    G.AddImm(5, 5, 1);
    G.B(ilLoop - G.Here());

    G.PatchBCond(ilChk4, G.Here());
    (* 4-byte UTF-8 -> surrogate pair *)
    G.MovImm(0, 0); G.Mov(1, SP); G.MovImm(2, 3);
    G.MovImm(16, 3); G.Svc(0);
    G.LdrImm(7, SP, 0, 1); G.LdrImm(8, SP, 1, 1); G.LdrImm(10, SP, 2, 1);
    G.MovImm(11, 7); G.And(6, 6, 11);
    G.MovImm(11, 3FH);
    G.And(7, 7, 11); G.And(8, 8, 11); G.And(10, 10, 11);
    G.AddLsl(6, 7, 6, 6);
    G.AddLsl(6, 8, 6, 6);
    G.AddLsl(6, 10, 6, 6);
    G.MovImm(11, 10000H); G.Sub(6, 6, 11);
    G.AsrImm(7, 6, 10);
    G.MovImm(11, 0D800H); G.Add(7, 7, 11);
    G.AddLsl(8, 3, 5, 1);
    G.StrImm(7, 8, 0, 2);
    G.AddImm(5, 5, 1);
    G.Cmp(5, 4);
    G.BCond(2 (* HS *), 0); ilSurrEnd := G.Here() - 1;
    G.MovImm(11, 3FFH); G.And(7, 6, 11);
    G.MovImm(11, 0DC00H); G.Add(7, 7, 11);
    G.AddLsl(8, 3, 5, 1);
    G.StrImm(7, 8, 0, 2);
    G.AddImm(5, 5, 1);
    G.B(ilLoop - G.Here());

    (* NUL-terminate *)
    i := G.Here();
    G.PatchBCond(ilEnd1, i); G.PatchBCond(ilEnd2, i);
    G.PatchBCond(ilEnd3, i); G.PatchBCond(ilSurrEnd, i);
    G.AddLsl(7, 3, 5, 1);
    G.MovImm(6, 0);
    G.StrImm(6, 7, 0, 2);
    G.AddImm(SP, SP, 16)

  ELSIF x.a = -5 (* Out.Char *) THEN
    (* On entry: w0 = c (CHAR, UCS-2). Encode to UTF-8 (1..3 bytes), then write.
       Lone surrogates are emitted as a 3-byte CESU-8 sequence. *)
    G.AddImm(SP, SP, -16);
    G.MovImm(11, 3FH);          (* mask for low 6 bits *)
    G.MovImm(13, 80H);          (* continuation marker *)
    G.CmpImm(0, 80H);
    G.BCond(2 (* HS *), 0); ocChk2 := G.Here() - 1;
    (* 1 byte: c < 0x80 *)
    G.StrImm(0, SP, 0, 1);
    G.MovImm(2, 1);
    G.B(0); ocB0 := G.Here() - 1;
    G.PatchBCond(ocChk2, G.Here());
    G.CmpImm(0, 800H);
    G.BCond(2 (* HS *), 0); ocChk3 := G.Here() - 1;
    (* 2 bytes: 0x80 <= c < 0x800 *)
    G.AsrImm(14, 0, 6);
    G.AddImm(14, 14, 0C0H);
    G.StrImm(14, SP, 0, 1);
    G.And(15, 0, 11);
    G.Add(15, 15, 13);
    G.StrImm(15, SP, 1, 1);
    G.MovImm(2, 2);
    G.B(0); ocBA0 := G.Here() - 1;
    G.PatchBCond(ocChk3, G.Here());
    (* 3 bytes: c >= 0x800 *)
    G.AsrImm(14, 0, 12);
    G.AddImm(14, 14, 0E0H);
    G.StrImm(14, SP, 0, 1);
    G.AsrImm(14, 0, 6);
    G.And(14, 14, 11);
    G.Add(14, 14, 13);
    G.StrImm(14, SP, 1, 1);
    G.And(14, 0, 11);
    G.Add(14, 14, 13);
    G.StrImm(14, SP, 2, 1);
    G.MovImm(2, 3);
    ocWrite := G.Here();
    G.PatchB(ocB0, ocWrite);
    G.PatchB(ocBA0, ocWrite);
    G.MovImm(0, 1);
    G.Mov(1, SP);
    G.MovImm(16, 4);
    G.Svc(0);
    G.AddImm(SP, SP, 16)
  ELSIF x.a = -10 (* Out.String *) THEN
    (* Inputs: x0 = ptr (UTF-16LE), x1 = LEN in CHAR elements.
       Encode UTF-16 -> UTF-8 into a 64-byte stack buffer; flush via write(2)
       when the buffer fills (>= 60 bytes used) and at end. Surrogate pairs
       (D800..DBFF + DC00..DFFF) are decoded to a single codepoint and
       emitted as 4 UTF-8 bytes; lone surrogates fall back to 3-byte CESU-8.
       Registers: x3=ptr, x12=maxBytes, x9=inOff, x4=buf, x5=outOff,
                  x6=hi, x7=lo/scratch, x8=bigConst, x10=writeBase,
                  x11=0x3F, x13=0x80, x14/x15=encode scratch. *)
    G.AddImm(SP, SP, -64);
    G.Mov(3, 0);
    G.Add(12, 1, 1);
    G.MovImm(9, 0);
    G.MovImm(5, 0);
    G.Mov(4, SP);
    G.MovImm(11, 3FH);
    G.MovImm(13, 80H);

    osLoop := G.Here();
    G.Cmp(9, 12);
    G.BCond(2 (* HS *), 0); osBR1 := G.Here() - 1;

    G.CmpImm(5, 60);
    G.BCond(3 (* LO *), 0); osNoFlush := G.Here() - 1;
    G.MovImm(0, 1);
    G.Mov(1, 4);
    G.Mov(2, 5);
    G.MovImm(16, 4);
    G.Svc(0);
    G.MovImm(5, 0);
    G.PatchBCond(osNoFlush, G.Here());

    G.LdrReg(6, 3, 9, 2);
    G.CmpImm(6, 0);
    G.BCond(0 (* EQ *), 0); osBR2 := G.Here() - 1;

    G.Add(10, 4, 5);

    G.CmpImm(6, 80H);
    G.BCond(2 (* HS *), 0); osChk2 := G.Here() - 1;
    (* 1 byte: c < 0x80 *)
    G.StrImm(6, 10, 0, 1);
    G.AddImm(5, 5, 1);
    G.AddImm(9, 9, 2);
    G.B(osLoop - G.Here());

    G.PatchBCond(osChk2, G.Here());
    G.CmpImm(6, 800H);
    G.BCond(2 (* HS *), 0); osChkSurr := G.Here() - 1;
    (* 2 bytes: 0x80..0x7FF *)
    G.AsrImm(14, 6, 6);
    G.AddImm(14, 14, 0C0H);
    G.StrImm(14, 10, 0, 1);
    G.And(15, 6, 11);
    G.Add(15, 15, 13);
    G.StrImm(15, 10, 1, 1);
    G.AddImm(5, 5, 2);
    G.AddImm(9, 9, 2);
    G.B(osLoop - G.Here());

    G.PatchBCond(osChkSurr, G.Here());
    (* c >= 0x800: handle surrogate pair or 3-byte BMP *)
    G.MovImm(7, 0D800H);
    G.Cmp(6, 7);
    G.BCond(3 (* LO *), 0); osNoSurrA := G.Here() - 1;  (* c < 0xD800 -> 3byte *)
    G.MovImm(7, 0DC00H);
    G.Cmp(6, 7);
    G.BCond(2 (* HS *), 0); osNoSurrB := G.Here() - 1;  (* c >= 0xDC00 -> 3byte CESU-8 or BMP *)

    (* high surrogate; check next CHAR exists *)
    G.AddImm(7, 9, 2);
    G.Cmp(7, 12);
    G.BCond(2 (* HS *), 0); osNoSurrC := G.Here() - 1;  (* no next -> 3byte CESU-8 *)
    G.LdrReg(7, 3, 7, 2);
    G.MovImm(8, 0DC00H);
    G.Cmp(7, 8);
    G.BCond(3 (* LO *), 0); osNoSurrD := G.Here() - 1;  (* not low surr *)
    G.MovImm(8, 0E000H);
    G.Cmp(7, 8);
    G.BCond(2 (* HS *), 0); osNoSurrE := G.Here() - 1;  (* not low surr *)

    (* surrogate pair: cp = (hi - D800) << 10 + (lo - DC00) + 0x10000 *)
    G.MovImm(8, 0D800H);
    G.Sub(6, 6, 8);
    G.MovImm(8, 0DC00H);
    G.Sub(7, 7, 8);
    G.AddLsl(14, 7, 6, 10);
    G.MovImm(8, 10000H);
    G.Add(14, 14, 8);

    G.AsrImm(15, 14, 18);
    G.AddImm(15, 15, 0F0H);
    G.StrImm(15, 10, 0, 1);
    G.AsrImm(15, 14, 12);
    G.And(15, 15, 11);
    G.Add(15, 15, 13);
    G.StrImm(15, 10, 1, 1);
    G.AsrImm(15, 14, 6);
    G.And(15, 15, 11);
    G.Add(15, 15, 13);
    G.StrImm(15, 10, 2, 1);
    G.And(15, 14, 11);
    G.Add(15, 15, 13);
    G.StrImm(15, 10, 3, 1);
    G.AddImm(5, 5, 4);
    G.AddImm(9, 9, 4);  (* consumed 2 CHARs *)
    G.B(osLoop - G.Here());

    (* 3-byte path: BMP non-surrogate or lone surrogate (CESU-8) *)
    os3byte := G.Here();
    G.PatchBCond(osNoSurrA, os3byte);
    G.PatchBCond(osNoSurrB, os3byte);
    G.PatchBCond(osNoSurrC, os3byte);
    G.PatchBCond(osNoSurrD, os3byte);
    G.PatchBCond(osNoSurrE, os3byte);
    G.AsrImm(14, 6, 12);
    G.AddImm(14, 14, 0E0H);
    G.StrImm(14, 10, 0, 1);
    G.AsrImm(14, 6, 6);
    G.And(14, 14, 11);
    G.Add(14, 14, 13);
    G.StrImm(14, 10, 1, 1);
    G.And(14, 6, 11);
    G.Add(14, 14, 13);
    G.StrImm(14, 10, 2, 1);
    G.AddImm(5, 5, 3);
    G.AddImm(9, 9, 2);
    G.B(osLoop - G.Here());

    (* tail flush + epilogue *)
    osFlushEnd := G.Here();
    G.PatchBCond(osBR1, osFlushEnd);
    G.PatchBCond(osBR2, osFlushEnd);
    G.CmpImm(5, 0);
    G.BCond(0 (* EQ *), 0); osSkipFlushWrite := G.Here() - 1;
    G.MovImm(0, 1);
    G.Mov(1, 4);
    G.Mov(2, 5);
    G.MovImm(16, 4);
    G.Svc(0);
    G.PatchBCond(osSkipFlushWrite, G.Here());
    G.AddImm(SP, SP, 64)
  ELSIF x.a = -6 (* Out.Int *) THEN
    (* Print integer as decimal text.
       On entry: x0 = i (LONGINT), w1 = n (ignored).
       Scratch registers: x9=value, x10=divisor, x11=digit, x12=mod scratch, x13=div scratch *)
    G.AddImm(SP, SP, -16);

    (* x9 := i (already 64-bit if LONGINT; narrower types widened by calling convention) *)
    G.Mov(9, 0);

    (* IF i < 0 THEN print '-'; i := -i END *)
    G.CmpImm(9, 0);           (* CMP x9, #0 *)
    skipNeg := G.Here();
    G.BCond(10 (* GE *), 0);  (* B.GE skipNeg — skip if i >= 0 *)

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
    exitLoop1 := G.Here();
    G.BCond(12 (* GT *), 0);  (* B.GT exitLoop1 *)
    G.MovImm(11, 10);         (* x11 := 10 *)
    G.Mul(10, 10, 11);        (* x10 := x10 * 10 *)
    G.B(loop1 - G.Here());  (* B loop1 *)
    FixLink(exitLoop1);       (* exitLoop1: *)

    (* WHILE x # 0 DO Out.Char(CHR(i DIV x MOD 10 + 30H)); x := x DIV 10 END *)
    loop2 := G.Here();
    G.CmpImm(10, 0);          (* CMP x10, #0 *)
    exitLoop2 := G.Here();
    G.BCond(0 (* EQ *), 0);   (* B.EQ exitLoop2 *)

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
    G.B(loop2 - G.Here());  (* B loop2 *)
    FixLink(exitLoop2);       (* exitLoop2: *)

    G.AddImm(SP, SP, 16)      (* sp := sp + 16 *)
  ELSIF x.a = -7 (* Out.Ln *) THEN
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
  ELSE (* user-defined procedure call *)
    IF x.mode = ST.Const THEN (* direct call *)
      IF ~proc.procResolved THEN
        (* Forward reference: emit BL with head-link, chain via imm26 *)
        G.Bl(proc.fixupList);
        proc.fixupList := G.Here() - 1
      ELSE
        G.Bl(M.SHORT(x.a) - G.Here())
      END
    ELSE (* indirect call via procedure variable *)
      Load(x);
      G.Blr(x.r);
      DEC(RH)
    END
  END;
  (* Restore saved registers and place result *)
  IF rx > 0 THEN
    (* Function result is in x0; save it temporarily *)
    IF x.type.base.form # ST.NoTyp THEN
      G.Mov(rx, 0)
    END;
    FOR i := 0 TO rx - 1 DO
      G.LdrImm(i, SP, i * 8, 8)
    END;
    G.AddImm(SP, SP, ((rx + 1) DIV 2) * 16);
    RH := rx
  ELSE
    RH := 0
  END
END Call;

(** Resolves all forward references to procedure p by patching each BL in
    its fixup chain to land at p.address. Walks the chain linked through
    BL imm26 fields (analogous to FixLinkWith for B.cond). *)
PROCEDURE ResolveProc*(p: ST.Object);
VAR L, nextL, target: INTEGER;
BEGIN
  target := M.SHORT(p.address);
  L := p.fixupList;
  WHILE L # 0 DO
    nextL := G.ImmFromBl(L);
    G.PatchBl(L, target);
    L := nextL
  END;
  p.fixupList := 0;
  p.procResolved := TRUE
END ResolveProc;

(** Procedure prologue: save FP, LR, allocate locals.
    frameSize must be 16-byte aligned, includes saved FP/LR (16 bytes).
    nofPars = number of value/var parameters (max 8).
    parSize = total size of parameters in frame in bytes. *)
PROCEDURE ProcPrologue*(frameSize, nofPars, parSize: INTEGER);
VAR i: INTEGER;
BEGIN
  G.Stp(FP, LR, SP, -frameSize); (* STP x29, x30, [sp, #-frameSize]! *)
  G.Mov(FP, SP);                 (* MOV x29, sp *)
  (* Store register parameters into frame *)
  FOR i := 0 TO nofPars - 1 DO
    G.StrImm(i, FP, 16 + i * 8, 8) (* STR xi, [x29, #16+i*8] *)
  END
END ProcPrologue;

(** Procedure epilogue: restore FP, LR, return *)
PROCEDURE ProcEpilogue*(frameSize: INTEGER);
BEGIN
  G.Ldp(FP, LR, SP, frameSize); (* LDP x29, x30, [sp], #frameSize *)
  G.Ret()                       (* RET *)
END ProcEpilogue;

(** Load function return value into x0 *)
PROCEDURE ReturnVal*(VAR x: Item);
BEGIN
  Load(x);
  IF x.r # 0 THEN G.Mov(0, x.r) END;
  RH := 0
END ReturnVal;

(** Set RH to given value (used after function calls to account for result) *)
PROCEDURE FixRH*(val: INTEGER);
BEGIN RH := val
END FixRH;

(** FOR loop support **)

(** Save the FOR end value. If endVal is a constant, just saves the value.
    If it's in a register, moves it to a callee-saved register. *)
PROCEDURE ForSave*(VAR endVal: Item; VAR savedConst: LONGINT;
    VAR endReg: INTEGER);
BEGIN
  IF endVal.mode = ST.Const THEN
    savedConst := endVal.a;
    endReg := -1
  ELSE
    Load(endVal);
    endReg := AllocS();
    G.Mov(endReg, endVal.r);
    DEC(RH)
  END
END ForSave;

(** Generate FOR loop condition check. Compares loop variable with saved end
    value. step > 0: exits when loopVar > end. step < 0: exits when < end. *)
PROCEDURE ForCond*(obj: ST.Object;
    endReg: INTEGER; endConst: LONGINT; step: INTEGER; VAR x: Item);
VAR loopVar, endItem: Item;
  cond: INTEGER;
BEGIN
  MakeItem(loopVar, obj); (* loadVar.mode = ST.Var *)
  IF endReg = -1 THEN (* end is a constant *)
    MakeConstItem(endItem, obj.type, endConst);
    IF step > 0 THEN IntRel(S.leq, loopVar, endItem)
    ELSE IntRel(S.geq, loopVar, endItem)
    END
  ELSE
    ASSERT((firstCSReg <= endReg) & (endReg <= maxCSReg));
    Load(loopVar); (* Allocates a register *)
    IF loopVar.type.size = 2 THEN G.Sxth(loopVar.r, loopVar.r)
    ELSIF loopVar.type.size = 4 THEN G.Sxtw(loopVar.r, loopVar.r)
    END;
    G.Cmp(loopVar.r, endReg);
    DEC(RH);
    IF step > 0 THEN cond := LE ELSE cond := GE END;
    SetCond(loopVar, cond)
  END;
  x := loopVar
END ForCond;

(** Free the callee-saved register after a FOR loop if one was allocated. *)
PROCEDURE ForClean*(endReg: INTEGER);
BEGIN
  IF endReg # -1 THEN
    ASSERT((firstCSReg <= endReg) & (endReg <= maxCSReg));
    FreeS
  END
END ForClean;

(** CASE statement support **)

(** Load case expression value into a register. *)
PROCEDURE CaseSave*(VAR x: Item);
BEGIN
  Load(x);
  IF x.type.size = 2 THEN G.Sxth(x.r, x.r)
  ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r)
  END
END CaseSave;

(** Compare case expression with a single value.
    Emits conditional jump chained into matchList when equal. *)
PROCEDURE CaseLabel*(VAR x: Item; val: INTEGER; VAR matchList: INTEGER);
BEGIN
  IF (val >= 0) & (val < 1000H) THEN
    G.CmpImm(x.r, val)
  ELSE
    G.MovImm(RH, val);
    G.Cmp(x.r, RH)
  END;
  G.BCond(EQ, matchList);
  matchList := G.Here() - 1
END CaseLabel;

(** Compare case expression with a range [lo..hi].
    Emits conditional jump chained into matchList when in range. *)
PROCEDURE CaseRangeLabel*(VAR x: Item; lo, hi: INTEGER; VAR matchList: INTEGER);
VAR skipPos: INTEGER;
BEGIN
  IF (lo >= 0) & (lo < 1000H) THEN
    G.CmpImm(x.r, lo)
  ELSE
    G.MovImm(RH, lo);
    G.Cmp(x.r, RH)
  END;
  skipPos := G.Here();
  G.BCond(LT, 0);
  IF (hi >= 0) & (hi < 1000H) THEN
    G.CmpImm(x.r, hi)
  ELSE
    G.MovImm(RH, hi);
    G.Cmp(x.r, RH)
  END;
  G.BCond(LE, matchList);
  matchList := G.Here() - 1;
  G.PatchBCond(skipPos, G.Here())
END CaseRangeLabel;

(** Free the case expression register before executing a branch body. *)
PROCEDURE CaseBodyBegin*;
BEGIN
  DEC(RH)
END CaseBodyBegin;

(** Restore the case expression register after a branch body
    so the next branch can compare against it. *)
PROCEDURE CaseBodyEnd*;
BEGIN
  INC(RH)
END CaseBodyEnd;

(** Free the case expression register at the end of the CASE statement. *)
PROCEDURE CaseClean*;
BEGIN
  DEC(RH)
END CaseClean;

(** - **)

(** Generates code that terminates the program. *)
PROCEDURE Exit*;
BEGIN
  G.Exit
END Exit;

(** Generates a trap instruction for unmatched CASE. *)
PROCEDURE Trap*;
BEGIN
  G.Brk(1)
END Trap;

PROCEDURE Init*;
BEGIN
  RH := 0;
  SH := firstCSReg;

  G.Init
END Init;

PROCEDURE Close*;
BEGIN
  G.Close
END Close;

END Emitter.
