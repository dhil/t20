// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.ast;

// TODO: specify domain-specific constructs such as define-transform, etc.
// Abstract syntax (algebraic specification in EBNF notation).
//
// Module
// M ::= (include ...)                         (* module inclusion *)
//     | : x T                                 (* signatures *)
//     | define x P* E                         (* value definitions *)
//     | define-typename NAME t* T             (* type aliases *)
//     | define-datatype NAME t* (NAME T*)*    (* algebraic data type definitions *)
//       (derive! (fold | map)+)?
//
// Constants
// C ::= #t | #f          (* boolean literals *)
//     | [0-9]+           (* integer literals *)
//     | ".*"             (* string literals *)
//
// Expressions
// E ::= C                (* constants *)
//     | x                (* variables *)
//     | f E*             (* n-ary application *)
//     | lambda P* E+     (* lambda function *)
//     | let (P E)+ E+    (* parallel binding *)
//     | let∗ (P E)+ E+   (* sequential binding *)
//     | , E*             (* n-ary tuples *)
//     | if E E_tt E_ff   (* conditional evaluation *)
//     | match E [P E+]*  (* pattern matching *)
//
// Top-level patterns
// P ::= P' : T           (* has type pattern *)
//     | Q                (* constructor patterns *)
//
// Regular patterns
// Q ::= x                (* variables *)
//     | K x*             (* constructor matching *)
//     | , x*             (* tuple matching *)
//     | [0-9]+           (* integer literal matching *)
//     | ".*"             (* string literal matching *)
//     | #t | #f          (* boolean literal matching *)
//     | _                (* wildcard *)
//
// Types
// T ::= Int | Bool | String (* base types *)
//    | forall id+ T         (* quantification *)
//    | -> T* T              (* n-ary function types *)
//    | K T*                 (* type application *)
//    | ∗ T*                 (* n-ary tuple types *)

import 'ast_declaration.dart';
import 'ast_expressions.dart';
import 'ast_module.dart';
import 'ast_patterns.dart';
import 'datatype.dart';

export 'ast_declaration.dart';
export 'ast_expressions.dart';
export 'ast_module.dart';
export 'ast_patterns.dart';
export 'datatype.dart';

