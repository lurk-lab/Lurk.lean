import Lake
open Lake DSL

package Lurk

lean_lib Lurk

@[default_target]
lean_exe lurk where
  root := `Main

require Poseidon from git
  "https://github.com/yatima-inc/Poseidon.lean" @ "9bc472ac2436e218a8c1687d8fc28935ca9d6cca"

require YatimaStdLib from git
  "https://github.com/yatima-inc/YatimaStdLib.lean" @ "649368d593f292227ab39b9fd08f6a448770dca8"

require LSpec from git
  "https://github.com/yatima-inc/LSpec.git" @ "88f7d23e56a061d32c7173cea5befa4b2c248b41"

require Megaparsec from git
  "https://github.com/yatima-inc/Megaparsec.lean" @ "24cf1754477fa3fed53c418d4bf9dffe2a7d2517"

require std from git
  "https://github.com/leanprover/std4/" @ "fde95b16907bf38ea3f310af406868fc6bcf48d1"

lean_exe Tests.Decoding
lean_exe Tests.Encoding
lean_exe Tests.Evaluation
lean_exe Tests.Parsing
lean_exe Tests.SerDe

lean_exe Tests.Inlining
