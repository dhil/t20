// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'name.dart';

enum TypeTag {
  // Base types.
  BOOL,
  INT,
  STRING,

  // Higher order types.
  ARROW,

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

class TypeVariable extends Datatype {
  final Name name;

  const TypeVariable(this.name) : super(TypeTag.VAR);
}
