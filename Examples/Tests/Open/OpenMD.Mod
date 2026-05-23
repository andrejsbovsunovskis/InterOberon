MODULE OpenMD;
(* Multidim open arrays: partial/full open, LEN, forwarding, slices. *)
IMPORT Out;
VAR
  m: ARRAY 3, 4 OF INTEGER;       (* partial- and fully-open 2D tests *)
  m25: ARRAY 2, 5 OF INTEGER;     (* fully-open 2D, different shape   *)
  m43: ARRAY 4, 3 OF INTEGER;     (* partial-open, non-pow2 stride    *)
  m73: ARRAY 7, 3 OF INTEGER;     (* same shape, different outer len  *)
  m3d: ARRAY 2, 3, 4 OF INTEGER;  (* 3D tests (full + partial-open)   *)
  mb: ARRAY 2, 2, 3 OF BYTE;      (* fully-open 3D BYTE test          *)
  mb43: ARRAY 4, 3 OF BYTE;       (* partial-open BYTE, non-pow2 inner*)
  i, j, k: INTEGER;

(* Partial-open 2D: inner dimension is fixed at 4. *)
PROCEDURE SumFix4(x: ARRAY OF ARRAY 4 OF INTEGER): INTEGER;
VAR i, j, r: INTEGER;
BEGIN r := 0;
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO r := r + x[i, j] END
  END
RETURN r END SumFix4;

(* Partial-open 2D, inner dim 3 (non-pow2 stride). *)
PROCEDURE SumFix3(x: ARRAY OF ARRAY 3 OF INTEGER): INTEGER;
VAR i, j, r: INTEGER;
BEGIN r := 0;
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO r := r + x[i, j] END
  END
RETURN r END SumFix3;

(* VAR partial-open 2D, inner dim closed. *)
PROCEDURE FillFix4(VAR x: ARRAY OF ARRAY 4 OF INTEGER);
VAR i, j: INTEGER;
BEGIN
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO x[i, j] := i + j END
  END
END FillFix4;

(* Partial-open 2D of BYTE, inner dim 3. *)
PROCEDURE SumByteFix3(x: ARRAY OF ARRAY 3 OF BYTE): INTEGER;
VAR i, j, r: INTEGER;
BEGIN r := 0;
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO r := r + x[i, j] END
  END
RETURN r END SumByteFix3;

(* Forward partial-open 2D formal. *)
PROCEDURE SumFix4Fwd(x: ARRAY OF ARRAY 4 OF INTEGER): INTEGER;
RETURN SumFix4(x) END SumFix4Fwd;

(* 3D: two open dims, innermost fixed at 4. *)
PROCEDURE Sum3DFix4(x: ARRAY OF ARRAY OF ARRAY 4 OF INTEGER): INTEGER;
VAR i, j, k, r: INTEGER;
BEGIN r := 0;
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO
      FOR k := 0 TO LEN(x[0, 0]) - 1 DO r := r + x[i, j, k] END
    END
  END
RETURN r END Sum3DFix4;

(* Fully-open 1D, used to receive a sub-array of a higher-dim actual. *)
PROCEDURE Sum1D(x: ARRAY OF INTEGER): INTEGER;
VAR i, r: INTEGER;
BEGIN r := 0;
  FOR i := 0 TO LEN(x) - 1 DO r := r + x[i] END
RETURN r END Sum1D;

PROCEDURE Fill1D(VAR x: ARRAY OF INTEGER);
VAR i: INTEGER;
BEGIN FOR i := 0 TO LEN(x) - 1 DO x[i] := i + 1 END
END Fill1D;

(* Fully-open 2D. *)
PROCEDURE Sum2D(x: ARRAY OF ARRAY OF INTEGER): INTEGER;
VAR i, j, r: INTEGER;
BEGIN r := 0;
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO r := r + x[i, j] END
  END
RETURN r END Sum2D;

PROCEDURE Fill2D(VAR x: ARRAY OF ARRAY OF INTEGER);
VAR i, j: INTEGER;
BEGIN
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO x[i, j] := i * 100 + j END
  END
END Fill2D;

PROCEDURE Zero2D(VAR x: ARRAY OF ARRAY OF INTEGER);
VAR i, j: INTEGER;
BEGIN
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO x[i, j] := 0 END
  END
END Zero2D;

(* Forwards a fully-open VAR 2D to another fully-open VAR 2D procedure. *)
PROCEDURE SumThenZero(VAR x: ARRAY OF ARRAY OF INTEGER): INTEGER;
VAR r: INTEGER;
BEGIN r := Sum2D(x); Zero2D(x)
RETURN r END SumThenZero;

(* Fully-open 3D. *)
PROCEDURE Sum3D(x: ARRAY OF ARRAY OF ARRAY OF INTEGER): INTEGER;
VAR i, j, k, r: INTEGER;
BEGIN r := 0;
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO
      FOR k := 0 TO LEN(x[0, 0]) - 1 DO r := r + x[i, j, k] END
    END
  END
RETURN r END Sum3D;

(* Forwards a value 3D actual to another value 3D formal. *)
PROCEDURE Sum3DFwd(x: ARRAY OF ARRAY OF ARRAY OF INTEGER): INTEGER;
RETURN Sum3D(x) END Sum3DFwd;

(* Fully-open 3D of BYTE. *)
PROCEDURE SumB3D(x: ARRAY OF ARRAY OF ARRAY OF BYTE): INTEGER;
VAR i, j, k, r: INTEGER;
BEGIN r := 0;
  FOR i := 0 TO LEN(x) - 1 DO
    FOR j := 0 TO LEN(x[0]) - 1 DO
      FOR k := 0 TO LEN(x[0, 0]) - 1 DO r := r + x[i, j, k] END
    END
  END
