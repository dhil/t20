// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../errors/errors.dart' show LocatedError;
import '../fp.dart' show Pair;
import '../location.dart';
import '../string_pool.dart';

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

// abstract class Morphism<S, T> {

//   const factory Morphism.of(T Function(S) f) = _FuncMorphism<S, T>;
//   T apply(S x);
// }

class Morphism<S, T> {
  final T Function(S) _f;
  const Morphism.of(this._f);
  T apply(S x) => _f(x);
}

class Endomorphism<S> extends Morphism<S, S> {
  const Endomorphism.of(S Function(S) f) : super.of(f);
}

// abstract class GMorphism {
//   Morphism<S, T> generate<S, T>();
// }

// Generic reductive traversals.
abstract class TypeCatamorphism<Name, Typ> extends TypeAlgebra<Name, Typ> {
  // A specialised monoid for each sort.
  Monoid<Name> get name;
  Monoid<Typ> get typ;

  // Primitive converters.
  Morphism<Name, Typ> get name2typ;

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

  Typ typeConstr(Name name, List<Typ> arguments, {Location location}) =>
      arguments.fold(name2typ.apply(name), typ.compose);
  Typ tupleType(List<Typ> components, {Location location}) =>
      components.fold(typ.empty, typ.compose);
  Typ errorType(LocatedError error, {Location location}) => typ.empty;
}

abstract class TypeReduction<T> extends TypeCatamorphism<T, T> {
  Monoid<T> get m;

  // A specialised monoid for each sort.
  Monoid<T> get name => m;
  Monoid<T> get typ => m;

  // Primitive converters.
  static T _id<T>(T x) => x;
  Endomorphism<T> id = Endomorphism<T>.of(_id);
  Endomorphism<T> get name2typ => id;
}

abstract class Catamorphism<Name, Mod, Exp, Pat, Typ>
    extends TAlgebra<Name, Mod, Exp, Pat, Typ>
    implements TypeCatamorphism<Name, Typ> {
  // A specialised monoid for each sort.
  Monoid<Mod> get mod;
  Monoid<Exp> get exp;
  Monoid<Pat> get pat;

  // Primitive converters.
  Morphism<Typ, Pat> get typ2pat;
  Morphism<Typ, Exp> get typ2exp;
  Morphism<Pat, Exp> get pat2exp;
  Morphism<Exp, Mod> get exp2mod;

  // Derived converters.
  Morphism<Name, Mod> _name2mod;
  Morphism<Name, Mod> get name2mod {
    _name2mod ??= Morphism<Name, Mod>.of(
        (Name name) => exp2mod.apply(name2exp.apply(name)));
    return _name2mod;
  }

  Morphism<Name, Exp> _name2exp;
  Morphism<Name, Exp> get name2exp {
    _name2exp ??= Morphism<Name, Exp>.of(
        (Name name) => typ2exp.apply(name2typ.apply(name)));
    return _name2exp;
  }

  Morphism<Pat, Mod> _pat2mod;
  Morphism<Pat, Mod> get pat2mod {
    _pat2mod ??=
        Morphism<Pat, Mod>.of((Pat p) => exp2mod.apply(pat2exp.apply(p)));
    return _pat2mod;
  }

  Morphism<Name, Pat> _name2pat;
  Morphism<Name, Pat> get name2pat {
    _name2pat ??= Morphism<Name, Pat>.of(
        (Name name) => typ2pat.apply(name2typ.apply(name)));
    return _name2pat;
  }

  Morphism<Typ, Mod> _typ2mod;
  Morphism<Typ, Mod> get typ2mod {
    _typ2mod ??=
        Morphism<Typ, Mod>.of((Typ typ) => exp2mod.apply(typ2exp.apply(typ)));
    return _typ2mod;
  }

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

  Typ typeConstr(Name name, List<Typ> arguments, {Location location}) =>
      arguments.fold(name2typ.apply(name), typ.compose);
  Typ tupleType(List<Typ> components, {Location location}) =>
      components.fold(typ.empty, typ.compose);
  Typ errorType(LocatedError error, {Location location}) => typ.empty;

  Name termName(String ident, {Location location}) => name.empty;
  Name typeName(String ident, {Location location}) => name.empty;
  Name errorName(LocatedError error, {Location location}) => name.empty;
}

