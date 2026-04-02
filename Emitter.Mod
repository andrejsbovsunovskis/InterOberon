MODULE Emitter;
IMPORT ST := SymTable, S := Scanner, G := Generator, E := ErrorMsg, Files, Strings, M := Machine;

CONST
  maxGenReg = 28; (** Max number of general-purpose registers (x0..x28) *)

  (** Values of Item.mode **)
  (** Some of Object Classes from SymTable are also valid *)
  Reg*  = 10;
  RegI* = 11; (** Register indirect: address in register r *)
  Cond* = 12; (** Condition expression result *)

  SP = G.SP;

  (** ARM64 condition codes **)
  EQ = 0;  (** Equal         *)
  NE = 1;  (** Not equal     *)
  GE = 10; (** Signed >=     *)
  LT = 11; (** Signed <      *)
  GT = 12; (** Signed >      *)
  LE = 13; (** Signed <=     *)
  AL = 14; (** Always (true) *)
  NV = 15; (** Never (false) *)

TYPE
  LONGINT = M.LONGINT;

  (** Item is a temporary object that exists during statement parsing.
        |  mode |     a     |     b     |      r      |
        |  Reg  |     -     |     -     | register No |
        | Const |   value   |     -     |      -      |
        |  Var  |  address  |     -     |      -      |
        | RegI  |     -     |     -     | register No |
        | Cond  |    false/true List?   |  cond code  |
  *)
  Item* = RECORD
    mode*: INTEGER; (** See constants above, also Object Classes *)
    type*: ST.Type;
    a*, b*, r*: INTEGER (** Meaning of a, b, r according to the table above *)
  END;

