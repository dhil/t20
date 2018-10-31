// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show Set;

import '../utils.dart' show Gensym;
import 'name.dart';

enum TypeTag {
  // Base types.
  BOOL,
  INT,
  STRING,

  // Higher order types.
  ARROW, FORALL, TUPLE,

  // Variables.
  VAR
}

abstract class Datatype {
  final TypeTag tag;
  const Datatype(this.tag);
}

abstract class BaseType extends Datatype {
  const BaseType(TypeTag tag) : super(tag);
}

class BoolType extends BaseType {
  const BoolType() : super(TypeTag.BOOL);
}

class IntType extends BaseType {
  const IntType() : super(TypeTag.INT);
}

class StringType extends BaseType {
  const StringType() : super(TypeTag.STRING);
}

class ArrowType extends Datatype {
  final List<Datatype> domain;
  final Datatype codomain;

  ArrowType(this.domain, this.codomain) : super(TypeTag.ARROW);

  int get arity => domain.length;
}

class TupleType extends Datatype {
  final List<Datatype> components;
  const TupleType(this.components) : super(TypeTag.TUPLE);

  int get arity => components.length;
}

class TypeVariable extends Datatype {
  // May be null during construction. Otherwise it is intended to point to its
  // binder.
  Quantifier binder;

  TypeVariable() : super(TypeTag.VAR);
  TypeVariable.bound(Quantifier binder) : this.binder = binder, super(TypeTag.VAR);
}

class Quantifier {
  final Kind kind = Kind.TYPE;
  final int ident;
  final Set<Object> constraints;

  Quantifier(this.ident) : constraints = new Set<Object>();
}

class ForallType extends Datatype {
  List<Quantifier> quantifiers;
  Datatype body;

  ForallType() : super(TypeTag.FORALL);
}

// Kinds
enum Kind {
  TYPE
}
