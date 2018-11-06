// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../builtins.dart';
import '../errors/errors.dart'
    show ArityMismatchError, TypeExpectationError, TypeSignatureMismatchError;

import '../fp.dart' show Pair, Triple, Either;
import '../immutable_collections.dart';
import '../location.dart';
import '../utils.dart' show Gensym;

import '../ast/algebra.dart';
import '../ast/datatype.dart';
import '../ast/name.dart';
import '../ast/traversals.dart' show AccumulatingContextualTransformation;

import 'type_utils.dart' as typeUtils;
import 'unification.dart';

class AlgebraicDatatype {
  Datatype _type;
  Name name;
  List<Quantifier> quantifiers;
  List<DataConstructor> dataConstructors;

  AlgebraicDatatype(this.name, this.quantifiers, this.dataConstructors);

  Datatype get asType {
    _type ??= TypeConstructor.of(name.id,
        quantifiers.map((Quantifier q) => TypeVariable.bound(q)).toList());
    return _type;
  }
}

class DataConstructor {
  Name name;
  Datatype type;

  DataConstructor._(this.name, this.type);

  factory DataConstructor(
      Name name, AlgebraicDatatype adt, List<Datatype> domain) {
    Datatype ft = ArrowType(domain, adt.asType);
    if (adt.quantifiers.length > 0) {
      ForallType forall = ForallType();
      forall.quantifiers = adt.quantifiers;
      forall.body = ft;
      ft = forall;
    }
    return DataConstructor._(name, ft);
  }
}

class TypeAlias {
  Name name;
  List<Quantifier> quantifiers;
  Datatype type;

  TypeAlias(this.name, this.quantifiers, this.type);
}

class TypeResult {
  Datatype type; // Type resulting from check or synthesis.
  TypingContext outputContext;
  // TypeAlias typeAlias; // Might be null.
  // List<AlgebraicDatatype> adts; // Might be null.
  // // List<Pair<int, Datatype>> dataConstructors; // Might be null.

  TypeResult(this.type, this.outputContext);
}

// class OutputContext extends TypeResult {
//   TypingContext context;
//   OutputContext(this.context, Datatype type) : super(type);
// }

class SignatureResult extends TypeResult {
  final Name name;
  SignatureResult(this.name, Datatype type, TypingContext context)
      : super(type, context);
}

class TypeAliasResult extends TypeResult {
  final Name name;
  final List<Name> typeParameters;

  TypeAliasResult(
      this.name, this.typeParameters, Datatype type, TypingContext context)
      : super(type, context);
}

class TypingContext {
  final ImmutableMap<int, Quantifier> quantifiers; // ident -> quantifier.
  final ImmutableMap<int, Datatype> environment; // ident -> type.
  // final ImmutableMap<int, TypeAlias> typeAliases; // ident -> typename.
  // // ImmutableMap<int, Object> interfaces;         // ident -> interfaces

  // TypeContext(this._mode, this.quantifiers, this.environment, this.typeAliases);
  TypingContext(this.quantifiers, this.environment);
  TypingContext.empty()
      : this(ImmutableMap<int, Quantifier>.empty(),
            ImmutableMap<int, Datatype>.empty());

  TypingContext bind(Name name, Datatype type) {
    ImmutableMap<int, Datatype> env = environment.put(name.id, type);
    return TypingContext(quantifiers, env);
  }

  Datatype lookup(Name name) {
    if (environment.containsKey(name.id)) {
      return environment.lookup(name.id);
    } else {
      throw ("No type for name ${name}");
    }
  }

  TypingContext union(TypingContext other) {
    return TypingContext(quantifiers.union(other.quantifiers),
        environment.union(other.environment));
  }

  TypingContext remember(Quantifier q) {
    ImmutableMap<int, Quantifier> qs = quantifiers.put(q.ident, q);
    return TypingContext(qs, environment);
  }

  Quantifier recall(Name name) {
    if (quantifiers.containsKey(name.id)) {
      return quantifiers.lookup(name.id);
    } else {
      throw ("Unbound name $name");
    }
  }
}

// class CheckingContext extends TypingContext {
//   final Datatype type; // Type to check against.

