// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/datatype.dart';
import '../ast/monoids.dart';
import '../errors/errors.dart' show TypeError, InstantiationError;

// A collection of convenient utility functions for inspecting / destructing
// types.
List<Datatype> domain(Datatype ft) {
  if (ft is ArrowType) {
    return ft.domain;
  }

  if (ft is ForallType) {
    return domain(ft.body);
  }

  // Error.
  throw "'domain' called with non-function type argument.";
}

Datatype codomain(Datatype ft) {
  if (ft is ArrowType) {
    return ft.codomain;
  }

  if (ft is ForallType) {
    return codomain(ft.body);
  }

  // Error.
  throw "'codomain' called with non-function type argument.";
}

bool isFunctionType(Datatype ft) {
  if (ft is ArrowType) return true;
  if (ft is ForallType) return isFunctionType(ft.body);
  return false;
}

bool isForallType(Datatype t) {
  if (t is ForallType) return true;
  else return false;
}

List<Quantifier> extractQuantifiers(Datatype t) {
  if (t is ForallType) {
    return t.quantifiers;
  } else {
    return const <Quantifier>[];
  }
}

Datatype stripQuantifiers(Datatype t) {
  if (t is ForallType) {
    return t.body;
  } else {
    return t;
  }
}

Datatype unrigidify(Datatype t) {
  if (t is ForallType) {
    ForallType forallType = t;
    List<Datatype> skolems = new List<Datatype>(forallType.quantifiers.length);
    for (int i = 0; i < skolems.length; i++) {
      Datatype skolem = Skolem(); // Fresh unification variable.
      skolems[i] = skolem;
    }

    Map<int, Datatype> subst = Map<int, Datatype>.fromIterables(
        forallType.quantifiers.map((Quantifier q) => q.binder.id), skolems);
    return substitute(forallType.body, subst);
  } else {
    return t;
  }
}

// Base types.
const Datatype unitType = const TupleType(const <Datatype>[]);
bool isUnitType(Datatype type) {
  if (type is TupleType) {
    return type.components.length == 0;
  }
  return false;
}
const Datatype boolType = const BoolType();
const Datatype intType  = const IntType();
const Datatype stringType = const StringType();


class _FreeTypeVariables extends ReduceDatatype<Set<int>> {
  static _FreeTypeVariables _instance;
  static SetMonoid<int> _m = new SetMonoid<int>();

  _FreeTypeVariables._();
  factory _FreeTypeVariables() {
    if (_instance == null) _instance = _FreeTypeVariables._();
    return _instance;
  }
  Monoid<Set<int>> get m => _m;

  Set<int> visitTypeVariable(TypeVariable variable) =>
      new Set<int>()..add(variable.ident);

  Set<int> visitForallType(ForallType forallType) {
    Set<int> ftv = forallType.body.accept(this);
    Set<int> btv =
        forallType.quantifiers.fold(m.empty, (Set<int> acc, Quantifier q) {
      acc.add(q.binder.id);
      return acc;
    });
    return ftv.difference(btv);
  }
}

Set<int> freeTypeVariables(Datatype type) {
  _FreeTypeVariables ftv = _FreeTypeVariables();
  return type.accept(ftv);
}

Datatype instantiate(Datatype type, List<Datatype> arguments) {
  if (type is ForallType) {
    List<Quantifier> qs = type.quantifiers;
    if (qs.length != arguments.length) {
      throw InstantiationError(qs.length, arguments.length);
    }

    Map<int, Datatype> subst = Map<int, Datatype>.fromIterables(
        qs.map((Quantifier q) => q.binder.id), arguments);
    return substitute(type.body, subst);
  }

  return type;
}
