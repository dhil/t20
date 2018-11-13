// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import '../errors/errors.dart' show T20Error;
import '../utils.dart' show Gensym;
// import 'ast_common.dart';
import 'binder.dart';
import 'datatype.dart';
import 'ast_declaration.dart';
// import 'ast_types.dart';

abstract class PatternVisitor<T> {
  T visitBool(BoolPattern b);
  T visitConstructor(ConstructorPattern constr);
  T visitError(ErrorPattern e);
  T visitHasType(HasTypePattern t);
  T visitInt(IntPattern i);
  T visitString(StringPattern s);
  T visitTuple(TuplePattern t);
  T visitVariable(VariablePattern v);
  T visitWildcard(WildcardPattern w);
}

abstract class Pattern {
  Datatype type;
  Location location;
  final PatternTag tag;
  Pattern(this.tag, this.location);

  T accept<T>(PatternVisitor<T> v);
}

enum PatternTag {
  BOOL,
  CONSTR,
  ERROR,
  HAS_TYPE,
  INT,
  STRING,
  TUPLE,
  VAR,
  WILDCARD
}

abstract class BaseValuePattern<T> extends Pattern {
  T value;

  BaseValuePattern(this.value, PatternTag tag, Location location)
      : super(tag, location);
}

class BoolPattern extends BaseValuePattern<bool> {
  BoolPattern(bool value, Location location)
      : super(value, PatternTag.BOOL, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitBool(this);
  }
}

class ConstructorPattern extends Pattern {
  Binder binder;
  List<VariablePattern> components;

  ConstructorPattern(this.binder, this.components, Location location)
      : super(PatternTag.CONSTR, location);
  ConstructorPattern.nullary(Binder binder, Location location)
      : this(binder, const <VariablePattern>[], location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitConstructor(this);
  }
}

class ErrorPattern extends Pattern {
  ErrorPattern(Location location) : super(PatternTag.ERROR, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitError(this);
  }
}

class HasTypePattern extends Pattern {
  Pattern pattern;
  Datatype type;

  HasTypePattern(this.pattern, this.type, Location location)
      : super(PatternTag.HAS_TYPE, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitHasType(this);
  }
}

class IntPattern extends BaseValuePattern<int> {
  IntPattern(int value, Location location)
      : super(value, PatternTag.INT, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitInt(this);
  }
}

class StringPattern extends BaseValuePattern<String> {
  StringPattern(String value, Location location)
      : super(value, PatternTag.STRING, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitString(this);
  }
}

class TuplePattern extends Pattern {
  List<Pattern> components;

  TuplePattern(this.components, Location location)
      : super(PatternTag.TUPLE, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitTuple(this);
  }
}

// abstract class NamePattern implements Pattern {}

class VariablePattern extends Pattern implements Declaration {
  Binder binder;

  VariablePattern(this.binder, Location location) : super(PatternTag.VAR, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitVariable(this);
  }
}

class WildcardPattern extends Pattern {
  WildcardPattern(Location location) : super(PatternTag.WILDCARD, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitWildcard(this);
  }
}
