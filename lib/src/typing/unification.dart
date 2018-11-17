// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/datatype.dart';
import '../errors/errors.dart';
import '../fp.dart';
import '../unionfind.dart' as unionfind;

import 'type_utils.dart';

// Return substitution or throw an error.
int _identOfQuantifier(Quantifier q) => q.binder.id;
Map<int, Datatype> _updateSubstitutionMap(
    Map<int, Datatype> map, Map<int, Datatype> entries) {
  map.addAll(entries);
  return map;
}

Map<int, Datatype> unifyMany(List<Datatype> as, List<Datatype> bs) {
  // a -> b ~ c -> d
  //   =
  // S(2)
  // where S(0)     = []
  //       S(i + 1) = (t(i)S(i) ~ u(i)S(i)) . S(i)
  //       t, u     = [a, b], [c, d]
  if (as.length != bs.length) {
    throw UnificationError();
  }

  Map<int, Datatype> subst = new Map<int, Datatype>();
  for (int i = 0; i < as.length; i++) {
    Datatype ai = as[i];
    Datatype bi = bs[i];
    print("$ai ~ $bi");
    Map<int, Datatype> result =
        unifyS(substitute(ai, subst), substitute(bi, subst));
    // Update substitution.
    _updateSubstitutionMap(subst, result);
  }

  return subst;
}

Map<int, Datatype> unifyS(Datatype a, Datatype b) {
  // bool ~ bool = []
  // int ~ int = []
  // string ~ string = []
  if (a is BoolType && b is BoolType ||
      a is IntType && b is IntType ||
      a is StringType && b is StringType) {
    // Success.
    return const <int, Datatype>{};
  }

  // %a ~ %b = []
  if (a is Skolem && b is Skolem) {
    a.sameAs(b);
    return const <int, Datatype>{};
  }

  if (a is Skolem) {
    _occursCheck(a.ident, b);
    a.be(b);
    return const <int, Datatype>{};
  }

  if (b is Skolem) {
    _occursCheck(b.ident, a);
    b.be(a);
    return const <int, Datatype>{};
  }

  // a ~ b = [], if a = b
  if (a is TypeVariable && b is TypeVariable) {
    if (a.ident == b.ident) {
      return const <int, Datatype>{};
    } else {
      return <int, Datatype>{a.ident: b};
    }

    // Error.
    // throw UnificationError();
  }

  // a ~ t
  //  =
  // [t/a] if a \notin FTV(t)
  if (a is TypeVariable) {
    _occursCheck(a.ident, b);
    return <int, Datatype>{a.ident: b};
  }

  if (b is TypeVariable) {
    _occursCheck(b.ident, a);
    return <int, Datatype>{b.ident: a};
  }

  // a -> b ~ c -> d
  //   =
  // S(2)
  // where S(0)     = []
  //       S(i + 1) = (t(i)S(i) ~ u(i)S(i)) . S(i)
  //       t, u     = [a, b], [c, d]
  if (a is ArrowType && b is ArrowType) {
    // Unify the domains.
    Map<int, Datatype> subst = unifyMany(a.domain, b.domain);
    // Unify the codomains.
    Map<int, Datatype> result =
        unifyS(substitute(a.codomain, subst), substitute(b.codomain, subst));
    _updateSubstitutionMap(subst, result);

    return subst;
  }

  if (a is TupleType && b is TupleType) {
    return unifyMany(a.components, b.components);
  }

  if (a is TypeConstructor && b is TypeConstructor) {
    // Check whether their tags agree.
    if (a.declarator.binder.id != b.declarator.binder.id) {
      throw UnificationError();
    }

    return unifyMany(a.arguments, b.arguments);
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
      Datatype skolem = Skolem(); // Fresh unification variable.
      skolems[i] = skolem;
    }

    Map<int, Datatype> substA = Map<int, Datatype>.fromIterables(
        a.quantifiers.map(_identOfQuantifier), skolems);
    Map<int, Datatype> substB = Map<int, Datatype>.fromIterables(
        b.quantifiers.map(_identOfQuantifier), skolems);

    Datatype a0 = substitute(a.body, substA);
    Datatype b0 = substitute(b.body, substB);

    Map<int, Datatype> result = unifyS(a0, b0);
    _escapeCheck(skolems, result);
    return result;
  }

  print("unify fail: $a ~ $b");
  throw UnificationError();
}

void _escapeCheck(List<Datatype> skolems, Map<int, Datatype> subst) {
  for (int i = 0; i < skolems.length; i++) {
    Skolem skolem = skolems[i];
    Datatype ty = subst[skolem.ident];
    if (ty != null) {
      if (ty is Skolem) {
        Skolem skolem0 = ty;
        if (skolem.ident == skolem0.ident) throw SkolemEscapeError();
      }
    }
  }
}

void _occursCheck(int ident, Datatype type) {
  Set<int> ftv = freeTypeVariables(type);
  if (ftv.contains(ident)) {
    throw OccursError();
  }
}

Datatype unify(Datatype a, Datatype b) {
  Map<int, Datatype> subst = unifyS(a, b);
  return substitute(a, subst);
  // try {
  //   Map<int, Datatype> subst = _unify(a, b);
  //   return Either.right(subst);
  // } on UnificationError catch (e) {
  //   return Either.left(e);
  // }
}
