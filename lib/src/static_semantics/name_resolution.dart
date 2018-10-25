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
        MultipleDefinitionsError,
        UnboundNameError;
import '../fp.dart' show Pair, Triple;
import '../immutable_collections.dart';
import '../location.dart';
import '../string_pool.dart';
import '../utils.dart' show Gensym;

import '../ast/algebra.dart';
import '../ast/name.dart';
import '../ast/traversals.dart'
    show
        AccumulatingContextualTransformation,
        AccuTransformer,
        Catamorphism,
        Endomorphism,
        ListMonoid,
        Monoid,
        Morphism,
        NullMonoid,
        ContextualTransformation,
        Transformation,
        Transformer;

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

  // Name resolve(String name, {Location location}) {
  //   int intern = computeIntern(name);
  //   if (vars.containsKey(intern)) {
  //     final int binderId = vars.lookup(intern);
  //     return resolveAs(intern, binderId, location: location);
  //   } else if (types.containsKey(intern)) {
  //     final int binderId = types.lookup(intern);
  //     return resolveAs(intern, binderId, location: location);
  //   } else {
  //     return new Name.unresolved(name, location);
  //   }
  // }

  // Name resolveAs(int intern, int id, {Location location}) {
  //   return new Name.of(intern, id, location);
  // }

  // bool containsVar(int intern) {
  //   return vars.containsKey(intern);
  // }

  bool containsTypename(Name name) {
    return typenames.containsKey(name.intern);
  }

  int computeIntern(String name) => Name.computeIntern(name);
}

// class BindingContext extends NameContext {
//   BindingContext() : super(null, null);

//   Name resolve(String name, {Location location}) {
//     return Name.resolved(name, Gensym.freshInt(), location);
//   }

//   bool containsVar(int _) => true;
//   bool containsType(int _) => true;
// }

// class PatternBindingContext extends BindingContext {
//   final List<Name> names = new List<Name>();
//   PatternBindingContext() : super();

//   Name resolve(String name, {Location location}) {
//     Name resolved = super.resolve(name, location: location);
//     names.add(resolved);
//     return resolved;
//   }
// }

// class NameResolver<Mod, Exp, Pat, Typ> extends ContextualTransformation<
//     NameContext, Name, Pair<NameContext, Mod>, Exp, Pat, Typ> {
//   final TAlgebra<Name, Mod, Exp, Pat, Typ> _alg;
//   TAlgebra<Name, Mod, Exp, Pat, Typ> get alg => _alg;

//   final BindingContext bindingContext = new BindingContext();
//   final Map<int, Name> signatureMap = new Map<int, Name>();

//   NameResolver(this._alg);

//   Name resolveBinder(Transformer<NameContext, Name> binder) {
//     return binder(bindingContext);
//   }

//   Pair<List<Name>, Pat> resolvePatternBinding(
//       Transformer<NameContext, Pat> pattern) {
//     PatternBindingContext ctxt = new PatternBindingContext();
//     Pat pat = pattern(ctxt);
//     return Pair<List<Name>, Pat>(ctxt.names, pat);
//   }

//   Pair<List<Name>, List<Pat>> resolvePatternBindings(
//       List<Transformer<NameContext, Pat>> patterns) {
//     if (patterns.length == 0) {
//       return Pair<List<Name>, List<Pat>>(new List<Name>(), new List<Pat>());
//     }
//     Pair<List<Name>, List<Pat>> initial =
//         Pair<List<Name>, List<Pat>>(new List<Name>(), new List<Pat>());
//     Pair<List<Name>, List<Pat>> result = patterns
//         .map(resolvePatternBinding)
//         .fold(initial,
//             (Pair<List<Name>, List<Pat>> acc, Pair<List<Name>, Pat> elem) {
//       acc.$1.addAll(elem.$1);
//       acc.$2.add(elem.$2);
//       return acc;
//     });

//     return result;
//   }

//   T resolveLocal<T>(Transformer<NameContext, T> obj, NameContext ctxt) {
//     return obj(ctxt);
//   }

//   Transformer<NameContext, Pair<NameContext, Mod>> datatypes(
//           List<
//                   Triple<
//                       Transformer<NameContext, Name>,
//                       List<Transformer<NameContext, Name>>,
//                       List<
//                           Pair<Transformer<NameContext, Name>,
//                               List<Transformer<NameContext, Typ>>>>>>
//               defs,
//           List<Transformer<NameContext, Name>> deriving,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Two passes:
//         // 1) Resolve all binders.
//         // 2) Resolve all right hand sides.
//         List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>> defs0 =
//             new List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>>(
//                 defs.length);

//         // First pass.
//         List<Name> binders = new List<Name>(defs.length);
//         for (int i = 0; i < defs0.length; i++) {
//           Triple<
//               Transformer<NameContext, Name>,
//               List<Transformer<NameContext, Name>>,
//               List<
//                   Pair<Transformer<NameContext, Name>,
//                       List<Transformer<NameContext, Typ>>>>> def = defs[i];

//           Name binder = resolveBinder(def.$1);
//           if (ctxt.containsType(binder.intern)) {
//             return alg.errorModule(
//                 MultipleDeclarationsError(binder.sourceName, binder.location),
//                 location: binder.location);
//           } else {
//             ctxt = ctxt.addType(binder);
//           }
//           binders[i] = binder;
//         }

