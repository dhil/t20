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

import 'ast_common.dart';
import 'ast_declaration.dart';
import 'ast_expressions.dart';
import 'ast_module.dart';
import 'ast_patterns.dart';
import 'ast_types.dart';

export 'ast_common.dart';
export 'ast_declaration.dart';
export 'ast_expressions.dart';
export 'ast_module.dart';
export 'ast_patterns.dart';
export 'ast_types.dart';

class _UnsupportedVisitorMethodError {
  final String methodName;
  _UnsupportedVisitorMethodError(this.methodName);

  String toString() {
    return "Unsupported invocation of AST visitor method '$methodName'.";
  }
}

abstract class DefaultExpressionVisitor<T> implements ExpressionVisitor<T> {
  T visitBool(BoolLit boolean) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitBool");
  }

  T visitInt(IntLit integer) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitInt");
  }

  T visitString(StringLit string) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitString");
  }

  T visitApply(Apply apply) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitApply");
  }

  T visitIf(If ifthenelse) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitIf");
  }

  T visitLambda(Lambda lambda) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitLambda");
  }

  T visitLet(Let binding) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitLet");
  }

  T visitMatch(Match match) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitMatch");
  }

  T visitTuple(Tuple tuple) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitTuple");
  }

  T visitVariable(Variable v) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitVariable");
  }

  T visitTypeAscription(TypeAscription ascription) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitTypeAscription");
  }
}

abstract class DefaultModuleVisitor<T> implements ModuleVisitor<T> {
  T visitDatatype(DatatypeDeclaration _) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitDatatype");
  }

  T visitError(ErrorModule _) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitError");
  }

  T visitFunction(FunctionDeclaration _) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitFunction");
  }

  T visitInclude(Include _) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitInclude");
  }

  T visitTopModule(TopModule _) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitTopModule");
  }

  T visitTypename(TypenameDeclaration _) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitTypename");
  }

  T visitValue(ValueDeclaration _) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitValue");
  }
}

abstract class DefaultPatternVisitor<T> implements PatternVisitor<T> {
  T visitBool(BoolPattern b) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitBool");
  }

  T visitConstructor(ConstructorPattern constr) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitConstructor");
  }

  T visitError(ErrorPattern e) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitError");
  }

  T visitHasType(HasTypePattern t) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitHasType");
  }

  T visitInt(IntPattern i) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitInt");
  }

  T visitString(StringPattern s) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitString");
  }

  T visitTuple(TuplePattern t) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitTuple");
  }

  T visitVariable(VariablePattern v) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitVariable");
  }

  T visitWildcard(WildcardPattern w) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitWildcard");
  }
}

abstract class DefaultTypeVisitor<T> implements TypeVisitor<T> {

  T visitConstructor(TypeConstructor ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitConstructor");
  }

  T visitBool(BoolType ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitBool");
  }

  T visitForall(ForallType ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitForall");
  }

  T visitFunction(FunctionType ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitFunction");
  }

  T visitInt(IntType ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitInt");
  }

  T visitInvalid(InvalidType ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitInvalid");
  }

  T visitString(StringType ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitString");
  }

  T visitTuple(TupleType ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitTuple");
  }

  T visitTypeVariable(TypeVariable ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitTypeVariable");
  }

  T visitTypeParameter(TypeParameter ty) {
    assert(false);
    throw _UnsupportedVisitorMethodError("visitTypeParameter");
  }
}
