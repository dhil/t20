// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show LocatedError;
import '../fp.dart' show Pair, Quadruple;
import '../location.dart';

import 'algebra.dart';
import 'monoids.dart';

class Morphism<S, T> {
  final T Function(S) _f;
  const Morphism.of(this._f);
  T apply(S x) => _f(x);
}

class Endomorphism<S> extends Morphism<S, S> {
  const Endomorphism.of(S Function(S) f) : super.of(f);
}

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
  Typ constraintType(List<Pair<Name, Typ>> constraints, Typ body,
      {Location location}) {
    Typ result = typ.empty;
    for (int i = 0; i < constraints.length; i++) {
      Pair<Name, Typ> constraint = constraints[i];
      typ.compose(
          result, typ.compose(name2typ.apply(constraint.fst), constraint.snd));
    }
    return typ.compose(result, body);
  }

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

  // Mod datatype(Name binder, List<Name> typeParameters,
  //     List<Pair<Name, List<Typ>>> constructors, List<Name> deriving,
  //     {Location location}) {
  //   Name r0 = typeParameters.fold(binder, name.compose);
  //   Typ r1 = name2typ.apply(r0);
  //   for (int i = 0; i < constructors.length; i++) {
  //     Typ seed = typ.compose(r1, name2typ.apply(constructors[i].$1));
  //     r1 = constructors[i].$2.fold(seed, typ.compose);
  //   }
  //   Mod r2 = typ2mod.apply(r1);
  //   Name r3 = deriving.fold(name.empty, name.compose);
  //   return mod.compose(r2, name2mod.apply(r3));
  // }

  Mod datatypes(
      List<Quadruple<Name, List<Name>, List<Pair<Name, List<Typ>>>, List<Name>>>
          defs,
      {Location location}) {
    Mod r0 = mod.empty;
    for (int i = 0; i < defs.length; i++) {
      Quadruple<Name, List<Name>, List<Pair<Name, List<Typ>>>, List<Name>> def =
          defs[i];
      Name r1 = def.$1;
      r1 = def.$2.fold(r1, name.compose);
      r0 = mod.compose(r0, name2mod.apply(r1));
      List<Pair<Name, List<Typ>>> constrs = def.$3;
      for (int j = 0; j < constrs.length; j++) {
        Pair<Name, List<Typ>> constr = constrs[i];
        Typ seed = name2typ.apply(constr.$1);
        Typ result = constr.$2.fold(seed, typ.compose);
        r0 = mod.compose(r0, typ2mod.apply(result));
      }
      List<Name> deriving = def.$4;
      Name r3 = deriving.fold(name.empty, name.compose);
      r0 = mod.compose(r0, name2mod.apply(r3));
    }
    return r0;
  }

  Mod stub(Name name, List<Pat> parameters, {Location location}) =>
      parameters == null
          ? name2mod.apply(name)
          : pat2mod.apply(parameters.fold(name2pat.apply(name), pat.compose));

  Mod valueDef(Name name, Exp body, {Location location}) =>
      exp2mod.apply(exp.compose(name2exp.apply(name), body));

  Mod functionDef(Name name, List<Pat> parameters, Exp body,
      {Location location}) {
    Pat r0 = parameters.fold(name2pat.apply(name), pat.compose);
    return mod.compose(pat2mod.apply(r0), exp2mod.apply(body));
  }

  Mod module(List<Mod> members, String name, {Location location}) =>
      members.fold(mod.empty, mod.compose);
  Mod typename(Name binder, List<Name> typeParameters, Typ type,
      {Location location}) {
    Name r0 = typeParameters.fold(binder, name.compose);
    return mod.compose(name2mod.apply(r0), typ2mod.apply(type));
  }

  Mod signature(Name name, Typ type, {Location location}) =>
      mod.compose(name2mod.apply(name), typ2mod.apply(type));
  Mod open(String moduleName, {Location location}) => mod.empty;
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
  Typ constraintType(List<Pair<Name, Typ>> constraints, Typ body,
      {Location location}) {
    Typ result = typ.empty;
    for (int i = 0; i < constraints.length; i++) {
      Pair<Name, Typ> constraint = constraints[i];
      typ.compose(
          result, typ.compose(name2typ.apply(constraint.fst), constraint.snd));
    }
    return typ.compose(result, body);
  }

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
// class ErrorCollector extends Reduction<List<LocatedError>> {
//   final ListMonoid<LocatedError> _m = new ListMonoid<LocatedError>();
//   Monoid<List<LocatedError>> get m => _m;

//   List<LocatedError> errorModule(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
//   List<LocatedError> errorExp(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
//   List<LocatedError> errorPattern(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
//   List<LocatedError> errorType(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
//   List<LocatedError> errorName(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
// }

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

class ComputeSigInfo extends Reduction<SigInfo<String>> {
  final SigInfoMonoid<String> _m = new SigInfoMonoid<String>();
  Monoid<SigInfo<String>> get m => _m;

  SigInfo<String> forallType(
      List<SigInfo<String>> quantifiers, SigInfo<String> type,
      {Location location}) {
    SigInfo<String> si = quantifiers.fold(m.empty, m.compose);
    Set<String> bvs = si
        .freeVariables; // It's a bit unfortunate that the "bound names" are the "free names".
    Set<String> fvs = type.freeVariables.difference(bvs);
    return SigInfo<String>(true, fvs, bvs);
  }

  SigInfo<String> typeName(String ident, {Location location}) {
    return SigInfo<String>(
        false, new Set<String>()..add(ident), new Set<String>());
  }

  SigInfo<String> typeConstr(SigInfo<String> _, List<SigInfo<String>> arguments, {Location location}) => arguments.fold(m.empty, m.compose);
}

