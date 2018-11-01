// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// import 'dart:collection' show Set;

// import '../utils.dart' show Gensym;
import 'monoids.dart' show Monoid;
// import 'name.dart';

enum TypeTag {
  // Base types.
  BOOL,
  INT,
  STRING,

  // Higher order types.
  ARROW,
  CONSTR,
  FORALL,
  TUPLE,

  // Variables.
  VAR
}

abstract class TypeVisitor<T> {
  T visitBoolType(BoolType boolType);
  T visitIntType(IntType intType);
  T visitStringType(StringType stringType);

  T visitForallType(ForallType forallType);

  T visitArrowType(ArrowType arrowType);
  T visitTupleType(TupleType tupleType);
  T visitTypeConstructor(TypeConstructor constr);

  T visitTypeVariable(TypeVariable variable);
}

abstract class ReduceDatatype<T> extends TypeVisitor<T> {
  Monoid<T> get m;

  T visitList(List<Datatype> types) {
    return types.fold(
        m.empty, (T acc, Datatype type) => m.compose(acc, type.accept(this)));
  }

  T visitBoolType(BoolType boolType) => m.empty;
  T visitIntType(IntType intType) => m.empty;
  T visitStringType(StringType stringType) => m.empty;

  T visitForallType(ForallType forallType) {
    return forallType.body.accept(this);
  }

  T visitArrowType(ArrowType arrowType) {
    T domain = visitList(arrowType.domain);
    T codomain = arrowType.codomain.accept(this);
    return m.compose(domain, codomain);
  }

  T visitTupleType(TupleType tupleType) {
    return visitList(tupleType.components);
  }

  T visitTypeConstructor(TypeConstructor constr) {
    return visitList(constr.arguments);
  }

  T visitTypeVariable(TypeVariable variable) => m.empty;
}

abstract class TransformDatatype extends TypeVisitor<Datatype> {
  List<Datatype> visitList(List<Datatype> types) {
    final List<Datatype> types0 = new List<Datatype>();
    for (int i = 0; i < types.length; i++) {
      types0[i] = types[i].accept(this);
    }
    return types0;
  }

  Datatype visitBoolType(BoolType boolType) => boolType;
  Datatype visitIntType(IntType intType) => intType;
  Datatype visitStringType(StringType stringType) => stringType;

  Datatype visitForallType(ForallType forallType) {
    Datatype body0 = forallType.body.accept(this);
    ForallType forallType0 = new ForallType();
    forallType0.quantifiers = forallType.quantifiers;
    forallType0.body = body0;
    return forallType0;
  }

  Datatype visitArrowType(ArrowType arrowType) {
    List<Datatype> domain = visitList(arrowType.domain);
    Datatype codomain = arrowType.codomain.accept(this);
    return ArrowType(domain, codomain);
  }

  Datatype visitTupleType(TupleType tupleType) {
    return TupleType(visitList(tupleType.components));
  }

  Datatype visitTypeConstructor(TypeConstructor constr) {
    TypeConstructor constr0 = new TypeConstructor();
    constr0.ident = constr.ident;
    constr0.arguments = visitList(constr.arguments);
    return constr0;
  }

  Datatype visitTypeVariable(TypeVariable variable) => variable;
}

Datatype substitute(Datatype type, Map<int, Datatype> substMap) {
  return _Substitutor.from(substMap).substitute(type);
}

class _Substitutor extends TransformDatatype {
  final Map<int, Datatype> _substMap;
  _Substitutor.from(Map<int, Datatype> substitutionMap)
      : _substMap = substitutionMap;

  Datatype substitute(Datatype type) {
    return type.accept(this);
  }

  Datatype visitTypeVariable(TypeVariable variable) {
    if (_substMap.containsKey(variable.binder.ident)) {
      return _substMap[variable.binder.ident];
    } else {
      return variable;
    }
  }
}



abstract class Datatype {
  final TypeTag tag;
  const Datatype(this.tag);

  T accept<T>(TypeVisitor<T> v);
}

abstract class BaseType extends Datatype {
  const BaseType(TypeTag tag) : super(tag);
}

class BoolType extends BaseType {
  const BoolType() : super(TypeTag.BOOL);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitBoolType(this);
  }
}

class IntType extends BaseType {
  const IntType() : super(TypeTag.INT);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitIntType(this);
  }
}

class StringType extends BaseType {
  const StringType() : super(TypeTag.STRING);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitStringType(this);
  }
}

class ArrowType extends Datatype {
  final List<Datatype> domain;
  final Datatype codomain;

  ArrowType(this.domain, this.codomain) : super(TypeTag.ARROW);

  int get arity => domain.length;

  T accept<T>(TypeVisitor<T> v) {
    return v.visitArrowType(this);
  }
}

class TupleType extends Datatype {
  final List<Datatype> components;
  const TupleType(this.components) : super(TypeTag.TUPLE);

  int get arity => components.length;

  T accept<T>(TypeVisitor<T> v) {
    return v.visitTupleType(this);
  }
}

class TypeVariable extends Datatype {
  // May be null during construction. Otherwise it is intended to point to its
  // binder.
  Quantifier binder;

  TypeVariable() : super(TypeTag.VAR);
  TypeVariable.bound(Quantifier binder)
      : this.binder = binder,
        super(TypeTag.VAR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitTypeVariable(this);
  }
}

class Quantifier {
  final Kind kind = Kind.TYPE;
  final int ident;
  // final Set<Object> constraints;

  Quantifier(this.ident); // : constraints = new Set<Object>();
}

class ForallType extends Datatype {
  List<Quantifier> quantifiers;
  Datatype body;

  ForallType() : super(TypeTag.FORALL);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitForallType(this);
  }
}

class TypeConstructor extends Datatype {
  Datatype type;
  List<Datatype> arguments;
  int ident;

  TypeConstructor() : super(TypeTag.CONSTR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitTypeConstructor(this);
  }
}

// Kinds
enum Kind { TYPE }
