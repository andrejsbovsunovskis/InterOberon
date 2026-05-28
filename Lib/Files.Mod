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
  sysChdir = 12;
  sysLseek = 199;
  sysFtruncate = 201;
  sysRename = 128;
  sysFstat = 345;

  oRdWr = 2;
  oCreat = 200H;
  oTrunc = 400H;
  fileMode = 1A4H;
  seekSet = 0;
  seekCur = 1;
  seekEnd = 2;

  statAtime = 80;
  statMtime = 96;
  statCtime = 112;
  statBirth = 128;

TYPE
  File* = POINTER TO FileDesc; (**%RU:Файл%LV:Fails*)
  Rider* = RECORD (**%RU:Бегунок%LV:Bīdnis*)
    eof*: BOOLEAN; (**%RU:конец%LV:beigas*)
    res*: INTEGER; (**%RU:рез%LV:rez*)
    f: File; (**%RU:ф*)
    pos: LONGINT; (**%RU:поз%LV:poz*)
    pending: CHAR (**%RU:ожидает%LV:gaida*)
  END;

  FileDesc = RECORD (**%RU:ОписьФайла%LV:FailaApr*)
    regName: ARRAY 256 OF CHAR; (**%RU:регИмя%LV:regVārds*)
    fd: INTEGER; (**%RU:фд%LV:fd*)
    len: LONGINT; (**%RU:длина%LV:garums*)
    memLen: INTEGER; (**%RU:длПам%LV:atmGar*)
    memOnly: BOOLEAN; (**%RU:толькоПам%LV:tikaiAtm*)
    mem: ARRAY maxMem OF BYTE (**%RU:память%LV:atmiņa*)
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

PROCEDURE NormRes(err: LONGINT): INTEGER;
VAR r: INTEGER;
BEGIN
  IF err = 0 THEN r := 0
  ELSIF err = 2 THEN r := 2
  ELSE r := 1
  END
RETURN r END NormRes;

PROCEDURE SysOpen(name: ARRAY OF CHAR; flags: INTEGER): LONGINT;
VAR path: ARRAY 1024 OF BYTE; r: LONGINT;
BEGIN
  IF PathUtf8(name, path) = 0 THEN r := invalidFd
  ELSE r := SYSTEM.SVC(sysOpen, SYSTEM.ADR(path), flags, fileMode)
  END
RETURN r END SysOpen;

PROCEDURE SysClose(fd: INTEGER): LONGINT;
RETURN SYSTEM.SVC(sysClose, fd, 0, 0) END SysClose;

PROCEDURE SysRead(fd: INTEGER; VAR buf: ARRAY OF BYTE; n: INTEGER): LONGINT;
RETURN SYSTEM.SVC(sysRead, fd, SYSTEM.ADR(buf), n) END SysRead;

PROCEDURE SysWrite(fd: INTEGER; buf: ARRAY OF BYTE; n: INTEGER): LONGINT;
RETURN SYSTEM.SVC(sysWrite, fd, SYSTEM.ADR(buf), n) END SysWrite;

PROCEDURE SysUnlink(name: ARRAY OF CHAR): LONGINT;
VAR path: ARRAY 1024 OF BYTE; r: LONGINT;
BEGIN
  IF PathUtf8(name, path) = 0 THEN r := 1
  ELSE r := SYSTEM.SVC(sysUnlink, SYSTEM.ADR(path), 0, 0)
  END
RETURN r END SysUnlink;

PROCEDURE SysRename(old, new: ARRAY OF CHAR): LONGINT;
VAR p0, p1: ARRAY 1024 OF BYTE; r: LONGINT;
BEGIN
  IF PathUtf8(old, p0) = 0 THEN r := 1
  ELSIF PathUtf8(new, p1) = 0 THEN r := 1
  ELSE r := SYSTEM.SVC(sysRename, SYSTEM.ADR(p0), SYSTEM.ADR(p1), 0)
  END