// class TrueBiasedMonoid implements Monoid<bool> {
//   bool get empty => false;
//   bool compose(bool x, bool y) => x || y;
// }

// // class CheckSignatureHasForall extends Reduction<bool> {
// //   final TrueBiasedMonoid _m = new TrueBiasedMonoid();
// //   Monoid<bool> get m => _m;

// //   bool module(List<bool> members, {Location location}) =>
// //       members.every((b) => b == true);
// //   // bool datatype(bool binder, List<bool> typeParameters,
// //   //         List<Pair<bool, List<bool>>> constructors, List<bool> deriving,
// //   //         {Location location}) =>
// //   //     true;

// //   bool datatypes(
// //           List<Triple<bool, List<bool>, List<Pair<bool, List<bool>>>>> defs,
// //           List<bool> deriving,
// //           {Location location}) =>
// //       true;
// //   bool valueDef(bool name, bool body, {Location location}) => true;
// //   bool functionDef(bool name, List<bool> parameters, bool body,
// //           {Location location}) =>
// //       true;
// //   bool typename(bool binder, List<bool> typeParameters, bool type,
// //           {Location location}) =>
// //       true;
// //   bool signature(bool name, bool type, {Location location}) => type;
// //   bool errorModule(LocatedError error, {Location location}) => true;

// //   bool forallType(List<bool> quantifiers, bool type, {Location location}) =>
// //       true;
// // }

// // Transforms.
// abstract class Transformation<Name, Mod, Exp, Pat, Typ>
//     extends TAlgebra<Name, Mod, Exp, Pat, Typ> {
//   TAlgebra<Name, Mod, Exp, Pat, Typ> get alg;

//   // Mod datatype(Name binder, List<Name> typeParameters,
//   //         List<Pair<Name, List<Typ>>> constructors, List<Name> deriving,
//   //         {Location location}) =>
//   //     alg.datatype(binder, typeParameters, constructors, deriving,
//   //         location: location);

//   Mod datatypes(
//           List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>> defs,
//           List<Name> deriving,
//           {Location location}) =>
//       alg.datatypes(defs, deriving, location: location);

//   Mod valueDef(Name name, Exp body, {Location location}) =>
//       alg.valueDef(name, body, location: location);
//   Mod functionDef(Name name, List<Pat> parameters, Exp body,
//           {Location location}) =>
//       alg.functionDef(name, parameters, body, location: location);
//   Mod module(List<Mod> members, String name, {Location location}) =>
//       alg.module(members, name, location: location);
//   Mod typename(Name binder, List<Name> typeParameters, Typ type,
//           {Location location}) =>
//       alg.typename(binder, typeParameters, type, location: location);
//   Mod signature(Name name, Typ type, {Location location}) =>
//       alg.signature(name, type, location: location);
//   Mod open(String moduleName, {Location location}) =>
//       alg.open(moduleName, location: location);
//   Mod errorModule(LocatedError error, {Location location}) =>
//       alg.errorModule(error, location: location);

//   Exp boolLit(bool b, {Location location}) =>
//       alg.boolLit(b, location: location);
//   Exp intLit(int n, {Location location}) => alg.intLit(n, location: location);
//   Exp stringLit(String s, {Location location}) =>
//       alg.stringLit(s, location: location);
//   Exp varExp(Name name, {Location location}) =>
//       alg.varExp(name, location: location);
//   Exp apply(Exp fn, List<Exp> arguments, {Location location}) =>
//       alg.apply(fn, arguments, location: location);
//   Exp lambda(List<Pat> parameters, Exp body, {Location location}) =>
//       alg.lambda(parameters, body, location: location);
//   Exp let(List<Pair<Pat, Exp>> bindings, Exp body,
//           {BindingMethod bindingMethod = BindingMethod.Parallel,
//           Location location}) =>
//       alg.let(bindings, body, bindingMethod: bindingMethod, location: location);
//   Exp tuple(List<Exp> components, {Location location}) =>
//       alg.tuple(components, location: location);
//   Exp ifthenelse(Exp condition, Exp thenBranch, Exp elseBranch,
//           {Location location}) =>
//       alg.ifthenelse(condition, thenBranch, elseBranch, location: location);
//   Exp match(Exp scrutinee, List<Pair<Pat, Exp>> cases, {Location location}) =>
//       alg.match(scrutinee, cases, location: location);
//   Exp typeAscription(Exp e, Typ type, {Location location}) =>
//       alg.typeAscription(e, type, location: location);
//   Exp errorExp(LocatedError error, {Location location}) =>
//       alg.errorExp(error, location: location);

//   Pat hasTypePattern(Pat pattern, Typ type, {Location location}) =>
//       alg.hasTypePattern(pattern, type, location: location);
//   Pat boolPattern(bool b, {Location location}) =>
//       alg.boolPattern(b, location: location);
//   Pat intPattern(int n, {Location location}) =>
//       alg.intPattern(n, location: location);
//   Pat stringPattern(String s, {Location location}) =>
//       alg.stringPattern(s, location: location);
//   Pat wildcard({Location location}) => alg.wildcard(location: location);
//   Pat varPattern(Name name, {Location location}) =>
//       alg.varPattern(name, location: location);
//   Pat constrPattern(Name name, List<Pat> parameters, {Location location}) =>
//       alg.constrPattern(name, parameters, location: location);
//   Pat tuplePattern(List<Pat> components, {Location location}) =>
//       alg.tuplePattern(components, location: location);
//   Pat errorPattern(LocatedError error, {Location location}) =>
//       alg.errorPattern(error, location: location);