//         // Second pass.
//         for (int i = 0; i < defs0.length; i++) {
//           Triple<
//               Transformer<NameContext, Name>,
//               List<Transformer<NameContext, Name>>,
//               List<
//                   Pair<Transformer<NameContext, Name>,
//                       List<Transformer<NameContext, Typ>>>>> def = defs[i];
//           NameContext ctxt0 = ctxt;

//           List<Name> typeParameters = new List<Name>(def.$2.length);
//           for (int j = 0; j < typeParameters.length; j++) {
//             Name param = resolveBinder(def.$2[j]);
//             if (ctxt.containsType(param.intern)) {
//               return alg.errorModule(
//                   MultipleDeclarationsError(param.sourceName, param.location),
//                   location: param.location);
//             } else {
//               typeParameters[j] = param;
//               ctxt0 = ctxt0.addType(param);
//             }
//           }

//           List<
//               Pair<Transformer<NameContext, Name>,
//                   List<Transformer<NameContext, Typ>>>> constructors = def.$3;
//           List<Pair<Name, List<Typ>>> constructors0 =
//               new List<Pair<Name, List<Typ>>>(constructors.length);
//           for (int j = 0; j < constructors0.length; j++) {
//             Pair<Transformer<NameContext, Name>,
//                     List<Transformer<NameContext, Typ>>> constructor =
//                 constructors[j];
//             Name cname = resolveBinder(constructor.$1);
//             if (ctxt.containsVar(cname.intern)) {
//               return alg.errorModule(
//                   MultipleDeclarationsError(cname.sourceName, cname.location),
//                   location: cname.location);
//             }
//             ctxt = ctxt.addVar(cname);

//             List<Typ> types = new List<Typ>(constructor.$2.length);
//             for (int k = 0; k < types.length; k++) {
//               Transformer<NameContext, Typ> type = constructors[j].$2[k];
//               types[k] = resolveLocal<Typ>(type, ctxt0);
//             }
//             constructors0[j] = new Pair<Name, List<Typ>>(cname, types);
//           }
//           defs0[i] = Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>(
//               binders[i], typeParameters, constructors0);
//         }

//         List<Name> deriving0 = new List<Name>(deriving.length);
//         for (int i = 0; i < deriving0.length; i++) {
//           deriving0[i] = resolveLocal<Name>(deriving[i], ctxt);
//         }

