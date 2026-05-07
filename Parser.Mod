MODULE Parser;
IMPORT S := Scanner, ST := SymTable, E := ErrorMsg, Strings,
  Generator, Emitter, Out, Lang, M := Machine, SYSTEM;

TYPE
  LONGINT = M.LONGINT;
  LONGREAL = M.LONGREAL;

VAR
  sym: INTEGER;
  dummy: ST.Object; (** In case of error in QualIdent *)
  varsize: INTEGER; (** How many bytes variables occupy *)

  Expr0: PROCEDURE(VAR x: Emitter.Item);
  StatSeq0: PROCEDURE;
  Type0: PROCEDURE(VAR T: ST.Type);
  FormalType0: PROCEDURE(VAR T: ST.Type);

  allowOpenArrayParams: BOOLEAN;

  modName: ST.Name; (** Names of last compiled module *)

(** Returns name of the last compiled module in current language. *)
PROCEDURE GetModName*(VAR name: ARRAY OF CHAR);
BEGIN
  ST.GetName(modName, name)
END GetModName;

PROCEDURE Load*(fname: ARRAY OF CHAR): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  ok := FALSE;
  IF S.Load(fname) THEN
    S.Get(sym);
    IF (sym = S.ident) & Lang.Identify(S.id) THEN ok := TRUE END;
    S.Rewind
  END;
  IF ~ok THEN S.Mark(E.unknownLang) END
RETURN ok END Load;

PROCEDURE CheckInt(VAR x: Emitter.Item);
BEGIN
  IF ~(x.type.form IN {ST.Int, ST.Byte, ST.ShortInt, ST.LongInt}) THEN
    S.Mark(E.notInt);
    x.type := ST.intType
  END
END CheckInt;

(** Import = [ident ":="] ident. *)
PROCEDURE Import;
VAR name: ARRAY 64 OF CHAR;
  M: ST.Object;
BEGIN
  IF sym = S.ident THEN
    Strings.Copy(S.id, name);
    M := ST.NewObject(ST.Mod, name);
    S.Get(sym);
    IF sym = S.becomes THEN
      S.Get(sym);
      IF sym = S.ident THEN Strings.Copy(S.id, name); S.Get(sym)
      ELSE S.Mark(E.expIdent)
      END
    END;
    ST.Import(M)
  ELSE S.Mark(E.expIdent)
  END
END Import;

(** ImportList = Import {"," Import} ";". *)
PROCEDURE ImportList;
BEGIN
  Import;
  WHILE sym = S.comma DO S.Get(sym); Import END;
  IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END
END ImportList;

PROCEDURE FormalType(VAR T: ST.Type);
VAR x: Emitter.Item;
  elemType: ST.Type;
  dims: ARRAY 8 OF INTEGER;
  n, i: INTEGER;
BEGIN
  IF sym = S.array THEN
    S.Get(sym);
    IF sym = S.of THEN
      IF ~allowOpenArrayParams THEN S.Mark(E.incompatible) END;
      S.Get(sym);
      FormalType(elemType);
      NEW(T);
      T.form := ST.Array;
      T.base := elemType;
      T.len := 0;
      T.size := 8;
      T.openRank := elemType.openRank + 1
    ELSE
      Expr0(x);
      IF x.mode # ST.Const THEN S.Mark(E.expConst); x.a := 1 END;
      dims[0] := M.SHORT(x.a); n := 1;
      WHILE (sym = S.comma) & (n < 8) DO
        S.Get(sym);
        Expr0(x);
        IF x.mode # ST.Const THEN S.Mark(E.expConst); x.a := 1 END;
        dims[n] := M.SHORT(x.a); INC(n)
      END;
      IF sym = S.of THEN S.Get(sym) ELSE S.Mark(E.expOf) END;
      FormalType(elemType);
      i := n - 1;
      WHILE i >= 0 DO
        NEW(T);
        T.form := ST.Array;
        T.base := elemType;
        T.len := dims[i];
        T.size := dims[i] * elemType.size;
        T.openRank := elemType.openRank;
        elemType := T;
        DEC(i)
      END
    END
  ELSE
    Type0(T)
  END
END FormalType;

(** FPSection = [VAR] ident {"," ident} ":" FormalType. *)
PROCEDURE FPSection(VAR nofPars: INTEGER);
VAR class: INTEGER;
  first, p: ST.Object;
  T: ST.Type;
BEGIN
  IF sym = S.var THEN class := ST.VarPar; S.Get(sym) ELSE class := ST.Var END;
  IF sym = S.ident THEN
    first := ST.NewObject(class, S.id);
    first.address := 16 + nofPars * 8; INC(nofPars);
    S.Get(sym);
    WHILE sym = S.comma DO
      S.Get(sym);
      IF sym = S.ident THEN
        IF nofPars >= 8 THEN S.Mark(E.tooManyParams) END;
        p := ST.NewObject(class, S.id);
        p.address := 16 + nofPars * 8; INC(nofPars);
        S.Get(sym)
      ELSE S.Mark(E.expIdent)
      END
    END;
    IF sym = S.colon THEN S.Get(sym) ELSE S.Mark(E.expColon) END;
    FormalType0(T);
    p := first;
    WHILE p # ST.dummy DO
      p.type := T;
      IF (class = ST.Var) & (T.form = ST.Array) THEN
        p.class := ST.VarPar; p.readOnly := TRUE
      END;
      p := p.next
    END
  ELSE S.Mark(E.expIdent)
  END
END FPSection;

(** ProcedureType = PROCEDURE ["(" [FPSection {";" FPSection}] ")"]
                    [":" Type]. *)
PROCEDURE ProcedureType(VAR T: ST.Type);
VAR n: INTEGER;
  oldOpen: BOOLEAN;
BEGIN
  S.Get(sym);
  NEW(T);
  T.form := ST.Proc;
  T.size := 8;
  T.openRank := 0;
  T.base := ST.noType;
  T.nofpars := 0;
  T.dsc := NIL;
  oldOpen := allowOpenArrayParams;
  allowOpenArrayParams := FALSE;
  IF sym = S.lparen THEN
    S.Get(sym);
    ST.OpenScope;
    n := 0;
    IF sym # S.rparen THEN
      FPSection(n);
      WHILE sym = S.semicol DO
        S.Get(sym);
        FPSection(n)
      END
    END;
    T.nofpars := n;
    T.dsc := ST.topScope.next;
    ST.CloseScope;
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
  END;
  allowOpenArrayParams := oldOpen;
  IF sym = S.colon THEN
    S.Get(sym);
    Type0(T.base)
  END