//   Typ intType({Location location}) => alg.intType(location: location);
//   Typ boolType({Location location}) => alg.boolType(location: location);
//   Typ stringType({Location location}) => alg.stringType(location: location);
//   Typ typeVar(Name name, {Location location}) =>
//       alg.typeVar(name, location: location);
//   Typ forallType(List<Name> quantifiers, Typ type, {Location location}) =>
//       alg.forallType(quantifiers, type, location: location);
//   Typ arrowType(List<Typ> domain, Typ codomain, {Location location}) =>
//       alg.arrowType(domain, codomain, location: location);
//   Typ typeConstr(Name name, List<Typ> arguments, {Location location}) =>
//       alg.typeConstr(name, arguments, location: location);
//   Typ tupleType(List<Typ> components, {Location location}) =>
//       alg.tupleType(components, location: location);
//   Typ constraintType(List<Pair<Name, Typ>> constraints, Typ body,
//           {Location location}) =>
//       alg.constraintType(constraints, body, location: location);
//   Typ errorType(LocatedError error, {Location location}) =>
//       alg.errorType(error, location: location);

//   Name termName(String ident, {Location location}) =>
//       alg.termName(ident, location: location);
//   Name typeName(String ident, {Location location}) =>
//       alg.typeName(ident, location: location);
//   Name errorName(LocatedError error, {Location location}) =>
//       alg.errorName(error, location: location);
// }

// // Contextual transformations.
// typedef Transformer<C, T> = T Function(C);

// abstract class ContextualTransformation<C, Name, Mod, Exp, Pat, Typ>
//     extends TAlgebra<Transformer<C, Name>, Transformer<C, Mod>,
//         Transformer<C, Exp>, Transformer<C, Pat>, Transformer<C, Typ>> {
//   TAlgebra<Name, Mod, Exp, Pat, Typ> get alg;

//   Transformer<C, Mod> datatypes(
//           List<
//                   Triple<
//                       Transformer<C, Name>,
//                       List<Transformer<C, Name>>,
//                       List<
//                           Pair<Transformer<C, Name>,
//                               List<Transformer<C, Typ>>>>>>
//               defs,
//           List<Transformer<C, Name>> deriving,
//           {Location location}) =>
//       (C c) {
//         List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>> defs0 =
//             new List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>>(
//                 defs.length);

//         for (int i = 0; i < defs0.length; i++) {
//           Triple<Transformer<C, Name>, List<Transformer<C, Name>>,
//                   List<Pair<Transformer<C, Name>, List<Transformer<C, Typ>>>>>
//               def = defs[i];

//           Name binder = def.$1(c);
//           List<Name> typeParameters = def.$2.map((f) => f(c)).toList();

//           List<Pair<Transformer<C, Name>, List<Transformer<C, Typ>>>>
//               constructors = def.$3;
//           List<Pair<Name, List<Typ>>> constructors0 =
//               new List<Pair<Name, List<Typ>>>(constructors.length);
//           for (int j = 0; j < constructors0.length; j++) {
//             Pair<Transformer<C, Name>, List<Transformer<C, Typ>>> constructor =
//                 constructors[j];
//             Name cname = constructor.$1(c);
//             List<Typ> types = new List<Typ>(constructor.$2.length);
//             for (int k = 0; k < types.length; k++) {
//               types[k] = constructors[j].$2[j](c);
//             }
//             constructors0[j] = new Pair<Name, List<Typ>>(cname, types);
//           }
//           defs0[i] = Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>(
//               binder, typeParameters, constructors0);
//         }

//         List<Name> deriving0 = new List<Name>(deriving.length);
//         for (int i = 0; i < deriving0.length; i++) {
//           deriving0[i] = deriving[i](c);
//         }

//         return alg.datatypes(defs0, deriving0, location: location);
//       };

//   Transformer<C, Mod> valueDef(
//           Transformer<C, Name> name, Transformer<C, Exp> body,
//           {Location location}) =>
//       (C c) => alg.valueDef(name(c), body(c), location: location);
//   Transformer<C, Mod> functionDef(Transformer<C, Name> name,
//           List<Transformer<C, Pat>> parameters, Transformer<C, Exp> body,
//           {Location location}) =>
//       (C c) {
//         Name fname = name(c);
//         List<Pat> params = parameters.map((f) => f(c)).toList();
//         alg.functionDef(fname, params, body(c), location: location);
//       };
//   Transformer<C, Mod> module(List<Transformer<C, Mod>> members, String name,
//           {Location location}) =>
//       (C c) => alg.module(members.map((f) => f(c)).toList(), name,
//           location: location);
//   Transformer<C, Mod> typename(Transformer<C, Name> binder,
//           List<Transformer<C, Name>> typeParameters, Transformer<C, Typ> type,
//           {Location location}) =>
//       (C c) {
//         Name binder0 = binder(c);
//         List<Name> typeParameters0 = typeParameters.map((f) => f(c)).toList();
//         return alg.typename(binder0, typeParameters0, type(c),
//             location: location);
//       };
//   Transformer<C, Mod> signature(
//           Transformer<C, Name> name, Transformer<C, Typ> type,
//           {Location location}) =>
//       (C c) => alg.signature(name(c), type(c), location: location);
//   Transformer<C, Mod> open(String moduleName, {Location location}) =>
//       (C _) => alg.open(moduleName, location: location);
//   Transformer<C, Mod> errorModule(LocatedError error, {Location location}) =>
//       (C _) => alg.errorModule(error, location: location);

