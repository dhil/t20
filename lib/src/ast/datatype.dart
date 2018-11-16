// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show Set;

import '../errors/errors.dart' show LocatedError;
import '../location.dart';
import '../unionfind.dart' as unionfind;
import '../unionfind.dart' show Point;
import '../utils.dart' show Gensym;

import 'ast_declaration.dart';
import 'binder.dart';
import 'monoids.dart' show Monoid;
// import 'name.dart';

abstract class TypeDescriptor {
  Binder binder;
  List<Quantifier> parameters;
  int get arity;
}

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
  VAR,

  // Misc.
  ERROR
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
  T visitSkolem(Skolem skolem);

  T visitError(ErrorType error);
}

abstract class ReduceDatatype<T> extends TypeVisitor<T> {
  Monoid<T> get m;

  T visitList(List<Datatype> types) {
    return types.fold(
        m.empty, (T acc, Datatype type) => m.compose(acc, type.accept(this)));
  }

  T visitBoolType(BoolType _) => m.empty;
  T visitIntType(IntType _) => m.empty;
  T visitStringType(StringType _) => m.empty;

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

  T visitTypeVariable(TypeVariable _) => m.empty;
  T visitSkolem(Skolem _) => m.empty;
  T visitError(ErrorType error) => m.empty;
}

abstract class TransformDatatype extends TypeVisitor<Datatype> {
  List<Datatype> visitList(List<Datatype> types) {
    final List<Datatype> types0 = new List<Datatype>();
    for (int i = 0; i < types.length; i++) {
      types0.add(types[i].accept(this));
    }
    return types0;
  }

  Datatype visitBoolType(BoolType boolType) => boolType;
  Datatype visitIntType(IntType intType) => intType;
  Datatype visitStringType(StringType stringType) => stringType;

  Datatype visitForallType(ForallType forallType) {
    Datatype body0 = forallType.body.accept(this);
    ForallType forallType0 = new ForallType();
    forallType0._quantifiers = forallType._quantifiers;
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
    return TypeConstructor.from(constr.declarator, visitList(constr.arguments));
  }

  Datatype visitTypeVariable(TypeVariable variable) => variable;
  Datatype visitSkolem(Skolem skolem) => skolem;
  Datatype visitError(ErrorType error) => error;
}

Datatype substitute(Datatype type, Map<int, Datatype> substMap) {
  if (substMap.length == 0) return type;
  return _Substitutor.from(substMap).substitute(type);
}

class _Substitutor extends TransformDatatype {
  final Map<int, Datatype> _substMap;
  _Substitutor.from(Map<int, Datatype> substitutionMap)
      : _substMap = substitutionMap;

  Datatype substitute(Datatype type) {
    return type.accept(this);
  }

  // Datatype visitForallType(ForallType forallType) {
  //   Set<int> quantifiers = forallType.quantifiers.fold(new Set<int>(), (Set<int> acc, Quantifier q) {
  //       acc.add(q.ident);
  //       return acc;
  //     });
  //   Set<int> idents = Set<int>.of(_substMap.keys);
  //   Set<int> diff = quantifiers.difference(idents);
  //   if (diff.length != 0) {
  //     return null;
  //   } else {
  //     return forallType.body.accept(this);
  //   }
  // }

  Datatype visitTypeVariable(TypeVariable variable) {
    if (_substMap.containsKey(variable.ident)) {
      return _substMap[variable.ident];
    } else {
      return variable;
    }
  }

  Datatype visitSkolem(Skolem skolem) {
    Datatype type = skolem.type;
    if (type is TypeVariable) {
      if (_substMap.containsKey(type.ident)) {
        return _substMap[type.ident];
      }
    }
    return skolem;
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
  Quantifier declarator;

  TypeVariable() : super(TypeTag.VAR);
  TypeVariable.bound(this.declarator)
      : super(TypeTag.VAR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitTypeVariable(this);
  }

  int get ident => declarator.binder.id;
}

class Skolem extends Datatype {
  Point<Datatype> _point;
  final int _ident;
  int get ident => _ident;

  Skolem._(this._ident) : super(TypeTag.VAR);
  factory Skolem() {
    Skolem s = new Skolem._(Gensym.freshInt());
    s._point = unionfind.singleton(s);
    return s;
  }

  T accept<T>(TypeVisitor<T> v) {
    return v.visitSkolem(this);
  }

  // Never null.
  Datatype get type => unionfind.find(_point);

  void be(Datatype type) {
    unionfind.change(_point, type);
  }

  void sameAs(Skolem other) {
    unionfind.union(_point, other._point);
  }
}

class Quantifier {
  final Kind kind = Kind.TYPE;
  final Binder binder;
  // final Set<Object> constraints;

  Quantifier.fresh() : binder = Binder.fresh(); // : constraints = new Set<Object>();
  Quantifier.of(Binder binder)
      : this.binder = binder; // TODO: replace ident by binder.

  static int compare(Quantifier a, Quantifier b) {
    if (a.binder.id < b.binder.id)
      return -1;
    else if (a.binder.id == b.binder.id)
      return 0;
    else
      return 1;
  }
}

class ForallType extends Datatype {
  List<Quantifier> _quantifiers;
  List<Quantifier> get quantifiers => _quantifiers;
  void set quantifiers(List<Quantifier> quantifiers) {
    quantifiers.sort(Quantifier.compare);
    _quantifiers = quantifiers;
  }

  Datatype body;

  ForallType() : super(TypeTag.FORALL);
  factory ForallType.complete(List<Quantifier> quantifiers, Datatype body) {
    ForallType type = new ForallType();
    type.quantifiers = quantifiers;
    type.body = body;
    return body;
  }

  T accept<T>(TypeVisitor<T> v) {
    return v.visitForallType(this);
  }
}

class TypeConstructor extends Datatype {
  TypeDescriptor declarator;
  List<Datatype> arguments;

  TypeConstructor() : super(TypeTag.CONSTR);
  TypeConstructor.from(this.declarator, this.arguments) : super(TypeTag.CONSTR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitTypeConstructor(this);
  }
}

class ErrorType extends Datatype {
  final LocatedError error;

  ErrorType(this.error, Location location) : super(TypeTag.ERROR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitError(this);
  }
}

// Kinds
enum Kind { TYPE }
