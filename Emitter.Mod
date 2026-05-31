MODULE Emitter;
IMPORT ST := SymTable, S := Scanner, G := Generator, E := ErrorMsg, Files,
  Strings, M := Machine, SYSTEM;

CONST
  maxGenReg = 18;  (** Last general-purpose register (x18) *)
  firstCSReg = 19; (** First callee-saved register (x19) *)
  maxCSReg = 28;   (** Last callee-saved register (x28) *)
  ieeeExpMask = 0FFH;
  ieeeFracMask = 07FFFFFH;
  ieeeOne = 03F800000H;
  ieeeTwo = 040000000H;
  ieeeTiny = 034800000H;
  ieeeMsbFrac = 0800000H;

  (** Values of Item.mode **)
  (** Some of Object Classes from SymTable are also valid *)
  Reg*  = 10;
  RegI* = 11; (** Register indirect: address in register r — exported for Parser *)
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
  LONGREAL = M.LONGREAL;

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
    rdo*: BOOLEAN; (** Read-only: TRUE for non-VAR array param elements *)
    extImp*: INTEGER; (** Import index for module-level Var, or -1 for own __DATA *)
  END;

VAR
  RH: INTEGER; (** Next free general-purpose register (x0..x18) *)
  SH: INTEGER; (** Next free callee-saved register (x19..x28) *)
  cmpNeeded: BOOLEAN;
  assertModIdx, assertModLen, assertProcIdx, assertProcLen: INTEGER;
  noAssert: BOOLEAN;

PROCEDURE FixRH*(val: INTEGER);
BEGIN RH := val
END FixRH;

(** Item Constructors **)

PROCEDURE MakeConstItem*(VAR x: Item; type: ST.Type; val: LONGINT);
BEGIN
  x.mode := ST.Const;
  x.type := type;
  x.a := val;
  x.rdo := FALSE;
  x.extImp := -1
END MakeConstItem;

PROCEDURE MakeStringConstItem*(VAR x: Item; strIdx, charLen: INTEGER);
BEGIN
  x.mode := ST.Const;
  x.type := ST.MakeStringType(charLen);
  x.a := strIdx;
  x.rdo := FALSE;
  x.extImp := -1
END MakeStringConstItem;