//   Transformer<C, Exp> boolLit(bool b, {Location location}) =>
//       (C _) => alg.boolLit(b, location: location);
//   Transformer<C, Exp> intLit(int n, {Location location}) =>
//       (C _) => alg.intLit(n, location: location);
//   Transformer<C, Exp> stringLit(String s, {Location location}) =>
//       (C _) => alg.stringLit(s, location: location);
//   Transformer<C, Exp> varExp(Transformer<C, Name> name, {Location location}) =>
//       (C c) => alg.varExp(name(c), location: location);
//   Transformer<C, Exp> apply(
//           Transformer<C, Exp> fn, List<Transformer<C, Exp>> arguments,
//           {Location location}) =>
//       (C c) => alg.apply(fn(c), arguments.map((f) => f(c)).toList(),
//           location: location);
//   Transformer<C, Exp> lambda(
//           List<Transformer<C, Pat>> parameters, Transformer<C, Exp> body,
//           {Location location}) =>
//       (C c) => alg.lambda(parameters.map((f) => f(c)).toList(), body(c),
//           location: location);
//   Transformer<C, Exp> let(
//           List<Pair<Transformer<C, Pat>, Transformer<C, Exp>>> bindings,
//           Transformer<C, Exp> body,
//           {BindingMethod bindingMethod = BindingMethod.Parallel,
//           Location location}) =>
//       (C c) {
//         List<Pair<Pat, Exp>> valBindings =
//             new List<Pair<Pat, Exp>>(bindings.length);
//         for (int i = 0; i < bindings.length; i++) {
//           valBindings[i] =
//               new Pair<Pat, Exp>(bindings[i].$1(c), bindings[i].$2(c));
//         }
//         return alg.let(valBindings, body(c),
//             bindingMethod: bindingMethod, location: location);
//       };
//   Transformer<C, Exp> tuple(List<Transformer<C, Exp>> components,
//           {Location location}) =>
//       (C c) =>
//           alg.tuple(components.map((f) => f(c)).toList(), location: location);
//   Transformer<C, Exp> ifthenelse(Transformer<C, Exp> condition,
//           Transformer<C, Exp> thenBranch, Transformer<C, Exp> elseBranch,
//           {Location location}) =>
//       (C c) => alg.ifthenelse(condition(c), thenBranch(c), elseBranch(c),
//           location: location);
//   Transformer<C, Exp> match(Transformer<C, Exp> scrutinee,
//           List<Pair<Transformer<C, Pat>, Transformer<C, Exp>>> cases,
//           {Location location}) =>
//       (C c) {
//         Exp e = scrutinee(c);
//         List<Pair<Pat, Exp>> clauses = new List<Pair<Pat, Exp>>(cases.length);
//         for (int i = 0; i < cases.length; i++) {
//           clauses[i] = Pair<Pat, Exp>(cases[i].$1(c), cases[i].$2(c));
//         }
//         return alg.match(e, clauses, location: location);
//       };
//   Transformer<C, Exp> typeAscription(
//           Transformer<C, Exp> e, Transformer<C, Typ> type,
//           {Location location}) =>
//       (C c) => alg.typeAscription(e(c), type(c), location: location);
//   Transformer<C, Exp> errorExp(LocatedError error, {Location location}) =>
//       (C _) => alg.errorExp(error, location: location);

//   Transformer<C, Pat> hasTypePattern(
//           Transformer<C, Pat> pattern, Transformer<C, Typ> type,
//           {Location location}) =>
//       (C c) => alg.hasTypePattern(pattern(c), type(c), location: location);
//   Transformer<C, Pat> boolPattern(bool b, {Location location}) =>
//       (C _) => alg.boolPattern(b, location: location);
//   Transformer<C, Pat> intPattern(int n, {Location location}) =>
//       (C _) => alg.intPattern(n, location: location);
//   Transformer<C, Pat> stringPattern(String s, {Location location}) =>
//       (C _) => alg.stringPattern(s, location: location);
//   Transformer<C, Pat> wildcard({Location location}) =>
//       (C _) => alg.wildcard(location: location);
//   Transformer<C, Pat> varPattern(Transformer<C, Name> name,
//           {Location location}) =>
//       (C c) => alg.varPattern(name(c), location: location);
//   Transformer<C, Pat> constrPattern(
//           Transformer<C, Name> name, List<Transformer<C, Pat>> parameters,
//           {Location location}) =>
//       (C c) => alg.constrPattern(name(c), parameters.map((f) => f(c)).toList(),
//           location: location);
//   Transformer<C, Pat> tuplePattern(List<Transformer<C, Pat>> components,
//           {Location location}) =>
//       (C c) => alg.tuplePattern(components.map((f) => f(c)).toList(),
//           location: location);
//   Transformer<C, Pat> errorPattern(LocatedError error, {Location location}) =>
//       (C _) => alg.errorPattern(error, location: location);

