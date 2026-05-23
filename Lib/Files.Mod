MODULE Files; (**%RU:Файлы%LV:Faili*)
IMPORT SYSTEM, Utf8;

CONST
  bufSize = 4096;
  maxMem = 16384;
  invalidFd = -1;

  (** Darwin arm64 syscalls **)
  sysOpen = 5;
  sysClose = 6;
  sysRead = 3;
  sysWrite = 4;
  sysUnlink = 10;
  sysLseek = 199;
  sysFtruncate = 196;
  sysRename = 128;
  sysFstat = 345;

  oRdWr = 2;
  oCreat = 200H;
  oTrunc = 400H;
  fileMode = 1A4H;
  seekSet = 0;
  seekCur = 1;
  seekEnd = 2;

TYPE
  File* = POINTER TO FileDesc;
  Rider* = RECORD
    eof*: BOOLEAN;
    res*: INTEGER;
    f: File;
    pos: INTEGER
  END;

  FileDesc = RECORD
    regName: ARRAY 256 OF CHAR;
    fd: INTEGER;
    len: INTEGER;
    memLen: INTEGER;
    memOnly: BOOLEAN;
    mem: ARRAY maxMem OF BYTE
  END;

PROCEDURE Halt(msg: ARRAY OF CHAR);
VAR i: INTEGER; b: BYTE;
BEGIN
  i := 0;
  WHILE msg[i] # 0X DO
    b := SYSTEM.VAL(BYTE, ORD(msg[i]) MOD 100H);
    IF SYSTEM.SVC(4, 2, SYSTEM.ADR(b), 1) = 0 THEN END;
    INC(i)
  END;
  b := 10;
  IF SYSTEM.SVC(4, 2, SYSTEM.ADR(b), 1) = 0 THEN END;
  IF SYSTEM.SVC(1, 99, 0, 0) = 0 THEN END
END Halt;