abstract class Reduction<T> extends Catamorphism<T, T, T, T, T> {
  Monoid<T> get m;

  Monoid<T> get mod => m;
  Monoid<T> get exp => m;
  Monoid<T> get name => m;
  Monoid<T> get pat => m;
  Monoid<T> get typ => m;

  // Primitive converters.
  static T _id<T>(T x) => x;
  Endomorphism<T> id = Endomorphism<T>.of(_id);
  Endomorphism<T> get name2typ => id;
  Endomorphism<T> get typ2pat => id;
  Endomorphism<T> get typ2exp => id;
  Endomorphism<T> get pat2exp => id;
  Endomorphism<T> get exp2mod => id;
}

// Error accumulator.
class ErrorCollector extends Reduction<List<LocatedError>> {
  final ListMonoid<LocatedError> _m = new ListMonoid<LocatedError>();
  Monoid<List<LocatedError>> get m => _m;

  List<LocatedError> errorModule(LocatedError error, {Location location}) =>
      <LocatedError>[error];
  List<LocatedError> errorExp(LocatedError error, {Location location}) =>
      <LocatedError>[error];
  List<LocatedError> errorPattern(LocatedError error, {Location location}) =>
      <LocatedError>[error];
  List<LocatedError> errorType(LocatedError error, {Location location}) =>
      <LocatedError>[error];
  List<LocatedError> errorName(LocatedError error, {Location location}) =>
      <LocatedError>[error];
}

// Free type variables.
class FreeTypeVars<Name> extends Reduction<Set<Name>> {
  final SetMonoid<Name> _m = new SetMonoid<Name>();
  Monoid<Set<Name>> get m => _m;

  Set<Name> forallType(List<Set<Name>> quantifiers, Set<Name> type,
      {Location location}) {
    Set<Name> boundVars = quantifiers.fold(m.empty, m.compose);
    return type.difference(boundVars);
  }
}

class SigInfo<Name> {
  final Set<Name> freeVariables;
  final Set<Name> boundVariables;
  final bool hasExplicitForall;

  const SigInfo(
      this.hasExplicitForall, this.freeVariables, this.boundVariables);
  SigInfo.empty() : this(false, new Set<Name>(), new Set<Name>());
}

class SigInfoMonoid<Name> implements Monoid<SigInfo<Name>> {
  SigInfo<Name> get empty => new SigInfo<Name>.empty();
  SigInfo<Name> compose(SigInfo<Name> x, SigInfo<Name> y) {
    Set<Name> bvs = x.boundVariables.union(y.boundVariables);
    Set<Name> fvs = x.freeVariables.union(y.freeVariables);
    bool hasExplicitForall = x.hasExplicitForall || y.hasExplicitForall;
    return SigInfo<Name>(hasExplicitForall, fvs, bvs);
  }
}

class ComputeSigInfo<Name> extends Reduction<SigInfo<Name>> {
  final SigInfoMonoid<Name> _m = new SigInfoMonoid<Name>();
  Monoid<SigInfo<Name>> get m => _m;

  SigInfo<Name> forallType(List<SigInfo<Name>> quantifiers, SigInfo<Name> type,
      {Location location}) {
    SigInfo<Name> si = quantifiers.fold(m.empty, m.compose);
    Set<Name> bvs = si
        .freeVariables; // It's a bit unfortunate that the "bound names" are the "free names".
    Set<Name> fvs = type.freeVariables.difference(bvs);
    return SigInfo<Name>(true, fvs, bvs);
  }
}

class TrueBiasedMonoid implements Monoid<bool> {
  bool get empty => false;
  bool compose(bool x, bool y) => x || y;
}

class CheckSignatureHasForall extends Reduction<bool> {
  final TrueBiasedMonoid _m = new TrueBiasedMonoid();
  Monoid<bool> get m => _m;

