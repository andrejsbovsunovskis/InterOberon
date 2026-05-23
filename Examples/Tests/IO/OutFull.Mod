MODULE OutFull;
IMPORT Out;

BEGIN
  Out.Open;
  Out.String('--- Int ---'); Out.Ln;
  Out.Int(0, 0);     Out.Ln;
  Out.Int(42, 0);    Out.Ln;
  Out.Int(-42, 0);   Out.Ln;
  Out.Int(42, 1);    Out.Ln;
  Out.Int(42, 5);    Out.Ln;
  Out.Int(-42, 5);   Out.Ln;
  Out.Int(123456, 4); Out.Ln;

  Out.String('--- Hex ---'); Out.Ln;
  Out.Hex(0, 0);     Out.Ln;
  Out.Hex(0, 4);     Out.Ln;
  Out.Hex(15, 0);    Out.Ln;
  Out.Hex(16, 0);    Out.Ln;
  Out.Hex(255, 0);   Out.Ln;
  Out.Hex(255, 4);   Out.Ln;
  Out.Hex(0DEADH, 8); Out.Ln;
  Out.Hex(0100000000H, 0); Out.Ln;
  Out.Hex(-1, 0);    Out.Ln;
  Out.Hex(-16, 0);   Out.Ln;
  Out.Hex(-1, 20);   Out.Ln;

  Out.String('--- Real ---'); Out.Ln;
  Out.Real(0.0, 0); Out.Ln;
  Out.Real(1.5, 0); Out.Ln;
  Out.Real(-1.5, 10); Out.Ln;
  Out.Real(3.14159, 12); Out.Ln;

  Out.String('--- RealFix ---'); Out.Ln;
  Out.RealFix(0.0, 0, 3); Out.Ln;
  Out.RealFix(1.5, 0, 3); Out.Ln;
  Out.RealFix(-1.5, 0, 3); Out.Ln;
  Out.RealFix(3.14159, 0, 2); Out.Ln;
  Out.RealFix(0.5, 10, 4); Out.Ln;

  Out.String('--- LongReal ---'); Out.Ln;
  Out.LongReal(2.5, 0); Out.Ln;
  Out.LongRealFix(2.5, 0, 2); Out.Ln;

  Out.String('--- Char ---'); Out.Ln;
  Out.Char('A'); Out.Char('B'); Out.Ln;

  Out.String('--- String ---'); Out.Ln;
  Out.String('Hi!'); Out.Ln;

  Out.String('--- Flush ---'); Out.Ln;
  Out.Flush;
  Out.String('done'); Out.Ln
END OutFull.