PROCEDURE CopyName(src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (src[i] # 0X) & (i < LEN(dst) - 1) DO dst[i] := src[i]; INC(i) END;
  dst[i] := 0X
END CopyName;

PROCEDURE PathUtf8(name: ARRAY OF CHAR; VAR q: ARRAY OF BYTE): INTEGER;
VAR n, used: INTEGER;
BEGIN
  n := 0;
  WHILE (n # LEN(name)) & (name[n] # 0X) DO INC(n) END;
  used := Utf8.Encode(name, 0, n, q, 0, LEN(q) - 1);
  IF used < 0 THEN used := 0 END;
  IF used < LEN(q) THEN q[used] := 0 END
RETURN used END PathUtf8;

PROCEDURE SysOpen(name: ARRAY OF CHAR; flags: INTEGER): INTEGER;
VAR path: ARRAY 1024 OF BYTE; r: LONGINT;
BEGIN
  IF PathUtf8(name, path) = 0 THEN r := invalidFd
  ELSE r := SYSTEM.SVC(sysOpen, SYSTEM.ADR(path), flags, fileMode)
  END
RETURN SHORT(r) END SysOpen;

PROCEDURE SysClose(fd: INTEGER): INTEGER;
RETURN SYSTEM.SVC(sysClose, fd, 0, 0) END SysClose;

PROCEDURE SysRead(fd: INTEGER; VAR buf: ARRAY OF BYTE; n: INTEGER): INTEGER;
VAR r: LONGINT;
BEGIN r := SYSTEM.SVC(sysRead, fd, SYSTEM.ADR(buf), n)
RETURN SHORT(r) END SysRead;

PROCEDURE SysWrite(fd: INTEGER; buf: ARRAY OF BYTE; n: INTEGER): INTEGER;
VAR r: LONGINT;
BEGIN r := SYSTEM.SVC(sysWrite, fd, SYSTEM.ADR(buf), n)
RETURN SHORT(r) END SysWrite;

PROCEDURE SysUnlink(name: ARRAY OF CHAR): INTEGER;
VAR path: ARRAY 1024 OF BYTE; r: LONGINT;
BEGIN
  IF PathUtf8(name, path) = 0 THEN r := 1
  ELSE r := SYSTEM.SVC(sysUnlink, SYSTEM.ADR(path), 0, 0)
  END
RETURN SHORT(r) END SysUnlink;

PROCEDURE SysRename(old, new: ARRAY OF CHAR): INTEGER;
VAR p0, p1: ARRAY 1024 OF BYTE; r: LONGINT;
BEGIN
  IF PathUtf8(old, p0) = 0 THEN r := 1
  ELSIF PathUtf8(new, p1) = 0 THEN r := 1
  ELSE r := SYSTEM.SVC(sysRename, SYSTEM.ADR(p0), SYSTEM.ADR(p1), 0)
  END
RETURN SHORT(r) END SysRename;

PROCEDURE SysSeek(fd: INTEGER; pos: INTEGER): INTEGER;
VAR r: LONGINT;
BEGIN r := SYSTEM.SVC(sysLseek, fd, pos, seekSet)
RETURN SHORT(r) END SysSeek;

PROCEDURE SysTruncate(fd: INTEGER; pos: INTEGER): INTEGER;
VAR r: LONGINT;
BEGIN r := SYSTEM.SVC(sysFtruncate, fd, pos, 0)
RETURN SHORT(r) END SysTruncate;

PROCEDURE FdLength(fd: INTEGER): INTEGER;
VAR cur, sz: LONGINT;
BEGIN
  cur := SYSTEM.SVC(sysLseek, fd, 0, seekCur);
  sz := SYSTEM.SVC(sysLseek, fd, 0, seekEnd);
  IF cur >= 0 THEN IF SYSTEM.SVC(sysLseek, fd, cur, seekSet) = 0 THEN END END;
  IF sz < 0 THEN sz := 0 END
RETURN SHORT(sz) END FdLength;

PROCEDURE OpenRegistered(f: File);
VAR fd, n: INTEGER;
BEGIN
  IF f.memOnly THEN
    fd := SysOpen(f.regName, oRdWr + oCreat + oTrunc);
    IF fd < 0 THEN Halt('Files.Register open') END;
    IF f.memLen > 0 THEN
      n := SysWrite(fd, f.mem, f.memLen);
      IF n # f.memLen THEN Halt('Files.Register write') END
    END;
    f.fd := fd;
    f.len := f.memLen; (* memLen fits INTEGER *)
    f.memLen := 0;
    f.memOnly := FALSE
  END
END OpenRegistered;

PROCEDURE New*(name: ARRAY OF CHAR): File; (**%RU:Новый,имя%LV:Jauns,vārds*)
VAR f: File;
BEGIN
  NEW(f);
  CopyName(name, f.regName);
  f.fd := invalidFd;
  f.len := 0;
  f.memLen := 0;
  f.memOnly := TRUE
RETURN f END New;

PROCEDURE Old*(name: ARRAY OF CHAR): File; (**%RU:Старый,имя%LV:Vecs,vārds*)
VAR f: File; fd: INTEGER;
BEGIN
  fd := SysOpen(name, oRdWr);
  IF fd < 0 THEN f := NIL
  ELSE
    NEW(f);
    CopyName(name, f.regName);
    f.fd := fd;
    f.len := FdLength(fd);
    f.memLen := 0;
    f.memOnly := FALSE
  END
RETURN f END Old;

PROCEDURE Register*(f: File); (**%RU:Зарегистрировать,файл%LV:Reģistrēt,fails*)
BEGIN
  IF f # NIL THEN OpenRegistered(f) END
END Register;

PROCEDURE Close*(f: File); (**%RU:Закрыть,файл%LV:Aizvērt,fails*)
BEGIN
  IF (f # NIL) & (f.fd # invalidFd) THEN
    IF SysClose(f.fd) = 0 THEN END;
    f.fd := invalidFd
  END
END Close;

PROCEDURE Purge*(f: File); (**%RU:Очистить,файл%LV:Iztukšot,fails*)
BEGIN
  IF f # NIL THEN
    IF f.memOnly THEN f.len := 0; f.memLen := 0
    ELSIF f.fd # invalidFd THEN
      IF SysTruncate(f.fd, 0) = 0 THEN END;
      f.len := 0
    END
  END
END Purge;

PROCEDURE Delete*(name: ARRAY OF CHAR; VAR res: INTEGER); (**%RU:Удалить,имя,рез%LV:Dzēst,vārds,rez*)
BEGIN res := SysUnlink(name) END Delete;

PROCEDURE Rename*(old, new: ARRAY OF CHAR; VAR res: INTEGER); (**%RU:Переименовать,стар,нов,рез%LV:Pārdēvēt,vecs,jauns,rez*)
BEGIN res := SysRename(old, new) END Rename;

PROCEDURE Length*(f: File): INTEGER; (**%RU:Длина,файл%LV:Garums,fails*)
VAR n: INTEGER;
BEGIN
  IF f = NIL THEN n := 0
  ELSIF f.memOnly THEN n := f.len
  ELSE n := FdLength(f.fd)
  END
RETURN n END Length;

PROCEDURE ModTime*(name: ARRAY OF CHAR): INTEGER; (**%RU:ВремяМод,имя%LV:ModLaiks,vārds*)
VAR fd: INTEGER;
  buf: ARRAY 144 OF BYTE;
  r: LONGINT;
  t: INTEGER;
BEGIN
  t := 0;
  fd := SysOpen(name, 0);
  IF fd >= 0 THEN
    r := SYSTEM.SVC(sysFstat, fd, SYSTEM.ADR(buf), 0);
    IF r = 0 THEN
      t := buf[48] + buf[49] * 100H + buf[50] * 10000H + buf[51] * 1000000H
    END;
    IF SysClose(fd) = 0 THEN END
  END
RETURN t END ModTime;

PROCEDURE GetDate*(f: File; VAR t, d: INTEGER); (**%RU:Дата,файл,время,дата%LV:Datums,fails,laiks,datums*)
BEGIN
  IF f = NIL THEN t := 0
  ELSE t := ModTime(f.regName)
  END;
  d := 0
END GetDate;

PROCEDURE Set*(VAR r: Rider; f: File; pos: INTEGER); (**%RU:Установить,райдер,файл,поз%LV:Iestatīt,jātnieks,fails,poz*)
BEGIN
  r.f := f; r.pos := pos; r.eof := FALSE; r.res := 0;
  IF (f # NIL) & (pos > f.len) THEN r.pos := f.len END;
  IF (f # NIL) & ~f.memOnly & (f.fd # invalidFd) THEN
    IF SysSeek(f.fd, r.pos) = r.pos THEN END
  END
END Set;

PROCEDURE Pos*(VAR r: Rider): INTEGER; (**%RU:Позиция,райдер%LV:Pozīcija,jātnieks*)
RETURN r.pos END Pos;

PROCEDURE Base*(VAR r: Rider): File; (**%RU:База,райдер%LV:Bāze,jātnieks*)
RETURN r.f END Base;

PROCEDURE ReadByte(f: File; pos: INTEGER; VAR b: BYTE; VAR ok: BOOLEAN);
VAR n: INTEGER; i: INTEGER; buf: ARRAY 1 OF BYTE;
BEGIN
  ok := FALSE;
  IF f.memOnly THEN
    i := pos;
    IF (i >= 0) & (i < f.memLen) THEN b := f.mem[i]; ok := TRUE END
  ELSIF f.fd # invalidFd THEN
    IF pos >= f.len THEN ok := FALSE
    ELSIF SysSeek(f.fd, pos) = pos THEN
      n := SysRead(f.fd, buf, 1);
      IF n = 1 THEN b := buf[0]; ok := TRUE ELSE ok := FALSE END
    END
  END
END ReadByte;

PROCEDURE WriteByte(f: File; pos: INTEGER; b: BYTE);
VAR n: INTEGER; i: INTEGER; buf: ARRAY 1 OF BYTE;
BEGIN
  IF f.memOnly THEN
    i := pos;
    IF (i >= 0) & (i < maxMem) THEN
      f.mem[i] := b;
      IF i + 1 > f.memLen THEN f.memLen := i + 1 END;
      IF f.len < f.memLen THEN f.len := f.memLen END
    END
  ELSIF f.fd # invalidFd THEN
    IF SysSeek(f.fd, pos) = pos THEN
      buf[0] := b;
      n := SysWrite(f.fd, buf, 1);
      IF n = 1 THEN
        IF pos + 1 > f.len THEN f.len := pos + 1 END
      END
    END
  END
END WriteByte;

PROCEDURE Read*(VAR r: Rider; VAR x: BYTE); (**%RU:Читать,райдер,байт%LV:Lasīt,jātnieks,baits*)
VAR ok: BOOLEAN;
BEGIN
  ReadByte(r.f, r.pos, x, ok);
  IF ok THEN INC(r.pos) ELSE x := 0; r.eof := TRUE END
END Read;

PROCEDURE ReadChar*(VAR r: Rider; VAR x: CHAR); (**%RU:ЧитатьСимвол,райдер,символ%LV:LasītZīmi,jātnieks,zīme*)
VAR b: BYTE; y: INTEGER;
BEGIN
  Read(r, b); y := b;
  IF y > 80H THEN
    Read(r, b); b := b MOD 64;
    IF y DIV 32 = 6 THEN y := y MOD 32 * 64 + b
    ELSIF y DIV 16 = 14 THEN
      y := (y MOD 16 * 64 + b) * 64;
      Read(r, b); INC(y, b MOD 64)
    ELSIF y DIV 8 = 30 THEN
      y := (y MOD 8 * 64 + b) * 64;
      Read(r, b); y := (y + b MOD 64) * 64;
      Read(r, b); INC(y, b MOD 64)
    ELSE y := 0
    END
  END;
  x := CHR(y)
END ReadChar;

PROCEDURE Write*(VAR r: Rider; x: BYTE); (**%RU:Писать,райдер,байт%LV:Rakstīt,jātnieks,baits*)
BEGIN
  WriteByte(r.f, r.pos, x);
  INC(r.pos);
  IF r.pos > r.f.len THEN r.f.len := r.pos END;
  r.eof := FALSE; r.res := 0
END Write;

PROCEDURE ReadBytes*(VAR r: Rider; VAR x: ARRAY OF BYTE; n: INTEGER); (**%RU:ЧитатьБайты,райдер,буф,число%LV:LasītBaitus,jātnieks,buf,skaits*)
VAR i, got, remain: INTEGER; b: BYTE; ok: BOOLEAN;
BEGIN
  IF n > LEN(x) THEN n := LEN(x) END;
  remain := n; i := 0; got := 0;
  WHILE i # remain DO
    ReadByte(r.f, r.pos, b, ok);
    IF ok THEN x[i] := b; INC(i); INC(r.pos); INC(got)
    ELSE r.res := remain - got; r.eof := TRUE; i := remain
    END
  END;
  IF got = remain THEN r.res := 0; r.eof := FALSE END
END ReadBytes;

PROCEDURE WriteBytes*(VAR r: Rider; x: ARRAY OF BYTE; n: INTEGER);
VAR i, remain: INTEGER;
BEGIN
  IF n > LEN(x) THEN n := LEN(x) END;
  remain := n; i := 0;
  WHILE i # remain DO
    WriteByte(r.f, r.pos, x[i]);
    INC(r.pos); INC(i)
  END;
  IF r.pos > r.f.len THEN r.f.len := r.pos END;
  r.res := 0
END WriteBytes;

PROCEDURE ReadInt*(VAR r: Rider; VAR x: INTEGER); (**%RU:ЧитатьЦелое,райдер,знач%LV:LasītVesels,jātnieks,vērt*)
VAR b: ARRAY 2 OF BYTE;
BEGIN ReadBytes(r, b, 2);
  x := b[0] + b[1] * 100H;
  IF x >= 8000H THEN x := x - 10000H END
END ReadInt;

PROCEDURE WriteInt*(VAR r: Rider; x: INTEGER); (**%RU:ПисатьЦелое,райдер,знач%LV:RakstītVesels,jātnieks,vērt*)
VAR b: ARRAY 2 OF BYTE;
BEGIN
  b[0] := x MOD 100H; b[1] := x DIV 100H MOD 100H;
  WriteBytes(r, b, 2)
END WriteInt;

PROCEDURE ReadLInt*(VAR r: Rider; VAR x: INTEGER); (**%RU:ЧитатьДлинЦелое,райдер,знач%LV:LasītGarVesels,jātnieks,vērt*)
BEGIN ReadInt(r, x) END ReadLInt;

PROCEDURE WriteLInt*(VAR r: Rider; x: INTEGER); (**%RU:ПисатьДлинЦелое,райдер,знач%LV:RakstītGarVesels,jātnieks,vērt*)
BEGIN WriteInt(r, x) END WriteLInt;

PROCEDURE ReadSet*(VAR r: Rider; VAR x: SET); (**%RU:ЧитатьМнож,райдер,знач%LV:LasītKopa,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE; bits, j: INTEGER;
BEGIN ReadBytes(r, b, 4);
  bits := b[0] + b[1] * 100H + b[2] * 10000H + b[3] * 1000000H;
  x := {}; j := 0;
  WHILE j # 32 DO
    IF bits DIV LSL(1, j) MOD 2 # 0 THEN INCL(x, j) END;
    INC(j)
  END
END ReadSet;

PROCEDURE WriteSet*(VAR r: Rider; x: SET); (**%RU:ПисатьМнож,райдер,знач%LV:RakstītKopa,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE; bits, j: INTEGER;
BEGIN
  bits := 0; j := 0;
  WHILE j # 32 DO
    IF j IN x THEN INC(bits, LSL(1, j)) END;
    INC(j)
  END;
  b[0] := bits MOD 100H; b[1] := bits DIV 100H MOD 100H;
  b[2] := bits DIV 10000H MOD 100H; b[3] := bits DIV 1000000H MOD 100H;
  WriteBytes(r, b, 4)
END WriteSet;

PROCEDURE ReadBool*(VAR r: Rider; VAR x: BOOLEAN); (**%RU:ЧитатьЛог,райдер,знач%LV:LasītLoģ,jātnieks,vērt*)
VAR b: BYTE;
BEGIN Read(r, b); x := b # 0 END ReadBool;

PROCEDURE WriteBool*(VAR r: Rider; x: BOOLEAN); (**%RU:ПисатьЛог,райдер,знач%LV:RakstītLoģ,jātnieks,vērt*)
BEGIN Write(r, ORD(x)) END WriteBool;

PROCEDURE ReadReal*(VAR r: Rider; VAR x: REAL); (**%RU:ЧитатьВещ,райдер,знач%LV:LasītReāls,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE; u: INTEGER;
BEGIN
  ReadBytes(r, b, 4);
  u := b[0] + b[1] * 100H + b[2] * 10000H + b[3] * 1000000H;
  x := SYSTEM.VAL(REAL, u)
END ReadReal;

PROCEDURE WriteReal*(VAR r: Rider; x: REAL); (**%RU:ПисатьВещ,райдер,знач%LV:RakstītReāls,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE; u: INTEGER;
BEGIN
  u := SYSTEM.VAL(INTEGER, x);
  b[0] := u MOD 100H; b[1] := u DIV 100H MOD 100H;
  b[2] := u DIV 10000H MOD 100H; b[3] := u DIV 1000000H MOD 100H;
  WriteBytes(r, b, 4)
END WriteReal;

PROCEDURE ReadLReal*(VAR r: Rider; VAR x: LONGREAL); (**%RU:ЧитатьДлинВещ,райдер,знач%LV:LasītGarReāls,jātnieks,vērt*)
VAR b: ARRAY 8 OF BYTE; u: LONGINT; i: INTEGER;
BEGIN
  ReadBytes(r, b, 8);
  u := 0; i := 0;
  WHILE i # 8 DO
    u := u * 100H + b[i];
    INC(i)
  END;
  x := SYSTEM.VAL(LONGREAL, u)
END ReadLReal;

PROCEDURE WriteLReal*(VAR r: Rider; x: LONGREAL); (**%RU:ПисатьДлинВещ,райдер,знач%LV:RakstītGarReāls,jātnieks,vērt*)
VAR b: ARRAY 8 OF BYTE; u: LONGINT; i: INTEGER;
BEGIN
  u := SYSTEM.VAL(LONGINT, x);
  i := 7;
  WHILE i # -1 DO
    b[i] := u MOD 100H;
    u := u DIV 100H;
    DEC(i)
  END;
  WriteBytes(r, b, 8)
END WriteLReal;

PROCEDURE ReadString*(VAR r: Rider; VAR x: ARRAY OF CHAR); (**%RU:ЧитатьСтроку,райдер,приёмник%LV:LasītVirkni,jātnieks,mērķis*)
VAR i: INTEGER; lo, hi: BYTE; ch: CHAR;
BEGIN
  i := 0;
  WHILE ~r.eof DO
    IF (r.f # NIL) & (r.pos >= r.f.len) THEN r.eof := TRUE
    ELSE
      Read(r, lo);
      IF ~r.eof THEN
        Read(r, hi);
        IF r.eof THEN hi := 0 END;
        ch := CHR(ORD(lo) + ORD(hi) * 100H);
        IF i < LEN(x) THEN x[i] := ch; INC(i) END;
        IF ch = 0X THEN r.eof := TRUE END
      END
    END
  END;
  IF i < LEN(x) THEN x[i] := 0X ELSE x[LEN(x) - 1] := 0X END
END ReadString;

PROCEDURE WriteString*(VAR r: Rider; x: ARRAY OF CHAR); (**%RU:ПисатьСтроку,райдер,источник%LV:RakstītVirkni,jātnieks,avots*)
VAR i: INTEGER; lo, hi: BYTE;
BEGIN
  i := 0;
  WHILE (i # LEN(x)) & (x[i] # 0X) DO
    lo := ORD(x[i]) MOD 100H; hi := ORD(x[i]) DIV 100H MOD 100H;
    Write(r, lo); Write(r, hi); INC(i)
  END;
  Write(r, 0); Write(r, 0)
END WriteString;

PROCEDURE ReadNum*(VAR r: Rider; VAR x: INTEGER); (**%RU:ЧитатьЧисло,райдер,знач%LV:LasītSkaitlis,jātnieks,vērt*)
VAR ch: BYTE; u: INTEGER;
BEGIN
  Read(r, ch);
  u := ORD(ch);
  IF u >= 64 THEN x := -(u - 64) ELSE x := u END
END ReadNum;

PROCEDURE WriteNum*(VAR r: Rider; x: INTEGER); (**%RU:ПисатьЧисло,райдер,знач%LV:RakstītSkaitlis,jātnieks,vērt*)
BEGIN
  IF (x >= -64) & (x <= 63) THEN
    IF x < 0 THEN Write(r, (-x) + 64) ELSE Write(r, x) END
  ELSE Halt('Files.WriteNum range')
  END
END WriteNum;

END Files.
