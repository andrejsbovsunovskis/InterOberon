MODULE SymTable;
IMPORT Out, S := Scanner, E := ErrorMsg, Strings, L := Lang, M := Machine, Files, Utf8, SYSTEM;

CONST
  (** Object Classes **)
  Head*   = 0;
  Const*  = 1; (** User defined procedures also are constants *)
  Var*    = 2; (** Variables and value parameters *)
  VarPar* = 3; (** VAR-parameters *)
  Fld*    = 4; (** Record field; address is byte offset within record *)
  Typ*    = 5;
  SProc*  = 6; (** Standard procedure *)
  SFunc*  = 7; (** Standard functional procedure *)
  Mod*    = 8;

  (** Type Forms **)
  Bool*     = 2;
  Char*     = 3;
  Int*      = 4;
  Set*      = 5;
  Byte*     = 6;
  Real*     = 7;
  Pointer*  = 8;
  NoTyp*    = 9;
  Proc*     = 10;
  ShortInt* = 11;
  LongInt*  = 12;
  LongSet*  = 13;
  TinyInt*  = 18;
  TinySet*  = 19;
  ShortSet* = 20;
  LongReal* = 17;
  Array*    = 14;
  Record*   = 15;
  String*   = 16; (** String literals and CONST only; not a user-declarable type *)

  (** .sym format mark and serialization tags for composite types. *)
  symVersion = 1;
  symFileMark* = ORD('S') + 256 * (ORD('Y') + 256 * (ORD('M') + 256 * symVersion));
  tcArray   = -10;
  tcProc    = -11;
  tcRecord  = -12;
  tcString  = -13;
  tcNil     = -14;
  tcPointer = -15;
  tcTypeRef = -16; (** Reference into the .sym type table by index *)

