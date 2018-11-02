// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/datatype.dart';
import '../errors/errors.dart';
import '../fp.dart';

import 'type_utils.dart';

// Return substitution or throw an error.
int _identOfQuantifier(Quantifier q) => q.ident;
Map<int, Datatype> _updateSubstitutionMap(
    Map<int, Datatype> map, List<MapEntry<int, Datatype>> entries) {
  for (int j = 0; j < entries.length; j++) {
    MapEntry<int, Datatype> entry = entries[j];
    map[entry.key] = entry.value;
  }
  return map;
}

List<MapEntry<int, Datatype>> _unify(Datatype a, Datatype b) {
  // bool ~ bool = []
  // int ~ int = []
  // string ~ string = []
  if (a is BoolType && b is BoolType ||
      a is IntType && b is IntType ||
      a is StringType && b is StringType) {
    // Success.
    return const <MapEntry<int, Datatype>>[];
  }

  // a ~ b = [], if a = b
  if (a is TypeVariable && b is TypeVariable) {
    if (a.binder.ident == b.binder.ident) {
      return const <MapEntry<int, Datatype>>[];
    }

    // Error.
    throw UnificationError();
  }

  // a ~ t
  //  =
  // [t/a] if a \notin FTV(t)
  if (a is TypeVariable) {
    _occursCheck(a, b);
    return <MapEntry<int, Datatype>>[
      MapEntry<int, Datatype>(a.binder.ident, b)
    ];
  }

  if (b is TypeVariable) {
    _occursCheck(b, a);
    return <MapEntry<int, Datatype>>[
      MapEntry<int, Datatype>(b.binder.ident, a)
    ];
  }

  // a -> b ~ c -> d
  //   =
  // S(2)
  // where S(0)     = []
  //       S(i + 1) = (t(i)S(i) ~ u(i)S(i)) . S(i)
  //       t, u     = [a, b], [c, d]
  if (a is ArrowType && b is ArrowType) {
    if (a.arity != b.arity) {
      throw UnificationError();
    }

    Map<int, Datatype> subst = new Map<int, Datatype>();
    for (int i = 0; i < a.arity; i++) {
      Datatype ai = a.domain[i];
      Datatype bi = b.domain[i];
      List<MapEntry<int, Datatype>> result =
          _unify(substitute(ai, subst), substitute(bi, subst));
      // Update substitution.
      _updateSubstitutionMap(subst, result);
    }
    List<MapEntry<int, Datatype>> result =
        _unify(substitute(a.codomain, subst), substitute(b.codomain, subst));
    _updateSubstitutionMap(subst, result);

    return subst.entries.toList();
  }

  if (a is TupleType && b is TupleType) {
    // TODO.
  }

  if (a is TypeConstructor && b is TypeConstructor) {
    // TODO.
  }

  // \/a.t0 ~ \/b.t1
  //   =
  // t0[s/a] ~ t1[s/b]
  if (a is ForallType && b is ForallType) {
    if (a.quantifiers.length != b.quantifiers.length) {
      throw UnificationError();
    }

    List<Datatype> skolems = new List<Datatype>(a.quantifiers.length);
    for (int i = 0; i < skolems.length; i++) {
      Datatype skolem = null; // Fresh unification variable.
      skolems[i] = skolem;
    }

    Map<int, Datatype> substA = Map<int, Datatype>.fromIterables(
        a.quantifiers.map(_identOfQuantifier), skolems);
    Map<int, Datatype> substB = Map<int, Datatype>.fromIterables(
        b.quantifiers.map(_identOfQuantifier), skolems);

    Datatype a0 = substitute(a.body, substA);
    Datatype b0 = substitute(b.body, substB);

    List<MapEntry<int, Datatype>> result = _unify(a0, b0);
    _escapeCheck(skolems, result);
    return result;
  }

  throw UnificationError();
}

void _escapeCheck(List<Datatype> skolems, List<MapEntry<int, Datatype>> subst) {
  for (int i = 0; i < skolems.length; i++) {
    Skolem skolem = skolems[i];
    for (int j = 0; j < subst.length; j++) {
      Datatype ty = subst[j].value;
      if (ty is Skolem) {
        Skolem skolem0 = ty;
        if (skolem == skolem0) throw SkolemEscapeError();
      }
    }
  }
}

void _occursCheck(TypeVariable a, Datatype type) {
  Set<int> ftv = freeTypeVariables(type);
  if (ftv.contains(a.binder.ident)) {
    throw OccursError();
  }
}

Either<UnificationError, Map<int, Datatype>> unify(Datatype a, Datatype b) {
  try {
    List<MapEntry<int, Datatype>> subst = _unify(a, b);
    return Either.right(Map<int, Datatype>.fromEntries(subst));
  } on UnificationError catch (e) {
    return Either.left(e);
  }
}
