// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import '../errors/errors.dart' show LocatedError;
// import 'ast_common.dart';
import 'binder.dart';
import 'datatype.dart';
import 'ast_declaration.dart';
import 'ast_module.dart' show DataConstructor;
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

abstract class BaseValuePattern extends Pattern {
  BaseValuePattern(PatternTag tag, Location location) : super(tag, location);
}

class BoolPattern extends BaseValuePattern {
  final bool value;

  BoolPattern(this.value, Location location) : super(PatternTag.BOOL, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitBool(this);
  }

  String toString() {
    return "$value";
  }
}

class ConstructorPattern extends Pattern {
  DataConstructor declarator;
  List<VariablePattern> components;
  Datatype get type => declarator.type;

  ConstructorPattern(this.declarator, this.components, Location location)
      : super(PatternTag.CONSTR, location);
  ConstructorPattern.nullary(DataConstructor declarator, Location location)
      : this(declarator, const <VariablePattern>[], location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitConstructor(this);
  }

  String toString() {
    return "[${declarator.binder.sourceName} $components]";
  }
}

class ErrorPattern extends Pattern {
  final LocatedError error;
  ErrorPattern(this.error, Location location)
      : super(PatternTag.ERROR, location);

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

  String toString() {
    return "[$pattern : $type]";
  }
}

class IntPattern extends BaseValuePattern {
  final int value;

  IntPattern(this.value, Location location) : super(PatternTag.INT, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitInt(this);
  }

  String toString() {
    return "$value";
  }
}

class StringPattern extends BaseValuePattern {
  final String value;

  StringPattern(this.value, Location location)
      : super(PatternTag.STRING, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitString(this);
  }

  String toString() {
    return "$value";
  }
}

class TuplePattern extends Pattern {
  List<Pattern> components;

  TuplePattern(this.components, Location location)
      : super(PatternTag.TUPLE, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitTuple(this);
  }

  String toString() {
    if (components.length == 0) {
      return "(*)";
    } else {
      return "(* $components)";
    }
  }
}

class VariablePattern extends Pattern implements Declaration {
  Binder binder;
  bool get isVirtual => false;

  int get ident => binder.id;

  VariablePattern(this.binder, Location location)
      : super(PatternTag.VAR, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitVariable(this);
  }

  String toString() {
    return "${binder}";
  }
}

class WildcardPattern extends Pattern {
  WildcardPattern(Location location) : super(PatternTag.WILDCARD, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitWildcard(this);
  }

  String toString() {
    return "_";
  }
}
