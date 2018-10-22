// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../builtins.dart';
import '../errors/errors.dart'
    show
        DuplicateTypeSignatureError,
        LocatedError,
        MultipleDeclarationsError,
        UnboundNameError;
import '../fp.dart' show Pair, Triple;
import '../location.dart';
import '../string_pool.dart';
import '../utils.dart' show Gensym;

import '../ast/algebra.dart';
import '../ast/name.dart';
import '../ast/traversals.dart'
    show
        Catamorphism,
        Endomorphism,
        ListMonoid,
        Monoid,
        Morphism,
        NullMonoid,
        ContextualTransformation,
        Transformation,
        Transformer;

// TODO unify globals and NameContext. For example, have globals being shared
// amongst instances of NameContext.
class NameContext {
  final Map<int, int> nameEnv;
  final Map<int, int> tynameEnv;

  NameContext(this.nameEnv, this.tynameEnv);
  NameContext.empty() : this(new Map<int, int>(), new Map<int, int>());
  NameContext.withBuiltins()
      : this(
            Builtin.termNameMap.map(
                (int id, Name name) => MapEntry<int, int>(name.intern, id)),
            Builtin.typeNameMap.map(
                (int id, Name name) => MapEntry<int, int>(name.intern, id)));

  NameContext addTermName(Name name, {Location location}) {
    // TODO use a proper immutable map data structure.
    final Map<int, int> nameEnv0 = Map<int, int>.of(nameEnv);
    nameEnv0[name.intern] = name.id;
    return NameContext(nameEnv0, tynameEnv);
  }

  NameContext addTypeName(Name name, {Location location}) {
    // TODO use a proper immutable map data structure.
    final Map<int, int> tynameEnv0 = Map<int, int>.of(nameEnv);
    tynameEnv0[name.intern] = name.id;
    return NameContext(nameEnv, tynameEnv0);
  }

  Name resolve(String name, {Location location}) {
    if (nameEnv.containsKey(name)) {
      final int binderId = nameEnv[name];
      return new Name.resolved(name, binderId, location);
    } else if (tynameEnv.containsKey(name)) {
      final int binderId = tynameEnv[name];
      return new Name.resolved(name, binderId, location);
    } else {
      return new Name.unresolved(name, location);
    }
  }

  Name resolveAs(int intern, int id, {Location location}) {
    return new Name.of(intern, id, location);
  }

  bool contains(String name) {
    final int intern = computeIntern(name);
    return nameEnv.containsKey(intern) || tynameEnv.containsKey(intern);
  }

  int computeIntern(String name) => Name.computeIntern(name);
}

class BindingContext extends NameContext {
  BindingContext() : super(null, null);

  Name resolve(String name, {Location location}) {
    return new Name.resolved(name, Gensym.freshInt(), location);
  }

  bool contains(String _) => true;
}

class PatternBindingContext extends BindingContext {
  final List<Name> names = new List<Name>();
  PatternBindingContext() : super();

  Name resolve(String name, {Location location}) {
    Name resolved = super.resolve(name, location: location);
    names.add(resolved);
    return resolved;
  }
}

