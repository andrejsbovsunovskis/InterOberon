MODULE PartLv;

IMPORT Out, PartCore;

BEGIN
  PartCore.IestatTot(7);
  Out.Int(PartCore.Alpha(PartCore.Baze), 0); Out.Ln;
  Out.Int(PartCore.Beta(2), 0); Out.Ln;
  PartCore.ShowTotal
END PartLv.
