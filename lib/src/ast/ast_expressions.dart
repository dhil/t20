// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show LocatedError;
// import '../fp.dart' show Pair;
import '../location.dart';
import '../utils.dart' show ListUtils;
import 'binder.dart';
import 'datatype.dart';
import 'ast_declaration.dart';
// import 'ast_types.dart';
import 'ast_patterns.dart' show Pattern;

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
  // T visitProjection(Projection p);
  T visitTuple(Tuple tuple);
  T visitVariable(Variable v);
  T visitTypeAscription(TypeAscription ascription);

  T visitError(ErrorExpression e);
}

abstract class Expression {
  final ExpTag tag;
  Datatype type;
  Location location;

  Expression(this.tag, this.location);

  T accept<T>(ExpressionVisitor<T> v);
}

enum ExpTag {
  BOOL,
  ERROR,
  INT,
  STRING,
  APPLY,
  IF,
  LAMBDA,
  LET,
  MATCH,
  TUPLE,
  VAR,
  TYPE_ASCRIPTION
}

/** Constants. **/
abstract class Constant<T> extends Expression {
  T value;
  Constant(this.value, ExpTag tag, Location location) : super(tag, location);

  String toString() {
    return "$value";
  }
}

class BoolLit extends Constant<bool> {
  BoolLit(bool value, Location location) : super(value, ExpTag.BOOL, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitBool(this);
  }

  static const String T_LITERAL = "#t";
  static const String F_LITERAL = "#f";

  String toString() {
    if (value) return T_LITERAL;
    else return F_LITERAL;
  }
}

class IntLit extends Constant<int> {
  IntLit(int value, Location location) : super(value, ExpTag.INT, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitInt(this);
  }
}

class StringLit extends Constant<String> {
  StringLit(String value, Location location)
      : super(value, ExpTag.STRING, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitString(this);
  }

  String toString() {
    return "\"$value\"";
  }
}

class Apply extends Expression {
  Expression abstractor;
  List<Expression> arguments;

  Apply(this.abstractor, this.arguments, Location location)
      : super(ExpTag.APPLY, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitApply(this);
  }

  String toString() {
    if (arguments.length == 0) {
      return "($abstractor)";
    } else {
      String arguments0 = ListUtils.stringify(" ", arguments);
      return "($abstractor $arguments0)";
    }
  }
}

class Variable extends Expression {
  Declaration declarator;

  Variable(this.declarator, Location location) : super(ExpTag.VAR, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitVariable(this);
  }

  String toString() {
    return "${declarator.binder}";
  }
}

class If extends Expression {
  Expression condition;
  Expression thenBranch;
  Expression elseBranch;

  If(this.condition, this.thenBranch, this.elseBranch, Location location)
      : super(ExpTag.IF, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitIf(this);
  }
}

class Binding {
  Pattern pattern;
  Expression expression;

  Binding(this.pattern, this.expression);

  String toString() {
    return "($pattern ...)";
  }
}

class Let extends Expression {
  List<Binding> valueBindings;
  Expression body;

  Let(this.valueBindings, this.body, Location location)
      : super(ExpTag.LET, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitLet(this);
  }

  String toString() {
    String valueBindings0 = ListUtils.stringify(" ", valueBindings);
    return "(let ($valueBindings0) $body)";
  }
}

class Lambda extends Expression {
  List<Pattern> parameters;
  Expression body;

  int get arity => parameters.length;

  Lambda(this.parameters, this.body, Location location)
      : super(ExpTag.LAMBDA, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitLambda(this);
  }

  String toString() {
    String parameters0 = ListUtils.stringify(" ", parameters);
    return "(lambda ($parameters0) (...))";
  }
}

class Case {
  Pattern pattern;
  Expression expression;

  Case(this.pattern, this.expression);

  String toString() {
    return "[$pattern $expression]";
  }
}

class Match extends Expression {
  Expression scrutinee;
  List<Case> cases;

  Match(this.scrutinee, this.cases, Location location)
      : super(ExpTag.MATCH, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitMatch(this);
  }

  String toString() {
    String cases0 = ListUtils.stringify(" ", cases);
    return "(match $scrutinee cases0)";
  }
}

class Tuple extends Expression {
  List<Expression> components;

  Tuple(this.components, Location location) : super(ExpTag.TUPLE, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitTuple(this);
  }

  bool get isUnit => components.length == 0;

  String toString() {
    if (isUnit) {
      return "(,)";
    } else {
      String components0 = ListUtils.stringify(" ", components);
      return "(, $components0)";
    }
  }
}

class TypeAscription extends Expression {
  Expression exp;

  TypeAscription._(this.exp, Location location)
      : super(ExpTag.TYPE_ASCRIPTION, location);

  factory TypeAscription(Expression exp, Datatype type, Location location) {
    TypeAscription typeAs = new TypeAscription._(exp, location);
    typeAs.type = type;
    return typeAs;
  }

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitTypeAscription(this);
  }
}

class ErrorExpression extends Expression {
  final LocatedError error;

  ErrorExpression(this.error, Location location)
      : super(ExpTag.ERROR, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitError(this);
  }
}
