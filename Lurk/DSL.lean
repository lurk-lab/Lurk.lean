import Lean
import Lurk.Printer

open Lean Elab Meta

declare_syntax_cat    lurk_literal
syntax "t"          : lurk_literal
syntax "nil"        : lurk_literal
syntax "-" noWs num : lurk_literal
syntax num          : lurk_literal
syntax str          : lurk_literal
syntax char         : lurk_literal
syntax ident        : lurk_literal

def elabLurkLiteral : Syntax → MetaM Expr
  | `(lurk_literal| t) => return mkConst ``Lurk.Literal.t
  | `(lurk_literal| nil) => return mkConst ``Lurk.Literal.nil
  | `(lurk_literal| -$n) => match n.getNat with
    | 0     => do 
      let n ← mkAppM ``Int.ofNat #[mkConst ``Nat.zero]
      let num ← mkAppM ``Lurk.Num.mk #[n, ← mkAppOptM ``none #[mkConst ``Nat]]
      mkAppM ``Lurk.Literal.num #[num]
    | n + 1 => do 
      let n ← mkAppM ``Int.negSucc #[mkNatLit n]
      let num ← mkAppM ``Lurk.Num.mk #[n, ← mkAppOptM ``none #[mkConst ``Nat]]
      mkAppM ``Lurk.Literal.num #[num]
  | `(lurk_literal| $n:num) => do 
    let n ← mkAppM ``Int.ofNat #[mkNatLit n.getNat]
    let num ← mkAppM ``Lurk.Num.mk #[n, ← mkAppOptM ``none #[mkConst ``Nat]]
    mkAppM ``Lurk.Literal.num #[num]
  | `(lurk_literal| $s:str)   => mkAppM ``Lurk.Literal.str #[mkStrLit s.getString]
  | `(lurk_literal| $c:char)  => do
    let c ← mkAppM ``Char.ofNat #[mkNatLit c.getChar.val.toNat]
    mkAppM ``Lurk.Literal.char #[c]
  | `(lurk_literal| $i:ident) => do 
    let s ← mkAppM ``Lurk.Name.mk #[mkStrLit i.getId.toString]
    mkAppM ``Lurk.Literal.sym #[s]
  | _ => throwUnsupportedSyntax

declare_syntax_cat lurk_bin_op
syntax "cons "    : lurk_bin_op 
syntax "strcons " : lurk_bin_op
syntax "+ "       : lurk_bin_op
syntax "- "       : lurk_bin_op
syntax "* "       : lurk_bin_op
syntax "/ "       : lurk_bin_op
syntax "= "       : lurk_bin_op
syntax "eq "      : lurk_bin_op

def elabLurkBinOp : Syntax → MetaM Expr
  | `(lurk_bin_op| cons) => return mkConst ``Lurk.BinOp.cons
  | `(lurk_bin_op| +)    => return mkConst ``Lurk.BinOp.sum
  | `(lurk_bin_op| -)    => return mkConst ``Lurk.BinOp.diff
  | `(lurk_bin_op| *)    => return mkConst ``Lurk.BinOp.prod
  | `(lurk_bin_op| /)    => return mkConst ``Lurk.BinOp.quot
  | `(lurk_bin_op| =)    => return mkConst ``Lurk.BinOp.eq
  | `(lurk_bin_op| eq)   => return mkConst ``Lurk.BinOp.nEq -- unfortunate clash again
  | _ => throwUnsupportedSyntax

declare_syntax_cat lurk_unary_op 
syntax "car "  : lurk_unary_op
syntax "cdr "  : lurk_unary_op
syntax "atom " : lurk_unary_op
syntax "emit " : lurk_unary_op

def elabLurkUnaryOp : Syntax → MetaM Expr
  | `(lurk_unary_op| car) => return mkConst ``Lurk.UnaryOp.car
  | `(lurk_unary_op| cdr) => return mkConst ``Lurk.UnaryOp.cdr
  | `(lurk_unary_op| atom) => return mkConst ``Lurk.UnaryOp.atom
  | `(lurk_unary_op| emit) => return mkConst ``Lurk.UnaryOp.emit
  | _ => throwUnsupportedSyntax

declare_syntax_cat sexpr
syntax "-" noWs num        : sexpr
syntax num                 : sexpr
syntax ident               : sexpr
-- TODO: these are very brittle, should generalize
syntax "+"                 : sexpr
syntax "-"                 : sexpr
syntax "*"                 : sexpr
syntax "/"                 : sexpr
syntax str                 : sexpr
syntax char                : sexpr
syntax "(" sexpr+ ")"      : sexpr
syntax sexpr " . " sexpr   : sexpr