//   Transformer<C, Typ> intType({Location location}) =>
//       (C _) => alg.intType(location: location);
//   Transformer<C, Typ> boolType({Location location}) =>
//       (C _) => alg.boolType(location: location);
//   Transformer<C, Typ> stringType({Location location}) =>
//       (C _) => alg.stringType(location: location);
//   Transformer<C, Typ> typeVar(Transformer<C, Name> name, {Location location}) =>
//       (C c) => alg.typeVar(name(c), location: location);
//   Transformer<C, Typ> forallType(
//           List<Transformer<C, Name>> quantifiers, Transformer<C, Typ> type,
//           {Location location}) =>
//       (C c) => alg.forallType(quantifiers.map((f) => f(c)).toList(), type(c),
//           location: location);
//   Transformer<C, Typ> arrowType(
//           List<Transformer<C, Typ>> domain, Transformer<C, Typ> codomain,
//           {Location location}) =>
//       (C c) => alg.arrowType(domain.map((f) => f(c)).toList(), codomain(c),
//           location: location);
//   Transformer<C, Typ> typeConstr(
//           Transformer<C, Name> name, List<Transformer<C, Typ>> arguments,
//           {Location location}) =>
//       (C c) => alg.typeConstr(name(c), arguments.map((f) => f(c)).toList(),
//           location: location);
//   Transformer<C, Typ> tupleType(List<Transformer<C, Typ>> components,
//           {Location location}) =>
//       (C c) => alg.tupleType(components.map((f) => f(c)).toList(),
//           location: location);
//   Transformer<C, Typ> constraintType(
//           List<Pair<Transformer<C, Name>, Transformer<C, Typ>>> constraints,
//           Transformer<C, Typ> body,
//           {Location location}) =>
//       (C ctxt) {
//         List<Pair<Name, Typ>> constraints0 = new List<Pair<Name, Typ>>();
//         for (int i = 0; i < constraints.length; i++) {
//           Pair<Transformer<C, Name>, Transformer<C, Typ>> constraint =
//               constraints[i];
//           Name name = constraint.fst(ctxt);
//           Typ type = constraint.snd(ctxt);
//           constraints0.add(Pair<Name, Typ>(name, type));
//         }
//         Typ body0 = body(ctxt);
//         return alg.constraintType(constraints0, body0, location: location);
//       };
//   Transformer<C, Typ> errorType(LocatedError error, {Location location}) =>
//       (C _) => alg.errorType(error, location: location);

//   Transformer<C, Name> termName(String ident, {Location location}) =>
//       (C _) => alg.termName(ident, location: location);
//   Transformer<C, Name> typeName(String ident, {Location location}) =>
//       (C _) => alg.typeName(ident, location: location);
//   Transformer<C, Name> errorName(LocatedError error, {Location location}) =>
//       (C _) => alg.errorName(error, location: location);
// }

// // Contextual transformation with an accumulator.
// typedef AccuTransformer<S, C, T> = Pair<S, T> Function(C);

// abstract class AccumulatingContextualTransformation<S, C, Name, Mod, Exp, Pat,
//         Typ>
//     extends TAlgebra<
//         AccuTransformer<S, C, Name>,
//         AccuTransformer<S, C, Mod>,
//         AccuTransformer<S, C, Exp>,
//         AccuTransformer<S, C, Pat>,
//         AccuTransformer<S, C, Typ>> {
//   TAlgebra<Name, Mod, Exp, Pat, Typ> get alg;
//   Monoid<S> get m;

//   Pair<S, List<T>> transformList<T>(List<AccuTransformer<S, C, T>> xs, C ctxt,
//       [S initial]) {
//     S state = initial == null ? m.empty : initial;

//     final List<T> xs0 = new List<T>(xs.length);
//     for (int i = 0; i < xs0.length; i++) {
//       AccuTransformer<S, C, T> x = xs[i];
//       Pair<S, T> result = x(ctxt);
//       state = m.compose(state, result.$1);
//       xs0[i] = result.$2;
//     }

//     return Pair<S, List<T>>(state, xs0);
//   }

//   Pair<S, List<Pair<P, Q>>> transformPairList<P, Q>(
//       List<Pair<AccuTransformer<S, C, P>, AccuTransformer<S, C, Q>>> xs, C ctxt,
//       [S initial]) {
//     S state = initial == null ? m.empty : initial;

//     final List<Pair<P, Q>> xs0 = new List<Pair<P, Q>>(xs.length);
//     for (int i = 0; i < xs0.length; i++) {
//       final Pair<AccuTransformer<S, C, P>, AccuTransformer<S, C, Q>> x = xs[i];
//       final Pair<S, P> r0 = x.$1(ctxt);
//       final P p = r0.$2;
//       state = m.compose(state, r0.$1);

//       final Pair<S, Q> r1 = x.$2(ctxt);
//       final Q q = r1.$2;
//       state = m.compose(state, r1.$1);

//       xs0[i] = Pair<P, Q>(p, q);
//     }

//     return Pair<S, List<Pair<P, Q>>>(state, xs0);
//   }

//   AccuTransformer<S, C, Mod> datatypes(
//           List<
//                   Triple<
//                       AccuTransformer<S, C, Name>,
//                       List<AccuTransformer<S, C, Name>>,
//                       List<
//                           Pair<AccuTransformer<S, C, Name>,
//                               List<AccuTransformer<S, C, Typ>>>>>>
//               defs,
//           List<AccuTransformer<S, C, Name>> deriving,
//           {Location location}) =>
//       (C c) {
//         List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>> defs0 =
//             new List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>>(
//                 defs.length);

//         S state = m.empty;
//         for (int i = 0; i < defs0.length; i++) {
//           Triple<
//               AccuTransformer<S, C, Name>,
//               List<AccuTransformer<S, C, Name>>,
//               List<
//                   Pair<AccuTransformer<S, C, Name>,
//                       List<AccuTransformer<S, C, Typ>>>>> def = defs[i];

//           final Pair<S, Name> r0 = def.$1(c);
//           state = m.compose(state, r0.$1);
//           final Name name0 = r0.$2;

//           final Pair<S, List<Name>> r1 = transformList<Name>(def.$2, c, state);
//           state = r1.$1;
//           final List<Name> typeParameters0 = r1.$2;

//           final List<
//               Pair<AccuTransformer<S, C, Name>,
//                   List<AccuTransformer<S, C, Typ>>>> constructors = def.$3;

//           final List<Pair<Name, List<Typ>>> constructors0 =
//               new List<Pair<Name, List<Typ>>>(constructors.length);

//           for (int j = 0; j < constructors0.length; j++) {
//             final Pair<AccuTransformer<S, C, Name>,
//                 List<AccuTransformer<S, C, Typ>>> constructor = constructors[j];

