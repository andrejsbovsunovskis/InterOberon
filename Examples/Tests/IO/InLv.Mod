MODULIS InLv;
IMPORTĒ Ievade, Izvade;

MAINĪGIE
  i: VESELAIS;
  c: LITERA;
  r: REĀLAIS;
  rinda: MASĪVS 64 NO LITERA;
SĀKUMS
  Ievade.Atvērt;
  Ievade.Litera(c); Izvade.Virkne('--- Litera ---'); Izvade.Pārnese;
  Izvade.Veselais(ORD(c), 0); Izvade.Pārnese;
  Ievade.Veselais(i); Izvade.Virkne('--- Veselais ---'); Izvade.Pārnese;
  Izvade.Veselais(i, 0); Izvade.Pārnese;
  Ievade.Veselais(i); Izvade.Veselais(i, 0); Izvade.Pārnese;
  Ievade.Rinda(rinda);
  Izvade.Virkne('--- Rinda ---'); Izvade.Pārnese;
  Izvade.Virkne(rinda); Izvade.Pārnese;
  Ievade.Rinda(rinda); Izvade.Virkne(rinda); Izvade.Pārnese;
  Ievade.Reālais(r); Izvade.Virkne('--- Reālais ---'); Izvade.Pārnese;
  Izvade.ReālaisFix(r, 0, 1); Izvade.Pārnese;
  Izvade.Virkne('--- Pabeigts ---'); Izvade.Pārnese;
  JA Ievade.Pabeigts TAD Izvade.Virkne('jā') CITĀDI Izvade.Virkne('nē') BEIGAS;
  Izvade.Pārnese
BEIGAS InLv.
