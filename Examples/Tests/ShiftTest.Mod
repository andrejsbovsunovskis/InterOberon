MODULE ShiftTest;
IMPORT Out;
VAR a, b, res: INTEGER;
BEGIN
  (* 1. LSL: 1 << 4 = 16 *)
  res := LSL(1, 4);
  Out.Int(res, 0); Out.Ln;

  (* 2. LSL: 3 << 8 = 768 *)
  res := LSL(3, 8);
  Out.Int(res, 0); Out.Ln;

  (* 3. ASR: 256 >> 4 = 16 *)
  res := ASR(256, 4);
  Out.Int(res, 0); Out.Ln;

  (* 4. ASR: 1024 >> 3 = 128 *)
  res := ASR(1024, 3);
  Out.Int(res, 0); Out.Ln;

  (* 5. ASR negative: -16 >> 2 = -4 (arithmetic, sign preserved) *)
  res := ASR(-16, 2);
  Out.Int(res, 0); Out.Ln;

  (* 6. LSL with variable: 5 << 3 = 40 *)
  a := 5;
  res := LSL(a, 3);
  Out.Int(res, 0); Out.Ln;

  (* 7. ASR with variable: 80 >> 2 = 20 *)
  a := 80;
  res := ASR(a, 2);
  Out.Int(res, 0); Out.Ln;

  (* 8. LSL then ASR roundtrip: (7 << 5) >> 5 = 7 *)
  res := ASR(LSL(7, 5), 5);
  Out.Int(res, 0); Out.Ln;

  (* 9. Shift by 0 = identity: LSL(42, 0) = 42 *)
  res := LSL(42, 0);
  Out.Int(res, 0); Out.Ln;

  (* 10. ASR by 0 = identity: ASR(99, 0) = 99 *)
  res := ASR(99, 0);
  Out.Int(res, 0); Out.Ln;

  (* 11. Both args as variables: LSL *)
  a := 1; b := 10;
  res := LSL(a, b);
  Out.Int(res, 0); Out.Ln;

  (* 12. Both args as variables: ASR *)
  a := 2048; b := 5;
  res := ASR(a, b);
  Out.Int(res, 0); Out.Ln;

  (* 13. ROR with constants: ROR(1, 1) on 64-bit *)
  (* Rotate right 1 bit: bit0 goes to bit63 *)
  (* Result is a large negative number in signed 64-bit: -9223372036854775808 *)
  (* But we use 32-bit integers, so let's do 256 ROR 4 *)
  a := 256;
  res := ROR(a, 4);
  Out.Int(res, 0); Out.Ln;

  (* 14. LSL large: 1 << 20 = 1048576 *)
  res := LSL(1, 20);
  Out.Int(res, 0); Out.Ln;

  (* 15. ASR large: 1048576 >> 20 = 1 *)
  res := ASR(1048576, 20);
  Out.Int(res, 0); Out.Ln;

  (* 16. Chained: LSL(LSL(1, 3), 2) = 1*8*4 = 32 *)
  res := LSL(LSL(1, 3), 2);
  Out.Int(res, 0); Out.Ln;

  Out.Char('O'); Out.Char('K'); Out.Ln
END ShiftTest.