TYPE
  LONGINT = M.LONGINT;
  LONGREAL = M.LONGREAL;

  Object* = POINTER TO ObjectDesc;
  Type* = POINTER TO TypeDesc;
  Name* = POINTER TO NameDesc;
  Lang* = POINTER TO LangDesc;

  NameDesc* = RECORD
    str*: ARRAY 64 OF CHAR;
    lang*: ARRAY 6 OF CHAR;
    next: Name
  END;

  LangDesc* = RECORD
    code*: ARRAY 6 OF CHAR;
    next: Lang
  END;

  StringEntry* = POINTER TO StringEntryDesc;
  StringEntryDesc* = RECORD
    bytes*: ARRAY 256 OF CHAR;
    nChars*: INTEGER; (** CHAR count including final 0X *)
    next*: StringEntry
  END;

  ObjectDesc* = RECORD
    names*: Name;
    exported*: BOOLEAN;
    class*: INTEGER; (** See Object Classes *)
    dsc*: Object;
    next*: Object;
    type*: Type;
    lev*: INTEGER; (** Scope level: 0 - global, > 0 - local *)
    address*: LONGINT; (** Address for variables, number for standard procedures *)
    (** class = Const: integers, pool index (String), SET/LONGSET bits, proc offset — all in intVal. *)
    intVal*: LONGINT;
    realVal*: LONGREAL;
    readOnly*: BOOLEAN; (** non-VAR array params and imported variables *)
    procResolved*: BOOLEAN; (** TRUE once final entry address is recorded *)
    fixupList*: INTEGER; (** Only for procedures. Word position of last unpatched BL, 0 = empty *)
    external*: BOOLEAN; (** TRUE for objects imported from another user module *)
    importIdx*: INTEGER (** Index into module's imports list for external procedures *)
  END;

  TypeDesc* = RECORD
    form*: INTEGER;
    len*: INTEGER; (** Array length; nofpars for Proc *)
    openRank*: INTEGER; (** Number of open array dimensions *)
    nofpars*: INTEGER;
    dsc*: Object;
    base*: Type;
    size*: INTEGER; (** In bytes *)
    extLevel*: INTEGER; (** RECORD: 0 for root, base.extLevel + 1 for extensions *)
    descOffset*: INTEGER; (** Byte offset of this RECORD's TypeDesc inside the
        owning module's __DATA segment, or -1 if no descriptor was reserved
        (non-record types, or imported records without local RTTI). *)
    descModule*: INTEGER; (** Index of the module whose __DATA holds the
        TypeDesc at descOffset; -1 = current compilation unit. *)
    declNames*: Name; (** RECORD type id from TYPE decl or POINTER TO resolve *)
    declExported*: BOOLEAN
  END;

  LangBuf* = ARRAY 16, 6 OF CHAR;

  CanonicalReg* = POINTER TO CanonicalRegDesc;
  CanonicalRegDesc* = RECORD
    name*: ARRAY 64 OF CHAR;
    next*: CanonicalReg
  END;

VAR
  topScope*: Object;
  dummy*: Object;
  curLev*: INTEGER; (** Current scope level: 0 = module, > 0 = procedure *)

  (** Standard Types **)
  boolType*, charType*, intType*, setType*, byteType*, realType*, longRealType*, noType*: Type;
  tinyIntType*, shortIntType*, longIntType*: Type;
  tinySetType*, shortSetType*, longSetType*: Type;
  (** Singleton type of the NIL literal.  form = Pointer, base = NIL,
      size = 8.  Compatible (assignable into and comparable with) every
      POINTER type; never serialised — when an exported type contains
      NIL slots they encode as tcNil and decode back to NIL. *)
  nilType*: Type;
  (** SYSTEM.ADRINT -- platform-sized signed integer used for addresses.
      Identical to longIntType in `form` (so it freely mixes with
      LONGINT in expressions, assignments and parameter passing on
      64-bit targets), but a *different* Type object so that LONG/SHORT
      can recognise it and produce platform-stable results: LONG on
      ADRINT always yields LONGINT, SHORT on ADRINT always yields
      INTEGER -- regardless of word size. *)
  adrIntType*: Type;

  (** Runtime string pool for literals (dedup by content); index for relocations *)
  strPool*: StringEntry;
  nofPoolStrings*: INTEGER;

  (** - **)
  langs: Lang;

  (** Type table for .sym serialisation.  Built fresh per ExportModule
      pass over CollectTypes; cleared again right after.  Holds the
      Pointer/Record types reachable from the exported objects in the
      order they were first discovered.  Any type encountered during
      serialisation that is in the table is written as `tcTypeRef <idx>`
      instead of inlined, which is what makes self-recursive
      `POINTER TO Self`-style structures expressible at all. *)
  typeTable: ARRAY 256 OF Type;
  typeTableN: INTEGER;

  (** Mirror used during ImportSymFile: the N type slots are pre-NEW'd
      in the first pass so that during the second pass tcTypeRef can
      hand back a valid Type pointer even before that slot is filled. *)
  importTable: ARRAY 256 OF Type;
  importTableN: INTEGER;

  (** Indirection for the mutual recursion between ReadType and
      ReadTypeInto.  Wired up to ReadType at module init. *)
  readType: PROCEDURE(VAR R: Files.Rider; VAR T: Type;
    VAR codes: LangBuf; nLangs: INTEGER): BOOLEAN;

  (** Canonical module names known to be present in M.outDir as
      <name>.sym / <name>.obj files.  Populated by the build driver
      during Discover so that ResolveCanonical can answer "what
      canonical name does this localised import resolve to?" without
      relying on directory listing. *)
  canonRegs: CanonicalReg;

PROCEDURE SetNameLang*(VAR names: Name; langCode, str: ARRAY OF CHAR);
VAR n, p: Name;
BEGIN
  (* If we already have an entry for langCode, update it in place — keeps
     the list compact and avoids duplicate language tags when (a) NewObject
     pre-seeds the curLang entry and (b) ImportSymFile then layers on the
     full per-language name set read from the .sym file. *)
  p := names;
  WHILE (p # NIL) & (p.lang # langCode) DO p := p.next END;
  IF p # NIL THEN
    Strings.Copy(str, p.str)
  ELSE
    NEW(n);
    Strings.Copy(langCode, n.lang);
    Strings.Copy(str, n.str);
    p := names;
    IF p # NIL THEN
      WHILE p.next # NIL DO p := p.next END;
      p.next := n
    ELSE
      names := n
    END
  END
END SetNameLang;

PROCEDURE SetName*(VAR names: Name; str: ARRAY OF CHAR);
BEGIN
  SetNameLang(names, L.curLang, str)
END SetName;

PROCEDURE GetNameLang*(names: Name; langCode: ARRAY OF CHAR; VAR str: ARRAY OF CHAR);
VAR p: Name;
BEGIN
  IF names = NIL THEN
    str := ''
  ELSE
    p := names;
    WHILE (p # NIL) & (p.lang # langCode) DO p := p.next END;
    IF p # NIL THEN
      Strings.Copy(p.str, str)
    ELSE
      str := '' (*!TODO: Handle missing name *)
    END
  END
END GetNameLang;

PROCEDURE GetName*(names: Name; VAR str: ARRAY OF CHAR);
BEGIN
  IF names = NIL THEN
    str := ''
  ELSE
    Strings.Copy(names.str, str)
  END
END GetName;

PROCEDURE DeclNamesEmpty*(names: Name): BOOLEAN;
VAR s: ARRAY 64 OF CHAR;
  empty: BOOLEAN;
BEGIN
  IF names = NIL THEN empty := TRUE
  ELSE
    GetName(names, s);
    empty := s = ''
  END
RETURN empty END DeclNamesEmpty;

PROCEDURE CopyDeclNames*(src: Name; VAR dst: Name);
VAR p: Name;
BEGIN
  p := src;
  WHILE p # NIL DO
    SetNameLang(dst, p.lang, p.str);
    p := p.next
  END
END CopyDeclNames;

(** Attach typ-object id and export flag to a record type. *)
PROCEDURE BindDecl*(T: Type; obj: Object);
BEGIN
  IF (T # NIL) & (T.form = Record) & (obj # NIL) THEN
    CopyDeclNames(obj.names, T.declNames);
    T.declExported := obj.exported
  END
END BindDecl;

PROCEDURE BindDeclIfEmpty*(T: Type; obj: Object);
BEGIN
  IF (T # NIL) & DeclNamesEmpty(T.declNames) THEN BindDecl(T, obj) END
END BindDeclIfEmpty;

(** Returns TRUE iff any language-specific form of `names` equals `s`.
    Used by lookups (ThisObject, ThisImport, NewObject) so that an
    identifier written in the current source language matches an entry
    declared in any other language via per-module translation comments
    (or imported from a .sym file that registered multiple names). *)
PROCEDURE NameMatches*(names: Name; s: ARRAY OF CHAR): BOOLEAN;
VAR p: Name;
    ok: BOOLEAN;
BEGIN
  ok := FALSE;
  p := names;
  WHILE (p # NIL) & ~ok DO
    IF p.str = s THEN ok := TRUE END;
    p := p.next
  END
RETURN ok END NameMatches;

(** Returns TRUE iff `s` equals the identifier form for the current source
    language.  Translation names for other languages are metadata only and
    must not resolve in the same module text. *)
PROCEDURE NameInCurrentLang*(names: Name; s: ARRAY OF CHAR): BOOLEAN;
VAR cur: ARRAY 64 OF CHAR;
BEGIN
  GetNameLang(names, L.curLang, cur);
  IF cur = '' THEN GetName(names, cur) END
RETURN cur = s END NameInCurrentLang;

PROCEDURE InitUniverse;
VAR U: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  U := topScope;
  NEW(U.next);
  U := U.next;
  L.FindUniObj('BOOLEAN', s); SetName(U.names, s);
  U.class := Typ;
  U.type := boolType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('CHAR', s); SetName(U.names, s);
  U.class := Typ;
  U.type := charType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('INTEGER', s); SetName(U.names, s);
  U.class := Typ;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('SET', s); SetName(U.names, s);
  U.class := Typ;
  U.type := setType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ORD', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 31;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('BITS', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 52;
  U.type := setType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('CHR', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 32;
  U.type := charType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ABS', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 33;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ODD', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 34;
  U.type := boolType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ASR', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 35;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LSL', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 36;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ROR', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 37;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('INC', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 41;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('DEC', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 42;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('INCL', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 43;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('EXCL', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 44;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('BYTE', s); SetName(U.names, s);
  U.class := Typ;
  U.type := byteType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('TINYINT', s); SetName(U.names, s);
  U.class := Typ;
  U.type := tinyIntType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('TINYSET', s); SetName(U.names, s);
  U.class := Typ;
  U.type := tinySetType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('SHORTSET', s); SetName(U.names, s);
  U.class := Typ;
  U.type := shortSetType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('REAL', s); SetName(U.names, s);
  U.class := Typ;
  U.type := realType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LONGREAL', s); SetName(U.names, s);
  U.class := Typ;
  U.type := longRealType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('FLOOR', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 38;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('FLT', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 39;
  U.type := realType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ENTIER', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 50;
  U.type := longIntType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LONGFLT', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 51;
  U.type := longRealType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('SHORTINT', s); SetName(U.names, s);
  U.class := Typ;
  U.type := shortIntType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LONGINT', s); SetName(U.names, s);
  U.class := Typ;
  U.type := longIntType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LONGSET', s); SetName(U.names, s);
  U.class := Typ;
  U.type := longSetType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LEN', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 40;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('SHORT', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 45;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LONG', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 46;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('NEW', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 48;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ASSERT', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 49;
  U.type := noType;

  U.next := dummy
END InitUniverse;

PROCEDURE OpenScope*;
VAR p: Object;
BEGIN
  p := topScope;
  NEW(topScope);
  topScope.dsc := p;
  topScope.class := Head;

  (* Remove dummy from previous top scope *)
  IF p # NIL THEN
    WHILE p.next # dummy DO p := p.next END;
    p.next := NIL
  END;

  topScope.next := dummy
END OpenScope;

PROCEDURE CloseScope*;
VAR p: Object;
BEGIN
  topScope := topScope.dsc;
  p := topScope;
  WHILE p.next # NIL DO p := p.next END;
  p.next := dummy
END CloseScope;

PROCEDURE IncLev*;
BEGIN INC(curLev)
END IncLev;

PROCEDURE DecLev*;
BEGIN DEC(curLev)
END DecLev;

(** Returns TRUE if t1 and t2 can appear together in a comparison (symmetric, no narrowing check).
    For RECORD types, only identity (same Type pointer) makes them compatible — Oberon-07
    is nominal, not structural.
    For POINTER types, identity OR involvement of nilType (base = NIL) makes them
    compatible.  This covers `p1 = p2` and `p = NIL`. *)
PROCEDURE Extends*(t1, t2: Type): BOOLEAN;
VAR p: Type; ok: BOOLEAN;
BEGIN
  ok := FALSE;
  IF (t1 # NIL) & (t2 # NIL) & (t1.form = Record) & (t2.form = Record) THEN
    IF t1 = t2 THEN ok := TRUE
    ELSE
      p := t1;
      WHILE (p # NIL) & (p # t2) DO p := p.base END;
      IF p = t2 THEN ok := TRUE END
    END
  END
RETURN ok END Extends;

(** Walk T's base-chain until extLevel = level.  Returns NIL if T is not
    a Record or `level` is out of range. *)
PROCEDURE AncestorAt*(T: Type; level: INTEGER): Type;
BEGIN
  IF (T # NIL) & (T.form = Record) THEN
    WHILE (T # NIL) & (T.extLevel > level) DO T := T.base END;
    IF (T = NIL) OR (T.extLevel # level) THEN T := NIL END
  ELSE T := NIL
  END
RETURN T END AncestorAt;

PROCEDURE IntegerRank*(f: INTEGER): INTEGER;
VAR r: INTEGER;
BEGIN
  IF    f = TinyInt  THEN r := 0
  ELSIF f = ShortInt THEN r := 1
  ELSIF f = Int      THEN r := 2
  ELSIF f = LongInt  THEN r := 3
  ELSE r := -1
  END
RETURN r END IntegerRank;

PROCEDURE SetRank*(f: INTEGER): INTEGER;
VAR r: INTEGER;
BEGIN
  IF    f = TinySet  THEN r := 0
  ELSIF f = ShortSet THEN r := 1
  ELSIF f = Set      THEN r := 2
  ELSIF f = LongSet  THEN r := 3
  ELSE r := -1
  END
RETURN r END SetRank;

PROCEDURE IntegerTypeAtRank*(rank: INTEGER): Type;
VAR T: Type;
BEGIN
  IF    rank = 0 THEN T := tinyIntType
  ELSIF rank = 1 THEN T := shortIntType
  ELSIF rank = 2 THEN T := intType
  ELSIF rank = 3 THEN T := longIntType
  ELSE T := NIL
  END
RETURN T END IntegerTypeAtRank;

PROCEDURE SetTypeAtRank*(rank: INTEGER): Type;
VAR T: Type;
BEGIN
  IF    rank = 0 THEN T := tinySetType
  ELSIF rank = 1 THEN T := shortSetType
  ELSIF rank = 2 THEN T := setType
  ELSIF rank = 3 THEN T := longSetType
  ELSE T := NIL
  END
RETURN T END SetTypeAtRank;

PROCEDURE IsIntegerForm*(f: INTEGER): BOOLEAN;
RETURN (IntegerRank(f) >= 0) OR (f = Byte) END IsIntegerForm;

PROCEDURE IsSetForm*(f: INTEGER): BOOLEAN;
RETURN SetRank(f) >= 0 END IsSetForm;

PROCEDURE IsElementaryForm*(f: INTEGER): BOOLEAN;
RETURN (f = 2) OR (f = 3) OR (f = 6) OR (f = 7) OR (f = 17)
  OR IsIntegerForm(f) OR IsSetForm(f) END IsElementaryForm;

PROCEDURE IsAddressType*(t: Type): BOOLEAN;
RETURN (t = intType) OR (t = longIntType) OR (t = adrIntType) END IsAddressType;

PROCEDURE ProcCompatible(t1, t2: Type): BOOLEAN;
VAR p1, p2: Object;
  ok: BOOLEAN;
BEGIN
  IF (t1 = NIL) OR (t2 = NIL) OR (t1.form # Proc) OR (t2.form # Proc) THEN ok := FALSE
  ELSIF (t1.nofpars # t2.nofpars) OR (t1.base # t2.base) THEN ok := FALSE
  ELSE
    ok := TRUE;
    p1 := t1.dsc; p2 := t2.dsc;
    WHILE ok & (p1 # NIL) & (p1 # dummy) DO
      IF (p2 = NIL) OR (p2 = dummy) THEN ok := FALSE
      ELSIF (p1.class # p2.class) OR (p1.type # p2.type) THEN ok := FALSE
      ELSE p1 := p1.next; p2 := p2.next
      END
    END;
    IF ok & ((p1 # dummy) OR (p2 # dummy)) THEN ok := FALSE END
  END
RETURN ok END ProcCompatible;

PROCEDURE TypesCompatible*(t1, t2: Type): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  IF (t1.form = Record) OR (t2.form = Record) THEN
    ok := t1 = t2
  ELSIF (t1.form = Pointer) OR (t2.form = Pointer) THEN
    ok := (t1 = t2) OR (t1 = nilType) OR (t2 = nilType)
       OR (t1.form = Pointer) & (t2.form = Pointer)
                     & ((t1.base = NIL) OR (t2.base = NIL)
                        OR Extends(t1.base, t2.base)
                        OR Extends(t2.base, t1.base))
  ELSIF (t1.form = Proc) OR (t2.form = Proc) THEN
    ok := (t1 = t2) OR (t1 = nilType) OR (t2 = nilType)
       OR (t1.form = Proc) & (t2.form = Proc) & ProcCompatible(t1, t2)
  ELSE
    ok := (t1.form = t2.form)
       OR (IntegerRank(t1.form) >= 0) & (IntegerRank(t2.form) >= 0)
       OR (t1.form = Byte) & (IntegerRank(t2.form) >= 0)
       OR (IntegerRank(t1.form) >= 0) & (t2.form = Byte)
       OR (SetRank(t1.form) >= 0) & (SetRank(t2.form) >= 0)
  END
RETURN ok END TypesCompatible;

(** Returns TRUE when actual type act may be passed to a VAR formal of
    type formal.  Scalars require identity; open arrays keep structural
    rules; RECORD and POINTER allow extension. *)
PROCEDURE VarActualCompatible*(formal, act: Type): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  IF formal = act THEN ok := TRUE
  ELSIF formal = NIL THEN ok := FALSE
  ELSIF act = NIL THEN ok := FALSE
  ELSIF (formal.form = Array) & ((formal.openRank > 0) OR (formal.len = 0)) THEN
    ok := TypesCompatible(formal, act)
  ELSIF formal.form = Record THEN
    ok := (act.form = Record) & ((act = formal) OR Extends(act, formal))
  ELSIF (formal.form = Pointer) & (act.form = Pointer) THEN
    ok := (act = formal)
       OR (act.base # NIL) & (formal.base # NIL) & Extends(act.base, formal.base)
  ELSE
    ok := FALSE
  END
RETURN ok END VarActualCompatible;

(** Returns TRUE if src is assignable to dst without explicit narrowing.
    Rules:
      BYTE <-> all integer types  (bidirectional special case).
      TinyInt <= ShortInt <= Int <= LongInt  (widening only).
      TinySet <= ShortSet <= Set <= LongSet  (widening only).
      RECORD:  identity only (nominal typing).
      POINTER: identity OR src is NIL (nilType has base = NIL). *)
PROCEDURE TypeAssignable*(dst, src: Type): BOOLEAN;
VAR df, sf, dr, sr: INTEGER;
  ok: BOOLEAN;
BEGIN
  df := dst.form; sf := src.form;
  IF (df = Record) OR (sf = Record) THEN
    ok := dst = src
  ELSIF (df = Pointer) OR (sf = Pointer) THEN
    ok := (dst = src)
       OR (df = Pointer) & (sf = Pointer)
            & ((src.base = NIL) OR Extends(src.base, dst.base))
  ELSIF (df = Proc) & (sf = Proc) THEN
    ok := ProcCompatible(dst, src)
  ELSE
    dr := IntegerRank(df); sr := IntegerRank(sf);
    ok := (df = sf)
      OR (df = Byte) & ((sf = Byte) OR (sr >= 0))
      OR (sf = Byte) & ((df = Byte) OR (dr >= 0))
      OR (dr >= 0) & (sr >= 0) & (dr >= sr)
      OR (SetRank(df) >= 0) & (SetRank(sf) >= 0) & (SetRank(df) >= SetRank(sf))
      OR (df = LongReal) & (sf = Real)
  END
RETURN ok END TypeAssignable;

(** Assignment without explicit VAL/SHORT: widening rules, plus const
    compatibility for integer/byte mixes; set constants may not narrow. *)
PROCEDURE AssignCompatible*(dst, src: Type; srcConst: BOOLEAN): BOOLEAN;
VAR dr, sr, dsr, ssr: INTEGER;
  ok: BOOLEAN;
BEGIN
  IF TypeAssignable(dst, src) THEN ok := TRUE
  ELSIF srcConst & TypesCompatible(dst, src) THEN
    dsr := SetRank(dst.form); ssr := SetRank(src.form);
    IF (dsr >= 0) & (ssr >= 0) THEN ok := dsr >= ssr
    ELSE ok := TRUE
    END
  ELSE ok := FALSE
  END
RETURN ok END AssignCompatible;

PROCEDURE IsRealForm*(f: INTEGER): BOOLEAN;
RETURN f IN {Real, LongReal} END IsRealForm;

(** TRUE when SYSTEM.VAL(dst, src) is allowed. *)
PROCEDURE ValCompatible*(dst, src: Type): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  IF IsIntegerForm(dst.form) & IsIntegerForm(src.form) THEN ok := TRUE
  ELSIF IsSetForm(dst.form) & IsSetForm(src.form) THEN ok := TRUE
  ELSIF dst = src THEN ok := TRUE
  ELSIF TypesCompatible(dst, src) THEN ok := TRUE
  ELSIF (dst.form = Real) & IsIntegerForm(src.form) THEN ok := TRUE
  ELSIF IsIntegerForm(dst.form) & (src.form = Real) THEN ok := TRUE
  ELSIF (dst.form = LongReal) & IsIntegerForm(src.form) THEN ok := TRUE
  ELSIF IsIntegerForm(dst.form) & (src.form = LongReal) THEN ok := TRUE
  ELSIF (dst.form = LongReal) & (src.form = Real) THEN ok := TRUE
  ELSIF (dst.form = Real) & (src.form = LongReal) THEN ok := TRUE
  ELSIF (dst.form = Char) & IsIntegerForm(src.form) THEN ok := TRUE
  ELSIF (dst.form = Int) & (src.form = Char) THEN ok := TRUE
  ELSIF IsSetForm(dst.form) & IsIntegerForm(src.form) THEN ok := TRUE
  ELSIF IsIntegerForm(dst.form) & IsSetForm(src.form) THEN ok := TRUE
  ELSE ok := FALSE
  END
RETURN ok END ValCompatible;

PROCEDURE ThisObject*(): Object;
VAR scope, p: Object;
    found: BOOLEAN;
BEGIN
  scope := topScope;
  found := FALSE;
  REPEAT
    p := scope.next;
    WHILE (p.next # NIL) & ~NameInCurrentLang(p.names, S.id) DO p := p.next END;
    IF NameInCurrentLang(p.names, S.id) THEN found := TRUE
    ELSE scope := scope.dsc
    END
  UNTIL (scope = NIL) OR found;
  IF ~found THEN p := NIL END
RETURN p END ThisObject;

(** Like ThisObject, but searches by an arbitrary name buffer instead of
    Scanner.id.  Used by the parser to resolve pending POINTER TO X
    fixups at the end of a TYPE section without disturbing the scanner
    state. *)
PROCEDURE ThisObjectByName*(name: ARRAY OF CHAR): Object;
VAR scope, p: Object;
    found: BOOLEAN;
BEGIN
  scope := topScope;
  found := FALSE;
  REPEAT
    p := scope.next;
    WHILE (p.next # NIL) & ~NameInCurrentLang(p.names, name) DO p := p.next END;
    IF NameInCurrentLang(p.names, name) THEN found := TRUE
    ELSE scope := scope.dsc
    END
  UNTIL (scope = NIL) OR found;
  IF ~found THEN p := NIL END
RETURN p END ThisObjectByName;

PROCEDURE ThisImport*(M: Object): Object;
VAR p: Object;
BEGIN
  p := M.dsc;
  WHILE (p # NIL) & ~NameMatches(p.names, S.id) DO p := p.next END
RETURN p END ThisImport;

(** Lookup imported object by Const address (e.g. SYSTEM.DIV when DIV is a keyword). *)
PROCEDURE ImportByAddress*(M: Object; adr: INTEGER): Object;
VAR p: Object;
BEGIN
  p := M.dsc;
  WHILE (p # NIL) & (p.intVal # adr) DO p := p.next END
RETURN p END ImportByAddress;

(** Walk the field list of record type T looking for an entry whose name
    matches Scanner.id.  Returns NIL if not found.  Stops at dummy
    sentinel which terminates a record's field chain. *)
PROCEDURE ThisField*(T: Type): Object;
VAR p: Object;
BEGIN
  p := NIL;
  WHILE (T # NIL) & (T.form = Record) & (p = NIL) DO
    p := T.dsc;
    WHILE (p # NIL) & (p # dummy) & ~NameInCurrentLang(p.names, S.id) DO p := p.next END;
    IF (p = NIL) OR (p = dummy) THEN
      p := NIL;
      T := T.base
    END
  END
RETURN p END ThisField;

(** Maximum byte alignment required by type T.
    For scalars: equals T.size.
    For arrays:  equals alignment of innermost element type.
    For records: equals max alignment over all fields (1 for empty record). *)
PROCEDURE Alignment*(T: Type): INTEGER;
VAR a, fa: INTEGER;
  field: Object;
BEGIN
  WHILE T.form = Array DO T := T.base END;
  IF T.form = Record THEN
    a := 1;
    field := T.dsc;
    WHILE (field # NIL) & (field # dummy) DO
      fa := Alignment(field.type);
      IF fa > a THEN a := fa END;
      field := field.next
    END
  ELSE
    a := T.size
  END
RETURN a END Alignment;

(** Lay out the fields of record type T (T.dsc must already be a chain
    of Fld objects terminated by dummy).  Assigns each field's `address`
    as its byte offset from the start of the record, and sets T.size to
    the total record size rounded up to T's natural alignment.  Honors
    record extension: own fields start past the base record's size, so
    a base-typed pointer can read inherited fields at the same offsets
    as in a non-extended view. *)
PROCEDURE RecordLayout*(T: Type);
VAR field: Object;
  off, fa, maxA: INTEGER;
BEGIN
  IF (T.base # NIL) & (T.base.form = Record) THEN
    off := T.base.size - 8 (* continue after base body; base.size includes tag *)
  ELSE
    off := 0 (* field offsets are body-relative; tag is below body at body-8 *)
  END;
  maxA := 1;
  field := T.dsc;
  WHILE (field # NIL) & (field # dummy) DO
    fa := Alignment(field.type);
    IF fa > maxA THEN maxA := fa END;
    IF fa > 1 THEN off := (off + fa - 1) DIV fa * fa END;
    field.address := off;
    off := off + field.type.size;
    field := field.next
  END;
  IF maxA > 1 THEN off := (off + maxA - 1) DIV maxA * maxA END;
  T.size := off + 8 (* 8-byte type tag before body *)
END RecordLayout;

PROCEDURE NewObject*(class: INTEGER; name: ARRAY OF CHAR): Object;
VAR p: Object;
BEGIN
  SetName(dummy.names, name);

  p := topScope;
  WHILE ~NameInCurrentLang(p.next.names, name) DO p := p.next END;

  IF p.next = dummy THEN
    NEW(p.next);
    p := p.next;
    p.next := dummy;
    p.class := class;
    p.exported := FALSE;
    p.lev := curLev;
    p.names := NIL;
    p.procResolved := FALSE;
    p.fixupList := 0;
    SetName(p.names, name);
    dummy.names := NIL
  ELSE S.Mark(E.multipleDecl); p := p.next
  END
RETURN p END NewObject;

(** Declares built-in SYSTEM module with the minimal low-level primitives.
    SYSTEM intentionally stays OS-agnostic: it only exposes
      SYSTEM.SVC(n [, a0 [, a1 .. a5]]): LONGINT  -- Const proc, id -100
      SYSTEM.VAL(T, expr)                          -- Const proc, id -101
      SYSTEM.BIT(a, n): BOOLEAN                    -- Const proc, id -102
      SYSTEM.GET(a, v)                               -- Const proc, id -103
      SYSTEM.PUT(a, x)                               -- Const proc, id -104
      SYSTEM.COPY(src, dst, n)                       -- Const proc, id -105
      SYSTEM.ADC(m, n): INTEGER                      -- Const proc, id -106
      SYSTEM.SBC(m, n): INTEGER                      -- Const proc, id -107
      SYSTEM.UML(m, n): INTEGER                      -- Const proc, id -108
      SYSTEM.COND(n): BOOLEAN                        -- Const proc, id -109
      SYSTEM.DIV(m, n): INTEGER                      -- Const proc, id -110, trunc toward 0
      SYSTEM.MOD(m, n): INTEGER                      -- Const proc, id -111, trunc toward 0
      SYSTEM.PACK(VAR x: REAL; n: INTEGER)         -- Const proc, id -112, x := x * 2^n
      SYSTEM.UNPK(VAR x: REAL; VAR n: INTEGER)     -- Const proc, id -113, normalize x, n := exp
      SYSTEM.ADR(designator): ADRINT               -- SFunc id 47, polymorphic
      SYSTEM.ADRINT                                -- platform-sized integer
    SVC accepts 1..7 LONGINT actuals (syscall number plus up to six args).
    Parser.ActualParams treats arity specially (like INC's optional 2nd arg).
    Codegen moves x0 -> x16 and shifts remaining registers down, then SVC #0
    (Darwin ARM64 ABI).  ADR is a SFunc rather than an ordinary procedure.
    All higher-level OS abstractions live in Lib/Platform.Mod.
    num is the Lang-internal index of module M (the localized 'SYSTEM'). *)
PROCEDURE ImportSystem*(M: Object; num: INTEGER);
VAR p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  (* SYSTEM.SVC -- variable arity 1..7; type lists max formals for tools *)
  NEW(M.dsc); M := M.dsc;
  M.class := Const; M.address := -100; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'SVC', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 7; M.type.base := longIntType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'n'); p.type := longIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'a0'); p.type := longIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'a1'); p.type := longIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'a2'); p.type := longIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'a3'); p.type := longIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'a4'); p.type := longIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'a5'); p.type := longIntType;

  (* SYSTEM.VAL(T, x) -- Parser.ValCall; first actual is a type *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -101; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'VAL', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := noType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Typ; SetName(p.names, 'T');
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'x');

  (* SYSTEM.BIT(a, n) -- Parser.SystemBitCall *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -102; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'BIT', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := boolType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'a'); p.type := adrIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.GET(a, v) -- Parser.SystemGetCall; v is elementary VAR *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -103; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'GET', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := noType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'a'); p.type := adrIntType;
  NEW(p.next); p := p.next;
  p.class := VarPar; SetName(p.names, 'v');

  (* SYSTEM.PUT(a, x) -- Parser.SystemPutCall; x is elementary *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -104; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'PUT', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := noType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'a'); p.type := adrIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'x');

  (* SYSTEM.COPY(src, dst, n) -- overlap-safe memmove; n bytes *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -105; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'COPY', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 3; M.type.base := noType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'src'); p.type := adrIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'dst'); p.type := adrIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.ADC(m, n) -- Parser.SystemInt2Call *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -106; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'ADC', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := intType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'm'); p.type := intType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.SBC(m, n) *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -107; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'SBC', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := intType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'm'); p.type := intType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.UML(m, n) *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -108; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'UML', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := intType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'm'); p.type := intType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.COND(n) *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -109; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'COND', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := boolType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.DIV(m, n) -- truncating divide (SDIV), unlike Oberon DIV *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -110; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'DIV', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := intType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'm'); p.type := intType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.MOD(m, n) -- truncating remainder, unlike Oberon MOD *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -111; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'MOD', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := intType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'm'); p.type := intType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.PACK(x, n) -- Parser.SystemPackCall *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -112; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'PACK', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := noType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := VarPar; SetName(p.names, 'x'); p.type := realType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.UNPK(x, n) -- Parser.SystemUnpkCall *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -113; M.intVal := M.address;
  M.procResolved := TRUE;
  L.FindModObj(num, 'UNPK', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := noType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := VarPar; SetName(p.names, 'x'); p.type := realType;
  NEW(p.next); p := p.next;
  p.class := VarPar; SetName(p.names, 'n'); p.type := intType;

  (* SYSTEM.ADR -- polymorphic, handled by Parser.StandFunc(47) *)
  NEW(M.next); M := M.next;
  M.class := SFunc; M.address := 47;
  L.FindModObj(num, 'ADR', s); SetName(M.names, s);
  M.type := adrIntType;

  (* SYSTEM.ADRINT -- platform-sized integer type for addresses. *)
  NEW(M.next); M := M.next;
  M.class := Typ;
  L.FindModObj(num, 'ADRINT', s); SetName(M.names, s);
  M.type := adrIntType
END ImportSystem;

PROCEDURE PrintIndent(n: INTEGER);
BEGIN WHILE n > 0 DO Out.String('  '); DEC(n) END
END PrintIndent;

PROCEDURE Debug*(scope: Object; indent: INTEGER);
VAR p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  WHILE scope # NIL DO
    p := scope;
    WHILE p # NIL DO
      PrintIndent(indent);
      IF p = dummy THEN Out.String('Dummy')
      ELSIF p.class = Head THEN Out.String('Header')
      ELSIF p.class = Var THEN
        GetName(p.names, s);
        Out.String('Variable "'); Out.String(s);
        Out.String('" of type with form '); Out.Int(p.type.form, 0);
        Out.String(' at address '); Out.Int(M.SHORT(p.address), 0)
      ELSIF p.class = Typ THEN
        GetName(p.names, s);
        Out.String('Type "'); Out.String(s);
        Out.String('", refers to type with form ');
        Out.Int(p.type.form, 0)
      ELSIF p.class = Const THEN
        GetName(p.names, s);
        Out.String('Constant "'); Out.String(s);
        Out.String('"');
        IF p.type.form = Proc THEN Out.String(' of procedure type with ');
          Out.Int(p.type.nofpars, 0); Out.String(' parameters'); Out.Ln;
          Debug(p.type.dsc, indent + 1)
        ELSE Out.String(' of type with form'); Out.Int(p.type.form, 0)
        END
      ELSIF p.class = Mod THEN
        GetName(p.names, s);
        Out.String('Module "'); Out.String(s);
        Out.String('":'); Out.Ln; Debug(p.dsc, indent + 1)
      ELSE Out.String('Unknown object')
      END;
      Out.Ln;
      p := p.next
    END;
    scope := scope.dsc;
    IF scope # NIL THEN
      PrintIndent(indent);
      Out.String('--- Next scope ---'); Out.Ln
    END
  END
END Debug;

PROCEDURE ShowDebug*;
BEGIN Debug(topScope, 0)
END ShowDebug;

PROCEDURE WriteByte(VAR R: Files.Rider; n: INTEGER);
BEGIN Files.Write(R, n)
END WriteByte;

(** Write NUL-terminated UTF-8 string. *)
PROCEDURE WriteString(VAR R: Files.Rider; s: ARRAY OF CHAR);
BEGIN
  Files.WriteString(R, s);
  WriteByte(R, 0)
END WriteString;

PROCEDURE OutputLangs(VAR R: Files.Rider);
VAR l: Lang;
  zero: BYTE;
BEGIN
  l := langs;
  WHILE l # NIL DO
    WriteString(R, l.code);
    l := l.next
  END;
  zero := 0;
  Files.Write(R, zero) (* End of languages marker *)
END OutputLangs;

PROCEDURE OutputNames(VAR R: Files.Rider; names: Name);
VAR l: Lang;
  s: ARRAY 64 OF CHAR;
BEGIN
  l := langs;
  WHILE l # NIL DO
    IF names = NIL THEN s := ''
    ELSE
      GetNameLang(names, l.code, s);
      IF s = '' THEN GetName(names, s) END
    END;
    WriteString(R, s);
    l := l.next
  END
END OutputNames;

PROCEDURE AddLang*(code: ARRAY OF CHAR);
VAR l, n, tail: Lang;
BEGIN
  tail := NIL;
  l := langs;
  WHILE (l # NIL) & (l.code # code) DO tail := l; l := l.next END;

  IF l = NIL THEN
    NEW(n);
    Strings.Copy(code, n.code);
    IF tail = NIL THEN langs := n ELSE tail.next := n END
  END
END AddLang;

PROCEDURE ResetStringPool*;
BEGIN strPool := NIL; nofPoolStrings := 0
END ResetStringPool;

PROCEDURE PoolEntry*(idx: INTEGER): StringEntry;
VAR e: StringEntry;
  i: INTEGER;
BEGIN
  e := strPool;
  i := 0;
  WHILE (e # NIL) & (i # idx) DO e := e.next; INC(i) END
RETURN e END PoolEntry;

PROCEDURE PoolBytesEqual(s: ARRAY OF CHAR; charLen: INTEGER; e: StringEntry): BOOLEAN;
VAR i: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  IF (e = NIL) OR (e.nChars # charLen + 1) THEN ok := FALSE END;
  IF ok THEN
    i := 0;
    WHILE (i < charLen) & ok DO
      IF s[i] # e.bytes[i] THEN ok := FALSE END;
      INC(i)
    END
  END;
  IF ok & (e # NIL) & (e.bytes[charLen] # 0X) THEN ok := FALSE END;
RETURN ok END PoolBytesEqual;

PROCEDURE RegisterString*(s: ARRAY OF CHAR; charLen: INTEGER): INTEGER;
VAR e, tail: StringEntry;
  i, idx, res, hit, nscan: INTEGER;
BEGIN
  idx := 0;
  hit := -1;
  nscan := nofPoolStrings;
  WHILE idx < nscan DO
    e := PoolEntry(idx);
    IF PoolBytesEqual(s, charLen, e) THEN
      IF hit < 0 THEN hit := idx END
    END;
    INC(idx)
  END;
  IF hit >= 0 THEN
    res := hit
  ELSE
    NEW(e);
    i := 0;
    WHILE i < charLen DO e.bytes[i] := s[i]; INC(i) END;
    e.bytes[charLen] := 0X;
    e.nChars := charLen + 1;
    e.next := NIL;
    res := nofPoolStrings;
    IF strPool = NIL THEN strPool := e
    ELSE
      tail := strPool;
      WHILE tail.next # NIL DO tail := tail.next END;
      tail.next := e
    END;
    INC(nofPoolStrings)
  END
RETURN res END RegisterString;

PROCEDURE MakeStringType*(charLen: INTEGER): Type;
VAR T: Type;
BEGIN
  NEW(T);
  T.form := String;
  T.len := charLen + 1;
  T.size := (charLen + 1) * 2;
  T.openRank := 0;
  T.base := NIL;
  T.extLevel := 0;
  T.descOffset := -1; T.descModule := -1
RETURN T END MakeStringType;

PROCEDURE IsCharArrayType*(t: Type): BOOLEAN;
BEGIN
RETURN (t # NIL) & (t.form = Array) & (t.base = charType)
END IsCharArrayType;

PROCEDURE IsOpenArrayType*(t: Type): BOOLEAN;
BEGIN
RETURN (t # NIL) & (t.form = Array) & ((t.openRank > 0) OR (t.len = 0))
END IsOpenArrayType;

PROCEDURE OpenArrayRank*(t: Type): INTEGER;
VAR n: INTEGER;
BEGIN
  IF (t # NIL) & (t.openRank > 0) THEN n := t.openRank
  ELSE
    n := 0;
    WHILE (t # NIL) & (t.form = Array) & (t.len = 0) DO
      INC(n);
      t := t.base
    END
  END
RETURN n END OpenArrayRank;

(** Append STRP section to rider R: pool count, then each literal as UTF-8 bytes + 0X (no per-string length prefix). *)
PROCEDURE WriteStrpSection*(VAR R: Files.Rider);
VAR e: StringEntry;
  i, utf8len: INTEGER;
  u8: ARRAY 1024 OF Utf8.SHORTCHAR;
BEGIN
  Files.WriteInt(R, nofPoolStrings);
  e := strPool;
  WHILE e # NIL DO
    Utf8.EncodeEx(e.bytes, e.nChars - 1, u8, utf8len);
    IF Utf8.Done THEN
      i := 0;
      WHILE i <= utf8len DO Files.Write(R, ORD(u8[i])); INC(i) END
    ELSE
      Files.Write(R, 0)
    END;
    e := e.next
  END
END WriteStrpSection;

(** Look up T in the export-time type table; return its index in
    table or -1 if not present. *)
PROCEDURE TableIndex(T: Type): INTEGER;
VAR i, r: INTEGER;
BEGIN
  r := -1;
  i := 0;
  WHILE (i < typeTableN) & (r < 0) DO
    IF typeTable[i] = T THEN r := i END;
    INC(i)
  END
RETURN r END TableIndex;

(** Pre-pass over an exported object's type tree.  Adds every Pointer
    or Record encountered to typeTable in first-discovery order so
    that subsequent serialisation can refer to them by index instead
    of inlining (which would loop on `POINTER TO Self` structures).
    Stops descending into types already in the table -- that's the
    cycle break.  *)
PROCEDURE CollectTypes(T: Type);
VAR p: Object;
BEGIN
  IF T # NIL THEN
    IF (T.form = Pointer) OR (T.form = Record) THEN
      IF TableIndex(T) < 0 THEN
        IF typeTableN < LEN(typeTable) THEN
          typeTable[typeTableN] := T;
          INC(typeTableN);
          IF T.form = Pointer THEN
            CollectTypes(T.base)
          ELSE
            CollectTypes(T.base);
            p := T.dsc;
            WHILE (p # NIL) & (p # dummy) DO
              CollectTypes(p.type);
              p := p.next
            END
          END
        END
      END
    ELSIF T.form = Array THEN
      CollectTypes(T.base)
    ELSIF T.form = Proc THEN
      CollectTypes(T.base);
      p := T.dsc;
      WHILE p # NIL DO
        CollectTypes(p.type);
        p := p.next
      END
    END
  END
END CollectTypes;

(** Encodes the type T into rider R.  When `forceInline` is TRUE the
    Pointer/Record body is always emitted in full (used to serialise
    typeTable entries themselves); otherwise such types collapse to
    `tcTypeRef <idx>` when present in the table -- which is the
    Phase-2 hook that breaks `POINTER TO Self` recursion.
    Returns FALSE if serialization is not implemented for this type. *)
PROCEDURE WriteType(VAR R: Files.Rider; T: Type; forceInline: BOOLEAN): BOOLEAN;
VAR p: Object;
  ok: BOOLEAN;
  i, idx: INTEGER;
BEGIN
  ok := TRUE;
  IF T = NIL THEN
    Files.WriteInt(R, tcNil)
  ELSIF (T.form = Pointer) OR (T.form = Record) THEN
    idx := TableIndex(T);
    IF (idx >= 0) & ~forceInline THEN
      Files.WriteInt(R, tcTypeRef);
      Files.WriteInt(R, idx)
    ELSIF T.form = Pointer THEN
      Files.WriteInt(R, tcPointer);
      IF ~WriteType(R, T.base, FALSE) THEN ok := FALSE END
    ELSE (* Record *)
      Files.WriteInt(R, tcRecord);
      Files.WriteInt(R, T.size);
      Files.WriteInt(R, T.extLevel);
      Files.WriteInt(R, T.descOffset);
      WriteByte(R, ORD(T.declExported));
      OutputNames(R, T.declNames);
      IF ~WriteType(R, T.base, FALSE) THEN ok := FALSE END;
      p := T.dsc; i := 0;
      WHILE (p # NIL) & (p # dummy) DO INC(i); p := p.next END;
      Files.WriteInt(R, i);
      p := T.dsc;
      WHILE ok & (p # NIL) & (p # dummy) DO
        WriteByte(R, ORD(p.exported));
        Files.WriteInt(R, M.SHORT(p.address));
        OutputNames(R, p.names);
        IF ~WriteType(R, p.type, FALSE) THEN ok := FALSE END;
        p := p.next
      END
    END
  ELSIF (T.form = Bool) OR (T.form = Char) OR (T.form = Int) OR (T.form = Set)
      OR (T.form = Byte) OR (T.form = Real) OR (T.form = LongReal) OR (T.form = NoTyp)
      OR (T.form = TinyInt) OR (T.form = ShortInt) OR (T.form = LongInt)
      OR (T.form = TinySet) OR (T.form = ShortSet) OR (T.form = LongSet) THEN
    Files.WriteInt(R, T.form)
  ELSIF T.form = Array THEN
    Files.WriteInt(R, tcArray);
    Files.WriteInt(R, T.len);
    Files.WriteInt(R, T.openRank);
    Files.WriteInt(R, T.size);
    IF ~WriteType(R, T.base, FALSE) THEN ok := FALSE END
  ELSIF T.form = Proc THEN
    Files.WriteInt(R, tcProc);
    Files.WriteInt(R, T.nofpars);
    IF ~WriteType(R, T.base, FALSE) THEN ok := FALSE END;
    p := T.dsc;
    i := 0;
    WHILE ok & (i < T.nofpars) & (p # NIL) DO
      WriteByte(R, p.class);
      WriteByte(R, ORD(p.readOnly));
      OutputNames(R, p.names);
      IF ~WriteType(R, p.type, FALSE) THEN ok := FALSE END;
      p := p.next;
      INC(i)
    END
  ELSIF T.form = String THEN
    Files.WriteInt(R, tcString);
    Files.WriteInt(R, T.len);
    Files.WriteInt(R, T.size)
  ELSE ok := FALSE
  END
RETURN ok END WriteType;

(** Read NUL-terminated UTF-8 string. *)
PROCEDURE ReadCStr(VAR R: Files.Rider; VAR s: ARRAY OF CHAR);
VAR i, n: INTEGER;
  b: BYTE;
  u8: ARRAY 1024 OF Utf8.SHORTCHAR;
BEGIN
  i := 0;
  Files.Read(R, b);
  WHILE (~R.eof) & (b # 0) DO
    IF i < LEN(u8) - 1 THEN
      n := b; u8[i] := Utf8.ShortChr(n); INC(i)
    END;
    Files.Read(R, b)
  END;
  u8[i] := 0X;
  Utf8.Decode(u8, s)
END ReadCStr;

(** Read all language-keyed variants of a name written in the writer's
    lang order and attach them to *names*. *)
PROCEDURE ReadNamesIn(VAR R: Files.Rider; VAR names: Name; VAR codes: LangBuf; nLangs: INTEGER);
VAR i: INTEGER;
  s: ARRAY 64 OF CHAR;
BEGIN
  i := 0;
  WHILE i < nLangs DO
    ReadCStr(R, s);
    SetNameLang(names, codes[i], s);
    INC(i)
  END
END ReadNamesIn;

PROCEDURE LookupStdType(form: INTEGER): Type;
VAR T: Type;
BEGIN
  T := NIL;
  IF    form = Bool     THEN T := boolType
  ELSIF form = Char     THEN T := charType
  ELSIF form = Int      THEN T := intType
  ELSIF form = Set      THEN T := setType
  ELSIF form = Byte     THEN T := byteType
  ELSIF form = Real     THEN T := realType
  ELSIF form = LongReal THEN T := longRealType
  ELSIF form = NoTyp    THEN T := noType
  ELSIF form = TinyInt  THEN T := tinyIntType
  ELSIF form = ShortInt THEN T := shortIntType
  ELSIF form = LongInt  THEN T := longIntType
  ELSIF form = TinySet  THEN T := tinySetType
  ELSIF form = ShortSet THEN T := shortSetType
  ELSIF form = LongSet  THEN T := longSetType
  END
RETURN T END LookupStdType;

(** Fill in a pre-allocated, currently-empty table slot T by reading
    its definition from R.  Writes through T instead of NEW'ing a
    fresh one -- preserves the slot's identity so any tcTypeRef
    encountered earlier already points at the right object once we
    finish. *)
PROCEDURE ReadTypeInto(VAR R: Files.Rider; T: Type;
    VAR codes: LangBuf; nLangs: INTEGER): BOOLEAN;
VAR tag, i, ival: INTEGER;
  par, prev, head: Object;
  rb: BYTE;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  Files.ReadInt(R, tag);
  IF tag = tcRecord THEN
    T.form := Record; T.openRank := 0;
    Files.ReadInt(R, T.size);
    Files.ReadInt(R, T.extLevel);
    Files.ReadInt(R, T.descOffset);
    Files.Read(R, rb); T.declExported := rb # 0;
    ReadNamesIn(R, T.declNames, codes, nLangs);
    IF ~readType(R, T.base, codes, nLangs) THEN ok := FALSE END;
    Files.ReadInt(R, i);
    head := NIL; prev := NIL;
    WHILE ok & (i > 0) DO
      NEW(par);
      par.class := Fld;
      Files.Read(R, rb); par.exported := rb # 0;
      Files.ReadInt(R, ival); par.address := ival;
      ReadNamesIn(R, par.names, codes, nLangs);
      IF ~readType(R, par.type, codes, nLangs) THEN ok := FALSE END;
      IF prev = NIL THEN head := par ELSE prev.next := par END;
      prev := par;
      DEC(i)
    END;
    IF prev # NIL THEN prev.next := dummy END;
    T.dsc := head
  ELSIF tag = tcPointer THEN
    T.form := Pointer; T.openRank := 0; T.size := 8;
    T.descOffset := -1; T.descModule := -1;
    IF ~readType(R, T.base, codes, nLangs) THEN ok := FALSE END
  ELSE ok := FALSE
  END
RETURN ok END ReadTypeInto;

PROCEDURE ReadType(VAR R: Files.Rider; VAR T: Type;
    VAR codes: LangBuf; nLangs: INTEGER): BOOLEAN;
VAR tag, i, ival, idx: INTEGER;
  base: Type;
  par, prev, head: Object;
  rb: BYTE;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  Files.ReadInt(R, tag);
  IF tag = tcNil THEN T := NIL
  ELSIF tag = tcTypeRef THEN
    Files.ReadInt(R, idx);
    IF (idx >= 0) & (idx < importTableN) THEN
      T := importTable[idx]
    ELSE
      T := NIL; ok := FALSE
    END
  ELSIF tag >= 0 THEN
    T := LookupStdType(tag);
    IF T = NIL THEN ok := FALSE END
  ELSIF tag = tcArray THEN
    NEW(T); T.form := Array; T.descOffset := -1; T.descModule := -1;
    Files.ReadInt(R, T.len);
    Files.ReadInt(R, T.openRank);
    Files.ReadInt(R, T.size);
    IF ~ReadType(R, base, codes, nLangs) THEN ok := FALSE END;
    T.base := base
  ELSIF tag = tcProc THEN
    NEW(T); T.form := Proc; T.size := 8; T.openRank := 0;
    T.descOffset := -1; T.descModule := -1;
    Files.ReadInt(R, T.nofpars);
    IF ~ReadType(R, base, codes, nLangs) THEN ok := FALSE END;
    T.base := base;
    head := NIL; prev := NIL;
    i := 0;
    WHILE ok & (i < T.nofpars) DO
      NEW(par);
      Files.Read(R, rb); par.class := rb;
      Files.Read(R, rb); par.readOnly := rb # 0;
      ReadNamesIn(R, par.names, codes, nLangs);
      IF ~ReadType(R, par.type, codes, nLangs) THEN ok := FALSE END;
      IF prev = NIL THEN head := par ELSE prev.next := par END;
      prev := par;
      INC(i)
    END;
    T.dsc := head
  ELSIF tag = tcString THEN
    NEW(T); T.form := String; T.openRank := 0;
    T.descOffset := -1; T.descModule := -1;
    Files.ReadInt(R, T.len);
    Files.ReadInt(R, T.size)
  ELSIF tag = tcRecord THEN
    NEW(T); T.form := Record; T.openRank := 0;
    Files.ReadInt(R, T.size);
    Files.ReadInt(R, T.extLevel);
    Files.ReadInt(R, T.descOffset);
    Files.Read(R, rb); T.declExported := rb # 0;
    ReadNamesIn(R, T.declNames, codes, nLangs);
    IF ~ReadType(R, T.base, codes, nLangs) THEN ok := FALSE END;
    Files.ReadInt(R, i); (* field count *)
    head := NIL; prev := NIL;
    WHILE ok & (i > 0) DO
      NEW(par);
      par.class := Fld;
      Files.Read(R, rb); par.exported := rb # 0;
      Files.ReadInt(R, ival); par.address := ival;
      ReadNamesIn(R, par.names, codes, nLangs);
      IF ~ReadType(R, par.type, codes, nLangs) THEN ok := FALSE END;
      IF prev = NIL THEN head := par ELSE prev.next := par END;
      prev := par;
      DEC(i)
    END;
    IF prev # NIL THEN prev.next := dummy END;
    T.dsc := head
  ELSIF tag = tcPointer THEN
    NEW(T); T.form := Pointer; T.openRank := 0; T.size := 8;
    T.descOffset := -1; T.descModule := -1;
    IF ~ReadType(R, base, codes, nLangs) THEN ok := FALSE END;
    T.base := base
  ELSE ok := FALSE
  END
RETURN ok END ReadType;

(** Compute a tiny interface fingerprint over a byte range of file F. *)
PROCEDURE FileHash(F: Files.File; from, to: INTEGER): INTEGER;
VAR R: Files.Rider;
  b: BYTE;
  h, p, n: INTEGER;
BEGIN
  h := 5381;
  Files.Set(R, F, from);
  p := from;
  WHILE p < to DO
    Files.Read(R, b);
    n := b;
    h := (h * 33 + n) MOD 1073741824;
    INC(p)
  END
RETURN h END FileHash;

(** Read the language-code list from rider R (after magic and hash). *)
PROCEDURE ReadLangList(VAR R: Files.Rider; VAR codes: LangBuf; VAR nLangs: INTEGER);
VAR k: INTEGER;
  langB: BYTE;
BEGIN
  nLangs := 0;
  Files.Read(R, langB);
  WHILE (~R.eof) & (langB # 0) DO
    k := 0;
    WHILE (~R.eof) & (langB # 0) DO
      IF (nLangs < 16) & (k < 5) THEN
        codes[nLangs, k] := CHR(langB);
        INC(k)
      END;
      Files.Read(R, langB)
    END;
    IF nLangs < 16 THEN
      codes[nLangs, k] := 0X;
      INC(nLangs)
    END;
    Files.Read(R, langB)
  END
END ReadLangList;

(** Load a .sym file by full path for tools (showdef).  Returns module
    names, export object list, and language codes.  Does not set external. *)
PROCEDURE LoadSymFile*(fname: ARRAY OF CHAR; VAR modNames: Name; VAR exports: Object;
    VAR codes: LangBuf; VAR nLangs: INTEGER): BOOLEAN;
VAR F: Files.File;
  R: Files.Rider;
  poolIdx, charLen: INTEGER;
  mark, hash, count, addr, ival, i: INTEGER;
  p, prev: Object;
  ok: BOOLEAN;
  classB: BYTE;
  s: ARRAY 256 OF CHAR;
BEGIN
  ok := FALSE;
  exports := NIL;
  modNames := NIL;
  F := Files.Old(fname);
  IF F # NIL THEN
    Files.Set(R, F, 0);
    Files.ReadInt(R, mark);
    IF mark = symFileMark THEN
      Files.ReadInt(R, hash);
      ReadLangList(R, codes, nLangs);
      ReadNamesIn(R, modNames, codes, nLangs);
      Files.ReadInt(R, importTableN);
      ok := TRUE;
      i := 0;
      WHILE i < importTableN DO
        NEW(importTable[i]);
        importTable[i].form := -1;
        importTable[i].base := NIL;
        importTable[i].dsc := NIL;
        importTable[i].extLevel := 0;
        importTable[i].descOffset := -1;
        importTable[i].descModule := -1;
        INC(i)
      END;
      i := 0;
      WHILE ok & (i < importTableN) DO
        IF ~ReadTypeInto(R, importTable[i], codes, nLangs) THEN ok := FALSE END;
        INC(i)
      END;
      Files.ReadInt(R, count);
      prev := NIL;
      i := 0;
      WHILE ok & (i < count) DO
        NEW(p); p.exported := TRUE; p.external := FALSE;
        p.importIdx := -1; p.lev := 0;
        Files.Read(R, classB);
        p.class := SYSTEM.VAL(INTEGER, classB);
        ReadNamesIn(R, p.names, codes, nLangs);
        Files.ReadInt(R, addr); p.address := addr;
        Files.ReadInt(R, ival); p.intVal := ival;
        IF ~ReadType(R, p.type, codes, nLangs) THEN ok := FALSE END;
        IF ok & (p.class = Const) & (p.type # NIL) & (p.type.form = String) THEN
          ReadCStr(R, s);
          charLen := p.type.len - 1;
          poolIdx := RegisterString(s, charLen);
          p.intVal := poolIdx
        END;
        IF prev = NIL THEN exports := p ELSE prev.next := p END;
        prev := p;
        INC(i)
      END
    END
  END
RETURN ok END LoadSymFile;

(** Read only the language list from a .sym file. *)
PROCEDURE PeekSymLangs*(fname: ARRAY OF CHAR; VAR codes: LangBuf; VAR nLangs: INTEGER): BOOLEAN;
VAR F: Files.File;
  R: Files.Rider;
  mark, hash: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  nLangs := 0;
  F := Files.Old(fname);
  IF F # NIL THEN
    Files.Set(R, F, 0);
    Files.ReadInt(R, mark);
    IF mark = symFileMark THEN
      Files.ReadInt(R, hash);
      ReadLangList(R, codes, nLangs);
      ok := TRUE
    END
  END
RETURN ok END PeekSymLangs;

(** Returns TRUE if a .sym file for moduleName exists in M.outDir, and
    populates M.dsc with imported objects (Const, Typ, Var) and their
    types.  Each imported object has external = TRUE so that the
    code generator can emit external relocations for procedure calls.

    importIdx is the index assigned by the driver to this module in the
    importing module's imports list — needed to refer to procedures
    correctly via external BL relocations later. *)
PROCEDURE ImportSymFile*(modObj: Object; moduleName: ARRAY OF CHAR; importIdx: INTEGER): BOOLEAN;
VAR F: Files.File;
  R: Files.Rider;
  fname: ARRAY 256 OF CHAR;
  codes: LangBuf;
  poolIdx, charLen: INTEGER;
  mark, hash, count, addr, ival, i, nLangs: INTEGER;
  p, prev: Object;
  ok: BOOLEAN;
  classB: BYTE;
BEGIN
  ok := FALSE;
  IF ~M.FindSymFile(moduleName, fname) THEN
    F := NIL
  ELSE
    F := Files.Old(fname)
  END;
  IF F # NIL THEN
    Files.Set(R, F, 0);
    Files.ReadInt(R, mark);
    IF mark = symFileMark THEN
      Files.ReadInt(R, hash);
      ReadLangList(R, codes, nLangs);
      ReadNamesIn(R, modObj.names, codes, nLangs);

      (* Two-pass type-table read: pre-allocate N empty Type slots so
         that any tcTypeRef encountered in pass 2 already has a stable
         pointer to hand back, then fill each slot in order.  This is
         what lets cyclic forms like `POINTER TO Self` round-trip. *)
      Files.ReadInt(R, importTableN);
      ok := TRUE;
      i := 0;
      WHILE i < importTableN DO
        NEW(importTable[i]);
        importTable[i].form := -1;
        importTable[i].base := NIL;
        importTable[i].dsc := NIL;
        importTable[i].extLevel := 0;
        importTable[i].descOffset := -1;
        importTable[i].descModule := -1;
        INC(i)
      END;
      i := 0;
      WHILE ok & (i < importTableN) DO
        IF ~ReadTypeInto(R, importTable[i], codes, nLangs) THEN
          ok := FALSE
        ELSIF (importTable[i].form = Record) & (importTable[i].descOffset >= 0) THEN
          importTable[i].descModule := importIdx
        END;
        INC(i)
      END;

      Files.ReadInt(R, count);
      prev := NIL;
      i := 0;
      WHILE ok & (i < count) DO
        NEW(p); p.exported := TRUE; p.external := TRUE;
        p.importIdx := importIdx; p.lev := 0;
        Files.Read(R, classB);
        p.class := SYSTEM.VAL(INTEGER, classB);
        ReadNamesIn(R, p.names, codes, nLangs);
        Files.ReadInt(R, addr); p.address := addr;
        Files.ReadInt(R, ival); p.intVal := ival;
        IF ~ReadType(R, p.type, codes, nLangs) THEN ok := FALSE END;
        IF ok & (p.class = Const) & (p.type # NIL) & (p.type.form = String) THEN
          ReadCStr(R, fname);
          charLen := p.type.len - 1;
          poolIdx := RegisterString(fname, charLen);
          p.intVal := poolIdx
        END;
        IF prev = NIL THEN modObj.dsc := p ELSE prev.next := p END;
        prev := p;
        INC(i)
      END
    END
  END
RETURN ok END ImportSymFile;

(** Add `name` to the list of canonical module names known to live in
    M.outDir.  Called by the build driver during Discover for every
    discovered module (its canonical name = the name written after
    MODULE in the source).  Idempotent. *)
PROCEDURE RegisterCanonical*(name: ARRAY OF CHAR);
VAR p, tail: CanonicalReg;
BEGIN
  p := canonRegs; tail := NIL;
  WHILE (p # NIL) & (p.name # name) DO tail := p; p := p.next END;
  IF p = NIL THEN
    NEW(p);
    Strings.Copy(name, p.name);
    p.next := NIL;
    IF tail = NIL THEN canonRegs := p ELSE tail.next := p END
  END
END RegisterCanonical;

PROCEDURE ResetCanonical*;
BEGIN canonRegs := NIL
END ResetCanonical;

(** Reads only the languages list and the module-name slot of a .sym
    file at `fname`.  Returns TRUE iff the file exists, has the right
    magic, and the module slot decodes cleanly.  `names` ends up with
    one entry per language found in the file.  Used by ResolveCanonical
    to peek into candidate .sym files without disturbing the rest of
    the symbol table. *)
PROCEDURE PeekSymModuleNames*(fname: ARRAY OF CHAR; VAR names: Name): BOOLEAN;
VAR F: Files.File;
  R: Files.Rider;
  codes: LangBuf;
  mark, k, nLangs: INTEGER;
  langB: BYTE;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  F := Files.Old(fname);
  IF F # NIL THEN
    Files.Set(R, F, 0);
    Files.ReadInt(R, mark);
    IF mark = symFileMark THEN
      Files.ReadInt(R, mark); (* skip hash *)

      nLangs := 0;
      Files.Read(R, langB);
      WHILE (~R.eof) & (langB # 0) DO
        k := 0;
        WHILE (~R.eof) & (langB # 0) DO
          IF (nLangs < 16) & (k < 5) THEN
            codes[nLangs, k] := CHR(langB);
            INC(k)
          END;
          Files.Read(R, langB)
        END;
        IF nLangs < 16 THEN
          codes[nLangs, k] := 0X;
          INC(nLangs)
        END;
        Files.Read(R, langB)
      END;

      names := NIL;
      ReadNamesIn(R, names, codes, nLangs);
      ok := TRUE
    END
  END
RETURN ok END PeekSymModuleNames;

(** Resolve the canonical (file-system) name for an imported module.
    The localised `name` is as written in the source.  Lookup order:
      1. SYSTEM via the language table -> 'SYSTEM'.
      2. Direct match: M.outDir/<name>.sym exists -> canonical := name.
      3. Iterate every name registered via RegisterCanonical and peek
         at its .sym file; if any language form of its module name
         equals `name`, return that canonical.
      4. Fall back to `name` (callers will get a clean "module not
         found" error from ImportSymFile).
    *)
PROCEDURE ResolveCanonical*(name: ARRAY OF CHAR; VAR canonical: ARRAY OF CHAR);
VAR s: ARRAY 32 OF CHAR;
  fname: ARRAY 256 OF CHAR;
  num: INTEGER;
  F: Files.File;
  reg: CanonicalReg;
  cand: Name;
BEGIN
  Strings.Copy(name, canonical);

  L.FindModule(name, s, num);
  IF s = 'SYSTEM' THEN
    Strings.Copy('SYSTEM', canonical)
  ELSIF M.FindSymFile(name, fname) THEN
    (* direct hit in build dir or lib cache *)
  ELSE
    reg := canonRegs;
    WHILE (reg # NIL) & (reg.name # canonical) DO
      IF reg.name # name THEN
        IF M.FindSymFile(reg.name, fname) &
           PeekSymModuleNames(fname, cand) & NameMatches(cand, name) THEN
          Strings.Copy(reg.name, canonical)
        END
      END;
      reg := reg.next
    END
  END
END ResolveCanonical;

(** Loads symbol data of module to M.  `canonical` is the file-system
    name that selects M.outDir/<canonical>.{sym,obj}; it may differ from
    the localised name stored on M.names when an import was written in
    a non-canonical language and resolved via ResolveCanonical. *)
PROCEDURE Import*(M: Object; canonical: ARRAY OF CHAR; importIdx: INTEGER);
VAR s: ARRAY 32 OF CHAR;
  num: INTEGER;
BEGIN
  L.FindModule(canonical, s, num);
  IF (s = 'SYSTEM') OR (canonical = 'SYSTEM') THEN ImportSystem(M, num)
  ELSIF ImportSymFile(M, canonical, importIdx) THEN
    (* loaded *)
  ELSE S.Mark(E.noModule)
  END
END Import;

(** Export module symbols to .sym file with full type tree for each
    exported entity and a 32-bit interface fingerprint at offset 4.
    The format version is fixed at 1 (see plan). *)
PROCEDURE ExportModule*(modNames: Name);
VAR
  F: Files.File;
  R: Files.Rider;
  fname: ARRAY 256 OF CHAR;
  p: Object;
  pe: StringEntry;
  i, utf8len, hashStart, hashEnd, hash, exportCount: INTEGER;
  u8: ARRAY 1024 OF Utf8.SHORTCHAR;
BEGIN
  Strings.Copy(M.outDir, fname); Strings.Append(modNames.str, fname);
  Strings.Append('.sym', fname);
  F := Files.New(fname);

  IF F # NIL THEN
    Files.Set(R, F, 0);
    Files.WriteInt(R, symFileMark);
    Files.WriteInt(R, 0); (* placeholder for interface hash *)
    OutputLangs(R);
    OutputNames(R, modNames);

    exportCount := 0;
    p := topScope.next;
    WHILE p # dummy DO
      IF p.exported THEN INC(exportCount) END;
      p := p.next
    END;

    (* Build the type table: walk all exported objects' type trees,
       collecting the Pointer/Record types that need indirected
       serialisation.  The collection order doubles as the index
       assignment, so cross-references inside the table itself
       resolve cleanly. *)
    typeTableN := 0;
    p := topScope.next;
    WHILE p # dummy DO
      IF p.exported THEN CollectTypes(p.type) END;
      p := p.next
    END;

    hashStart := Files.Pos(R);
    Files.WriteInt(R, typeTableN);
    i := 0;
    WHILE i < typeTableN DO
      IF ~WriteType(R, typeTable[i], TRUE) THEN
        M.WriteError(E.exportTooDeep)
      END;
      INC(i)
    END;
    Files.WriteInt(R, exportCount);

    p := topScope.next;
    WHILE p # dummy DO
      IF p.exported THEN
        WriteByte(R, p.class);
        OutputNames(R, p.names);
        Files.WriteInt(R, M.SHORT(p.address));
        Files.WriteInt(R, M.SHORT(p.intVal));
        IF ~WriteType(R, p.type, FALSE) THEN
          M.WriteError(E.exportTooDeep)
        END;
        IF (p.class = Const) & (p.type # NIL) & (p.type.form = String) THEN
          pe := PoolEntry(M.SHORT(p.intVal));
          IF pe # NIL THEN
            Utf8.EncodeEx(pe.bytes, pe.nChars - 1, u8, utf8len);
            IF Utf8.Done THEN
              i := 0;
              WHILE i <= utf8len DO Files.Write(R, ORD(u8[i])); INC(i) END
            ELSE Files.Write(R, 0)
            END
          ELSE Files.Write(R, 0)
          END
        END
      END;
      p := p.next
    END;

    hashEnd := Files.Pos(R);
    Files.Register(F);
    F := Files.Old(fname);
    IF F # NIL THEN
      hash := FileHash(F, hashStart, hashEnd);
      Files.Set(R, F, 4);
      Files.WriteInt(R, hash)
    END
  ELSE
    M.WriteErrorS(E.cantCreateSym, fname)
  END
END ExportModule;

PROCEDURE Init*(curLang: ARRAY OF CHAR);
BEGIN
  AddLang(curLang);
  ResetStringPool;

  curLev := 0;
  topScope := NIL;
  NEW(dummy);
  OpenScope;
  InitUniverse;
  OpenScope
END Init;

PROCEDURE CreateType(form, size: INTEGER): Type;
VAR T: Type;
BEGIN NEW(T); T.form := form; T.size := size; T.openRank := 0;
  T.extLevel := 0; T.descOffset := -1; T.descModule := -1
RETURN T END CreateType;

BEGIN
  strPool := NIL;
  nofPoolStrings := 0;
  boolType     := CreateType(Bool    , 1);
  charType     := CreateType(Char    , 2);
  intType      := CreateType(Int     , 4);
  setType      := CreateType(Set     , 4);
  byteType     := CreateType(Byte    , 1);
  realType     := CreateType(Real    , 4);
  longRealType := CreateType(LongReal, 8);
  noType       := CreateType(NoTyp   , 0);
  tinyIntType  := CreateType(TinyInt , 1);
  shortIntType := CreateType(ShortInt, 2);
  longIntType  := CreateType(LongInt , 8);
  tinySetType  := CreateType(TinySet , 1);
  shortSetType := CreateType(ShortSet, 2);
  longSetType  := CreateType(LongSet , 8);
  (* ADRINT is a separate Type whose form mirrors the host word size:
     LongInt (8 B) on 64-bit targets, Int (4 B) on 32-bit ones.  By
     reusing the existing forms it inherits all the standard arithmetic
     and assignment rules; the dedicated Type pointer is solely a tag
     for the LONG/SHORT special-casing in Parser.StandFunc. *)
  IF M.Is64Bit THEN
    adrIntType := CreateType(LongInt, M.WordSize)
  ELSE
    adrIntType := CreateType(Int, M.WordSize)
  END;
  nilType := CreateType(Pointer, 8);
  nilType.base := NIL;
  readType := ReadType
END SymTable.
