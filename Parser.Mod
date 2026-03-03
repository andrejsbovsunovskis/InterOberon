MODULE Parser;
IMPORT S := Scanner, ST := SymTable, E := ErrorMsg, Strings,
  Generator, Emitter, Out, Lang;

VAR
  sym: INTEGER;
  dummy: ST.Object; (** In case of error in QualIdent *)
  varsize: INTEGER; (** How many bytes variables occupy *)

  Expr0: PROCEDURE(VAR x: Emitter.Item);
  StatSeq0: PROCEDURE;

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
  IF x.type.form # ST.Int THEN
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

(** Type = ident. *)
PROCEDURE Type(VAR T: ST.Type);
VAR p: ST.Object;
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

(** VarDecl = IdentList ":" Type. *)
PROCEDURE VarDecl(VAR firstObj: ST.Object);
VAR p, q: ST.Object;
  T: ST.Type;
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
  REPEAT
    p.type := T;
    IF T.size > 1 THEN
      varsize := (varsize + T.size - 1) DIV T.size * T.size
    END;
    p.val := varsize;
    varsize := varsize + T.size;
    p := p.next
  UNTIL p = ST.dummy
END VarDecl;

(** DeclSeq = [VAR {VarDecl ";"}]. *)
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

BEGIN
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
  END
END DeclSeq;

(** Selector = . *)
PROCEDURE Selector;
BEGIN
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

PROCEDURE StandFunc(VAR x: Emitter.Item; func: INTEGER; resType: ST.Type);
VAR y: Emitter.Item;
  n: INTEGER;
BEGIN
  IF sym = S.lparen THEN
    S.Get(sym);
    Expr0(x);
    n := 1;
    WHILE sym = S.comma DO (* Max 2 params, but skip all *)
      S.Get(sym);
      Expr0(y);
      INC(n)
    END;
    IF n # 1 THEN S.Mark(E.moreParams) END;
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END;
    IF func = 31 (*ORD*) THEN
      IF x.type.form = ST.Char THEN Emitter.Ord(x) END
    ELSIF func = 32 (*CHR*) THEN
      IF x.type.form = ST.Int THEN Emitter.Ord(x) END
    ELSE ASSERT(FALSE)
    END;
    x.type := resType
  ELSE S.Mark(E.expLparen)
  END
END StandFunc;

(** Param = Expr.
     par can be NIL *)
PROCEDURE Param(par: ST.Object);
VAR x: Emitter.Item;
BEGIN
  Expr0(x);
  IF par # NIL THEN
    IF ST.TypesCompatible(par.type, x.type) THEN
      IF par.class = ST.Var THEN
        Emitter.ValueParam(x)
      ELSE (* par.class = ST.Par *)
        Emitter.VarParam(x)
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
BEGIN
  IF sym = S.lparen THEN
    S.Get(sym);
    Expr0(x);
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
  ELSIF sym = S.int THEN
    Emitter.MakeConstItem(x, ST.intType, S.ival);
    S.Get(sym)
  ELSIF sym = S.ident THEN
    QualIdent(obj);
    IF obj.class = ST.SFunc THEN StandFunc(x, obj.val, obj.type)
    ELSE Emitter.MakeItem(x, obj)
    END
  ELSIF sym = S.string THEN
    Emitter.MakeConstItem(x, ST.charType, ORD(S.sval[0]));
    IF S.len # 1 THEN S.Mark(E.stringTodo) END;
    S.Get(sym)
  ELSIF (sym = S.false) OR (sym = S.true) THEN
    Emitter.MakeConstItem(x, ST.boolType, ORD(sym = S.true));
    S.Get(sym)
  ELSIF sym = S.not THEN
    S.Get(sym);
    Factor(x);
    IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
    Emitter.Not(x)
  ELSIF sym = S.false THEN Emitter.MakeConstItem(x, ST.boolType, 0)
  ELSIF sym = S.true THEN Emitter.MakeConstItem(x, ST.boolType, 1)
  ELSE S.Mark(E.notValue)
  END
END Factor;

(* Term = Factor [MulOperator Factor].
   MulOperator = "*" | DIV | MOD | "&". *)
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
    ELSE (* sym = one of mul, div, mod *)
      Factor(y);
      IF x.type.form = ST.Int THEN
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
  IF minus THEN Emitter.Neg(x) END;
  WHILE (S.plus <= sym) & (sym <= S.or) DO
    op := sym;
    S.Get(sym);
    IF op = S.or THEN
      IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
      Emitter.Or1(x);
      Term(y);
      IF y.type.form # ST.Bool THEN S.Mark(E.expBool) END;
      Emitter.Or2(x, y)
    ELSE (* sym = plus or minus *)
      Term(y);
      IF x.type.form = ST.Int THEN
        CheckInt(y);
        Emitter.AddOp(op, x, y)
      ELSE S.Mark(E.incompatible)
      END
    END
  END