END ProcedureType;

(** Type = ident | ARRAY expr {"," expr} OF Type |
           PROCEDURE ["(" [FPSection {";" FPSection}] ")"]. *)
PROCEDURE Type(VAR T: ST.Type);
VAR p: ST.Object;
  x: Emitter.Item;
  elemType: ST.Type;
  dims: ARRAY 8 OF INTEGER;
  n, i: INTEGER;
BEGIN
  T := ST.intType;
  IF sym = S.ident THEN
    p := ST.ThisObject();
    S.Get(sym);
    IF p # NIL THEN
      IF p.class = ST.Typ THEN
        T := p.type
      ELSE S.Mark(E.expType)
      END
    ELSE S.Mark(E.undecl)
    END
  ELSIF sym = S.array THEN
    S.Get(sym);
    Expr0(x);
    IF x.mode # ST.Const THEN S.Mark(E.expConst); x.a := 1 END;
    dims[0] := M.SHORT(x.a); n := 1;
    WHILE (sym = S.comma) & (n < 8) DO
      S.Get(sym);
      Expr0(x);
      IF x.mode # ST.Const THEN S.Mark(E.expConst); x.a := 1 END;
      dims[n] := M.SHORT(x.a); INC(n)
    END;
    IF sym = S.of THEN S.Get(sym) ELSE S.Mark(E.expOf) END;
    Type(elemType);
    i := n - 1;
    WHILE i >= 0 DO
      NEW(T);
      T.form := ST.Array;
      T.base := elemType; (* Wrap around *)
      T.len := dims[i];
      T.openRank := 0;
      T.size := dims[i] * elemType.size;
      elemType := T;
      DEC(i)
    END
  ELSIF sym = S.procedure THEN
    ProcedureType(T)
  ELSE S.Mark(E.expIdent)
  END
END Type;

PROCEDURE CheckExport(VAR exported: BOOLEAN);
BEGIN
  IF sym = S.times THEN
    S.Get(sym);
    exported := TRUE
  ELSE
    exported := FALSE
  END
END CheckExport;

(** Alignment of T in bytes: scalar = T.size, array = alignment of element,
    record = max alignment of fields. *)
PROCEDURE Alignment(T: ST.Type): INTEGER;
VAR a, fa: INTEGER;
  field: ST.Object;