//             final Pair<S, Name> r2 = constructor.$1(c);
//             state = m.compose(state, r2.$1);
//             final Name cname = r2.$2;

//             final Pair<S, List<Typ>> r3 =
//                 transformList<Typ>(constructor.$2, c, state);
//             state = r3.$1;
//             final List<Typ> types = r3.$2;

//             final Pair<Name, List<Typ>> constructor0 =
//                 Pair<Name, List<Typ>>(cname, types);
//             constructors0[j] = constructor0;
//           }

//           final Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>> def0 =
//               Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>(
//                   name0, typeParameters0, constructors0);

//           defs0[i] = def0;
//         }

//         final Pair<S, List<Name>> r4 = transformList<Name>(deriving, c, state);
//         state = r4.$1;
//         final List<Name> deriving0 = r4.$2;

//         return Pair<S, Mod>(
//             state, alg.datatypes(defs0, deriving0, location: location));
//       };

//   AccuTransformer<S, C, Mod> valueDef(
//           AccuTransformer<S, C, Name> name, AccuTransformer<S, C, Exp> body,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Name> r0 = name(c);
//         S state = r0.$1;
//         final Name name0 = r0.$2;

//         final Pair<S, Exp> r1 = body(c);
//         state = m.compose(state, r1.$1);
//         final Exp body0 = r1.$2;

//         return Pair<S, Mod>(
//             state, alg.valueDef(name0, body0, location: location));
//       };

//   AccuTransformer<S, C, Mod> functionDef(
//           AccuTransformer<S, C, Name> name,
//           List<AccuTransformer<S, C, Pat>> parameters,
//           AccuTransformer<S, C, Exp> body,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Name> r0 = name(c);
//         S state = r0.$1;
//         final Name name0 = r0.$2;

//         final Pair<S, List<Pat>> r1 = transformList<Pat>(parameters, c, state);
//         state = r1.$1;
//         final List<Pat> parameters0 = r1.$2;

//         final Pair<S, Exp> r2 = body(c);
//         state = m.compose(state, r2.$1);
//         final Exp body0 = r2.$2;

//         return Pair<S, Mod>(state,
//             alg.functionDef(name0, parameters0, body0, location: location));
//       };

//   AccuTransformer<S, C, Mod> module(
//           List<AccuTransformer<S, C, Mod>> members, String name,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, List<Mod>> r0 = transformList<Mod>(members, c);
//         final S state = r0.$1;
//         final List<Mod> members0 = r0.$2;

//         return Pair<S, Mod>(
//             state, alg.module(members0, name, location: location));
//       };

//   AccuTransformer<S, C, Mod> typename(
//           AccuTransformer<S, C, Name> binder,
//           List<AccuTransformer<S, C, Name>> typeParameters,
//           AccuTransformer<S, C, Typ> type,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Name> r0 = binder(c);
//         S state = r0.$1;
//         final Name binder0 = r0.$2;

//         final Pair<S, List<Name>> r1 =
//             transformList<Name>(typeParameters, c, state);
//         state = r1.$1;
//         final List<Name> typeParameters0 = r1.$2;

//         final Pair<S, Typ> r2 = type(c);
//         state = m.compose(state, r2.$1);
//         final Typ type0 = r2.$2;

//         return Pair<S, Mod>(state,
//             alg.typename(binder0, typeParameters0, type0, location: location));
//       };

//   AccuTransformer<S, C, Mod> signature(
//           AccuTransformer<S, C, Name> name, AccuTransformer<S, C, Typ> type,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Name> r0 = name(c);
//         S state = r0.$1;
//         final Name name0 = r0.$2;

//         final Pair<S, Typ> r1 = type(c);
//         state = m.compose(state, r1.$1);
//         final Typ type0 = r1.$2;

//         return Pair<S, Mod>(
//             state, alg.signature(name0, type0, location: location));
//       };

//   AccuTransformer<S, C, Mod> errorModule(LocatedError error,
//           {Location location}) =>
//       (C _) =>
//           Pair<S, Mod>(m.empty, alg.errorModule(error, location: location));

//   AccuTransformer<S, C, Exp> boolLit(bool b, {Location location}) =>
//       (C _) => Pair<S, Exp>(m.empty, alg.boolLit(b, location: location));
//   AccuTransformer<S, C, Exp> intLit(int n, {Location location}) =>
//       (C _) => Pair<S, Exp>(m.empty, alg.intLit(n, location: location));
//   AccuTransformer<S, C, Exp> stringLit(String s, {Location location}) =>
//       (C _) => Pair<S, Exp>(m.empty, alg.stringLit(s, location: location));
//   AccuTransformer<S, C, Exp> varExp(AccuTransformer<S, C, Name> name,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Name> result = name(c);
//         final S state = result.$1;
//         final Name name0 = result.$2;

//         return Pair<S, Exp>(state, alg.varExp(name0, location: location));
//       };

//   AccuTransformer<S, C, Exp> apply(AccuTransformer<S, C, Exp> fn,
//           List<AccuTransformer<S, C, Exp>> arguments,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Exp> r0 = fn(c);
//         S state = r0.$1;
//         final Exp fn0 = r0.$2;

//         final Pair<S, List<Exp>> r1 = transformList<Exp>(arguments, c, state);
//         state = r1.$1;
//         final List<Exp> arguments0 = r1.$2;

//         return Pair<S, Exp>(
//             state, alg.apply(fn0, arguments0, location: location));
//       };

//   AccuTransformer<S, C, Exp> lambda(List<AccuTransformer<S, C, Pat>> parameters,
//           AccuTransformer<S, C, Exp> body,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, List<Pat>> r0 = transformList<Pat>(parameters, c);
//         S state = r0.$1;
//         final List<Pat> parameters0 = r0.$2;

