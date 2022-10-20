import Lurk.AST
import Lurk.Utils
import Lurk.Hashing.Markers
import Poseidon.ForLurk

namespace Lurk

instance : Coe F' F := ⟨.ofInt⟩

structure ScalarPtr where
  kind : F
  val  : F
  deriving Inhabited, Ord, BEq, Repr

inductive ScalarExpr
  | nil
  | cons (car : ScalarPtr) (cdr : ScalarPtr)
  | comm (x : F) (ptr : ScalarPtr)
  | sym (sym : ScalarPtr)
  | «fun» (arg : ScalarPtr) (body : ScalarPtr) (env : ScalarPtr)
  | num (val : F)
  | strCons (head : ScalarPtr) (tail : ScalarPtr)
  | strNil
  | char (x : F)
  deriving BEq, Repr

def hashPtrPair (x y : ScalarPtr) : F :=
  Hash x.kind x.val y.kind y.val

open Std in
structure ScalarStore where
  exprs : RBMap ScalarPtr ScalarExpr compare
  -- conts : RBMap ScalarContPtr ScalarCont compare
  deriving Inhabited

open Std in
structure HashState where
  exprs       : RBMap ScalarPtr ScalarExpr compare
  charCache   : RBMap Char   ScalarPtr compare
  stringCache : RBMap String ScalarPtr compare
  deriving Inhabited

def HashState.store (stt : HashState) : ScalarStore :=
  ⟨stt.exprs⟩

abbrev HashM := StateM HashState

def hashChar (c : Char) : HashM ScalarPtr := do
  match (← get).charCache.find? c with
  | some ptr => pure ptr
  | none =>
    let ptr := ⟨Tag.char, .ofNat c.val.toNat⟩
    modifyGet fun stt =>
      (ptr, { stt with charCache := stt.charCache.insert c ptr })

def addToStore (ptr : ScalarPtr) (expr : ScalarExpr) : HashM ScalarPtr :=
  modifyGet fun stt =>
    (ptr, { stt with exprs := stt.exprs.insert ptr expr })

def BinaryOp.toString : BinaryOp → String
  | sum   => "+"
  | diff  => "-"
  | prod  => "*"
  | quot  => "/"
  | numEq => "="
  | lt    => "<"
  | gt    => ">"
  | le    => "<="
  | ge    => ">="
  | eq    => "EQ"

def SExpr.toExpr : SExpr → Expr
  | .lit l => .lit l
  | .cons a b => .cons a.toExpr (.cons b.toExpr (.lit .nil))

def mkExprFromBinders (binders : List (Name × Expr)) : Expr :=
  .mkList $ binders.map fun (n, e) => .mkList [.sym n, e]

mutual

partial def hashString (s : String) : HashM ScalarPtr := do
  match (← get).stringCache.find? s with
  | some ptr => pure ptr
  | none =>
    let ptr ← hashExpr (.lit $ .str s)
    modifyGet fun stt =>
      (ptr, { stt with stringCache := stt.stringCache.insert s ptr })

partial def hashExpr : Expr → HashM ScalarPtr
  | .lit .nil => do
    let ptr ← hashExpr (.sym `NIL)
    addToStore ⟨Tag.nil, ptr.val⟩ .nil
  | .lit .t => do
    let ptr ← hashString "t"
    addToStore ⟨Tag.sym, ptr.val⟩ (.sym ptr)
  | .lit (.num n) => addToStore ⟨Tag.num, n⟩ (.num n)
  | .lit (.str ⟨s⟩) => do
    match s with
    | c :: cs =>
      let headPtr ← hashChar c
      let tailPtr ← hashString ⟨cs⟩
      let ptr := ⟨Tag.str, hashPtrPair headPtr tailPtr⟩
      let expr := .strCons headPtr tailPtr
      addToStore ptr expr
    | [] => addToStore ⟨Tag.str, F.zero⟩ .strNil
  | .lit (.char c) => do
    let ptr ← hashChar c
    addToStore ptr (.char ptr.val)
  | .sym name => do
    let ptr ← hashString (name.toString false)
    addToStore ⟨Tag.sym, ptr.val⟩ (.sym ptr)
  | .cons    a b => do
    let aPtr ← hashExpr a
    let bPtr ← hashExpr b
    let ptr := ⟨Tag.cons, hashPtrPair aPtr bPtr⟩
    addToStore ptr (.cons aPtr bPtr)
  | .binaryOp op a b => hashExpr $ .mkList [.sym op.toString, a, b]
  | .quote se => hashExpr $ .mkList [.sym `QUOTE, se.toExpr]
  | .strcons a b => hashExpr $ .mkList [.sym `STRCONS, a, b]
  | .hide    a b => hashExpr $ .mkList [.sym `HIDE,    a, b]
  | .begin   a b => hashExpr $ .mkList [.sym `BEGIN,   a, b]
  | .comm   expr => hashExpr $ .mkList [.sym `COMM,   expr]
  | .atom   expr => hashExpr $ .mkList [.sym `ATOM,   expr]
  | .car    expr => hashExpr $ .mkList [.sym `CAR,    expr]
  | .cdr    expr => hashExpr $ .mkList [.sym `CDR,    expr]
  | .emit   expr => hashExpr $ .mkList [.sym `EMIT,   expr]
  | .commit expr => hashExpr $ .mkList [.sym `COMMIT, expr]
  | .currEnv => hashExpr $ .sym "CURRENT-ENV"
  | .ifE a b c => hashExpr $ .mkList [.sym `IF, a, b, c]
  | .app fn none => hashExpr $ .mkList [fn]
  | .app fn (some arg) => hashExpr $ .mkList [fn, arg]
  | .lam args body => hashExpr $ .mkList [.sym `LAMBDA, .mkList $ args.map .sym, body]
  | .letE    binders body => hashExpr $ .mkList [.sym `LET,    mkExprFromBinders binders, body]
  | .letRecE binders body => hashExpr $ .mkList [.sym `LETREC, mkExprFromBinders binders, body]
  | .mutRecE binders body => hashExpr $ .mkList [.sym `MUTREC, mkExprFromBinders binders, body]

end

def Expr.hash (e : Expr) : ScalarStore × ScalarPtr := Id.run do
  match ← StateT.run (hashExpr e) default with
  | (ptr, stt) => (stt.store, ptr)

end Lurk
