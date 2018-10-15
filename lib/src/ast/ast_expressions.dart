// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../fp.dart' show Pair;
import '../location.dart';
import 'ast_common.dart' show Name;
import 'ast_types.dart';
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
}

abstract class Expression {
  final ExpTag tag;
  Location location;

  Expression(this.tag, this.location);

  T accept<T>(ExpressionVisitor<T> v);
}

enum ExpTag {
  BOOL,
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
}

class BoolLit extends Constant<bool> {
  BoolLit(bool value, Location location) : super(value, ExpTag.BOOL, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitBool(this);
  }

  static const String T_LITERAL = "#t";
  static const String F_LITERAL = "#f";
}

class IntLit extends Constant<int> {
  IntLit(int value, Location location) : super(value, ExpTag.INT, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitInt(this);
  }
}

class StringLit extends Constant<String> {
  StringLit(String value, Location location) : super(value, ExpTag.STRING, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitString(this);
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
}

class Variable extends Expression {
  Name id;

  Variable(this.id, Location location) : super(ExpTag.VAR, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitVariable(this);
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

enum LetKind { Parallel, Sequential }

class Let extends Expression {
  LetKind _kind;
  List<Pair<Pattern, Expression>> valueBindings;
  List<Expression> body;

  LetKind get kind => _kind;

  Let(this._kind, this.valueBindings, this.body, Location location)
      : super(ExpTag.LET, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitLet(this);
  }
}

class Lambda extends Expression {
  List<Pattern> parameters;
  List<Expression> body;

  Lambda(this.parameters, this.body, Location location)
      : super(ExpTag.LAMBDA, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitLambda(this);
  }
}

class Match extends Expression {
  Expression scrutinee;
  List<Pair<Pattern, List<Expression>>> cases;

  Match(this.scrutinee, this.cases, Location location)
      : super(ExpTag.MATCH, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitMatch(this);
  }
}

class Tuple extends Expression {
  List<Expression> components;

  Tuple(this.components, Location location) : super(ExpTag.TUPLE, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitTuple(this);
  }

  bool get isUnit => components.length == 0;
}

class TypeAscription extends Expression {
  Datatype type;
  Expression exp;

  TypeAscription(this.exp, this.type, Location location)
      : super(ExpTag.TYPE_ASCRIPTION, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitTypeAscription(this);
  }
}
