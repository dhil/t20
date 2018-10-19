// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../errors/errors.dart'
    show
        DuplicateTypeSignatureError,
        LocatedError,
        MultipleDeclarationsError,
        UnboundNameError;
import '../fp.dart' show Pair;
import '../location.dart';
import '../string_pool.dart';
import '../utils.dart' show Gensym;

import '../ast/algebra.dart';
import '../ast/traversals.dart'
    show
        Catamorphism,
        Endomorphism,
        ListMonoid,
        Monoid,
        Morphism,
        NullMonoid,
        ContextualTransformation,
        Transformer;

final StringPool _sharedPool = new StringPool();

class Name {
  static const int UNRESOLVED = -1;
  final Location location;
  final int intern;

  int _id;
  int get id => _id;
  bool get isResolved => _id != UNRESOLVED;
  String get sourceName => _sharedPool[intern];

  Name._(this.intern, this._id, this.location);
  Name.resolved(int intern, int id, Location location)
      : this._(intern, id, location);
  Name.unresolved(int intern, Location location)
      : this._(intern, UNRESOLVED, location);

  void resolve(int id) => _id = id;
}

class NameContext {
  final Map<int, int> nameEnv;
  final Map<int, int> tynameEnv;

  NameContext(this.nameEnv, this.tynameEnv);
  NameContext.empty() : this(new Map<int, int>(), new Map<int, int>());

  NameContext addTermName(Name name, {Location location}) {
    nameEnv[name.intern] = name.id;
    return this;
  }

  NameContext addTypeName(Name name, {Location location}) {
    tynameEnv[name.intern] = name.id;
    return this;
  }

  Name resolve(String name, {Location location}) {
    if (nameEnv.containsKey(name)) {
      int binderId = nameEnv[name];
      return new Name.resolved(_sharedPool.intern(name), binderId, location);
    } else if (tynameEnv.containsKey(name)) {
      int binderId = tynameEnv[name];
      return new Name.resolved(_sharedPool.intern(name), binderId, location);
    } else {
      return new Name.unresolved(_sharedPool.intern(name), location);
    }
  }

  Name resolveAs(int intern, int id, {Location location}) {
    return new Name._(intern, id, location);
  }

  bool contains(String name) {
    int intern = computeIntern(name);
    return nameEnv.containsKey(intern) || tynameEnv.containsKey(intern);
  }

  int computeIntern(String name) => name.hashCode;
}

class BindingContext extends NameContext {
  BindingContext() : super(null, null);

  Name resolve(String name, {Location location}) {
    return new Name._(_sharedPool.intern(name), Gensym.freshInt(), location);
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

  T resolveLocal<T>(Transformer<NameContext, T> obj, NameContext ctxt) {
    return obj(ctxt);
  }

  Transformer<NameContext, Mod> datatype(
          Pair<Transformer<NameContext, Name>,
                  List<Transformer<NameContext, Name>>>
              binder,
          List<
                  Pair<Transformer<NameContext, Name>,
                      List<Transformer<NameContext, Typ>>>>
              constructors,
          List<Transformer<NameContext, Name>> deriving,
          {Location location}) =>
      (NameContext ctxt) {
        // As recursive data types are allowed, we immediately register the name.
        Name name = resolveBinder(binder.$1);
        if (datatypes.containsKey(name.intern)) {
          return alg.errorModule(
              MultipleDeclarationsError(name.sourceName, name.location),
              location: name.location);
        } else {
          datatypes[name.intern] = name;
          ctxt = ctxt.addTypeName(name);
        }
        List<Name> qs = new List<Name>(binder.$2.length);
        Set<int> qsi = new Set<int>();
        for (int i = 0; i < binder.$2.length; i++) {
          Name q = resolveBinder(binder.$2[i]);
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
        Pair<Name, List<Name>> binder0 = Pair<Name, List<Name>>(name, qs);

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

        return alg.datatype(binder0, constructors0, deriving0,
            location: location);
      };

  Transformer<NameContext, Mod> valueDef(Transformer<NameContext, Name> name,
          Transformer<NameContext, Exp> body,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve names in [body] before resolving [name].
        Exp body0 = body(ctxt);
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
          Pair<Transformer<NameContext, Name>,
                  List<Transformer<NameContext, Name>>>
              constr,
          Transformer<NameContext, Typ> type,
          {Location location}) =>
      (NameContext ctxt) {
        Name constrName = constr.$1(ctxt);
        List<Name> parameters = constr.$2.map((f) => f(ctxt)).toList();
        Pair<Name, List<Name>> constr0 =
            Pair<Name, List<Name>>(constrName, parameters);
        return alg.typename(constr0, type(ctxt), location: location);
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

class NameMonoid implements Monoid<Name> {
  final Name dummy = Name.resolved(_sharedPool.intern("dummy"), -1, Location.dummy());
  Name get empty => dummy;
  Name compose(Name x, Name y) => dummy;
}

class ResolvedErrorCollector extends Catamorphism<Name, List<LocatedError>,
    List<LocatedError>, List<LocatedError>, List<LocatedError>> {
  final ListMonoid<LocatedError> _m = new ListMonoid<LocatedError>();
  final NameMonoid _name = new NameMonoid();
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
