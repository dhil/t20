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
  T visitTuple(Tuple tuple);
  T visitVariable(Variable v);
  T visitTypeAscription(TypeAscription ascription);
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

  static const String T_LITERAL = "#t";
  static const String F_LITERAL = "#f";
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
  Name id;

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
  List<Pair<Pattern,Expression>> valueBindings;
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
  List<Pair<Pattern, List<Expression>>> cases;

  Match(this.scrutinee, this.cases, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitMatch(this);
  }
}

class Tuple implements Expression {
  SpanLocation location;
  List<Expression> components;

  Tuple(this.components, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitTuple(this);
  }

  bool get isUnit => components.length == 0;
}

class TypeAscription implements Expression {
  Location location;
  Datatype type;
  Expression exp;

  TypeAscription(this.exp, this.type, this.location);

  T visit<T>(ExpressionVisitor<T> v) {
    return v.visitTypeAscription(this);
  }
}
