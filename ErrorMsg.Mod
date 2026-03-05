MODULE ErrorMsg;

CONST
  (** Compiler error codes **)
  expModule*         = 1;
  expSemicol*        = 2;
  expIdent*          = 3;
  expEnd*            = 4;
  expPeriod*         = 5;
  expColon*          = 6;
  expBecomes*        = 7;
  expType*           = 8;
  expBool*           = 9;
  expThen*           = 10;
  expDo*             = 11;
  expUntil*          = 12;
  expLparen*         = 30;
  expRparen*         = 31;
  expStatement*      = 32;

  notValue*          = 40;
  notInt*            = 41;
  notUsed*           = 42;
  notProcedure*      = 43;

  badDiv*            = 50;
  divByZero*         = 51;
  badVarPar*         = 52;

  assignConst*       = 59;
  incompatible*      = 60;
  undecl*            = 61;
  multipleDecl*      = 62;
  noModule*          = 63;
  noParams*          = 64;
  fewerParams*       = 65;
  moreParams*        = 66;
  onlyEqlNeq*        = 67;

  modNameMismatch*   = 90;
  unknownLang*       = 91;

  longString*        = 110;
  intOverflow*       = 111;
  regOverflow*       = 112;
  outOfMemory*       = 113;

  unknownKW*         = 114;
  stringTodo*        = 115;
  badTransLang*      = 116;
  expColonTrans*     = 117;
  commentNotClosed*  = 118;
  longTransName*     = 119;
  badTransName*      = 120;

  (** Compiler message codes **)
  compileOk1*        = 1;
  compileOk2*        = 2;
  compileFail*       = 3;
  fileNotLoaded*     = 4;
  linkFail*          = 5;
  cantCreateFile*    = 6;
  invalidObjFile*    = 7;
  linkComplete*      = 8;
  cantOpenObj*       = 9;
  cantCreateSym*     = 10;
  chmodFailed*       = 11;
  signFailed*        = 12;

END ErrorMsg.
