MODULE Algo;
IMPORT Out;
CONST
  MaxArr = 20;
VAR
  a: ARRAY MaxArr OF INTEGER;
  i, j, n, tmp: INTEGER;
BEGIN
  (* 1. GCD using Euclid's algorithm: GCD(48, 18) = 6 *)
  i := 48; j := 18;
  WHILE j # 0 DO
    tmp := j;
    j := i MOD j;
    i := tmp
  END;
  Out.Int(i, 0); Out.Ln;

  (* 2. Factorial of 10 = 3628800 *)
  n := 1;
  FOR i := 1 TO 10 DO
    n := n * i
  END;
  Out.Int(n, 0); Out.Ln;

  (* 3. Fibonacci: 1 1 2 3 5 8 13 21 *)
  i := 1; j := 1;
  Out.Int(i, 0); Out.Char(' ');
  Out.Int(j, 0); Out.Char(' ');
  n := 0;
  WHILE n < 6 DO
    tmp := i + j;
    i := j;
    j := tmp;
    Out.Int(j, 0); Out.Char(' ');
    n := n + 1
  END;
  Out.Ln;

  (* 4. Power: 2^10 = 1024 *)
  n := 1;
  FOR i := 1 TO 10 DO
    n := n * 2
  END;
  Out.Int(n, 0); Out.Ln;

  (* 5. Sum of digits of 12345 = 15 *)
  i := 12345;
  n := 0;
  WHILE i > 0 DO
    n := n + i MOD 10;
    i := i DIV 10
  END;
  Out.Int(n, 0); Out.Ln;

  (* 6. Reverse digits: 1234 → print 4321 *)
  i := 1234;
  WHILE i > 0 DO
    Out.Int(i MOD 10, 0);
    i := i DIV 10
  END;
  Out.Ln;

  (* 7. Count primes up to 30 using sieve-like approach *)
  (* Primes: 2,3,5,7,11,13,17,19,23,29 = 10 *)
  n := 0;
  FOR i := 2 TO 30 DO
    j := 2;
    tmp := 1;  (* assume prime *)
    WHILE j * j <= i DO
      IF i MOD j = 0 THEN tmp := 0 END;
      j := j + 1
    END;
    IF tmp = 1 THEN n := n + 1 END
  END;
  Out.Int(n, 0); Out.Ln;

  (* 8. Binary representation of 42 = 101010: count set bits = 3 *)
  i := 42; n := 0;
  WHILE i > 0 DO
    IF ODD(i) THEN n := n + 1 END;
    i := i DIV 2
  END;
  Out.Int(n, 0); Out.Ln;

  (* 9. Selection sort *)
  a[0] := 9; a[1] := 7; a[2] := 5; a[3] := 3; a[4] := 1;
  FOR i := 0 TO 3 DO
    n := i;
    FOR j := i + 1 TO 4 DO
      IF a[j] < a[n] THEN n := j END
    END;
    IF n # i THEN
      tmp := a[i]; a[i] := a[n]; a[n] := tmp
    END
  END;
  FOR i := 0 TO 4 DO
    Out.Int(a[i], 0); Out.Char(' ')
  END;
  Out.Ln;

  (* 10. Collatz steps for 27: how many steps to reach 1 *)
  i := 27; n := 0;
  WHILE i # 1 DO
    IF ODD(i) THEN
      i := 3 * i + 1
    ELSE
      i := i DIV 2
    END;
    n := n + 1
  END;
  Out.Int(n, 0); Out.Ln
END Algo.