  bool module(List<bool> members, {Location location}) =>
      members.every((b) => b == true);
  bool datatype(Pair<bool, List<bool>> binder,
          List<Pair<bool, List<bool>>> constructors, List<bool> deriving,
          {Location location}) =>
      true;
  bool valueDef(bool name, bool body, {Location location}) => true;
  bool functionDef(bool name, List<bool> parameters, bool body,
          {Location location}) =>
      true;
  bool typename(Pair<bool, List<bool>> constr, bool type,
          {Location location}) =>
      true;
  bool signature(bool name, bool type, {Location location}) => type;
  bool errorModule(LocatedError error, {Location location}) => true;

  bool forallType(List<bool> quantifiers, bool type, {Location location}) =>
      true;
}

// Transforms.
abstract class Transform<Name, Mod, Exp, Pat, Typ>
    extends TAlgebra<Name, Mod, Exp, Pat, Typ> {
  TAlgebra<Name, Mod, Exp, Pat, Typ> get alg;

  Mod datatype(Pair<Name, List<Name>> binder,
          List<Pair<Name, List<Typ>>> constructors, List<Name> deriving,
          {Location location}) =>
      alg.datatype(binder, constructors, deriving, location: location);

  Mod valueDef(Name name, Exp body, {Location location}) =>
      alg.valueDef(name, body, location: location);
  Mod functionDef(Name name, List<Pat> parameters, Exp body,
          {Location location}) =>
      alg.functionDef(name, parameters, body, location: location);
  Mod module(List<Mod> members, {Location location}) =>
      alg.module(members, location: location);
  Mod typename(Pair<Name, List<Name>> constr, Typ type, {Location location}) =>
      alg.typename(constr, type, location: location);
  Mod signature(Name name, Typ type, {Location location}) =>
      alg.signature(name, type, location: location);
  Mod errorModule(LocatedError error, {Location location}) =>
      alg.errorModule(error, location: location);

  Exp boolLit(bool b, {Location location}) =>
      alg.boolLit(b, location: location);
  Exp intLit(int n, {Location location}) => alg.intLit(n, location: location);
  Exp stringLit(String s, {Location location}) =>
      alg.stringLit(s, location: location);
  Exp varExp(Name name, {Location location}) =>
      alg.varExp(name, location: location);
  Exp apply(Exp fn, List<Exp> arguments, {Location location}) =>
      alg.apply(fn, arguments, location: location);
  Exp lambda(List<Pat> parameters, Exp body, {Location location}) =>
      alg.lambda(parameters, body, location: location);
  Exp let(List<Pair<Pat, Exp>> bindings, Exp body,
          {BindingMethod bindingMethod = BindingMethod.Parallel,
          Location location}) =>
      alg.let(bindings, body, bindingMethod: bindingMethod, location: location);
  Exp tuple(List<Exp> components, {Location location}) =>
      alg.tuple(components, location: location);
  Exp ifthenelse(Exp condition, Exp thenBranch, Exp elseBranch,
          {Location location}) =>
      alg.ifthenelse(condition, thenBranch, elseBranch, location: location);
  Exp match(Exp scrutinee, List<Pair<Pat, Exp>> cases, {Location location}) =>
      alg.match(scrutinee, cases, location: location);
  Exp typeAscription(Exp e, Typ type, {Location location}) =>
      alg.typeAscription(e, type, location: location);
  Exp errorExp(LocatedError error, {Location location}) =>
      alg.errorExp(error, location: location);

  Pat hasTypePattern(Pat pattern, Typ type, {Location location}) =>
      alg.hasTypePattern(pattern, type, location: location);
  Pat boolPattern(bool b, {Location location}) =>
      alg.boolPattern(b, location: location);
  Pat intPattern(int n, {Location location}) =>
      alg.intPattern(n, location: location);
  Pat stringPattern(String s, {Location location}) =>
      alg.stringPattern(s, location: location);
  Pat wildcard({Location location}) => alg.wildcard(location: location);
  Pat varPattern(Name name, {Location location}) =>
      alg.varPattern(name, location: location);
  Pat constrPattern(Name name, List<Pat> parameters, {Location location}) =>
      alg.constrPattern(name, parameters, location: location);
  Pat tuplePattern(List<Pat> components, {Location location}) =>
      alg.tuplePattern(components, location: location);
  Pat errorPattern(LocatedError error, {Location location}) =>
      alg.errorPattern(error, location: location);

  Typ intType({Location location}) => alg.intType(location: location);
  Typ boolType({Location location}) => alg.boolType(location: location);
  Typ stringType({Location location}) => alg.stringType(location: location);
  Typ typeVar(Name name, {Location location}) =>
      alg.typeVar(name, location: location);
  Typ forallType(List<Name> quantifiers, Typ type, {Location location}) =>
      alg.forallType(quantifiers, type, location: location);
  Typ arrowType(List<Typ> domain, Typ codomain, {Location location}) =>
      alg.arrowType(domain, codomain, location: location);
  Typ typeConstr(Name name, List<Typ> arguments, {Location location}) =>
      alg.typeConstr(name, arguments, location: location);
  Typ tupleType(List<Typ> components, {Location location}) =>
      alg.tupleType(components, location: location);
  Typ errorType(LocatedError error, {Location location}) =>
      alg.errorType(error, location: location);

  Name termName(String ident, {Location location}) =>
      alg.termName(ident, location: location);
  Name typeName(String ident, {Location location}) =>
      alg.typeName(ident, location: location);
  Name errorName(LocatedError error, {Location location}) =>
      alg.errorName(error, location: location);
}

