import LSpec
import Lurk.DSL
import Lurk.Scalar

open Lurk

open LDON.DSL Expr.DSL DSL in
def exprs := [
  ⟦nil⟧,
  ⟦t⟧,
  ⟦(current-env)⟧,
  ⟦()⟧,
  ⟦(nil)⟧,
  ⟦(t)⟧,
  ⟦(current-env)⟧,
  ⟦(nil t)⟧,
  ⟦(t nil)⟧,
  ⟦((current-env) t nil)⟧,
  ⟦(num 1)⟧,
  ⟦(char 1)⟧,
  ⟦(f)⟧,
  ⟦(f a)⟧,
  ⟦(f 1 q)⟧,
  ⟦(/ (- (+ 1 2) a) (* 4 3))⟧,
  ⟦(begin)⟧,
  ⟦(begin 1)⟧,
  ⟦(begin nil)⟧,
  ⟦(begin 1 2 3)⟧,
  ⟦(hide a b)⟧,
  ⟦(lambda (a b c) (begin (cons a b) c))⟧,
  ⟦(let ((a 1) (b c)) (+ a b))⟧,
  ⟦(quote 1)⟧,
  ⟦(quote x)⟧,
  ⟦(quote (nil cons IF lambda begin quote + / eval))⟧,
  ⟦(eval (quote (nil 1)))⟧,
  ⟦(,(1 . 1))⟧,
  ⟦(quote ((1 . 1) x))⟧,
  ⟦((+ 1 2) (f x) (cons 4 2))⟧
]

open LSpec in
def main :=
  lspecIO $ exprs.foldl (init := .done)
    fun tSeq (e : Expr) =>
      let ldon := e.toLDON
      let (comm, stt) := ldon.commit default
      withExceptOk s!"Opening {comm.asHex} succeeds" (stt.store.open comm) fun ldon' =>
        withExceptOk s!"Converting {ldon'} back to Expr succeeds" ldon'.toExpr fun e' =>
          tSeq ++ test s!"{e} roundtrips" (e == e')
