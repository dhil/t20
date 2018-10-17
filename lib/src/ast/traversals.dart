// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../errors/errors.dart' show LocatedError;
import '../fp.dart' show Pair;
import '../location.dart';

import 'algebra.dart';

// Monoids.
abstract class Magma<R> {
  R compose(R x, R y);
}

abstract class Monoid<R> implements Magma<R> {
  R get empty;
}

class SetMonoid<T> implements Monoid<Set<T>> {
  Set<T> get empty => new Set<T>();
  Set<T> compose(Set<T> x, Set<T> y) => x.union(y);
}

class ListMonoid<T> implements Monoid<List<T>> {
  List<T> get empty => new List<T>();
  List<T> compose(List<T> x, List<T> y) {
    assert(x != null && y != null);
    x.addAll(y); // TODO: use an immutable list.
    return x;
  }
}

// class PairMonoid<T> implements Monoid<Pair<T, T>> {
//   final Monoid<T> _m;
//   PairMonoid(this._m);

//   Pair<T, T> get empty => Pair<T, T>(_m.empty, _m.empty);
//   Pair<T, T> compose(Pair<T, T> x, Pair<T, T> y) =>
//       Pair<T, T>(_m.compose(x.$1, y.$1), _m.compose(x.$2, y.$2));
// }

abstract class Morphism<S, T> {
  T apply(S x);
}

abstract class GMorphism {
  Morphism<S, T> generate<S, T>();
}

// Generic reductive traversals.
abstract class Fold<Name, Mod, Exp, Pat, Typ> extends TAlgebra<Name, Mod, Exp, Pat, Typ> {
  // A specialised monoid for each sort.
  Monoid<Mod> get mod;
  Monoid<Exp> get exp;
  Monoid<Name> get name;
  Monoid<Pat> get pat;
  Monoid<Typ> get typ;

  // Primitive converters.
  Morphism<Name, Typ> get name2typ;
  Morphism<Typ, Pat> get typ2pat;
  Morphism<Typ, Exp> get typ2exp;
  Morphism<Pat, Exp> get pat2exp;
  Morphism<Exp, Mod> get exp2mod;

  // Derived converters.
  Morphism<Name, Mod> get name2mod;
  Morphism<Name, Exp> get name2exp;
  Morphism<Pat, Mod> get pat2mod;
  Morphism<Name, Pat> get name2pat;
  Morphism<Typ, Mod> get typ2mod;

  Mod datatype(Pair<Name, List<Name>> binder,
      List<Pair<Name, List<Typ>>> constructors, List<Name> deriving,
      {Location location}) {
    Name r0 = binder.$2.fold(binder.$1, name.compose);
    Typ r1 = name2typ.apply(r0);
    for (int i = 0; i < constructors.length; i++) {
      Typ seed = typ.compose(r1, name2typ.apply(constructors[i].$1));
      r1 = constructors[i].$2.fold(seed, typ.compose);
    }
    Name r2 = deriving.fold(name.empty, name.compose);
    return name2mod.apply(r2);
  }

  Mod valueDef(Name name, Exp body, {Location location}) =>
      exp2mod.apply(exp.compose(name2exp.apply(name), body));

  Mod functionDef(Name name, List<Pat> parameters, Exp body,
      {Location location}) {
    Pat r0 = parameters.fold(name2pat.apply(name), pat.compose);
    return mod.compose(pat2mod.apply(r0), exp2mod.apply(body));
  }

  Mod module(List<Mod> members, {Location location}) =>
      members.fold(mod.empty, mod.compose);
  Mod typename(Pair<Name, List<Name>> constr, Typ type, {Location location}) {
    Name r0 = constr.$2.fold(constr.$1, name.compose);
    return mod.compose(name2mod.apply(r0), typ2mod.apply(type));
  }

  Mod signature(Name name, Typ type, {Location location}) =>
      mod.compose(name2mod.apply(name), typ2mod.apply(type));
  Mod errorModule(LocatedError error, {Location location}) => mod.empty;

  Exp boolLit(bool b, {Location location}) => exp.empty;
  Exp intLit(int n, {Location location}) => exp.empty;
  Exp stringLit(String s, {Location location}) => exp.empty;
  Exp varExp(Name name, {Location location}) => name2exp.apply(name);
  Exp apply(Exp fn, List<Exp> arguments, {Location location}) =>
      arguments.fold(fn, exp.compose);
  Exp lambda(List<Pat> parameters, Exp body, {Location location}) {
    Pat r0 = parameters.fold(pat.empty, pat.compose);
    return exp.compose(pat2exp.apply(r0), body);
  }