//         final Pair<S, Exp> r1 = body(c);
//         state = m.compose(state, r1.$1);
//         final Exp body0 = r1.$2;

//         return Pair<S, Exp>(
//             state, alg.lambda(parameters0, body0, location: location));
//       };

//   AccuTransformer<S, C, Exp> let(
//           List<Pair<AccuTransformer<S, C, Pat>, AccuTransformer<S, C, Exp>>>
//               bindings,
//           AccuTransformer<S, C, Exp> body,
//           {BindingMethod bindingMethod = BindingMethod.Parallel,
//           Location location}) =>
//       (C c) {
//         final Pair<S, List<Pair<Pat, Exp>>> r0 =
//             transformPairList<Pat, Exp>(bindings, c);
//         S state = r0.$1;
//         final List<Pair<Pat, Exp>> bindings0 = r0.$2;

//         final Pair<S, Exp> r1 = body(c);
//         state = m.compose(state, r1.$1);
//         final Exp body0 = r1.$2;

//         return Pair<S, Exp>(
//             state,
//             alg.let(bindings0, body0,
//                 bindingMethod: bindingMethod, location: location));
//       };

//   AccuTransformer<S, C, Exp> tuple(List<AccuTransformer<S, C, Exp>> components,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, List<Exp>> result = transformList<Exp>(components, c);
//         final S state = result.$1;
//         final List<Exp> components0 = result.$2;
//         return Pair<S, Exp>(state, alg.tuple(components0, location: location));
//       };

//   AccuTransformer<S, C, Exp> ifthenelse(
//           AccuTransformer<S, C, Exp> condition,
//           AccuTransformer<S, C, Exp> thenBranch,
//           AccuTransformer<S, C, Exp> elseBranch,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Exp> r0 = condition(c);
//         S state = r0.$1;
//         final Exp condition0 = r0.$2;

//         final Pair<S, Exp> r1 = thenBranch(c);
//         state = m.compose(state, r1.$1);
//         final Exp thenBranch0 = r1.$2;

//         final Pair<S, Exp> r2 = elseBranch(c);
//         state = m.compose(state, r2.$1);
//         final Exp elseBranch0 = r2.$2;

//         return Pair<S, Exp>(
//             state,
//             alg.ifthenelse(condition0, thenBranch0, elseBranch0,
//                 location: location));
//       };

//   AccuTransformer<S, C, Exp> match(
//           AccuTransformer<S, C, Exp> scrutinee,
//           List<Pair<AccuTransformer<S, C, Pat>, AccuTransformer<S, C, Exp>>>
//               cases,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Exp> r0 = scrutinee(c);
//         S state = r0.$1;
//         final Exp scrutinee0 = r0.$2;

//         Pair<S, List<Pair<Pat, Exp>>> result =
//             transformPairList<Pat, Exp>(cases, c, state);
//         state = result.$1;
//         final List<Pair<Pat, Exp>> cases0 = result.$2;

//         return Pair<S, Exp>(
//             state, alg.match(scrutinee0, cases0, location: location));
//       };

//   AccuTransformer<S, C, Exp> typeAscription(
//           AccuTransformer<S, C, Exp> e, AccuTransformer<S, C, Typ> type,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Exp> r0 = e(c);
//         S state = r0.$1;
//         final Exp exp0 = r0.$2;

//         final Pair<S, Typ> r1 = type(c);
//         state = m.compose(state, r1.$1);
//         final Typ type0 = r1.$2;

//         return Pair<S, Exp>(
//             state, alg.typeAscription(exp0, type0, location: location));
//       };

//   AccuTransformer<S, C, Exp> errorExp(LocatedError error,
//           {Location location}) =>
//       (C _) => Pair<S, Exp>(m.empty, alg.errorExp(error, location: location));

//   AccuTransformer<S, C, Pat> hasTypePattern(
//           AccuTransformer<S, C, Pat> pattern, AccuTransformer<S, C, Typ> type,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Pat> r0 = pattern(c);
//         final Pat pattern0 = r0.$2;
//         S state = r0.$1;

//         final Pair<S, Typ> r1 = type(c);
//         state = m.compose(state, r1.$1);
//         final Typ type0 = r1.$2;

//         return Pair<S, Pat>(
//             state, alg.hasTypePattern(pattern0, type0, location: location));
//       };

//   AccuTransformer<S, C, Pat> boolPattern(bool b, {Location location}) =>
//       (C _) => Pair<S, Pat>(m.empty, alg.boolPattern(b, location: location));

//   AccuTransformer<S, C, Pat> intPattern(int n, {Location location}) =>
//       (C _) => Pair<S, Pat>(m.empty, alg.intPattern(n, location: location));

//   AccuTransformer<S, C, Pat> stringPattern(String s, {Location location}) =>
//       (C _) => Pair<S, Pat>(m.empty, alg.stringPattern(s, location: location));

//   AccuTransformer<S, C, Pat> wildcard({Location location}) =>
//       (C _) => Pair<S, Pat>(m.empty, alg.wildcard(location: location));

//   AccuTransformer<S, C, Pat> varPattern(AccuTransformer<S, C, Name> name,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Name> result = name(c);
//         return Pair<S, Pat>(
//             result.$1, alg.varPattern(result.$2, location: location));
//       };

//   AccuTransformer<S, C, Pat> constrPattern(AccuTransformer<S, C, Name> name,
//           List<AccuTransformer<S, C, Pat>> parameters,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Name> r0 = name(c);
//         S state = r0.$1;
//         Name name0 = r0.$2;

//         final Pair<S, List<Pat>> r1 = transformList<Pat>(parameters, c, state);
//         state = m.compose(state, r1.$1);
//         final List<Pat> parameters0 = r1.$2;

