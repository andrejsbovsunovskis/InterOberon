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
  expEql*            = 15;
  expBool*           = 9;
  expThen*           = 10;
  expDo*             = 11;
  expUntil*          = 12;
  expOf*             = 13;
  expTo*             = 14;
  expLparen*         = 30;
  expRparen*         = 31;
  expStatement*      = 32;
  expRbrace*         = 33;

  notValue*          = 40;
  notInt*            = 41;
  notUsed*           = 42;
  notProcedure*      = 43;

  badDiv*            = 50;
  divByZero*         = 51;
  badVarPar*         = 52;

  readOnly*          = 53;
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

  stringTooLong*     = 131;
  incompatibleArray* = 132;
  illegalRelation*   = 133;
  badTransLang*      = 116;
  expColonTrans*     = 117;
  commentNotClosed*  = 118;
  longTransName*     = 119;
  badTransName*      = 120;
  badHex*            = 121;

  expLbrak*          = 122;
  expRbrak*          = 123;
  notArray*          = 124;
  indexOutOfBounds*  = 125;
  expConst*          = 127;
  tooManyParams*     = 128;
  procNameMismatch*  = 129;
  outerLocalAccess*  = 130;

  notRecord*         = 134; (** Designator before '.' is not a record *)
  notField*          = 135; (** Identifier after '.' is not a field of the record *)
  notPointer*        = 136; (** Designator before '^' is not a pointer *)
  expBaseRecord*     = 137; (** POINTER TO X — X is not a record type *)
  pendingPointer*    = 138; (** Forward POINTER TO X never resolved at end of TYPE section *)
  tooManyTransIds*   = 139; (** More translation names than pending declared objects *)
  transStickyMulti*  = 140; (** Sticky translation comment has more than one name *)
  transExtraComment* = 141; (** Extra translation comment while hadSticky follow-up is pending *)
  transAfterStickyMulti* = 142; (** After sticky: follow-up comment must have one name only *)
  transModuleOne*    = 143; (** MODULE translation must have exactly one name per language *)

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
  cantOpenSym*       = 13;
  badSymFile*        = 14;
  importCycle*       = 15;
  cmdNotFound*       = 16;
  cmdAmbiguous*      = 17;
  fileNotFound*      = 18;
  multipleExt*       = 19;
  cmdHasParams*      = 20;
  cmdHasReturn*      = 21;
  noModuleForCmd*    = 22;
  badCmdSpec*        = 23;
  symHashMismatch*   = 24;
  exportTooDeep*     = 25;
  compileSkip*       = 26;
  inModule*          = 27;
  hasNoCommand*      = 28;

END ErrorMsg.