//         return Pair<NameContext, Mod>(
//             ctxt, alg.datatypes(defs0, deriving0, location: location));
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> valueDef(
//           Transformer<NameContext, Name> name,
//           Transformer<NameContext, Exp> body,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve names in [body] before resolving [name].
//         Exp body0 = resolveLocal<Exp>(body, ctxt);
//         // Although [name] is global, we resolve as a "local" name, because it
//         // must have a type signature that precedes it.
//         Name name0 = resolveLocal<Name>(name, ctxt);
//         bool containsSignature = signatureMap.containsKey(name0.intern);
//         if (!containsSignature) {
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(MissingAccompanyingSignatureError(
//                   name0.sourceName, name0.location)));
//         } else if (containsSignature && signatureMap[name0.intern] == null) {
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(
//                   MultipleDefinitionsError(name0.sourceName, name0.location)));
//         } else {
//           ctxt = ctxt.addVar(name0);
//           signatureMap[name0.intern] = null;
//           return Pair<NameContext, Mod>(
//               ctxt, alg.valueDef(name0, body0, location: location));
//         }
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> functionDef(
//           Transformer<NameContext, Name> name,
//           List<Transformer<NameContext, Pat>> parameters,
//           Transformer<NameContext, Exp> body,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve parameters.
//         List<Pat> params = List<Pat>(parameters.length);
//         NameContext ctxt0 = ctxt;
//         for (int i = 0; i < params.length; i++) {
//           Pair<List<Name>, Pat> param = resolvePatternBinding(parameters[i]);
//           Set<int> idents = new Set<int>();
//           for (int j = 0; j < param.$1.length; j++) {
//             Name paramName = param.$1[j];
//             if (idents.contains(paramName.intern)) {
//               // TODO aggregate errors.
//               return alg.errorModule(
//                   MultipleDeclarationsError(
//                       paramName.sourceName, paramName.location),
//                   location: paramName.location);
//             } else {
//               idents.add(paramName.intern);
//               ctxt0 = ctxt0.addVar(paramName);
//             }
//           }
//           params[i] = param.$2;
//         }
//         // Resolve any names in [body] before resolving [name].
//         Exp body0 = resolveLocal<Exp>(body, ctxt0);
//         // Resolve function definition name as "local" name.
//         Name name0 = resolveLocal<Name>(name, ctxt);
//         bool containsSignature = signatureMap.containsKey(name0.intern);
//         if (!containsSignature) {
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(MissingAccompanyingSignatureError(
//                   name0.sourceName, name0.location)));
//         } else if (containsSignature && signatureMap[name0.intern] == null) {
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(
//                   MultipleDefinitionsError(name0.sourceName, name0.location)));
//         } else {
//           ctxt = ctxt.addVar(name0);
//           signatureMap[name0.intern] = null;
//           return Pair<NameContext, Mod>(
//               ctxt, alg.functionDef(name0, params, body0, location: location));
//         }
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> typename(
//           Transformer<NameContext, Name> binder,
//           List<Transformer<NameContext, Name>> typeParameters,
//           Transformer<NameContext, Typ> type,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve [typeParameters] first.
//         NameContext ctxt0 = ctxt;
//         final List<Name> typeParameters0 =
//             new List<Name>(typeParameters.length);
//         Set<int> idents = new Set<int>();
//         for (int i = 0; i < typeParameters0.length; i++) {
//           Name name = resolveBinder(typeParameters[i]);
//           if (idents.contains(name.intern)) {
//             // TODO aggregate errors.
//             return Pair<NameContext, Mod>(
//                 ctxt,
//                 alg.errorModule(
//                     MultipleDeclarationsError(name.sourceName, name.location),
//                     location: name.location));
//           } else {
//             typeParameters0[i] = name;
//             ctxt0 = ctxt0.addType(name);
//           }
//         }
//         Typ type0 = resolveLocal<Typ>(type, ctxt0);

//         // Type aliases cannot be recursive.
//         final Name binder0 = resolveBinder(binder);
//         ctxt = ctxt.addType(binder0);
//         return Pair<NameContext, Mod>(ctxt,
//             alg.typename(binder0, typeParameters0, type0, location: location));
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> signature(
//           Transformer<NameContext, Name> name,
//           Transformer<NameContext, Typ> type,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve the signature name, and register it as a global.
//         Name name0 = resolveBinder(name);
//         // bool containsSignature = signatureMap.containsKey(name0.intern);
//         // if (containsSignature) {
//         //   return Pair<NameContext, Mod>(
//         //       ctxt,
//         //       alg.errorModule(
//         //           DuplicateTypeSignatureError(name0.sourceName, name0.location),
//         //           location: name0.location));
//         // } else

//         if (ctxt.containsVar(name0)) {
//           signatureMap[name0.intern] = name0; // To avoid cascading errors.
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(
//                   MultipleDeclarationsError(name0.sourceName, name0.location),
//                   location: name0.location));
//         } else {
//           signatureMap[name0.intern] = name0;
//           ctxt = ctxt.addVar(name0);
//         }
//         Typ type0 = resolveLocal<Typ>(type, ctxt);
//         return Pair<NameContext, Mod>(
//             ctxt, alg.signature(name0, type0, location: location));
//       };

//   Transformer<NameContext, Name> termName(String ident, {Location location}) =>
//       (NameContext ctxt) {
//         if (ctxt.containsVar(ident)) {
//           Name name = ctxt.resolve(ident, location: location);
//           return name;
//         } else {
//           return alg.errorName(UnboundNameError(ident, location),
//               location: location);
//         }
//       };

//   Transformer<NameContext, Exp> lambda(
//           List<Transformer<NameContext, Pat>> parameters,
//           Transformer<NameContext, Exp> body,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve parameters.
//         final Pair<List<Name>, List<Pat>> result =
//             resolvePatternBindings(parameters);
//         final List<Pat> parameters0 = result.$2;
//         // Check for duplicate names.
//         final List<Name> params = result.$1;
//         Set<int> idents = new Set<int>();
//         for (int j = 0; j < params.length; j++) {
//           Name paramName = params[j];
//           if (idents.contains(paramName.intern)) {
//             // TODO aggregate errors.
//             return alg.errorExp(
//                 MultipleDeclarationsError(
//                     paramName.sourceName, paramName.location),
//                 location: paramName.location);
//           } else {
//             idents.add(paramName.intern);
//             ctxt = ctxt.addVar(paramName);
//           }
//         }

//         // Resolve names in [body].
//         Exp body0 = resolveLocal<Exp>(body, ctxt);
//         return alg.lambda(parameters0, body0, location: location);
//       };

//   Transformer<NameContext, Exp> let(
//           List<
//                   Pair<Transformer<NameContext, Pat>,
//                       Transformer<NameContext, Exp>>>
//               bindings,
//           Transformer<NameContext, Exp> body,
//           {BindingMethod bindingMethod = BindingMethod.Parallel,
//           Location location}) =>
//       (NameContext ctxt) {
//         final List<Pair<Pat, Exp>> bindings0 =
//             new List<Pair<Pat, Exp>>(bindings.length);
//         Set<int> idents = new Set<int>();
//         // Resolve let bindings.
//         switch (bindingMethod) {
//           case BindingMethod.Parallel:
//             NameContext ctxt0 = ctxt;
//             for (int i = 0; i < bindings0.length; i++) {
//               final Pair<List<Name>, Pat> result =
//                   resolvePatternBinding(bindings[i].$1);
//               final List<Name> declaredNames = result.$1;

//               Exp exp = resolveLocal<Exp>(bindings[i].$2, ctxt);
//               bindings0[i] = Pair<Pat, Exp>(result.$2, exp);

//               for (int j = 0; j < declaredNames.length; j++) {
//                 Name name = declaredNames[j];
//                 if (idents.contains(name.intern)) {
//                   return alg.errorExp(
//                       MultipleDeclarationsError(name.sourceName, name.location),
//                       location: name.location);
//                 } else {
//                   ctxt0 = ctxt0.addVar(name);
//                 }
//               }
//             }
//             ctxt = ctxt0;
//             break;
//           case BindingMethod.Sequential:
//             for (int i = 0; i < bindings.length; i++) {
//               final Pair<List<Name>, Pat> result =
//                   resolvePatternBinding(bindings[i].$1);
//               final List<Name> declaredNames = result.$1;

//               for (int j = 0; j < declaredNames.length; j++) {
//                 Name name = declaredNames[j];
//                 if (idents.contains(name.intern)) {
//                   return alg.errorExp(
//                       MultipleDeclarationsError(name.sourceName, name.location),
//                       location: name.location);
//                 } else {
//                   ctxt = ctxt.addVar(name);
//                 }
//               }

//               Exp exp = resolveLocal<Exp>(bindings[i].$2, ctxt);
//               bindings0[i] = Pair<Pat, Exp>(result.$2, exp);
//             }
//             break;
//         }

//         // Finally resolve the continuation (body).
//         Exp body0 = resolveLocal<Exp>(body, ctxt);

//         return alg.let(bindings0, body0,
//             bindingMethod: bindingMethod, location: location);
//       };

//   Transformer<NameContext, Exp> match(
//           Transformer<NameContext, Exp> scrutinee,
//           List<
//                   Pair<Transformer<NameContext, Pat>,
//                       Transformer<NameContext, Exp>>>
//               cases,
//           {Location location}) =>
//       (NameContext ctxt) {
//         Exp e = resolveLocal<Exp>(scrutinee, ctxt);
//         List<Pair<Pat, Exp>> clauses = new List<Pair<Pat, Exp>>(cases.length);
//         for (int i = 0; i < cases.length; i++) {
//           NameContext ctxt0 = ctxt;
//           Pair<List<Name>, Pat> result = resolvePatternBinding(cases[i].$1);

//           // Check for duplicate declarations.
//           List<Name> declaredNames = result.$1;
//           Set<int> idents = new Set<int>();
//           for (int i = 0; i < declaredNames.length; i++) {
//             Name declaredName = declaredNames[i];
//             if (idents.contains(declaredName.intern)) {
//               return alg.errorExp(MultipleDeclarationsError(
//                   declaredName.sourceName, declaredName.location));
//             } else {
//               ctxt0 = ctxt0.addVar(declaredName);
//             }
//           }

//           // Resolve body.
//           Exp body = resolveLocal<Exp>(cases[i].$2, ctxt0);
//           clauses[i] = Pair<Pat, Exp>(result.$2, body);
//         }
//         return alg.match(e, clauses, location: location);
//       };

//   Transformer<NameContext, Name> typeName(String ident, {Location location}) =>
//       (NameContext ctxt) {
//         if (ctxt.containsType(ident)) {
//           return ctxt.resolve(ident, location: location);
//         } else {
//           return alg.errorName(UnboundNameError(ident, location),
//               location: location);
//         }
//       };
//   Transformer<NameContext, Name> errorName(LocatedError error,
//           {Location location}) =>
//       (NameContext _) => alg.errorName(error, location: location);

//   Transformer<NameContext, Typ> forallType(
//           List<Transformer<NameContext, Name>> quantifiers,
//           Transformer<NameContext, Typ> type,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve binders first.
//         final List<Name> qs = new List<Name>(quantifiers.length);
//         Set<int> idents = new Set<int>();
//         for (int i = 0; i < qs.length; i++) {
//           Name qname = resolveBinder(quantifiers[i]);
//           if (idents.contains(qname.intern)) {
//             return alg.errorType(
//                 MultipleDeclarationsError(qname.sourceName, qname.location),
//                 location: qname.location);
//           } else {
//             ctxt = ctxt.addType(qname);
//             qs[i] = qname;
//           }
//         }

//         // Resolve body.
//         Typ type0 = resolveLocal<Typ>(type, ctxt);
//         return alg.forallType(qs, type0, location: location);
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> module(
//           List<Transformer<NameContext, Pair<NameContext, Mod>>> members,
//           {Location location}) =>
//       (NameContext ctxt) {
//         final List<Mod> members0 = new List<Mod>();
//         for (int i = 0; i < members.length; i++) {
//           Pair<NameContext, Mod> result = members[i](ctxt);
//           ctxt = result.$1;
//           members0.add(result.$2);
//         }

//         // Check whether there are any signatures without an accompanying definition.
//         ctxt.signatures.forEach((int intern, Name name) {
//           if (name != null) {
//             members0.add(alg.errorModule(MissingAccompanyingDefinitionError(
//                 name.sourceName, name.location)));
//           }
//         });
//         return Pair<NameContext, Mod>(
//             ctxt, alg.module(members0, location: location));
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> errorModule(
//           LocatedError error,
//           {Location location}) =>
//       (NameContext ctxt) => Pair<NameContext, Mod>(
//           ctxt, alg.errorModule(error, location: location));
// }

// class ResolvedErrorCollector extends Catamorphism<Name, List<LocatedError>,
//     List<LocatedError>, List<LocatedError>, List<LocatedError>> {
//   final ListMonoid<LocatedError> _m = new ListMonoid<LocatedError>();
//   final NullMonoid<Name> _name = new NullMonoid<Name>();
//   // A specialised monoid for each sort.
//   Monoid<Name> get name => _name;
//   Monoid<List<LocatedError>> get typ => _m;
//   Monoid<List<LocatedError>> get mod => _m;
//   Monoid<List<LocatedError>> get exp => _m;
//   Monoid<List<LocatedError>> get pat => _m;

//   // Primitive converters.
//   static T _id<T>(T x) => x;
//   Endomorphism<List<LocatedError>> id =
//       Endomorphism<List<LocatedError>>.of(_id);
//   static List<LocatedError> _dropName(Name _) => <LocatedError>[];
//   final Morphism<Name, List<LocatedError>> dropName =
//       new Morphism<Name, List<LocatedError>>.of(_dropName);
//   Morphism<Name, List<LocatedError>> get name2typ => dropName;
//   Morphism<List<LocatedError>, List<LocatedError>> get typ2pat => id;
//   Morphism<List<LocatedError>, List<LocatedError>> get typ2exp => id;
//   Morphism<List<LocatedError>, List<LocatedError>> get pat2exp => id;
//   Morphism<List<LocatedError>, List<LocatedError>> get exp2mod => id;

//   final List<LocatedError> nameErrors = new List<LocatedError>();

//   List<LocatedError> errorModule(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
//   List<LocatedError> errorExp(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
//   List<LocatedError> errorPattern(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
//   List<LocatedError> errorType(LocatedError error, {Location location}) =>
//       <LocatedError>[error];
//   Name errorName(LocatedError error, {Location location}) {
//     nameErrors.add(error);
//     return name.empty;
//   }

//   List<LocatedError> module(List<List<LocatedError>> members,
//       {Location location}) {
//     List<LocatedError> errors = members.fold(mod.empty, mod.compose);
//     errors.addAll(nameErrors);
//     return errors;
//   }
// }

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
      unresolvedTypeNames.addAll(other.unresolvedTypeNames);
    }

    if (other.resolvedTypeNames != null) {
      resolvedTypeNames.addAll(other.resolvedTypeNames);
    }

    if (other.resolvedValueNames != null) {
      resolvedValueNames.addAll(other.resolvedValueNames);
    }

    if (other.unresolvedValueNames != null) {
      unresolvedValueNames.addAll(other.unresolvedValueNames);
    }

    if (signatureVars == null) signatureVars = other.signatureVars;
    return this;
  }

  ResolutionResult addTypeName(Name name) {
    if (name.isResolved) {
      if (resolvedTypeNames == null) resolvedTypeNames = new List<Name>();
      resolvedTypeNames.add(name);
      return this;
    } else {
      if (unresolvedTypeNames == null) unresolvedTypeNames = new List<Name>();
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

abstract class NameResolver<Mod, Exp, Pat, Typ>
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

  Pair<List<Name>, Pat> resolveBindingPattern(Resolver<Pat> pat) {
    Pair<ResolutionResult, Pat> r0 = pat(emptyContext);
    Pat pat0 = r0.$2;

    List<Name> names = r0.$1.unresolvedValueNames;
    List<Name> names0 = new List<Name>();
    for (int i = 0; i < names.length; i++) {
      Name name = names[i];
      if (name.isResolved) {
        // This should be impossible.
        throw "Impossible! The binder '$name' has already been resolved!";
      } else {
        names0.add(Name.resolveAs(name, Gensym.freshInt()));
      }
    }

    return Pair<List<Name>, Pat>(names0, pat0);
  }

  T resolveLocal<T>(Resolver<T> resolve, NameContext ctxt,
      [T Function(LocatedError, {Location location}) error]) {
    final Pair<ResolutionResult, T> result = resolve(ctxt);
    if (result.$1.unresolvedValueNames.length != 0) {
      Name name = result.$1.unresolvedValueNames[0];
      return error == null
          ? name
          : error(UnboundNameError(name.sourceName, name.location),
              location: name.location);
    }

    if (result.$1.unresolvedTypeNames.length != 0) {
      Name name = result.$1.unresolvedTypeNames[0];
      return error == null
          ? name
          : error(UnboundNameError(name.sourceName, name.location),
              location: name.location);
    }

    return result.$2;
  }

  Pair<ImmutableMap<int, int>, Typ> resolveSignatureType(
      Resolver<Typ> sigtype) {
    Pair<ResolutionResult, Typ> result = sigtype(emptyContext);
    List<Name> typeVars = result.$1.unresolvedTypeNames;
    ImmutableMap<int, int> typeVarMap = ImmutableMap<int, int>.empty();
    for (int i = 0; i < typeVars.length; i++) {
      Name typeVar = typeVars[i];
      typeVarMap = typeVarMap.put(typeVar.intern, typeVar.id);
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
          Pair<List<Name>, Pat> result = resolveBindingPattern(param);
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
          List<Name> constructorNames = new List<Name>(constructors.length);
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

//   final BindingContext bindingContext = new BindingContext();
//   final Map<int, Name> signatureMap = new Map<int, Name>();

//   NameResolver(this._alg);

//   Name resolveBinder(Transformer<NameContext, Name> binder) {
//     return binder(bindingContext);
//   }

//   Pair<List<Name>, Pat> resolvePatternBinding(
//       Transformer<NameContext, Pat> pattern) {
//     PatternBindingContext ctxt = new PatternBindingContext();
//     Pat pat = pattern(ctxt);
//     return Pair<List<Name>, Pat>(ctxt.names, pat);
//   }

//   Pair<List<Name>, List<Pat>> resolvePatternBindings(
//       List<Transformer<NameContext, Pat>> patterns) {
//     if (patterns.length == 0) {
//       return Pair<List<Name>, List<Pat>>(new List<Name>(), new List<Pat>());
//     }
//     Pair<List<Name>, List<Pat>> initial =
//         Pair<List<Name>, List<Pat>>(new List<Name>(), new List<Pat>());
//     Pair<List<Name>, List<Pat>> result = patterns
//         .map(resolvePatternBinding)
//         .fold(initial,
//             (Pair<List<Name>, List<Pat>> acc, Pair<List<Name>, Pat> elem) {
//       acc.$1.addAll(elem.$1);
//       acc.$2.add(elem.$2);
//       return acc;
//     });

//     return result;
//   }

//   T resolveLocal<T>(Transformer<NameContext, T> obj, NameContext ctxt) {
//     return obj(ctxt);
//   }

//   Transformer<NameContext, Pair<NameContext, Mod>> datatypes(
//           List<
//                   Triple<
//                       Transformer<NameContext, Name>,
//                       List<Transformer<NameContext, Name>>,
//                       List<
//                           Pair<Transformer<NameContext, Name>,
//                               List<Transformer<NameContext, Typ>>>>>>
//               defs,
//           List<Transformer<NameContext, Name>> deriving,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Two passes:
//         // 1) Resolve all binders.
//         // 2) Resolve all right hand sides.
//         List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>> defs0 =
//             new List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>>(
//                 defs.length);

//         // First pass.
//         List<Name> binders = new List<Name>(defs.length);
//         for (int i = 0; i < defs0.length; i++) {
//           Triple<
//               Transformer<NameContext, Name>,
//               List<Transformer<NameContext, Name>>,
//               List<
//                   Pair<Transformer<NameContext, Name>,
//                       List<Transformer<NameContext, Typ>>>>> def = defs[i];

//           Name binder = resolveBinder(def.$1);
//           if (ctxt.containsType(binder.intern)) {
//             return alg.errorModule(
//                 MultipleDeclarationsError(binder.sourceName, binder.location),
//                 location: binder.location);
//           } else {
//             ctxt = ctxt.addType(binder);
//           }
//           binders[i] = binder;
//         }

//         // Second pass.
//         for (int i = 0; i < defs0.length; i++) {
//           Triple<
//               Transformer<NameContext, Name>,
//               List<Transformer<NameContext, Name>>,
//               List<
//                   Pair<Transformer<NameContext, Name>,
//                       List<Transformer<NameContext, Typ>>>>> def = defs[i];
//           NameContext ctxt0 = ctxt;

//           List<Name> typeParameters = new List<Name>(def.$2.length);
//           for (int j = 0; j < typeParameters.length; j++) {
//             Name param = resolveBinder(def.$2[j]);
//             if (ctxt.containsType(param.intern)) {
//               return alg.errorModule(
//                   MultipleDeclarationsError(param.sourceName, param.location),
//                   location: param.location);
//             } else {
//               typeParameters[j] = param;
//               ctxt0 = ctxt0.addType(param);
//             }
//           }

//           List<
//               Pair<Transformer<NameContext, Name>,
//                   List<Transformer<NameContext, Typ>>>> constructors = def.$3;
//           List<Pair<Name, List<Typ>>> constructors0 =
//               new List<Pair<Name, List<Typ>>>(constructors.length);
//           for (int j = 0; j < constructors0.length; j++) {
//             Pair<Transformer<NameContext, Name>,
//                     List<Transformer<NameContext, Typ>>> constructor =
//                 constructors[j];
//             Name cname = resolveBinder(constructor.$1);
//             if (ctxt.containsVar(cname.intern)) {
//               return alg.errorModule(
//                   MultipleDeclarationsError(cname.sourceName, cname.location),
//                   location: cname.location);
//             }
//             ctxt = ctxt.addVar(cname);

//             List<Typ> types = new List<Typ>(constructor.$2.length);
//             for (int k = 0; k < types.length; k++) {
//               Transformer<NameContext, Typ> type = constructors[j].$2[k];
//               types[k] = resolveLocal<Typ>(type, ctxt0);
//             }
//             constructors0[j] = new Pair<Name, List<Typ>>(cname, types);
//           }
//           defs0[i] = Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>(
//               binders[i], typeParameters, constructors0);
//         }

//         List<Name> deriving0 = new List<Name>(deriving.length);
//         for (int i = 0; i < deriving0.length; i++) {
//           deriving0[i] = resolveLocal<Name>(deriving[i], ctxt);
//         }

//         return Pair<NameContext, Mod>(
//             ctxt, alg.datatypes(defs0, deriving0, location: location));
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> valueDef(
//           Transformer<NameContext, Name> name,
//           Transformer<NameContext, Exp> body,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve names in [body] before resolving [name].
//         Exp body0 = resolveLocal<Exp>(body, ctxt);
//         // Although [name] is global, we resolve as a "local" name, because it
//         // must have a type signature that precedes it.
//         Name name0 = resolveLocal<Name>(name, ctxt);
//         bool containsSignature = signatureMap.containsKey(name0.intern);
//         if (!containsSignature) {
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(MissingAccompanyingSignatureError(
//                   name0.sourceName, name0.location)));
//         } else if (containsSignature && signatureMap[name0.intern] == null) {
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(
//                   MultipleDefinitionsError(name0.sourceName, name0.location)));
//         } else {
//           ctxt = ctxt.addVar(name0);
//           signatureMap[name0.intern] = null;
//           return Pair<NameContext, Mod>(
//               ctxt, alg.valueDef(name0, body0, location: location));
//         }
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> functionDef(
//           Transformer<NameContext, Name> name,
//           List<Transformer<NameContext, Pat>> parameters,
//           Transformer<NameContext, Exp> body,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve parameters.
//         List<Pat> params = List<Pat>(parameters.length);
//         NameContext ctxt0 = ctxt;
//         for (int i = 0; i < params.length; i++) {
//           Pair<List<Name>, Pat> param = resolvePatternBinding(parameters[i]);
//           Set<int> idents = new Set<int>();
//           for (int j = 0; j < param.$1.length; j++) {
//             Name paramName = param.$1[j];
//             if (idents.contains(paramName.intern)) {
//               // TODO aggregate errors.
//               return alg.errorModule(
//                   MultipleDeclarationsError(
//                       paramName.sourceName, paramName.location),
//                   location: paramName.location);
//             } else {
//               idents.add(paramName.intern);
//               ctxt0 = ctxt0.addVar(paramName);
//             }
//           }
//           params[i] = param.$2;
//         }
//         // Resolve any names in [body] before resolving [name].
//         Exp body0 = resolveLocal<Exp>(body, ctxt0);
//         // Resolve function definition name as "local" name.
//         Name name0 = resolveLocal<Name>(name, ctxt);
//         bool containsSignature = signatureMap.containsKey(name0.intern);
//         if (!containsSignature) {
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(MissingAccompanyingSignatureError(
//                   name0.sourceName, name0.location)));
//         } else if (containsSignature && signatureMap[name0.intern] == null) {
//           return Pair<NameContext, Mod>(
//               ctxt,
//               alg.errorModule(
//                   MultipleDefinitionsError(name0.sourceName, name0.location)));
//         } else {
//           ctxt = ctxt.addVar(name0);
//           signatureMap[name0.intern] = null;
//           return Pair<NameContext, Mod>(
//               ctxt, alg.functionDef(name0, params, body0, location: location));
//         }
//       };

//   Transformer<NameContext, Pair<NameContext, Mod>> typename(
//           Transformer<NameContext, Name> binder,
//           List<Transformer<NameContext, Name>> typeParameters,
//           Transformer<NameContext, Typ> type,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve [typeParameters] first.
//         NameContext ctxt0 = ctxt;
//         final List<Name> typeParameters0 =
//             new List<Name>(typeParameters.length);
//         Set<int> idents = new Set<int>();
//         for (int i = 0; i < typeParameters0.length; i++) {
//           Name name = resolveBinder(typeParameters[i]);
//           if (idents.contains(name.intern)) {
//             // TODO aggregate errors.
//             return Pair<NameContext, Mod>(
//                 ctxt,
//                 alg.errorModule(
//                     MultipleDeclarationsError(name.sourceName, name.location),
//                     location: name.location));
//           } else {
//             typeParameters0[i] = name;
//             ctxt0 = ctxt0.addType(name);
//           }
//         }
//         Typ type0 = resolveLocal<Typ>(type, ctxt0);

//         // Type aliases cannot be recursive.
//         final Name binder0 = resolveBinder(binder);
//         ctxt = ctxt.addType(binder0);
//         return Pair<NameContext, Mod>(ctxt,
//             alg.typename(binder0, typeParameters0, type0, location: location));
//       };

//   Transformer<NameContext, Name> termName(String ident, {Location location}) =>
//       (NameContext ctxt) {
//         if (ctxt.containsVar(ident)) {
//           Name name = ctxt.resolve(ident, location: location);
//           return name;
//         } else {
//           return alg.errorName(UnboundNameError(ident, location),
//               location: location);
//         }
//       };

//   Transformer<NameContext, Exp> lambda(
//           List<Transformer<NameContext, Pat>> parameters,
//           Transformer<NameContext, Exp> body,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve parameters.
//         final Pair<List<Name>, List<Pat>> result =
//             resolvePatternBindings(parameters);
//         final List<Pat> parameters0 = result.$2;
//         // Check for duplicate names.
//         final List<Name> params = result.$1;
//         Set<int> idents = new Set<int>();
//         for (int j = 0; j < params.length; j++) {
//           Name paramName = params[j];
//           if (idents.contains(paramName.intern)) {
//             // TODO aggregate errors.
//             return alg.errorExp(
//                 MultipleDeclarationsError(
//                     paramName.sourceName, paramName.location),
//                 location: paramName.location);
//           } else {
//             idents.add(paramName.intern);
//             ctxt = ctxt.addVar(paramName);
//           }
//         }

//         // Resolve names in [body].
//         Exp body0 = resolveLocal<Exp>(body, ctxt);
//         return alg.lambda(parameters0, body0, location: location);
//       };

//   Transformer<NameContext, Exp> let(
//           List<
//                   Pair<Transformer<NameContext, Pat>,
//                       Transformer<NameContext, Exp>>>
//               bindings,
//           Transformer<NameContext, Exp> body,
//           {BindingMethod bindingMethod = BindingMethod.Parallel,
//           Location location}) =>
//       (NameContext ctxt) {
//         final List<Pair<Pat, Exp>> bindings0 =
//             new List<Pair<Pat, Exp>>(bindings.length);
//         Set<int> idents = new Set<int>();
//         // Resolve let bindings.
//         switch (bindingMethod) {
//           case BindingMethod.Parallel:
//             NameContext ctxt0 = ctxt;
//             for (int i = 0; i < bindings0.length; i++) {
//               final Pair<List<Name>, Pat> result =
//                   resolvePatternBinding(bindings[i].$1);
//               final List<Name> declaredNames = result.$1;

//               Exp exp = resolveLocal<Exp>(bindings[i].$2, ctxt);
//               bindings0[i] = Pair<Pat, Exp>(result.$2, exp);

//               for (int j = 0; j < declaredNames.length; j++) {
//                 Name name = declaredNames[j];
//                 if (idents.contains(name.intern)) {
//                   return alg.errorExp(
//                       MultipleDeclarationsError(name.sourceName, name.location),
//                       location: name.location);
//                 } else {
//                   ctxt0 = ctxt0.addVar(name);
//                 }
//               }
//             }
//             ctxt = ctxt0;
//             break;
//           case BindingMethod.Sequential:
//             for (int i = 0; i < bindings.length; i++) {
//               final Pair<List<Name>, Pat> result =
//                   resolvePatternBinding(bindings[i].$1);
//               final List<Name> declaredNames = result.$1;

//               for (int j = 0; j < declaredNames.length; j++) {
//                 Name name = declaredNames[j];
//                 if (idents.contains(name.intern)) {
//                   return alg.errorExp(
//                       MultipleDeclarationsError(name.sourceName, name.location),
//                       location: name.location);
//                 } else {
//                   ctxt = ctxt.addVar(name);
//                 }
//               }

//               Exp exp = resolveLocal<Exp>(bindings[i].$2, ctxt);
//               bindings0[i] = Pair<Pat, Exp>(result.$2, exp);
//             }
//             break;
//         }

//         // Finally resolve the continuation (body).
//         Exp body0 = resolveLocal<Exp>(body, ctxt);

//         return alg.let(bindings0, body0,
//             bindingMethod: bindingMethod, location: location);
//       };

//   Transformer<NameContext, Exp> match(
//           Transformer<NameContext, Exp> scrutinee,
//           List<
//                   Pair<Transformer<NameContext, Pat>,
//                       Transformer<NameContext, Exp>>>
//               cases,
//           {Location location}) =>
//       (NameContext ctxt) {
//         Exp e = resolveLocal<Exp>(scrutinee, ctxt);
//         List<Pair<Pat, Exp>> clauses = new List<Pair<Pat, Exp>>(cases.length);
//         for (int i = 0; i < cases.length; i++) {
//           NameContext ctxt0 = ctxt;
//           Pair<List<Name>, Pat> result = resolvePatternBinding(cases[i].$1);

//           // Check for duplicate declarations.
//           List<Name> declaredNames = result.$1;
//           Set<int> idents = new Set<int>();
//           for (int i = 0; i < declaredNames.length; i++) {
//             Name declaredName = declaredNames[i];
//             if (idents.contains(declaredName.intern)) {
//               return alg.errorExp(MultipleDeclarationsError(
//                   declaredName.sourceName, declaredName.location));
//             } else {
//               ctxt0 = ctxt0.addVar(declaredName);
//             }
//           }

//           // Resolve body.
//           Exp body = resolveLocal<Exp>(cases[i].$2, ctxt0);
//           clauses[i] = Pair<Pat, Exp>(result.$2, body);
//         }
//         return alg.match(e, clauses, location: location);
//       };

//   Transformer<NameContext, Name> typeName(String ident, {Location location}) =>
//       (NameContext ctxt) {
//         if (ctxt.containsType(ident)) {
//           return ctxt.resolve(ident, location: location);
//         } else {
//           return alg.errorName(UnboundNameError(ident, location),
//               location: location);
//         }
//       };
//   Transformer<NameContext, Name> errorName(LocatedError error,
//           {Location location}) =>
//       (NameContext _) => alg.errorName(error, location: location);

//   Transformer<NameContext, Typ> forallType(
//           List<Transformer<NameContext, Name>> quantifiers,
//           Transformer<NameContext, Typ> type,
//           {Location location}) =>
//       (NameContext ctxt) {
//         // Resolve binders first.
//         final List<Name> qs = new List<Name>(quantifiers.length);
//         Set<int> idents = new Set<int>();
//         for (int i = 0; i < qs.length; i++) {
//           Name qname = resolveBinder(quantifiers[i]);
//           if (idents.contains(qname.intern)) {
//             return alg.errorType(
//                 MultipleDeclarationsError(qname.sourceName, qname.location),
//                 location: qname.location);
//           } else {
//             ctxt = ctxt.addType(qname);
//             qs[i] = qname;
//           }
//         }

//         // Resolve body.
//         Typ type0 = resolveLocal<Typ>(type, ctxt);
//         return alg.forallType(qs, type0, location: location);
//       };

}
