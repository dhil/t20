// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.ast;

// Algebraic definition
// E ::= if E E E          (* conditional evaluation *)
//     | E E               (* application *)
//     | let B E E         (* let binding *)
//     | x                 (* variables *)
//     | match E (P -> E)* (* pattern matching *)
//     | E.l               (* component selection *)
//     | def B E           (* definition *)
// B ::= name
// P ::= x                 (* variable pattern *)
//     | K P*              (* constructor pattern *)
//     | [0-9]+            (* int literal pattern *)
//     | string            (* string literal pattern *)

abstract class ExpressionVisitor<T> {
  T visitApply(Apply application);
  T visitDefinition(Defintion def);
  T visitIf(If ifthenelse);
  T visitInt(IntLiteral intlit);
  T visitLet(Let let);
  T visitMatch(Match match);
  T visitSelection(Select selection);
  T visitString(StringLiteral stringlit);
  T visitVariable(Variable x);
}

abstract class PatternVisitor<T> {
  T visitConstructor(ConstructorPattern k);
  T visitInt(IntPattern i);
  T visitString(StringPattern s);
  T visitVariable(VariablePattern x);
}