partial def elabSExpr : Syntax → MetaM Expr
  | `(sexpr| -$n:num) => match n.getNat with
    | 0     => do
      let n ← mkAppM ``Int.ofNat #[mkConst ``Nat.zero]
      mkAppM ``Lurk.SExpr.num #[n]
    | n + 1 => do
      let n ← mkAppM ``Int.negSucc #[mkNatLit n]
      mkAppM ``Lurk.SExpr.num #[n]
  | `(sexpr| $n:num) => do
    let n ← mkAppM ``Int.ofNat #[mkNatLit n.getNat]
    mkAppM ``Lurk.SExpr.num #[n]
  | `(sexpr| $i:ident) => do
    mkAppM ``Lurk.SExpr.atom #[mkStrLit i.getId.toString]
  -- TODO: these are extremely brittle, should generalize
  | `(sexpr| +) => do
    mkAppM ``Lurk.SExpr.atom #[mkStrLit "+"]
  | `(sexpr| -) => do
    mkAppM ``Lurk.SExpr.atom #[mkStrLit "-"]
  | `(sexpr| *) => do
    mkAppM ``Lurk.SExpr.atom #[mkStrLit "*"]
  | `(sexpr| /) => do
    mkAppM ``Lurk.SExpr.atom #[mkStrLit "/"]
  | `(sexpr| $s:str) => do
    mkAppM ``Lurk.SExpr.str #[mkStrLit s.getString]
  | `(sexpr| $c:char)  => do
    let c ← mkAppM ``Char.ofNat #[mkNatLit c.getChar.val.toNat]
    mkAppM ``Lurk.SExpr.char #[c]
  | `(sexpr| ($es*)) => do
    let es ← (es.mapM fun e => elabSExpr e)
    mkAppM ``Lurk.SExpr.list #[← mkListLit (mkConst ``Lurk.SExpr) es.toList]
  | `(sexpr| $e1 . $e2) => do
    mkAppM ``Lurk.SExpr.cons #[← elabSExpr e1, ← elabSExpr e2]
  | _ => throwUnsupportedSyntax

elab "[SExpr| " e:sexpr "]" : term =>
  elabSExpr e

#eval [SExpr| (+ a . b . c) ]

declare_syntax_cat lurk_expr
declare_syntax_cat lurk_binding
declare_syntax_cat lurk_bindings

syntax "(" ident lurk_expr ")" : lurk_binding
syntax  "(" lurk_binding* ")": lurk_bindings

syntax lurk_literal                       : lurk_expr
syntax "(" "if" lurk_expr lurk_expr lurk_expr ")" : lurk_expr
syntax "(" "lambda" "(" ident* ")" lurk_expr ")"  : lurk_expr
syntax "(" "let" lurk_bindings lurk_expr ")"      : lurk_expr
syntax "(" "letrec" lurk_bindings lurk_expr ")"   : lurk_expr
syntax "(" "quote" sexpr  ")"                     : lurk_expr -- TODO: fixme to use `
syntax "(" lurk_unary_op lurk_expr ")"            : lurk_expr
syntax "(" lurk_bin_op lurk_expr lurk_expr ")"    : lurk_expr
syntax "(" "emit" lurk_expr ")"                   : lurk_expr
syntax "(" "begin" lurk_expr*  ")"                : lurk_expr
syntax "current-env"                      : lurk_expr
syntax "(" "eval" lurk_expr  ")"                  : lurk_expr
syntax "(" lurk_expr+ ")"                 : lurk_expr


mutual 
partial def elabLurkBinding : Syntax → MetaM Expr 
  | `(lurk_binding| ($name $body)) => do 
    let name ← mkAppM ``Lurk.Name.mk #[mkStrLit name.getId.toString]
    mkAppM ``Prod.mk #[name, ← elabLurkExpr body]
  | _ => throwUnsupportedSyntax

partial def elabLurkBindings : Syntax → MetaM Expr 
  | `(lurk_bindings| ($bindings*)) => do 
    let bindings ← bindings.mapM elabLurkBinding
    let type ← mkAppM ``Prod #[mkConst ``Lurk.Name, mkConst ``Lurk.Expr]
    mkListLit type bindings.toList
  | _ => throwUnsupportedSyntax