//   CheckingContext(ImmutableMap<int, Quantifier> quantifiers,
//       ImmutableMap<int, Datatype> environment, this.type)
//       : super(quantifiers, environment);
// }

// class SynthesisContext extends TypingContext {
//   SynthesisContext(ImmutableMap<int, Datatype> environment)
//       : super(environment);
// }

typedef Type<T> = Pair<TypeResult, T> Function(TypingContext);

abstract class TypeChecker<Mod, Exp, Pat>
    extends AccumulatingContextualTransformation<TypeResult, TypingContext,
        Name, Mod, Exp, Pat, Datatype> {
  final TypingContext emptyContext = TypingContext.empty();
  final TAlgebra<Name, Mod, Exp, Pat, Datatype> _alg;
  TAlgebra<Name, Mod, Exp, Pat, Datatype> get alg => _alg;
  TypeChecker(this._alg);

  Pair<TypeResult, T> typeCheck<T>(Type<T> obj, TypingContext ctxt) {
    return obj(ctxt);
  }

  Pair<Datatype, T> check<T>(Type<T> obj, Datatype type, TypingContext ctxt) {
    Pair<TypeResult, T> result = obj(ctxt);
    Datatype inferredType = result.fst.type;
    Map<int, Datatype> subst = unify(inferredType, type);
    return Pair<Datatype, T>(substitute(type, subst), result.snd);
  }

  Pair<TypeResult, T> checkBinder<T>(
      Type<T> binder, Datatype type, TypingContext ctxt) {
    Pair<TypeResult, T> result = binder(ctxt);
    Datatype inferredType = result.fst.type;
    Map<int, Datatype> subst = unify(inferredType, type);
    result.fst.type = substitute(type, subst);
    return result;
  }

  T trivial<T>(Type<T> obj) {
    Pair<TypeResult, T> result = obj(emptyContext);
    return result.snd;
  }

  Pair<Datatype, T> synthesise<T>(Type<T> obj, TypingContext ctxt) {
    Pair<TypeResult, T> result = obj(ctxt);
    return Pair<Datatype, T>(result.fst.type, result.snd);
  }

  Type<Mod> signature(Type<Name> name, Type<Datatype> type,
          {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [name].
        Name name0 = trivial<Name>(name);
        // Unwrap [type].
        Datatype type0 = trivial<Datatype>(type);
        return Pair<TypeResult, Mod>(SignatureResult(name0, type0, ctxt),
            alg.signature(name0, type0, location: location));
      };

  Type<Mod> valueDef(Type<Name> name, Type<Exp> body, {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [name].
        Name name0 = trivial<Name>(name);
        // Look up the signature for [name].
        Datatype sig = ctxt.lookup(name0);
        // Check body against the signature type.
        Pair<Datatype, Exp> body0 = check<Exp>(body, sig, ctxt);
        return Pair<TypeResult, Mod>(
            null, alg.valueDef(name0, body0.snd, location: location));
      };

  Type<Mod> functionDef(
          Type<Name> name, List<Type<Pat>> parameters, Type<Exp> body,
          {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [name].
        Name name0 = trivial<Name>(name);
        // Look up the signature for [name].
        Datatype sig = ctxt.lookup(name0);
        // Decompose the signature, and check each parameter against it...
        List<Datatype> domain = typeUtils.domain(sig);
        if (parameters.length != domain.length) {
          return Pair<TypeResult, Mod>(
              null,
              alg.errorModule(
                  TypeSignatureMismatchError(
                      domain.length, parameters.length, location),
                  location: location));
        }
        List<Pat> parameters0 = new List<Pat>(domain.length);
        for (int i = 0; i < domain.length; i++) {
          Pair<TypeResult, Pat> result =
              checkBinder<Pat>(parameters[i], domain[i], ctxt);
          ctxt = ctxt.union(result.fst.outputContext);
          parameters0[i] = result.snd;
        }

        // Check the body against the codomain.
        Datatype codomain = typeUtils.codomain(sig);
        Pair<Datatype, Exp> body0 = check<Exp>(body, codomain, ctxt);

        return Pair<TypeResult, Mod>(null,
            alg.functionDef(name0, parameters0, body0.snd, location: location));
      };

  Type<Mod> typename(Type<Name> binder, List<Type<Name>> typeParameters,
          Type<Datatype> type,
          {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [binder].
        Name binder0 = trivial<Name>(binder);
        // Unwrap [typeParameters].
        List<Name> typeParameters0 = typeParameters.map(trivial).toList();
        // Unwrap [type].
        Datatype type0 = trivial<Datatype>(type);

        return Pair<TypeResult, Mod>(
            TypeAliasResult(binder0, typeParameters0, type0, ctxt),
            alg.typename(binder0, typeParameters0, type0, location: location));
      };

  Type<Mod> module(List<Type<Mod>> members, {Location location}) =>
      (TypingContext ctxt) {
        List<Mod> members0 = new List<Mod>(members.length);
        for (int i = 0; i < members.length; i++) {
          Pair<TypeResult, Mod> result = typeCheck(members[i], ctxt);
          TypeResult tres = result.fst;
          members0[i] = result.snd;

          if (tres == null) continue;
          if (tres is SignatureResult) {
            // Add the signature to the context.
            ctxt = ctxt.bind(tres.name, tres.type);
          } else if (tres is TypeAliasResult) {
            // TODO: Add the alias to the context.
          }
        }
        return null;
      };

  Type<Exp> boolLit(bool b, {Location location}) =>
      (TypingContext ctxt) => Pair<TypeResult, Exp>(
          TypeResult(typeUtils.boolType, ctxt),
          alg.boolLit(b, location: location));
  Type<Exp> intLit(int n, {Location location}) =>
      (TypingContext ctxt) => Pair<TypeResult, Exp>(
          TypeResult(typeUtils.intType, ctxt),
          alg.intLit(n, location: location));
  Type<Exp> stringLit(String s, {Location location}) =>
      (TypingContext ctxt) => Pair<TypeResult, Exp>(
          TypeResult(typeUtils.stringType, ctxt),
          alg.stringLit(s, location: location));

  Type<Exp> varExp(Type<Name> name, {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [name].
        Name name0 = trivial<Name>(name);
        // Look up [name0] in the environment.
        Datatype type = ctxt.lookup(name0);
        return Pair<TypeResult, Exp>(
            TypeResult(type, ctxt), alg.varExp(name0, location: location));
      };

  Type<Exp> apply(Type<Exp> fn, List<Type<Exp>> arguments,
          {Location location}) =>
      (TypingContext ctxt) {
        // Synthesise a type for [fn].
        Pair<Datatype, Exp> result = synthesise<Exp>(fn, ctxt);
        Exp fn0 = result.snd;
        Datatype fnType = result.fst;
        // Synthesise the types of the arguments.
        List<Exp> arguments0 = new List<Exp>(arguments.length);
        List<Datatype> types = new List<Datatype>(arguments.length);
        for (int i = 0; i < arguments0.length; i++) {
          Pair<Datatype, Exp> result0 = synthesise<Exp>(arguments[i], ctxt);
          types[i] = result0.fst;
          arguments0[i] = result0.snd;
        }
        // Check that the synthesised type for [fn] is a function type.
        if (!typeUtils.isFunctionType(fnType)) {
          return Pair<TypeResult, Exp>(null,
              alg.errorExp(TypeExpectationError(location), location: location));
        }
        // Check whether the synthesised argument types conform with the domain.
        List<Datatype> domain = typeUtils.domain(fnType);
        if (domain.length != arguments.length) {
          return Pair<TypeResult, Exp>(
              null,
              alg.errorExp(
                  ArityMismatchError(domain.length, arguments.length, location),
                  location: location));
        }
        for (int i = 0; i < domain.length; i++) {
          Datatype formal = domain[i];
          Datatype actual = types[i];
          Map<int, Datatype> subst = unify(formal, actual);
        }
        // TODO instantiate [fnType].
        Datatype returnType = typeUtils.codomain(fnType);

        return Pair<TypeResult, Exp>(TypeResult(returnType, ctxt),
            alg.apply(fn0, arguments0, location: location));
      };
}
