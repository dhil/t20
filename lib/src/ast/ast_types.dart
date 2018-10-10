// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';

import 'ast_common.dart';
import 'ast_declaration.dart';

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
  T visitTypeParameter(TypeParameter ty);
}

enum TypeTag {
  BOOL_TYPE,
  CONSTRUCTOR_TYPE,
  FORALL,
  FUNCTION_TYPE,
  INT_TYPE,
  INVALID_TYPE,
  STRING_TYPE,
  TUPLE_TYPE,
  VARIABLE,
  QUANTIFIER
}

abstract class Datatype {
  final TypeTag tag;
  Location _location;
  Location get location => _location;

  Datatype(this.tag, this._location);

  T visit<T>(TypeVisitor<T> v);
}

class BoolType extends Datatype {
  BoolType(Location location) : super(TypeTag.BOOL_TYPE, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitBool(this);
  }
}

class IntType extends Datatype {
  IntType(Location location) : super(TypeTag.INT_TYPE, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitInt(this);
  }
}

class ForallType extends Datatype {
  List<TypeParameter> quantifiers;
  Datatype body;

  ForallType(this.quantifiers, this.body, Location location)
      : super(TypeTag.FORALL, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitForall(this);
  }
}

class FunctionType extends Datatype {
  List<Datatype> domain;
  Datatype codomain;

  FunctionType(this.domain, this.codomain, Location location)
      : super(TypeTag.FUNCTION_TYPE, location);
  FunctionType.thunk(Datatype codomain, Location location)
      : this(const <Datatype>[], codomain, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitFunction(this);
  }
}

class StringType extends Datatype {
  StringType(Location location) : super(TypeTag.STRING_TYPE, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitString(this);
  }
}

class TypeConstructor extends Datatype {
  Name name;
  List<Datatype> arguments;

  TypeConstructor(this.name, this.arguments, Location location)
      : super(TypeTag.CONSTRUCTOR_TYPE, location);
  TypeConstructor.nullary(Name name, Location location)
      : this(name, const <Datatype>[], location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitConstructor(this);
  }
}

class TupleType extends Datatype {
  List<Datatype> components;

  TupleType(this.components, Location location)
      : super(TypeTag.TUPLE_TYPE, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitTuple(this);
  }
}

class InvalidType extends Datatype {
  InvalidType(Location location) : super(TypeTag.INVALID_TYPE, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitInvalid(this);
  }
}

enum Kind { TYPE }

class TypeParameter extends Datatype implements TypeDeclaration {
  Name name;

  TypeParameter(this.name, Location location)
      : super(TypeTag.QUANTIFIER, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitTypeParameter(this);
  }
}

class TypeVariable extends Datatype {
  final TypeTag tag = TypeTag.VARIABLE;
  final Name name;

  TypeVariable(this.name, Location location)
      : super(TypeTag.VARIABLE, location);

  T visit<T>(TypeVisitor<T> v) {
    return v.visitTypeVariable(this);
  }
}
