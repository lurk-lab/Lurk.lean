import Lurk.Hashing.Hashing

namespace Lurk.Hashing

open Lurk.Syntax

def hashString' (s : String) (state : HashState) : ScalarPtr × HashState :=
  StateT.run (hashString s) state

def knownSymbols := [
  "nil",
  "t",
  "quote",
  "lambda",
  -- "_",
  "let",
  "letrec",
  "mutrec",
  "begin",
  "hide",
  "cons",
  "strcons",
  "car",
  "cdr",
  "commit",
  -- "num",
  "comm",
  -- "char",
  -- "open",
  -- "secret",
  "atom",
  "emit",
  "+",
  "-",
  "*",
  "/",
  "=",
  "<",
  ">",
  "<=",
  ">=",
  "eq",
  "current-env",
  "if"
  -- "terminal",
  -- "dummy",
  -- "outermost",
  -- "error"
]

structure Context where
  store : ScalarStore
  memo  : Std.RBMap ScalarPtr String compare

abbrev State := Std.RBMap ScalarPtr Expr compare

abbrev DecodeM := ReaderT Context $ ExceptT String $ StateM State

partial def unfoldCons (ptr : ScalarPtr) (acc : Array ScalarPtr := #[]) :
    DecodeM $ Array ScalarPtr := do
  match (← read).store.exprs.find? ptr with
  | some (.cons h ⟨.nil, _⟩) => return acc.push h
  | some (.cons h t) => unfoldCons t (acc.push h)
  | some x => throw s!"Invalid expression on a cons chain:\n  {x}"
  | none => throw s!"Pointer not found on the store:\n  {ptr}"

mutual

partial def decodeExpr (ptr : ScalarPtr) : DecodeM Expr := do
  let ctx ← read
  match ctx.store.exprs.find? ptr with
  | none => throw s!"Pointer not found on the store:\n  {ptr}"
  | some expr => match (ptr.tag, expr) with
    | (.nil, .sym ptr') => match ctx.memo.find? ptr' with
      | some "nil" => return .lit .nil
      | _ => throw s!"Pointer incompatible with nil:\n  {ptr'}"
    | (.num, .num x) => return .lit $ .num x
    | (.char, .char x) => return .lit $ .char (Char.ofNat x)
    | (.sym, .sym x) => match ← getOrDecodeExpr x with
      | .lit $ .str s => return .sym s
      | _ => throw s!"Invalid pointer for a symbol:\n  {x}"
    | (.str, .strCons h t) => match (← getOrDecodeExpr h, ← getOrDecodeExpr t) with
      | (.lit $ .char h, .lit $ .str t) => return .lit $ .str ⟨h :: t.data⟩
      | _ => throw "Error when decoding string"
    | (.str, .strNil) =>
      if ptr.val == F.zero then return .lit $ .str ""
      else throw s!"Invalid pointer for empty string:\n  {ptr}"
    | (.cons, .cons car cdr) => match ctx.memo.find? car with
      | some sym => decodeExprOf sym cdr
      | none => throw s!"Pointer not found on memo:\n {car}"
    | _ => throw s!"Pointer tag {ptr.tag} incompatible with expression:\n  {expr}"

partial def decodeExprOf (carSym : String) (cdrPtr : ScalarPtr) : DecodeM Expr := do
  match (carSym, ← unfoldCons cdrPtr) with
  | ("nil", #[]) => return .lit .nil
  | ("t", #[]) => return .lit .t
  | ("quote", _) => sorry
  | ("lambda", #[args, body]) => sorry
  | ("let", _) => sorry
  | ("letrec", _) => sorry
  | ("mutrec", _) => sorry
  | ("begin", _) => sorry
  | ("hide", #[a, b]) => return .hide (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("cons", #[a, b]) => return .cons (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("strcons", #[a, b]) => return .strcons (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("car", #[e]) => return .car (← getOrDecodeExpr e)
  | ("cdr", #[e]) => return .cdr (← getOrDecodeExpr e)
  | ("commit", #[e]) => return .commit (← getOrDecodeExpr e)
  -- | ("num", _) => sorry
  | ("comm", #[e]) => return .comm (← getOrDecodeExpr e)
  -- | ("char", _) => sorry
  -- | ("open", _) => sorry
  -- | ("secret", _) => sorry
  | ("atom", #[e]) => return .atom (← getOrDecodeExpr e)
  | ("emit", #[e]) => return .emit (← getOrDecodeExpr e)
  | ("+", #[a, b]) => return .binaryOp .sum (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("-", #[a, b]) => return .binaryOp .diff (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("*", #[a, b]) => return .binaryOp .prod (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("/", #[a, b]) => return .binaryOp .quot (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("=", #[a, b]) => return .binaryOp .numEq (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("<", #[a, b]) => return .binaryOp .lt (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | (">", #[a, b]) => return .binaryOp .gt (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("<=", #[a, b]) => return .binaryOp .le (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | (">=", #[a, b]) => return .binaryOp .ge (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("eq", #[a, b]) => return .binaryOp .eq (← getOrDecodeExpr a) (← getOrDecodeExpr b)
  | ("current-env", #[]) => return .currEnv
  | ("if", #[a, b, c]) =>
    return .ifE (← getOrDecodeExpr a) (← getOrDecodeExpr b) (← getOrDecodeExpr c)
  -- | ("terminal", _) => sorry
  -- | ("dummy", _) => sorry
  -- | ("outermost", _) => sorry
  -- | ("error", _) => sorry
  | (x, y) => throw s!"Invalid tail length for {x}: {y.size}"

partial def getOrDecodeExpr (ptr : ScalarPtr) : DecodeM Expr := do
  match (← get).find? ptr with
  | some expr => pure expr
  | none =>
    let expr ← decodeExpr ptr
    modifyGet fun stt => (expr, stt.insert ptr expr)

end

def enhanceStore (store : ScalarStore) : Context :=
  let state := ⟨store.exprs, default, default, default⟩
  let (state, memo) : HashState × Std.RBMap ScalarPtr String compare :=
    knownSymbols.foldl (init := (state, default)) fun (state, memo) s =>
      let (ptr, state) := hashString' s.toUpper state
      (state, memo.insert ptr s)
  ⟨state.store, memo⟩

def decode (ptr : ScalarPtr) (store : ScalarStore) : Except String Expr :=
  (StateT.run (ReaderT.run (decodeExpr ptr) (enhanceStore store)) default).1

end Lurk.Hashing