RETURN r END SysRename;

PROCEDURE SysSeek(fd: INTEGER; pos: LONGINT): LONGINT;
RETURN SYSTEM.SVC(sysLseek, fd, pos, seekSet) END SysSeek;

PROCEDURE SysTruncate(fd: INTEGER; pos: LONGINT): LONGINT;
VAR p: INTEGER;
BEGIN
  p := SHORT(pos);
  RETURN SYSTEM.SVC(sysFtruncate, fd, p, 0)
END SysTruncate;

PROCEDURE FdLength(fd: INTEGER): LONGINT;
VAR cur, sz: LONGINT;
BEGIN
  cur := SYSTEM.SVC(sysLseek, fd, 0, seekCur);
  sz := SYSTEM.SVC(sysLseek, fd, 0, seekEnd);
  IF cur >= 0 THEN IF SYSTEM.SVC(sysLseek, fd, cur, seekSet) = 0 THEN END END;
  IF sz < 0 THEN sz := 0 END
RETURN sz END FdLength;

PROCEDURE ReadSec(buf: ARRAY OF BYTE; off: INTEGER): LONGINT;
RETURN ORD(buf[off]) + ORD(buf[off + 1]) * 100H + ORD(buf[off + 2]) * 10000H
    + ORD(buf[off + 3]) * 1000000H + ORD(buf[off + 4]) * 100000000H
    + ORD(buf[off + 5]) * 10000000000H + ORD(buf[off + 6]) * 1000000000000H
    + ORD(buf[off + 7]) * 100000000000000H END ReadSec;

PROCEDURE PackDate(sec: LONGINT): LONGINT;
VAR z, era, doe, yoe, doy, moe: LONGINT;
  y, mo, d, h, mi, s: INTEGER;
BEGIN
  s := SHORT(sec MOD 60); sec := sec DIV 60;
  mi := SHORT(sec MOD 60); sec := sec DIV 60;
  h := SHORT(sec MOD 24); z := sec DIV 24;
  z := z + 719468;
  era := z DIV 146097;
  doe := z - era * 146097;
  yoe := (doe - doe DIV 1460 + doe DIV 36524 - doe DIV 146096) DIV 365;
  y := SHORT(yoe + era * 400);
  doy := doe - (365 * yoe + yoe DIV 4 - yoe DIV 100 + yoe DIV 400);
  moe := (5 * doy + 2) DIV 153;
  d := SHORT(doy - (153 * moe + 2) DIV 5 + 1);
  IF moe < 10 THEN mo := SHORT(moe + 3) ELSE mo := SHORT(moe - 9) END;
  IF mo <= 2 THEN INC(y) END
RETURN s + mi * 64 + h * 4096 + d * 20000H + mo * 400000H + (y MOD 100) * 4000000H END PackDate;

