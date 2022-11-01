import Lurk.Evaluation2.FromAST
import Lurk.Hashing2.Datatypes
import Std.Data.HashMap


namespace Lurk.Evaluation
open Lurk.Syntax Std

abbrev PoseidonCache := HashMap (Array F) F

structure Ptr where
  tag : Tag
  val : USize
  deriving BEq, Hashable

structure ContPtr where
  tag : ContTag
  val : USize
  deriving BEq, Hashable

structure ConsData where 
  car : Ptr
  cdr : Ptr
  deriving BEq, Hashable

structure FunData where 
  arg  : Ptr
  body : Ptr
  env  : Ptr
  deriving BEq, Hashable

structure ThunkData where 
  val  : Ptr
  cont : ContPtr
  deriving BEq, Hashable

structure Call₀Data where 
  env   : Ptr
  cont  : ContPtr
  deriving BEq, Hashable

structure CallData where 
  unevaled : Ptr
  env      : Ptr
  cont     : ContPtr
  deriving BEq, Hashable

structure CallNextData where 
  function : Ptr
  env      : Ptr
  cont     : ContPtr
  deriving BEq, Hashable

structure TailData where 
  env  : Ptr
  cont : ContPtr
  deriving BEq, Hashable

structure LookupData where 
  env  : Ptr
  cont : ContPtr
  deriving BEq, Hashable

structure Op₁Data where 
  op   : Ptr
  cont : ContPtr
  deriving BEq, Hashable

structure Op₂Data where 
  op       : Ptr
  unevaled : Ptr
  env      : Ptr
  cont     : ContPtr
  deriving BEq, Hashable

structure Op₂NextData where 
  op     : Ptr
  evaled : Ptr
  cont   : ContPtr
  deriving BEq, Hashable

structure IfData where 
  unevaled : Ptr
  cont     : ContPtr
  deriving BEq, Hashable

structure LetTypeData where 
  var  : Ptr
  body : Ptr
  env  : Ptr
  cont : ContPtr
  deriving BEq, Hashable

structure EmitData where
  cont : ContPtr
  deriving BEq, Hashable

structure Store where
  consStore : Lean.HashSet ConsData
  funStore : Lean.HashSet FunData
  symStore : Lean.HashSet String
  strStore : Lean.HashSet String
  thunkStore : Lean.HashSet ThunkData
  call₀Store : Lean.HashSet Call₀Data
  callStore : Lean.HashSet CallData
  callnextStore : Lean.HashSet CallNextData
  tailStore : Lean.HashSet TailData
  lookupStore : Lean.HashSet LookupData
  op₁Store : Lean.HashSet Op₁Data
  op₂Store : Lean.HashSet Op₂Data
  op₂nextStore : Lean.HashSet Op₂NextData
  ifStore : Lean.HashSet IfData
  letStore : Lean.HashSet LetTypeData
  letrecStore : Lean.HashSet LetTypeData
  emitStore : Lean.HashSet EmitData

  opaques : HashMap Ptr Hashing.ScalarPtr
  scalars : HashMap Hashing.ScalarPtr Ptr
  -- conts : HashMap Hashing.ScalarContPtr Ptr

  poseidonCache : PoseidonCache

  dehyrated : Array Ptr
  dehyratedConts : Array ContPtr
  opaqueCount : USize



end Lurk.Evaluation
