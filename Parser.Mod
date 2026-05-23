MODULE Parser;
IMPORT S := Scanner, ST := SymTable, E := ErrorMsg, Strings,
  Generator, Emitter, Out, Lang, M := Machine, SYSTEM;

TYPE
  LONGINT = M.LONGINT;
  LONGREAL = M.LONGREAL;

  PendingPtr = POINTER TO PendingPtrDesc;
  PendingPtrDesc = RECORD
    typ: ST.Type;
    name: ARRAY 64 OF CHAR;
    next: PendingPtr
  END;

VAR
  sym: INTEGER;
  dummy: ST.Object; (** In case of error in QualIdent *)
  varsize: INTEGER; (** How many bytes variables occupy *)
  exprExpect: ST.Type; (** Target type for set literals in assignment RHS *)

  Expr0: PROCEDURE(VAR x: Emitter.Item);
  SimpleExpr0: PROCEDURE(VAR x: Emitter.Item);
  StatSeq0: PROCEDURE;
  Type0: PROCEDURE(VAR T: ST.Type);
  FormalType0: PROCEDURE(VAR T: ST.Type);

  allowOpenArrayParams: BOOLEAN;

  modName: ST.Name; (** Names of last compiled module *)

  (** Pending POINTER TO X fixups inside the current TYPE section.
      ParsePointer adds an entry whenever the base ident is not yet
      declared; ResolvePendingPointers walks the list at section end
      and either binds the base or marks the unresolved fixup. *)
  pendingPtrs: PendingPtr;
  inTypeSection: BOOLEAN;

  (** Module-local record types that need a runtime TypeDesc.
      Populated by ParseRecord, drained at the start of the module init
      proc by EmitRecordTypeDescInits. *)
  recordTypes: ARRAY 256 OF ST.Type;
  recordTypesN: INTEGER;

  (** Circular queue of declarable objects waiting for a translation comment.
      ringHead — oldest; ringTail — next write. When full, RingPut drops oldest. *)
  pendingRing: ARRAY 64 OF ST.Object;
  ringHead, ringTail, ringCount: INTEGER;
  hadSticky: BOOLEAN;
  inTypeDecl: BOOLEAN;
  inConstVarSection: BOOLEAN; (** CONST/VAR: RTL attach, full clear per comment *)

  insideLen: INTEGER; (** Nesting depth while parsing LEN(...) designator *)
  lenDepth: INTEGER; (** Trailing index count for LEN dimension selection *)

  LenIndexFactor0: PROCEDURE(VAR x: Emitter.Item);
  LenIndexTerm0: PROCEDURE(VAR x: Emitter.Item);
  LenIndexExpr0: PROCEDURE(VAR x: Emitter.Item);

(** Returns name of the last compiled module in current language. *)
PROCEDURE GetModName*(VAR name: ARRAY OF CHAR);
BEGIN
  ST.GetName(modName, name)
END GetModName;

PROCEDURE SetNoAssert*(on: BOOLEAN);
BEGIN Emitter.SetNoAssert(on) END SetNoAssert;

PROCEDURE Load*(fname: ARRAY OF CHAR): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  ok := FALSE;
  IF S.Load(fname) THEN
    S.Get(sym);
    IF sym = S.module THEN
      ok := TRUE (** Language already loaded for this header keyword. *)
    ELSIF (sym = S.ident) & Lang.Identify(S.id) THEN
      ok := TRUE
    END;
    S.Rewind
  END;
  IF ~ok THEN S.Mark(E.unknownLang) END
RETURN ok END Load;

PROCEDURE CheckInt(VAR x: Emitter.Item);
BEGIN
  IF ~ST.IsIntegerForm(x.type.form) THEN
    S.Mark(E.notInt);
    x.type := ST.intType
  END
END CheckInt;

(** Import = [ident ":="] ident. *)
PROCEDURE Import;
VAR alias, name, canonical: ARRAY 64 OF CHAR;
  M: ST.Object;
  idx: INTEGER;
BEGIN
  IF sym = S.ident THEN
    Strings.Copy(S.id, alias);
    Strings.Copy(S.id, name);
    M := ST.NewObject(ST.Mod, alias);
    S.Get(sym);
    IF sym = S.becomes THEN
      S.Get(sym);
      IF sym = S.ident THEN Strings.Copy(S.id, name); S.Get(sym)
      ELSE S.Mark(E.expIdent)
      END
    END;
    (* `name` is the literal as written in source -- may be a translated
       form (e.g. 'Ввод' for the 'In' module).  ResolveCanonical maps it
       to the file-system / linker name actually used for .sym/.obj. *)
    ST.ResolveCanonical(name, canonical);
    (* Built-in modules (SYSTEM) are resolved entirely inside the
       compiler, do not have a .obj/.sym companion, and must not appear
       in the import list of the produced object file. *)
    IF (canonical = 'SYSTEM') OR (alias = 'SYSTEM') THEN
      idx := -1
    ELSE
      idx := Generator.AddImport(canonical)
    END;
    ST.Import(M, canonical, idx)
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

PROCEDURE RingClear;
BEGIN ringHead := 0; ringTail := 0; ringCount := 0; hadSticky := FALSE END RingClear;

PROCEDURE RingPut(obj: ST.Object);
VAR cap: INTEGER;
BEGIN
  cap := LEN(pendingRing);
  IF ringCount = cap THEN ringHead := (ringHead + 1) MOD cap ELSE INC(ringCount) END;
  pendingRing[ringTail] := obj;
  ringTail := (ringTail + 1) MOD cap
END RingPut;

PROCEDURE RingCount(): INTEGER;
BEGIN RETURN ringCount END RingCount;

PROCEDURE RingAt(logical: INTEGER): ST.Object;
BEGIN RETURN pendingRing[(ringHead + logical) MOD LEN(pendingRing)] END RingAt;

(** Keep oldest `keep` entries; drop the rest from the logical tail. *)
PROCEDURE RingKeepFirst(keep: INTEGER);
VAR cap: INTEGER;
BEGIN
  IF keep < ringCount THEN
    cap := LEN(pendingRing);
    ringCount := keep;
    IF keep = 0 THEN ringHead := 0; ringTail := 0
    ELSE ringTail := (ringHead + keep) MOD cap
    END
  END
END RingKeepFirst;

(** Remove the most recently queued entry (sticky attach). *)
PROCEDURE RingDropLast;
VAR cap: INTEGER;
BEGIN
  IF ringCount > 0 THEN
    cap := LEN(pendingRing);
    ringTail := (ringTail - 1 + cap) MOD cap;
    DEC(ringCount)
  END
END RingDropLast;