  Exp let(List<Pair<Pat, Exp>> bindings, Exp body,
      {BindingMethod bindingMethod = BindingMethod.Parallel,
      Location location}) {
    Exp r0 = exp.empty;
    for (int i = 0; i < bindings.length; i++) {
      Exp e = pat2exp.apply(bindings[i].$1);
      r0 = exp.compose(e, bindings[i].$2);
    }
    return exp.compose(r0, body);
  }

  Exp tuple(List<Exp> components, {Location location}) =>
      components.fold(exp.empty, exp.compose);
  Exp ifthenelse(Exp condition, Exp thenBranch, Exp elseBranch,
          {Location location}) =>
      exp.compose(exp.compose(condition, thenBranch), elseBranch);
  Exp match(Exp scrutinee, List<Pair<Pat, Exp>> cases, {Location location}) {
    Exp acc = scrutinee;
    for (int i = 0; i < cases.length; i++) {
      Exp e = pat2exp.apply(cases[i].$1);
      acc = exp.compose(e, cases[i].$2);
    }
    return acc;
  }

  Exp typeAscription(Exp e, Typ type, {Location location}) =>
      exp.compose(e, typ2exp.apply(type));
  Exp errorExp(LocatedError error, {Location location}) => exp.empty;

  Pat hasTypePattern(Pat pattern, Typ type, {Location location}) =>
      pat.compose(pattern, typ2pat.apply(type));
  Pat boolPattern(bool b, {Location location}) => pat.empty;
  Pat intPattern(int n, {Location location}) => pat.empty;
  Pat stringPattern(String s, {Location location}) => pat.empty;
  Pat wildcard({Location location}) => pat.empty;
  Pat varPattern(Name name, {Location location}) => name2pat.apply(name);
  Pat constrPattern(Name name, List<Pat> parameters, {Location location}) =>
      parameters.fold(name2pat.apply(name), pat.compose);
  Pat tuplePattern(List<Pat> components, {Location location}) =>
      components.fold(pat.empty, pat.compose);
  Pat errorPattern(LocatedError error, {Location location}) => pat.empty;

  Typ intType({Location location}) => typ.empty;
  Typ boolType({Location location}) => typ.empty;
  Typ stringType({Location location}) => typ.empty;
  Typ typeVar(Name name, {Location location}) => name2typ.apply(name);
  Typ forallType(List<Name> quantifiers, Typ type, {Location location}) {
    Name r0 = quantifiers.fold(name.empty, name.compose);
    return typ.compose(name2typ.apply(r0), type);
  }
  Typ arrowType(List<Typ> domain, Typ codomain, {Location location}) {
    Typ acc = domain.fold(typ.empty, typ.compose);
    return typ.compose(acc, codomain);
  }
  Typ typeConstr(Name name, List<Typ> arguments, {Location location}) => arguments.fold(name2typ.apply(name), typ.compose);
  Typ tupleType(List<Typ> components, {Location location}) => components.fold(typ.empty, typ.compose);
  Typ errorType(LocatedError error, {Location location}) => typ.empty;

  Name termName(String ident, {Location location}) => name.empty;
  Name typeName(String ident, {Location location}) => name.empty;
  Name errorName(LocatedError error, {Location location}) => name.empty;
}

abstract class Reduce<TResult> extends Fold<TResult, TResult, TResult, TResult, TResult> {
  Monoid<TResult> get mod;
  Monoid<TResult> get exp;
  Monoid<TResult> get name;
  Monoid<TResult> get pat;
  Monoid<TResult> get typ;

  // Primitive converters.
  Morphism<TResult, TResult> get name2typ;
  Morphism<TResult, TResult> get typ2pat;
  Morphism<TResult, TResult> get typ2exp;
  Morphism<TResult, TResult> get pat2exp;
  Morphism<TResult, TResult> get exp2mod;

  // TODO.
}

// Error accumulator.

// abstract class ReduceModule<TResult>
//     extends ModuleAlgebra<TResult, TResult, TResult, TResult, TResult> {
//   Monoid<TResult> get m;
//   // final ReduceName<TResult> name;
//   // final ReduceExp<TResult> exp;
//   // final ReducePattern<TResult> pat;
//   // final ReduceType<TResult> typ;

//   // ReduceModule(this.name, this.exp, this.pat, this.typ);

//   TResult datatype(Pair<TResult, List<TResult>> binder,
//       List<Pair<TResult, List<TResult>>> constructors, List<TResult> deriving,
//       {Location location}) {
//     TResult r0 = binder.$2.fold(binder.$1, m.compose);
//     TResult r1 = constructors.fold(
//         r0,
//         (TResult acc, Pair<TResult, List<TResult>> x) =>
//             m.compose(acc, x.$2.fold(x.$1, m.compose)));
//     TResult r3 = deriving.fold(r1, m.compose);
//     return r3;
//   }