VAR
  RH: INTEGER; (** Number of the highest free register *)
  caseReg: INTEGER; (** Register holding the CASE expression value *)

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
  IF (obj.class = ST.Const) & (obj.constVal # NIL) THEN
    x.a := obj.constVal.intVal
  ELSE
    x.a := M.SHORT(obj.address)
  END
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
      IF x.type.form = ST.Real THEN
        G.MovImm(RH, x.a);
        G.FMovWtoS(RH, RH)
      ELSE
        G.MovImm(RH, x.a)
      END;
      x.r := RH;
      IncR
    ELSIF x.mode = RegI THEN
      IF x.type.form = ST.Real THEN
        G.FLdrImm(x.r, x.r, 0)
      ELSE
        G.LdrImm(x.r, x.r, 0, x.type.size);
        IF x.type.form = ST.ShortInt THEN G.Sxth(x.r, x.r) END
      END;
      cmpNeeded := TRUE
    ELSIF x.mode = ST.Var THEN
      G.Adrp(RH, 2);
      IF x.type.form = ST.Real THEN
        G.FLdrImm(RH, RH, x.a)
      ELSE
        G.LdrImm(RH, RH, x.a, x.type.size); (* LDR* {RH}, [x{RH}, #{x.a}] *)
        IF x.type.form = ST.ShortInt THEN G.Sxth(RH, RH) END
      END;
      cmpNeeded := TRUE;
      x.r := RH;
      IncR
    ELSIF x.mode = Cond THEN
      FixLink(x.b);
      FixLinkWith(x.a, G.Here());
      (* CSINC Xd, xzr, xzr, Negated(x.r) = CSET Xd, x.r *)
      G.CSInc(RH, SP, SP, Negated(x.r));
      x.r := RH;
      IncR
    END;
    x.mode := Reg
  END
END Load;

PROCEDURE LoadAddr(VAR x: Item);
BEGIN
  IF x.mode = ST.Var THEN
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
    x.a := ABS(x.a) MOD 2
  ELSE
    Load(x);
    G.AndImm1(x.r, x.r)
  END
END OddVal;

(** Arithmetic shift right. x := ASR(x, y) *)
PROCEDURE AsrVal*(VAR x, y: Item);
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    x.a := ASR(x.a, y.a)
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
    x.a := LSL(x.a, y.a)
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
    x.a := ROR(x.a, y.a)
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
    x.a := LSL(1, x.a)
  ELSE
    Load(x);
    G.MovImm(RH, 1);
    G.Lsl(x.r, RH, x.r)
  END;
  x.type := ST.setType
END Singleton;

(** Constructs a range set {x..y}. Result in x. *)
PROCEDURE SetRange*(VAR x, y: Item);
VAR mask: INTEGER;
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    (* Build bit range from x.a to y.a *)
    IF y.a < 31 THEN mask := LSL(2, y.a) - 1
    ELSE mask := -1
    END;
    x.a := mask - (LSL(1, x.a) - 1)
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
VAR addr, size: INTEGER;
BEGIN
  IF s.mode # ST.Var THEN S.Mark(E.badVarPar)
  ELSE
    addr := s.a; size := s.type.size;
    Load(s);
    IF x.mode = ST.Const THEN
      G.MovImm(RH, LSL(1, x.a));
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
    G.Adrp(RH, 2);
    G.StrImm(s.r, RH, addr, size);
    DEC(RH)
  END
END InclExclVar;

(** INC/DEC. obj := obj +/- n. sub=TRUE means DEC. *)
PROCEDURE IncDecVar*(VAR obj, n: Item; sub: BOOLEAN);
VAR addr, size, addrReg: INTEGER;
BEGIN
  IF obj.mode = RegI THEN
    addrReg := obj.r; size := obj.type.size;
    G.LdrImm(RH, addrReg, 0, size);
    obj.r := RH;
    obj.mode := Reg;
    IncR;
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
    G.StrImm(obj.r, addrReg, 0, size);
    DEC(RH, 2)
  ELSIF obj.mode = ST.Var THEN
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
  ELSE S.Mark(E.badVarPar)
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
  t := x.a; x.a := x.b; x.b := t
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
    Load(x); (* x -- Reg; RH and RH+1 are then used as scratch *)
    IF op = S.times THEN
      G.MovImm(RH, y.a);
      G.Mul(x.r, x.r, RH)
    ELSIF y.a <= 0 THEN S.Mark(E.badDiv)
    ELSIF op = S.div THEN
      IF Log2(y.a) >= 0 THEN
        G.AsrImm(x.r, x.r, Log2(y.a))
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
  x.a := 0; x.b := 0 (* False- and True-lists respectively *)
END SetCond;

PROCEDURE IntRel*(op: INTEGER; VAR x, y: Item);
BEGIN
  IF (y.mode = ST.Const) & (y.a >= 0) & (y.a < 1000H) THEN
    Load(x);
    IF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r) END;
    G.CmpImm(x.r, y.a);
    DEC(RH)
  ELSE
    Load(x);
    IF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r) END;
    Load(y);
    IF y.type.size = 2 THEN G.Sxth(y.r, y.r)
    ELSIF y.type.size = 4 THEN G.Sxtw(y.r, y.r) END;
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

PROCEDURE Assign*(VAR x, y: Item);
VAR size, q: INTEGER;
BEGIN
  IF ~ST.TypesCompatible(x.type, y.type) THEN
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
    IF x.type.form = ST.Real THEN
      G.Adrp(RH, 2);
      G.FStrImm(y.r, RH, x.a)
    ELSE
      G.Adrp(RH, 2); (* ADRP RH, 2 *)
      G.StrImm(y.r, RH, x.a, x.type.size) (* STR* w{y.r}, [x{RH}, #{x.a}] *)
    END;
    DEC(RH)
  ELSE
    S.Mark(E.assignConst)
  END
END Assign;

(** Array indexing. x := x[y].
    x is an array variable, y is the index expression.
    Result: x.mode = RegI or Var (when index is a constant),
    x.type = element type. *)
PROCEDURE Index*(VAR x, y: Item);
VAR elemSize, shift: INTEGER;
BEGIN
  IF x.type.form # ST.Array THEN S.Mark(E.notArray)
  ELSE
    elemSize := x.type.base.size;
    IF (y.mode = ST.Const) & (x.mode = ST.Var) THEN
      x.a := x.a + y.a * elemSize
    ELSIF (y.mode = ST.Const) & (x.mode = RegI) THEN
      IF y.a * elemSize # 0 THEN
        G.AddImm(x.r, x.r, y.a * elemSize)
      END
    ELSIF x.mode = ST.Var THEN
      Load(y);
      G.Adrp(RH, 2);
      G.AddImm(RH, RH, x.a);
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
      shift := Log2(elemSize);
      IF shift >= 0 THEN
        G.AddLsl(x.r, x.r, y.r, shift)
      ELSE
        G.MovImm(RH, elemSize);
        G.Madd(x.r, y.r, RH, x.r)
      END;
      DEC(RH)
    ELSE S.Mark(E.notArray)
    END;
    x.type := x.type.base
  END
END Index;

PROCEDURE Fixup*(VAR x: Item);
BEGIN FixLink(x.a)
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
    G.BCond(AL, x.a); (* Cannot use G.B because it would break the chain *)
    x.a := G.Here() - 1
  ELSE
    (* Emit B.cond(Negated(x.r)), chain x.a false-list; fix x.b true-list to here *)
    FixLink(x.b);
    x.b := 0; (* Required because of And1 *)
    G.BCond(Negated(x.r), x.a);
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
    FixLinkWith(x.a, L)
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
  x.a := MergeLists(y.a, x.a);
  x.b := y.b; x.r := y.r
END And2;

(** x := x OR *)
PROCEDURE Or1*(VAR x: Item);
BEGIN
  LoadCond(x);
  IF x.r = AL THEN
    (* Const TRUE OR y: result is always true, skip y *)
    FixLink(x.a);
    x.a := 0
  ELSIF x.r = NV THEN
    (* Const FALSE OR y: result depends only on y *)
    FixLink(x.a);
    x.a := 0
  ELSE
    (* Emit B.cond(x.r): if TRUE jump forward → true-list; chain x.b *)
    FixLink(x.a);
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

(** FOR loop support **)

(** Save the FOR end value. If endVal is a constant, just saves the value.
    If it's in a register, pushes it on the stack. *)
PROCEDURE ForSave*(VAR endVal: Item; VAR savedConst: INTEGER;
    VAR onStack: BOOLEAN);
BEGIN
  IF endVal.mode = ST.Const THEN
    savedConst := endVal.a;
    onStack := FALSE
  ELSE
    Load(endVal);
    G.AddImm(G.SP, G.SP, -16);
    G.StrImm(endVal.r, G.SP, 0, 8);
    DEC(RH);
    onStack := TRUE
  END
END ForSave;

(** Generate FOR loop condition check. Compares loop variable with saved end
    value. step > 0: exits when loopVar > end. step < 0: exits when < end. *)
PROCEDURE ForCond*(obj: ST.Object; onStack: BOOLEAN;
    savedConst, step: INTEGER; VAR x: Item);
VAR loopVar, endItem: Item;
  cond: INTEGER;
BEGIN
  MakeItem(loopVar, obj);
  IF onStack THEN
    Load(loopVar);
    IF loopVar.type.size = 2 THEN G.Sxth(loopVar.r, loopVar.r)
    ELSIF loopVar.type.size = 4 THEN G.Sxtw(loopVar.r, loopVar.r) END;
    G.LdrImm(RH, G.SP, 0, 8);
    G.Cmp(loopVar.r, RH);
    DEC(RH);
    IF step > 0 THEN cond := LE ELSE cond := GE END;
    SetCond(loopVar, cond)
  ELSE
    MakeConstItem(endItem, obj.type, savedConst);
    IF step > 0 THEN IntRel(S.leq, loopVar, endItem)
    ELSE IntRel(S.geq, loopVar, endItem)
    END
  END;
  x := loopVar
END ForCond;

(** Clean up the stack after a FOR loop if end value was saved there. *)
PROCEDURE ForClean*(onStack: BOOLEAN);
BEGIN
  IF onStack THEN G.AddImm(G.SP, G.SP, 16) END
END ForClean;

(** CASE statement support **)

(** Keep case expression value in a register. *)
PROCEDURE CaseSave*(VAR x: Item);
BEGIN
  Load(x);
  IF x.type.size = 2 THEN G.Sxth(x.r, x.r)
  ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r)
  END;
  caseReg := x.r
END CaseSave;

(** Compare case register with a single value.
    Emits conditional jump chained into matchList when equal. *)
PROCEDURE CaseLabel*(val: INTEGER; VAR matchList: INTEGER);
BEGIN
  IF (val >= 0) & (val < 1000H) THEN
    G.CmpImm(caseReg, val)
  ELSE
    G.MovImm(RH, val);
    G.Cmp(caseReg, RH)
  END;
  G.BCond(EQ, matchList);
  matchList := G.Here() - 1
END CaseLabel;

(** Compare case register with a range [lo..hi].
    Emits conditional jump chained into matchList when in range. *)
PROCEDURE CaseRangeLabel*(lo, hi: INTEGER; VAR matchList: INTEGER);
VAR skipPos: INTEGER;
BEGIN
  IF (lo >= 0) & (lo < 1000H) THEN
    G.CmpImm(caseReg, lo)
  ELSE
    G.MovImm(RH, lo);
    G.Cmp(caseReg, RH)
  END;
  skipPos := G.Here();
  G.BCond(LT, 0);
  IF (hi >= 0) & (hi < 1000H) THEN
    G.CmpImm(caseReg, hi)
  ELSE
    G.MovImm(RH, hi);
    G.Cmp(caseReg, RH)
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

END Emitter.