PROCEDURE MakeItem*(VAR x: Item; obj: ST.Object);
BEGIN
  x.mode := obj.class;
  x.type := obj.type;
  x.b := obj.lev;
  x.rdo := obj.readOnly;
  x.extImp := -1;
  IF (obj.class = ST.Var) & (obj.lev = 0) & obj.external THEN
    x.extImp := obj.importIdx
  END;
  IF (obj.class IN {ST.Var, ST.VarPar}) & (obj.lev > 0) & (obj.lev < ST.curLev) THEN
    S.Mark(E.outerLocalAccess)
  END;
  IF obj.class = ST.Const THEN
    IF (obj.type # NIL) & (obj.type.form = ST.Proc) THEN
      x.a := obj.address
    ELSIF (obj.type # NIL) & (obj.type.form = ST.LongReal) THEN
      x.a := SYSTEM.VAL(LONGINT, obj.realVal)
    ELSIF (obj.type # NIL) & (obj.type.form = ST.Real) THEN
      x.a := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, obj.realVal))
    ELSE
      x.a := obj.intVal
    END
  ELSE
    x.a := obj.address
  END;
  IF (obj.class IN {ST.Var, ST.VarPar}) & (obj.type.form = ST.Array)
      & (obj.type.openRank > 0) THEN
    x.b := M.SHORT(x.a) + 8 (* address of first hidden length parameter *)
  END
END MakeItem;

(** Emit ADRP for own or imported __DATA page. *)
PROCEDURE DataPageAdrp(reg, extImp: INTEGER);
BEGIN
  IF extImp >= 0 THEN G.LoadExtDataPage(reg, extImp)
  ELSE G.LoadDataPage(reg)
  END
END DataPageAdrp;

(** Returns TRUE if ARM64 scaled unsigned offset can encode `off`. *)
PROCEDURE MemImmFits(off, size: INTEGER): BOOLEAN;
BEGIN
RETURN (off >= 0) & (off MOD size = 0) & (off DIV size < 1000H)
END MemImmFits;

PROCEDURE AddImmFits(off: INTEGER): BOOLEAN;
VAR a: INTEGER;
BEGIN
  IF off < 0 THEN a := -off ELSE a := off END;
  IF (a # 0) & (a MOD 1000H = 0) THEN a := a DIV 1000H END;
RETURN a MOD 1000H = a
END AddImmFits;

PROCEDURE AddrOffset(reg, base, off: INTEGER);
BEGIN
  IF AddImmFits(off) THEN G.AddImm(reg, base, off)
  ELSE
    G.MovImm(reg, off);
    G.Add(reg, base, reg)
  END
END AddrOffset;

PROCEDURE AdjustSP(off: INTEGER);
VAR rest, q, chunk: INTEGER;
BEGIN
  rest := off;
  WHILE rest # 0 DO
    IF rest < 0 THEN
      IF -rest >= 1000H THEN
        q := (-rest) DIV 1000H;
        IF q >= 1000H THEN q := 0FFFH END;
        chunk := q * 1000H
      ELSE chunk := -rest
      END;
      G.AddImm(SP, SP, -chunk);
      rest := rest + chunk
    ELSE
      IF rest >= 1000H THEN
        q := rest DIV 1000H;
        IF q >= 1000H THEN q := 0FFFH END;
        chunk := q * 1000H
      ELSE chunk := rest
      END;
      G.AddImm(SP, SP, chunk);
      rest := rest - chunk
    END
  END
END AdjustSP;

PROCEDURE LoadAt(rt, rn, off, size: INTEGER);
VAR scratch: INTEGER;
BEGIN
  IF MemImmFits(off, size) THEN G.LdrImm(rt, rn, off, size)
  ELSE
    IF rt = rn THEN
      scratch := RH;
      IF scratch = rt THEN INC(scratch) END;
      AddrOffset(scratch, rn, off);
      G.LdrImm(rt, scratch, 0, size)
    ELSE
      AddrOffset(rt, rn, off);
      G.LdrImm(rt, rt, 0, size)
    END
  END
END LoadAt;

PROCEDURE StoreAt(rt, rn, off, size: INTEGER);
VAR scratch: INTEGER;
BEGIN
  IF MemImmFits(off, size) THEN G.StrImm(rt, rn, off, size)
  ELSE
    scratch := RH;
    IF (scratch = rt) OR (scratch = rn) THEN INC(scratch) END;
    IF (scratch = rt) OR (scratch = rn) THEN INC(scratch) END;
    AddrOffset(scratch, rn, off);
    G.StrImm(rt, scratch, 0, size)
  END
END StoreAt;

PROCEDURE FLoadAt(ft, rn, off: INTEGER);
VAR scratch: INTEGER;
BEGIN
  IF MemImmFits(off, 4) THEN G.FLdrImm(ft, rn, off)
  ELSE
    scratch := RH;
    IF scratch = rn THEN INC(scratch) END;
    AddrOffset(scratch, rn, off);
    G.FLdrImm(ft, scratch, 0)
  END
END FLoadAt;

PROCEDURE FStoreAt(ft, rn, off: INTEGER);
VAR scratch: INTEGER;
BEGIN
  IF MemImmFits(off, 4) THEN G.FStrImm(ft, rn, off)
  ELSE
    scratch := RH;
    IF scratch = rn THEN INC(scratch) END;
    AddrOffset(scratch, rn, off);
    G.FStrImm(ft, scratch, 0)
  END
END FStoreAt;

PROCEDURE FDLoadAt(ft, rn, off: INTEGER);
VAR scratch: INTEGER;
BEGIN
  IF MemImmFits(off, 8) THEN G.DLdrImm(ft, rn, off)
  ELSE
    scratch := RH;
    IF scratch = rn THEN INC(scratch) END;
    AddrOffset(scratch, rn, off);
    G.DLdrImm(ft, scratch, 0)
  END
END FDLoadAt;

PROCEDURE FDStoreAt(ft, rn, off: INTEGER);
VAR scratch: INTEGER;
BEGIN
  IF MemImmFits(off, 8) THEN G.DStrImm(ft, rn, off)
  ELSE
    scratch := RH;
    IF scratch = rn THEN INC(scratch) END;
    AddrOffset(scratch, rn, off);
    G.DStrImm(ft, scratch, 0)
  END
END FDStoreAt;

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

PROCEDURE MaskSetConst*(VAR x: Item);
BEGIN
  IF x.type.size = 1 THEN x.a := x.a MOD 100H
  ELSIF x.type.size = 2 THEN x.a := x.a MOD 10000H
  END
END MaskSetConst;

PROCEDURE MaskSetReg(reg: INTEGER; size: INTEGER);
VAR mask: INTEGER;
BEGIN
  IF size <= 4 THEN
    mask := AllocR();
    IF size = 1 THEN G.MovImm(mask, 0FFH)
    ELSIF size = 2 THEN G.MovImm(mask, 0FFFFH)
    ELSE G.MovImm(mask, 0FFFFFFFFH)
    END;
    G.And(reg, reg, mask);
    DEC(RH)
  END
END MaskSetReg;

PROCEDURE SignExtendForm*(reg: INTEGER; form: INTEGER);
BEGIN
  IF form = ST.TinyInt THEN G.Sxtb(reg, reg)
  ELSIF form = ST.ShortInt THEN G.Sxth(reg, reg)
  ELSIF form = ST.Int THEN G.Sxtw(reg, reg)
  END
END SignExtendForm;

PROCEDURE Load*(VAR x: Item);
VAR op, q, addr, endL, trueL: INTEGER;
BEGIN
  IF x.mode # Reg THEN
    IF x.mode = ST.Const THEN
      IF x.type.form = ST.String THEN
        S.Mark(E.incompatible)
      ELSIF x.type.form = ST.LongReal THEN
        G.MovImm(RH, x.a);
        G.FMovXtoD(RH, RH);
        G.FMovDtoX(RH, RH)
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
      IF x.type.form = ST.LongReal THEN
        FDLoadAt(x.r, x.r, 0);
        G.FMovDtoX(x.r, x.r)
      ELSIF x.type.form = ST.Real THEN
        FLoadAt(x.r, x.r, 0)
      ELSE
        LoadAt(x.r, x.r, 0, x.type.size);
        IF ST.IsIntegerForm(x.type.form) & (x.type.form # ST.Byte)
            & (x.type.form # ST.LongInt) THEN SignExtendForm(x.r, x.type.form)
        ELSIF ST.IsSetForm(x.type.form) & (x.type.size = 4) THEN G.Sxtw(x.r, x.r)
        END
      END;
      cmpNeeded := TRUE
    ELSIF x.mode = ST.Var THEN
      IF x.b > 0 THEN (* local variable or value parameter *)
        IF x.type.form = ST.LongReal THEN
          FDLoadAt(RH, FP, M.SHORT(x.a));
          G.FMovDtoX(RH, RH)
        ELSIF x.type.form = ST.Real THEN
          FLoadAt(RH, FP, M.SHORT(x.a));
          (* ProcPrologue spills x0.. into FP-relative param slots. *)
          G.FMovStoW(RH, RH)
        ELSE
          LoadAt(RH, FP, M.SHORT(x.a), x.type.size);
          IF ST.IsIntegerForm(x.type.form) & (x.type.form # ST.Byte)
              & (x.type.form # ST.LongInt) THEN SignExtendForm(RH, x.type.form)
          ELSIF ST.IsSetForm(x.type.form) & (x.type.size = 4) THEN G.Sxtw(RH, RH)
          END
        END
      ELSE (* global variable *)
        DataPageAdrp(RH, x.extImp);
        IF x.type.form = ST.LongReal THEN
          FDLoadAt(RH, RH, M.SHORT(x.a));
          G.FMovDtoX(RH, RH)
        ELSIF x.type.form = ST.Real THEN
          FLoadAt(RH, RH, M.SHORT(x.a));
          G.FMovStoW(RH, RH)
        ELSE
          LoadAt(RH, RH, M.SHORT(x.a), x.type.size);
          IF ST.IsIntegerForm(x.type.form) & (x.type.form # ST.Byte)
              & (x.type.form # ST.LongInt) THEN SignExtendForm(RH, x.type.form)
          ELSIF ST.IsSetForm(x.type.form) & (x.type.size = 4) THEN G.Sxtw(RH, RH)
          END
        END
      END;
      cmpNeeded := TRUE;
      x.r := AllocR()
    ELSIF x.mode = ST.VarPar THEN (* VAR parameter: load address, then value *)
      LoadAt(RH, FP, M.SHORT(x.a), 8); (* load pointer from stack frame *)
      IF x.type.form = ST.LongReal THEN
        FDLoadAt(RH, RH, 0);
        G.FMovDtoX(RH, RH)
      ELSIF x.type.form = ST.Real THEN
        FLoadAt(RH, RH, 0)
      ELSE
        LoadAt(RH, RH, 0, x.type.size);
        IF ST.IsIntegerForm(x.type.form) & (x.type.form # ST.Byte)
            & (x.type.form # ST.LongInt) THEN SignExtendForm(RH, x.type.form)
        ELSIF ST.IsSetForm(x.type.form) & (x.type.size = 4) THEN G.Sxtw(RH, RH)
        ELSIF ST.IsSetForm(x.type.form) & (x.type.size = 1) THEN MaskSetReg(RH, x.type.size)
        END
      END;
      cmpNeeded := TRUE;
      x.r := AllocR()
    ELSIF x.mode = Cond THEN
      IF (M.SHORT(x.a) # 0) OR (x.b # 0) THEN
        (* AND/OR chains combine pending true/false jumps with the current
           condition code in x.r. Materialise false first so a failed current
           condition can fall through naturally. *)
        trueL := x.b;
        IF x.r = AL THEN
          G.BCond(AL, trueL); trueL := G.Here() - 1
        ELSIF x.r # NV THEN
          G.BCond(x.r, trueL); trueL := G.Here() - 1
        END;
        FixLinkWith(M.SHORT(x.a), G.Here());
        G.MovImm(RH, 0);
        endL := 0;
        G.BCond(14, endL);
        endL := G.Here() - 1;
        FixLink(trueL);
        G.MovImm(RH, 1);
        FixLinkWith(endL, G.Here());
        x.r := AllocR()
      ELSE
        FixLink(x.b);
        FixLinkWith(M.SHORT(x.a), G.Here());
        IF x.r = AL THEN G.MovImm(RH, 1)
        ELSIF x.r = NV THEN G.MovImm(RH, 0)
        ELSE G.CSInc(RH, SP, SP, Negated(x.r))
        END;
        x.r := AllocR()
      END
    END;
    x.mode := Reg
  END
END Load;

PROCEDURE SetBitsConst(v: LONGINT; dst: ST.Type): LONGINT;
VAR r: LONGINT;
BEGIN
  IF dst.size = 1 THEN r := v MOD 100H
  ELSIF dst.size = 2 THEN r := v MOD 10000H
  ELSIF dst.size = 4 THEN r := M.LONG(M.SHORT(v))
  ELSE r := v
  END
RETURN r END SetBitsConst;

PROCEDURE OrdSetConst(v: LONGINT; src, dst: ST.Type): LONGINT;
VAR r: LONGINT; srcSz, dstSz: INTEGER;
BEGIN
  r := SetBitsConst(v, src);
  srcSz := src.size; dstSz := dst.size;
  IF dstSz < srcSz THEN
    IF srcSz = 8 THEN r := M.LONG(M.SHORT(r)); srcSz := 4 END;
    IF (srcSz = 4) & (dstSz <= 2) THEN r := M.LONG(M.SHORT(r)); srcSz := 2 END;
    IF (srcSz = 2) & (dstSz = 1) THEN r := M.LONG(M.SHORT(M.SHORT(r) MOD 100H)); srcSz := 1 END
  ELSIF (dst.form = ST.LongInt) & (srcSz = 8) THEN r := M.LONG(M.SHORT(M.SHORT(r)))
  ELSIF dstSz > srcSz THEN
    IF srcSz = 1 THEN
      IF r >= 80H THEN r := r - 100H END
    ELSIF srcSz = 2 THEN r := M.LONG(M.SHORT(r))
    ELSIF srcSz = 4 THEN r := M.LONG(M.SHORT(r))
    END
  END;
  IF dst.form = ST.Byte THEN r := r MOD 100H
  ELSIF dst.form = ST.TinyInt THEN
    r := r MOD 100H;
    IF r >= 80H THEN r := r - 100H END
  ELSIF dst.form = ST.ShortInt THEN r := M.LONG(M.SHORT(r))
  ELSIF (dst.form = ST.Int) & (srcSz = 8) THEN r := M.LONG(M.SHORT(r))
  END
RETURN r END OrdSetConst;

PROCEDURE PromoteIntConst(v: LONGINT; src: ST.Type; dr: INTEGER): LONGINT;
VAR r: LONGINT; ir: INTEGER;
BEGIN
  IF src.form = ST.Byte THEN r := v MOD 100H; ir := 0
  ELSE r := v; ir := ST.IntegerRank(src.form)
  END;
  WHILE ir < dr DO
    IF ir = 0 THEN
      IF r >= 80H THEN r := r - 100H END
    ELSIF ir = 1 THEN r := M.LONG(M.SHORT(r))
    ELSIF ir = 2 THEN r := M.LONG(M.SHORT(r))
    END;
    INC(ir)
  END
RETURN r END PromoteIntConst;

PROCEDURE ValIntFromSet(VAR x: Item; y: Item; dst: ST.Type);
VAR srcSz, dstSz, mask: INTEGER;
BEGIN
  IF y.mode = ST.Const THEN
    MakeConstItem(x, dst, OrdSetConst(y.a, y.type, dst))
  ELSE
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Load(x);
    MaskSetReg(x.r, y.type.size);
    srcSz := y.type.size; dstSz := dst.size;
    IF dstSz < srcSz THEN
      IF srcSz = 8 THEN G.Sxtw(x.r, x.r); srcSz := 4 END;
      IF (srcSz = 4) & (dstSz <= 2) THEN G.Sxth(x.r, x.r); srcSz := 2 END;
      IF (srcSz = 2) & (dstSz = 1) THEN G.Sxtb(x.r, x.r); srcSz := 1 END;
      IF dst.form = ST.Byte THEN
        mask := AllocR(); G.MovImm(mask, 0FFH); G.And(x.r, x.r, mask); DEC(RH)
      END
    ELSIF dstSz >= srcSz THEN
      IF srcSz = 1 THEN G.Sxtb(x.r, x.r)
      ELSIF srcSz = 2 THEN G.Sxth(x.r, x.r)
      ELSIF srcSz = 4 THEN G.Sxtw(x.r, x.r)
      ELSIF (srcSz = 8) & (dst.form = ST.LongInt) THEN G.Sxtw(x.r, x.r)
      END;
      IF dst.form = ST.Byte THEN
        mask := AllocR(); G.MovImm(mask, 0FFH); G.And(x.r, x.r, mask); DEC(RH)
      END
    END;
    x.type := dst
  END
END ValIntFromSet;

PROCEDURE ValSetFromInt(VAR x: Item; y: Item; dst: ST.Type);
VAR srcSz, dstSz, ir, dr, mask: INTEGER;
BEGIN
  IF y.mode = ST.Const THEN
    dr := ST.SetRank(dst.form);
    IF y.type.form = ST.Byte THEN
      MakeConstItem(x, dst, SetBitsConst(y.a MOD 100H, dst))
    ELSE
      MakeConstItem(x, dst, SetBitsConst(PromoteIntConst(y.a, y.type, dr), dst))
    END
  ELSE
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Load(x);
    IF y.type.form = ST.Byte THEN
      mask := AllocR(); G.MovImm(mask, 0FFH); G.And(x.r, x.r, mask); DEC(RH);
      srcSz := 1
    ELSE
      srcSz := y.type.size;
      ir := ST.IntegerRank(y.type.form);
      dr := ST.SetRank(dst.form);
      WHILE ir < dr DO
        IF srcSz = 1 THEN G.Sxtb(x.r, x.r)
        ELSIF srcSz = 2 THEN G.Sxth(x.r, x.r)
        ELSIF srcSz = 4 THEN G.Sxtw(x.r, x.r)
        END;
        INC(ir);
        IF ir = 1 THEN srcSz := 2
        ELSIF ir = 2 THEN srcSz := 4
        ELSIF ir = 3 THEN srcSz := 8
        END
      END
    END;
    dstSz := dst.size;
    IF dstSz < srcSz THEN MaskSetReg(x.r, dstSz)
    ELSIF dstSz > srcSz THEN MaskSetReg(x.r, srcSz)
    END;
    x.type := dst
  END
END ValSetFromInt;

(** BITS: integer bit pattern to set type (cast, not conversion). *)
PROCEDURE Bits*(VAR x: Item; dst: ST.Type);
VAR y: Item;
BEGIN
  y.mode := x.mode; y.type := x.type; y.a := x.a; y.b := x.b;
  y.r := x.r; y.rdo := x.rdo; y.extImp := x.extImp;
  ValSetFromInt(x, y, dst)
END Bits;

PROCEDURE PromoteRealToLong*(VAR x: Item);
BEGIN
  IF (x.type # NIL) & (x.type.form = ST.Real) THEN
    Load(x);
    G.FcvtSD(x.r, x.r);
    G.FMovDtoX(x.r, x.r);
    x.type := ST.longRealType
  END
END PromoteRealToLong;

PROCEDURE LoadAddr(VAR x: Item);
BEGIN
  IF (x.mode = ST.Const) & (x.type.form = ST.String) THEN
    G.LoadStringAddr(RH, M.SHORT(x.a));
    x.r := RH;
    INC(RH);
    x.mode := Reg
  ELSIF x.mode = ST.Var THEN
    IF x.b > 0 THEN (* local variable *)
      AddrOffset(RH, FP, M.SHORT(x.a))
    ELSE (* global variable *)
      DataPageAdrp(RH, x.extImp);
      AddrOffset(RH, RH, M.SHORT(x.a))
    END;
    x.r := AllocR()
  ELSIF x.mode = ST.VarPar THEN (* already a pointer in stack frame *)
    LoadAt(RH, FP, M.SHORT(x.a), 8);
    x.r := AllocR()
  ELSIF x.mode = RegI THEN
    (* Indexed array element: the exact byte address is already in x.r
       (computed by Index/Field).  Just downgrade RegI to Reg. *)
  ELSE S.Mark(E.badVarPar)
  END;
  x.mode := Reg
END LoadAddr;

PROCEDURE PreserveAddr*(VAR x: Item);
VAR r: INTEGER;
BEGIN
  IF x.mode = RegI THEN
    r := AllocR();
    G.Mov(r, x.r);
    x.r := r
  END
END PreserveAddr;

(** Load the address of T's TypeDesc block in __DATA (own or imported). *)
PROCEDURE TypeDescAddr(reg: INTEGER; T: ST.Type);
BEGIN
  IF T.descModule < 0 THEN
    G.LoadDataPage(reg);
    AddrOffset(reg, reg, T.descOffset)
  ELSE
    G.LoadExtDataPage(reg, T.descModule);
    AddrOffset(reg, reg, T.descOffset)
  END
END TypeDescAddr;

(** reg := address of the record body for designator x (fields start here). *)
PROCEDURE LoadBodyAddr(VAR x: Item; VAR reg: INTEGER);
BEGIN
  IF x.mode = ST.Pointer THEN
    Load(x); reg := x.r
  ELSIF x.mode = ST.Var THEN
    IF (x.type # NIL) & (x.type.form = ST.Pointer) THEN
      IF x.b > 0 THEN
        LoadAt(reg, FP, M.SHORT(x.a), 8)
      ELSE
        DataPageAdrp(reg, x.extImp);
        LoadAt(reg, reg, M.SHORT(x.a), 8)
      END
    ELSIF x.b > 0 THEN AddrOffset(reg, FP, M.SHORT(x.a))
    ELSE
      DataPageAdrp(reg, x.extImp);
      AddrOffset(reg, reg, M.SHORT(x.a))
    END
  ELSIF x.mode = ST.VarPar THEN
    LoadAt(reg, FP, M.SHORT(x.a), 8);
    IF (x.type # NIL) & (x.type.form = ST.Pointer) THEN
      LoadAt(reg, reg, 0, 8)
    END
  ELSIF x.mode = RegI THEN
    reg := x.r
  ELSE
    S.Mark(E.incompatible); G.MovImm(reg, 0)
  END
END LoadBodyAddr;

(** SYSTEM.ADR(designator): take the address of a variable/array element.
    Works uniformly for scalars, fixed and open arrays, and both for
    `arr` and `arr[0]`: open arrays carry their data pointer in the
    VarPar slot, so `arr` (mode VarPar) loads the pointer directly,
    while `arr[0]` (mode RegI/Var) has already resolved to the same
    address.  Result type is SYSTEM.ADRINT (platform-sized signed
    integer; identical to LONGINT in form on 64-bit targets). *)
PROCEDURE AddrOf*(VAR x: Item);
BEGIN
  LoadAddr(x);
  x.type := ST.adrIntType;
  x.rdo := FALSE
END AddrOf;

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
  IF x.mode IN {ST.Var, ST.VarPar, ST.Const, Reg, RegI} THEN Load(x)
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

(** FLOOR: LONGREAL → INTEGER. *)
PROCEDURE FloorD*(VAR x: Item);
BEGIN
  Load(x);
  G.FcvtmsWfromD(x.r, x.r);
  x.type := ST.intType
END FloorD;

(** ENTIER: REAL → LONGINT. *)
PROCEDURE EntierR*(VAR x: Item);
BEGIN
  Load(x);
  G.Fcvtms(x.r, x.r);
  G.Sxtw(x.r, x.r);
  x.type := ST.longIntType
END EntierR;

(** ENTIER: LONGREAL → LONGINT. *)
PROCEDURE Entier*(VAR x: Item);
BEGIN
  Load(x);
  G.FcvtmsD(x.r, x.r);
  x.type := ST.longIntType
END Entier;

PROCEDURE MaskSetBits*(VAR x: Item);
BEGIN
  IF x.mode # ST.Const THEN
    Load(x);
    MaskSetReg(x.r, x.type.size)
  END
END MaskSetBits;

(** SHORT: type narrowing. Result type is set by caller. *)
PROCEDURE Short*(VAR x: Item);
BEGIN
  IF x.mode # ST.Const THEN
    Load(x);
    IF ST.IsSetForm(x.type.form) THEN
    ELSIF x.type.size = 8 THEN G.Sxtw(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 2 THEN G.Sxtb(x.r, x.r)
    END
  END
END Short;

(** LONG: type widening. Result type is set by caller. *)
PROCEDURE Long*(VAR x: Item);
BEGIN
  IF x.mode # ST.Const THEN
    Load(x);
    IF ST.IsSetForm(x.type.form) THEN
    ELSIF x.type.size = 1 THEN G.Sxtb(x.r, x.r)
    ELSIF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r)
    END
  END
END Long;

(** FLT: integer types → REAL. *)
PROCEDURE Flt*(VAR x: Item);
BEGIN
  Load(x);
  IF x.type.size = 8 THEN
    G.ScvtfD(x.r, x.r);
    G.FcvtDS(x.r, x.r);
    G.FMovStoW(x.r, x.r)
  ELSE
    G.Scvtf(x.r, x.r);
    G.FMovStoW(x.r, x.r)
  END;
  x.type := ST.realType
END Flt;

(** LONGFLT: integer types → LONGREAL. *)
PROCEDURE LongFlt*(VAR x: Item);
BEGIN
  Load(x);
  IF x.type.size = 8 THEN G.ScvtfD(x.r, x.r)
  ELSE G.Scvtf(x.r, x.r); G.FcvtSD(x.r, x.r)
  END;
  G.FMovDtoX(x.r, x.r);
  x.type := ST.longRealType
END LongFlt;

PROCEDURE TruncIntConst(v: LONGINT; src, dst: ST.Type): LONGINT;
VAR r: LONGINT;
BEGIN
  IF dst.form = ST.Byte THEN r := v MOD 100H
  ELSIF dst.form = ST.TinyInt THEN
    r := v MOD 100H;
    IF r >= 80H THEN r := r - 100H END
  ELSIF dst.form = ST.ShortInt THEN r := M.LONG(M.SHORT(v))
  ELSIF (dst.form = ST.Int) & (src.size = 8) THEN r := M.LONG(M.SHORT(v))
  ELSE r := v
  END
RETURN r END TruncIntConst;

(** SYSTEM.VAL: integer narrowing/widening; other pairs via ValCompatible. *)
PROCEDURE Val*(VAR x: Item; y: Item; dst: ST.Type);
VAR srcSz, dstSz, mask: INTEGER;
BEGIN
  IF ST.IsIntegerForm(dst.form) & ST.IsIntegerForm(y.type.form) THEN
    IF y.mode = ST.Const THEN
      MakeConstItem(x, dst, TruncIntConst(y.a, y.type, dst))
    ELSE
      x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
      x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
      Load(x);
      srcSz := y.type.size; dstSz := dst.size;
      IF dstSz < srcSz THEN
        IF srcSz = 8 THEN G.Sxtw(x.r, x.r); srcSz := 4 END;
        IF (srcSz = 4) & (dstSz <= 2) THEN G.Sxth(x.r, x.r); srcSz := 2 END;
        IF (srcSz = 2) & (dstSz = 1) THEN G.Sxtb(x.r, x.r); srcSz := 1 END;
        IF dst.form = ST.Byte THEN
          mask := AllocR(); G.MovImm(mask, 0FFH); G.And(x.r, x.r, mask); DEC(RH)
        END
      ELSIF dstSz > srcSz THEN
        IF srcSz = 1 THEN G.Sxtb(x.r, x.r)
        ELSIF srcSz = 2 THEN G.Sxth(x.r, x.r)
        ELSIF srcSz = 4 THEN G.Sxtw(x.r, x.r)
        END
      ELSIF dst.form = ST.Byte THEN
        mask := AllocR(); G.MovImm(mask, 0FFH); G.And(x.r, x.r, mask); DEC(RH)
      END;
      x.type := dst
    END
  ELSIF ST.IsSetForm(dst.form) & ST.IsSetForm(y.type.form) THEN
    IF y.mode = ST.Const THEN
      MakeConstItem(x, dst, SetBitsConst(y.a, dst))
    ELSE
      x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
      x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
      Load(x);
      IF dst.size < y.type.size THEN MaskSetReg(x.r, dst.size)
      ELSIF dst.size > y.type.size THEN MaskSetReg(x.r, y.type.size)
      END;
      x.type := dst
    END
  ELSIF (dst.form = ST.Real) & ST.IsIntegerForm(y.type.form) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Flt(x)
  ELSIF (dst.form = ST.LongReal) & ST.IsIntegerForm(y.type.form) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    LongFlt(x)
  ELSIF (dst.form = ST.LongReal) & (y.type.form = ST.Real) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    PromoteRealToLong(x)
  ELSIF (dst.form = ST.Real) & (y.type.form = ST.LongReal) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Load(x);
    G.FcvtDS(x.r, x.r);
    G.FMovStoW(x.r, x.r);
    x.type := dst
  ELSIF (dst.form = ST.Int) & (y.type.form = ST.Real) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Floor(x)
  ELSIF (dst.form = ST.Int) & (y.type.form = ST.LongReal) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    FloorD(x)
  ELSIF (dst.form = ST.LongInt) & (y.type.form = ST.Real) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    EntierR(x)
  ELSIF (dst.form = ST.LongInt) & (y.type.form = ST.LongReal) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Entier(x)
  ELSIF ST.IsIntegerForm(dst.form) & (y.type.form = ST.Real) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Floor(x); x.type := dst
  ELSIF ST.IsIntegerForm(dst.form) & (y.type.form = ST.LongReal) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Entier(x);
    IF dst.form # ST.LongInt THEN Short(x) END;
    x.type := dst
  ELSIF (dst.form = ST.Char) & ST.IsIntegerForm(y.type.form) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Ord(x); x.type := dst
  ELSIF (dst.form = ST.Int) & (y.type.form = ST.Char) THEN
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    Ord(x)
  ELSIF ST.IsSetForm(dst.form) & ST.IsIntegerForm(y.type.form) THEN
    ValSetFromInt(x, y, dst)
  ELSIF ST.IsIntegerForm(dst.form) & ST.IsSetForm(y.type.form) THEN
    ValIntFromSet(x, y, dst)
  ELSE
    x.mode := y.mode; x.type := y.type; x.a := y.a; x.b := y.b;
    x.r := y.r; x.rdo := y.rdo; x.extImp := y.extImp;
    IF y.mode # ST.Const THEN Load(x) END;
    x.type := dst
  END
END Val;

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

PROCEDURE PromoteSetTo*(VAR x: Item; rank: INTEGER);
VAR r: INTEGER;
BEGIN
  r := ST.SetRank(x.type.form);
  WHILE r < rank DO
    Long(x);
    INC(r);
    x.type := ST.SetTypeAtRank(r)
  END
END PromoteSetTo;

PROCEDURE UnifySetTypes*(VAR x, y: Item);
VAR r: INTEGER;
BEGIN
  r := ST.SetRank(x.type.form);
  IF ST.SetRank(y.type.form) > r THEN r := ST.SetRank(y.type.form) END;
  PromoteSetTo(x, r);
  PromoteSetTo(y, r);
  x.type := ST.SetTypeAtRank(r)
END UnifySetTypes;

(** Set union. x := x + y (bitwise OR) *)
PROCEDURE SetUnion*(VAR x, y: Item);
VAR s, t: SET;
BEGIN
  IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
    s := SYSTEM.VAL(SET, x.a); t := SYSTEM.VAL(SET, y.a);
    x.a := ORD(s + t);
    MaskSetConst(x)
  ELSE
    UnifySetTypes(x, y);
    Load(x); Load(y);
    G.Orr(x.r, x.r, y.r);
    DEC(RH)
  END
END SetUnion;

(** Set difference. x := x - y (bitwise AND NOT) *)
PROCEDURE SetDiff*(VAR x, y: Item);
BEGIN
  UnifySetTypes(x, y);
  Load(x); Load(y);
  G.Bic(x.r, x.r, y.r);
  DEC(RH)
END SetDiff;

(** Set intersection. x := x * y (bitwise AND) *)
PROCEDURE SetInter*(VAR x, y: Item);
BEGIN
  UnifySetTypes(x, y);
  Load(x); Load(y);
  G.And(x.r, x.r, y.r);
  DEC(RH)
END SetInter;

(** Set symmetric difference. x := x / y (bitwise XOR) *)
PROCEDURE SetSymDiff*(VAR x, y: Item);
BEGIN
  UnifySetTypes(x, y);
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
  ELSIF (s.mode = ST.VarPar) & ST.IsSetForm(s.type.form) THEN
    size := s.type.size;
    LoadAddr(s);
    addrReg := s.r;
    valReg := AllocR();
    LoadAt(valReg, addrReg, 0, size);
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
    IF ST.IsSetForm(s.type.form) & (size = 1) THEN MaskSetReg(valReg, size) END;
    StoreAt(valReg, addrReg, 0, size);
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
      StoreAt(s.r, FP, addr, size)
    ELSE (* module-level variable *)
      DataPageAdrp(RH, s.extImp);
      StoreAt(s.r, RH, addr, size)
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
      LoadAt(RH, addrReg, 0, size);
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
      StoreAt(x.r, addrReg, 0, size);
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
        StoreAt(x.r, FP, addr, size)
      ELSE (* global variable *)
        DataPageAdrp(RH, x.extImp);
        StoreAt(x.r, RH, addr, size)
      END;
      DEC(RH)
    ELSIF x.mode = ST.VarPar THEN
      addrReg := AllocR();
      LoadAt(addrReg, FP, M.SHORT(x.a), 8);
      x.r := AllocR();
      LoadAt(x.r, addrReg, 0, x.type.size);
      IF n.mode = ST.Const THEN
        G.AddImm(x.r, x.r, a)
      ELSE
        Load(n);
        IF dec THEN G.Sub(x.r, x.r, n.r)
        ELSE G.Add(x.r, x.r, n.r)
        END;
        DEC(RH)
      END;
      StoreAt(x.r, addrReg, 0, x.type.size);
      DEC(RH, 2)
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
    IF (y.a >= -4095) & (y.a <= 4095) THEN
      IF op = S.plus THEN
        G.AddImm(x.r, x.r, M.SHORT(y.a))
      ELSE
        G.AddImm(x.r, x.r, -M.SHORT(y.a))
      END
    ELSE
      Load(y);
      IF op = S.plus THEN G.Add(x.r, x.r, y.r)
      ELSE G.Sub(x.r, x.r, y.r)
      END;
      DEC(RH)
    END
  ELSIF x.mode = ST.Const THEN (* y -- Reg or Var *)
    Load(y); (* x -- Const, y -- Reg *)
    IF op = S.minus THEN Neg(y) END;
    IF (x.a >= -4095) & (x.a <= 4095) THEN
      G.AddImm(y.r, y.r, M.SHORT(x.a))
    ELSE
      Load(x);
      G.Add(y.r, y.r, x.r);
      DEC(RH)
    END;
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
VAR sign: LONGINT;
BEGIN
  IF x.mode = ST.Const THEN
    IF x.type.form = ST.LongReal THEN
      sign := M.LSL64(SYSTEM.VAL(LONGINT, 1), 63);
      IF x.a >= 0 THEN x.a := x.a + sign ELSE x.a := x.a - sign END
    ELSE
      IF x.a >= 0 THEN x.a := x.a + (-7FFFFFFFH - 1)
      ELSE x.a := x.a - (-7FFFFFFFH - 1)
      END
    END
  ELSIF x.type.form = ST.LongReal THEN
    Load(x);
    G.DNeg(x.r, x.r);
    G.FMovDtoX(x.r, x.r)
  ELSE
    Load(x);
    G.FNeg(x.r, x.r);
    G.FMovStoW(x.r, x.r)
  END
END FNegVal;

(** Float addition or subtraction. x := x op y *)
PROCEDURE FAddOp*(op: INTEGER; VAR x, y: Item);
BEGIN
  Load(x);
  IF (y.mode # Reg) & (x.mode = Reg) & (RH = x.r) THEN INC(RH) END;
  Load(y);
  IF x.type.form = ST.LongReal THEN
    IF op = S.plus THEN G.DAdd(x.r, x.r, y.r)
    ELSE G.DSub(x.r, x.r, y.r)
    END;
    G.FMovDtoX(x.r, x.r)
  ELSE
    IF op = S.plus THEN G.FAdd(x.r, x.r, y.r)
    ELSE G.FSub(x.r, x.r, y.r)
    END;
    G.FMovStoW(x.r, x.r)
  END;
  DEC(RH)
END FAddOp;

(** Float multiplication or division. x := x op y *)
PROCEDURE FMulOp*(op: INTEGER; VAR x, y: Item);
BEGIN
  Load(x);
  IF (y.mode # Reg) & (x.mode = Reg) & (RH = x.r) THEN INC(RH) END;
  Load(y);
  IF x.type.form = ST.LongReal THEN
    IF op = S.times THEN G.DMul(x.r, x.r, y.r)
    ELSE G.DDiv(x.r, x.r, y.r)
    END;
    G.FMovDtoX(x.r, x.r)
  ELSE
    IF op = S.times THEN G.FMul(x.r, x.r, y.r)
    ELSE G.FDiv(x.r, x.r, y.r)
    END;
    G.FMovStoW(x.r, x.r)
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
VAR cmpSz: INTEGER;
BEGIN
  IF ST.IsSetForm(x.type.form) & ST.IsSetForm(y.type.form) THEN
    cmpSz := x.type.size;
    IF y.type.size < cmpSz THEN cmpSz := y.type.size END;
    IF (y.mode = ST.Const) & (y.a >= 0) & (y.a < 1000H) THEN
      Load(x);
      IF x.type.size > cmpSz THEN MaskSetReg(x.r, cmpSz) END;
      G.CmpImm(x.r, M.SHORT(y.a));
      DEC(RH)
    ELSE
      Load(x);
      IF x.type.size > cmpSz THEN MaskSetReg(x.r, cmpSz) END;
      Load(y);
      IF y.type.size > cmpSz THEN MaskSetReg(y.r, cmpSz) END;
      G.Cmp(x.r, y.r);
      DEC(RH, 2)
    END
  ELSIF (y.mode = ST.Const) & (y.a >= 0) & (y.a < 1000H) THEN
    Load(x);
    IF x.type.form = ST.Byte THEN
      IF x.type.size = 1 THEN MaskSetReg(x.r, 1) END
    ELSIF x.type.size = 1 THEN G.Sxtb(x.r, x.r)
    ELSIF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r)
    END;
    G.CmpImm(x.r, M.SHORT(y.a));
    DEC(RH)
  ELSE
    Load(x);
    IF x.type.form = ST.Byte THEN
      IF x.type.size = 1 THEN MaskSetReg(x.r, 1) END
    ELSIF x.type.size = 1 THEN G.Sxtb(x.r, x.r)
    ELSIF x.type.size = 2 THEN G.Sxth(x.r, x.r)
    ELSIF x.type.size = 4 THEN G.Sxtw(x.r, x.r)
    END;
    Load(y);
    IF y.type.form = ST.Byte THEN
      IF y.type.size = 1 THEN MaskSetReg(y.r, 1) END
    ELSIF y.type.size = 1 THEN G.Sxtb(y.r, y.r)
    ELSIF y.type.size = 2 THEN G.Sxth(y.r, y.r)
    ELSIF y.type.size = 4 THEN G.Sxtw(y.r, y.r)
    END;
    G.Cmp(x.r, y.r);
    DEC(RH, 2)
  END;
  SetCond(x, RelCond(op));
  FixRH(0)
END IntRel;

(** Float comparison. x rel y → Bool result *)
PROCEDURE FRel*(op: INTEGER; VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  IF x.type.form = ST.LongReal THEN G.DCmp(x.r, y.r)
  ELSE G.FCmp(x.r, y.r)
  END;
  DEC(RH, 2);
  SetCond(x, RelCond(op))
END FRel;

PROCEDURE AssignCharFromString(VAR x, y: Item);
VAR r, base: INTEGER;
BEGIN
  r := AllocR();
  G.LoadStringAddr(r, M.SHORT(y.a));
  LoadAt(r, r, 0, 2);
  IF x.mode = ST.Var THEN
    IF x.b > 0 THEN StoreAt(r, FP, M.SHORT(x.a), 2); DEC(RH)
    ELSE
      (* Adrp writes to register index RH without AllocR; INC so RH matches two live regs (r, base). *)
      base := RH;
      DataPageAdrp(base, x.extImp);
      StoreAt(r, base, M.SHORT(x.a), 2);
      INC(RH);
      DEC(RH, 2)
    END
  ELSIF x.mode = RegI THEN
    StoreAt(r, x.r, 0, 2);
    DEC(RH, 2)
  ELSIF x.mode = ST.VarPar THEN
    LoadAt(RH, FP, M.SHORT(x.a), 8);
    StoreAt(r, RH, 0, 2);
    DEC(RH)
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
  LoadAt(bl, pl, 0, 2);
  LoadAt(br, pr, 0, 2);
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
  xa.a := 0; xa.b := 0; xa.rdo := FALSE; xa.extImp := -1
END CmpStrings;

(** Emits a byte-by-byte copy of `size` bytes from [srcReg] to [dstReg].
    Uses 8/4/2/1-byte chunks chosen by remaining size, all unrolled.
    Allocates one scratch register from RH and frees it on exit; caller
    must ensure both src and dst registers are already live. *)
PROCEDURE CopyAggregate*(dstReg, srcReg, size: INTEGER);
VAR i, t, chunk: INTEGER;
BEGIN
  t := AllocR();
  i := 0;
  WHILE i < size DO
    IF (size - i >= 8) & (i MOD 8 = 0) THEN chunk := 8
    ELSIF (size - i >= 4) & (i MOD 4 = 0) THEN chunk := 4
    ELSIF (size - i >= 2) & (i MOD 2 = 0) THEN chunk := 2
    ELSE chunk := 1
    END;
    LoadAt(t, srcReg, i, chunk);
    StoreAt(t, dstReg, i, chunk);
    i := i + chunk
  END;
  DEC(RH)
END CopyAggregate;

(** Emits in-place selection of a record field on Item x.
    Result is an Item whose effective address is `addressOf(x) + field.address`,
    with the field's type. Mode-preserving: Var stays Var (offset folded into x.a),
    RegI stays RegI (offset added to x.r), VarPar is dereferenced to RegI
    so subsequent operations work on the field of the pointed-to record. *)
PROCEDURE Field*(VAR x: Item; field: ST.Object);
VAR off: INTEGER;
BEGIN
  off := M.SHORT(field.address);
  IF x.mode = ST.Var THEN
    x.a := x.a + off
  ELSIF x.mode = RegI THEN
    IF off # 0 THEN G.AddImm(x.r, x.r, off) END
  ELSIF x.mode = ST.VarPar THEN
    LoadAt(RH, FP, M.SHORT(x.a), 8);
    x.r := AllocR();
    IF off # 0 THEN G.AddImm(x.r, x.r, off) END;
    x.mode := RegI
  ELSE
    S.Mark(E.notRecord)
  END;
  x.type := field.type;
  x.rdo := FALSE
END Field;

(** NIL literal Item: 0-valued Const of the singleton nilType. *)
PROCEDURE MakeNilItem*(VAR x: Item);
BEGIN
  x.mode := ST.Const;
  x.type := ST.nilType;
  x.a := 0;
  x.b := 0;
  x.rdo := FALSE;
  x.extImp := -1
END MakeNilItem;

(** Pointer dereference: x must be a Pointer designator.  Loads the
    pointer value into a register, traps with BRK 1 if NIL, then
    re-tags the Item as RegI of the base record so subsequent .field /
    [..] / := operations transparently work on the pointed-to record. *)
PROCEDURE Deref*(VAR x: Item);
VAR okL: INTEGER;
BEGIN
  IF (x.type = NIL) OR (x.type.form # ST.Pointer) OR (x.type.base = NIL) THEN
    S.Mark(E.notPointer)
  ELSE
    Load(x);                    (* x.mode := Reg; x.r := pointer value *)
    G.CmpImm(x.r, 0);
    G.BCond(NE, 0); okL := G.Here() - 1;
    G.Brk(1);
    G.PatchBCond(okL, G.Here());
    x.mode := RegI;
    x.type := x.type.base;
    x.rdo := FALSE
  END
END Deref;

(** Called once per value-Record formal parameter from the procedure
    prologue.  The caller passed a pointer to the source record in
    register x_i, which `ProcPrologue` already spilled to FP+ptrSlot.
    We load that pointer, derive the address of the local copy slot
    at FP+localOff, and copy `size` bytes — giving the procedure body
    its private mutable copy with full Oberon-07 value semantics. *)
PROCEDURE CopyValueRecordParam*(localOff, ptrSlot, size: INTEGER);
VAR srcR, dstR: INTEGER;
BEGIN
  srcR := AllocR();
  LoadAt(srcR, FP, ptrSlot, 8);
  dstR := AllocR();
  AddrOffset(dstR, FP, localOff);
  CopyAggregate(dstR, srcR, size);
  DEC(RH, 2)
END CopyValueRecordParam;

PROCEDURE Assign*(VAR x, y: Item);
VAR size, q, rt, src, addrReg: INTEGER;
BEGIN
  IF x.rdo THEN S.Mark(E.readOnly)
  ELSIF (x.type # NIL) & (x.type.form = ST.LongReal) & (y.type # NIL) & (y.type.form = ST.Real) THEN
    PromoteRealToLong(y);
    Assign(x, y)
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
        LoadAt(RH, rt, size, 2);
        StoreAt(RH, q, size, 2);
        INC(size, 2)
      END;
      DEC(RH, 2)
    END
  ELSIF ~ST.AssignCompatible(x.type, y.type, y.mode = ST.Const) THEN
    S.Mark(E.incompatible)
  ELSIF x.type.form = ST.Record THEN
    LoadAddr(y);
    LoadAddr(x);
    src := AllocR();
    G.AddImm(src, y.r, -8);
    G.AddImm(x.r, x.r, -8);
    CopyAggregate(x.r, src, x.type.size);
    DEC(RH, 3)
  ELSIF x.mode = RegI THEN
    addrReg := AllocR();
    G.Mov(addrReg, x.r);
    Load(y);
    IF x.type.form = ST.LongReal THEN
      FDStoreAt(y.r, addrReg, 0)
    ELSIF x.type.form = ST.Real THEN
      FStoreAt(y.r, addrReg, 0)
    ELSE
      StoreAt(y.r, addrReg, 0, x.type.size)
    END;
    DEC(RH, 3)
  ELSIF x.mode = ST.Var THEN
    Load(y); (* x -- Var, y -- Reg *)
    IF x.b > 0 THEN (* local variable *)
      IF x.type.form = ST.LongReal THEN
        FDStoreAt(y.r, FP, M.SHORT(x.a))
      ELSIF x.type.form = ST.Real THEN
        FStoreAt(y.r, FP, M.SHORT(x.a))
      ELSE
        StoreAt(y.r, FP, M.SHORT(x.a), x.type.size)
      END
    ELSE (* global variable *)
      IF x.type.form = ST.LongReal THEN
        DataPageAdrp(RH, x.extImp);
        FDStoreAt(y.r, RH, M.SHORT(x.a))
      ELSIF x.type.form = ST.Real THEN
        DataPageAdrp(RH, x.extImp);
        FStoreAt(y.r, RH, M.SHORT(x.a))
      ELSE
        DataPageAdrp(RH, x.extImp);
        StoreAt(y.r, RH, M.SHORT(x.a), x.type.size)
      END
    END;
    DEC(RH)
  ELSIF x.mode = ST.VarPar THEN (* VAR parameter assignment *)
    Load(y);
    LoadAt(RH, FP, M.SHORT(x.a), 8); (* load pointer *)
    IF x.type.form = ST.LongReal THEN
      FDStoreAt(y.r, RH, 0)
    ELSIF x.type.form = ST.Real THEN
      FStoreAt(y.r, RH, 0)
    ELSE
      StoreAt(y.r, RH, 0, x.type.size)
    END;
    DEC(RH)
  ELSE
    S.Mark(E.assignConst)
  END
END Assign;

(** NEW(x): allocate x.type.base.size bytes via Heap.Allocate, write
    the type tag at offset 0, and assign the body pointer to x.
    Layout:    [tag : 8B] [field0] [field1] ... [fieldN]
                          ^---- pointer value points here, so field
                                offsets match stack/global records. *)
PROCEDURE NewVar*(VAR x: Item);
VAR allocSize, importIdx, savedRH, resReg, i, okL: INTEGER;
  recType: ST.Type;
  y: Item;
BEGIN
  IF (x.type = NIL) OR (x.type.form # ST.Pointer) OR (x.type.base = NIL) THEN
    S.Mark(E.notPointer)
  ELSE
    recType := x.type.base;
    allocSize := recType.size;
    savedRH := RH;
    IF RH > 0 THEN
      G.AddImm(SP, SP, -(((RH + 1) DIV 2) * 16));
      FOR i := 0 TO RH - 1 DO StoreAt(i, SP, i * 8, 8) END
    END;
    RH := 0;
    G.MovImm(0, allocSize);
    importIdx := G.AddImport('Heap');
    G.CallExt(importIdx, 'Allocate');
    G.CmpImm(0, 0);
    G.BCond(NE, 0); okL := G.Here() - 1;
    G.Brk(1);
    G.PatchBCond(okL, G.Here());
    (* Write the type-tag at offset 0 of the allocated block: address of
       the record's TypeDesc when known locally, NIL otherwise. *)
    IF (recType.form = ST.Record) & (recType.descOffset >= 0) THEN
      TypeDescAddr(1, recType)
    ELSE
      G.MovImm(1, 0)
    END;
    StoreAt(1, 0, 0, 8);
    G.AddImm(0, 0, 8);          (* x0 += 8: skip type tag *)
    resReg := 0;
    IF savedRH > 0 THEN
      resReg := savedRH;
      G.Mov(resReg, 0)
    END;
    IF savedRH > 0 THEN
      FOR i := 0 TO savedRH - 1 DO LoadAt(i, SP, i * 8, 8) END;
      G.AddImm(SP, SP, ((savedRH + 1) DIV 2) * 16)
    END;
    RH := savedRH;
    y.mode := Reg; y.type := x.type; y.a := 0; y.b := 0; y.rdo := FALSE;
    y.extImp := -1;
    y.r := AllocR();
    IF y.r # resReg THEN G.Mov(y.r, resReg) END;
    Assign(x, y)
  END
END NewVar;

(** Initialise the in-data TypeDesc for a single record-type T.
    Layout in __DATA: T.extLevel + 1 contiguous 8-byte slots starting at
    T.descOffset, where slot[i] holds the address of T's ancestor at
    extension level i (slot[T.extLevel] holds the address of T itself).
    Ancestors that live in another module (descOffset < 0) get NIL — IS
    tests against those will simply return FALSE.  Caller must run with
    RH = 0 (during the module-init prologue). *)
PROCEDURE EmitRecordTypeDescInit*(T: ST.Type);
VAR i, dataReg, ancReg: INTEGER;
  anc: ST.Type;
BEGIN
  IF (T # NIL) & (T.form = ST.Record) & (T.descOffset >= 0) THEN
    dataReg := AllocR();
    G.LoadDataPage(dataReg);
    ancReg := AllocR();
    FOR i := 0 TO T.extLevel DO
      anc := ST.AncestorAt(T, i);
      IF (anc # NIL) & (anc.descOffset >= 0) THEN
        TypeDescAddr(ancReg, anc)
      ELSE
        G.MovImm(ancReg, 0)
      END;
      StoreAt(ancReg, dataReg, T.descOffset + i * 8, 8)
    END;
    DEC(RH, 2)
  END
END EmitRecordTypeDescInit;

(** Wirth-style runtime type test `e IS T`.
    e (Pointer) holds the address of a record body; the type-tag (a
    pointer to TypeDesc(actualType)) lives 8 bytes before that body.
    The test loads this tag, indexes into TypeDesc(actualType) at slot
    extLevel(T), and compares the result to &TypeDesc(T): they are
    equal iff actualType extends T.

    `T` is the target Record type (caller has already validated that
    `T` extends `x.type.base`).  When T's descriptor lives in another
    module (descOffset < 0) we can't compare against it from here, so
    the test reduces to a constant FALSE — a documented degraded mode
    until cross-module RTTI is wired through the linker. *)
PROCEDURE IsTest*(VAR x: Item; T: ST.Type);
VAR bodyReg, tagReg, cmpReg, targReg: INTEGER;
BEGIN
  IF (x.type # NIL) & ((x.type.form = ST.Pointer) OR (x.type.form = ST.Record))
      & (T # NIL) & (T.form = ST.Record) & (T.descOffset >= 0) THEN
    bodyReg := AllocR();
    LoadBodyAddr(x, bodyReg);
    tagReg := AllocR();
    cmpReg := AllocR();
    targReg := AllocR();
    G.AddImm(tagReg, bodyReg, -8);
    LoadAt(tagReg, tagReg, 0, 8);
    LoadAt(cmpReg, tagReg, T.extLevel * 8, 8);
    TypeDescAddr(targReg, T);
    G.Cmp(cmpReg, targReg);
    DEC(RH, 4);
    SetCond(x, EQ);
    x.type := ST.boolType
  ELSE
    x.mode := ST.Const; x.a := 0; x.type := ST.boolType
  END
END IsTest;

(** Type-guard `p(T)` for Pointer p.  Emits the same tag-walk + compare
    as IsTest, but on mismatch the program traps (BRK 1) rather than
    yielding FALSE; after the guard, x's static type is narrowed by the
    caller.  The pointer designator x is preserved unchanged: we work
    on a temporary copy of x so that subsequent selectors (e.g. `^.fld`)
    still re-load it from its original location.

    For cross-module T (descOffset < 0) the guard is a no-op (degraded
    mode, same as IsTest). *)
PROCEDURE TypeGuard*(VAR x: Item; T: ST.Type);
VAR bodyReg, tagReg, cmpReg, targReg, okL: INTEGER;
BEGIN
  IF (T # NIL) & (T.form = ST.Record) & (T.descOffset >= 0)
      & (x.type # NIL) & ((x.type.form = ST.Pointer) OR (x.type.form = ST.Record)) THEN
    bodyReg := AllocR();
    LoadBodyAddr(x, bodyReg);
    tagReg := AllocR();
    cmpReg := AllocR();
    targReg := AllocR();
    G.AddImm(tagReg, bodyReg, -8);
    LoadAt(tagReg, tagReg, 0, 8);
    LoadAt(cmpReg, tagReg, T.extLevel * 8, 8);
    TypeDescAddr(targReg, T);
    G.Cmp(cmpReg, targReg);
    G.BCond(EQ, 0);
    okL := G.Here() - 1;
    G.Brk(1);
    G.PatchBCond(okL, G.Here());
    DEC(RH, 4)
  END
END TypeGuard;

(** Dubova 5.14: verify actual record's dynamic type extends formal. *)
PROCEDURE EmitRecordParamTypeCheck*(VAR x: Item; formalType: ST.Type);
VAR bodyReg, tagReg, cmpReg, targReg, okL: INTEGER;
BEGIN
  IF (formalType # NIL) & (formalType.form = ST.Record)
      & (formalType.descOffset >= 0) THEN
    bodyReg := AllocR();
    LoadBodyAddr(x, bodyReg);
    tagReg := AllocR();
    cmpReg := AllocR();
    targReg := AllocR();
    G.AddImm(tagReg, bodyReg, -8);
    LoadAt(tagReg, tagReg, 0, 8);
    LoadAt(cmpReg, tagReg, formalType.extLevel * 8, 8);
    TypeDescAddr(targReg, formalType);
    G.Cmp(cmpReg, targReg);
    G.BCond(EQ, 0);
    okL := G.Here() - 1;
    G.Brk(1);
    G.PatchBCond(okL, G.Here());
    DEC(RH, 4)
  END
END EmitRecordParamTypeCheck;

(** Write the type tag word at [bodyAddr-8] for a record variable. *)
PROCEDURE EmitRecordBodyTag*(bodyOff, lev, extImp: INTEGER; T: ST.Type);
VAR tagReg, addrReg, tagOff: INTEGER;
BEGIN
  IF (T # NIL) & (T.form = ST.Record) & (T.descOffset >= 0) THEN
    tagReg := AllocR();
    TypeDescAddr(tagReg, T);
    tagOff := bodyOff - 8;
    IF tagOff < 0 THEN
      addrReg := AllocR();
      IF lev > 0 THEN AddrOffset(addrReg, FP, bodyOff)
      ELSE
        DataPageAdrp(addrReg, extImp);
        G.AddImm(addrReg, addrReg, bodyOff)
      END;
      G.AddImm(addrReg, addrReg, -8);
      StoreAt(tagReg, addrReg, 0, 8);
      DEC(RH, 2)
    ELSIF lev > 0 THEN
      StoreAt(tagReg, FP, tagOff, 8);
      DEC(RH)
    ELSE
      DataPageAdrp(RH, extImp);
      StoreAt(tagReg, RH, tagOff, 8);
      DEC(RH)
    END
  END
END EmitRecordBodyTag;

PROCEDURE EmitRecordVarTags*(scope: ST.Object; local: BOOLEAN);
VAR p: ST.Object;
  extImp: INTEGER;
BEGIN
  p := scope.next;
  WHILE p # ST.dummy DO
    IF (p.class = ST.Var) & (p.type # NIL) & (p.type.form = ST.Record) THEN
      IF local & (p.lev > 0) THEN
        EmitRecordBodyTag(M.SHORT(p.address), p.lev, -1, p.type)
      ELSIF ~local & (p.lev = 0) THEN
        extImp := -1;
        IF p.external THEN extImp := p.importIdx END;
        EmitRecordBodyTag(M.SHORT(p.address), 0, extImp, p.type)
      END
    END;
    p := p.next
  END
END EmitRecordVarTags;

PROCEDURE ZeroLocals*(fromOff, toOff: INTEGER);
VAR off: INTEGER;
BEGIN
  G.MovImm(RH, 0);
  off := fromOff;
  WHILE off # toOff DO
    StoreAt(RH, FP, off, 8);
    off := off + 8
  END;
  RH := 0
END ZeroLocals;

PROCEDURE EmitNilGlobals*(scope: ST.Object);
VAR p: ST.Object;
  valReg, addrReg, extImp: INTEGER;
BEGIN
  valReg := RH;
  G.MovImm(valReg, 0);
  INC(RH);
  p := scope.next;
  WHILE p # ST.dummy DO
    IF (p.class = ST.Var) & (p.lev = 0) & (p.type # NIL)
        & (p.type.form IN {ST.Pointer, ST.Proc}) THEN
      extImp := -1;
      IF p.external THEN extImp := p.importIdx END;
      addrReg := RH; INC(RH);
      DataPageAdrp(addrReg, extImp);
      StoreAt(valReg, addrReg, M.SHORT(p.address), 8)
    END;
    p := p.next
  END;
  RH := 0
END EmitNilGlobals;

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
    LoadAt(lenReg, FP, lenAddr, 8);
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
  LoadAt(RH, FP, lenBaseAddr + 8, 8);
  k := 2;
  WHILE k <= numLens DO
    LoadAt(RH + 1, FP, lenBaseAddr + k * 8, 8);
    G.Mul(RH, RH, RH + 1);
    INC(k)
  END;
  IF elemSize # 1 THEN
    G.MovImm(RH + 1, elemSize);
    G.Mul(RH, RH, RH + 1)
  END
END EmitDynStride;

(** Index into a string CONST designator. Result is CHAR; read-only. *)
PROCEDURE StringIndex*(VAR x, y: Item);
VAR idx, addrReg: INTEGER;
  pe: ST.StringEntry;
BEGIN
  IF (x.type = NIL) OR (x.type.form # ST.String) THEN S.Mark(E.notArray)
  ELSIF x.mode # ST.Const THEN S.Mark(E.incompatible)
  ELSE
    IF y.mode = ST.Const THEN
      idx := M.SHORT(y.a);
      IF (idx < 0) OR (idx >= x.type.len) THEN S.Mark(E.indexOutOfBounds) END;
      pe := ST.PoolEntry(M.SHORT(x.a));
      IF pe # NIL THEN
        MakeConstItem(x, ST.charType, ORD(pe.bytes[idx]))
      END
    ELSE
      Load(y);
      CheckIndexBounds(y.r, x.type.len, 0);
      addrReg := AllocR();
      G.LoadStringAddr(addrReg, M.SHORT(x.a));
      G.AddLsl(x.r, addrReg, y.r, 1);
      LoadAt(x.r, x.r, 0, 2);
      x.mode := Reg;
      x.rdo := TRUE;
      x.type := ST.charType;
      DEC(RH)
    END;
    IF x.mode = ST.Const THEN x.rdo := TRUE END
  END
END StringIndex;

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
        AddrOffset(RH, FP, M.SHORT(x.a))
      ELSE (* global array *)
        DataPageAdrp(RH, x.extImp);
        AddrOffset(RH, RH, M.SHORT(x.a))
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
      LoadAt(RH, FP, M.SHORT(x.a), 8); (* load array base address *)
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
    (* Emit the negated-cond branch first so the true-list (x.b) lands
       AFTER it (i.e., at the THEN block's first real instruction).
       Patching x.b before the BCond would route every short-circuit
       OR-true straight back into the conditional jump and cause it to
       reuse the latest CMP's flags -- a subtle bug that only fires
       when the OR fell through with NZCV that happens to satisfy the
       negated RHS condition. *)
    G.BCond(Negated(x.r), M.SHORT(x.a));
    x.a := G.Here() - 1;
    FixLink(x.b);
    x.b := 0
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
  IF y.r = NV THEN
    x.r := NV; FixLink(M.SHORT(x.b)); x.b := 0
  ELSIF x.r = NV THEN
    FixLink(M.SHORT(y.a)); FixLink(y.b)
  ELSIF x.r = AL THEN
    IF y.r = NV THEN x.r := NV
    ELSE
      x.a := MergeLists(M.SHORT(y.a), M.SHORT(x.a));
      x.b := MergeLists(y.b, x.b); x.r := y.r
    END
  ELSE
    IF y.r = NV THEN
      x.r := NV
    ELSIF y.r = AL THEN
      x.a := MergeLists(M.SHORT(y.a), M.SHORT(x.a));
      x.b := MergeLists(y.b, x.b)
    ELSE
      G.BCond(Negated(y.r), M.SHORT(x.a));
      x.a := G.Here() - 1;
      x.b := MergeLists(y.b, x.b);
      x.r := y.r
    END
  END
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
    (* If LHS is true, branch to Or2's exit (x.b patched there) and skip
       RHS.  Clear the false-list head in x.a first (same as And1/CFJump). *)
    G.BCond(x.r, x.b);
    x.b := G.Here() - 1;
    FixLink(M.SHORT(x.a));
    x.a := 0
  END
END Or1;

(** x := x OR y *)
PROCEDURE Or2*(VAR x, y: Item);
BEGIN
  LoadCond(y);
  IF x.r = AL THEN
    FixLink(M.SHORT(y.a)); FixLink(y.b)
  ELSIF y.r = AL THEN
    x.r := AL; x.a := 0; x.b := 0
  ELSIF (x.r = NV) & (y.r = NV) THEN
    x.r := NV; x.a := 0; x.b := 0
  ELSIF x.r = NV THEN
    x.a := y.a; x.b := y.b; x.r := y.r
  ELSE
    x.a := MergeLists(M.SHORT(y.a), M.SHORT(x.a));
    x.b := MergeLists(y.b, x.b);
    x.r := y.r
  END
END Or2;

(** Procedure Calls *)

(** Place actual parameter x in ARM64 argument register x{slot}.
    Expression evaluation may leave the value in any register with RH
    ahead of the next ABI slot; force x{slot} and RH := slot + 1 before
    the next actual is prepared. *)
PROCEDURE ValueParam*(VAR x: Item; slot: INTEGER);
VAR s: INTEGER;
BEGIN
  s := slot;
  IF x.mode = RegI THEN Load(x); x.mode := Reg
  ELSIF x.type.form = ST.Record THEN LoadAddr(x)
  ELSIF x.mode # Reg THEN Load(x)
  END;
  IF (slot >= 0) & (x.mode = Reg) THEN
    IF x.r # s THEN
      IF x.type.form = ST.LongReal THEN
        IF x.r # s THEN G.Mov(s, x.r) END
      ELSIF x.type.form = ST.Real THEN G.FMovS(s, x.r)
      ELSE G.Mov(s, x.r)
      END
    END;
    x.r := s;
    RH := s + 1
  END
END ValueParam;

(** VAR-parameters are passed as pointers in x{slot}. *)
PROCEDURE VarParam*(VAR x: Item; slot: INTEGER);
VAR s: INTEGER;
BEGIN
  s := slot;
  LoadAddr(x);
  IF (slot >= 0) & (x.mode = Reg) THEN
    IF x.r # s THEN G.Mov(s, x.r) END;
    x.r := s;
    RH := s + 1
  END
END VarParam;

PROCEDURE LoadParamLen*(VAR x: Item; address: INTEGER);
BEGIN
  x.mode := Reg;
  x.type := ST.intType;
  x.rdo := FALSE;
  x.r := AllocR();
  LoadAt(x.r, FP, address, 8)
END LoadParamLen;

PROCEDURE LoadAddress(VAR x: Item);
BEGIN
  IF x.mode = RegI THEN Load(x); x.mode := Reg
  ELSIF x.mode # Reg THEN Load(x)
  END
END LoadAddress;

(** SYSTEM.BIT(a, n): bit n of the word at byte address a. *)
PROCEDURE SystemBit*(VAR x: Item; VAR addr, n: Item);
VAR w: INTEGER;
BEGIN
  LoadAddress(addr);
  Load(n);
  w := AllocR();
  LoadAt(w, addr.r, 0, 4);
  G.Ror(w, w, n.r);
  G.AndImm1(w, w);
  x.mode := Reg;
  x.type := ST.boolType;
  x.r := w;
  x.a := 0; x.b := 0; x.rdo := FALSE; x.extImp := -1;
  DEC(RH, 2)
END SystemBit;

PROCEDURE MemLoadToReg(reg, addrReg: INTEGER; T: ST.Type);
BEGIN
  IF T.form = ST.LongReal THEN
    FDLoadAt(reg, addrReg, 0);
    G.FMovDtoX(reg, reg)
  ELSIF T.form = ST.Real THEN
    FLoadAt(reg, addrReg, 0);
    G.FMovStoW(reg, reg)
  ELSE
    LoadAt(reg, addrReg, 0, T.size)
  END
END MemLoadToReg;

PROCEDURE MemStoreFromReg(reg, addrReg: INTEGER; T: ST.Type);
BEGIN
  IF T.form = ST.LongReal THEN
    G.FMovXtoD(reg, reg);
    FDStoreAt(reg, addrReg, 0)
  ELSIF T.form = ST.Real THEN
    FStoreAt(reg, addrReg, 0)
  ELSE
    StoreAt(reg, addrReg, 0, T.size)
  END
END MemStoreFromReg;

(** SYSTEM.GET(a, v): load elementary value from mem[a] into VAR v. *)
PROCEDURE SystemGet*(VAR addr: Item; VAR dest: Item);
VAR a, d, v: INTEGER;
BEGIN
  LoadAddr(dest);
  d := dest.r;
  LoadAddress(addr);
  a := addr.r;
  v := AllocR();
  MemLoadToReg(v, a, dest.type);
  IF dest.type.form = ST.LongReal THEN
    G.FMovXtoD(v, v);
    FDStoreAt(v, d, 0)
  ELSIF dest.type.form = ST.Real THEN
    FStoreAt(v, d, 0)
  ELSIF (dest.type.form = ST.Int) & (M.WordSize = 8) THEN
    G.Sxtw(v, v);
    StoreAt(v, d, 0, 8)
  ELSE
    StoreAt(v, d, 0, dest.type.size)
  END;
  DEC(RH, 3)
END SystemGet;

(** SYSTEM.PUT(a, x): store elementary x at mem[a]. *)
PROCEDURE SystemPut*(VAR addr: Item; src: Item);
VAR a: INTEGER; s: Item;
BEGIN
  s := src;
  LoadAddress(addr);
  a := addr.r;
  IF s.mode = RegI THEN Load(s); s.mode := Reg
  ELSIF s.mode # Reg THEN Load(s)
  END;
  MemStoreFromReg(s.r, a, s.type);
  DEC(RH, 1)
END SystemPut;

PROCEDURE Copy16Fwd(s, d, rLo, rHi, t: INTEGER);
BEGIN
  G.Ldp(rLo, rHi, s, 16);
  G.StrReg(rLo, d, 0, 8);
  G.AddImm(t, 0, 8);
  G.StrReg(rHi, d, t, 8);
  G.AddImm(d, d, 16)
END Copy16Fwd;

PROCEDURE Copy16Back(s, d, off, rLo, rHi, t: INTEGER);
BEGIN
  G.LdrReg(rLo, s, off, 8);
  G.AddImm(t, off, 8);
  G.LdrReg(rHi, s, t, 8);
  G.StrReg(rLo, d, off, 8);
  G.StrReg(rHi, d, t, 8)
END Copy16Back;

PROCEDURE CopyTail(s, d, nReg, w: INTEGER);
VAR skipL: INTEGER;
BEGIN
  G.CmpImm(nReg, 8);
  G.BCond(LO, 0);
  skipL := G.Here() - 1;
  LoadAt(w, s, 0, 8);
  StoreAt(w, d, 0, 8);
  G.AddImm(s, s, 8);
  G.AddImm(d, d, 8);
  G.AddImm(nReg, nReg, 0FFFFFFF8H);
  G.PatchBCond(skipL, G.Here());
  G.CmpImm(nReg, 4);
  G.BCond(LO, 0);
  skipL := G.Here() - 1;
  LoadAt(w, s, 0, 4);
  StoreAt(w, d, 0, 4);
  G.AddImm(s, s, 4);
  G.AddImm(d, d, 4);
  G.AddImm(nReg, nReg, 0FFFFFFFCH);
  G.PatchBCond(skipL, G.Here());
  G.CmpImm(nReg, 2);
  G.BCond(LO, 0);
  skipL := G.Here() - 1;
  LoadAt(w, s, 0, 2);
  StoreAt(w, d, 0, 2);
  G.AddImm(s, s, 2);
  G.AddImm(d, d, 2);
  G.AddImm(nReg, nReg, 0FFFFFFFEH);
  G.PatchBCond(skipL, G.Here());
  G.CmpImm(nReg, 1);
  G.BCond(LO, 0);
  skipL := G.Here() - 1;
  LoadAt(w, s, 0, 1);
  StoreAt(w, d, 0, 1);
  G.PatchBCond(skipL, G.Here())
END CopyTail;

(** SYSTEM.COPY(src, dst, n): copy n bytes; overlap-safe; LDP/STP by 16. *)
PROCEDURE SystemCopy*(VAR src, dst, cnt: Item);
VAR s, d, n, rem, rLo, rHi, w, t, top, exitL, fwdL1, fwdL2, end, fwdLab, loopExitL, skipBackL: INTEGER;
BEGIN
  LoadAddress(src);
  s := src.r;
  LoadAddress(dst);
  d := dst.r;
  Load(cnt);
  n := cnt.r;
  rem := AllocR();
  G.Mov(rem, n);
  rLo := AllocR();
  rHi := AllocR();
  w := AllocR();
  t := AllocR();
  G.CmpImm(n, 0);
  G.BCond(EQ, 0);
  exitL := G.Here() - 1;
  G.Cmp(d, s);
  G.BCond(LE, 0);
  fwdL1 := G.Here() - 1;
  end := AllocR();
  G.Add(end, s, n);
  G.Cmp(d, end);
  G.BCond(GE, 0);
  fwdL2 := G.Here() - 1;
  top := G.Here();
  G.CmpImm(rem, 16);
  G.BCond(LO, 0);
  loopExitL := G.Here() - 1;
  G.AddImm(rem, rem, 0FFFFFFF0H);
  Copy16Back(s, d, rem, rLo, rHi, t);
  G.B(0);
  G.PatchB(G.Here() - 1, top);
  G.PatchBCond(loopExitL, G.Here());
  CopyTail(s, d, rem, w);
  G.B(0);
  skipBackL := G.Here() - 1;
  fwdLab := G.Here();
  G.PatchBCond(fwdL1, fwdLab);
  G.PatchBCond(fwdL2, fwdLab);
  top := G.Here();
  G.CmpImm(rem, 16);
  G.BCond(LO, 0);
  loopExitL := G.Here() - 1;
  Copy16Fwd(s, d, rLo, rHi, t);
  G.AddImm(rem, rem, 0FFFFFFF0H);
  G.B(0);
  G.PatchB(G.Here() - 1, top);
  G.PatchBCond(loopExitL, G.Here());
  CopyTail(s, d, rem, w);
  G.PatchBCond(skipBackL, G.Here());
  G.PatchBCond(exitL, G.Here());
  DEC(RH, 7)
END SystemCopy;

PROCEDURE PrepInt32(VAR x: Item);
BEGIN
  Load(x);
  IF M.WordSize = 8 THEN MaskSetReg(x.r, 4) END
END PrepInt32;

(** SYSTEM.ADC(m, n): add with carry flag. *)
PROCEDURE SystemAdc*(VAR x: Item; VAR m, n: Item);
VAR rd: INTEGER;
BEGIN
  PrepInt32(m); PrepInt32(n);
  rd := AllocR();
  G.Adcs(rd, m.r, n.r);
  x.mode := Reg;
  x.type := ST.intType;
  x.r := rd;
  x.a := 0; x.b := 0; x.rdo := FALSE; x.extImp := -1;
  DEC(RH, 2)
END SystemAdc;

(** SYSTEM.SBC(m, n): subtract with borrow flag. *)
PROCEDURE SystemSbc*(VAR x: Item; VAR m, n: Item);
VAR rd: INTEGER;
BEGIN
  PrepInt32(m); PrepInt32(n);
  rd := AllocR();
  G.Sbcs(rd, m.r, n.r);
  x.mode := Reg;
  x.type := ST.intType;
  x.r := rd;
  x.a := 0; x.b := 0; x.rdo := FALSE; x.extImp := -1;
  DEC(RH, 2)
END SystemSbc;

(** SYSTEM.UML(m, n): unsigned multiply, low 32 bits. *)
PROCEDURE SystemUml*(VAR x: Item; VAR m, n: Item);
VAR rd: INTEGER;
BEGIN
  PrepInt32(m); PrepInt32(n);
  rd := AllocR();
  G.Umull(rd, m.r, n.r);
  IF M.WordSize = 8 THEN MaskSetReg(rd, 4) END;
  x.mode := Reg;
  x.type := ST.intType;
  x.r := rd;
  x.a := 0; x.b := 0; x.rdo := FALSE; x.extImp := -1;
  DEC(RH, 2)
END SystemUml;

PROCEDURE StoreIntItem(VAR dest: Item; valReg: INTEGER);
VAR addr: INTEGER;
BEGIN
  IF dest.mode = RegI THEN
    StoreAt(valReg, dest.r, 0, 4)
  ELSIF dest.mode = ST.Var THEN
    IF dest.b > 0 THEN StoreAt(valReg, FP, M.SHORT(dest.a), 4)
    ELSE
      DataPageAdrp(RH, dest.extImp);
      StoreAt(valReg, RH, M.SHORT(dest.a), 4)
    END
  ELSIF dest.mode = ST.VarPar THEN
    LoadAt(addr, FP, M.SHORT(dest.a), 8);
    StoreAt(valReg, addr, 0, 4);
    DEC(RH)
  ELSE S.Mark(E.incompatible)
  END
END StoreIntItem;

(** ft := ft * 2^nReg (IEEE single bits in ft). *)
PROCEDURE RealLdexp(ft, nReg: INTEGER);
VAR t, ftS, sh, topRH: INTEGER;
BEGIN
  topRH := RH;
  ftS := AllocR();
  t := AllocR();
  sh := AllocR();
  G.MovImm(t, 127);
  G.Add(t, nReg, t);
  G.MovImm(sh, 23);
  G.Lsl(t, t, sh);
  G.FMovWtoS(ftS, t);
  G.FMul(ft, ft, ftS);
  RH := topRH
END RealLdexp;

(** Normalize IEEE single bits in r to [1, 2); unbiased exponent in nOut. *)
PROCEDURE RealUnpkBits(r, nOut: INTEGER);
VAR expW, frac, sign, t, topRH: INTEGER;
BEGIN
  topRH := RH;
  expW := AllocR();
  t := AllocR();
  frac := AllocR();
  sign := AllocR();
  G.AsrImm(expW, r, 23);
  G.MovImm(t, ieeeExpMask);
  G.And(expW, expW, t);
  G.MovImm(t, 127);
  G.Sub(nOut, expW, t);
  G.MovImm(t, ieeeFracMask);
  G.And(frac, r, t);
  G.AsrImm(sign, r, 31);
  G.Lsl(sign, sign, 31);
  G.MovImm(t, ieeeOne);
  G.Orr(r, sign, t);
  G.Orr(r, r, frac);
  RH := topRH
END RealUnpkBits;

(** SYSTEM.PACK(x, n): x := x * 2^n. *)
PROCEDURE SystemPack*(VAR x: Item; VAR n: Item);
VAR addr, ft: INTEGER;
BEGIN
  LoadAddr(x);
  addr := x.r;
  ft := AllocR();
  FLoadAt(ft, addr, 0);
  Load(n);
  RealLdexp(ft, n.r);
  FStoreAt(ft, addr, 0);
  DEC(RH, 2)
END SystemPack;

(** SYSTEM.UNPK(x, n): normalize x; n := exponent. *)
PROCEDURE SystemUnpk*(VAR x: Item; VAR n: Item);
VAR addr, w, nReg: INTEGER;
BEGIN
  LoadAddr(x);
  addr := x.r;
  w := AllocR();
  nReg := AllocR();
  LoadAt(w, addr, 0, 4);
  RealUnpkBits(w, nReg);
  StoreAt(w, addr, 0, 4);
  StoreIntItem(n, nReg);
  DEC(RH, 2)
END SystemUnpk;

(** SYSTEM.DIV(m, n): signed divide, trunc toward zero (SDIV). *)
PROCEDURE SystemDiv*(VAR x: Item; VAR m, n: Item);
VAR rd: INTEGER;
BEGIN
  PrepInt32(m); PrepInt32(n);
  rd := AllocR();
  G.Div(rd, m.r, n.r);
  x.mode := Reg;
  x.type := ST.intType;
  x.r := rd;
  x.a := 0; x.b := 0; x.rdo := FALSE; x.extImp := -1;
  DEC(RH, 2)
END SystemDiv;

(** SYSTEM.MOD(m, n): remainder after truncating divide. *)
PROCEDURE SystemMod*(VAR x: Item; VAR m, n: Item);
VAR rd, q, t: INTEGER;
BEGIN
  PrepInt32(m); PrepInt32(n);
  q := AllocR();
  G.Div(q, m.r, n.r);
  t := AllocR();
  G.Mul(t, q, n.r);
  rd := AllocR();
  G.Sub(rd, m.r, t);
  x.mode := Reg;
  x.type := ST.intType;
  x.r := rd;
  x.a := 0; x.b := 0; x.rdo := FALSE; x.extImp := -1;
  DEC(RH, 3)
END SystemMod;

(** SYSTEM.COND(n): IF uses B.cond on NZCV from the preceding ADC/SBC/UML. *)
PROCEDURE SystemCond*(VAR x: Item; VAR n: Item);
VAR cc: INTEGER;
BEGIN
  cc := M.SHORT(SetBitsConst(n.a, n.type)) MOD 16;
  IF cc < 0 THEN cc := cc + 16 END;
  x.mode := Cond;
  x.type := ST.boolType;
  x.r := cc;
  x.a := 0; x.b := 0; x.rdo := FALSE; x.extImp := -1
END SystemCond;

(** Called before Actual Parameters.
    Saves live registers x0..x(RH-1) to stack if any. *)
PROCEDURE PrepCall*(VAR x: Item; VAR rx: INTEGER);
VAR i: INTEGER;
BEGIN
  rx := RH;
  IF RH > 0 THEN
    G.AddImm(SP, SP, -(((RH + 1) DIV 2) * 16));
    FOR i := 0 TO RH - 1 DO
      StoreAt(i, SP, i * 8, 8)
    END;
    RH := 0
  END
END PrepCall;

(** Called after Actual Parameters.
    proc is the target procedure object for direct calls (used for
    forward-reference resolution). *)
PROCEDURE Call*(VAR x: Item; rx: INTEGER; proc: ST.Object);
VAR i: INTEGER;
  pname: ARRAY 64 OF CHAR;
BEGIN
  ASSERT(proc # NIL);
  (* x.a < 0: inline call ID; x.a >= 0: user procedure word offset *)
  IF x.a = -100 (* SYSTEM.SVC(n [, a0 .. a5]): LONGINT; RH = arity *) THEN
    (* x0..x(RH-1) hold actuals; Darwin ABI wants n in x16, args in x0.. *)
    G.Mov(16, 0);
    FOR i := 1 TO RH - 1 DO
      G.Mov(i - 1, i)
    END;
    G.Svc(0)
  ELSE (* user-defined procedure call *)
    IF x.mode = ST.Const THEN (* direct call *)
      IF proc.external THEN
        (* Cross-module call: placeholder BL + extCallReloc for linker *)
        ST.GetName(proc.names, pname);
        G.CallExt(proc.importIdx, pname)
      ELSIF ~proc.procResolved THEN
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
      LoadAt(i, SP, i * 8, 8)
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

(** Module init proc prologue: save FP, LR.  No parameters, no locals. *)
PROCEDURE ModuleInitPrologue*;
BEGIN
  G.Stp(FP, LR, SP, -16);
  G.Mov(FP, SP)
END ModuleInitPrologue;

(** Emit module init epilogue. *)
PROCEDURE ModuleInitEpilogue*;
BEGIN
  RH := 0;
  G.Ldp(FP, LR, SP, 16);
  G.Ret()
END ModuleInitEpilogue;

(** Procedure prologue: stp fp,lr,[sp,#-16]!; mov fp,sp; sub sp,#(frame-16);
    spill x0.. into param slots at FP- parBytes + i*8. *)
PROCEDURE ProcPrologue*(frameSize, nSlots: INTEGER);
VAR i, below, parBytes: INTEGER;
BEGIN
  G.Stp(FP, LR, SP, -16);
  G.Mov(FP, SP);
  below := frameSize - 16;
  IF below # 0 THEN AdjustSP(-below) END;
  parBytes := nSlots * 8;
  RH := nSlots;
  FOR i := 0 TO nSlots - 1 DO
    StoreAt(i, FP, -parBytes + i * 8, 8)
  END;
  RH := 0
END ProcPrologue;

(** Procedure epilogue: drop stack below link, restore FP/LR, return. *)
PROCEDURE ProcEpilogue*(frameSize: INTEGER);
VAR below: INTEGER;
BEGIN
  below := frameSize - 16;
  IF below # 0 THEN AdjustSP(below) END;
  G.Ldp(FP, LR, SP, 16);
  G.Ret()
END ProcEpilogue;

(** Load function return value into x0 *)
PROCEDURE ReturnVal*(VAR x: Item);
BEGIN
  Load(x);
  IF x.r # 0 THEN G.Mov(0, x.r) END;
  RH := 0
END ReturnVal;

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

PROCEDURE SetNoAssert*(on: BOOLEAN);
BEGIN
  noAssert := on;
  IF on THEN G.SetCompileFlags(M.compileFlagNoAssert)
  ELSE G.SetCompileFlags(0)
  END
END SetNoAssert;

PROCEDURE SetModuleName*(modName: ARRAY OF CHAR);
VAR idx, len: INTEGER;
BEGIN
  len := 0; WHILE (modName[len] # 0X) & (len < LEN(modName) - 1) DO INC(len) END;
  idx := ST.RegisterString(modName, len);
  assertModIdx := idx;
  assertModLen := len
END SetModuleName;

PROCEDURE SetProcName*(procName: ARRAY OF CHAR);
VAR idx, len: INTEGER;
BEGIN
  len := 0; WHILE (procName[len] # 0X) & (len < LEN(procName) - 1) DO INC(len) END;
  idx := ST.RegisterString(procName, len);
  assertProcIdx := idx;
  assertProcLen := len
END SetProcName;

PROCEDURE CallKernelAssert(n, line: INTEGER);
VAR rx, importIdx, slot, i: INTEGER;
  dummy, m, p, ml, pl, ln, nc: Item;
BEGIN
  importIdx := G.AddImport('Kernel');
  MakeConstItem(dummy, ST.intType, 0);
  PrepCall(dummy, rx);
  slot := 0;
  MakeStringConstItem(m, assertModIdx, assertModLen);
  VarParam(m, slot); INC(slot);
  MakeConstItem(ml, ST.intType, assertModLen + 1);
  ValueParam(ml, slot); INC(slot);
  MakeStringConstItem(p, assertProcIdx, assertProcLen);
  VarParam(p, slot); INC(slot);
  MakeConstItem(pl, ST.intType, assertProcLen + 1);
  ValueParam(pl, slot); INC(slot);
  MakeConstItem(ln, ST.intType, line);
  ValueParam(ln, slot); INC(slot);
  MakeConstItem(nc, ST.intType, n);
  ValueParam(nc, slot);
  G.CallExt(importIdx, 'Assert');
  IF rx > 0 THEN
    FOR i := 0 TO rx - 1 DO LoadAt(i, SP, i * 8, 8) END;
    G.AddImm(SP, SP, ((rx + 1) DIV 2) * 16);
    RH := rx
  ELSE RH := 0
  END
END CallKernelAssert;

(** ASSERT(b [, n]): on FALSE call Kernel.Assert(mod, proc, line, n). *)
PROCEDURE Assert*(VAR x: Item; n, line: INTEGER);
VAR okL: INTEGER;
BEGIN
  IF ~noAssert THEN
    IF (x.mode = ST.Const) & (x.type.form = ST.Bool) THEN
      IF x.a = 0 THEN CallKernelAssert(n, line) END
    ELSE
      IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
      Load(x);
      G.CmpImm(x.r, 0);
      G.BCond(NE, 0); okL := G.Here() - 1;
      CallKernelAssert(n, line);
      G.PatchBCond(okL, G.Here());
      DEC(RH);
      FixRH(0)
    END
  END
END Assert;

(** Generates a trap instruction for unmatched CASE. *)
PROCEDURE Trap*;
BEGIN
  G.Brk(1)
END Trap;

PROCEDURE Init*;
BEGIN
  RH := 0;
  SH := firstCSReg;
  assertModIdx := 0;
  assertModLen := 0;
  assertProcIdx := 0;
  assertProcLen := 0;
  G.Init
END Init;

PROCEDURE Close*;
BEGIN
  G.Close
END Close;

END Emitter.