//   TResult value(TResult name, TResult body, {Location location}) =>
//       m.compose(name, body);
//   TResult function(TResult binder, List<TResult> parameters, TResult body,
//           {Location location}) =>
//       m.compose(parameters.fold(binder, m.compose), body);
//   TResult module(List<TResult> members, {Location location}) =>
//       members.fold(m.empty, m.compose);
//   TResult typename(Pair<TResult, List<TResult>> binder, TResult type,
//       {Location location}) {
//     TResult r0 = binder.$2.fold(binder.$1, m.compose);
//     return m.compose(r0, type);
//   }

//   TResult signature(TResult binder, TResult type, {Location location}) =>
//       m.compose(binder, type);

//   TResult error(LocatedError error, {Location location}) => m.empty;
// }

// abstract class ReduceExp<TResult>
//     extends ExpAlgebra<TResult, TResult, TResult, TResult> {
//   Monoid<TResult> get m;

//   TResult boolean(bool b, {Location location}) => m.empty;
//   TResult integer(int n, {Location location}) => m.empty;
//   TResult string(String s, {Location location}) => m.empty;

//   TResult var_(TResult name, {Location location}) => name;
//   TResult apply(TResult fn, List<TResult> arguments, {Location location}) =>
//       arguments.fold(fn, m.compose);
//   TResult lambda(List<TResult> parameters, TResult body, {Location location}) =>
//       m.compose(parameters.fold(m.empty, m.compose), body);
//   TResult let(List<Pair<TResult, TResult>> bindings, TResult body,
//       {BindingMethod bindingMethod = BindingMethod.Parallel,
//       Location location}) {
//     TResult r0 = bindings.fold(
//         m.empty,
//         (TResult acc, Pair<TResult, TResult> p) =>
//             m.compose(acc, m.compose(p.$1, p.$2)));
//     return m.compose(r0, body);
//   }

//   TResult tuple(List<TResult> components, {Location location}) =>
//       components.fold(m.empty, m.compose);
//   TResult ifthenelse(TResult condition, TResult thenBranch, TResult elseBranch,
//           {Location location}) =>
//       m.compose(m.compose(condition, thenBranch), elseBranch);
//   TResult match(TResult scrutinee, List<Pair<TResult, TResult>> cases,
//       {Location location}) {
//     return cases.fold(
//         scrutinee,
//         (TResult acc, Pair<TResult, TResult> p) =>
//             m.compose(acc, m.compose(p.$1, p.$2)));
//   }

//   TResult typeAscription(TResult exp, TResult type, {Location location}) =>
//       m.compose(exp, type);

//   TResult error(LocatedError error, {Location location}) => m.empty;
// }

// abstract class ReducePattern<TResult>
//     extends PatternAlgebra<TResult, TResult, TResult> {
//   Monoid<TResult> get m;

//   TResult hasType(TResult pattern, TResult type, {Location location}) =>
//       m.compose(pattern, type);
//   TResult boolean(bool b, {Location location}) => m.empty;
//   TResult integer(int n, {Location location}) => m.empty;
//   TResult string(String s, {Location location}) => m.empty;
//   TResult wildcard({Location location}) => m.empty;
//   TResult var_(TResult name, {Location location}) => name;
//   TResult constr(TResult name, List<TResult> parameters, {Location location}) =>
//       parameters.fold(name, m.compose);
//   TResult tuple(List<TResult> components, {Location location}) =>
//       components.fold(m.empty, m.compose);

//   TResult error(LocatedError error, {Location location}) => m.empty;
// }

// abstract class ReduceType<TResult> extends TypeAlgebra<TResult, TResult> {
//   Monoid<TResult> get m;

//   TResult integer({Location location}) => m.empty;
//   TResult boolean({Location location}) => m.empty;
//   TResult string({Location location}) => m.empty;
//   TResult var_(TResult name, {Location location}) => name;
//   TResult forall(List<TResult> quantifiers, TResult type,
//           {Location location}) =>
//       m.compose(quantifiers.fold(m.empty, m.compose), type);
//   TResult arrow(List<TResult> domain, TResult codomain, {Location location}) =>
//       m.compose(domain.fold(m.empty, m.compose), codomain);
//   TResult constr(TResult name, List<TResult> arguments, {Location location}) =>
//       arguments.fold(name, m.compose);
//   TResult tuple(List<TResult> components, {Location location}) =>
//       components.fold(m.empty, m.compose);

//   TResult error(LocatedError error, {Location location});
// }

