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
  | str (head : ScalarPtr) (tail : ScalarPtr)
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

def hashString (s : String) : HashM ScalarPtr := do
  match (← get).stringCache.find? s with
  | some ptr => pure ptr
  | none => match s with
    | ⟨[]⟩ => return ⟨Tag.str, F.zero⟩
    | ⟨c :: cs⟩ => do
      let head ← hashChar c
      let tail ← hashString ⟨cs⟩
      let ptr := ⟨Tag.str, hashPtrPair head tail⟩
      modifyGet fun stt =>
        (ptr, { stt with stringCache := stt.stringCache.insert s ptr })

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
  | eq    => "eq"

def SExpr.toExpr : SExpr → Expr
  | .lit l => .lit l
  | .cons a b => .cons a.toExpr (.cons b.toExpr (.lit .nil))

def mkExprFromBinders (binders : List (Name × Expr)) : Expr :=
  .mkList $ binders.map fun (n, e) => .mkList [.sym n, e]

partial def hashExpr : Expr → HashM ScalarPtr
  | .lit .nil => do
    let ptr ← hashExpr (.sym `nil)
    addToStore ⟨Tag.nil, ptr.val⟩ .nil
  | .lit .t => do
    let ptr ← hashString "t"
    addToStore ⟨Tag.sym, ptr.val⟩ (.sym ptr)
  | .lit (.num n) => addToStore ⟨Tag.num, n⟩ (.num n)
  | .lit (.str ⟨s⟩) => do
    let (headPtr, tailPtr) ← match s with
      | c :: cs => pure (← hashChar c, ← hashString ⟨cs⟩)
      | [] => pure (← hashString "", ⟨Tag.str, F.zero⟩)
    let ptr := ⟨Tag.str, hashPtrPair headPtr tailPtr⟩
    let expr := .str headPtr tailPtr
    addToStore ptr expr
  | .lit (.char c) => do
    let ptr ← hashChar c
    addToStore ptr (.char ptr.val)
  | .sym name => do
    let ptr ← hashString (name.toString false)
    addToStore ⟨Tag.sym, ptr.val⟩ (.sym ptr)
  | .quote se => hashExpr $ .mkList [.sym `quote, se.toExpr]
  | .binaryOp op a b => hashExpr $ .mkList [.sym op.toString, a, b]
  | .cons    a b => do
    let aPtr ← hashExpr a
    let bPtr ← hashExpr b
    let ptr := ⟨Tag.cons, hashPtrPair aPtr bPtr⟩
    addToStore ptr (.cons aPtr bPtr)
  | .strcons a b => hashExpr $ .mkList [.sym `strcons, a, b]
  | .hide    a b => hashExpr $ .mkList [.sym `hide,    a, b]
  | .begin   a b => hashExpr $ .mkList [.sym `begin,   a, b]
  | .comm   expr => hashExpr $ .mkList [.sym `comm,   expr]
  | .atom   expr => hashExpr $ .mkList [.sym `atom,   expr]
  | .car    expr => hashExpr $ .mkList [.sym `car,    expr]
  | .cdr    expr => hashExpr $ .mkList [.sym `cdr,    expr]
  | .emit   expr => hashExpr $ .mkList [.sym `emit,   expr]
  | .commit expr => hashExpr $ .mkList [.sym `commit, expr]
  | .currEnv => hashExpr $ .sym "current-env"
  | .ifE a b c => hashExpr $ .mkList [.sym `if, a, b, c]
  | .app fn none => hashExpr $ .mkList [fn]
  | .app fn (some arg) => hashExpr $ .mkList [fn, arg]
  | .lam args body => hashExpr $ .mkList [.sym `lambda, .mkList $ args.map .sym, body]
  | .letE    binders body => hashExpr $ .mkList [.sym `let,    mkExprFromBinders binders, body]
  | .letRecE binders body => hashExpr $ .mkList [.sym `letrec, mkExprFromBinders binders, body]
  | .mutRecE binders body => hashExpr $ .mkList [.sym `mutrec, mkExprFromBinders binders, body]

def Expr.hash (e : Expr) : ScalarStore × ScalarPtr := Id.run do
  match ← StateT.run (hashExpr e) default with
  | (ptr, stt) => (stt.store, ptr)

end Lurk