//         return Pair<S, Pat>(
//             state, alg.constrPattern(name0, parameters0, location: location));
//       };

//   AccuTransformer<S, C, Pat> tuplePattern(
//           List<AccuTransformer<S, C, Pat>> components,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, List<Pat>> result = transformList<Pat>(components, c);
//         return Pair<S, Pat>(
//             result.$1, alg.tuplePattern(result.$2, location: location));
//       };

//   AccuTransformer<S, C, Pat> errorPattern(LocatedError error,
//           {Location location}) =>
//       (C _) =>
//           Pair<S, Pat>(m.empty, alg.errorPattern(error, location: location));

//   AccuTransformer<S, C, Typ> intType({Location location}) => (C _) {
//         return Pair<S, Typ>(m.empty, alg.intType(location: location));
//       };
//   AccuTransformer<S, C, Typ> boolType({Location location}) => (C _) {
//         return Pair<S, Typ>(m.empty, alg.boolType(location: location));
//       };
//   AccuTransformer<S, C, Typ> stringType({Location location}) => (C _) {
//         return Pair<S, Typ>(m.empty, alg.stringType(location: location));
//       };

//   AccuTransformer<S, C, Typ> typeVar(AccuTransformer<S, C, Name> name,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, Name> result = name(c);
//         final S state = result.$1;
//         final Name name0 = result.$2;
//         return Pair<S, Typ>(state, alg.typeVar(name0, location: location));
//       };

//   AccuTransformer<S, C, Typ> forallType(
//           List<AccuTransformer<S, C, Name>> quantifiers,
//           AccuTransformer<S, C, Typ> type,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, List<Name>> r0 = transformList<Name>(quantifiers, c);
//         S state = r0.$1;
//         final List<Name> quantifiers0 = r0.$2;

//         final Pair<S, Typ> r1 = type(c);
//         state = m.compose(state, r1.$1);
//         final Typ type0 = r1.$2;

//         return Pair<S, Typ>(
//             state, alg.forallType(quantifiers0, type0, location: location));
//       };

//   AccuTransformer<S, C, Typ> arrowType(List<AccuTransformer<S, C, Typ>> domain,
//           AccuTransformer<S, C, Typ> codomain,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, List<Typ>> r0 = transformList<Typ>(domain, c);
//         S state = r0.$1;
//         final List<Typ> domain0 = r0.$2;

//         final Pair<S, Typ> r1 = codomain(c);
//         state = m.compose(state, r1.$1);
//         final Typ codomain0 = r1.$2;

//         return Pair<S, Typ>(
//             state, alg.arrowType(domain0, codomain0, location: location));
//       };

//   AccuTransformer<S, C, Typ> typeConstr(AccuTransformer<S, C, Name> name,
//           List<AccuTransformer<S, C, Typ>> arguments,
//           {Location location}) =>
//       (C c) {
//         Pair<S, Name> r0 = name(c);
//         S state = r0.$1;
//         Name name0 = r0.$2;

//         final Pair<S, List<Typ>> result =
//             transformList<Typ>(arguments, c, state);
//         state = result.$1;
//         final List<Typ> arguments0 = result.$2;

//         return Pair<S, Typ>(
//             state, alg.typeConstr(name0, arguments0, location: location));
//       };

//   AccuTransformer<S, C, Typ> tupleType(
//           List<AccuTransformer<S, C, Typ>> components,
//           {Location location}) =>
//       (C c) {
//         final Pair<S, List<Typ>> result = transformList<Typ>(components, c);
//         S state = result.$1;
//         final List<Typ> components0 = result.$2;

//         return Pair<S, Typ>(
//             state, alg.tupleType(components0, location: location));
//       };

//   AccuTransformer<S, C, Typ> constraintType(
//           List<Pair<AccuTransformer<S, C, Name>, AccuTransformer<S, C, Typ>>>
//               constraints,
//           AccuTransformer<S, C, Typ> body,
//           {Location location}) =>
//       (C ctxt) {
//         S state = m.empty;
//         List<Pair<Name, Typ>> constraints0 = new List<Pair<Name, Typ>>();
//         for (int i = 0; i < constraints.length; i++) {
//           Pair<AccuTransformer<S, C, Name>, AccuTransformer<S, C, Typ>>
//               constraint = constraints[i];
//           Pair<S, Name> r0 = constraint.fst(ctxt);
//           state = m.compose(state, r0.fst);
//           Name name = r0.snd;

//           Pair<S, Typ> r1 = constraint.snd(ctxt);
//           state = m.compose(state, r1.fst);
//           Typ type = r1.snd;

//           constraints0.add(Pair<Name, Typ>(name, type));
//         }
//         Pair<S, Typ> r2 = body(ctxt);
//         state = m.compose(state, r2.fst);
//         Typ body0 = r2.snd;
//         return Pair<S, Typ>(
//             state, alg.constraintType(constraints0, body0, location: location));
//       };

//   AccuTransformer<S, C, Typ> errorType(LocatedError error,
//           {Location location}) =>
//       (C _) => Pair<S, Typ>(m.empty, alg.errorType(error, location: location));

//   AccuTransformer<S, C, Name> termName(String ident, {Location location}) =>
//       (C _) => Pair<S, Name>(m.empty, alg.termName(ident, location: location));
//   AccuTransformer<S, C, Name> typeName(String ident, {Location location}) =>
//       (C _) => Pair<S, Name>(m.empty, alg.typeName(ident, location: location));
//   AccuTransformer<S, C, Name> errorName(LocatedError error,
//           {Location location}) =>
//       (C _) => Pair<S, Name>(m.empty, alg.errorName(error, location: location));
// }
