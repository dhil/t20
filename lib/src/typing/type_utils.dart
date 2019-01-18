// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart' show TypeAliasDescriptor;
import '../ast/binder.dart';
import '../ast/datatype.dart';
import '../ast/monoids.dart';
import '../unicode.dart' as unicode;

import 'ordered_context.dart' show OrderedContext;
import 'substitution.dart' show Substitution;

// A collection of convenient utility functions for inspecting / destructing
// types.
List<Datatype> domain(Datatype ft) {
  if (ft is ArrowType) {
    return ft.domain;
  }

  if (ft is ForallType) {
    return domain(ft.body);
  }

  if (ft is DynamicType) {
    return <Datatype>[ft];
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

  if (ft is DynamicType) {
    return ft;
  }

  // Error.
  throw "'codomain' called with non-function type argument.";
}

bool isFunctionType(Datatype ft) {
  if (ft is ArrowType) return true;
  if (ft is ForallType) return isFunctionType(ft.body);
  return false;
}

int arity(Datatype ft) {
  if (ft is ArrowType) return ft.domain.length;
  if (ft is ForallType) return arity(ft.body);

  throw "$ft is not a function type!";
}

bool isForallType(Datatype t) {
  if (t is ForallType)
    return true;
  else
    return false;
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

// Base types.
const Datatype unitType = const TupleType(const <Datatype>[]);
bool isUnitType(Datatype type) {
  if (type is TupleType) {
    return type.components.length == 0;
  }
  return false;
}

const Datatype boolType = const BoolType();
const Datatype intType = const IntType();
const Datatype stringType = const StringType();
const Datatype dynamicType = const DynamicType();

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
      acc.add(q.ident);
      return acc;
    });
    return ftv.difference(btv);
  }

  Set<int> visitSkolem(Skolem skolem) => new Set<int>()..add(skolem.ident);
}

Set<int> freeTypeVariables(Datatype type) {
  _FreeTypeVariables ftv = _FreeTypeVariables();
  return type.accept<Set<int>>(ftv);
}

// class _Substitutor extends TransformDatatype {
//   Map<int, Datatype> substMap;

//   _Substitutor(this.substMap);

//   Datatype visitForallType(ForallType forallType) {
//     Set<int> qs = new Set<int>();
//     for (int i = 0; i < forallType.quantifiers.length; i++) {
//       Quantifier q = forallType.quantifiers[i];
//       qs.add(q.ident);
//     }

//     Set<int> keys = Set.of(substMap.keys);
//     Set<int> common = keys.intersection(qs);

//     if (common.length == 0) {
//       Datatype body0 = forallType.body.accept<Datatype>(this);
//       return ForallType.complete(forallType.quantifiers, body0);
//     } else if (common.length == forallType.quantifiers.length) {
//       return forallType.body.accept<Datatype>(this);
//     } else {
//       Datatype body0 = forallType.body.accept<Datatype>(this);
//       List<Quantifier> quantifiers0 = forallType.quantifiers
//           .where((Quantifier q) => !common.contains(q))
//           .toList();
//       return ForallType.complete(quantifiers0, body0);
//     }
//   }

//   Datatype visitTypeVariable(TypeVariable variable) =>
//       substMap.containsKey(variable.ident)
//           ? substMap[variable.ident]
//           : variable;

//   Datatype visitSkolem(Skolem skolem) {
//     Datatype type;
//     if (skolem.painted) {
//       type = skolem;
//     } else {
//       skolem.paint();
//       if (substMap.containsKey(skolem.ident)) {
//         type = substMap[skolem.ident];
//       } else {
//         type = skolem;
//       }
//       skolem.reset();
//     }
//     return type;
//   }
// }

// Datatype substitute(Datatype type, Map<int, Datatype> substitutionMap) {
//   _Substitutor subst = _Substitutor(substitutionMap);
//   return type.accept<Datatype>(subst);
// }

class _MonoTypeVerifier extends ReduceDatatype<bool> {
  static _MonoTypeVerifier _instance;

