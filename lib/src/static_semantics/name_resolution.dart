// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../builtins.dart';
import '../errors/errors.dart'
    show
        DuplicateTypeSignatureError,
        LocatedError,
        MissingAccompanyingDefinitionError,
        MissingAccompanyingSignatureError,
        MultipleDeclarationsError,
        UnboundNameError;
import '../fp.dart' show Pair, Triple;
import '../immutable_collections.dart';
import '../location.dart';
import '../utils.dart' show Gensym;

import '../ast/algebra.dart';
import '../ast/monoids.dart';
import '../ast/name.dart';
import '../ast/traversals.dart'
    show
        AccumulatingContextualTransformation,
        Catamorphism,
        Endomorphism,
        Morphism;

class SignatureVars {
  final ImmutableMap<int, int> vars;
  final Name name;
  bool hasAccompanyingDefinition = false;
  SignatureVars(this.name, this.vars);
}

class NameContext {
  final ImmutableMap<int, SignatureVars> signatureVars;
  final ImmutableMap<int, int> typenames;
  final ImmutableMap<int, int> valuenames;

  NameContext(this.typenames, this.valuenames, this.signatureVars);
  NameContext.empty()
      : this(ImmutableMap<int, int>.empty(), ImmutableMap<int, int>.empty(),
            ImmutableMap<int, SignatureVars>.empty());
  factory NameContext.withBuiltins() {
    ImmutableMap<int, int> vars = ImmutableMap<int, int>.of(Builtin.termNameMap
        .map((int _, Name name) => MapEntry<int, int>(name.intern, name.id)));
    ImmutableMap<int, int> types = ImmutableMap<int, int>.of(Builtin.typeNameMap
        .map((int _, Name name) => MapEntry<int, int>(name.intern, name.id)));
    return NameContext(types, vars, ImmutableMap<int, SignatureVars>.empty());
  }
  NameContext.onlyWithTypes(ImmutableMap<int, int> typenames)
      : this(typenames, ImmutableMap<int, int>.empty(),
            ImmutableMap<int, SignatureVars>.empty());

  NameContext addValueName(Name name, {Location location}) {
    final ImmutableMap<int, int> valuenames0 =
        valuenames.put(name.intern, name.id);
    return NameContext(typenames, valuenames0, signatureVars);
  }

  NameContext addTypeName(Name name, {Location location}) {
    final ImmutableMap<int, int> typenames0 =
        typenames.put(name.intern, name.id);
    return NameContext(typenames0, valuenames, signatureVars);
  }

  NameContext addSignature(Name name, SignatureVars sigvars) {
    ImmutableMap<int, SignatureVars> sigVars0 =
        signatureVars.put(name.intern, sigvars);
    return NameContext(typenames, valuenames, sigVars0);
  }

  NameContext includeTypes(ImmutableMap<int, int> otherTypes) {
    ImmutableMap<int, int> typesnames0 = typenames.union(otherTypes);
    return NameContext(typesnames0, valuenames, signatureVars);
  }

  NameContext addValueNames(List<Name> names) {
    ImmutableMap<int, int> valuenames0 = valuenames;
    for (int i = 0; i < names.length; i++) {
      valuenames0 = valuenames0.put(names[i].intern, names[i].id);
    }
    return NameContext(typenames, valuenames0, signatureVars);
  }

  NameContext addTypeNames(List<Name> names) {
    ImmutableMap<int, int> typenames0 = typenames;
    for (int i = 0; i < names.length; i++) {
      typenames0 = typenames0.put(names[i].intern, names[i].id);
    }
    return NameContext(typenames0, valuenames, signatureVars);
  }

  Name resolve(String name, {Location location}) {
    int intern = computeIntern(name);
    if (valuenames.containsKey(intern)) {
      final int binderId = valuenames.lookup(intern);
      return resolveAs(intern, binderId, location: location);
    } else if (typenames.containsKey(intern)) {
      final int binderId = typenames.lookup(intern);
      return resolveAs(intern, binderId, location: location);
    } else {
      return new Name.unresolved(name, location);
    }
  }