END SimpleExpr;

(* Expr = SimpleExpr [relation SimpleExpr]. *)
PROCEDURE Expr(VAR x: Emitter.Item);
VAR op: INTEGER;
  y: Emitter.Item;
BEGIN
  SimpleExpr(x);
  IF (S.eql <= sym) & (sym <= S.geq) THEN
    op := sym;
    S.Get(sym);
    SimpleExpr(y);
    IF (x.type.form IN {ST.Char, ST.Int}) & (x.type = y.type) THEN
      Emitter.IntRel(op, x, y);
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
      Emitter.PrepCall(x, rx); ActualParams(x); Emitter.Call(x, rx)
    END
  ELSIF x.type.form = ST.Proc THEN (* Procedure with no parameters *)
    IF x.type.nofpars > 0 THEN S.Mark(E.noParams) END;
    IF x.type.base.form # ST.NoTyp THEN S.Mark(E.notUsed)
    ELSE Emitter.PrepCall(x, rx); Emitter.Call(x, rx)
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

  (* CONDITIONAL JUMP *)
  Emitter.CFJump(x);

  IF sym = S.then THEN S.Get(sym) ELSE S.Mark(E.expThen) END;

  StatSeq0;
  L := 0;
  WHILE sym = S.elsif DO
    S.Get(sym);

    (* UNCONDITIONAL JUMP *)
    Emitter.FJump(L);

    (* FIXUP CONDITIONAL JUMP *)
    Emitter.Fixup(x);

    Expr(x);
    IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
    IF sym = S.then THEN S.Get(sym) ELSE S.Mark(E.expThen) END;

    (* CONDITIONAL JUMP *)
    Emitter.CFJump(x);

    StatSeq0
  END;

  IF sym = S.else THEN
    S.Get(sym);

    (* UNCONDITIONAL JUMP *)
    Emitter.FJump(L);

    (* FIXUP CONDITIONAL JUMP *)
    Emitter.Fixup(x);

    StatSeq0
  ELSE
    (* FIXUP CONDITIONAL JUMP *)
    Emitter.Fixup(x)
  END;

  IF sym = S.end THEN S.Get(sym) ELSE S.Mark(E.expEnd) END;

  (* FIXUP UNCONDITIONAL JUMP *)
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
  ELSE S.Get(sym);
    Expr(x);
    IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;

    (* CONDITIONAL BACK JUMP TO START OF LOOP *)
    Emitter.CBJump(x, L)
  END
END RepeatStatement;

(** Statement = [Assign | ProcedureCall | IfStatement |
    WhileStatement | RepeatStatement ]. *)
PROCEDURE Statement;
VAR obj: ST.Object;
BEGIN
  IF sym = S.ident THEN
    QualIdent(obj);
    Selector;
    IF sym = S.eql THEN S.Mark(E.expBecomes); sym := S.becomes END;
    IF sym = S.becomes THEN
      S.Get(sym);
      Assign(obj)
    ELSE
      ProcedureCall(obj)
    END
  ELSIF sym = S.if THEN
    IfStatement
  ELSIF sym = S.while THEN
    WhileStatement
  ELSIF sym = S.repeat THEN
    RepeatStatement
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
      IF sym = S.begin THEN S.Get(sym); StatSeq END;

      IF sym = S.end THEN
        S.Get(sym);
        IF sym = S.ident THEN
          GetModName(nameStr);
          IF nameStr # S.id THEN S.Mark(E.modNameMismatch) END;
          S.Get(sym);
          IF sym = S.period THEN S.Get(sym) ELSE S.Mark(E.expPeriod) END
        ELSE S.Mark(E.expIdent)
        END
      ELSE S.Mark(E.expEnd)
      END
    ELSE S.Mark(E.expIdent)
    END
  ELSE S.Mark(E.expModule)
  END;
  IF ~S.error THEN 
    Generator.Close;
    ST.ExportModule(modName)
  END
END Module;

PROCEDURE Compile*(): BOOLEAN;
BEGIN
  S.Get(sym);
  ST.Init(Lang.curLang);
  Generator.Init;
  Module
RETURN ~S.error END Compile;

BEGIN
  Expr0 := Expr;
  StatSeq0 := StatSeq;
  NEW(dummy); dummy.class := ST.Var; dummy.type := ST.intType
END Parser.