partial def elabLurkExpr : Syntax → MetaM Expr
  | `(lurk_expr| $l:lurk_literal) => do
    mkAppM ``Lurk.Expr.lit #[← elabLurkLiteral l]
  | `(lurk_expr| (if $test $con $alt)) => do
    mkAppM ``Lurk.Expr.ifE
      #[← elabLurkExpr test, ← elabLurkExpr con, ← elabLurkExpr alt]
  | `(lurk_expr| (lambda ($formals*) $body)) => do
    let formals ← formals.mapM fun i =>
      mkAppM ``Lurk.Name.mk #[mkStrLit i.getId.toString]
    let formals := formals.toList
    let formals ← mkListLit (mkConst ``Lurk.Name) formals
    mkAppM ``Lurk.Expr.lam #[formals, ← elabLurkExpr body]
  | `(lurk_expr| (let $bind $body)) => do
    mkAppM ``Lurk.Expr.letE #[← elabLurkBindings bind, ← elabLurkExpr body]
  | `(lurk_expr| (letrec $bind $body)) => do
    mkAppM ``Lurk.Expr.letRecE #[← elabLurkBindings bind, ← elabLurkExpr body]
  | `(lurk_expr| (quote $datum)) => do
    mkAppM ``Lurk.Expr.quote #[← elabSExpr datum]
  | `(lurk_expr| ($op:lurk_unary_op $e)) => do
    mkAppM ``Lurk.Expr.unaryOp #[← elabLurkUnaryOp op, ← elabLurkExpr e]
  | `(lurk_expr| ($op:lurk_bin_op $e1 $e2)) => do
    mkAppM ``Lurk.Expr.binOp
      #[← elabLurkBinOp op, ← elabLurkExpr e1, ← elabLurkExpr e2]
  | `(lurk_expr| (emit $e)) => do
    mkAppM ``Lurk.Expr.emit #[← elabLurkExpr e]
  | `(lurk_expr| (begin $es*)) => do
    let es := (← es.mapM elabLurkExpr).toList
    let type := mkConst ``Lurk.Expr
    mkAppM ``Lurk.Expr.begin #[← mkListLit type es]
  | `(lurk_expr| current-env) => return mkConst ``Lurk.Expr.currEnv
  | `(lurk_expr| (eval $e)) => elabLurkExpr e
  | `(lurk_expr| ($e*)) => do 
    let e := (← e.mapM elabLurkExpr).toList
    match e with 
    | []   => throwUnsupportedSyntax
    | e::es => 
      let type := mkConst ``Lurk.Expr
      mkAppM ``Lurk.Expr.app #[e, ← mkListLit type es]
  | _ => throwUnsupportedSyntax
end

-- Tests 

elab "test_elabLurkLiteral " v:lurk_literal : term =>
  elabLurkLiteral v

#eval test_elabLurkLiteral 5     -- Lurk.Literal.num { data := 5, modulus? := none }
#eval test_elabLurkLiteral 0     -- Lurk.Literal.num { data := 0, modulus? := none }
#eval test_elabLurkLiteral -0    -- Lurk.Literal.num { data := 0, modulus? := none }
#eval test_elabLurkLiteral -5    -- Lurk.Literal.num { data := -5, modulus? := none }
#eval test_elabLurkLiteral ""    -- Lurk.Literal.str ""
#eval test_elabLurkLiteral "sss" -- Lurk.Literal.str "sss"
#eval test_elabLurkLiteral a     -- Lurk.Literal.sym { data := "a" }

elab "test_elabLurkBinOp " v:lurk_bin_op : term =>
  elabLurkBinOp v

#eval test_elabLurkBinOp +
#eval test_elabLurkBinOp -
#eval test_elabLurkBinOp *
#eval test_elabLurkBinOp /


elab "test_elabLurkUnaryOp " v:lurk_unary_op : term =>
  elabLurkUnaryOp v

#eval test_elabLurkUnaryOp car

elab "[Lurk| " e:lurk_expr "]" : term =>
  elabLurkExpr e

#check [({ data := "n" } : Lurk.Name)]

#eval Lurk.Expr.print [Lurk| (lambda (n) n) ] -- (lambda (n) n)

#eval Lurk.Expr.print [Lurk|
(let ((foo (lambda (a b c)
             (* (+ a b) c))))
  (foo "1" 2 3))
]
