// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import '../errors/errors.dart' show T20Error;
import '../utils.dart' show Gensym;
import 'ast_common.dart';
import 'ast_declaration.dart';
import 'ast_types.dart';

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
  T visit<T>(PatternVisitor<T> v);
}

abstract class BaseValuePattern<T> implements Pattern {
  Location location;
  T value;

  BaseValuePattern(this.value, this.location);
}

class BoolPattern extends BaseValuePattern<bool> {
  BoolPattern(bool value, Location location) : super(value, location);

  T visit<T>(PatternVisitor<T> v) {
    return v.visitBool(this);
  }
}

class ConstructorPattern implements Pattern {
  Location location;
  Name name;
  List<VariablePattern> components;

  ConstructorPattern(this.name, this.components, this.location);
  ConstructorPattern.nullary(Name name, Location location)
      : this(name, const <VariablePattern>[], location);

  T visit<T>(PatternVisitor<T> v) {
    return v.visitConstructor(this);
  }
}

class ErrorPattern implements Pattern {
  Location location;
  ErrorPattern(this.location);

  T visit<T>(PatternVisitor<T> v) {
    return v.visitError(this);
  }
}

class HasTypePattern implements Pattern {
  Location location;
  Pattern pattern;
  Datatype type;

  HasTypePattern(this.pattern, this.type, this.location);

  T visit<T>(PatternVisitor<T> v) {
    return v.visitHasType(this);
  }
}

class IntPattern extends BaseValuePattern<int> {
  IntPattern(int value, Location location) : super(value, location);

  T visit<T>(PatternVisitor<T> v) {
    return v.visitInt(this);
  }
}

class StringPattern extends BaseValuePattern<String> {
  StringPattern(String value, Location location) : super(value, location);

  T visit<T>(PatternVisitor<T> v) {
    return v.visitString(this);
  }
}

class TuplePattern implements Pattern {
  Location location;
  List<NamePattern> components;

  TuplePattern(this.components, this.location);

  T visit<T>(PatternVisitor<T> v) {
    return v.visitTuple(this);
  }
}

abstract class NamePattern implements Pattern {
  Location location;
}

class VariablePattern implements TermDeclaration, NamePattern {
  Location location;
  Datatype type;
  Name name;

  VariablePattern(this.name, this.location, {bool isSynthetic = false});
  factory VariablePattern.synthetic(
      [Location location = null, String prefix = "x"]) {
    if (location == null) location = Location.dummy();
    String name = Gensym.freshString(prefix);
    return VariablePattern(Name(name, location), location, isSynthetic: true);
  }

  factory VariablePattern.wildcard([Location location = null]) {
    if (location == null) location = Location.dummy();
    String name = "_";
    return VariablePattern(Name(name, location), location, isSynthetic: false);
  }

  T visit<T>(PatternVisitor<T> v) {
    return v.visitVariable(this);
  }
}

class WildcardPattern implements NamePattern {
  Location location;

  WildcardPattern(this.location);

  T visit<T>(PatternVisitor<T> v) {
    return v.visitWildcard(this);
  }
}
