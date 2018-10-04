// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast_common.dart';
import '../location.dart';

// Abstract syntax (algebraic specification in EBNF notation).
// Types
// T ::= Int | Bool | String (* base types *)
//    | forall id+ T         (* quantification *)
//    | -> T* T              (* n-ary function types *)
//    | K T*                 (* type application *)
//    | tuple T*             (* n-ary tuple types *)

//
// Type language
//
abstract class TypeVisitor<T> {
  T visitConstructor(TypeConstructor ty);
  T visitBool(BoolType ty);
  T visitForall(ForallType ty);
  T visitFunction(FunctionType ty);
  T visitInt(IntType ty);
  T visitInvalid(InvalidType ty);
  T visitString(StringType ty);
  T visitTuple(TupleType ty);
  T visitTypeVariable(TypeVariable ty);
  T visitQuantifier(Quantifier ty);
}

abstract class Datatype {
  T visit<T>(TypeVisitor<T> v);
}

class BoolType implements Datatype {
  Location location;

  BoolType(this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitBool(this);
  }
}

class IntType implements Datatype {
  Location location;

  IntType(this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitInt(this);
  }
}

class ForallType implements Datatype {
  List<Quantifier> quantifiers;
  Datatype body;
  Location location;

  ForallType(this.quantifiers, this.body, this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitForall(this);
  }
}

class FunctionType implements Datatype {
  List<Datatype> domain;
  Datatype codomain;
  Location location;

  FunctionType(this.domain, this.codomain, this.location);
  FunctionType.thunk(Datatype codomain, Location location)
      : this(const <Datatype>[], codomain, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitFunction(this);
  }
}

class StringType implements Datatype {
  Location location;

  StringType(this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitString(this);
  }
}

class TypeConstructor implements Datatype {
  Location location;
  Name name;
  List<Datatype> arguments;

  TypeConstructor(this.name, this.arguments, this.location);
  TypeConstructor.nullary(Name name, Location location)
      : this(name, const <Datatype>[], location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitConstructor(this);
  }
}

class TupleType implements Datatype {
  Location location;
  List<Datatype> components;

  TupleType(this.components, this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitTuple(this);
  }
}

class InvalidType implements Datatype {
  Location location;

  InvalidType(this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitInvalid(this);
  }
}

class Quantifier implements Datatype {
  Location location;
  final Name name;

  Quantifier(this.name, this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitQuantifier(this);
  }
}

class TypeVariable implements Datatype {
  Location location;
  final Name name;

  TypeVariable(this.name, this.location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitTypeVariable(this);
  }
}
