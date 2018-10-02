// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.ast;

import '../location.dart';

// TODO: specify domain-specific constructs such as define-transform, etc.
// Abstract syntax (algebraic specification in EBNF notation).
//
// Module
// M ::= (include ...)                         (* module inclusion *)
//     | define x P* E                         (* value definitions *)
//     | define-datatype NAME t* (NAME type*)* (* algebraic data type definitions *)
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
//     | f x*             (* n-ary application *)
//     | lambda P* E+     (* lambda function *)
//     | let (P E)+ E+    (* parallel binding *)
//     | let∗ (P E)+ E+   (* sequential binding *)
//     | tuple E*         (* n-ary tuples *)
//     | if E E_tt E_ff   (* conditional evaluation *)
//     | match E P*       (* pattern matching *)
//
// Top-level patterns
// P ::= K Q*             (* constructor pattern *)
//     | Q                (* regular pattern *)
//
// Regular patterns
// Q ::= x                (* variables *)
//     | x : T            (* has type pattern *)
//     | tuple x*         (* tuple matching *)
//     | [0-9]+           (* integer literal matching *)
//     | #t | #f          (* boolean literal matching *)
//
// Types
// T ::= Int | Bool | String (* base types *)
//    | -> T* T              (* n-ary function types *)
//    | K T*                 (* type application *)
//    | tuple T*             (* n-ary tuple types *)

// abstract class ExpressionVisitor<T> {
//   T visitApply(/*Apply*/ application);
//   T visitDefinition(/*Defintion*/ def);
//   T visitIf(/*If*/ ifthenelse);
//   T visitInt(/*IntLiteral*/ intlit);
//   T visitLet(/*Let*/ let);
//   T visitMatch(/*Match*/ match);
//   T visitSelection(/*Select*/ selection);
//   T visitString(/*StringLiteral*/ stringlit);
//   T visitVariable(/*Variable*/ x);
// }

// abstract class PatternVisitor<T> {
//   T visitConstructor(/*ConstructorPattern*/ k);
//   T visitInt(/*IntPattern*/ i);
//   T visitString(/*StringPattern*/ s);
//   T visitVariable(/*VariablePattern*/ x);
// }

//
// Type language
//
abstract class TypeVisitor<T> {
  T visitConstructor(TypeConstructor ty);
  T visitBool(BoolType ty);
  T visitFunction(FunctionType ty);
  T visitInt(IntType ty);
  T visitInvalid(InvalidType ty);
  T visitString(StringType ty);
  T visitTuple(TupleType ty);
}

abstract class T20Type {
  T visit<T>(TypeVisitor<T> v);
}

class BoolType implements T20Type {
  Location location;

  BoolType(this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitBool(this);
  }
}

class IntType implements T20Type {
  Location location;

  IntType(this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitInt(this);
  }
}

class FunctionType implements T20Type {
  List<T20Type> domain;
  T20Type codomain;
  Location location;

  FunctionType(this.domain, this.codomain, this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitFunction(this);
  }
}

class StringType implements T20Type {
  Location location;

  StringType(this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitString(this);
  }
}

class TypeConstructor implements T20Type {
  Location location;
  String name;
  List<T20Type> arguments;

  TypeConstructor(this.name, this.arguments, this.location);
  TypeConstructor.nullary(String name, Location location)
      : this(name, const <T20Type>[], location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitConstructor(this);
  }
}

class TupleType implements T20Type {
  Location location;
  List<T20Type> components;

  TupleType(this.components, this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitTuple(this);
  }
}

class InvalidType implements T20Type {
  Location location;

  InvalidType(this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitInvalid(this);
  }
}

//
// Module / top-level language.
//
abstract class ToplevelVisitor<T> {
  T visitDatatype(DatatypeDefinition def);
  T visitFunction(FunctionDefinition def);
  T visitInclude(Include include);
  T visitValue(ValueDefinition def);
}

abstract class Toplevel {
  T visit<T>(ToplevelVisitor<T> v);
}

class ValueDefinition implements Toplevel {
  String name;
  Expression body;
  Location location;

  ValueDefinition(this.name, this.body, this.location);
  T visit<T>(ToplevelVisitor<T> v) {
    return v.visitValue(this);
  }
}

class FunctionDefinition implements Toplevel {
  String name;
  List<Object> parameters;
  Expression body;
  Location location;

  FunctionDefinition(this.name, this.parameters, this.body, this.location);

  T visit<T>(ToplevelVisitor<T> v) {
    return v.visitFunction(this);
  }
}

class DatatypeDefinition implements Toplevel {
  String name;
  List<Object> typeParameters;
  List<Object> constructors;
  Location location;

  DatatypeDefinition(
      this.name, this.typeParameters, this.constructors, this.location);

  T visit<T>(ToplevelVisitor<T> v) {
    return v.visitDatatype(this);
  }
}

class Include implements Toplevel {
  String module;
  Location location;

  Include(this.module, this.location);

  T visit<T>(ToplevelVisitor<T> v) {
    return v.visitInclude(this);
  }
}

//
// Expression language.
//
abstract class ExpressionVisitor<T> {
  // Literals.
  T visitBool(BoolLit boolean);
  T visitInt(IntLit integer);
  T visitString(StringLit string);

  // Expressions.
  T visitApply(Apply apply);
  T visitIf(If ifthenelse);
  T visitLambda(Lambda lambda);
  T visitLet(Let binding);
  T visitMatch(Match match);
  T visitTuple(Tuple tuple);
  T visitVariable(Variable v);
}

abstract class Expression {
  T visit<T>(ExpressionVisitor<T> v);
}

/** Constants. **/
abstract class Constant extends Expression {}

class BoolLit implements Constant {
  bool value;
  Location location;

  BoolLit(this.value, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitBool(this);
  }
}

class IntLit implements Constant {
  Location location;
  int value;

  IntLit(this.value, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitInt(this);
  }
}

class StringLit implements Constant {
  Location location;
  String value;

  StringLit(this.value, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitString(this);
  }
}

class Apply implements Expression {
  Location location;
  Expression abstractor;
  List<Expression> arguments;

  Apply(this.abstractor, this.arguments, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitApply(this);
  }
}

class Variable implements Expression {
  Location location;
  int id;

  Variable(this.id, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitVariable(this);
  }
}

class If implements Expression {
  Location location;
  Expression condition;
  Expression thenBranch;
  Expression elseBranch;

  If(this.condition, this.thenBranch, this.elseBranch, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitIf(this);
  }
}

enum LetKind { Parallel, Sequential }

class Let implements Expression {
  Location location;
  LetKind _kind;
  List<Object> valueBindings;
  List<Expression> body;

  LetKind get kind => _kind;

  Let(this._kind, this.valueBindings, this.body, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitLet(this);
  }
}

class Lambda implements Expression {
  Location location;
  List<Object> parameters;
  List<Expression> body;

  Lambda(this.parameters, this.body, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitLambda(this);
  }
}

class Match implements Expression {
  Location location;
  Expression scrutinee;
  List<Object> cases;

  Match(this.scrutinee, this.cases, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitMatch(this);
  }
}

class Tuple implements Expression {
  Location location;
  List<Expression> components;

  Tuple(this.components, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitTuple(this);
  }
}
