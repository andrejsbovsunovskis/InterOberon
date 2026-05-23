MODULE FormalTrans; (**%RU:ФормТранс%LV:FormTrans*)

IMPORT Out;

CONST
  Base* = 10; (**%RU:База%LV:Baze*)
  Pi = 314; (**%RU:Пи%LV:Pi*)
  N = 5; M = 6; (**%RU:н,м*)

TYPE
  MyType* = INTEGER; (**%RU:МойТип%LV:MansTips*)
  AnotherType = INTEGER; (**%RU:ДругойТип*)
  HelloType = INTEGER; (**%RU:ПриветТип*)
  Rec* = RECORD
    x(**%RU:икс*), y(**%RU:игрек*): INTEGER;
    a(**%RU:аз*), b(**%RU:бэ*): INTEGER
  END; (**%RU:Запись%LV:Ieraksts*)
  RecHead* = RECORD (**%RU:ЗаписьВНачале%LV:IerakstsSakuma*)
    x(**%RU:икс*), y(**%RU:игрек*): INTEGER;
    a(**%RU:аз*), b(**%RU:бэ*): INTEGER
  END;

VAR r: Rec;
  rh: RecHead;
  sum: INTEGER;

PROCEDURE P*(x: MyType; y: INTEGER; z: AnotherType): HelloType; (**%RU:П,икс,игрек,зет*)
BEGIN RETURN x + y + z + Base END P;

PROCEDURE Q(**%RU:Ку*)(x, a(**%RU:аз*): INTEGER): INTEGER;
BEGIN RETURN x + a END Q;

PROCEDURE R(  (**%RU:Эр*)
  x, a: INTEGER;  (**%RU:икс,аз*)
  z: MyType  (**%RU:зед*)
): INTEGER;
BEGIN RETURN x + a + z END R;

PROCEDURE S(x, y: INTEGER): INTEGER; (**%RU:Эс,икс,игрек*)
BEGIN RETURN x + y END S;

PROCEDURE T(x, y: INTEGER): INTEGER; (**%RU:Тэ,икс*)
BEGIN RETURN x + y END T;

PROCEDURE U*(x: RECORD i, j: INTEGER END;
  w: ARRAY 5 OF RECORD n: INTEGER END): INTEGER; (**%RU:У,икс,и,й,ве,эн*)
BEGIN RETURN 0 END U;

PROCEDURE V*(w: PROCEDURE(x: INTEGER)): INTEGER; (**%RU:Вэ,ве,икс*)
BEGIN RETURN 0 END V;

PROCEDURE PNested(
  q, w, t: INTEGER;
  x: PROCEDURE(a: INTEGER): INTEGER
); (**%RU:П*)
BEGIN END PNested;

PROCEDURE W(x, y: INTEGER): INTEGER; (**%RU: ДаблЮ , икс , игрек *)
BEGIN RETURN x + y END W;

BEGIN
  r.x := 10; r.y := 20; r.a := 1; r.b := 2;
  rh.x := 3; rh.y := 4; rh.a := 5; rh.b := 6;
  sum := P(1, 2, 3) + Q(4, 5) + R(6, 7, 8) + S(9, 10)
       + T(1, 1) + r.x + r.y + r.a + r.b
       + rh.x + rh.y + rh.a + rh.b;
  Out.Int(sum, 0); Out.Ln
END FormalTrans.
