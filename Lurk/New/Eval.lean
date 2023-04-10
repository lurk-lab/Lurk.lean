import Lurk.New.ExprPtrArith
import Lurk.New.Store

open Std (RBMap)
open Store

def car (exprPtr : ExprPtr) : StoreM ExprPtr := do
  match ← getExprPtrImg exprPtr with
  | .cons x _ => pure x
  | _ => if ← isNil exprPtr then pure exprPtr else throw "car failed"

def cdr (exprPtr : ExprPtr) : StoreM ExprPtr := do
  match ← getExprPtrImg exprPtr with
  | .cons _ x => pure x
  | _ => if ← isNil exprPtr then pure exprPtr else throw "cdr failed"

def cadr (exprPtr : ExprPtr) : StoreM $ ExprPtr × ExprPtr := do
  match ← getExprPtrImg exprPtr with
  | .cons x y => pure (x, y)
  | _ => if ← isNil exprPtr then pure (exprPtr, exprPtr) else throw "cadr failed"

def uncons (exprPtr : ExprPtr) : StoreM (ExprPtr × ExprPtr) := do
  match ← getExprPtrImg exprPtr with
  | .cons a b => pure (a, b)
  | _ => throw "uncons failed"

def unfold1 (exprPtr : ExprPtr) : StoreM ExprPtr := do
  let (car, cdr) ← uncons exprPtr
  if ← isNil cdr then return car
  throw "unfold1 failed"

def unfold2 (exprPtr : ExprPtr) : StoreM (ExprPtr × ExprPtr) := do
  let (car₁, cdr) ← uncons exprPtr
  let (car₂, cdr) ← uncons cdr
  if ← isNil cdr then return (car₁, car₂)
  throw "unfold2 failed"

def unfold3 (exprPtr : ExprPtr) : StoreM (ExprPtr × ExprPtr × ExprPtr) := do
  let (car₁, cdr) ← uncons exprPtr
  let (car₂, cdr) ← uncons cdr
  let (car₃, cdr) ← uncons cdr
  if ← isNil cdr then return (car₁, car₂, car₃)
  throw "unfold3 failed"

def insert (envPtr symPtr valPtr : ExprPtr) : StoreM ExprPtr := do
  let pair ← addToExprStore
    ⟨.cons, hash4 symPtr.tag.toF symPtr.val valPtr.tag.toF valPtr.val⟩
    (.cons symPtr valPtr)
  addToExprStore
    ⟨.cons, hash4 pair.tag.toF pair.val envPtr.tag.toF envPtr.val⟩
    (.cons pair envPtr)

