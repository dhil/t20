// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show Map, MapEntry;

import '../ast/datatype.dart';

// Substitution algebra.

abstract class Substitution {
  // Construct an empty subsitution.
  factory Substitution.empty() = MutableSubstitution.empty;

  // Applies this substitution to the [type].
  Datatype apply(Datatype type);

  // Applies this substitution to every type in [types].
  List<Datatype> applyMany(List<Datatype> types);

  // Combines this substitution with an [other] substitution.
  Substitution combine(Substitution other);

  // Extends this substitution with a binding from [typeVar] to [type].
  Substitution bindVar(TypeVariable typeVar, Datatype type);

  // Extends this substitution with a binding from [skolem] to [type].
  Substitution bindSkolem(Skolem skolem, Datatype type);

  // Return the number of elements in the domain of the substitution.
  int get size;
}

// TODO replace with an immutable implementation once I have implemented an
// efficient version of ImmutableMap.
class MutableSubstitution extends TransformDatatype implements Substitution {
  // Type var -> datatype
  Map<int, Datatype> _typeVarSubst;
  // Skolen -> datatype
  Map<int, Datatype> _skolemSubst;

  MutableSubstitution.empty();

  int get size => (_typeVarSubst?.length ?? 0) + (_skolemSubst?.length ?? 0);

  Datatype apply(Datatype type) {
    return type.accept<Datatype>(this);
  }

  List<Datatype> applyMany(List<Datatype> types) {
    return visitList(types);
  }

  Substitution combine(Substitution other) {
    // Optimise trivial cases.
    if (identical(this, other)) return this;
    // Relies on [size] having O(1) time.
    if (this.size == 0) return other;
    if (other.size == 0) return this;


    Map<int, Datatype> thisTypeVarSubst = _substituteInto(this._typeVarSubst, other);

    if (other is MutableSubstitution) {
      MutableSubstitution otherSubst = other;
      Map<int, Datatype> otherTypeVarSubst = _substituteInto(other._typeVarSubst, this);

      thisTypeVarSubst.addAll(otherTypeVarSubst);
      _typeVarSubst = thisTypeVarSubst;
      if (_skolemSubst == null) {
        _skolemSubst = other._skolemSubst;
      } else if (other._skolemSubst != null) {
        _skolemSubst.addAll(other._skolemSubst);
      }

      // Symmetric update.
      other._typeVarSubst = _typeVarSubst;
      other._skolemSubst = _skolemSubst;

      return this;
    } else {
      throw "Not yet implemented.";
    }
  }

  static Map<int, Datatype> _substituteInto(Map<int, Datatype> map, Substitution subst) {
    Map<int, Datatype> map0 = new Map<int, Datatype>();
    if (map == null) return map0;

    Iterable<MapEntry<int, Datatype>> entries = map.entries;
    for (MapEntry<int, Datatype> entry in entries) {
      int ident = entry.key;
      Datatype type = subst.apply(entry.value);
      map0[ident] = type;
    }
    return map0;
  }

  Substitution bindVar(TypeVariable typeVar, Datatype type) {
    _typeVarSubst ??= new Map<int, Datatype>();
    _typeVarSubst[typeVar.ident] = type;
    return this;
  }

  Substitution bindSkolem(Skolem skolem, Datatype type) {
    _skolemSubst ??= new Map<int, Datatype>();
    _skolemSubst[skolem.ident] = type;
    return this;
  }

  // Override of the relevant visit methods from [TransformDatatype].
  Datatype visitTypeVariable(TypeVariable variable) {
    return _typeVarSubst[variable.ident] ?? variable;
  }

  Datatype visitSkolem(Skolem skolem) {
    return _skolemSubst[skolem.ident] ?? skolem;
  }
}

// void main() {
//   Map<int, String> test = <int, String>{0: "Hello", 1: "World"};
//   Iterable<MapEntry<int, String>> entries = test.entries.toList();
//   int size = test.length;
//   for (MapEntry<int, String> entry in entries) {
//     print("${entry.key} -> ${entry.value}");
//     test[size] = "!";
//     ++size;
//   }
// }