PROCEDURE FstatSec(f: File; off: INTEGER): LONGINT;
VAR buf: ARRAY 144 OF BYTE; sec: LONGINT;
BEGIN
  sec := 0;
  IF (f # NIL) & ~f.memOnly & (f.fd # invalidFd) THEN
    IF SYSTEM.SVC(sysFstat, f.fd, SYSTEM.ADR(buf), 0) = 0 THEN sec := ReadSec(buf, off) END
  END
RETURN sec END FstatSec;

PROCEDURE OpenRegistered(f: File);
VAR fd: INTEGER; n: LONGINT;
BEGIN
  IF f.memOnly THEN
    fd := SHORT(SysOpen(f.regName, oRdWr + oCreat + oTrunc));
    IF fd < 0 THEN Halt('Files.Register open') END;
    IF f.memLen > 0 THEN
      n := SysWrite(fd, f.mem, f.memLen);
      IF n # f.memLen THEN Halt('Files.Register write') END
    END;
    f.fd := fd;
    f.len := f.memLen;
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
  fd := SHORT(SysOpen(name, oRdWr));
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

PROCEDURE Truncate*(f: File; pos: LONGINT); (**%RU:Усечь,файл,поз%LV:Saspiest,fails,poz*)
VAR i: INTEGER;
BEGIN
  IF f # NIL THEN
    IF f.memOnly THEN
      IF pos < f.len THEN
        f.len := pos;
        IF pos < f.memLen THEN f.memLen := SHORT(pos) END
      ELSIF pos > f.len THEN
        i := SHORT(f.len);
        WHILE i # pos DO
          IF i < maxMem THEN f.mem[i] := 0 END;
          INC(i)
        END;
        f.len := pos;
        IF pos <= maxMem THEN f.memLen := SHORT(pos) END
      END
    ELSIF f.fd # invalidFd THEN
      IF SysTruncate(f.fd, pos) = 0 THEN END;
      f.len := pos
    END
  END
END Truncate;

PROCEDURE Delete*(name: ARRAY OF CHAR; VAR res: INTEGER); (**%RU:Удалить,имя,рез%LV:Dzēst,vārds,rez*)
BEGIN res := NormRes(SysUnlink(name)) END Delete;

PROCEDURE Rename*(old, new: ARRAY OF CHAR; VAR res: INTEGER); (**%RU:Переименовать,стар,нов,рез%LV:Pārdēvēt,vecs,jauns,rez*)
BEGIN res := NormRes(SysRename(old, new)) END Rename;

PROCEDURE ChangeDirectory*(path: ARRAY OF CHAR; VAR res: INTEGER); (**%RU:СменитьКаталог,путь,рез%LV:MainītKatalogu,ceļš,rez*)
VAR q: ARRAY 1024 OF BYTE;
BEGIN
  IF PathUtf8(path, q) = 0 THEN res := 1
  ELSE res := NormRes(SYSTEM.SVC(sysChdir, SYSTEM.ADR(q), 0, 0))
  END
END ChangeDirectory;

PROCEDURE GetName*(f: File; VAR name: ARRAY OF CHAR); (**%RU:Имя,файл,буф%LV:Vārds,fails,buf*)
BEGIN
  IF f = NIL THEN name[0] := 0X ELSE CopyName(f.regName, name) END
END GetName;

PROCEDURE Length*(f: File): LONGINT; (**%RU:Длина,файл%LV:Garums,fails*)
VAR n: LONGINT;
BEGIN
  IF f = NIL THEN n := 0
  ELSIF f.memOnly THEN n := f.len
  ELSE n := FdLength(f.fd)
  END
RETURN n END Length;

PROCEDURE Date*(f: File): LONGINT; (**%RU:ДатаСоздания,файл%LV:IzveidesDatums,fails*)
RETURN PackDate(FstatSec(f, statBirth)) END Date;

PROCEDURE DateModified*(f: File): LONGINT; (**%RU:ДатаИзмен,файл%LV:ModificDatums,fails*)
RETURN PackDate(FstatSec(f, statMtime)) END DateModified;

PROCEDURE DateAccessed*(f: File): LONGINT; (**%RU:ДатаДоступа,файл%LV:PiekļuvesDatums,fails*)
RETURN PackDate(FstatSec(f, statAtime)) END DateAccessed;

PROCEDURE DateChanged*(f: File): LONGINT; (**%RU:ДатаСтатуса,файл%LV:StatusaDatums,fails*)
RETURN PackDate(FstatSec(f, statCtime)) END DateChanged;

PROCEDURE ModTime*(name: ARRAY OF CHAR): LONGINT; (**%RU:ВремяМод,имя%LV:ModLaiks,vārds*)
VAR fd: INTEGER;
  buf: ARRAY 144 OF BYTE;
  t: LONGINT;
BEGIN
  t := 0;
  fd := SHORT(SysOpen(name, 0));
  IF fd >= 0 THEN
    IF SYSTEM.SVC(sysFstat, fd, SYSTEM.ADR(buf), 0) = 0 THEN t := ReadSec(buf, statMtime) END;
    IF SysClose(fd) = 0 THEN END
  END
RETURN t END ModTime;

PROCEDURE GetDate*(f: File; VAR t, d: LONGINT); (**%RU:Дата,файл,время,дата%LV:Datums,fails,laiks,datums*)
BEGIN
  IF f = NIL THEN t := 0 ELSE t := FstatSec(f, statMtime) END;
  d := PackDate(t)
END GetDate;

PROCEDURE Set*(VAR r: Rider; f: File; pos: LONGINT); (**%RU:Установить,райдер,файл,поз%LV:Iestatīt,jātnieks,fails,poz*)
BEGIN
  r.f := f; r.pos := pos; r.eof := FALSE; r.res := 0; r.pending := 0X;
  IF (f # NIL) & (pos > f.len) THEN r.pos := f.len END;
  IF (f # NIL) & ~f.memOnly & (f.fd # invalidFd) THEN
    IF SysSeek(f.fd, r.pos) = r.pos THEN END
  END
END Set;

PROCEDURE Pos*(VAR r: Rider): LONGINT; (**%RU:Позиция,райдер%LV:Pozīcija,jātnieks*)
RETURN r.pos END Pos;

PROCEDURE Base*(VAR r: Rider): File; (**%RU:База,райдер%LV:Bāze,jātnieks*)
RETURN r.f END Base;

PROCEDURE ReadAt(f: File; pos: LONGINT; VAR b: BYTE; VAR ok: BOOLEAN);
VAR n: LONGINT; i: INTEGER; buf: ARRAY 1 OF BYTE;
BEGIN
  ok := FALSE;
  IF f.memOnly THEN
    i := SHORT(pos);
    IF (i >= 0) & (i < f.memLen) THEN b := f.mem[i]; ok := TRUE END
  ELSIF f.fd # invalidFd THEN
    IF pos >= f.len THEN ok := FALSE
    ELSIF SysSeek(f.fd, pos) = pos THEN
      n := SysRead(f.fd, buf, 1);
      IF n = 1 THEN b := buf[0]; ok := TRUE ELSE ok := FALSE END
    END
  END
END ReadAt;

PROCEDURE WriteAt(f: File; pos: LONGINT; b: BYTE);
VAR n: LONGINT; i: INTEGER; buf: ARRAY 1 OF BYTE;
BEGIN
  IF f.memOnly THEN
    i := SHORT(pos);
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
END WriteAt;

PROCEDURE Read*(VAR r: Rider; VAR x: BYTE); (**%RU:Читать,райдер,байт%LV:Lasīt,jātnieks,baits*)
VAR ok: BOOLEAN;
BEGIN
  ReadAt(r.f, r.pos, x, ok);
  IF ok THEN INC(r.pos) ELSE x := 0; r.eof := TRUE END
END Read;

PROCEDURE Write*(VAR r: Rider; x: BYTE); (**%RU:Писать,райдер,байт%LV:Rakstīt,jātnieks,baits*)
BEGIN
  WriteAt(r.f, r.pos, x);
  INC(r.pos);
  IF r.pos > r.f.len THEN r.f.len := r.pos END;
  r.eof := FALSE; r.res := 0
END Write;

PROCEDURE ReadBytes*(VAR r: Rider; VAR x: ARRAY OF BYTE; offset, len: INTEGER): INTEGER; (**%RU:ЧитатьБайты,райдер,буф,смещ,длина%LV:LasītBaitus,jātnieks,buf,poz,garums*)
VAR i, got, remain: INTEGER; b: BYTE; ok: BOOLEAN;
BEGIN
  got := 0; remain := len; i := 0;
  WHILE i # remain DO
    ReadAt(r.f, r.pos, b, ok);
    IF ok THEN
      IF (offset + i >= 0) & (offset + i < LEN(x)) THEN x[offset + i] := b END;
      INC(r.pos); INC(got); INC(i)
    ELSE r.eof := TRUE; i := remain
    END
  END;
  IF got # len THEN r.res := len - got ELSE r.res := 0 END
RETURN got END ReadBytes;

PROCEDURE WriteBytes*(VAR r: Rider; x: ARRAY OF BYTE; offset, len: INTEGER): INTEGER; (**%RU:ПисатьБайты,райдер,буф,смещ,длина%LV:RakstītBaitus,jātnieks,buf,poz,garums*)
VAR i, remain, wrote: INTEGER;
BEGIN
  remain := len; i := 0; wrote := 0;
  WHILE i # remain DO
    IF (offset + i >= 0) & (offset + i < LEN(x)) THEN
      WriteAt(r.f, r.pos, x[offset + i]);
      INC(r.pos); INC(wrote)
    END;
    INC(i)
  END;
  IF r.pos > r.f.len THEN r.f.len := r.pos END;
  r.res := 0
RETURN wrote END WriteBytes;

PROCEDURE RdBytes(VAR r: Rider; VAR x: ARRAY OF BYTE; offset, len: INTEGER);
VAR n: INTEGER;
BEGIN n := ReadBytes(r, x, offset, len) END RdBytes;

PROCEDURE WrBytes(VAR r: Rider; x: ARRAY OF BYTE; offset, len: INTEGER);
VAR n: INTEGER;
BEGIN n := WriteBytes(r, x, offset, len) END WrBytes;

PROCEDURE ReadInt*(VAR r: Rider; VAR x: INTEGER); (**%RU:ЧитатьЦелое,райдер,знач%LV:LasītVesels,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE;
BEGIN
  RdBytes(r, b, 0, 4);
  x := b[0] + b[1] * 100H + b[2] * 10000H + b[3] * 1000000H;
  IF x >= 80000000H THEN x := x - 100000000H END
END ReadInt;

PROCEDURE WriteInt*(VAR r: Rider; x: INTEGER); (**%RU:ПисатьЦелое,райдер,знач%LV:RakstītVesels,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE;
BEGIN
  b[0] := x MOD 100H; b[1] := x DIV 100H MOD 100H;
  b[2] := x DIV 10000H MOD 100H; b[3] := x DIV 1000000H MOD 100H;
  WrBytes(r, b, 0, 4)
END WriteInt;

PROCEDURE ReadShortInt*(VAR r: Rider; VAR x: SHORTINT); (**%RU:ЧитатьКорЦелое,райдер,знач%LV:LasītĪssVesels,jātnieks,vērt*)
VAR b: ARRAY 2 OF BYTE; i: INTEGER;
BEGIN
  RdBytes(r, b, 0, 2);
  i := b[0] + b[1] * 100H;
  IF i >= 8000H THEN i := i - 10000H END;
  x := SHORT(i)
END ReadShortInt;

PROCEDURE WriteShortInt*(VAR r: Rider; x: SHORTINT); (**%RU:ПисатьКорЦелое,райдер,знач%LV:RakstītĪssVesels,jātnieks,vērt*)
VAR b: ARRAY 2 OF BYTE; i: INTEGER;
BEGIN
  i := x;
  b[0] := i MOD 100H; b[1] := i DIV 100H MOD 100H;
  WrBytes(r, b, 0, 2)
END WriteShortInt;

PROCEDURE ReadLInt*(VAR r: Rider; VAR x: LONGINT); (**%RU:ЧитатьДлинЦелое,райдер,знач%LV:LasītGarVesels,jātnieks,vērt*)
VAR b: ARRAY 8 OF BYTE; u: LONGINT; i: INTEGER;
BEGIN
  RdBytes(r, b, 0, 8);
  u := 0; i := 0;
  WHILE i # 8 DO
    u := u * 100H + b[i];
    INC(i)
  END;
  x := u
END ReadLInt;

PROCEDURE WriteLInt*(VAR r: Rider; x: LONGINT); (**%RU:ПисатьДлинЦелое,райдер,знач%LV:RakstītGarVesels,jātnieks,vērt*)
VAR b: ARRAY 8 OF BYTE; u: LONGINT; i: INTEGER;
BEGIN
  u := x; i := 7;
  WHILE i # -1 DO
    b[i] := SHORT(u MOD 100H);
    u := u DIV 100H;
    DEC(i)
  END;
  WrBytes(r, b, 0, 8)
END WriteLInt;

PROCEDURE SetBits(VAR x: SET; bits, n: INTEGER);
VAR j: INTEGER;
BEGIN
  x := {}; j := 0;
  WHILE j # n DO
    IF bits DIV LSL(1, j) MOD 2 # 0 THEN INCL(x, j) END;
    INC(j)
  END
END SetBits;

PROCEDURE GetBits(x: SET; n: INTEGER): INTEGER;
VAR bits, j: INTEGER;
BEGIN
  bits := 0; j := 0;
  WHILE j # n DO
    IF j IN x THEN INC(bits, LSL(1, j)) END;
    INC(j)
  END
RETURN bits END GetBits;

PROCEDURE ReadTinySet*(VAR r: Rider; VAR x: SET); (**%RU:ЧитатьМикроМнож,райдер,знач%LV:LasītMikroKopa,jātnieks,vērt*)
VAR b: BYTE;
BEGIN Read(r, b); SetBits(x, ORD(b), 8) END ReadTinySet;

PROCEDURE WriteTinySet*(VAR r: Rider; x: SET); (**%RU:ПисатьМикроМнож,райдер,знач%LV:RakstītMikroKopa,jātnieks,vērt*)
BEGIN Write(r, SHORT(GetBits(x, 8))) END WriteTinySet;

PROCEDURE ReadShortSet*(VAR r: Rider; VAR x: SET); (**%RU:ЧитатьКорМнож,райдер,знач%LV:LasītĪsaKopa,jātnieks,vērt*)
VAR b: ARRAY 2 OF BYTE; bits: INTEGER;
BEGIN
  RdBytes(r, b, 0, 2);
  bits := b[0] + b[1] * 100H;
  SetBits(x, bits, 16)
END ReadShortSet;

PROCEDURE WriteShortSet*(VAR r: Rider; x: SET); (**%RU:ПисатьКорМнож,райдер,знач%LV:RakstītĪsaKopa,jātnieks,vērt*)
VAR b: ARRAY 2 OF BYTE; bits: INTEGER;
BEGIN
  bits := GetBits(x, 16);
  b[0] := SHORT(bits MOD 100H); b[1] := SHORT(bits DIV 100H MOD 100H);
  WrBytes(r, b, 0, 2)
END WriteShortSet;

PROCEDURE ReadSet*(VAR r: Rider; VAR x: SET); (**%RU:ЧитатьМнож,райдер,знач%LV:LasītKopa,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE; bits: INTEGER;
BEGIN
  RdBytes(r, b, 0, 4);
  bits := b[0] + b[1] * 100H + b[2] * 10000H + b[3] * 1000000H;
  SetBits(x, bits, 32)
END ReadSet;

PROCEDURE WriteSet*(VAR r: Rider; x: SET); (**%RU:ПисатьМнож,райдер,знач%LV:RakstītKopa,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE; bits: INTEGER;
BEGIN
  bits := GetBits(x, 32);
  b[0] := SHORT(bits MOD 100H); b[1] := SHORT(bits DIV 100H MOD 100H);
  b[2] := SHORT(bits DIV 10000H MOD 100H); b[3] := SHORT(bits DIV 1000000H MOD 100H);
  WrBytes(r, b, 0, 4)
END WriteSet;

PROCEDURE ReadLongSet*(VAR r: Rider; VAR x: SET); (**%RU:ЧитатьДлинМнож,райдер,знач%LV:LasītGarKopa,jātnieks,vērt*)
VAR b: ARRAY 8 OF BYTE; bits: INTEGER;
BEGIN
  RdBytes(r, b, 0, 8);
  bits := b[0] + b[1] * 100H + b[2] * 10000H + b[3] * 1000000H;
  SetBits(x, bits, 32)
END ReadLongSet;

PROCEDURE WriteLongSet*(VAR r: Rider; x: SET); (**%RU:ПисатьДлинМнож,райдер,знач%LV:RakstītGarKopa,jātnieks,vērt*)
VAR b: ARRAY 8 OF BYTE; bits: INTEGER; i: INTEGER;
BEGIN
  bits := GetBits(x, 32); i := 0;
  WHILE i # 8 DO b[i] := 0; INC(i) END;
  b[0] := SHORT(bits MOD 100H); b[1] := SHORT(bits DIV 100H MOD 100H);
  b[2] := SHORT(bits DIV 10000H MOD 100H); b[3] := SHORT(bits DIV 1000000H MOD 100H);
  WrBytes(r, b, 0, 8)
END WriteLongSet;

PROCEDURE ReadBool*(VAR r: Rider; VAR x: BOOLEAN); (**%RU:ЧитатьЛог,райдер,знач%LV:LasītLoģ,jātnieks,vērt*)
VAR b: BYTE;
BEGIN Read(r, b); x := b # 0 END ReadBool;

PROCEDURE WriteBool*(VAR r: Rider; x: BOOLEAN); (**%RU:ПисатьЛог,райдер,знач%LV:RakstītLoģ,jātnieks,vērt*)
BEGIN Write(r, ORD(x)) END WriteBool;

PROCEDURE ReadReal*(VAR r: Rider; VAR x: REAL); (**%RU:ЧитатьВещ,райдер,знач%LV:LasītReāls,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE; u: INTEGER;
BEGIN
  RdBytes(r, b, 0, 4);
  u := b[0] + b[1] * 100H + b[2] * 10000H + b[3] * 1000000H;
  x := SYSTEM.VAL(REAL, u)
END ReadReal;

PROCEDURE WriteReal*(VAR r: Rider; x: REAL); (**%RU:ПисатьВещ,райдер,знач%LV:RakstītReāls,jātnieks,vērt*)
VAR b: ARRAY 4 OF BYTE; u: INTEGER;
BEGIN
  u := SYSTEM.VAL(INTEGER, x);
  b[0] := u MOD 100H; b[1] := u DIV 100H MOD 100H;
  b[2] := u DIV 10000H MOD 100H; b[3] := u DIV 1000000H MOD 100H;
  WrBytes(r, b, 0, 4)
END WriteReal;

PROCEDURE ReadLReal*(VAR r: Rider; VAR x: LONGREAL); (**%RU:ЧитатьДлинВещ,райдер,знач%LV:LasītGarReāls,jātnieks,vērt*)
VAR b: ARRAY 8 OF BYTE; u: LONGINT; i: INTEGER;
BEGIN
  RdBytes(r, b, 0, 8);
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
    b[i] := SHORT(u MOD 100H);
    u := u DIV 100H;
    DEC(i)
  END;
  WrBytes(r, b, 0, 8)
END WriteLReal;

PROCEDURE ReadChar*(VAR r: Rider; VAR x: CHAR); (**%RU:ЧитатьСимвол,райдер,символ%LV:LasītZīmi,jātnieks,zīme*)
VAR buf: ARRAY 8 OF BYTE; n, need, i: INTEGER; hi, lo: CHAR; ok, fail: BOOLEAN;
BEGIN
  x := 0X; fail := FALSE;
  IF r.pending # 0X THEN x := r.pending; r.pending := 0X
  ELSE
    n := 0; need := 1;
    WHILE (n # need) & ~fail DO
      ReadAt(r.f, r.pos + n, buf[n], ok);
      IF ~ok THEN r.eof := TRUE; fail := TRUE
      ELSE
        IF n = 0 THEN need := Utf8.SeqLen(buf[n]) END;
        INC(n)
      END
    END;
    IF ~fail THEN
      i := Utf8.DecodeCharEx(buf, 0, hi, lo);
      IF i <= 0 THEN x := Utf8.replacementChar
      ELSE
        r.pos := r.pos + i;
        IF lo # 0X THEN r.pending := lo END;
        x := hi
      END
    END
  END
END ReadChar;

PROCEDURE WriteChar*(VAR r: Rider; x: CHAR); (**%RU:ПисатьСимвол,райдер,символ%LV:RakstītZīmi,jātnieks,zīme*)
VAR buf: ARRAY 4 OF BYTE; n, i: INTEGER;
BEGIN
  n := Utf8.EncodeChar(x, buf, 0);
  IF n > 0 THEN
    i := 0;
    WHILE i # n DO Write(r, buf[i]); INC(i) END
  END
END WriteChar;

PROCEDURE ReadString*(VAR r: Rider; VAR x: ARRAY OF CHAR); (**%RU:ЧитатьСтроку,райдер,приёмник%LV:LasītVirkni,jātnieks,mērķis*)
VAR buf: ARRAY maxMem OF BYTE; n, used: INTEGER; b: BYTE; stop: BOOLEAN;
BEGIN
  n := 0; stop := FALSE;
  WHILE (n # LEN(buf) - 1) & ~r.eof & ~stop DO
    Read(r, b);
    IF r.eof THEN stop := TRUE
    ELSE
      buf[n] := b; INC(n);
      IF b = 0 THEN stop := TRUE END
    END
  END;
  used := Utf8.Decode(buf, 0, n, x, 0, LEN(x) - 1);
  IF used < 0 THEN x[0] := 0X END
END ReadString;

PROCEDURE WriteString*(VAR r: Rider; x: ARRAY OF CHAR); (**%RU:ПисатьСтроку,райдер,источник%LV:RakstītVirkni,jātnieks,avots*)
VAR buf: ARRAY 512 OF BYTE; n, used: INTEGER;
BEGIN
  n := 0;
  WHILE (n # LEN(x)) & (x[n] # 0X) DO INC(n) END;
  used := Utf8.Encode(x, 0, n, buf, 0, LEN(buf) - 1);
  IF used > 0 THEN WrBytes(r, buf, 0, used) END;
  Write(r, 0)
END WriteString;

PROCEDURE ReadNum*(VAR r: Rider; VAR x: LONGINT); (**%RU:ЧитатьЧисло,райдер,знач%LV:LasītSkaitlis,jātnieks,vērt*)
VAR n, i, part: INTEGER; b: BYTE; v: LONGINT;
BEGIN
  n := 0; v := 0; Read(r, b);
  WHILE b >= 128 DO
    part := ORD(b) - 128; i := 0;
    WHILE i # n DO part := part * 2; INC(i) END;
    v := v + part;
    INC(n, 7); Read(r, b)
  END;
  part := ORD(b) MOD 64 - ORD(b) DIV 64 * 64; i := 0;
  WHILE i # n DO part := part * 2; INC(i) END;
  v := v + part;
  x := v
END ReadNum;

PROCEDURE WriteNum*(VAR r: Rider; x: LONGINT); (**%RU:ПисатьЧисло,райдер,знач%LV:RakstītSkaitlis,jātnieks,vērt*)
VAR sx: INTEGER; done: BOOLEAN;
BEGIN
  done := FALSE;
  WHILE ~done DO
    sx := SHORT(x);
    IF (x = sx) & (sx >= -64) & (sx <= 63) THEN Write(r, SHORT(x MOD 128)); done := TRUE
    ELSE Write(r, SHORT(x MOD 128 + 128)); x := x DIV 128
    END
  END
END WriteNum;

END Files.