-- eliminate this linear cost
partial def find? (envPtr symPtr : ExprPtr) : StoreM (Option ExprPtr) := do
  if ← isNil envPtr then return none
  let (head, tail) ← uncons envPtr
  let (symPtr', valPtr) ← cadr head
  if symPtr' == symPtr then return some valPtr
  find? tail symPtr

def getCont0 (contPtr : ContPtr) : StoreM ContPtr := do
  match (← get).contData.find? contPtr with
  | some $ .cont0 a => return a
  | _ => throw "getCont0 failed"

def getCont1 (contPtr : ContPtr) : StoreM (ExprPtr × ContPtr) := do
  match (← get).contData.find? contPtr with
  | some $ .cont1 a b => return (a, b)
  | _ => throw "getCont1 failed"

def getCont2 (contPtr : ContPtr) : StoreM (ExprPtr × ExprPtr × ContPtr) := do
  match (← get).contData.find? contPtr with
  | some $ .cont2 a b c => return (a, b, c)
  | _ => throw "getCont2 failed"

def getCont3 (contPtr : ContPtr) : StoreM (ExprPtr × ExprPtr × ExprPtr × ContPtr) := do
  match (← get).contData.find? contPtr with
  | some $ .cont3 a b c d => return (a, b, c, d)
  | _ => throw "getCont3 failed"

@[inline] def mkFunPtr (argsSymsPtr funEnvPtr bodyPtr : ExprPtr) : StoreM ExprPtr :=
  addToExprStore
    ⟨.fun, hash6 argsSymsPtr.tag.toF argsSymsPtr.val funEnvPtr.tag.toF funEnvPtr.val
      bodyPtr.tag.toF bodyPtr.val⟩
    (.fun argsSymsPtr funEnvPtr bodyPtr)

structure Frame where
  expr : ExprPtr
  env  : ExprPtr
  cont : ContPtr
  deriving BEq

instance : ToString Frame where
  toString x := s!"⟨{x.expr}, {x.cont}⟩"

def isTrivial (exprPtr : ExprPtr) : StoreM Bool :=
  match exprPtr.tag with
  | .num | .u64 | .char | .str | .comm | .fun => return true
  | .sym => do match ← getSym exprPtr with
    | .nil | .t => return false
    | _ => return false
  | _ => return false

def extractUnOp : ContTag → StoreM UnOp
  | .unOp op => return op
  | x => throw s!"Can't extract unary operator from {x}"

def extractBinOp : ContTag → StoreM BinOp
  | .binOp₁ op | .binOp₂ op => return op
  | x => throw s!"Can't extract binary operator from {x}"

abbrev StepInto := ExprPtr × ContPtr → StoreM Frame

def intoUnOpHandle (resPtr : ExprPtr) (op : UnOp) : StepInto := fun (envPtr, contPtr) =>
  match op with
  | .car => return ⟨← car resPtr, envPtr, contPtr⟩

def intoUnOp (tag : ContTag) (tailPtr : ExprPtr) : StepInto := fun (envPtr, contPtr) => do
  let x ← unfold1 tailPtr
  if ← isTrivial x then intoUnOpHandle x (← extractUnOp tag) (envPtr, contPtr)
  else
    let contPtr' ← addToContStore
      ⟨tag, hash2 contPtr.tag.toF contPtr.val⟩
      (.cont0 contPtr)
    return ⟨x, envPtr, contPtr'⟩

def intoBinOp₂Handle (lPtr rPtr : ExprPtr) (op : BinOp) : StepInto := fun (envPtr, contPtr) =>
  match op with
  | .add => return ⟨← lPtr.add rPtr, envPtr, contPtr⟩
  | .numEq => return ⟨← boolToExprPtr $ ← lPtr.numEq rPtr, envPtr, contPtr⟩

def intoBinOp₁Handle (lPtr rPtr : ExprPtr) (op : BinOp) : StepInto := fun (envPtr, contPtr) => do
  if ← isTrivial rPtr then intoBinOp₂Handle lPtr rPtr op (envPtr, contPtr)
  else
    let contPtr' ← addToContStore
      ⟨.binOp₂ op, hash4 lPtr.tag.toF lPtr.val contPtr.tag.toF contPtr.val⟩
      (.cont1 lPtr contPtr)
    return ⟨rPtr, envPtr, contPtr'⟩

def intoBinOp (tag : ContTag) (tailPtr : ExprPtr) : StepInto := fun (envPtr, contPtr) => do
  let (x, y) ← unfold2 tailPtr
  if ← isTrivial x then intoBinOp₁Handle x y (← extractBinOp tag) (envPtr, contPtr)
  else
    let contPtr' ← addToContStore
      ⟨tag, hash4 y.tag.toF y.val contPtr.tag.toF contPtr.val⟩
      (.cont1 y contPtr)
    return ⟨x, envPtr, contPtr'⟩

def intoApp (fnPtr argsPtr : ExprPtr) : StepInto := fun (envPtr, contPtr) => do
  let contPtr' ← addToContStore
    ⟨.appFn, hash4 argsPtr.tag.toF argsPtr.val contPtr.tag.toF contPtr.val⟩
    (.cont1 argsPtr contPtr)
  return ⟨fnPtr, envPtr, contPtr'⟩

def indoIfHandle (resPtr truePtr falsePtr : ExprPtr) : StepInto :=
  fun (envPtr, contPtr) => do
    if ← isNil resPtr then return ⟨falsePtr, envPtr, contPtr⟩
    else return ⟨truePtr, envPtr, contPtr⟩

def intoIf (tailPtr : ExprPtr) : StepInto := fun (envPtr, contPtr) => do
  let (propPtr, tailPtr) ← cadr tailPtr
  let (truePtr, tailPtr) ← cadr tailPtr
  let (falsePtr, tailPtr) ← cadr tailPtr
  if ← isNotNil tailPtr then throw "To many if arguments"
  if ← isTrivial propPtr then indoIfHandle propPtr truePtr falsePtr (envPtr, contPtr)
  else
    let contPtr' ← addToContStore
      ⟨.if, hash6 truePtr.tag.toF truePtr.val falsePtr.tag.toF falsePtr.val
        contPtr.tag.toF contPtr.val⟩
      (.cont2 truePtr falsePtr contPtr)
    return ⟨propPtr, envPtr, contPtr'⟩

def intoLet (bindsPtr bodyPtr: ExprPtr) : StepInto := fun (envPtr, contPtr) => do
  let bindPtr ← car bindsPtr
  let (_, bindExprPtr) ← unfold2 bindPtr
  let contPtr' ← addToContStore
    ⟨.let, hash6 bindsPtr.tag.toF bindsPtr.val bodyPtr.tag.toF bodyPtr.val
      contPtr.tag.toF contPtr.val⟩
    (.cont2 bindsPtr bodyPtr contPtr)
  return ⟨bindExprPtr, envPtr, contPtr'⟩

def intoLetrec (bindsPtr bodyPtr : ExprPtr) : StepInto := fun (envPtr, contPtr) => do
  let bindPtr ← car bindsPtr
  let (bindSymPtr, bindExprPtr) ← unfold2 bindPtr
  let contPtr' ← addToContStore
    ⟨.letrec, hash6 bindsPtr.tag.toF bindsPtr.val bodyPtr.tag.toF bodyPtr.val
      contPtr.tag.toF contPtr.val⟩
    (.cont2 bindsPtr bodyPtr contPtr)
  let thunkPtr ← addToExprStore
    ⟨.thunk, hash2 bindExprPtr.tag.toF bindExprPtr.val⟩
    (.thunk bindExprPtr)
  return ⟨bindExprPtr, ← insert envPtr bindSymPtr thunkPtr, contPtr'⟩

def intoNextAppArg (fnPtr argsSymsPtr argsPtr bodyPtr : ExprPtr) : StepInto :=
  fun (envPtr, contPtr) => do match ← isNil argsSymsPtr, ← isNil argsPtr with
    | true,  true  => return ⟨bodyPtr, envPtr, contPtr⟩ -- fulfilled
    | false, true  => return ⟨fnPtr, envPtr, contPtr⟩ -- still missing args
    | true,  false => throw "Too many arguments"
    | false, false => -- currying
      let (argPtr, argsPtr) ← uncons argsPtr
      let contPtr' ← addToContStore
        ⟨.appArg, hash6 fnPtr.tag.toF fnPtr.val argsPtr.tag.toF argsPtr.val
          contPtr.tag.toF contPtr.val⟩
        (.cont2 fnPtr argsPtr contPtr)
      return ⟨argPtr, envPtr, contPtr'⟩

def Frame.continue (frm : Frame) : StoreM Frame := do
  match frm.cont.tag with
  | .entry => pure { frm with cont := ← getCont0 frm.cont }
  | .halt => throw "Can't continue upon halt continuation"
  | .unOp op => intoUnOpHandle frm.expr op (frm.env, ← getCont0 frm.cont)
  | .binOp₁ op =>
    let (y, contPtr) ← getCont1 frm.cont
    intoBinOp₁Handle frm.expr y op (frm.env, contPtr)
  | .binOp₂ op =>
    let (x, contPtr) ← getCont1 frm.cont
    intoBinOp₂Handle x frm.expr op (frm.env, contPtr)
  | .appFn =>
    let fnPtr := frm.expr
    let (argsPtr, contPtr) ← getCont1 frm.cont
    match ← getExprPtrImg fnPtr with
    | .fun argsSymsPtr funEnvPtr bodyPtr =>
      intoNextAppArg fnPtr argsSymsPtr argsPtr bodyPtr (funEnvPtr, contPtr)
    | _ => throw s!"Error evaluating app function. Head function expected"
  | .appArg =>
    let (fnPtr, argsPtr, contPtr) ← getCont2 frm.cont
    match ← getExprPtrImg fnPtr with
    | .fun argsSymsPtr funEnvPtr bodyPtr =>
      let (argSymPtr, argsSymsPtr) ← uncons argsSymsPtr
      let funEnvPtr ← insert funEnvPtr argSymPtr frm.expr
      let fnPtr' ← mkFunPtr argsSymsPtr funEnvPtr bodyPtr
      intoNextAppArg fnPtr' argsSymsPtr argsPtr bodyPtr (funEnvPtr, contPtr)
    | _ => throw "Error applying app argument. Head function expected"
  | .if =>
    let (truePtr, falsePtr, contPtr) ← getCont2 frm.cont
    indoIfHandle frm.expr truePtr falsePtr (frm.env, contPtr)
  | .let =>
    let (bindsPtr, bodyPtr, contPtr) ← getCont2 frm.cont
    let (bindPtr, bindsPtr') ← uncons bindsPtr
    let (bindSymPtr, _) ← unfold2 bindPtr
    let envPtr ← insert frm.env bindSymPtr frm.expr
    if ← isNil bindsPtr' then pure ⟨bodyPtr, envPtr, contPtr⟩
    else intoLet bindsPtr' bodyPtr (envPtr, contPtr)
  | .letrec =>
    let (bindsPtr, bodyPtr, contPtr) ← getCont2 frm.cont
    let (bindPtr, bindsPtr') ← uncons bindsPtr
    let (bindSymPtr, _) ← unfold2 bindPtr
    let envPtr ← insert frm.env bindSymPtr frm.expr
    if ← isNil bindsPtr' then pure ⟨bodyPtr, envPtr, contPtr⟩
    else intoLetrec bindsPtr' bodyPtr (envPtr, contPtr)
  | .env =>
    let (envPtr₀, contPtr) ← getCont1 frm.cont
    pure ⟨frm.expr, envPtr₀, contPtr⟩

@[inline] def Frame.stepIntoParams (frm : Frame) : ExprPtr × ContPtr :=
  (frm.env, frm.cont)

def Frame.saveEnv (frm : Frame) : StoreM Frame := do
  if frm.cont.tag == .env then return frm
  let (envPtr, contPtr) := (frm.env, frm.cont)
  let contPtr' ← addToContStore
    ⟨.env, hash4 envPtr.tag.toF envPtr.val contPtr.tag.toF contPtr.val⟩
    (.cont1 envPtr contPtr)
  return { frm with cont := contPtr' }

def Frame.step (frm : Frame) : StoreM Frame := do
  let frm' ← match frm.expr.tag with
    | .num | .u64 | .char | .str | .comm | .fun => frm.continue
    | .sym =>
      let symPtr := frm.expr
      match ← getSym symPtr with
      | .nil | .t => frm.continue
      | sym => match ← find? frm.env symPtr with
        | some valPtr =>
          if valPtr.tag != .thunk then Frame.continue { frm with expr := valPtr }
          else pure ⟨valPtr, ← insert frm.env symPtr valPtr, frm.cont⟩
        | none => throw s!"{sym} not found"
    | .thunk =>
      let .thunk expr ← getExprPtrImg frm.expr | throw "Expected thunk. Malformed store"
      pure { frm with expr }
    | .cons =>
      let .cons head tail ← getExprPtrImg frm.expr
        | throw "Expected cons. Malformed store"
      if head.tag == .sym then match ← getSym head with
        | .ofString "car" => intoUnOp (.unOp .car) tail frm.stepIntoParams
        | .ofString "+" => intoBinOp (.binOp₁ .add) tail frm.stepIntoParams
        | .ofString "=" => intoBinOp (.binOp₁ .numEq) tail frm.stepIntoParams
        | .ofString "lambda" =>
          let (argsSymsPtr, bodyPtr) ← unfold2 tail
          let envPtr := frm.env
          let funPtr ← mkFunPtr argsSymsPtr envPtr bodyPtr
          pure ⟨funPtr, envPtr, frm.cont⟩
        | .ofString "if" => intoIf tail frm.stepIntoParams
        | .ofString "let" =>
          let (bindsPtr, bodyPtr) ← unfold2 tail
          if ← isNil bindsPtr then pure { frm with expr := bodyPtr }
          else let frm ← frm.saveEnv; intoLet bindsPtr bodyPtr frm.stepIntoParams
        | .ofString "letrec" =>
          let (bindsPtr, bodyPtr) ← unfold2 tail
          if ← isNil bindsPtr then pure { frm with expr := bodyPtr }
          else let frm ← frm.saveEnv; intoLetrec bindsPtr bodyPtr frm.stepIntoParams
        | _ => let frm ← frm.saveEnv; intoApp head tail frm.stepIntoParams
      else let frm ← frm.saveEnv; intoApp head tail frm.stepIntoParams
  if (← isTrivial frm'.expr) && frm'.cont.tag == .entry then
    return { frm' with cont := ← getCont0 frm'.cont }
  else return frm'

def Frame.eval (frm : Frame) : StoreM $ ExprPtr × Array Frame := do
  let mut frm' := frm
  let mut frms := #[frm]
  dbg_trace frm'
  while true do
    frm' ← frm'.step
    frms := frms.push frm'
    dbg_trace frm'
    if frm'.cont.tag == .halt then break
  return (frm'.expr, frms)

def LDON.evalM (ldon : LDON) : StoreM $ ExprPtr × Array Frame := do
  let haltPtr := ContPtr.mk .halt .zero
  let contPtr ← addToContStore
    ⟨.entry, hash2 haltPtr.tag.toF haltPtr.val⟩
    (.cont0 haltPtr)
  Frame.eval ⟨← putLDON ldon, ← putSym .nil, contPtr⟩

def LDON.eval (ldon : LDON) (store : Store := default) :
    Except String $ ExprPtr × (Array Frame) × Store :=
  match EStateM.run ldon.evalM store with
  | .ok (expr, frms) store => return (expr, frms, store)
  | .error err _ => throw err

def test (ldon : LDON) : Except String Nat :=
  match ldon.eval with
  | .ok x => return x.2.1.size.pred
  | .error x => throw x

open LDON.DSL
def main : IO Unit :=
  let code := ⟪
    -- (letrec ((count10 (lambda (i) (if (= i 10) i (count10 (+ i 1)))))) (count10 0))
    -- (let ((a 1) (b a)) (+ b 1))
    -- ((lambda (i) (if (= i 10) i (+ i 1))) 0)
    -- ((lambda (a b c) nil) 1 2 3)
    -- (+ (+ 1 1) (+ 1 1))
    -- 1
    (+ 1 1)
    -- (car nil)
    -- (if nil 1 (+ 1 2))
    -- (let () 2)
    -- ((lambda (x y) (+ x y)) (+ 1 1) 3)
    -- (((lambda (x y) (+ x y)) (+ 1 1)) 3)
    -- (let ((count10 (lambda (i) (if (= i 10) i (+ i 1))))) (count10 0))
    -- (+ ((lambda (x) x) 1) x)
    -- (+ (let ((a 1)) a) a)
  ⟫
  match test code with
  | .ok e | .error e => IO.println e