  Name resolveAs(int intern, int id, {Location location}) {
    return new Name.of(intern, id, location);
  }

  bool containsTypename(Name name) {
    return typenames.containsKey(name.intern);
  }

  int computeIntern(String name) => Name.computeIntern(name);
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

class ResolutionResult {
  List<Name> unresolvedTypeNames;
  List<Name> resolvedTypeNames;

  List<Name> unresolvedValueNames;
  List<Name> resolvedValueNames;

  SignatureVars signatureVars;

  ResolutionResult._(this.unresolvedTypeNames, this.resolvedTypeNames,
      this.unresolvedValueNames, this.resolvedValueNames, this.signatureVars);
  factory ResolutionResult.empty() {
    return ResolutionResult._(null, null, null, null, null);
  }

  ResolutionResult merge(ResolutionResult other) {
    if (other.unresolvedTypeNames != null) {
      unresolvedTypeNames ??= new List<Name>();
      unresolvedTypeNames.addAll(other.unresolvedTypeNames);
    }

    if (other.resolvedTypeNames != null) {
      resolvedTypeNames ??= new List<Name>();
      resolvedTypeNames.addAll(other.resolvedTypeNames);
    }

    if (other.resolvedValueNames != null) {
      resolvedValueNames ??= new List<Name>();
      resolvedValueNames.addAll(other.resolvedValueNames);
    }

    if (other.unresolvedValueNames != null) {
      unresolvedValueNames ??= new List<Name>();
      unresolvedValueNames.addAll(other.unresolvedValueNames);
    }

    if (signatureVars == null) signatureVars = other.signatureVars;
    return this;
  }

  ResolutionResult addTypeName(Name name) {
    if (name.isResolved) {
      resolvedTypeNames ??= new List<Name>();
      resolvedTypeNames.add(name);
      return this;
    } else {
      unresolvedTypeNames ??= new List<Name>();
      unresolvedTypeNames.add(name);
      return this;
    }
  }

  ResolutionResult addValueName(Name name) {
    if (name.isResolved) {
      if (resolvedValueNames == null) resolvedValueNames = new List<Name>();
      resolvedValueNames.add(name);
      return this;
    } else {
      if (unresolvedValueNames == null) unresolvedValueNames = new List<Name>();
      unresolvedValueNames.add(name);
      return this;
    }
  }

  ResolutionResult addValueNames(List<Name> names) {
    ResolutionResult rr = this;
    for (int i = 0; i < names.length; i++) {
      rr = rr.addValueName(names[i]);
    }
    return rr;
  }

  ResolutionResult addTypeNames(List<Name> names) {
    ResolutionResult rr = this;
    for (int i = 0; i < names.length; i++) {
      rr = rr.addTypeName(names[i]);
    }
    return rr;
  }