class NameResolver<Mod, Exp, Pat, Typ>
    extends ContextualTransformation<NameContext, Name, Mod, Exp, Pat, Typ> {
  final TAlgebra<Name, Mod, Exp, Pat, Typ> _alg;
  TAlgebra<Name, Mod, Exp, Pat, Typ> get alg => _alg;
  final BindingContext bindingContext = new BindingContext();
  final Map<int, Name> globals;
  final Map<int, Name> datatypes;

  final List<Name> unresolved = new List<Name>();

  NameResolver(this.globals, this.datatypes, this._alg);
  NameResolver.closed(TAlgebra<Name, Mod, Exp, Pat, Typ> alg)
      : this(new Map<int, Name>(), new Map<int, Name>(), alg);

  Name resolveBinder(Transformer<NameContext, Name> binder) {
    return binder(bindingContext);
  }

  Pair<List<Name>, Pat> resolvePatternBinding(
      Transformer<NameContext, Pat> pattern) {
    PatternBindingContext ctxt = new PatternBindingContext();
    Pat pat = pattern(ctxt);
    return Pair<List<Name>, Pat>(ctxt.names, pat);
  }

  Pair<List<Name>, List<Pat>> resolvePatternBindings(
      List<Transformer<NameContext, Pat>> patterns) {
    if (patterns.length == 0) {
      return Pair<List<Name>, List<Pat>>(new List<Name>(), new List<Pat>());
    }
    Pair<List<Name>, List<Pat>> initial =
        Pair<List<Name>, List<Pat>>(new List<Name>(), new List<Pat>());
    Pair<List<Name>, List<Pat>> result = patterns
        .map(resolvePatternBinding)
        .fold(initial,
            (Pair<List<Name>, List<Pat>> acc, Pair<List<Name>, Pat> elem) {
      acc.$1.addAll(elem.$1);
      acc.$2.add(elem.$2);
      return acc;
    });

    return result;
  }

  T resolveLocal<T>(Transformer<NameContext, T> obj, NameContext ctxt) {
    return obj(ctxt);
  }

  Transformer<NameContext, Mod> datatype(
          Transformer<NameContext, Name> binder,
          List<Transformer<NameContext, Name>> typeParameters,
          List<
                  Pair<Transformer<NameContext, Name>,
                      List<Transformer<NameContext, Typ>>>>
              constructors,
          List<Transformer<NameContext, Name>> deriving,
          {Location location}) =>
      (NameContext ctxt) {
        // As recursive data types are allowed, we immediately register the name.
        Name binder0 = resolveBinder(binder);
        if (datatypes.containsKey(binder0.intern)) {
          return alg.errorModule(
              MultipleDeclarationsError(binder0.sourceName, binder0.location),
              location: binder0.location);
        } else {
          datatypes[binder0.intern] = binder0;
          ctxt = ctxt.addTypeName(binder0);
        }
        final List<Name> qs = new List<Name>(typeParameters.length);
        final Set<int> qsi = new Set<int>();
        for (int i = 0; i < qs.length; i++) {
          Name q = resolveBinder(typeParameters[i]);
          if (qsi.contains(q.intern)) {
            // TODO aggregate errors.
            return alg.errorModule(
                MultipleDeclarationsError(q.sourceName, q.location),
                location: q.location);
          } else {
            qs[i] = q;
            ctxt = ctxt.addTypeName(q);
          }
        }

        // Register constructors.
        final List<Pair<Name, List<Typ>>> constructors0 =
            new List<Pair<Name, List<Typ>>>(constructors.length);
        for (int i = 0; i < constructors0.length; i++) {
          Name constrName = resolveBinder(constructors[i].$1);
          // TODO check for duplicate.
          globals[constrName.intern] = constrName;
          List<Typ> types = new List<Typ>(constructors[i].$2.length);
          for (int j = 0; j < types.length; j++) {
            types[j] = resolveLocal<Typ>(constructors[i].$2[j], ctxt);
          }
          ctxt = ctxt.addTermName(constrName);
          constructors0[i] = Pair<Name, List<Typ>>(constrName, types);
        }
        // Resolve deriving names.
        final List<Name> deriving0 = new List<Name>(deriving.length);
        for (int i = 0; i < deriving0.length; i++) {
          deriving0[i] = resolveLocal<Name>(deriving[i], ctxt);
        }

        return alg.datatype(binder0, qs, constructors0, deriving0,
            location: location);
      };

  Transformer<NameContext, Mod> mutualDatatypes(
          List<
                  Triple<
                      Transformer<NameContext, Name>,
                      List<Transformer<NameContext, Name>>,
                      List<
                          Pair<Transformer<NameContext, Name>,
                              List<Transformer<NameContext, Typ>>>>>>
              defs,
          List<Transformer<NameContext, Name>> deriving,
          {Location location}) =>
      (NameContext ctxt) {
        // Two passes:
        // 1) Resolve all binders.
        // 2) Resolve bodies.
        List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>> defs0 =
            new List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>>(
                defs.length);

        // First pass.
        Set<int> idents = new Set<int>();
        List<Name> binders = new List<Name>(defs.length);
        for (int i = 0; i < defs0.length; i++) {
          Triple<
              Transformer<NameContext, Name>,
              List<Transformer<NameContext, Name>>,
              List<
                  Pair<Transformer<NameContext, Name>,
                      List<Transformer<NameContext, Typ>>>>> def = defs[i];

          Name binder = resolveBinder(def.$1);
          if (idents.contains(binder.intern)) {
            return alg.errorModule(
                MultipleDeclarationsError(binder.sourceName, binder.location),
                location: binder.location);
          } else {
            ctxt = ctxt.addTypeName(binder);
          }
          binders[i] = binder;
        }

        // Second pass.
        idents = new Set<int>();
        for (int i = 0; i < defs0.length; i++) {
          Triple<
              Transformer<NameContext, Name>,
              List<Transformer<NameContext, Name>>,
              List<
                  Pair<Transformer<NameContext, Name>,
                      List<Transformer<NameContext, Typ>>>>> def = defs[i];
          NameContext ctxt0 = ctxt;

          List<Name> typeParameters = new List<Name>(def.$2.length);
          for (int j = 0; j < typeParameters.length; j++) {
            Name param = resolveBinder(def.$2[j]);
            if (idents.contains(param.intern)) {
              return alg.errorModule(
                  MultipleDeclarationsError(param.sourceName, param.location),
                  location: param.location);
            } else {
              typeParameters.add(param);
              ctxt0 = ctxt0.addTypeName(param);
            }
          }

          List<
              Pair<Transformer<NameContext, Name>,
                  List<Transformer<NameContext, Typ>>>> constructors = def.$3;
          List<Pair<Name, List<Typ>>> constructors0 =
              new List<Pair<Name, List<Typ>>>(constructors.length);
          for (int j = 0; j < constructors0.length; j++) {
            Pair<Transformer<NameContext, Name>,
                    List<Transformer<NameContext, Typ>>> constructor =
                constructors[j];
            Name cname = resolveLocal<Name>(constructor.$1, ctxt0);
            if (globals.containsKey(cname.intern)) {
              return alg.errorModule(
                  MultipleDeclarationsError(cname.sourceName, cname.location),
                  location: cname.location);
            }
            globals[cname.intern] = cname;

            List<Typ> types = new List<Typ>(constructor.$2.length);
            for (int k = 0; k < types.length; k++) {
              types[k] = resolveLocal<Typ>(constructors[j].$2[j], ctxt0);
            }
            constructors0[j] = new Pair<Name, List<Typ>>(cname, types);
          }
          defs0[i] = Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>(
              binders[i], typeParameters, constructors0);
        }

        List<Name> deriving0 = new List<Name>(deriving.length);
        for (int i = 0; i < deriving0.length; i++) {
          deriving0[i] = resolveLocal<Name>(deriving[i], ctxt);
        }

        return alg.mutualDatatypes(defs0, deriving0, location: location);
      };

  Transformer<NameContext, Mod> valueDef(Transformer<NameContext, Name> name,
          Transformer<NameContext, Exp> body,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve names in [body] before resolving [name].
        Exp body0 = resolveLocal<Exp>(body, ctxt);
        // Although [name] is global, we resolve as a "local" name, because it
        // must have a type signature that precedes it.
        Name name0 = resolveLocal<Name>(name, ctxt);
        return alg.valueDef(name0, body0, location: location);
      };

  Transformer<NameContext, Mod> functionDef(
          Transformer<NameContext, Name> name,
          List<Transformer<NameContext, Pat>> parameters,
          Transformer<NameContext, Exp> body,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve parameters.
        List<Pat> params = List<Pat>(parameters.length);
        for (int i = 0; i < params.length; i++) {
          Pair<List<Name>, Pat> param = resolvePatternBinding(parameters[i]);
          Set<int> idents = new Set<int>();
          for (int j = 0; j < param.$1.length; j++) {
            Name paramName = param.$1[j];
            if (idents.contains(paramName.intern)) {
              // TODO aggregate errors.
              return alg.errorModule(
                  MultipleDeclarationsError(
                      paramName.sourceName, paramName.location),
                  location: paramName.location);
            } else {
              idents.add(paramName.intern);
              ctxt = ctxt.addTermName(paramName);
            }
          }
          params[i] = param.$2;
        }
        // Resolve any names in [body] before resolving [name].
        Exp body0 = body(ctxt);
        // Resolve function definition name as "local" name.
        Name name0 = name(ctxt);
        return alg.functionDef(name0, params, body0, location: location);
      };

  Transformer<NameContext, Mod> typename(
          Transformer<NameContext, Name> binder,
          List<Transformer<NameContext, Name>> typeParameters,
          Transformer<NameContext, Typ> type,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve [typeParameters] first.
        final List<Name> typeParameters0 =
            new List<Name>(typeParameters.length);
        Set<int> idents = new Set<int>();
        for (int i = 0; i < typeParameters0.length; i++) {
          Name name = resolveBinder(typeParameters[i]);
          if (idents.contains(name.intern)) {
            // TODO aggregate errors.
            return alg.errorModule(
                MultipleDeclarationsError(name.sourceName, name.location),
                location: name.location);
          } else {
            typeParameters0[i] = name;
            ctxt = ctxt.addTypeName(name);
          }
        }
        Typ type0 = resolveLocal<Typ>(type, ctxt);

        // Type aliases cannot be recursive.
        final Name binder0 = resolveBinder(binder);
        return alg.typename(binder0, typeParameters0, type0,
            location: location);
      };

  Transformer<NameContext, Mod> signature(Transformer<NameContext, Name> name,
          Transformer<NameContext, Typ> type,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve the signature name, and register it as a global.
        Name name0 = resolveBinder(name);
        ctxt = ctxt.addTermName(name0);
        if (globals.containsKey(name0.intern)) {
          return alg.errorModule(
              DuplicateTypeSignatureError(name0.sourceName, name0.location),
              location: name0.location);
        } else {
          globals[name0.intern] = name0;
        }
        return alg.signature(name0, resolveLocal<Typ>(type, ctxt),
            location: location);
      };

  Transformer<NameContext, Name> termName(String ident, {Location location}) =>
      (NameContext ctxt) {
        if (ctxt.contains(ident)) {
          return ctxt.resolve(ident, location: location);
        } else {
          int intern = ctxt.computeIntern(ident);
          if (globals.containsKey(intern)) {
            Name global = globals[intern];
            return ctxt.resolveAs(global.id, intern, location: location);
          } else {
            return alg.errorName(UnboundNameError(ident, location),
                location: location);
          }
        }
        Name name = ctxt.resolve(ident, location: location);
        if (name == null) {
          return alg.errorName(UnboundNameError(ident, location),
              location: location);
        } else {
          return name;
        }
      };

  Transformer<NameContext, Exp> lambda(
          List<Transformer<NameContext, Pat>> parameters,
          Transformer<NameContext, Exp> body,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve parameters.
        final Pair<List<Name>, List<Pat>> result =
            resolvePatternBindings(parameters);
        final List<Pat> parameters0 = result.$2;
        // Check for duplicate names.
        final List<Name> params = result.$1;
        Set<int> idents = new Set<int>();
        for (int j = 0; j < params.length; j++) {
          Name paramName = params[j];
          if (idents.contains(paramName.intern)) {
            // TODO aggregate errors.
            return alg.errorExp(
                MultipleDeclarationsError(
                    paramName.sourceName, paramName.location),
                location: paramName.location);
          } else {
            idents.add(paramName.intern);
            ctxt = ctxt.addTermName(paramName);
          }
        }

        // Resolve names in [body].
        Exp body0 = resolveLocal<Exp>(body, ctxt);
        return alg.lambda(parameters0, body0, location: location);
      };

  Transformer<NameContext, Exp> let(
          List<
                  Pair<Transformer<NameContext, Pat>,
                      Transformer<NameContext, Exp>>>
              bindings,
          Transformer<NameContext, Exp> body,
          {BindingMethod bindingMethod = BindingMethod.Parallel,
          Location location}) =>
      (NameContext ctxt) {
        final List<Pair<Pat, Exp>> bindings0 =
            new List<Pair<Pat, Exp>>(bindings.length);
        Set<int> idents = new Set<int>();
        // Resolve let bindings.
        switch (bindingMethod) {
          case BindingMethod.Parallel:
            NameContext ctxt0 = ctxt;
            for (int i = 0; i < bindings0.length; i++) {
              final Pair<List<Name>, Pat> result =
                  resolvePatternBinding(bindings[i].$1);
              final List<Name> declaredNames = result.$1;

              Exp exp = resolveLocal<Exp>(bindings[i].$2, ctxt);
              bindings0[i] = Pair<Pat, Exp>(result.$2, exp);

              for (int j = 0; j < declaredNames.length; j++) {
                Name name = declaredNames[j];
                if (idents.contains(name.intern)) {
                  return alg.errorExp(
                      MultipleDeclarationsError(name.sourceName, name.location),
                      location: name.location);
                } else {
                  ctxt0 = ctxt0.addTermName(name);
                }
              }
            }
            ctxt = ctxt0;
            break;
          case BindingMethod.Sequential:
            for (int i = 0; i < bindings.length; i++) {
              final Pair<List<Name>, Pat> result =
                  resolvePatternBinding(bindings[i].$1);
              final List<Name> declaredNames = result.$1;

              for (int j = 0; j < declaredNames.length; j++) {
                Name name = declaredNames[j];
                if (idents.contains(name.intern)) {
                  return alg.errorExp(
                      MultipleDeclarationsError(name.sourceName, name.location),
                      location: name.location);
                } else {
                  ctxt = ctxt.addTermName(name);
                }
              }

              Exp exp = resolveLocal<Exp>(bindings[i].$2, ctxt);
              bindings0[i] = Pair<Pat, Exp>(result.$2, exp);
            }
            break;
        }

        // Finally resolve the continuation (body).
        Exp body0 = resolveLocal<Exp>(body, ctxt);

        return alg.let(bindings0, body0,
            bindingMethod: bindingMethod, location: location);
      };

  Transformer<NameContext, Exp> match(
          Transformer<NameContext, Exp> scrutinee,
          List<
                  Pair<Transformer<NameContext, Pat>,
                      Transformer<NameContext, Exp>>>
              cases,
          {Location location}) =>
      (NameContext ctxt) {
        Exp e = scrutinee(ctxt);
        List<Pair<Pat, Exp>> clauses = new List<Pair<Pat, Exp>>(cases.length);
        for (int i = 0; i < cases.length; i++) {
          clauses[i] = Pair<Pat, Exp>(cases[i].$1(ctxt), cases[i].$2(ctxt));
        }
        return alg.match(e, clauses, location: location);
      };

  Transformer<NameContext, Name> typeName(String ident, {Location location}) =>
      (NameContext ctxt) {
        Name name = ctxt.resolve(ident, location: location);
        if (!name.isResolved) {
          unresolved.add(name);
        }
        return name;
      };
  Transformer<NameContext, Name> errorName(LocatedError error,
          {Location location}) =>
      (NameContext _) => alg.errorName(error, location: location);
}