// abstract class ReduceName<TResult> extends NameAlgebra<TResult> {
//   Monoid<TResult> get m;

//   TResult termName(String name, {Location location}) => m.empty;
//   TResult typeName(String name, {Location location}) => m.empty;

//   TResult error(LocatedError error, {Location location}) => m.empty;
// }

// // Error collecting reduction.
// class CollectErrorsMixin {
//   Monoid<List<LocatedError>> _m = new ListMonoid<LocatedError>();
//   Monoid<List<LocatedError>> get m => _m;

//   List<LocatedError> error(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
// }

// class CollectModuleErrors = ReduceModule<List<LocatedError>>
//     with CollectErrorsMixin;
// class CollectExpErrors = ReduceExp<List<LocatedError>> with CollectErrorsMixin;
// class CollectPatternErrors = ReducePattern<List<LocatedError>>
//     with CollectErrorsMixin;
// class CollectTypeErrors = ReduceType<List<LocatedError>>
//     with CollectErrorsMixin;
// class CollectNameErrors = ReduceName<List<LocatedError>>
//     with CollectErrorsMixin;

// // Free variables reduction.
// class FreeVarsMixin<Name> {
//   Monoid<Set<Name>> _m = new SetMonoid<Name>();
//   Monoid<Set<Name>> get m => _m;
// }

// class FreeVarsModule<Name> extends ReduceModule<Set<Name>>
//     with FreeVarsMixin<Name> {
//   Set<Name> globals = new Set<Name>();

//   Set<Name> module(List<Set<Name>> members, {Location location}) {
//     Set<Name> fvs = members.fold(m.empty, m.compose);
//     fvs = fvs.difference(globals);
//     return fvs;
//   }

//   Set<Name> value(Set<Name> name, Set<Name> body, {Location location}) {
//     globals = m.compose(globals, name);
//     return body;
//   }

//   Set<Name> function(
//       Set<Name> binder, List<Set<Name>> parameters, Set<Name> body,
//       {Location location}) {
//     globals = m.compose(globals, binder);
//     Set<Name> fvs = body;
//     for (int i = 0; i < parameters.length; i++) {
//       fvs = fvs.difference(parameters[i]);
//     }
//     return fvs;
//   }
// }

// class FreeVarsExp<Name> extends ReduceExp<Set<Name>> with FreeVarsMixin<Name> {
//   Set<Name> lambda(List<Set<Name>> parameters, Set<Name> body,
//       {Location location}) {
//     Set<Name> params = parameters.fold(m.empty, m.compose);
//     return body.difference(params);
//   }

//   Set<Name> let(List<Pair<Set<Name>, Set<Name>>> bindings, Set<Name> body,
//       {BindingMethod bindingMethod = BindingMethod.Parallel,
//       Location location}) {
//     Set<Name> bvs = m.empty;
//     Set<Name> fvs = m.empty;
//     switch (bindingMethod) {
//       case BindingMethod.Parallel:
//         for (int i = 0; i < bindings.length; i++) {
//           bvs = m.compose(bvs, bindings[i].$1);
//           fvs = m.compose(fvs, bindings[i].$2);
//         }
//         break;
//       case BindingMethod.Sequential:
//         for (int i = 0; i < bindings.length; i++) {
//           fvs = m.compose(fvs, bindings[i].$2.difference(bvs));
//           bvs = m.compose(bvs, bindings[i].$1);
//         }
//         break;
//     }
//     return m.compose(fvs, body.difference(bvs));
//   }

//   Set<Name> match(Set<Name> scrutinee, List<Pair<Set<Name>, Set<Name>>> cases,
//       {Location location}) {
//     Set<Name> fvs = scrutinee;
//     for (int i = 0; i < cases.length; i++) {
//       fvs = m.compose(fvs, cases[i].$2.difference(cases[i].$1));
//     }
//     return fvs;
//   }
// }

// class FreeVarsPat<Name> = ReducePattern<Set<Name>> with FreeVarsMixin<Name>;

// class FreeVarsName extends ReduceName<Set<String>> {
//   Monoid<Set<String>> get m => null;

//   Set<String> termName(String name, {Location location}) {
//     return new Set<String>()..add(name);
//   }

//   Set<String> typeName(String name, {Location location}) => new Set<String>();
// }

// Free type variables.
// class FreeTypeVarsTyp<Name> extends ReduceType<Set<Name>> with FreeVarsMixin {
//   Set<Name> forall(List<Set<Name>> quantifiers, Set<Name> type,
//                    {Location location}) {
//     Set<Name> bvs = quantifiers.fold(m.empty, m.compose);
//     return type.difference(bvs);
//   }
// }