(** Read one translated identifier from S.transNames[i] starting at j. *)
PROCEDURE ReadTransName(i: INTEGER; VAR j: INTEGER; VAR name: ARRAY OF CHAR);
VAR k: INTEGER;
BEGIN
  WHILE (S.transNames[i, j] # 0X) & (S.transNames[i, j] <= ' ') DO INC(j) END;
  k := 0;
  WHILE (S.transNames[i, j] # 0X) & (S.transNames[i, j] # ',') DO
    IF k # LEN(name) - 1 THEN
      name[k] := S.transNames[i, j]; INC(k)
    ELSE
      S.Mark(E.longTransName)
    END;
    INC(j)
  END;
  name[k] := 0X;
  WHILE (S.transNames[i, j] # 0X) & (S.transNames[i, j] <= ' ') DO INC(j) END;
  IF S.transNames[i, j] = ',' THEN INC(j) END
END ReadTransName;

PROCEDURE CountTransNames(i: INTEGER): INTEGER;
VAR j, n: INTEGER;
BEGIN
  n := 0;
  j := 0;
  WHILE S.transNames[i, j] # 0X DO
    WHILE (S.transNames[i, j] # 0X) & (S.transNames[i, j] <= ' ') DO INC(j) END;
    IF S.transNames[i, j] # 0X THEN
      INC(n);
      WHILE (S.transNames[i, j] # 0X) & (S.transNames[i, j] # ',') DO INC(j) END;
      IF S.transNames[i, j] = ',' THEN INC(j) END
    END
  END
RETURN n END CountTransNames;

PROCEDURE MaxTransNames(): INTEGER;
VAR i, n, maxN: INTEGER;
BEGIN
  maxN := 0;
  i := 0;
  WHILE i < S.transCount DO
    n := CountTransNames(i);
    IF n > maxN THEN maxN := n END;
    INC(i)
  END
RETURN maxN END MaxTransNames;

(** CONST/VAR: first name -> last queued object, then left along the queue. *)
PROCEDURE ApplyTranslationsFromRTL;
VAR i, j, n, k, maxN, cnt: INTEGER;
  name: ARRAY 64 OF CHAR;
  obj: ST.Object;
BEGIN
  IF S.transCount > 0 THEN
    cnt := RingCount();
    maxN := MaxTransNames();
    IF maxN > cnt THEN S.Mark(E.tooManyTransIds); maxN := cnt END;
    i := 0;
    WHILE i < S.transCount DO
      ST.AddLang(S.transLang[i]);
      n := CountTransNames(i);
      IF n > maxN THEN n := maxN END;
      j := 0;
      k := 0;
      WHILE k # n DO
        ReadTransName(i, j, name);
        obj := RingAt(cnt - 1 - k);
        IF name # '' THEN ST.SetNameLang(obj.names, S.transLang[i], name) END;
        INC(k)
      END;
      INC(i)
    END
  END
END ApplyTranslationsFromRTL;

(** limitN < 0: use full name count per language; else cap slots per language. *)
PROCEDURE ApplyTranslationsFrom(pos, limitN: INTEGER);
VAR i, j, n, k, maxN, cnt, avail: INTEGER;
  name: ARRAY 64 OF CHAR;
  obj: ST.Object;
BEGIN
  IF S.transCount > 0 THEN
    cnt := RingCount();
    IF pos > cnt THEN pos := cnt END;
    avail := cnt - pos;
    maxN := MaxTransNames();
    IF limitN >= 0 THEN
      IF limitN < maxN THEN maxN := limitN END
    END;
    IF maxN > avail THEN S.Mark(E.tooManyTransIds); maxN := avail END;
    i := 0;
    WHILE i < S.transCount DO
      ST.AddLang(S.transLang[i]);
      n := CountTransNames(i);
      IF (limitN >= 0) & (n > limitN) THEN n := limitN END;
      IF n > avail THEN n := avail END;
      j := 0;
      k := 0;
      WHILE k # n DO
        ReadTransName(i, j, name);
        obj := RingAt(pos + k);
        IF name # '' THEN ST.SetNameLang(obj.names, S.transLang[i], name) END;
        INC(k)
      END;
      INC(i)
    END
  END
END ApplyTranslationsFrom;

PROCEDURE ApplyModuleTranslations;
VAR i, j, n: INTEGER;
  name: ARRAY 64 OF CHAR;
BEGIN
  IF S.transCount > 0 THEN
    i := 0;
    WHILE i < S.transCount DO
      ST.AddLang(S.transLang[i]);
      n := CountTransNames(i);
      IF n # 1 THEN S.Mark(E.transModuleOne)
      ELSE
        j := 0;
        ReadTransName(i, j, name);
        IF name # '' THEN ST.SetNameLang(modName, S.transLang[i], name) END
      END;
      INC(i)
    END
  END
END ApplyModuleTranslations;

(** sticky=TRUE: comment immediately after ident; else fromPos left-to-right. *)
PROCEDURE DeclApply(sticky: BOOLEAN; fromPos: INTEGER);
VAR maxN, pos, nBefore: INTEGER;
BEGIN
  IF S.transCount > 0 THEN
    IF inConstVarSection THEN
      ApplyTranslationsFromRTL;
      RingClear
    ELSIF hadSticky & (S.transSeqInGap > 1) THEN S.Mark(E.transExtraComment)
    ELSE
    nBefore := RingCount();
    maxN := MaxTransNames();
    IF sticky THEN
      IF maxN > 1 THEN S.Mark(E.transStickyMulti)
      ELSIF RingCount() > 0 THEN
        pos := RingCount() - 1;
        ApplyTranslationsFrom(pos, 1);
        RingDropLast;
        IF nBefore > 1 THEN hadSticky := TRUE END
      END
    ELSIF hadSticky THEN
      IF maxN > 1 THEN S.Mark(E.transAfterStickyMulti)
      ELSE
        ApplyTranslationsFrom(fromPos, 1);
        hadSticky := FALSE;
        RingKeepFirst(fromPos)
      END
    ELSE
      ApplyTranslationsFrom(fromPos, -1);
      RingKeepFirst(fromPos);
      IF RingCount() = 0 THEN hadSticky := FALSE END
    END
    END
  END
END DeclApply;

PROCEDURE DeclGet(VAR sym: INTEGER; sticky: BOOLEAN; fromPos: INTEGER);
BEGIN
  S.Get(sym);
  DeclApply(sticky, fromPos)
END DeclGet;

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
      T.openRank := elemType.openRank + 1;
      T.descOffset := -1
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
        T.descOffset := -1;
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
    RingPut(first);
    first.address := 16 + nofPars * 8; INC(nofPars);
    DeclGet(sym, TRUE, 0);
    WHILE sym = S.comma DO
      DeclGet(sym, FALSE, 0);
      IF sym = S.ident THEN
        IF nofPars >= 8 THEN S.Mark(E.tooManyParams) END;
        p := ST.NewObject(class, S.id);
        RingPut(p);
        p.address := 16 + nofPars * 8; INC(nofPars);
        DeclGet(sym, TRUE, 0)
      ELSE S.Mark(E.expIdent)
      END
    END;
    IF sym = S.colon THEN DeclGet(sym, FALSE, 0) ELSE S.Mark(E.expColon) END;
    FormalType0(T);
    DeclApply(FALSE, 0);
    p := first;
    WHILE p # ST.dummy DO
      p.type := T;
      IF (class = ST.Var) & (T.form IN {ST.Array, ST.Record}) THEN
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
  T.descOffset := -1;
  T.base := ST.noType;
  T.nofpars := 0;
  T.dsc := NIL;
  oldOpen := allowOpenArrayParams;
  allowOpenArrayParams := FALSE;
  IF sym = S.lparen THEN
    DeclGet(sym, FALSE, 0);
    ST.OpenScope;
    n := 0;
    IF sym # S.rparen THEN
      FPSection(n);
      WHILE sym = S.semicol DO
        DeclGet(sym, FALSE, 0);
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

PROCEDURE CheckExport(VAR exported: BOOLEAN);
BEGIN
  IF sym = S.times THEN
    S.Get(sym);
    exported := TRUE
  ELSE
    exported := FALSE
  END
END CheckExport;

(** Append (typ, name) to the pending-pointer list for the current
    TYPE section.  Caller must have set inTypeSection = TRUE. *)
PROCEDURE AddPendingPtr(typ: ST.Type; name: ARRAY OF CHAR);
VAR p: PendingPtr;
BEGIN
  NEW(p);
  p.typ := typ;
  Strings.Copy(name, p.name);
  p.next := pendingPtrs;
  pendingPtrs := p
END AddPendingPtr;

(** Resolve every entry on pendingPtrs by name lookup in the current
    scope.  Successful entries get their `base` set to the matching
    record type; unresolved ones produce an error.  Always clears the
    list. *)
PROCEDURE ResolvePendingPointers;
VAR p: PendingPtr;
  obj: ST.Object;
BEGIN
  p := pendingPtrs;
  WHILE p # NIL DO
    obj := ST.ThisObjectByName(p.name);
    IF (obj # NIL) & (obj.class = ST.Typ) & (obj.type # NIL)
        & (obj.type.form = ST.Record) THEN
      p.typ.base := obj.type;
      ST.BindDeclIfEmpty(obj.type, obj)
    ELSE
      S.Mark(E.pendingPointer)
    END;
    p := p.next
  END;
  pendingPtrs := NIL
END ResolvePendingPointers;

(** ParsePointer = "POINTER" "TO" QualIdent.
    If the base is already declared as a record, link directly.
    Otherwise inside a TYPE section, defer via the pending list. *)
PROCEDURE ParsePointer(VAR T: ST.Type);
VAR p: ST.Object;
  baseName: ARRAY 64 OF CHAR;
BEGIN
  S.Get(sym); (* consume POINTER *)
  IF sym = S.to THEN S.Get(sym) ELSE S.Mark(E.expTo) END;
  NEW(T);
  T.form := ST.Pointer;
  T.openRank := 0;
  T.size := 8;
  T.descOffset := -1;
  T.base := NIL;
  IF sym = S.ident THEN
    p := ST.ThisObject();
    Strings.Copy(S.id, baseName);
    IF p # NIL THEN
      S.Get(sym);
      IF (sym = S.period) & (p.class = ST.Mod) THEN
        S.Get(sym);
        IF sym = S.ident THEN
          p := ST.ThisImport(p);
          S.Get(sym);
          IF p = NIL THEN S.Mark(E.undecl) END
        ELSE S.Mark(E.expIdent); p := NIL
        END
      END;
      IF (p # NIL) & (p.class = ST.Typ) & (p.type # NIL)
          & (p.type.form = ST.Record) THEN
        T.base := p.type;
        ST.BindDeclIfEmpty(p.type, p)
      ELSE S.Mark(E.expBaseRecord)
      END
    ELSIF inTypeSection THEN
      AddPendingPtr(T, baseName);
      S.Get(sym)
    ELSE
      S.Mark(E.undecl); S.Get(sym)
    END
  ELSE S.Mark(E.expIdent)
  END
END ParsePointer;

(** FieldList = IdentList ":" Type. fieldQBase = logical index in ring at section start. *)
PROCEDURE FieldList(fieldQBase: INTEGER);
VAR first, p: ST.Object;
  T: ST.Type;
  exported: BOOLEAN;
BEGIN
  first := ST.NewObject(ST.Fld, S.id);
  RingPut(first);
  DeclGet(sym, TRUE, fieldQBase);
  CheckExport(exported); first.exported := exported;
  WHILE sym = S.comma DO
    DeclGet(sym, FALSE, fieldQBase);
    IF sym = S.ident THEN
      p := ST.NewObject(ST.Fld, S.id);
      RingPut(p);
      DeclGet(sym, TRUE, fieldQBase);
      CheckExport(exported); p.exported := exported
    ELSE S.Mark(E.expIdent)
    END
  END;
  IF sym = S.colon THEN DeclGet(sym, FALSE, fieldQBase) ELSE S.Mark(E.expColon) END;
  Type0(T);
  DeclApply(FALSE, fieldQBase);
  p := first;
  WHILE p # ST.dummy DO
    p.type := T;
    p := p.next
  END
END FieldList;

(** ParseRecord = "RECORD" [FieldList {";" FieldList}] "END".
    Called with `sym` already on RECORD; consumes through END.
    The Record's `dsc` is a chain of Fld objects terminated by `dummy`. *)
PROCEDURE ParseRecord(VAR T: ST.Type);
VAR baseObj: ST.Object;
  fieldQBase: INTEGER;
BEGIN
  S.Get(sym); (* consume RECORD *)
  NEW(T);
  T.form := ST.Record;
  T.openRank := 0;
  T.base := NIL;
  T.dsc := NIL;
  T.size := 0;
  T.extLevel := 0;
  T.descOffset := -1;
  DeclApply(FALSE, 0);
  IF sym = S.lparen THEN
    S.Get(sym);
    IF sym = S.ident THEN
      baseObj := ST.ThisObject();
      S.Get(sym);
      (* Allow `Mod.Type` qualified identifier for the base type so a
         module can extend a record imported from another. *)
      IF (baseObj # NIL) & (baseObj.class = ST.Mod) & (sym = S.period) THEN
        S.Get(sym);
        IF sym = S.ident THEN
          baseObj := ST.ThisImport(baseObj);
          S.Get(sym)
        ELSE S.Mark(E.expIdent); baseObj := NIL
        END
      END;
      IF baseObj = NIL THEN S.Mark(E.undecl)
      ELSIF (baseObj.class # ST.Typ) OR (baseObj.type = NIL)
            OR (baseObj.type.form # ST.Record) THEN
        S.Mark(E.expBaseRecord)
      ELSE
        T.base := baseObj.type;
        T.extLevel := baseObj.type.extLevel + 1
      END
    ELSE S.Mark(E.expIdent)
    END;
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
  END;
  fieldQBase := RingCount();
  ST.OpenScope;
  IF sym = S.ident THEN
    FieldList(fieldQBase);
    WHILE sym = S.semicol DO
      DeclGet(sym, FALSE, fieldQBase);
      IF sym = S.ident THEN FieldList(fieldQBase) END
    END
  END;
  T.dsc := ST.topScope.next;
  ST.CloseScope;
  ST.RecordLayout(T);
  IF sym = S.end THEN S.Get(sym) ELSE S.Mark(E.expEnd) END;
  (* Reserve (extLevel + 1) eight-byte slots in the module's __DATA
     for this record's TypeDesc.  The slots are filled at module-init
     time by Emitter.EmitRecordTypeDescInit. *)
  IF recordTypesN < LEN(recordTypes) THEN
    varsize := (varsize + 7) DIV 8 * 8;
    T.descOffset := varsize;
    T.descModule := -1;
    varsize := varsize + (T.extLevel + 1) * 8;
    recordTypes[recordTypesN] := T;
    INC(recordTypesN)
  END
END ParseRecord;

(** Type = ident | ARRAY expr {"," expr} OF Type |
           RECORD [FieldList {";" FieldList}] END |
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
    (* Inlined qualified-ident resolution so that
       VAR a: SYSTEM.ADRINT      -- or any other Module.Type --
       works.  Cannot call QualIdent here because it is defined later. *)
    p := ST.ThisObject();
    IF p = NIL THEN S.Mark(E.undecl); p := dummy END;
    S.Get(sym);
    IF (sym = S.period) & (p.class = ST.Mod) THEN
      S.Get(sym);
      IF sym = S.ident THEN
        p := ST.ThisImport(p);
        S.Get(sym);
        IF p = NIL THEN S.Mark(E.undecl); p := dummy END
      ELSE S.Mark(E.expIdent); p := dummy
      END
    END;
    IF p.class = ST.Typ THEN
      T := p.type
    ELSE S.Mark(E.expType)
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
      T.descOffset := -1;
      T.size := dims[i] * elemType.size;
      elemType := T;
      DEC(i)
    END
  ELSIF sym = S.record THEN
    ParseRecord(T)
  ELSIF sym = S.pointer THEN
    ParsePointer(T)
  ELSIF sym = S.procedure THEN
    ProcedureType(T)
  ELSE S.Mark(E.expIdent)
  END
END Type;

(** VarDecl = IdentList ":" Type. *)
PROCEDURE VarDecl;
VAR p, q: ST.Object;
  T: ST.Type;
  align: INTEGER;
BEGIN
  p := ST.NewObject(ST.Var, S.id);
  RingPut(p);
  DeclGet(sym, FALSE, 0);
  CheckExport(p.exported);
  WHILE sym = S.comma DO
    DeclGet(sym, FALSE, 0);
    IF sym = S.ident THEN
      q := ST.NewObject(ST.Var, S.id);
      RingPut(q);
      DeclGet(sym, FALSE, 0);
      CheckExport(q.exported)
    ELSE S.Mark(E.expIdent)
    END
  END;
  IF sym = S.colon THEN DeclGet(sym, FALSE, 0) ELSE S.Mark(E.expColon) END;
  Type(T);
  align := ST.Alignment(T);
  REPEAT
    p.type := T;
    IF align > 1 THEN
      varsize := (varsize + align - 1) DIV align * align
    END;
    IF ST.curLev > 0 THEN
      IF T.form = ST.Record THEN
        varsize := (varsize + 7) DIV 8 * 8;
        p.address := -(varsize + T.size - 8)
      ELSE
        p.address := -(varsize + T.size)
      END
    ELSIF T.form = ST.Record THEN
      varsize := (varsize + 7) DIV 8 * 8;
      p.address := varsize + 8
    ELSE
      p.address := varsize
    END;
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
    RingPut(p);
    DeclGet(sym, FALSE, 0);
    CheckExport(p.exported);
    IF sym = S.eql THEN DeclGet(sym, FALSE, 0)
    ELSE S.Mark(E.expEql)
    END;
    Expr0(x);
    IF x.mode # ST.Const THEN S.Mark(E.expConst); x.mode := ST.Const; x.a := 0 END;
    p.intVal := 0;
    IF (x.type # NIL) & (x.type.form = ST.Real) THEN
      p.realVal := SYSTEM.VAL(LONGREAL, SYSTEM.VAL(REAL, M.SHORT(x.a)))
    ELSIF (x.type # NIL) & (x.type.form = ST.LongReal) THEN
      p.realVal := SYSTEM.VAL(LONGREAL, x.a)
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
    RingClear;
    inTypeDecl := TRUE;
    p := ST.NewObject(ST.Typ, S.id);
    RingPut(p);
    DeclGet(sym, TRUE, 0);
    CheckExport(p.exported);
    IF sym = S.eql THEN DeclGet(sym, FALSE, 0)
    ELSE S.Mark(E.expEql)
    END;
    Type(T);
    DeclApply(FALSE, 0);
    p.type := T;
    IF T.form = ST.Record THEN ST.BindDecl(T, p) END;
    inTypeDecl := FALSE
  ELSE S.Mark(E.expIdent)
  END
END TypeDecl;

(** DeclSeq = [CONST {ConstDecl ";"}] [TYPE {TypeDecl ";"}]
             [VAR {VarDecl ";"}] {ProcedureDecl ";"}. *)
PROCEDURE DeclSeq;

  (** ProcedureDecl = ProcedureHeading ";" ProcedureBody ident. *)
  PROCEDURE ProcedureDecl;
  VAR proc: ST.Object;
    procType: ST.Type;
    procName: ST.Name;
    savedVarSize, nofPars, totalPars, parSize, frameSize: INTEGER;
    oldOpen: BOOLEAN;
    nameStr, pname: ARRAY 64 OF CHAR;
    x: Emitter.Item;

    PROCEDURE AssignParamAddresses(VAR totSlots: INTEGER);
    VAR p: ST.Object;
      slot, bytes: INTEGER;
    BEGIN
      slot := 0;
      p := ST.topScope.next;
      WHILE p # ST.dummy DO
        INC(slot, p.type.openRank + 1);
        p := p.next
      END;
      totSlots := slot;
      bytes := slot * 8;
      slot := 0;
      p := ST.topScope.next;
      WHILE p # ST.dummy DO
        p.address := -bytes + slot * 8;
        INC(slot, p.type.openRank + 1);
        p := p.next
      END
    END AssignParamAddresses;

  BEGIN
    DeclGet(sym, FALSE, 0); (* consume PROCEDURE token; queue cleared in DeclSeq *)
    IF sym = S.ident THEN
      (* Create procedure object in current (outer) scope *)
      proc := ST.NewObject(ST.Const, S.id);
      RingPut(proc);
      procName := NIL; ST.SetName(procName, S.id);
      DeclGet(sym, TRUE, 0);
      CheckExport(proc.exported);

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
      IF ST.curLev = 1 THEN
        ST.GetName(procName, pname);
        Emitter.SetProcName(pname)
      END;
      nofPars := 0;

      (* Parse formal parameters *)
      oldOpen := allowOpenArrayParams;
      allowOpenArrayParams := TRUE;
      IF sym = S.lparen THEN
        DeclGet(sym, FALSE, 0);
        IF sym # S.rparen THEN
          FPSection(nofPars);
          WHILE sym = S.semicol DO
            DeclGet(sym, FALSE, 0);
            FPSection(nofPars)
          END
        END;
        IF sym = S.rparen THEN DeclGet(sym, FALSE, 0) ELSE S.Mark(E.expRparen) END
      END;
      AssignParamAddresses(totalPars);
      parSize := totalPars * 8;
      IF totalPars > 8 THEN S.Mark(E.tooManyParams) END;
      allowOpenArrayParams := oldOpen;
      procType.nofpars := nofPars;
      procType.dsc := ST.topScope.next; (* link to first parameter *)

      (* Parse return type *)
      IF sym = S.colon THEN
        S.Get(sym);
        Type(procType.base)
      END;

      IF sym = S.semicol THEN DeclGet(sym, FALSE, 0) ELSE S.Mark(E.expSemicol) END;

      (* Parse local declarations *)
      savedVarSize := varsize;
      varsize := parSize;
      DeclSeq;

      (* Record entry point: nested procedures are now behind us, prologue
         comes next. Resolve any forward-reference fixups (e.g. nested
         procs that called this one before its address was known). *)
      proc.address := Generator.Here();
      Emitter.ResolveProc(proc);

      (* Emit prologue *)
      frameSize := (varsize + 16 + 15) DIV 16 * 16;
      Emitter.ProcPrologue(frameSize, totalPars);
      Emitter.ZeroLocals(-(frameSize - 16), -parSize);
      Emitter.EmitRecordVarTags(ST.topScope, TRUE);

      (* Parse body *)
      IF sym = S.begin THEN
        S.Get(sym);
        StatSeq0
      END;

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
    RingClear;
    inConstVarSection := TRUE;
    DeclGet(sym, FALSE, 0);
    WHILE sym = S.ident DO
      ConstDecl;
      IF sym = S.semicol THEN DeclGet(sym, FALSE, 0) ELSE S.Mark(E.expSemicol) END
    END;
    inConstVarSection := FALSE
  END;
  IF sym = S.type THEN
    RingClear;
    DeclGet(sym, FALSE, 0);
    pendingPtrs := NIL;
    inTypeSection := TRUE;
    WHILE sym = S.ident DO
      TypeDecl;
      IF sym = S.semicol THEN DeclGet(sym, FALSE, 0) ELSE S.Mark(E.expSemicol) END
    END;
    inTypeSection := FALSE;
    ResolvePendingPointers
  END;
  IF sym = S.var THEN
    RingClear;
    inConstVarSection := TRUE;
    DeclGet(sym, FALSE, 0);
    WHILE sym = S.ident DO
      VarDecl;
      IF sym = S.semicol THEN DeclGet(sym, FALSE, 0) ELSE S.Mark(E.expSemicol) END
    END;
    inConstVarSection := FALSE
  END;
  WHILE sym = S.procedure DO
    RingClear;
    ProcedureDecl;
    IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END
  END
END DeclSeq;

PROCEDURE IsTypeGuardContext(VAR x: Emitter.Item): BOOLEAN;
RETURN (x.type # NIL) & ((x.type.form = ST.Pointer) OR (x.type.form = ST.Record))
END IsTypeGuardContext;

PROCEDURE LenIsNavigationAfter(VAR x: Emitter.Item): BOOLEAN;
RETURN (sym = S.period) OR (sym = S.arrow) OR (sym = S.lbrak)
    OR (sym = S.lparen) & IsTypeGuardContext(x)
END LenIsNavigationAfter;

PROCEDURE LenFoldable(VAR x: Emitter.Item): INTEGER;
VAR n: INTEGER;
BEGIN
  n := -1;
  IF x.type # NIL THEN
    IF x.type.form = ST.Array THEN
      IF ~((x.mode = ST.VarPar) & ST.IsOpenArrayType(x.type)) THEN n := x.type.len END
    ELSIF (x.type.form = ST.String) & (x.mode = ST.Const) THEN n := x.type.len END
  END;
RETURN n END LenFoldable;

PROCEDURE LenCheckArrayIndex(VAR x: Emitter.Item; idx: INTEGER);
BEGIN
  IF (x.type # NIL) & (x.type.form = ST.Array) & (x.type.len > 0) THEN
    IF (idx < 0) OR (idx >= x.type.len) THEN S.Mark(E.indexOutOfBounds) END
  END
END LenCheckArrayIndex;

PROCEDURE LenVarOffset(VAR x, y: Emitter.Item);
VAR es: INTEGER;
BEGIN
  IF (x.mode = ST.Var) & (y.mode = ST.Const) & (x.type # NIL) & (x.type.form = ST.Array)
      & (x.type.base # NIL) THEN
    es := x.type.base.size;
    x.a := x.a + M.SHORT(y.a) * es
  END
END LenVarOffset;

PROCEDURE LenField(VAR x: Emitter.Item; fld: ST.Object);
VAR off: INTEGER;
BEGIN
  off := M.SHORT(fld.address);
  IF x.mode = ST.Var THEN
    x.a := x.a + off
  ELSIF x.mode = ST.VarPar THEN (* type-only: closed LEN uses type.len *)
  ELSE S.Mark(E.notRecord)
  END;
  x.type := fld.type;
  x.rdo := FALSE
END LenField;

PROCEDURE LenDerefType(VAR x: Emitter.Item);
BEGIN
  IF (x.type = NIL) OR (x.type.form # ST.Pointer) OR (x.type.base = NIL) THEN
    S.Mark(E.notPointer)
  ELSE
    x.type := x.type.base;
    x.rdo := FALSE
  END
END LenDerefType;

PROCEDURE LenTypeGuardType(VAR x: Emitter.Item; gType: ST.Type);
VAR target, pt: ST.Type;
BEGIN
  IF (gType.form = ST.Pointer) & (gType.base # NIL) & (x.type # NIL)
      & (x.type.base # NIL) & ST.Extends(gType.base, x.type.base) THEN
    target := gType.base;
    NEW(pt);
    pt^ := x.type^;
    pt.base := target;
    x.type := pt
  ELSIF (gType.form = ST.Record) & (x.type # NIL) & (x.type.form = ST.Record)
      & ST.Extends(gType, x.type) THEN
    x.type := gType
  ELSE S.Mark(E.incompatible)
  END
END LenTypeGuardType;

PROCEDURE LenProcessBracket(VAR x: Emitter.Item);
VAR idxs: ARRAY 8 OF Emitter.Item;
  n, i: INTEGER;
  nav: BOOLEAN;
BEGIN
  LenIndexExpr0(idxs[0]);
  CheckInt(idxs[0]);
  n := 1;
  WHILE (sym = S.comma) & (n < 8) DO
    S.Get(sym);
    LenIndexExpr0(idxs[n]);
    CheckInt(idxs[n]);
    INC(n)
  END;
  IF sym = S.rbrak THEN S.Get(sym) ELSE S.Mark(E.expRbrak) END;
  nav := LenIsNavigationAfter(x);
  i := 0;
  WHILE i < n DO
    IF x.type.form # ST.Array THEN S.Mark(E.notArray)
    ELSE
      IF nav THEN
        IF idxs[i].mode = ST.Const THEN LenCheckArrayIndex(x, M.SHORT(idxs[i].a)) END;
        LenVarOffset(x, idxs[i]);
        x.type := x.type.base
      END
    END;
    INC(i)
  END;
  IF ~nav THEN
    lenDepth := lenDepth + n;
    i := 0;
    WHILE i < n DO
      IF (x.type # NIL) & (x.type.form = ST.Array) THEN x.type := x.type.base
      ELSE S.Mark(E.notArray)
      END;
      INC(i)
    END
  END
END LenProcessBracket;

PROCEDURE Selector(VAR x: Emitter.Item);
VAR y: Emitter.Item;
  fld, gObj: ST.Object;
  gType, target, pt: ST.Type;
BEGIN
  WHILE (sym = S.lbrak) OR (sym = S.period) OR (sym = S.arrow)
      OR (sym = S.lparen) & IsTypeGuardContext(x) DO
    IF sym = S.lbrak THEN
      S.Get(sym);
      IF insideLen > 0 THEN
        LenProcessBracket(x)
      ELSIF (x.mode = ST.Const) & (x.type.form = ST.String) THEN
        Expr0(y);
        CheckInt(y);
        IF sym = S.comma THEN S.Mark(E.incompatible) END;
        Emitter.StringIndex(x, y);
        IF sym = S.rbrak THEN S.Get(sym) ELSE S.Mark(E.expRbrak) END
      ELSE
        Expr0(y);
        Emitter.Index(x, y);
        WHILE sym = S.comma DO
          S.Get(sym);
          Expr0(y);
          Emitter.Index(x, y)
        END;
        IF sym = S.rbrak THEN S.Get(sym) ELSE S.Mark(E.expRbrak) END
      END
    ELSIF sym = S.arrow THEN
      S.Get(sym);
      IF insideLen > 0 THEN LenDerefType(x) ELSE Emitter.Deref(x) END
    ELSIF sym = S.lparen THEN
      S.Get(sym);
      gType := NIL;
      IF sym = S.ident THEN
        gObj := ST.ThisObject();
        IF gObj = NIL THEN S.Mark(E.undecl)
        ELSIF (gObj.class # ST.Typ) OR (gObj.type = NIL) THEN
          S.Mark(E.expType)
        ELSE gType := gObj.type
        END;
        S.Get(sym)
      ELSE S.Mark(E.expIdent)
      END;
      IF gType # NIL THEN
        IF insideLen > 0 THEN LenTypeGuardType(x, gType)
        ELSIF (gType.form = ST.Pointer) & (gType.base # NIL)
            & (x.type.base # NIL)
            & ST.Extends(gType.base, x.type.base) THEN
          target := gType.base;
          Emitter.TypeGuard(x, target);
          NEW(pt);
          pt^ := x.type^;
          pt.base := target;
          x.type := pt
        ELSIF (gType.form = ST.Record) & (x.type.form = ST.Record)
            & ST.Extends(gType, x.type) THEN
          Emitter.TypeGuard(x, gType);
          x.type := gType
        ELSE S.Mark(E.incompatible)
        END
      END;
      IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
    ELSE (* sym = S.period *)
      S.Get(sym);
      IF sym = S.ident THEN
        IF (x.type # NIL) & (x.type.form = ST.Pointer) THEN
          IF insideLen > 0 THEN LenDerefType(x) ELSE Emitter.Deref(x) END
        END;
        IF (x.type = NIL) OR (x.type.form # ST.Record) THEN
          S.Mark(E.notRecord)
        ELSE
          fld := ST.ThisField(x.type);
          IF fld = NIL THEN
            S.Mark(E.notField)
          ELSE
            IF insideLen > 0 THEN LenField(x, fld) ELSE Emitter.Field(x, fld) END
          END
        END;
        S.Get(sym)
      ELSE S.Mark(E.expIdent)
      END
    END
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
      ELSIF sym = S.div THEN
        obj := ST.ImportByAddress(obj, -110);
        S.Get(sym);
        IF obj = NIL THEN S.Mark(E.undecl); obj := dummy END
      ELSIF sym = S.mod THEN
        obj := ST.ImportByAddress(obj, -111);
        S.Get(sym);
        IF obj = NIL THEN S.Mark(E.undecl); obj := dummy END
      ELSE S.Mark(E.expIdent); obj := dummy
      END
    END
  ELSE S.Mark(E.expIdent)
  END
END QualIdent;

PROCEDURE LenParseDesignator(VAR x: Emitter.Item);
VAR obj: ST.Object;
BEGIN
  IF sym = S.string THEN
    Emitter.MakeStringConstItem(x, ST.RegisterString(S.sval, S.len), S.len);
    S.Get(sym)
  ELSIF sym = S.ident THEN
    QualIdent(obj);
    Emitter.MakeItem(x, obj);
    Selector(x)
  ELSE S.Mark(E.expIdent)
  END
END LenParseDesignator;

PROCEDURE LenParseLenOperand(VAR x: Emitter.Item);
VAR saved: INTEGER;
BEGIN
  IF sym # S.lparen THEN S.Mark(E.expLparen)
  ELSE
    S.Get(sym);
    saved := lenDepth;
    lenDepth := 0;
    INC(insideLen);
    LenParseDesignator(x);
    DEC(insideLen);
    lenDepth := saved;
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
  END
END LenParseLenOperand;

PROCEDURE LenIndexFactor(VAR x: Emitter.Item);
VAR obj: ST.Object;
  n: INTEGER;
  z: Emitter.Item;
BEGIN
  IF sym = S.int THEN
    Emitter.MakeConstItem(x, ST.intType, S.ival);
    S.Get(sym)
  ELSIF sym = S.ident THEN
    QualIdent(obj);
    IF (obj.class = ST.SFunc) & (M.SHORT(obj.address) = 40) THEN
      LenParseLenOperand(z);
      n := LenFoldable(z);
      IF n >= 0 THEN Emitter.MakeConstItem(x, ST.intType, n)
      ELSE Emitter.MakeConstItem(x, ST.intType, 0)
      END
    ELSIF (obj.type # NIL) & (obj.type.form = ST.Proc) & (sym = S.lparen) THEN
      S.Mark(E.incompatible);
      Emitter.MakeConstItem(x, ST.intType, 0)
    ELSE
      Emitter.MakeItem(x, obj);
      CheckInt(x)
    END
  ELSIF sym = S.lparen THEN
    S.Get(sym);
    LenIndexExpr0(x);
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
  ELSIF sym = S.not THEN
    S.Get(sym);
    LenIndexFactor0(x);
    IF x.mode = ST.Const THEN x.a := -x.a END
  ELSE S.Mark(E.expIdent)
  END
END LenIndexFactor;

PROCEDURE LenIndexTerm(VAR x: Emitter.Item);
VAR y: Emitter.Item;
  op: INTEGER;
BEGIN
  IF sym = S.minus THEN
    S.Get(sym);
    LenIndexFactor0(x);
    CheckInt(x);
    IF x.mode = ST.Const THEN x.a := -x.a END
  ELSE
    LenIndexFactor0(x);
    CheckInt(x)
  END;
  WHILE (sym = S.plus) OR (sym = S.minus) DO
    op := sym;
    S.Get(sym);
    LenIndexFactor0(y);
    CheckInt(y);
    IF (x.mode = ST.Const) & (y.mode = ST.Const) THEN
      IF op = S.plus THEN x.a := x.a + y.a ELSE x.a := x.a - y.a END
    ELSE x.mode := ST.Const; x.a := 0 END;
    x.type := ST.intType
  END
END LenIndexTerm;

PROCEDURE LenIndexExpr(VAR x: Emitter.Item);
BEGIN LenIndexTerm0(x) END LenIndexExpr;

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

(** SYSTEM.VAL(T, expr): first actual is a type. *)
PROCEDURE ValCall(VAR x: Emitter.Item);
VAR dstType: ST.Type;
  y: Emitter.Item;
BEGIN
  S.Get(sym);
  Type(dstType);
  IF sym = S.comma THEN
    S.Get(sym);
    Expr0(y);
    IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END;
    IF ~S.error & ~ST.ValCompatible(dstType, y.type) THEN S.Mark(E.incompatible) END;
    Emitter.Val(x, y, dstType)
  ELSE S.Mark(E.fewerParams)
  END
END ValCall;

PROCEDURE CloseSystemParen;
BEGIN
  IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END
END CloseSystemParen;

PROCEDURE CheckAddress(VAR a: Emitter.Item);
BEGIN
  IF (a.type # NIL) & ~ST.IsAddressType(a.type) THEN S.Mark(E.incompatible) END
END CheckAddress;

PROCEDURE ParseAddress(VAR a: Emitter.Item);
BEGIN
  S.Get(sym);
  Expr0(a);
  CheckAddress(a)
END ParseAddress;

(** SYSTEM.BIT(a, n) *)
PROCEDURE SystemBitCall(VAR x: Emitter.Item);
VAR addr, bit: Emitter.Item;
BEGIN
  ParseAddress(addr);
  IF sym = S.comma THEN
    S.Get(sym);
    Expr0(bit);
    IF (bit.type # NIL) & ~ST.IsIntegerForm(bit.type.form) THEN S.Mark(E.incompatible) END
  ELSE S.Mark(E.fewerParams)
  END;
  CloseSystemParen;
  IF ~S.error THEN Emitter.SystemBit(x, addr, bit) END
END SystemBitCall;

(** SYSTEM.GET(a, v) *)
PROCEDURE SystemGetCall;
VAR addr, dest: Emitter.Item;
  obj: ST.Object;
BEGIN
  ParseAddress(addr);
  IF sym = S.comma THEN
    S.Get(sym);
    QualIdent(obj);
    Emitter.MakeItem(dest, obj);
    Selector(dest);
    IF dest.rdo THEN S.Mark(E.readOnly) END;
    IF (dest.type # NIL) & ~ST.IsElementaryForm(dest.type.form) THEN S.Mark(E.incompatible) END;
    IF dest.mode IN {ST.Var, ST.VarPar, Emitter.RegI} THEN
      IF ~S.error THEN Emitter.SystemGet(addr, dest) END
    ELSE S.Mark(E.incompatible)
    END
  ELSE S.Mark(E.fewerParams)
  END;
  CloseSystemParen
END SystemGetCall;

(** SYSTEM.PUT(a, x) *)
PROCEDURE SystemPutCall;
VAR addr, val: Emitter.Item;
BEGIN
  ParseAddress(addr);
  IF sym = S.comma THEN
    S.Get(sym);
    Expr0(val);
    IF (val.type # NIL) & ~ST.IsElementaryForm(val.type.form) THEN S.Mark(E.incompatible) END;
    IF ~S.error THEN Emitter.SystemPut(addr, val) END
  ELSE S.Mark(E.fewerParams)
  END;
  CloseSystemParen
END SystemPutCall;

(** SYSTEM.COPY(src, dst, n) *)
PROCEDURE SystemCopyCall;
VAR src, dst, n: Emitter.Item;
BEGIN
  ParseAddress(src);
  IF sym = S.comma THEN
    S.Get(sym);
    Expr0(dst);
    CheckAddress(dst);
    IF sym = S.comma THEN
      S.Get(sym);
      Expr0(n);
      IF (n.type # NIL) & ~ST.IsIntegerForm(n.type.form) THEN S.Mark(E.incompatible) END;
      IF ~S.error THEN Emitter.SystemCopy(src, dst, n) END
    ELSE S.Mark(E.fewerParams)
    END
  ELSE S.Mark(E.fewerParams)
  END;
  CloseSystemParen
END SystemCopyCall;

(** SYSTEM.ADC / SBC / UML / DIV / MOD(m, n) *)
PROCEDURE SystemInt2Call(VAR x: Emitter.Item; id: INTEGER);
VAR m, n: Emitter.Item;
BEGIN
  S.Get(sym);
  Expr0(m);
  IF (m.type # NIL) & ~ST.IsIntegerForm(m.type.form) THEN S.Mark(E.incompatible) END;
  IF sym = S.comma THEN
    S.Get(sym);
    Expr0(n);
    IF (n.type # NIL) & ~ST.IsIntegerForm(n.type.form) THEN S.Mark(E.incompatible) END
  ELSE S.Mark(E.fewerParams)
  END;
  CloseSystemParen;
  IF ~S.error THEN
    IF id = -106 THEN Emitter.SystemAdc(x, m, n)
    ELSIF id = -107 THEN Emitter.SystemSbc(x, m, n)
    ELSIF id = -108 THEN Emitter.SystemUml(x, m, n)
    ELSIF id = -110 THEN Emitter.SystemDiv(x, m, n)
    ELSE Emitter.SystemMod(x, m, n)
    END
  END
END SystemInt2Call;

(** SYSTEM.COND(n) *)
PROCEDURE SystemCondCall(VAR x: Emitter.Item);
VAR n: Emitter.Item;
BEGIN
  S.Get(sym);
  Expr0(n);
  IF (n.type # NIL) & ~ST.IsIntegerForm(n.type.form) THEN S.Mark(E.incompatible) END;
  IF n.mode # ST.Const THEN S.Mark(E.incompatible) END;
  CloseSystemParen;
  IF ~S.error THEN Emitter.SystemCond(x, n) END
END SystemCondCall;

(** SYSTEM.PACK(x, n) *)
PROCEDURE SystemPackCall;
VAR x, n: Emitter.Item;
  obj: ST.Object;
BEGIN
  S.Get(sym);
  QualIdent(obj);
  Emitter.MakeItem(x, obj);
  Selector(x);
  IF x.rdo THEN S.Mark(E.readOnly) END;
  IF (x.type # NIL) & (x.type.form # ST.Real) THEN S.Mark(E.incompatible) END;
  IF sym = S.comma THEN
    S.Get(sym);
    Expr0(n);
    IF (n.type # NIL) & ~ST.IsIntegerForm(n.type.form) THEN S.Mark(E.incompatible) END
  ELSE S.Mark(E.fewerParams)
  END;
  CloseSystemParen;
  IF ~S.error THEN Emitter.SystemPack(x, n) END
END SystemPackCall;

(** SYSTEM.UNPK(x, n) *)
PROCEDURE SystemUnpkCall;
VAR x, n: Emitter.Item;
  obj: ST.Object;
BEGIN
  S.Get(sym);
  QualIdent(obj);
  Emitter.MakeItem(x, obj);
  Selector(x);
  IF x.rdo THEN S.Mark(E.readOnly) END;
  IF (x.type # NIL) & (x.type.form # ST.Real) THEN S.Mark(E.incompatible) END;
  IF sym = S.comma THEN
    S.Get(sym);
    QualIdent(obj);
    Emitter.MakeItem(n, obj);
    Selector(n);
    IF n.rdo THEN S.Mark(E.readOnly) END;
    IF (n.type # NIL) & ~ST.IsIntegerForm(n.type.form) THEN S.Mark(E.incompatible) END;
    IF n.mode IN {ST.Var, ST.VarPar, Emitter.RegI} THEN
      IF ~S.error THEN Emitter.SystemUnpk(x, n) END
    ELSE S.Mark(E.incompatible)
    END
  ELSE S.Mark(E.fewerParams)
  END;
  CloseSystemParen
END SystemUnpkCall;

PROCEDURE SystemMemStmt(obj: ST.Object): BOOLEAN;
VAR id: INTEGER;
  handled: BOOLEAN;
BEGIN
  handled := FALSE;
  IF (obj.class = ST.Const) & (obj.type # NIL) & (obj.type.form = ST.Proc) THEN
    id := M.SHORT(obj.address);
    IF sym = S.lparen THEN
      IF id = -103 THEN handled := TRUE; SystemGetCall
      ELSIF id = -104 THEN handled := TRUE; SystemPutCall
      ELSIF id = -105 THEN handled := TRUE; SystemCopyCall
      ELSIF id = -112 THEN handled := TRUE; SystemPackCall
      ELSIF id = -113 THEN handled := TRUE; SystemUnpkCall
      END
    END
  END
RETURN handled END SystemMemStmt;

PROCEDURE StandFunc(VAR x: Emitter.Item; func: INTEGER; resType: ST.Type);
VAR y: Emitter.Item;
  obj: ST.Object;
  n, lenAddr: INTEGER;
  is2arg: BOOLEAN;
BEGIN
  is2arg := (func >= 35) & (func <= 37);
  IF sym = S.lparen THEN
    S.Get(sym);
    IF func = 40 (*LEN*) THEN
      lenDepth := 0;
      IF sym = S.string THEN
        Emitter.MakeStringConstItem(x, ST.RegisterString(S.sval, S.len), S.len);
        S.Get(sym)
      ELSIF sym = S.ident THEN
        INC(insideLen);
        QualIdent(obj);
        Emitter.MakeItem(x, obj);
        Selector(x);
        DEC(insideLen)
      ELSE S.Mark(E.expIdent)
      END;
      IF sym = S.comma THEN
        WHILE sym = S.comma DO
          S.Get(sym);
          Expr0(y)
        END;
        S.Mark(E.moreParams)
      END;
      IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END;
      IF x.type.form = ST.Array THEN
        IF (x.mode = ST.VarPar) & ST.IsOpenArrayType(x.type) THEN
          lenAddr := M.SHORT(x.a) + (lenDepth + 1) * 8;
          Emitter.LoadParamLen(x, lenAddr)
        ELSE
          Emitter.MakeConstItem(x, ST.intType, x.type.len)
        END
      ELSIF (x.type.form = ST.String) & (x.mode = ST.Const) THEN
        Emitter.MakeConstItem(x, ST.intType, x.type.len)
      ELSE
        S.Mark(E.notArray);
        Emitter.MakeConstItem(x, ST.intType, 0)
      END;
      x.type := ST.intType
    ELSIF func = 47 (*SYSTEM.ADR*) THEN
      (* Polymorphic: accepts any designator -- scalar, fixed/open
         array, VAR parameter.  For arrays SYSTEM.ADR(arr) and
         SYSTEM.ADR(arr[0]) both yield the address of the first
         element. *)
      QualIdent(obj);
      Emitter.MakeItem(x, obj);
      Selector(x);
      IF sym = S.comma THEN
        WHILE sym = S.comma DO
          S.Get(sym);
          Expr0(y)
        END;
        S.Mark(E.moreParams)
      END;
      IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END;
      Emitter.AddrOf(x)
    ELSE
      SimpleExpr0(x);
      n := 1;
      WHILE sym = S.comma DO
        S.Get(sym);
        SimpleExpr0(y);
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
        ELSIF ST.IsSetForm(x.type.form) THEN
          Emitter.Ord(x);
          IF x.type.form = ST.LongSet THEN x.type := ST.longIntType
          ELSE x.type := ST.intType
          END
        END
      ELSIF func = 52 (*BITS*) THEN
        IF ST.IsIntegerForm(x.type.form) THEN
          IF (exprExpect # NIL) & ST.IsSetForm(exprExpect.form) THEN
            Emitter.Bits(x, exprExpect);
            x.type := exprExpect
          ELSE
            Emitter.Bits(x, ST.setType);
            x.type := ST.setType
          END
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 32 (*CHR*) THEN
        IF ST.IsIntegerForm(x.type.form) THEN Emitter.Ord(x) END
      ELSIF func = 33 (*ABS*) THEN
        IF ST.IntegerRank(x.type.form) >= 0 THEN Emitter.AbsVal(x) END
      ELSIF func = 34 (*ODD*) THEN
        IF ST.IsIntegerForm(x.type.form) THEN Emitter.OddVal(x) END
      ELSIF func = 35 (*ASR*) THEN
        CheckInt(x); Emitter.AsrVal(x, y)
      ELSIF func = 36 (*LSL*) THEN
        CheckInt(x); Emitter.LslVal(x, y)
      ELSIF func = 37 (*ROR*) THEN
        CheckInt(x); Emitter.RorVal(x, y)
      ELSIF func = 38 (*FLOOR*) THEN
        IF x.type.form = ST.Real THEN Emitter.Floor(x)
        ELSIF x.type.form = ST.LongReal THEN Emitter.FloorD(x)
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 39 (*FLT*) THEN
        IF ST.IsIntegerForm(x.type.form) THEN Emitter.Flt(x)
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 50 (*ENTIER*) THEN
        IF x.type.form = ST.Real THEN Emitter.EntierR(x)
        ELSIF x.type.form = ST.LongReal THEN Emitter.Entier(x)
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 51 (*LONGFLT*) THEN
        IF ST.IsIntegerForm(x.type.form) THEN Emitter.LongFlt(x)
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 45 (*SHORT*) THEN
        (* SYSTEM.ADRINT must collapse to INTEGER on any host: a 64-bit
           target needs an actual truncation (form = LongInt -> Int);
           a 32-bit one is just a relabel.  This is *before* the
           generic form-based dispatch, otherwise SHORT(adrint) on a
           32-bit build would erroneously narrow to SHORTINT. *)
        IF x.type = ST.adrIntType THEN
          IF x.type.form = ST.LongInt THEN Emitter.Short(x) END;
          x.type := ST.intType
        ELSIF ST.IntegerRank(x.type.form) > 0 THEN
          Emitter.Short(x);
          x.type := ST.IntegerTypeAtRank(ST.IntegerRank(x.type.form) - 1)
        ELSIF ST.SetRank(x.type.form) > 0 THEN
          Emitter.Short(x);
          x.type := ST.SetTypeAtRank(ST.SetRank(x.type.form) - 1)
        ELSE S.Mark(E.incompatible)
        END
      ELSIF func = 46 (*LONG*) THEN
        (* SYSTEM.ADRINT must promote to LONGINT on any host: a 32-bit
           target needs an actual sign-extension (form = Int -> LongInt);
           a 64-bit one is just a relabel.  Check the ADRINT identity
           first so the standard `LongInt -> incompatible` path is not
           taken on 64-bit hosts. *)
        IF x.type = ST.adrIntType THEN
          IF x.type.form = ST.Int THEN Emitter.Long(x) END;
          x.type := ST.longIntType
        ELSIF ST.IntegerRank(x.type.form) >= 0 THEN
          IF ST.IntegerRank(x.type.form) < 3 THEN
            Emitter.Long(x);
            x.type := ST.IntegerTypeAtRank(ST.IntegerRank(x.type.form) + 1)
          ELSE S.Mark(E.incompatible)
          END
        ELSIF ST.SetRank(x.type.form) >= 0 THEN
          IF ST.SetRank(x.type.form) < 3 THEN
            Emitter.Long(x);
            x.type := ST.SetTypeAtRank(ST.SetRank(x.type.form) + 1)
          ELSE S.Mark(E.incompatible)
          END
        ELSE S.Mark(E.incompatible)
        END
      ELSE ASSERT(FALSE)
      END;
      IF (func # 31) & (func # 45) & (func # 46) & (func # 52) THEN x.type := resType END
    END
  ELSE S.Mark(E.expLparen)
  END
END StandFunc;

(** StandProc = ident "(" expr ["," expr] ")". *)
PROCEDURE StandProc(proc: INTEGER);
VAR x, n: Emitter.Item;
  line, nVal: INTEGER;
BEGIN
  IF proc = 49 (*ASSERT*) THEN
    line := S.identLine;
    IF sym = S.lparen THEN
      S.Get(sym);
      Expr0(x);
      nVal := 0;
      IF sym = S.comma THEN
        S.Get(sym);
        Expr0(n);
        IF n.mode # ST.Const THEN S.Mark(E.expConst)
        ELSIF ~ST.TypesCompatible(ST.intType, n.type) THEN S.Mark(E.incompatible)
        ELSE nVal := M.SHORT(n.a)
        END
      END;
      IF sym = S.rparen THEN S.Get(sym) ELSE S.Mark(E.expRparen) END;
      IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
      Emitter.Assert(x, nVal, line)
    ELSE S.Mark(E.expLparen)
    END
  ELSIF sym = S.lparen THEN
    S.Get(sym);
    Expr0(x);
    IF (proc = 48) & (sym = S.comma) THEN
      (* NEW takes exactly one designator *)
      S.Mark(E.moreParams);
      WHILE sym = S.comma DO S.Get(sym); Expr0(n) END
    ELSIF sym = S.comma THEN
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
    ELSIF proc = 48 (*NEW*) THEN Emitter.NewVar(x)
    END
  ELSE S.Mark(E.expLparen)
  END
END StandProc;

(** Emit hidden length params for an open-array actual into x{slot},
    x{slot+1}, ... (ABI slots after the array pointer). *)
PROCEDURE EmitOpenArrayLengths(parType, actType: ST.Type; actA: INTEGER; VAR slot: INTEGER);
VAR i: INTEGER;
  n: Emitter.Item;
BEGIN
  i := 0;
  WHILE i < ST.OpenArrayRank(parType) DO
    IF ST.IsOpenArrayType(actType) THEN
      Emitter.LoadParamLen(n, actA + (i + 1) * 8);
      Emitter.ValueParam(n, slot);
      INC(slot);
      actType := actType.base
    ELSIF (actType # NIL) & (actType.form = ST.Array) & (actType.len > 0) THEN
      Emitter.MakeConstItem(n, ST.intType, actType.len);
      Emitter.ValueParam(n, slot);
      INC(slot);
      actType := actType.base
    ELSIF (actType # NIL) & (actType.form = ST.String) THEN
      Emitter.MakeConstItem(n, ST.intType, actType.len);
      Emitter.ValueParam(n, slot);
      INC(slot);
      actType := ST.charType
    ELSE
      S.Mark(E.incompatible);
      Emitter.MakeConstItem(n, ST.intType, 0);
      Emitter.ValueParam(n, slot);
      INC(slot);
      IF (actType # NIL) & (actType.form = ST.Array) THEN actType := actType.base END
    END;
    INC(i)
  END
END EmitOpenArrayLengths;

(** Param = Expr. *)
PROCEDURE Param(par: ST.Object; VAR slot: INTEGER);
VAR x: Emitter.Item;
  actA: INTEGER;
BEGIN
  Expr0(x);
  IF (par.type.form = ST.Char) & (x.type.form = ST.String) THEN
    FoldStringConstToChar(x)
  END;
  IF ST.IsOpenArrayType(par.type) & ST.IsCharArrayType(par.type) & (x.type.form = ST.String) & (x.mode = ST.Const)
      OR (par.class = ST.Var) & (* value param: widening OK; constant numerics OK; VAR = strict *)
         ((x.mode = ST.Const) & (ST.TypesCompatible(par.type, x.type)
            OR ST.TypeAssignable(par.type, x.type))
          OR (x.mode # ST.Const) & ST.TypeAssignable(par.type, x.type))
      OR (par.class = ST.VarPar) & ST.VarActualCompatible(par.type, x.type) THEN
    actA := M.SHORT(x.a);
    IF (par.type # NIL) & (par.type.form = ST.LongReal) & (x.type # NIL) & (x.type.form = ST.Real) THEN
      Emitter.PromoteRealToLong(x)
    END;
    IF par.class = ST.Var THEN
      Emitter.ValueParam(x, slot)
    ELSE
      IF ~par.readOnly & x.rdo THEN S.Mark(E.readOnly) END;
      IF (par.type.form = ST.Record) & (x.type.form = ST.Record) THEN
        Emitter.EmitRecordParamTypeCheck(x, par.type)
      END;
      Emitter.VarParam(x, slot)
    END;
    INC(slot);
    IF ST.IsOpenArrayType(par.type) THEN
      EmitOpenArrayLengths(par.type, x.type, actA, slot)
    END
  ELSE S.Mark(E.incompatible)
  END
END Param;

(** ActualParams = "(" [Expr {"," Expr}] ")". *)
PROCEDURE ActualParams(VAR x: Emitter.Item);
CONST svcCall = -100; maxSvcArgs = 7;
VAR n, slot: INTEGER;
  par: ST.Object;
  isSvc: BOOLEAN;
  extra: Emitter.Item;

  PROCEDURE Arg(VAR slot: INTEGER);
  VAR a: Emitter.Item;
  BEGIN
    IF isSvc THEN
      Expr0(a);
      IF (a.mode = ST.Const) & (ST.TypesCompatible(ST.longIntType, a.type)
            OR ST.IsIntegerForm(a.type.form))
          OR (a.mode # ST.Const) & (ST.TypeAssignable(ST.longIntType, a.type)
            OR ST.IsIntegerForm(a.type.form)) THEN
        IF (a.type # NIL) & ST.IsIntegerForm(a.type.form) & (a.type.form # ST.LongInt) THEN
          Emitter.Long(a);
          a.type := ST.longIntType
        END;
        Emitter.ValueParam(a, slot);
        INC(slot)
      ELSE S.Mark(E.incompatible)
      END
    ELSE
      Param(par, slot)
    END
  END Arg;

BEGIN
  isSvc := (x.mode = ST.Const) & (x.a = svcCall);
  S.Get(sym);
  IF sym = S.rparen THEN
    IF isSvc THEN S.Mark(E.fewerParams) END;
    n := 0
  ELSE
    IF ~isSvc THEN par := x.type.dsc END;
    slot := 0;
    Arg(slot); n := 1;
    WHILE sym = S.comma DO
      S.Get(sym);
      IF isSvc THEN
        IF n >= maxSvcArgs THEN S.Mark(E.moreParams) END;
        Arg(slot)
      ELSIF (par # NIL) & (par # ST.dummy) THEN
        par := par.next;
        IF (par # NIL) & (par # ST.dummy) THEN Arg(slot)
        ELSE
          S.Mark(E.moreParams);
          IF sym = S.int THEN S.Get(sym)
          ELSIF sym = S.real THEN S.Get(sym)
          ELSIF sym = S.string THEN S.Get(sym)
          ELSIF (sym = S.false) OR (sym = S.true) THEN S.Get(sym)
          ELSIF sym = S.nil THEN S.Get(sym)
          ELSE Expr0(extra)
          END;
          Emitter.FixRH(0)
        END
      ELSE
        S.Mark(E.moreParams);
        IF sym = S.int THEN S.Get(sym)
        ELSIF sym = S.real THEN S.Get(sym)
        ELSIF sym = S.string THEN S.Get(sym)
        ELSIF (sym = S.false) OR (sym = S.true) THEN S.Get(sym)
        ELSIF sym = S.nil THEN S.Get(sym)
        ELSE Expr0(extra)
        END;
        Emitter.FixRH(0)
      END;
      INC(n)
    END;
    IF isSvc THEN
      IF n > maxSvcArgs THEN S.Mark(E.moreParams) END
    ELSIF n < x.type.nofpars THEN S.Mark(E.fewerParams)
    ELSIF n > x.type.nofpars THEN S.Mark(E.moreParams)
    END
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
    IF (obj.class = ST.Const) & (obj.type # NIL) & (obj.type.form = ST.Proc)
        & (sym = S.lparen) & (M.SHORT(obj.address) = -101) THEN ValCall(x)
    ELSIF (obj.class = ST.Const) & (obj.type # NIL) & (obj.type.form = ST.Proc)
        & (sym = S.lparen) & (M.SHORT(obj.address) = -102) THEN SystemBitCall(x)
    ELSIF (obj.class = ST.Const) & (obj.type # NIL) & (obj.type.form = ST.Proc)
        & (sym = S.lparen)         & (M.SHORT(obj.address) >= -111)
        & (M.SHORT(obj.address) <= -106)
        & (M.SHORT(obj.address) # -109)
        & (M.SHORT(obj.address) # -112)
        & (M.SHORT(obj.address) # -113) THEN SystemInt2Call(x, M.SHORT(obj.address))
    ELSIF (obj.class = ST.Const) & (obj.type # NIL) & (obj.type.form = ST.Proc)
        & (sym = S.lparen) & (M.SHORT(obj.address) = -109) THEN SystemCondCall(x)
    ELSIF (obj.class = ST.Const) & (obj.type # NIL) & (obj.type.form = ST.Proc)
        & (sym = S.lparen) & (M.SHORT(obj.address) >= -105)
        & (M.SHORT(obj.address) <= -103) THEN
      S.Get(sym); S.Mark(E.incompatible)
    ELSIF obj.class = ST.SFunc THEN StandFunc(x, M.SHORT(obj.address), obj.type)
    ELSE
      Emitter.MakeItem(x, obj); Selector(x);
      IF (x.type.form = ST.Proc) & (x.type.base.form # ST.NoTyp)
          & (sym = S.lparen) THEN
        Emitter.PrepCall(x, rx);
        ActualParams(x);
        IF ~S.error THEN
          Emitter.Call(x, rx, obj);
          x.type := x.type.base;
          x.mode := Emitter.Reg;
          x.r := rx;
          Emitter.FixRH(rx + 1)
        ELSE Emitter.FixRH(0)
        END
      END
    END
  ELSIF sym = S.string THEN
    Emitter.MakeStringConstItem(x, ST.RegisterString(S.sval, S.len), S.len);
    S.Get(sym);
    IF sym = S.lbrak THEN S.Mark(E.notArray) END
  ELSIF (sym = S.false) OR (sym = S.true) THEN
    Emitter.MakeConstItem(x, ST.boolType, ORD(sym = S.true));
    S.Get(sym)
  ELSIF sym = S.nil THEN
    Emitter.MakeNilItem(x);
    S.Get(sym)
  ELSIF sym = S.not THEN
    S.Get(sym);
    Factor(x);
    IF x.type.form # ST.Bool THEN S.Mark(E.expBool) END;
    Emitter.Not(x)
  ELSIF sym = S.lbrace THEN
    (* Set literal: {elem, lo..hi, ...} *)
    IF (exprExpect # NIL) & ST.IsSetForm(exprExpect.form) THEN
      Emitter.MakeConstItem(x, exprExpect, 0)
    ELSE
      Emitter.MakeConstItem(x, ST.setType, 0)
    END;
    S.Get(sym);
    IF sym # S.rbrace THEN
      Expr0(y);
      IF sym = S.upto THEN
        S.Get(sym); Expr0(z); Emitter.SetRange(y, z); y.type := x.type
      ELSE
        Emitter.Singleton(y); y.type := x.type
      END;
      Emitter.SetUnion(x, y);
      WHILE sym = S.comma DO
        S.Get(sym);
        Expr0(y);
        IF sym = S.upto THEN
          S.Get(sym); Expr0(z); Emitter.SetRange(y, z); y.type := x.type
        ELSE
          Emitter.Singleton(y); y.type := x.type
        END;
        Emitter.SetUnion(x, y)
      END
    END;
    IF sym = S.rbrace THEN S.Get(sym) ELSE S.Mark(E.expRbrace) END;
    Emitter.MaskSetConst(x)
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
    ELSIF (op = S.times) & ST.IsSetForm(x.type.form) THEN
      Factor(y);
      Emitter.SetInter(x, y)
    ELSIF (op = S.rdiv) & ST.IsSetForm(x.type.form) THEN
      Factor(y);
      Emitter.SetSymDiff(x, y)
    ELSIF x.type.form = ST.LongReal THEN
      Factor(y);
      IF y.type.form = ST.Real THEN Emitter.PromoteRealToLong(y) END;
      IF y.type.form # ST.LongReal THEN S.Mark(E.incompatible) END;
      IF (op = S.times) OR (op = S.rdiv) THEN
        Emitter.FMulOp(op, x, y)
      ELSE S.Mark(E.incompatible)
      END
    ELSIF x.type.form = ST.Real THEN
      Factor(y);
      IF y.type.form = ST.LongReal THEN
        Emitter.PromoteRealToLong(x);
        Emitter.FMulOp(op, x, y)
      ELSIF y.type.form # ST.Real THEN S.Mark(E.incompatible)
      ELSIF (op = S.times) OR (op = S.rdiv) THEN
        Emitter.FMulOp(op, x, y)
      ELSE S.Mark(E.incompatible)
      END
    ELSE (* sym = one of mul, div, mod *)
      Factor(y);
      IF ST.IsIntegerForm(x.type.form) THEN
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
    IF ST.IsSetForm(x.type.form) THEN Emitter.SetComplement(x)
    ELSIF ST.IsRealForm(x.type.form) THEN Emitter.FNegVal(x)
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
    ELSIF ST.IsSetForm(x.type.form) THEN
      Term(y);
      IF op = S.plus THEN Emitter.SetUnion(x, y)
      ELSE Emitter.SetDiff(x, y)
      END
    ELSIF x.type.form = ST.LongReal THEN
      Term(y);
      IF y.type.form = ST.Real THEN Emitter.PromoteRealToLong(y) END;
      IF y.type.form # ST.LongReal THEN S.Mark(E.incompatible) END;
      Emitter.FAddOp(op, x, y)
    ELSIF x.type.form = ST.Real THEN
      Term(y);
      IF y.type.form = ST.LongReal THEN
        Emitter.PromoteRealToLong(x);
        Emitter.FAddOp(op, x, y)
      ELSIF y.type.form # ST.Real THEN S.Mark(E.incompatible)
      ELSE Emitter.FAddOp(op, x, y)
      END
    ELSE (* sym = plus or minus *)
      Term(y);
      IF ST.IsIntegerForm(x.type.form) THEN
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
  rhsObj: ST.Object;
  rhsType, ptType, saved: ST.Type;
BEGIN
  SimpleExpr(x);
  IF sym = S.in THEN
    op := sym;
    S.Get(sym);
    SimpleExpr(y);
    Emitter.InSet(x, y);
    x.type := ST.boolType
  ELSIF sym = S.is THEN
    S.Get(sym);
    IF sym = S.ident THEN
      rhsObj := ST.ThisObject();
      IF rhsObj = NIL THEN S.Mark(E.undecl); rhsType := ST.intType
      ELSIF (rhsObj.class # ST.Typ) OR (rhsObj.type = NIL) THEN
        S.Mark(E.expType); rhsType := ST.intType
      ELSE rhsType := rhsObj.type
      END;
      S.Get(sym);
      IF (x.type # NIL) & (x.type.form = ST.Pointer) THEN
        ptType := x.type.base;
        IF (rhsType.form = ST.Pointer) & (rhsType.base # NIL)
            & (ptType # NIL) & ST.Extends(rhsType.base, ptType) THEN
          Emitter.IsTest(x, rhsType.base);
          x.type := ST.boolType
        ELSIF (rhsType.form = ST.Record) & (ptType # NIL)
            & ST.Extends(rhsType, ptType) THEN
          (* `p IS R` for Pointer p and Record R extending p's base. *)
          Emitter.IsTest(x, rhsType);
          x.type := ST.boolType
        ELSE
          S.Mark(E.incompatible); x.type := ST.boolType
        END
      ELSIF (x.type # NIL) & (x.type.form = ST.Record) THEN
        IF (rhsType.form = ST.Record) & ST.Extends(rhsType, x.type) THEN
          Emitter.IsTest(x, rhsType);
          x.type := ST.boolType
        ELSE
          S.Mark(E.incompatible); x.type := ST.boolType
        END
      ELSE
        S.Mark(E.incompatible); x.type := ST.boolType
      END
    ELSE S.Mark(E.expIdent); x.type := ST.boolType
    END
  ELSIF (S.eql <= sym) & (sym <= S.geq) THEN
    op := sym;
    S.Get(sym);
    saved := exprExpect;
    IF ST.IsSetForm(x.type.form) THEN exprExpect := x.type END;
    SimpleExpr(y);
    exprExpect := saved;
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
    ELSIF ((x.type.form = ST.Char) OR ST.IsIntegerForm(x.type.form) OR ST.IsSetForm(x.type.form))
        & ST.TypesCompatible(x.type, y.type) THEN
      Emitter.IntRel(op, x, y);
      x.type := ST.boolType
    ELSIF (x.type.form = ST.LongReal) & (y.type.form = ST.LongReal) THEN
      Emitter.FRel(op, x, y);
      x.type := ST.boolType
    ELSIF (x.type.form = ST.LongReal) & (y.type.form = ST.Real) THEN
      Emitter.PromoteRealToLong(y);
      Emitter.FRel(op, x, y);
      x.type := ST.boolType
    ELSIF (x.type.form = ST.Real) & (y.type.form = ST.LongReal) THEN
      Emitter.PromoteRealToLong(x);
      Emitter.FRel(op, x, y);
      x.type := ST.boolType
    ELSIF (x.type.form = ST.Real) & (y.type.form = ST.Real) THEN
      Emitter.FRel(op, x, y);
      x.type := ST.boolType
    ELSIF x.type.form = ST.Bool THEN
      IF op <= S.neq THEN Emitter.IntRel(op, x, y)
      ELSE S.Mark(E.onlyEqlNeq)
      END
    ELSIF (x.type.form = ST.Pointer) OR (y.type.form = ST.Pointer) THEN
      IF (op > S.neq) THEN
        S.Mark(E.onlyEqlNeq)
      ELSIF ~ST.TypesCompatible(x.type, y.type) THEN
        S.Mark(E.incompatible)
      ELSE
        Emitter.IntRel(op, x, y);
        x.type := ST.boolType
      END
    ELSIF (x.type.form = ST.Proc) OR (y.type.form = ST.Proc) THEN
      IF op > S.neq THEN
        S.Mark(E.onlyEqlNeq)
      ELSIF (x.type = ST.nilType) OR (y.type = ST.nilType) OR (x.type = y.type) THEN
        Emitter.IntRel(op, x, y);
        x.type := ST.boolType
      ELSE
        S.Mark(E.incompatible)
      END
    ELSE S.Mark(E.incompatible)
    END
  END
END Expr;

(** Assign = Designator ":=" Expr. *)
PROCEDURE Assign(obj: ST.Object);
VAR x, y: Emitter.Item;
  saved: ST.Type;
BEGIN
  Emitter.MakeItem(x, obj);
  saved := exprExpect;
  exprExpect := x.type;
  Expr(y);
  exprExpect := saved;
  Emitter.Assign(x, y)
END Assign;

(** AssignItem: assignment where left side is already an Item. *)
PROCEDURE AssignItem(VAR x: Emitter.Item);
VAR y: Emitter.Item;
  saved: ST.Type;
BEGIN
  Emitter.PreserveAddr(x);
  saved := exprExpect;
  exprExpect := x.type;
  Expr(y);
  exprExpect := saved;
  Emitter.Assign(x, y)
END AssignItem;

(** ProcedureCall = Designator [ActualParams]. *)
PROCEDURE ProcedureCall(obj: ST.Object);
VAR x: Emitter.Item;
  rx: INTEGER;
BEGIN
  IF ~SystemMemStmt(obj) THEN
  Emitter.MakeItem(x, obj);
  IF sym = S.lparen THEN (* With parameters *)
    IF x.type.form # ST.Proc THEN S.Mark(E.notProcedure)
    ELSE
      IF x.type.base.form # ST.NoTyp THEN S.Mark(E.notUsed) END;
      Emitter.PrepCall(x, rx); ActualParams(x);
      IF ~S.error THEN Emitter.Call(x, rx, obj)
      ELSE Emitter.FixRH(0)
      END
    END
  ELSIF x.type.form = ST.Proc THEN (* Procedure with no parameters *)
    IF x.type.nofpars > 0 THEN S.Mark(E.noParams) END;
    IF x.type.base.form # ST.NoTyp THEN S.Mark(E.notUsed)
    ELSE Emitter.PrepCall(x, rx); Emitter.Call(x, rx, obj)
    END
  ELSE S.Mark(E.expStatement)
  END
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

(** Records every exported parameter-less, no-result procedure as a
    candidate command, plus every exported procedure as a callable export.
    Called after the module body so that all proc.address values are
    finalized. *)
PROCEDURE EmitExportTable;
VAR p: ST.Object;
  pname: ARRAY 64 OF CHAR;
  isCmd: BOOLEAN;
BEGIN
  p := ST.topScope.next;
  WHILE p # ST.dummy DO
    IF p.exported & (p.class = ST.Const) & (p.type # NIL) & (p.type.form = ST.Proc)
        & ~p.external THEN
      ST.GetName(p.names, pname);
      isCmd := (p.type.nofpars = 0) & (p.type.base # NIL) & (p.type.base.form = ST.NoTyp);
      Generator.AddExport(pname, M.SHORT(p.address), isCmd)
    END;
    p := p.next
  END
END EmitExportTable;

(** Module = MODULE ident ";" [IMPORT ImportList] DeclSeq
             [BEGIN StatSeq] END ident ".". *)
PROCEDURE Module;
VAR nameStr: ARRAY 64 OF CHAR;
  i: INTEGER;
BEGIN
  varsize := 0;
  recordTypesN := 0;
  IF sym = S.module THEN
    S.Get(sym);
    IF sym = S.ident THEN
      modName := NIL;
      ST.SetName(modName, S.id);
      Emitter.SetModuleName(S.id);
      GetModName(nameStr);
      Generator.Open(nameStr);
      S.Get(sym);
      IF sym = S.semicol THEN S.Get(sym) ELSE S.Mark(E.expSemicol) END;
      ApplyModuleTranslations;

      IF sym = S.import THEN S.Get(sym); ImportList END;
      DeclSeq;
      (* Module init proc: prologue, RTTI setup, BEGIN body, epilogue. *)
      Generator.SetEntry(Generator.Here());
      Emitter.ModuleInitPrologue;
      FOR i := 0 TO recordTypesN - 1 DO
        Emitter.EmitRecordTypeDescInit(recordTypes[i])
      END;
      Emitter.EmitRecordVarTags(ST.topScope, FALSE);
      Emitter.EmitNilGlobals(ST.topScope);
      IF sym = S.begin THEN
        Emitter.SetProcName("");
        S.Get(sym);
        StatSeq
      END;

      IF sym = S.end THEN
        S.Get(sym);
        IF sym = S.ident THEN
          GetModName(nameStr);
          IF nameStr # S.id THEN S.Mark(E.modNameMismatch) END;
          S.Get(sym);
          IF sym = S.period THEN S.Get(sym) ELSE S.Mark(E.expPeriod) END;
          Emitter.ModuleInitEpilogue
        ELSE S.Mark(E.expIdent)
        END
      ELSE S.Mark(E.expEnd)
      END
    ELSE S.Mark(E.expIdent)
    END
  ELSE S.Mark(E.expModule)
  END;
  IF ~S.error THEN
    EmitExportTable;
    Generator.SetVarSize(varsize);
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

(** Forwarder so the driver (InterOberon.Mod) can register canonical
    module names with SymTable without importing it directly. Called
    once per discovered module before any module is compiled. *)
PROCEDURE RegisterCanonical*(name: ARRAY OF CHAR);
BEGIN ST.RegisterCanonical(name)
END RegisterCanonical;

PROCEDURE ResetCanonical*;
BEGIN ST.ResetCanonical
END ResetCanonical;

BEGIN
  Expr0 := Expr;
  SimpleExpr0 := SimpleExpr;
  StatSeq0 := StatSeq;
  Type0 := Type;
  FormalType0 := FormalType;
  LenIndexFactor0 := LenIndexFactor;
  LenIndexTerm0 := LenIndexTerm;
  LenIndexExpr0 := LenIndexExpr;
  allowOpenArrayParams := FALSE;
  pendingPtrs := NIL;
  inTypeSection := FALSE;
  inConstVarSection := FALSE;
  NEW(dummy); dummy.class := ST.Var; dummy.type := ST.intType
END Parser.