RETURN r END SumB3D;

BEGIN
  (* 3x4 matrix: m[i, j] := 10i + j. Sum = 138. *)
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO m[i, j] := i * 10 + j END
  END;

  (* Same matrix, seen via partial-open and fully-open formals. *)
  Out.Int(SumFix4(m), 0); Out.Ln;        (* 138 *)
  Out.Int(Sum2D(m), 0); Out.Ln;          (* 138 *)

  (* Fully-open 2D on a different shape via VAR fill. *)
  Fill2D(m25);                            (* m25[i, j] := 100i + j *)
  Out.Int(Sum2D(m25), 0); Out.Ln;        (* (0+1+2+3+4)+(100+101+102+103+104) = 520 *)

  (* Forwarding VAR 2D: sum then zero; then re-sum the now-zero matrix. *)
  Out.Int(SumThenZero(m), 0); Out.Ln;    (* 138 *)
  Out.Int(Sum2D(m), 0); Out.Ln;          (* 0 *)

  (* Fully-open 3D: m3d[i, j, k] := 100i + 10j + k. *)
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO
      FOR k := 0 TO 3 DO m3d[i, j, k] := i * 100 + j * 10 + k END
    END
  END;
  Out.Int(Sum3D(m3d), 0); Out.Ln;        (* 1476 *)
  Out.Int(Sum3DFwd(m3d), 0); Out.Ln;     (* 1476 via forwarding *)

  (* Slicing: pass a 2D sub-array of m3d to a fully-open 2D formal.
     m3d[0] covers j,k in [0..2]x[0..3], so its sum is 0+1+2+3 + 10+11+12+13
     + 20+21+22+23 = 138. *)
  Out.Int(Sum2D(m3d[0]), 0); Out.Ln;     (* 138 *)
  Out.Int(Sum2D(m3d[1]), 0); Out.Ln;     (* same shape, +1200 = 1338 *)

  (* Slicing: pass a 1D row of m3d to a fully-open 1D formal. *)
  Out.Int(Sum1D(m3d[0, 1]), 0); Out.Ln;  (* 10+11+12+13 = 46 *)
  Out.Int(Sum1D(m3d[1, 2]), 0); Out.Ln;  (* 120+121+122+123 = 486 *)

  (* Slicing into a VAR open-array formal: fill m3d[0, 0] := [1,2,3,4]
     and confirm via a 1D Sum, then re-sum the whole 3D. *)
  Fill1D(m3d[0, 0]);
  Out.Int(Sum1D(m3d[0, 0]), 0); Out.Ln;  (* 1+2+3+4 = 10 *)
  (* Original m3d[0, 0] was 0+1+2+3 = 6, so 3D sum changes by +4 to 1480. *)
  Out.Int(Sum3D(m3d), 0); Out.Ln;        (* 1480 *)

  (* Fully-open 3D BYTE: mb[i, j, k] := 4i + 2j + k + 1. *)
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 1 DO
      FOR k := 0 TO 2 DO mb[i, j, k] := i * 4 + j * 2 + k + 1 END
    END
  END;
  Out.Int(SumB3D(mb), 0); Out.Ln;        (* 60 *)

  (* === Partial-open (open-of-closed) coverage === *)

  (* Non-pow2 inner dim, INTEGER: m43[i, j] := 3i + j.
     Rows: 0,1,2 / 3,4,5 / 6,7,8 / 9,10,11 -> 0..11 -> sum = 66. *)
  FOR i := 0 TO 3 DO
    FOR j := 0 TO 2 DO m43[i, j] := i * 3 + j END
  END;
  Out.Int(SumFix3(m43), 0); Out.Ln;      (* 66 *)

  (* Same partial-open formal, different outer length: m73[i, j] := i + j.
     Row i sums to 3i + 3, total over i = 0..6 is 3*21 + 3*7 = 63 + 21 = 84. *)
  FOR i := 0 TO 6 DO
    FOR j := 0 TO 2 DO m73[i, j] := i + j END
  END;
  Out.Int(SumFix3(m73), 0); Out.Ln;      (* 84 *)

  (* VAR partial-open: m was zeroed by SumThenZero earlier; refill via
     a VAR partial-open formal, then re-sum via fully-open 2D.
     m[i, j] := i + j over 3x4 -> rows sum 6, 10, 14 -> total = 30. *)
  FillFix4(m);
  Out.Int(Sum2D(m), 0); Out.Ln;          (* 30 *)

  (* Forwarding: partial-open actual into partial-open formal, which
     then forwards into another partial-open formal. *)
  Out.Int(SumFix4Fwd(m), 0); Out.Ln;     (* 30 *)

  (* Partial-open BYTE with non-pow2 inner: mb43[i, j] := 3i + j + 1.
     Values are 1..12, sum = 78. *)
  FOR i := 0 TO 3 DO
    FOR j := 0 TO 2 DO mb43[i, j] := i * 3 + j + 1 END
  END;
  Out.Int(SumByteFix3(mb43), 0); Out.Ln; (* 78 *)

  (* 3D with closed innermost dim: m3d at this point sums to 1480
     (after Fill1D(m3d[0, 0]) above). Same elements, same total. *)
  Out.Int(Sum3DFix4(m3d), 0); Out.Ln;    (* 1480 *)

  (* Slicing 3D into partial-open 2D: m3d[0] as ARRAY OF ARRAY 4 OF T.
     Original m3d[0] sum was 138; m3d[0, 0] was changed by Fill1D from
     [0,1,2,3] (sum 6) to [1,2,3,4] (sum 10), so m3d[0] sum = 142. *)
  Out.Int(SumFix4(m3d[0]), 0); Out.Ln    (* 142 *)
END OpenMD.