class ResolvedErrorCollector extends Catamorphism<Name, List<LocatedError>,
    List<LocatedError>, List<LocatedError>, List<LocatedError>> {
  final ListMonoid<LocatedError> _m = new ListMonoid<LocatedError>();
  final NullMonoid<Name> _name = new NullMonoid<Name>();
  // A specialised monoid for each sort.
  Monoid<Name> get name => _name;
  Monoid<List<LocatedError>> get typ => _m;
  Monoid<List<LocatedError>> get mod => _m;
  Monoid<List<LocatedError>> get exp => _m;
  Monoid<List<LocatedError>> get pat => _m;

  // Primitive converters.
  static T _id<T>(T x) => x;
  Endomorphism<List<LocatedError>> id =
      Endomorphism<List<LocatedError>>.of(_id);
  static List<LocatedError> _dropName(Name _) => <LocatedError>[];
  final Morphism<Name, List<LocatedError>> dropName =
      new Morphism<Name, List<LocatedError>>.of(_dropName);
  Morphism<Name, List<LocatedError>> get name2typ => dropName;
  Morphism<List<LocatedError>, List<LocatedError>> get typ2pat => id;
  Morphism<List<LocatedError>, List<LocatedError>> get typ2exp => id;
  Morphism<List<LocatedError>, List<LocatedError>> get pat2exp => id;
  Morphism<List<LocatedError>, List<LocatedError>> get exp2mod => id;

  final List<LocatedError> nameErrors = new List<LocatedError>();

  List<LocatedError> errorModule(LocatedError error, {Location location}) =>
      <LocatedError>[error];
  List<LocatedError> errorExp(LocatedError error, {Location location}) =>
      <LocatedError>[error];
  List<LocatedError> errorPattern(LocatedError error, {Location location}) =>
      <LocatedError>[error];
  List<LocatedError> errorType(LocatedError error, {Location location}) =>
      <LocatedError>[error];
  Name errorName(LocatedError error, {Location location}) {
    nameErrors.add(error);
    return name.empty;
  }

  List<LocatedError> module(List<List<LocatedError>> members,
      {Location location}) {
    List<LocatedError> errors = members.fold(mod.empty, mod.compose);
    errors.addAll(nameErrors);
    return errors;
  }
}