  ResolutionResult attachSignatureVars(
      Name name, ImmutableMap<int, int> typeVarMap) {
    signatureVars = SignatureVars(name, typeVarMap);
    return this;
  }
}

class ResolutionResultMonoid implements Monoid<ResolutionResult> {
  ResolutionResult get empty => ResolutionResult.empty();
  ResolutionResult compose(ResolutionResult x, ResolutionResult y) {
    return x.merge(y);
  }
}

typedef Resolver<T> = Pair<ResolutionResult, T> Function(NameContext);

class NameResolver<Mod, Exp, Pat, Typ>
    extends AccumulatingContextualTransformation<ResolutionResult, NameContext,
        Name, Mod, Exp, Pat, Typ> {
  final ResolutionResultMonoid _m = new ResolutionResultMonoid();
  Monoid<ResolutionResult> get m => _m;

  final TAlgebra<Name, Mod, Exp, Pat, Typ> _alg;
  TAlgebra<Name, Mod, Exp, Pat, Typ> get alg => _alg;

  final NameContext emptyContext = NameContext.empty();

  NameResolver(this._alg);

  List<Name> duplicates(List<Name> names) {
    final List<Name> dups = new List<Name>();
    final Set<int> idents = new Set<int>();
    for (int i = 0; i < names.length; i++) {
      Name name = names[i];
      if (idents.contains(name.intern)) {
        dups.add(name);
      } else {
        idents.add(name.intern);
      }
    }
    return dups;
  }

  Pair<ResolutionResult, T> reportDuplicates<T>(List<Name> duplicates,
      T Function(LocatedError, {Location location}) error) {
    Name first = duplicates[0];
    return Pair<ResolutionResult, T>(
        m.empty,
        error(MultipleDeclarationsError(first.sourceName, first.location),
            location: first.location));
  }

  Name resolveBinder(Resolver<Name> name) {
    Pair<ResolutionResult, Name> r0 = name(emptyContext);
    Name name0 = r0.$2;
    if (name0.isResolved) {
      // This should be impossible.
      throw "Impossible! The binder '$name0' has already been resolved!";
    } else {
      return Name.resolveAs(name0, Gensym.freshInt());
    }
  }

  Pair<List<Name>, Pat> resolvePatternBinding(
      Resolver<Pat> pat, NameContext ctxt) {
    // Type name context.
    NameContext typenameCtxt = NameContext.onlyWithTypes(ctxt.typenames);

    Pair<ResolutionResult, Pat> r0 = pat(typenameCtxt);
    Pat pat0 = r0.$2;

    List<Name> names0 = new List<Name>();
    if (r0.$1.unresolvedTypeNames != null) {
      List<Name> names = r0.$1.unresolvedTypeNames;
      pat0 = alg.errorPattern(
          UnboundNameError(names[0].sourceName, names[0].location),
          location: names[0].location);
    } else {
      List<Name> names = r0.$1.unresolvedValueNames;
      if (names != null) {
        for (int i = 0; i < names.length; i++) {
          Name name = names[i];
          if (name.isResolved) {
            // This should be impossible.
            throw "Impossible! The binder '$name' has already been resolved!";
          } else {
            names0.add(Name.resolveAs(name, Gensym.freshInt()));
          }
        }
      }
    }

    return Pair<List<Name>, Pat>(names0, pat0);
  }

  T resolveLocal<T>(Resolver<T> resolve, NameContext ctxt,
      [T Function(LocatedError, {Location location}) error]) {
    final Pair<ResolutionResult, T> result = resolve(ctxt);
    if (result.$1.unresolvedValueNames != null) {
      Name name = result.$1.unresolvedValueNames[0];
      return error == null
          ? result.$2
          : error(UnboundNameError(name.sourceName, name.location),
              location: name.location);
    }

    if (result.$1.unresolvedTypeNames != null) {
      Name name = result.$1.unresolvedTypeNames[0];
      return error == null
          ? result.$2
          : error(UnboundNameError(name.sourceName, name.location),
              location: name.location);
    }

    return result.$2;
  }

  Pair<ImmutableMap<int, int>, Typ> resolveSignatureType(
      Resolver<Typ> sigtype) {
    Pair<ResolutionResult, Typ> result = sigtype(emptyContext);
    ImmutableMap<int, int> typeVarMap = ImmutableMap<int, int>.empty();
    List<Name> typeVars = result.$1.resolvedTypeNames;
    if (typeVars != null) {
      for (int i = 0; i < typeVars.length; i++) {
        Name typeVar = typeVars[i];
        typeVarMap = typeVarMap.put(typeVar.intern, typeVar.id);
      }
    }

    return Pair<ImmutableMap<int, int>, Typ>(typeVarMap, result.$2);
  }

  Resolver<Mod> module(List<Resolver<Mod>> members, {Location location}) =>
      (NameContext ctxt) {
        final List<Mod> members0 = new List<Mod>();
        for (int i = 0; i < members.length; i++) {
          Resolver<Mod> resolve = members[i];
          Pair<ResolutionResult, Mod> result = resolve(ctxt);
          Mod member0 = result.$2;

          if (result.$1.resolvedValueNames != null) {
            ctxt = ctxt.addValueNames(result.$1.resolvedValueNames);
          }

          if (result.$1.resolvedTypeNames != null) {
            ctxt = ctxt.addTypeNames(result.$1.resolvedTypeNames);
          }

          if (result.$1.signatureVars != null) {
            SignatureVars sigvars = result.$1.signatureVars;
            ctxt = ctxt.addSignature(sigvars.name, sigvars);
          }
          // TODO check whether there are any unresolved names.

          members0.add(result.$2);
        }

        // Signal an error for every signature that lacks an accompanying
        // binding.
        for (MapEntry<int, SignatureVars> entry in ctxt.signatureVars.entries) {
          if (!entry.value.hasAccompanyingDefinition) {
            Name name = entry.value.name;
            Mod err = alg.errorModule(
                MissingAccompanyingDefinitionError(
                    name.sourceName, name.location),
                location: name.location);
            members0.add(err);
          }
        }

        return Pair<ResolutionResult, Mod>(
            m.empty, alg.module(members0, location: location));
      };

  Resolver<Mod> signature(Resolver<Name> name, Resolver<Typ> type,
          {Location location}) =>
      (NameContext ctxt) {
        // Prepare new result.
        ResolutionResult rr = ResolutionResult.empty();

        // Resolve the signature name, and register it as a global.
        Name name0 = resolveBinder(name);
        if (ctxt.signatureVars.containsKey(name0.intern) &&
            !ctxt.signatureVars
                .lookup(name0.intern)
                .hasAccompanyingDefinition) {
          return Pair<ResolutionResult, Mod>(
              m.empty,
              alg.errorModule(
                  DuplicateTypeSignatureError(name0.sourceName, name0.location),
                  location: name0.location));
        }

        Pair<ImmutableMap<int, int>, Typ> result = resolveSignatureType(type);

        rr = rr.addValueName(name0).attachSignatureVars(name0, result.$1);
        Typ type0 = result.$2;

        return Pair<ResolutionResult, Mod>(
            rr, alg.signature(name0, type0, location: location));
      };

  Resolver<Mod> valueDef(Resolver<Name> name, Resolver<Exp> body,
          {Location location}) =>
      (NameContext ctxt) {
        // Prepare new result.
        ResolutionResult rr = ResolutionResult.empty();

        // Resolve the value as a local as this definition must be preceded by a
        // (signature) declaration.
        Name name0 = resolveLocal<Name>(name, ctxt);
        if (!name0.isResolved) {
          return Pair<ResolutionResult, Mod>(
              rr,
              alg.errorModule(
                  MissingAccompanyingSignatureError(
                      name0.sourceName, name0.location),
                  location: name0.location));
        }
        // Attach this definition to its declaration.
        SignatureVars sigvars = ctxt.signatureVars.lookup(name0.intern);
        sigvars.hasAccompanyingDefinition = true;

        // Resolve [body].
        ctxt = ctxt.includeTypes(sigvars.vars);
        Exp body0 = resolveLocal<Exp>(body, ctxt, alg.errorExp);

        return Pair<ResolutionResult, Mod>(
            rr, alg.valueDef(name0, body0, location: location));
      };

  Resolver<Mod> functionDef(Resolver<Name> name, List<Resolver<Pat>> parameters,
          Resolver<Exp> body,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve the value as a local as this definition must be preceded by a
        // (signature) declaration.
        Name name0 = resolveLocal<Name>(name, ctxt);
        if (!name0.isResolved) {
          return Pair<ResolutionResult, Mod>(
              m.empty,
              alg.errorModule(
                  MissingAccompanyingSignatureError(
                      name0.sourceName, name0.location),
                  location: name0.location));
        }
        // Attach this definition to its declaration.
        SignatureVars sigvars = ctxt.signatureVars.lookup(name0.intern);
        sigvars.hasAccompanyingDefinition = true;

        // Resolve parameters.
        List<Name> names = new List<Name>();
        List<Pat> parameters0 = new List<Pat>(parameters.length);
        for (int i = 0; i < parameters.length; i++) {
          Resolver<Pat> param = parameters[i];
          Pair<List<Name>, Pat> result = resolvePatternBinding(param, ctxt);
          names.addAll(result.$1);
          parameters0[i] = result.$2;
        }
        // Check for duplicates.
        List<Name> dups = duplicates(names);
        if (dups.length != 0) {
          return reportDuplicates<Mod>(dups, alg.errorModule);
        }
        // Add [names] to the function scope.
        for (int i = 0; i < names.length; i++) {
          ctxt = ctxt.addValueName(names[i]);
        }

        // Resolve [body].
        ctxt = ctxt.includeTypes(sigvars.vars);
        Exp body0 = resolveLocal<Exp>(body, ctxt, alg.errorExp);
        return Pair<ResolutionResult, Mod>(m.empty,
            alg.functionDef(name0, parameters0, body0, location: location));
      };

  Resolver<Mod> datatypes(
          List<
                  Triple<Resolver<Name>, List<Resolver<Name>>,
                      List<Pair<Resolver<Name>, List<Resolver<Typ>>>>>>
              defs,
          List<Resolver<Name>> deriving,
          {Location location}) =>
      (NameContext ctxt) {
        // Prepare new result.
        ResolutionResult rr = ResolutionResult.empty();

        // Two passes:
        // 1) Resolve all binders.
        // 2) Resolve all bodies with the above binders in scope.

        // First pass.
        List<Name> declaredNames = new List<Name>(defs.length);
        for (int i = 0; i < declaredNames.length; i++) {
          Resolver<Name> name = defs[i].fst;
          declaredNames[i] = resolveBinder(name);
        }
        // Check for duplicates.
        List<Name> dups = duplicates(declaredNames);
        if (dups.length != 0) {
          return reportDuplicates<Mod>(dups, alg.errorModule);
        }
        // Add all names to the current scope.
        for (int i = 0; i < declaredNames.length; i++) {
          Name name = declaredNames[i];
          if (ctxt.containsTypename(name)) {
            return Pair<ResolutionResult, Mod>(
                m.empty,
                alg.errorModule(
                    MultipleDeclarationsError(name.sourceName, name.location),
                    location: name.location));
          }
          ctxt = ctxt.addTypeName(name);
        }

        // Second pass.
        NameContext ctxt0 = ctxt; // Make a copy of the current context.
        List<Name> constructorNames = new List<Name>();
        List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>> defs0 =
            new List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>>(
                defs.length);
        for (int i = 0; i < declaredNames.length; i++) {
          Triple<Resolver<Name>, List<Resolver<Name>>,
              List<Pair<Resolver<Name>, List<Resolver<Typ>>>>> def = defs[i];

          // Bind type parameters in the local (type) scope.
          List<Resolver<Name>> typeParameters = def.snd;
          List<Name> typeParameters0 = new List<Name>(typeParameters.length);
          for (int i = 0; i < typeParameters0.length; i++) {
            Resolver<Name> name = typeParameters[i];
            Name name0 = resolveBinder(name);
            typeParameters0[i] = name0;
            ctxt0 = ctxt0.addTypeName(name0);
          }
          // Check for duplicates.
          dups = duplicates(typeParameters0);
          if (dups.length != 0) {
            return reportDuplicates<Mod>(dups, alg.errorModule);
          }
          // Now resolve constructors.
          List<Pair<Resolver<Name>, List<Resolver<Typ>>>> constructors =
              def.thd;
          List<Pair<Name, List<Typ>>> constructors0 =
              new List<Pair<Name, List<Typ>>>(constructors.length);
          for (int j = 0; j < constructors0.length; j++) {
            Resolver<Name> name = constructors[j].fst;
            // Resolve the constructor as a binding occurrence.
            Name name0 = resolveBinder(name);
            constructorNames.add(name0);

            // Resolve types.
            List<Resolver<Typ>> types = constructors[j].snd;
            List<Typ> types0 = new List<Typ>(types.length);
            for (int k = 0; k < types0.length; k++) {
              Resolver<Typ> type = types[k];
              types0[k] = resolveLocal<Typ>(type, ctxt0, alg.errorType);
            }

            // Add the constructor to the result.
            constructors0[j] = Pair<Name, List<Typ>>(name0, types0);
          }

          // Add the data type declaration to the result.
          defs0[i] = Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>(
              declaredNames[i], typeParameters0, constructors0);

          // Reset the context.
          ctxt0 = ctxt;
        }

        // Check for duplicate constructors.
        dups = duplicates(constructorNames);
        if (dups.length != 0) {
          return reportDuplicates<Mod>(dups, alg.errorModule);
        }

        // Resolve [deriving] names.
        List<Name> deriving0 = new List<Name>(deriving.length);
        for (int i = 0; i < deriving0.length; i++) {
          Resolver<Name> name = deriving[i];
          deriving0[i] = resolveLocal<Name>(name, ctxt, alg.errorName);
        }
        // TODO validate names in deriving0.

        // Add all the constructors and type names to the result.
        rr = rr.addValueNames(constructorNames).addTypeNames(declaredNames);

        return Pair<ResolutionResult, Mod>(
            rr, alg.datatypes(defs0, deriving0, location: location));
      };

  Resolver<Mod> typename(Resolver<Name> name,
          List<Resolver<Name>> typeParameters, Resolver<Typ> type,
          {Location location}) =>
      (NameContext ctxt) {
        // Prepare new result.
        ResolutionResult rr = ResolutionResult.empty();

        // Resolve the binder.
        Name name0 = resolveBinder(name);
        rr = rr.addTypeName(name0);

        // Resolve the type parameters and body without adding the binder to the
        // context as recursive type aliases aren't allowed.
        List<Name> typeParameters0 = new List<Name>(typeParameters.length);
        for (int i = 0; i < typeParameters0.length; i++) {
          Name param = resolveBinder(typeParameters[i]);
          typeParameters0[i] = param;
          ctxt = ctxt.addTypeName(param);
        }
        // Check for duplicates.
        List<Name> dups = duplicates(typeParameters0);
        if (dups.length != 0) {
          return reportDuplicates<Mod>(dups, alg.errorModule);
        }

        // Resolve body.
        Typ type0 = resolveLocal<Typ>(type, ctxt, alg.errorType);

        return Pair<ResolutionResult, Mod>(rr,
            alg.typename(name0, typeParameters0, type0, location: location));
      };

  Resolver<Exp> lambda(List<Resolver<Pat>> parameters, Resolver<Exp> body,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve parameters.
        List<Pat> parameters0 = new List<Pat>(parameters.length);
        List<Name> declaredNames = new List<Name>();
        for (int i = 0; i < parameters0.length; i++) {
          Pair<List<Name>, Pat> result =
              resolvePatternBinding(parameters[i], ctxt);
          declaredNames.addAll(result.fst);
          parameters0[i] = result.snd;
        }
        // Check for duplicates.
        List<Name> dups = duplicates(declaredNames);
        if (dups.length != 0) {
          return reportDuplicates<Exp>(dups, alg.errorExp);
        }
        // Add the parameters to the local scope.
        ctxt = ctxt.addValueNames(declaredNames);

        // Resolve the body.
        Exp body0 = resolveLocal<Exp>(body, ctxt, alg.errorExp);

        return Pair<ResolutionResult, Exp>(
            m.empty, alg.lambda(parameters0, body0, location: location));
      };

  Resolver<Exp> let(
          List<Pair<Resolver<Pat>, Resolver<Exp>>> bindings, Resolver<Exp> body,
          {BindingMethod bindingMethod = BindingMethod.Parallel,
          Location location}) =>
      (NameContext ctxt) {
        // Resolve bindings.
        List<Pair<Pat, Exp>> bindings0 =
            new List<Pair<Pat, Exp>>(bindings.length);
        List<Name> names = new List<Name>();
        switch (bindingMethod) {
          case BindingMethod.Parallel:
            {
              for (int i = 0; i < bindings0.length; i++) {
                Pair<Resolver<Pat>, Resolver<Exp>> binding = bindings[i];
                Pair<List<Name>, Pat> result =
                    resolvePatternBinding(binding.fst, ctxt);
                names.addAll(result.fst);
                Exp e = resolveLocal<Exp>(binding.snd, ctxt, alg.errorExp);
                bindings0[i] = Pair<Pat, Exp>(result.snd, e);
              }
              // Populate the context.
              ctxt = ctxt.addValueNames(names);
              break;
            }
          case BindingMethod.Sequential:
            {
              for (int i = 0; i < bindings0.length; i++) {
                Pair<Resolver<Pat>, Resolver<Exp>> binding = bindings[i];
                Pair<List<Name>, Pat> result =
                    resolvePatternBinding(binding.fst, ctxt);
                names.addAll(result.fst);
                Exp e = resolveLocal<Exp>(binding.snd, ctxt, alg.errorExp);
                ctxt = ctxt.addValueNames(result.fst);
              }
              break;
            }
        }
        // Check for duplicates.
        List<Name> dups = duplicates(names);
        if (dups.length != 0) {
          return reportDuplicates<Exp>(dups, alg.errorExp);
        }

        // Resolve the continuation.
        Exp body0 = resolveLocal<Exp>(body, ctxt, alg.errorExp);

        return Pair<ResolutionResult, Exp>(
            m.empty,
            alg.let(bindings0, body0,
                bindingMethod: bindingMethod, location: location));
      };

  Resolver<Exp> match(Resolver<Exp> scrutinee,
          List<Pair<Resolver<Pat>, Resolver<Exp>>> cases,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve the scrutinee.
        Exp scrutinee0 = resolveLocal<Exp>(scrutinee, ctxt);

        // Resolve each case.
        List<Pair<Pat, Exp>> cases0 = new List<Pair<Pat, Exp>>(cases.length);
        for (int i = 0; i < cases0.length; i++) {
          // Reset the context.
          NameContext ctxt0 = ctxt;
          // First resolve pattern bindings.
          Pair<Resolver<Pat>, Resolver<Exp>> case_ = cases[i];
          Pair<List<Name>, Pat> result = resolvePatternBinding(case_.fst, ctxt);
          // Check for duplicates.
          List<Name> dups = duplicates(result.fst);
          if (dups.length != 0) {
            return reportDuplicates<Exp>(dups, alg.errorExp);
          }
          // Populate the context.
          ctxt0 = ctxt0.addValueNames(result.fst);
          // Resolve the case body.
          Exp body = resolveLocal<Exp>(case_.snd, ctxt0);
          // Add case.
          cases0[i] = Pair<Pat, Exp>(result.snd, body);
        }

        return Pair<ResolutionResult, Exp>(
            m.empty, alg.match(scrutinee0, cases0, location: location));
      };

  Resolver<Typ> forallType(List<Resolver<Name>> quantifiers, Resolver<Typ> type,
          {Location location}) =>
      (NameContext ctxt) {
        // Resolve type parameters.
        List<Name> quantifiers0 = new List<Name>(quantifiers.length);
        for (int i = 0; i < quantifiers0.length; i++) {
          Name name = resolveBinder(quantifiers[i]);
          quantifiers0[i] = name;
          ctxt = ctxt.addTypeName(name);
        }
        // Check for duplicates.
        List<Name> dups = duplicates(quantifiers0);
        if (dups.length != 0) {
          return reportDuplicates<Typ>(dups, alg.errorType);
        }

        // Resolve the type.
        Typ type0 = resolveLocal<Typ>(type, ctxt);

        // Prepare the result.
        ResolutionResult rr =
            ResolutionResult.empty().addTypeNames(quantifiers0);
        return Pair<ResolutionResult, Typ>(
            rr, alg.forallType(quantifiers0, type0, location: location));
      };

  Resolver<Name> termName(String ident, {Location location}) =>
      (NameContext ctxt) {
        Name name = ctxt.resolve(ident, location: location);
        ResolutionResult rr = ResolutionResult.empty().addValueName(name);
        return Pair<ResolutionResult, Name>(rr, name);
      };

  Resolver<Name> typeName(String ident, {Location location}) =>
      (NameContext ctxt) {
        Name name = ctxt.resolve(ident, location: location);
        ResolutionResult rr = ResolutionResult.empty().addTypeName(name);
        return Pair<ResolutionResult, Name>(rr, name);
      };
}
