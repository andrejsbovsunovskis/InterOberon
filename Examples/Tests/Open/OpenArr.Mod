MODULE OpenArr;
(* 1D open-array params: value/VAR, LEN, forwarding. *)
IMPORT Out;
VAR
  a: ARRAY 5 OF INTEGER;
  b: ARRAY 3 OF INTEGER;
  bytes: ARRAY 6 OF BYTE;
  i: INTEGER;

PROCEDURE Sum(x: ARRAY OF INTEGER): INTEGER;
VAR i, s: INTEGER;
BEGIN s := 0;
  FOR i := 0 TO LEN(x) - 1 DO s := s + x[i] END
RETURN s END Sum;

PROCEDURE Max(x: ARRAY OF INTEGER): INTEGER;
VAR i, m: INTEGER;
BEGIN m := x[0];
  FOR i := 1 TO LEN(x) - 1 DO IF x[i] > m THEN m := x[i] END END
RETURN m END Max;

PROCEDURE FillSquares(VAR x: ARRAY OF INTEGER);
VAR i: INTEGER;
BEGIN FOR i := 0 TO LEN(x) - 1 DO x[i] := (i + 1) * (i + 1) END
END FillSquares;

PROCEDURE Reverse(VAR x: ARRAY OF INTEGER);
VAR i, j, t: INTEGER;
BEGIN i := 0; j := LEN(x) - 1;
  WHILE i < j DO t := x[i]; x[i] := x[j]; x[j] := t; INC(i); DEC(j) END
END Reverse;

PROCEDURE ByteSum(x: ARRAY OF BYTE): INTEGER;
VAR i, s: INTEGER;
BEGIN s := 0;
  FOR i := 0 TO LEN(x) - 1 DO s := s + x[i] END
RETURN s END ByteSum;

PROCEDURE Length(x: ARRAY OF INTEGER): INTEGER;
RETURN LEN(x) END Length;

PROCEDURE SumPlusMax(x: ARRAY OF INTEGER): INTEGER;
RETURN Sum(x) + Max(x) END SumPlusMax;

PROCEDURE FwdLen(x: ARRAY OF INTEGER): INTEGER;
RETURN Length(x) END FwdLen;

PROCEDURE FillAndReverse(VAR x: ARRAY OF INTEGER);
BEGIN FillSquares(x); Reverse(x)
END FillAndReverse;

PROCEDURE DoubleByteSum(x: ARRAY OF BYTE): INTEGER;
RETURN ByteSum(x) * 2 END DoubleByteSum;

BEGIN
  a[0] := 10; a[1] := 20; a[2] := 30; a[3] := 40; a[4] := 50;
  Out.Int(Sum(a), 0); Out.Ln;              (* 150 *)
  Out.Int(Max(a), 0); Out.Ln;              (* 50 *)
  Out.Int(Length(a), 0); Out.Ln;           (* 5 *)

  b[0] := 7; b[1] := 3; b[2] := 9;
  Out.Int(Sum(b), 0); Out.Ln;              (* 19 *)
  Out.Int(Max(b), 0); Out.Ln;              (* 9 *)
  Out.Int(Length(b), 0); Out.Ln;           (* 3 *)

  FillSquares(a);                          (* a := [1,4,9,16,25] *)
  Reverse(a);                              (* a := [25,16,9,4,1] *)
  FOR i := 0 TO 4 DO Out.Int(a[i], 0); Out.Char(" ") END;
  Out.Ln;                                  (* 25 16 9 4 1 *)

  FOR i := 0 TO 5 DO bytes[i] := i * 10 END;
  Out.Int(ByteSum(bytes), 0); Out.Ln;      (* 150 *)

  (* Forwarding: arrays already carry hidden lengths at this point. *)
  Out.Int(SumPlusMax(a), 0); Out.Ln;       (* 55 + 25 = 80 *)
  Out.Int(FwdLen(b), 0); Out.Ln;           (* 3 *)

  FillAndReverse(b);                       (* b := [9, 4, 1] *)
  FOR i := 0 TO 2 DO Out.Int(b[i], 0); Out.Char(" ") END;
  Out.Ln;                                  (* 9 4 1 *)

  Out.Int(DoubleByteSum(bytes), 0); Out.Ln (* 300 *)
END OpenArr.