// Contextual transformations.
typedef Transformer<C, T> = T Function(C);

abstract class ContextualTransformation<C, Name, Mod, Exp, Pat, Typ>
    extends TAlgebra<Transformer<C, Name>, Transformer<C, Mod>,
        Transformer<C, Exp>, Transformer<C, Pat>, Transformer<C, Typ>> {
  TAlgebra<Name, Mod, Exp, Pat, Typ> get alg;

  Transformer<C, Mod> datatype(
          Pair<Transformer<C, Name>, List<Transformer<C, Name>>> binder,
          List<Pair<Transformer<C, Name>, List<Transformer<C, Typ>>>>
              constructors,
          List<Transformer<C, Name>> deriving,
          {Location location}) =>
      (C c) {
        Name name = binder.$1(c);
        List<Name> qs = binder.$2.map((f) => f(c)).toList();
        Pair<Name, List<Name>> binder0 = new Pair<Name, List<Name>>(name, qs);
        List<Pair<Name, List<Typ>>> constructors0 =
            new List<Pair<Name, List<Typ>>>(constructors.length);
        for (int i = 0; i < constructors.length; i++) {
          Name cname = constructors[i].$1(c);
          List<Typ> types = new List<Typ>(constructors[i].$2.length);
          for (int j = 0; j < types.length; j++) {
            types[j] = constructors[i].$2[j](c);
          }
          constructors0[i] = new Pair<Name, List<Typ>>(cname, types);
        }
        List<Name> deriving0 = deriving.map((f) => f(c)).toList();
        return alg.datatype(binder0, constructors0, deriving0,
            location: location);
      };

  Transformer<C, Mod> valueDef(
          Transformer<C, Name> name, Transformer<C, Exp> body,
          {Location location}) =>
      (C c) => alg.valueDef(name(c), body(c), location: location);
  Transformer<C, Mod> functionDef(Transformer<C, Name> name,
          List<Transformer<C, Pat>> parameters, Transformer<C, Exp> body,
          {Location location}) =>
      (C c) {
        Name fname = name(c);
        List<Pat> params = parameters.map((f) => f(c)).toList();
        alg.functionDef(fname, params, body(c), location: location);
      };
  Transformer<C, Mod> module(List<Transformer<C, Mod>> members,
          {Location location}) =>
      (C c) =>
          alg.module(members.map((f) => f(c)).toList(), location: location);
  Transformer<C, Mod> typename(
          Pair<Transformer<C, Name>, List<Transformer<C, Name>>> constr,
          Transformer<C, Typ> type,
          {Location location}) =>
      (C c) {
        Name constrName = constr.$1(c);
        List<Name> parameters = constr.$2.map((f) => f(c)).toList();
        Pair<Name, List<Name>> constr0 =
            Pair<Name, List<Name>>(constrName, parameters);
        return alg.typename(constr0, type(c), location: location);
      };
  Transformer<C, Mod> signature(
          Transformer<C, Name> name, Transformer<C, Typ> type,
          {Location location}) =>
      (C c) => alg.signature(name(c), type(c), location: location);
  Transformer<C, Mod> errorModule(LocatedError error, {Location location}) =>
      (C _) => alg.errorModule(error, location: location);

  Transformer<C, Exp> boolLit(bool b, {Location location}) =>
      (C _) => alg.boolLit(b, location: location);
  Transformer<C, Exp> intLit(int n, {Location location}) =>
      (C _) => alg.intLit(n, location: location);
  Transformer<C, Exp> stringLit(String s, {Location location}) =>
      (C _) => alg.stringLit(s, location: location);
  Transformer<C, Exp> varExp(Transformer<C, Name> name, {Location location}) =>
      (C c) => alg.varExp(name(c), location: location);
  Transformer<C, Exp> apply(
          Transformer<C, Exp> fn, List<Transformer<C, Exp>> arguments,
          {Location location}) =>
      (C c) => alg.apply(fn(c), arguments.map((f) => f(c)).toList(),
          location: location);
  Transformer<C, Exp> lambda(
          List<Transformer<C, Pat>> parameters, Transformer<C, Exp> body,
          {Location location}) =>
      (C c) => alg.lambda(parameters.map((f) => f(c)).toList(), body(c),
          location: location);
  Transformer<C, Exp> let(
          List<Pair<Transformer<C, Pat>, Transformer<C, Exp>>> bindings,
          Transformer<C, Exp> body,
          {BindingMethod bindingMethod = BindingMethod.Parallel,
          Location location}) =>
      (C c) {
        List<Pair<Pat, Exp>> valBindings =
            new List<Pair<Pat, Exp>>(bindings.length);
        for (int i = 0; i < bindings.length; i++) {
          valBindings[i] =
              new Pair<Pat, Exp>(bindings[i].$1(c), bindings[i].$2(c));
        }
        return alg.let(valBindings, body(c),
            bindingMethod: bindingMethod, location: location);
      };
  Transformer<C, Exp> tuple(List<Transformer<C, Exp>> components,
          {Location location}) =>
      (C c) =>
          alg.tuple(components.map((f) => f(c)).toList(), location: location);
  Transformer<C, Exp> ifthenelse(Transformer<C, Exp> condition,
          Transformer<C, Exp> thenBranch, Transformer<C, Exp> elseBranch,
          {Location location}) =>
      (C c) => alg.ifthenelse(condition(c), thenBranch(c), elseBranch(c),
          location: location);
  Transformer<C, Exp> match(Transformer<C, Exp> scrutinee,
          List<Pair<Transformer<C, Pat>, Transformer<C, Exp>>> cases,
          {Location location}) =>
      (C c) {
        Exp e = scrutinee(c);
        List<Pair<Pat, Exp>> clauses = new List<Pair<Pat, Exp>>(cases.length);
        for (int i = 0; i < cases.length; i++) {
          clauses[i] = Pair<Pat, Exp>(cases[i].$1(c), cases[i].$2(c));
        }
        return alg.match(e, clauses, location: location);
      };
  Transformer<C, Exp> typeAscription(
          Transformer<C, Exp> e, Transformer<C, Typ> type,
          {Location location}) =>
      (C c) => alg.typeAscription(e(c), type(c), location: location);
  Transformer<C, Exp> errorExp(LocatedError error, {Location location}) =>
      (C _) => alg.errorExp(error, location: location);

  Transformer<C, Pat> hasTypePattern(
          Transformer<C, Pat> pattern, Transformer<C, Typ> type,
          {Location location}) =>
      (C c) => alg.hasTypePattern(pattern(c), type(c), location: location);
  Transformer<C, Pat> boolPattern(bool b, {Location location}) =>
      (C _) => alg.boolPattern(b, location: location);
  Transformer<C, Pat> intPattern(int n, {Location location}) =>
      (C _) => alg.intPattern(n, location: location);
  Transformer<C, Pat> stringPattern(String s, {Location location}) =>
      (C _) => alg.stringPattern(s, location: location);
  Transformer<C, Pat> wildcard({Location location}) =>
      (C _) => alg.wildcard(location: location);
  Transformer<C, Pat> varPattern(Transformer<C, Name> name,
          {Location location}) =>
      (C c) => alg.varPattern(name(c), location: location);
  Transformer<C, Pat> constrPattern(
          Transformer<C, Name> name, List<Transformer<C, Pat>> parameters,
          {Location location}) =>
      (C c) => alg.constrPattern(name(c), parameters.map((f) => f(c)).toList(),
          location: location);
  Transformer<C, Pat> tuplePattern(List<Transformer<C, Pat>> components,
          {Location location}) =>
      (C c) => alg.tuplePattern(components.map((f) => f(c)).toList(),
          location: location);
  Transformer<C, Pat> errorPattern(LocatedError error, {Location location}) =>
      (C _) => alg.errorPattern(error, location: location);

  Transformer<C, Typ> intType({Location location}) =>
      (C _) => alg.intType(location: location);
  Transformer<C, Typ> boolType({Location location}) =>
      (C _) => alg.boolType(location: location);
  Transformer<C, Typ> stringType({Location location}) =>
      (C _) => alg.stringType(location: location);
  Transformer<C, Typ> typeVar(Transformer<C, Name> name, {Location location}) =>
      (C c) => alg.typeVar(name(c), location: location);
  Transformer<C, Typ> forallType(
          List<Transformer<C, Name>> quantifiers, Transformer<C, Typ> type,
          {Location location}) =>
      (C c) => alg.forallType(quantifiers.map((f) => f(c)).toList(), type(c),
          location: location);
  Transformer<C, Typ> arrowType(
          List<Transformer<C, Typ>> domain, Transformer<C, Typ> codomain,
          {Location location}) =>
      (C c) => alg.arrowType(domain.map((f) => f(c)), codomain(c),
          location: location);
  Transformer<C, Typ> typeConstr(
          Transformer<C, Name> name, List<Transformer<C, Typ>> arguments,
          {Location location}) =>
      (C c) => alg.typeConstr(name(c), arguments.map((f) => f(c)).toList(),
          location: location);
  Transformer<C, Typ> tupleType(List<Transformer<C, Typ>> components,
          {Location location}) =>
      (C c) => alg.tupleType(components.map((f) => f(c)).toList(),
          location: location);
  Transformer<C, Typ> errorType(LocatedError error, {Location location}) =>
      (C _) => alg.errorType(error, location: location);

  Transformer<C, Name> termName(String ident, {Location location}) =>
      (C _) => alg.termName(ident, location: location);
  Transformer<C, Name> typeName(String ident, {Location location}) =>
      (C _) => alg.typeName(ident, location: location);
  Transformer<C, Name> errorName(LocatedError error, {Location location}) =>
      (C _) => alg.errorName(error, location: location);
}

class ResolvedName {
  static StringPool _sharedPool;
  final int intern;
  final int id;
  final Location location;
  const ResolvedName._(this.intern, this.id, this.location);

  String get sourceName => _sharedPool[intern];
}

class NameContext {
  final Map<String, int> nameEnv;
  final Map<String, int> tynameEnv;

  NameContext(this.nameEnv, this.tynameEnv) {
    ResolvedName._sharedPool ??= new StringPool();
  }

  StringPool get sharedPool => ResolvedName._sharedPool;

  ResolvedName addTermName(String name, {Location location}) {
    return null;
  }

  ResolvedName addTypeName(String name, {Location location}) {
    return null;
  }
}

class NameResolver<Mod, Exp, Pat, Typ> extends ContextualTransformation<
    NameContext, ResolvedName, Mod, Exp, Pat, Typ> {
  TAlgebra<ResolvedName, Mod, Exp, Pat, Typ> get alg => null;
}