BEGIN
  WHILE T.form = ST.Array DO T := T.base END;
  IF T.form = ST.Record THEN
    a := 1;
    field := T.dsc;
    WHILE (field # NIL) & (field # ST.dummy) DO
      fa := Alignment(field.type);
      IF fa > a THEN a := fa END;
      field := field.next
    END
  ELSE
    a := T.size
  END
RETURN a END Alignment;

(** VarDecl = IdentList ":" Type. *)
PROCEDURE VarDecl(VAR firstObj: ST.Object);
VAR p, q: ST.Object;
  T: ST.Type;
  align: INTEGER;
BEGIN
  (* Save pointer to the first object created below *)
  p := ST.NewObject(ST.Var, S.id);
  firstObj := p;
  S.Get(sym);
  CheckExport(p.exported);
  WHILE sym = S.comma DO
    S.Get(sym);
    IF sym = S.ident THEN
      q := ST.NewObject(ST.Var, S.id);
      S.Get(sym);
      CheckExport(q.exported)
    ELSE S.Mark(E.expIdent)
    END
  END;
  IF sym = S.colon THEN ELSE S.Mark(E.expColon) END;
  S.Get(sym);
  Type(T);
  align := Alignment(T);
  REPEAT
    p.type := T;
    IF align > 1 THEN
      varsize := (varsize + align - 1) DIV align * align
    END;
    p.address := varsize;
    varsize := varsize + T.size;
    p := p.next
  UNTIL p = ST.dummy
END VarDecl;

(** ConstDecl = ident "=" ConstExpr. *)
PROCEDURE ConstDecl;
VAR p: ST.Object;
  x: Emitter.Item;
BEGIN
  IF sym = S.ident THEN
    p := ST.NewObject(ST.Const, S.id);
    S.Get(sym);
    CheckExport(p.exported);
    IF sym = S.eql THEN S.Get(sym)
    ELSE S.Mark(E.expEql)
    END;
    Expr0(x);
    IF x.mode # ST.Const THEN S.Mark(E.expConst); x.mode := ST.Const; x.a := 0 END;
    p.intVal := 0;
    IF (x.type # NIL) & (x.type.form = ST.Real) THEN
      p.realVal := SYSTEM.VAL(LONGREAL, SYSTEM.VAL(REAL, M.SHORT(x.a)))
    ELSE
      p.intVal := x.a
    END;
    p.type := x.type
  ELSE S.Mark(E.expIdent)
  END
END ConstDecl;

(** TypeDecl = ident "=" Type. *)
PROCEDURE TypeDecl;
VAR p: ST.Object;
  T: ST.Type;
BEGIN
  IF sym = S.ident THEN
    p := ST.NewObject(ST.Typ, S.id);
    S.Get(sym);
    CheckExport(p.exported);
    IF sym = S.eql THEN S.Get(sym)
    ELSE S.Mark(E.expEql)
    END;
    Type(T);
    p.type := T
  ELSE S.Mark(E.expIdent)
  END
END TypeDecl;

(** DeclSeq = [CONST {ConstDecl ";"}] [TYPE {TypeDecl ";"}]
             [VAR {VarDecl ";"}] {ProcedureDecl ";"}. *)
PROCEDURE DeclSeq;
VAR firstVar, p: ST.Object;
  i, j: INTEGER;
  name: ARRAY 64 OF CHAR;

  (** Read one translated identifier from S.transNames[i] starting
      at position j, until ',' or 0X, and advance j accordingly. *)
  PROCEDURE ReadTrans(i: INTEGER; VAR j: INTEGER; VAR name: ARRAY OF CHAR);
  VAR k: INTEGER;
  BEGIN
    k := 0;
    WHILE (S.transNames[i, j] # 0X) & (S.transNames[i, j] # ',') DO
      IF k # LEN(name) - 1 THEN
        name[k] := S.transNames[i, j]; INC(k)
      ELSE
        S.Mark(E.longTransName)
      END;
      INC(j)
    END;
    name[k] := 0X
  END ReadTrans;

  (** ProcedureDecl = ProcedureHeading ";" ProcedureBody ident. *)
  PROCEDURE ProcedureDecl;
  VAR proc: ST.Object;
    procType: ST.Type;
    procName: ST.Name;
    savedVarSize, nofPars, totalPars, parSize, frameSize: INTEGER;
    oldOpen: BOOLEAN;
    nameStr: ARRAY 64 OF CHAR;
    x: Emitter.Item;

    PROCEDURE AssignParamAddresses(VAR total: INTEGER);
    VAR p: ST.Object;
      slot: INTEGER;
    BEGIN
      slot := 0;
      p := ST.topScope.next;
      WHILE p # ST.dummy DO
        p.address := 16 + slot * 8;
        INC(slot, p.type.openRank + 1); (* one for pointer, one for each hidden length *)
        p := p.next
      END;
      total := slot
    END AssignParamAddresses;

  BEGIN
    S.Get(sym); (* consume PROCEDURE token *)
    IF sym = S.ident THEN
      (* Create procedure object in current (outer) scope *)
      proc := ST.NewObject(ST.Const, S.id);
      procName := NIL; ST.SetName(procName, S.id);
      S.Get(sym);

      (* Create procedure type *)
      NEW(procType);
      procType.form := ST.Proc;
      procType.openRank := 0;
      procType.base := ST.noType;
      procType.nofpars := 0;
      proc.type := procType;

      (* Open scope for parameters and locals *)
      ST.OpenScope;
      ST.IncLev;
      nofPars := 0;

      (* Parse formal parameters *)
      oldOpen := allowOpenArrayParams;
      allowOpenArrayParams := TRUE;
      IF sym = S.lparen THEN
        S.Get(sym);
        IF sym # S.rparen THEN
          FPSection(nofPars);
          WHILE sym = S.semicol DO
            S.Get(sym);
            FPSection(nofPars)
          END
        END;
        IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
      END;
      AssignParamAddresses(totalPars);
      IF totalPars > 8 THEN S.Mark(E.tooManyParams) END;
      allowOpenArrayParams := oldOpen;
      parSize := totalPars * 8;
      procType.nofpars := nofPars;
      procType.dsc := ST.topScope.next; (* link to first parameter *)

      (* Parse return type *)
      IF sym = S.colon THEN
        S.Get(sym);
        Type(procType.base)
      END;

      IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END;

      (* Parse local declarations *)
      savedVarSize := varsize; (* save to restore later *)
      varsize := 16 + parSize; (* locals start after saved FP/LR + params *)
      DeclSeq;

      (* Record entry point: nested procedures are now behind us, prologue
         comes next. Resolve any forward-reference fixups (e.g. nested
         procs that called this one before its address was known). *)
      proc.address := Generator.Here();
      Emitter.ResolveProc(proc);

      (* Emit prologue *)
      frameSize := (varsize + 15) DIV 16 * 16; (* 16-byte align *)
      Emitter.ProcPrologue(frameSize, totalPars, parSize);

      (* Parse body *)
      IF sym = S.begin THEN S.Get(sym); StatSeq0 END;

      (* Parse RETURN expression *)
      IF sym = S.return THEN
        S.Get(sym);
        IF procType.base.form = ST.NoTyp THEN S.Mark(E.incompatible) END;
        Expr0(x);
        Emitter.ReturnVal(x)
      END;

      Emitter.ProcEpilogue(frameSize);
      ST.CloseScope;
      ST.DecLev;
      varsize := savedVarSize; (* restore *)

      (* Check END ident *)
      IF sym = S.end THEN
        S.Get(sym);
        IF sym = S.ident THEN
          ST.GetName(procName, nameStr);
          IF nameStr # S.id THEN S.Mark(E.procNameMismatch) END;
          S.Get(sym)
        ELSE S.Mark(E.expIdent)
        END
      ELSE S.Mark(E.expEnd)
      END
    ELSE S.Mark(E.expIdent)
    END
  END ProcedureDecl;

BEGIN
  IF sym = S.const THEN
    S.Get(sym);
    WHILE sym = S.ident DO
      ConstDecl;
      IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END
    END
  END;
  IF sym = S.type THEN
    S.Get(sym);
    WHILE sym = S.ident DO
      TypeDecl;
      IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END
    END
  END;
  IF sym = S.var THEN
    S.Get(sym);
    WHILE sym = S.ident DO
      VarDecl(firstVar);
      IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END;
      IF S.transCount > 0 THEN
        FOR i := 0 TO S.transCount - 1 DO
          ST.AddLang(S.transLang[i]);
          p := firstVar;
          j := 0;
          WHILE (p # ST.dummy) & (S.transNames[i, j] # 0X) DO
            ReadTrans(i, j, name);
            ST.SetNameLang(p.names, S.transLang[i], name);
            INC(j);
            p := p.next
          END
        END
      END
    END
  END;
  WHILE sym = S.procedure DO
    ProcedureDecl;
    IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END
  END
END DeclSeq;

(** Selector = {"[" Expr {"," Expr} "]"}. *)
PROCEDURE Selector(VAR x: Emitter.Item);
VAR y: Emitter.Item;
BEGIN
  WHILE sym = S.lbrak DO
    S.Get(sym);
    Expr0(y);
    Emitter.Index(x, y);
    WHILE sym = S.comma DO
      S.Get(sym);
      Expr0(y);
      Emitter.Index(x, y)
    END;
    IF sym = S.rbrak THEN S.Get(sym) ELSE S.Mark(E.expRbrak) END
  END
END Selector;

(** QualIdent = [ident "."] ident. *)
PROCEDURE QualIdent(VAR obj: ST.Object);
BEGIN
  IF sym = S.ident THEN
    obj := ST.ThisObject();
    IF obj = NIL THEN S.Mark(E.undecl); obj := dummy END;
    S.Get(sym);
    IF (sym = S.period) & (obj.class = ST.Mod) THEN
      S.Get(sym);
      IF sym = S.ident THEN
        obj := ST.ThisImport(obj);
        S.Get(sym);
        IF obj = NIL THEN S.Mark(E.undecl); obj := dummy END
      ELSE S.Mark(E.expIdent); obj := dummy
      END
    END
  ELSE S.Mark(E.expIdent)
  END
END QualIdent;

PROCEDURE LenDesignator(VAR x: Emitter.Item; VAR depth: INTEGER);
VAR obj: ST.Object;
  y: Emitter.Item;
BEGIN
  depth := 0;
  QualIdent(obj);
  Emitter.MakeItem(x, obj);
  WHILE sym = S.lbrak DO
    S.Get(sym);
    Expr0(y);
    CheckInt(y);
    IF y.mode # ST.Const THEN S.Mark(E.expConst) END;
    INC(depth);
    IF x.type.form = ST.Array THEN x.type := x.type.base
    ELSE S.Mark(E.notArray)
    END;
    WHILE sym = S.comma DO
      S.Get(sym);
      Expr0(y);
      CheckInt(y);
      IF y.mode # ST.Const THEN S.Mark(E.expConst) END;
      INC(depth);
      IF x.type.form = ST.Array THEN x.type := x.type.base
      ELSE S.Mark(E.notArray)
      END
    END;
    IF sym = S.rbrak THEN S.Get(sym) ELSE S.Mark(E.expRbrak) END
  END
END LenDesignator;

(** String literal / single-char string CONST (form String): fold to CHAR for ORD, Out.Char, CASE, etc. *)
PROCEDURE FoldStringConstToChar(VAR x: Emitter.Item);
VAR pe: ST.StringEntry;
  n: INTEGER;
BEGIN
  IF (x.mode = ST.Const) & (x.type.form = ST.String) THEN
    n := x.type.len - 1; (* character count; type.len = charLen+1 from MakeStringType *)
    IF n = 1 THEN
      pe := ST.PoolEntry(M.SHORT(x.a));
      IF pe # NIL THEN Emitter.MakeConstItem(x, ST.charType, ORD(pe.bytes[0])) END
    ELSIF n = 0 THEN
      Emitter.MakeConstItem(x, ST.charType, 0)
    ELSE
      S.Mark(E.incompatible)
    END
  END
END FoldStringConstToChar;

PROCEDURE StandFunc(VAR x: Emitter.Item; func: INTEGER; resType: ST.Type);
VAR y: Emitter.Item;
  n, depth, lenAddr: INTEGER;
  is2arg: BOOLEAN;
BEGIN
  is2arg := (func >= 35) & (func <= 37);
  IF sym = S.lparen THEN
    S.Get(sym);
    IF func = 40 (*LEN*) THEN
      LenDesignator(x, depth);
      IF sym = S.comma THEN
        WHILE sym = S.comma DO
          S.Get(sym);
          Expr0(y)
        END;
        S.Mark(E.moreParams)
      END;
      IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END;
      IF x.type.form = ST.Array THEN
        IF (x.mode = ST.VarPar) & (x.type.openRank > 0) THEN
          lenAddr := M.SHORT(x.a) + (depth + 1) * 8;
          Emitter.LoadParamLen(x, lenAddr)
        ELSE
          Emitter.MakeConstItem(x, ST.intType, x.type.len)
        END
      ELSE
        S.Mark(E.notArray);
        Emitter.MakeConstItem(x, ST.intType, 0)
      END;
      x.type := ST.intType
    ELSE
      Expr0(x);
      n := 1;
      WHILE sym = S.comma DO
        S.Get(sym);
        Expr0(y);
        INC(n)
      END;
      IF is2arg THEN
        IF n # 2 THEN S.Mark(E.fewerParams) END
      ELSE
        IF n # 1 THEN S.Mark(E.moreParams) END
      END;
      IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END;
      IF func = 31 (*ORD*) THEN
        IF (x.type.form = ST.String) & (x.mode = ST.Const) THEN
          FoldStringConstToChar(x)
        END;
        IF x.type.form = ST.Char THEN Emitter.Ord(x); x.type := ST.intType
        ELSIF x.type.form = ST.Bool THEN Emitter.Ord(x); x.type := ST.intType
        ELSIF x.type.form = ST.Set THEN Emitter.Ord(x); x.type := ST.intType
        ELSIF x.type.form = ST.LongSet THEN
          Emitter.Ord(x); x.type := ST.longIntType
        END
      ELSIF func = 32 (*CHR*) THEN
        IF (x.type.form = ST.Int) OR (x.type.form = ST.Byte) OR
           (x.type.form = ST.ShortInt) OR (x.type.form = ST.LongInt) THEN Emitter.Ord(x) END
      ELSIF func = 33 (*ABS*) THEN
        IF x.type.form IN {ST.Int, ST.ShortInt, ST.LongInt} THEN Emitter.AbsVal(x) END
      ELSIF func = 34 (*ODD*) THEN
        IF x.type.form IN {ST.Int, ST.ShortInt, ST.LongInt, ST.Byte} THEN Emitter.OddVal(x) END
      ELSIF func = 35 (*ASR*) THEN
        CheckInt(x); Emitter.AsrVal(x, y)
      ELSIF func = 36 (*LSL*) THEN
        CheckInt(x); Emitter.LslVal(x, y)
      ELSIF func = 37 (*ROR*) THEN
        CheckInt(x); Emitter.RorVal(x, y)
      ELSIF func = 38 (*FLOOR*) THEN
        IF x.type.form = ST.Real THEN Emitter.Floor(x)
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 39 (*FLT*) THEN
        IF x.type.form IN {ST.Int, ST.Byte, ST.ShortInt, ST.LongInt} THEN Emitter.Flt(x)
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 45 (*SHORT*) THEN
        IF x.type.form = ST.LongInt THEN
          Emitter.Short(x); x.type := ST.intType
        ELSIF x.type.form = ST.Int THEN
          Emitter.Short(x); x.type := ST.shortIntType
        ELSIF x.type.form = ST.LongSet THEN
          Emitter.Short(x); x.type := ST.setType
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 46 (*LONG*) THEN
        IF x.type.form = ST.Int THEN
          Emitter.Long(x); x.type := ST.longIntType
        ELSIF x.type.form = ST.ShortInt THEN
          Emitter.Long(x); x.type := ST.intType
        ELSIF x.type.form = ST.Set THEN
          Emitter.Long(x); x.type := ST.longSetType
        ELSE S.Mark(E.incompatible)
        END
      ELSE ASSERT(FALSE)
      END;
      IF (func # 31) & (func # 45) & (func # 46) THEN x.type := resType END
    END
  ELSE S.Mark(E.expLparen)
  END
END StandFunc;

(** StandProc = ident "(" expr ["," expr] ")". *)
PROCEDURE StandProc(proc: INTEGER);
VAR x, n: Emitter.Item;
BEGIN
  IF sym = S.lparen THEN
    S.Get(sym);
    Expr0(x);
    IF sym = S.comma THEN
      S.Get(sym);
      Expr0(n)
    ELSE
      Emitter.MakeConstItem(n, ST.intType, 1)
    END;
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END;
    IF proc = 41 (*INC*) THEN Emitter.IncDecVar(x, n, FALSE)
    ELSIF proc = 42 (*DEC*) THEN Emitter.IncDecVar(x, n, TRUE)
    ELSIF proc = 43 (*INCL*) THEN Emitter.InclExclVar(x, n, FALSE)
    ELSIF proc = 44 (*EXCL*) THEN Emitter.InclExclVar(x, n, TRUE)
    END
  ELSE S.Mark(E.expLparen)
  END
END StandProc;

(** Emit hidden length params for an open-array actual:
    forward from caller's frame if it is itself open, else push as constants. *)
PROCEDURE EmitOpenArrayLengths(parType, actType: ST.Type; actA: INTEGER);
VAR i: INTEGER;
  n: Emitter.Item;
BEGIN
  i := 0;
  WHILE i < parType.openRank DO
    IF (actType # NIL) & (actType.form = ST.Array) & (actType.openRank > 0) THEN
      Emitter.LoadParamLen(n, actA + (i + 1) * 8);
      Emitter.ValueParam(n);
      actType := actType.base
    ELSIF (actType # NIL) & (actType.form = ST.Array) & (actType.len > 0) THEN
      Emitter.MakeConstItem(n, ST.intType, actType.len);
      Emitter.ValueParam(n);
      actType := actType.base
    ELSIF (actType # NIL) & (actType.form = ST.String) THEN
      Emitter.MakeConstItem(n, ST.intType, actType.len);
      Emitter.ValueParam(n);
      actType := ST.charType
    ELSE
      S.Mark(E.incompatible);
      Emitter.MakeConstItem(n, ST.intType, 0);
      Emitter.ValueParam(n);
      IF (actType # NIL) & (actType.form = ST.Array) THEN actType := actType.base END
    END;
    INC(i)
  END
END EmitOpenArrayLengths;

(** Param = Expr.
     par can be NIL *)
PROCEDURE Param(par: ST.Object);
VAR x: Emitter.Item;
  actA: INTEGER;
BEGIN
  Expr0(x);
  IF par # NIL THEN
    IF (par.type.form = ST.Char) & (x.type.form = ST.String) THEN
      FoldStringConstToChar(x)
    END;
    IF (par.type.openRank > 0) & ST.IsCharArrayType(par.type) & (x.type.form = ST.String) & (x.mode = ST.Const)
        OR (par.class = ST.Var) & (* value param: widening OK; constant numerics OK; VAR = strict *)
           ((x.mode = ST.Const) & ST.TypesCompatible(par.type, x.type)
            OR (x.mode # ST.Const) & ST.TypeAssignable(par.type, x.type))
        OR (par.class = ST.VarPar) & ST.TypesCompatible(par.type, x.type) THEN
      actA := M.SHORT(x.a);
      IF par.class = ST.Var THEN
        Emitter.ValueParam(x)
      ELSE
        IF ~par.readOnly & x.rdo THEN S.Mark(E.readOnly) END;
        Emitter.VarParam(x)
      END;
      IF par.type.openRank > 0 THEN
        EmitOpenArrayLengths(par.type, x.type, actA)
      END
    ELSE S.Mark(E.incompatible)
    END
  END
END Param;

(** ActualParams = "(" [Expr {"," Expr}] ")". *)
PROCEDURE ActualParams(VAR x: Emitter.Item);
VAR n: INTEGER;
  par: ST.Object;
BEGIN
  S.Get(sym);
  IF sym # S.rparen THEN
    par := x.type.dsc;
    Param(par); n := 1;
    WHILE sym = S.comma DO
      S.Get(sym);
      IF par # NIL THEN par := par.next END;
      Param(par);
      INC(n)
    END
  ELSE n := 0
  END;
  IF n < x.type.nofpars THEN S.Mark(E.fewerParams)
  ELSIF n > x.type.nofpars THEN S.Mark(E.moreParams)
  END;
  IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
END ActualParams;

(* Factor = Designator [ActualParams] | Number | String |
   FALSE | TRUE | "(" Expr ")" | "~" Factor. *)
PROCEDURE Factor(VAR x: Emitter.Item);
VAR obj: ST.Object;
  y, z: Emitter.Item;
  rx: INTEGER;
BEGIN
  IF sym = S.lparen THEN
    S.Get(sym);
    Expr0(x);
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
  ELSIF sym = S.int THEN
    Emitter.MakeConstItem(x, ST.longIntType, S.ival);
    S.Get(sym)
  ELSIF sym = S.real THEN
    Emitter.MakeConstItem(x, ST.realType, S.ival);
    S.Get(sym)
  ELSIF sym = S.char THEN
    Emitter.MakeConstItem(x, ST.charType, S.ival);
    S.Get(sym)
  ELSIF sym = S.ident THEN
    QualIdent(obj);
    IF obj.class = ST.SFunc THEN StandFunc(x, M.SHORT(obj.address), obj.type)
    ELSE
      Emitter.MakeItem(x, obj); Selector(x);
      IF (x.type.form = ST.Proc) & (x.type.base.form # ST.NoTyp)
          & (sym = S.lparen) THEN
        Emitter.PrepCall(x, rx);
        ActualParams(x);
        Emitter.Call(x, rx, obj);
        x.type := x.type.base;
        x.mode := Emitter.Reg;
        x.r := rx;
        Emitter.FixRH(rx + 1)
      END
    END
  ELSIF sym = S.string THEN
    Emitter.MakeStringConstItem(x, ST.RegisterString(S.sval, S.len), S.len);
    S.Get(sym)
  ELSIF (sym = S.false) OR (sym = S.true) THEN
    Emitter.MakeConstItem(x, ST.boolType, ORD(sym = S.true));
    S.Get(sym)
  ELSIF sym = S.not THEN
    S.Get(sym);
    Factor(x);
    IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
    Emitter.Not(x)
  ELSIF sym = S.lbrace THEN
    (* Set literal: {elem, lo..hi, ...} *)
    Emitter.MakeConstItem(x, ST.setType, 0);
    S.Get(sym);
    IF sym # S.rbrace THEN
      Expr0(y);
      IF sym = S.upto THEN
        S.Get(sym); Expr0(z); Emitter.SetRange(y, z)
      ELSE
        Emitter.Singleton(y)
      END;
      Emitter.SetUnion(x, y);
      WHILE sym = S.comma DO
        S.Get(sym);
        Expr0(y);
        IF sym = S.upto THEN
          S.Get(sym); Expr0(z); Emitter.SetRange(y, z)
        ELSE
          Emitter.Singleton(y)
        END;
        Emitter.SetUnion(x, y)
      END
    END;
    IF sym = S.rbrace THEN S.Get(sym) ELSE S.Mark(E.expRbrace) END
  ELSE S.Mark(E.notValue)
  END
END Factor;

(* Term = Factor [MulOperator Factor].
   MulOperator = "*" | "/" | DIV | MOD | "&". *)
PROCEDURE Term(VAR x: Emitter.Item);
VAR op: INTEGER;
  y: Emitter.Item;
BEGIN
  Factor(x);
  WHILE (S.times <= sym) & (sym <= S.and) DO
    op := sym;
    S.Get(sym);
    IF op = S.and THEN
      IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
      Emitter.And1(x);
      Factor(y);
      IF y.type.form # ST.Bool THEN S.Mark(E.expBool) END;
      Emitter.And2(x, y)
    ELSIF (op = S.times) & (x.type.form IN {ST.Set, ST.LongSet}) THEN
      Factor(y);
      Emitter.SetInter(x, y)
    ELSIF (op = S.rdiv) & (x.type.form IN {ST.Set, ST.LongSet}) THEN
      Factor(y);
      Emitter.SetSymDiff(x, y)
    ELSIF x.type.form = ST.Real THEN
      Factor(y);
      IF y.type.form # ST.Real THEN S.Mark(E.incompatible) END;
      IF (op = S.times) OR (op = S.rdiv) THEN
        Emitter.FMulOp(op, x, y)
      ELSE S.Mark(E.incompatible)
      END
    ELSE (* sym = one of mul, div, mod *)
      Factor(y);
      IF x.type.form IN {ST.Int, ST.Byte, ST.ShortInt, ST.LongInt} THEN
        CheckInt(y);
        Emitter.MulOp(op, x, y)
      ELSE S.Mark(E.incompatible)
      END
    END
  END
END Term;

(* SimpleExpr = ["+" | "-"] Term [AddOperator Term].
   AddOperator = "+" | "-". *)
PROCEDURE SimpleExpr(VAR x: Emitter.Item);
VAR op: INTEGER;
  y: Emitter.Item;
  minus: BOOLEAN;
BEGIN
  IF sym = S.minus THEN S.Get(sym); minus := TRUE
  ELSE minus := FALSE;
    IF sym = S.plus THEN S.Get(sym) END
  END;
  Term(x);
  IF minus THEN
    IF x.type.form IN {ST.Set, ST.LongSet} THEN Emitter.SetComplement(x)
    ELSIF x.type.form = ST.Real THEN Emitter.FNegVal(x)
    ELSE Emitter.Neg(x)
    END
  END;
  WHILE (S.plus <= sym) & (sym <= S.or) DO
    op := sym;
    S.Get(sym);
    IF op = S.or THEN
      IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
      Emitter.Or1(x);
      Term(y);
      IF y.type.form # ST.Bool THEN S.Mark(E.expBool) END;
      Emitter.Or2(x, y)
    ELSIF x.type.form IN {ST.Set, ST.LongSet} THEN
      Term(y);
      IF op = S.plus THEN Emitter.SetUnion(x, y)
      ELSE Emitter.SetDiff(x, y)
      END
    ELSIF x.type.form = ST.Real THEN
      Term(y);
      IF y.type.form # ST.Real THEN S.Mark(E.incompatible) END;
      Emitter.FAddOp(op, x, y)
    ELSE (* sym = plus or minus *)
      Term(y);
      IF x.type.form IN {ST.Int, ST.Byte, ST.ShortInt, ST.LongInt} THEN
        CheckInt(y);
        Emitter.AddOp(op, x, y)
      ELSE S.Mark(E.incompatible)
      END
    END
  END
END SimpleExpr;

PROCEDURE IsCharSeq(t: ST.Type): BOOLEAN;
RETURN (t # NIL) &
       ((t.form = ST.Char) OR (t.form = ST.String) OR ST.IsCharArrayType(t))
END IsCharSeq;

PROCEDURE IllegalArrayRelation(t1, t2: ST.Type): BOOLEAN;
RETURN (t1 # NIL) & (t2 # NIL) & (t1.form = ST.Array) &
       (t2.form = ST.Array) & ~ST.IsCharArrayType(t1)
END IllegalArrayRelation;

(* Expr = SimpleExpr [relation SimpleExpr]. *)
PROCEDURE Expr(VAR x: Emitter.Item);
VAR op: INTEGER;
  y: Emitter.Item;
BEGIN
  SimpleExpr(x);
  IF sym = S.in THEN
    op := sym;
    S.Get(sym);
    SimpleExpr(y);
    Emitter.InSet(x, y);
    x.type := ST.boolType
  ELSIF (S.eql <= sym) & (sym <= S.geq) THEN
    op := sym;
    S.Get(sym);
    SimpleExpr(y);
    IF (x.type.form = ST.Char) & (y.type.form = ST.String) & (y.mode = ST.Const) THEN
      FoldStringConstToChar(y)
    END;
    IF (y.type.form = ST.Char) & (x.type.form = ST.String) & (x.mode = ST.Const) THEN
      FoldStringConstToChar(x)
    END;
    IF IllegalArrayRelation(x.type, y.type) OR IllegalArrayRelation(y.type, x.type) THEN
      S.Mark(E.illegalRelation)
    ELSIF (x.type.form = ST.Char) & (y.type.form = ST.Char) THEN
      Emitter.IntRel(op, x, y);
      x.type := ST.boolType
    ELSIF IsCharSeq(x.type) & IsCharSeq(y.type) THEN
      Emitter.CmpStrings(op, x, y)
    ELSIF (x.type.form IN {ST.Char, ST.Int, ST.Set, ST.Byte, ST.ShortInt, ST.LongInt, ST.LongSet}) & ST.TypesCompatible(x.type, y.type) THEN
      Emitter.IntRel(op, x, y);
      x.type := ST.boolType
    ELSIF (x.type.form = ST.Real) & (y.type.form = ST.Real) THEN
      Emitter.FRel(op, x, y);
      x.type := ST.boolType
    ELSIF x.type.form = ST.Bool THEN
      IF op <= S.neq THEN Emitter.IntRel(op, x, y)
      ELSE S.Mark(E.onlyEqlNeq)
      END
    ELSE S.Mark(E.incompatible)
    END
  END
END Expr;

(** Assign = Designator ":=" Expr. *)
PROCEDURE Assign(obj: ST.Object);
VAR x, y: Emitter.Item;
BEGIN
  Emitter.MakeItem(x, obj); 
  Expr(y);
  Emitter.Assign(x, y)
END Assign;

(** AssignItem: assignment where left side is already an Item. *)
PROCEDURE AssignItem(VAR x: Emitter.Item);
VAR y: Emitter.Item;
BEGIN
  Expr(y);
  Emitter.Assign(x, y)
END AssignItem;

(** ProcedureCall = Designator [ActualParams]. *)
PROCEDURE ProcedureCall(obj: ST.Object);
VAR x: Emitter.Item;
  rx: INTEGER;
BEGIN
  Emitter.MakeItem(x, obj);
  IF sym = S.lparen THEN (* With parameters *)
    IF x.type.form # ST.Proc THEN S.Mark(E.notProcedure)
    ELSE
      IF x.type.base.form # ST.NoTyp THEN S.Mark(E.notUsed) END;
      Emitter.PrepCall(x, rx); ActualParams(x); Emitter.Call(x, rx, obj)
    END
  ELSIF x.type.form = ST.Proc THEN (* Procedure with no parameters *)
    IF x.type.nofpars > 0 THEN S.Mark(E.noParams) END;
    IF x.type.base.form # ST.NoTyp THEN S.Mark(E.notUsed)
    ELSE Emitter.PrepCall(x, rx); Emitter.Call(x, rx, obj)
    END
  ELSE S.Mark(E.expStatement)
  END
END ProcedureCall;

(** IfStatement = IF expression THEN StatementSequence
    {ELSIF expression THEN StatementSequence}
    [ELSE StatementSequence] END. *)
PROCEDURE IfStatement;
VAR x: Emitter.Item;
  L: INTEGER;
BEGIN
  S.Get(sym);
  Expr(x);
  IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
  Emitter.CFJump(x);

  IF sym = S.then THEN S.Get(sym) ELSE S.Mark(E.expThen) END;

  StatSeq0;
  L := 0;
  WHILE sym = S.elsif DO
    S.Get(sym);
    Emitter.FJump(L);
    Emitter.Fixup(x);

    Expr(x);
    IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
    Emitter.CFJump(x);
  
    IF sym = S.then THEN S.Get(sym) ELSE S.Mark(E.expThen) END;

    StatSeq0
  END;

  IF sym = S.else THEN
    S.Get(sym);
    Emitter.FJump(L);
    Emitter.Fixup(x);
    StatSeq0
  ELSE
    Emitter.Fixup(x)
  END;

  IF sym = S.end THEN S.Get(sym) ELSE S.Mark(E.expEnd) END;
  Emitter.FixLink(L)
END IfStatement;

(** WhileStatement = WHILE expression DO StatementSequence
    {ELSIF expression DO StatementSequence} END. *)
PROCEDURE WhileStatement;
VAR x: Emitter.Item;
  L: INTEGER;
BEGIN
  L := Generator.Here();
  S.Get(sym);
  Expr(x);
  IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;

  (* CONDITIONAL JUMP *)
  Emitter.CFJump(x);

  IF sym = S.do THEN S.Get(sym) ELSE S.Mark(E.expDo) END;

  StatSeq0;

  (* UNCONDITIONAL BACK JUMP TO START OF LOOP *)
  Emitter.BJump(L);

  WHILE sym = S.elsif DO
    S.Get(sym);

    (* FIXUP CONDITIONAL JUMP *)
    Emitter.Fixup(x);

    Expr(x);
    IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
    IF sym = S.do THEN S.Get(sym) ELSE S.Mark(E.expDo) END;

    (* CONDITIONAL JUMP *)
    Emitter.CFJump(x);

    StatSeq0;

    (* UNCONDITIONAL BACK JUMP TO START OF LOOP *)
    Emitter.BJump(L)
  END;

  (* FIXUP CONDITIONAL JUMP *)
  Emitter.Fixup(x);

  IF sym = S.end THEN S.Get(sym) ELSE S.Mark(E.expEnd) END
END WhileStatement;

PROCEDURE RepeatStatement;
VAR x: Emitter.Item;
  L: INTEGER;
BEGIN
  L := Generator.Here();
  S.Get(sym);

  StatSeq0;

  IF sym # S.until THEN S.Mark(E.expUntil)
  ELSE
    S.Get(sym);
    Expr(x);
    IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
    Emitter.CBJump(x, L)
  END
END RepeatStatement;

(** ForStatement = FOR ident ":=" expression TO expression [BY constExpr]
    DO StatementSequence END. *)
PROCEDURE ForStatement;
VAR obj: ST.Object;
  x, y, endVal, inc: Emitter.Item;
  step, L, savedReg: INTEGER;
  savedConst: M.LONGINT;
BEGIN
  S.Get(sym);
  IF sym = S.ident THEN
    obj := ST.ThisObject();
    IF obj = NIL THEN S.Mark(E.undecl); obj := dummy END;
    S.Get(sym);
    IF sym = S.becomes THEN S.Get(sym)
    ELSIF sym = S.eql THEN S.Mark(E.expBecomes); S.Get(sym)
    ELSE S.Mark(E.expBecomes)
    END;
    Assign(obj)
  ELSE S.Mark(E.expIdent)
  END;
  IF sym = S.to THEN S.Get(sym) ELSE S.Mark(E.expTo) END;
  Expr0(endVal);
  Emitter.ForSave(endVal, savedConst, savedReg);
  step := 1;
  IF sym = S.by THEN
    S.Get(sym);
    Expr0(y);
    IF y.mode = ST.Const THEN
      IF y.a # 0 THEN step := M.SHORT(y.a)
      ELSE S.Mark(E.badDiv)
      END
    ELSE S.Mark(E.notValue)
    END
  END;
  IF sym = S.do THEN S.Get(sym) ELSE S.Mark(E.expDo) END;
  L := Generator.Here();
  Emitter.ForCond(obj, savedReg, savedConst, step, x);
  Emitter.CFJump(x);
  StatSeq0;
  Emitter.MakeItem(inc, obj);
  IF step > 0 THEN
    Emitter.MakeConstItem(y, obj.type, step);
    Emitter.IncDecVar(inc, y, FALSE)
  ELSE
    Emitter.MakeConstItem(y, obj.type, -step);
    Emitter.IncDecVar(inc, y, TRUE)
  END;
  Emitter.BJump(L);
  Emitter.Fixup(x);
  Emitter.ForClean(savedReg);
  IF sym = S.end THEN S.Get(sym) ELSE S.Mark(E.expEnd) END
END ForStatement;

(** CaseStatement = CASE expression OF case {"|" case} END.
    case = [caseLabelList ":" StatementSequence]. *)
PROCEDURE CaseStatement;
VAR expr: Emitter.Item;
  exitL: INTEGER;

  (** caseLabelList = caseLabels {"," caseLabels}.
      caseLabels = constExpr [".." constExpr]. *)
  PROCEDURE CaseLabelList(VAR expr: Emitter.Item; VAR matchL: INTEGER);
  VAR x, y: Emitter.Item;
  BEGIN
    Expr0(x);
    FoldStringConstToChar(x);
    IF x.mode # ST.Const THEN S.Mark(E.notValue); x.mode := ST.Const; x.a := 0 END;
    IF sym = S.upto THEN
      S.Get(sym); Expr0(y);
      FoldStringConstToChar(y);
      IF y.mode # ST.Const THEN S.Mark(E.notValue); y.mode := ST.Const; y.a := 0 END;
      Emitter.CaseRangeLabel(expr, M.SHORT(x.a), M.SHORT(y.a), matchL)
    ELSE
      Emitter.CaseLabel(expr, M.SHORT(x.a), matchL)
    END;
    WHILE sym = S.comma DO
      S.Get(sym);
      Expr0(x);
      FoldStringConstToChar(x);
      IF x.mode # ST.Const THEN S.Mark(E.notValue); x.mode := ST.Const; x.a := 0 END;
      IF sym = S.upto THEN
        S.Get(sym); Expr0(y);
        FoldStringConstToChar(y);
        IF y.mode # ST.Const THEN S.Mark(E.notValue); y.mode := ST.Const; y.a := 0 END;
        Emitter.CaseRangeLabel(expr, M.SHORT(x.a), M.SHORT(y.a), matchL)
      ELSE
        Emitter.CaseLabel(expr, M.SHORT(x.a), matchL)
      END
    END
  END CaseLabelList;

  PROCEDURE Case(VAR expr: Emitter.Item; VAR exitL: INTEGER);
  VAR matchL, nextL: INTEGER;
  BEGIN
    matchL := 0;
    CaseLabelList(expr, matchL);
    IF sym = S.colon THEN S.Get(sym) ELSE S.Mark(E.expColon) END;
    nextL := 0;
    Emitter.FJump(nextL);
    Emitter.FixLink(matchL);
    Emitter.CaseBodyBegin;
    StatSeq0;
    Emitter.FJump(exitL);
    Emitter.CaseBodyEnd;
    Emitter.FixLink(nextL)
  END Case;

BEGIN
  S.Get(sym);
  Expr0(expr);
  Emitter.CaseSave(expr);
  IF sym = S.of THEN S.Get(sym) ELSE S.Mark(E.expOf) END;
  exitL := 0;
  WHILE sym = S.bar DO S.Get(sym) END;
  IF (sym # S.end) & (sym # S.bar) THEN Case(expr, exitL) END;
  WHILE sym = S.bar DO
    S.Get(sym);
    IF (sym # S.end) & (sym # S.bar) THEN Case(expr, exitL) END
  END;
  Emitter.Trap;
  Emitter.FixLink(exitL);
  Emitter.CaseClean;
  IF sym = S.end THEN S.Get(sym) ELSE S.Mark(E.expEnd) END
END CaseStatement;

(** Statement = [Assign | ProcedureCall | IfStatement |
    WhileStatement | RepeatStatement ]. *)
PROCEDURE Statement;
VAR obj: ST.Object;
  x: Emitter.Item;
BEGIN
  IF sym = S.ident THEN
    QualIdent(obj);
    IF obj.class = ST.SProc THEN
      StandProc(M.SHORT(obj.address))
    ELSE
      Emitter.MakeItem(x, obj);
      Selector(x);
      IF sym = S.eql THEN S.Mark(E.expBecomes); sym := S.becomes END;
      IF sym = S.becomes THEN
        S.Get(sym);
        AssignItem(x)
      ELSE
        ProcedureCall(obj)
      END
    END
  ELSIF sym = S.if THEN
    IfStatement
  ELSIF sym = S.while THEN
    WhileStatement
  ELSIF sym = S.repeat THEN
    RepeatStatement
  ELSIF sym = S.for THEN
    ForStatement
  ELSIF sym = S.case THEN
    CaseStatement
  END
END Statement;

PROCEDURE StatSeq;
BEGIN
  Statement;
  WHILE sym = S.semicol DO
    S.Get(sym);
    Statement
  END
END StatSeq;

(** Module = MODULE ident ";" [IMPORT ImportList] DeclSeq
             [BEGIN StatSeq] END ident ".". *)
PROCEDURE Module;
VAR nameStr: ARRAY 64 OF CHAR;
  i: INTEGER;
BEGIN
  varsize := 0;
  IF sym = S.module THEN
    S.Get(sym);
    IF sym = S.ident THEN
      modName := NIL;
      ST.SetName(modName, S.id);
      GetModName(nameStr);
      Generator.Open(nameStr);
      S.Get(sym);
      IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END;

      (* Apply translation names for module *)
      FOR i := 0 TO S.transCount - 1 DO
        ST.AddLang(S.transLang[i]);
        ST.SetNameLang(modName, S.transLang[i], S.transNames[i])
      END;

      IF sym = S.import THEN S.Get(sym); ImportList END;
      DeclSeq;
      Generator.SetEntry(Generator.Here() * 4);
      IF sym = S.begin THEN S.Get(sym); StatSeq END;

      IF sym = S.end THEN
        S.Get(sym);
        IF sym = S.ident THEN
          GetModName(nameStr);
          IF nameStr # S.id THEN S.Mark(E.modNameMismatch) END;
          S.Get(sym);
          IF sym = S.period THEN S.Get(sym) ELSE S.Mark(E.expPeriod) END;
          Emitter.Exit
        ELSE S.Mark(E.expIdent)
        END
      ELSE S.Mark(E.expEnd)
      END
    ELSE S.Mark(E.expIdent)
    END
  ELSE S.Mark(E.expModule)
  END;
  IF ~S.error THEN 
    Emitter.Close;
    ST.ExportModule(modName)
  END
END Module;

PROCEDURE Compile*(): BOOLEAN;
BEGIN
  S.Get(sym);
  ST.Init(Lang.curLang);
  Emitter.Init;
  Module
RETURN ~S.error END Compile;

BEGIN
  Expr0 := Expr;
  StatSeq0 := StatSeq;
  Type0 := Type;
  FormalType0 := FormalType;
  allowOpenArrayParams := FALSE;
  NEW(dummy); dummy.class := ST.Var; dummy.type := ST.intType
END Parser.
