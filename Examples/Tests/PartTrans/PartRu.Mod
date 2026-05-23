MODULE PartRu;

IMPORT Out, PartCore;

BEGIN
  PartCore.SetTotal(5);
  Out.Int(PartCore.Альфа(PartCore.База), 0); Out.Ln;
  Out.Int(PartCore.Beta(3), 0); Out.Ln;
  PartCore.ShowTotal
END PartRu.