  OrderedContext prefix;
  Monoid<bool> get m => LAndMonoid();

  _MonoTypeVerifier._();
  factory _MonoTypeVerifier() {
    if (_instance == null) {
      _instance = _MonoTypeVerifier._();
    }
    return _instance;
  }

  bool visitForallType(ForallType forallType) => false;
  bool visitSkolem(Skolem skolem) {
    return prefix.lookup(skolem.ident) != null;
  }
}

bool isMonoType(Datatype type, OrderedContext prefix) {
  _MonoTypeVerifier verifier = _MonoTypeVerifier();
  verifier.prefix = prefix;
  bool result = type.accept<bool>(verifier);
  verifier.prefix = null; // Allow [prefix] to be garbage collected.
  return result;
}

List<Quantifier> freshenQuantifiers(List<Quantifier> qs) {
  List<Quantifier> result = new List<Quantifier>();
  int repetitions = 1;
  int next = null;

  for (int i = 0; i < qs.length; i++) {
    // Compute [next].
    if (next == null)
      next = unicode.a;
    else
      ++next;
    if (next > unicode.z) {
      next = unicode.a;
      ++repetitions;
    }

    // Build fake surface name.
    String surfaceName = List.filled(repetitions, next).join();
    Binder binder = Binder.primitive(qs[i].binder.origin, surfaceName);
    result.add(Quantifier.of(binder));
  }

  return result;
}

List<TypeVariable> typeVariables(List<Quantifier> qs) {
  List<TypeVariable> variables = new List<TypeVariable>();
  for (int i = 0; i < qs.length; i++) {
    variables.add(TypeVariable.bound(qs[i]));
  }
  return variables;
}

bool isTypeAlias(Datatype type) {
  if (type is TypeConstructor) {
    return type.declarator is TypeAliasDescriptor;
  } else {
    return false;
  }
}

Datatype unrollAlias(TypeConstructor typeAlias) {
  if (!isTypeAlias(typeAlias)) {
    throw "Logical error: The declarator of $typeAlias is not a TypeAliasDescriptor.";
  }

  TypeAliasDescriptor descriptor = typeAlias.declarator;
  Datatype unrolledType = descriptor.rhs;
  List<Quantifier> parameters = descriptor.parameters;
  List<Datatype> arguments = typeAlias.arguments;

  Substitution sigma = Substitution.fromPairs(parameters, arguments);

  return sigma.apply(unrolledType);
}

Datatype unroll(Datatype type) {
  if (type is Skolem) {
    return type.isSolved ? type.type : type;
  }

  if (isTypeAlias(type)) return unrollAlias(type);

  return type;
}

class _InstantiateType extends TransformDatatype {
  Map<int, Datatype> instantiationMap;

  _InstantiateType(this.instantiationMap);

  Datatype visitForallType(ForallType forallType) {
    List<Quantifier> quantifiers;
    for (int i = 0; i < forallType.quantifiers.length; i++) {
      Quantifier q = forallType.quantifiers[i];
      if (!instantiationMap.containsKey(q.ident)) {
        quantifiers ??= new List<Quantifier>();
        quantifiers.add(q);
      }
    }
    Datatype body0 = forallType.body.accept(this);
    if (quantifiers == null) {
      return body0;
    } else {
      return new ForallType.complete(quantifiers, body0);
    }
  }

  Datatype visitTypeVariable(TypeVariable variable) =>
      instantiationMap[variable.ident] ?? variable;
  Datatype visitSkolem(Skolem skolem) {
    if (skolem.painted) {
      return skolem;
    } else {
      skolem.paint();
      Datatype type = skolem.type.accept<Datatype>(this);
      skolem.reset();
      return type;
    }
  }
}

Datatype instantiate(
    List<Quantifier> quantifiers, List<Datatype> types, Datatype type) {
  Map<int, Datatype> instantiationMap =
      Map.fromIterables(quantifiers.map((Quantifier q) => q.ident), types);
  return type.accept<Datatype>(_InstantiateType(instantiationMap));
}
