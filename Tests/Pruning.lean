import LSpec
import Lurk.DSL
import Lurk.ExprUtils

open Lurk Expr.DSL DSL

def cases := [
  (⟦(let ((a 1)) a)⟧, ⟦1⟧),
  (⟦(let ((unused (lambda (x) 5))) 5)⟧, ⟦5⟧),
  (⟦(letrec ((unused (lambda (x) 5))) 5)⟧, ⟦5⟧),
  (⟦(let ((atm 10)) atm)⟧, ⟦10⟧),
  (⟦(letrec ((atm 10)) atm)⟧, ⟦10⟧),
  (⟦(let ((sym y)) sym)⟧, ⟦y⟧),
  (⟦(letrec ((sym y)) sym)⟧, ⟦y⟧),
  (⟦(letrec ((r 5) (r r)) r)⟧, ⟦(letrec ((r r)) r)⟧),
  (⟦(let ((r 5) (r r)) r)⟧, ⟦5⟧),
  (⟦(let ((r 5) (r 1)) r)⟧, ⟦1⟧),
  (⟦(let ((a 1) (b a)) b)⟧, ⟦1⟧),
  (⟦(let ((a 1) (b a)) c)⟧, ⟦c⟧),
  (⟦(let ((a 1)) (+ a a))⟧, ⟦(+ 1 1)⟧),
  (⟦(let ((a (+ 1 1))) (+ a a))⟧, ⟦(let ((a (+ 1 1))) (+ a a))⟧),
  (⟦(let ((a 1) (b (+ a a))) (+ b b))⟧, ⟦(let ((b (+ 1 1))) (+ b b))⟧),
  (⟦(let ((a (+ 1 1)) (b (+ a a))) (+ b b))⟧, ⟦(let ((a (+ 1 1)) (b (+ a a))) (+ b b))⟧),
  (⟦(let ((x a) (a 1) (b a)) c)⟧, ⟦c⟧),
  (⟦(let ((x a) (a 1) (b a)) (+ b x))⟧, ⟦(+ 1 a)⟧),
  (⟦(let ((x (+ a a)) (a 1) (b a)) (+ (+ b x) x))⟧, ⟦(let ((x (+ a a))) (+ (+ 1 x) x))⟧),
  (⟦(let ((z (let ((x 1)) x)) (a (+ z z))) (+ a a))⟧, ⟦(let ((a (+ 1 1))) (+ a a))⟧)
]

open LSpec

def main := lspecIO $
  cases.foldl (init := .done) fun tSeq (inp, out) =>
    tSeq ++ test s!"inlines {inp} correctly" (inp.dropUnusedAndInlineImmediates == out)
