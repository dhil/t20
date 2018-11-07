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

// class AlgebraicDatatype {
//   Datatype _type;
//   Name name;
//   List<Quantifier> quantifiers;
//   List<DataConstructor> dataConstructors;

//   AlgebraicDatatype(this.name, this.quantifiers, this.dataConstructors);

//   Datatype get asType {
//     _type ??= TypeConstructor.of(name.id,
//         quantifiers.map((Quantifier q) => TypeVariable.bound(q)).toList());
//     return _type;
//   }
// }

// class DataConstructor {
//   Name name;
//   Datatype type;

//   DataConstructor._(this.name, this.type);

//   factory DataConstructor(
//       Name name, AlgebraicDatatype adt, List<Datatype> domain) {
//     Datatype ft = ArrowType(domain, adt.asType);
//     if (adt.quantifiers.length > 0) {
//       ForallType forall = ForallType();
//       forall.quantifiers = adt.quantifiers;
//       forall.body = ft;
//       ft = forall;
//     }
//     return DataConstructor._(name, ft);
//   }
// }

class TypeConstructorDescription {
  Name name;
  List<Quantifier> quantifiers;

  TypeConstructorDescription(this.name, this.quantifiers);

  int get arity => quantifiers.length;
}

class TypeAliasDescription extends TypeConstructorDescription {
  Datatype type;

  TypeAliasDescription(Name name, List<Quantifier> quantifiers, this.type)
      : super(name, quantifiers);
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
  final List<Quantifier> quantifiers;

  TypeAliasResult(
      this.name, this.quantifiers, Datatype type, TypingContext context)
      : super(type, context);
}

class TypingContext {
  final ImmutableMap<int, Quantifier> quantifiers; // ident -> quantifier.
  final ImmutableMap<int, Datatype> environment; // ident -> type.
  final ImmutableMap<int, TypeConstructorDescription>
      tyconEnvironment; // ident -> type constructor
  // final ImmutableMap<int, TypeAlias> typeAliases; // ident -> typename.
  // // ImmutableMap<int, Object> interfaces;         // ident -> interfaces

  // TypeContext(this._mode, this.quantifiers, this.environment, this.typeAliases);
  TypingContext(this.quantifiers, this.environment, this.tyconEnvironment);
  TypingContext.empty()
      : this(
            ImmutableMap<int, Quantifier>.empty(),
            ImmutableMap<int, Datatype>.empty(),
            ImmutableMap<int, TypeConstructorDescription>.empty());

  TypingContext bind(Name name, Datatype type) {
    ImmutableMap<int, Datatype> env = environment.put(name.id, type);
    return TypingContext(quantifiers, env, tyconEnvironment);
  }

  Datatype lookup(Name name) {
    if (environment.containsKey(name.id)) {
      return environment.lookup(name.id);
    } else {
      throw ("No type for name ${name}");
    }
  }

  // This operation is questionable.
  TypingContext union(TypingContext other) {
    return TypingContext(quantifiers.union(other.quantifiers),
        environment.union(other.environment), tyconEnvironment);
  }

  TypingContext remember(Quantifier q) {
    ImmutableMap<int, Quantifier> qs = quantifiers.put(q.ident, q);
    return TypingContext(qs, environment, tyconEnvironment);
  }

  Quantifier recall(Name name) {
    if (quantifiers.containsKey(name.id)) {
      return quantifiers.lookup(name.id);
    } else {
      throw ("Unbound name $name");
    }
  }

  TypeConstructorDescription getTypeDescriptor(Name name) {
    if (tyconEnvironment.containsKey(name.id)) {
      return tyconEnvironment.lookup(name.id);
    } else {
      throw ("No type constructor by name $name");
    }
  }

  TypingContext putTypeDescriptor(Name name, TypeConstructorDescription desc) {
    ImmutableMap<int, TypeConstructorDescription> tycon =
        tyconEnvironment.put(name.id, desc);
    return TypingContext(quantifiers, environment, tycon);
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
    type = unify(inferredType, type);
    return Pair<Datatype, T>(type, result.snd);
  }

  Pair<TypeResult, T> checkBinder<T>(
      Type<T> binder, Datatype type, TypingContext ctxt) {
    Pair<TypeResult, T> result = binder(ctxt);
    Datatype inferredType = result.fst.type;
    result.fst.type = unify(inferredType, type);
    return result;
  }

  Pair<TypeResult, Pat> checkPattern(
      Type<Pat> pattern, Datatype type, TypingContext ctxt) {
    Pair<TypeResult, Pat> result = pattern(ctxt);
    Datatype inferredType = result.fst.type;
    result.fst.type = unify(inferredType, type);
    return result;
  }

  T trivial<T>(Type<T> obj) {
    Pair<TypeResult, T> result = obj(emptyContext);
    return result.snd;
  }

  T unwrap<T>(Type<T> obj, TypingContext ctxt) {
    Pair<TypeResult, T> result = obj(ctxt);
    return result.snd;
  }

  Pair<Datatype, T> synthesise<T>(Type<T> obj, TypingContext ctxt) {
    Pair<TypeResult, T> result = obj(ctxt);
    return Pair<Datatype, T>(result.fst.type, result.snd);
  }

  // Pair<TypeResult, T> synthesiseBinder<T>(Type<T> obj, TypingContext ctxt) {
  //   return obj(ctxt);
  // }

  Pair<TypeResult, Pat> synthesisePattern(Type<Pat> pat, TypingContext ctxt) {
    return pat(ctxt);
  }

  TypingContext exposeQuantifiers(Datatype type, TypingContext ctxt) {
    List<Quantifier> qs = typeUtils.extractQuantifiers(type);
    for (int i = 0; i < qs.length; i++) {
      ctxt = ctxt.remember(qs[i]);
    }
    return ctxt;
  }

  // Modules.
  Type<Mod> datatypes(
          List<
                  Triple<Type<Name>, List<Type<Name>>,
                      List<Pair<Type<Name>, List<Type<Datatype>>>>>>
              defs,
          List<Type<Name>> deriving,
          {Location location}) =>
      (TypingContext ctxt) {
        // Idea: Unwrap each algebraic data type definition. Bind the data
        // constructors to their induced function types in the
        // environment. Return the environment and the type constructors.
        for (int i = 0; i < defs.length; i++) {
          // Copy the original context.
          TypingContext ctxt0 = ctxt;
          // Unwrap the type constructor's name.
          Name name = trivial<Name>(defs[i].fst);
          // Unwrap the type parameters.
          List<Quantifier> quantifiers = defs[i]
              .snd
              .map(trivial)
              .map((Name name) => Quantifier(name.id))
              .toList();
          for (int j = 0; j < quantifiers.length; j++) {
            ctxt0 = ctxt0.remember(quantifiers[i]);
          }
          // Construct the target type.
          List<Datatype> arguments =
              quantifiers.map((Quantifier q) => TypeVariable.bound(q)).toList();
          Datatype targetType = TypeConstructor.of(name.id, arguments);

          List<Pair<Type<Name>, List<Type<Datatype>>>> dataConstructors =
              defs[i].thd;
          for (int j = 0; j < dataConstructors.length; j++) {
            // Unwrap the data constructor name.
            Name binder = trivial<Name>(dataConstructors[j].fst);
            // Unwrap the data constructor types.
            List<Datatype> types = dataConstructors[j]
                .snd
                .map((Type<Datatype> type) => unwrap<Datatype>(type, ctxt0))
                .toList();

            // Construct the induced function type.
            Datatype fnType = ArrowType(types, targetType);
            if (quantifiers.length > 0) {
              // Generalise the type.
              ForallType forallType = ForallType();
              forallType.quantifiers = quantifiers;
              forallType.body = fnType;
              fnType = forallType;
            }

            // Update the _original_ context.
            ctxt = ctxt.bind(binder, fnType);
          }
          // Update type constructor environment.
          TypeConstructorDescription desc =
              TypeConstructorDescription(name, quantifiers);
          ctxt = ctxt.putTypeDescriptor(name, desc);
        }
        return Pair<TypeResult, Mod>(
            TypeResult(typeUtils.unitType, ctxt), null);
      };

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
        // Copy the original context.
        TypingContext ctxt0 = ctxt;
        // Unwrap [name].
        Name name0 = trivial<Name>(name);
        // Look up the signature for [name].
        Datatype sig = ctxt.lookup(name0);
        // Bring the bound type variables into scope.
        ctxt0 = exposeQuantifiers(sig, ctxt);
        // Check body against the signature type.
        Pair<Datatype, Exp> body0 = check<Exp>(body, sig, ctxt0);
        return Pair<TypeResult, Mod>(TypeResult(typeUtils.unitType, ctxt),
            alg.valueDef(name0, body0.snd, location: location));
      };

  Type<Mod> functionDef(
          Type<Name> name, List<Type<Pat>> parameters, Type<Exp> body,
          {Location location}) =>
      (TypingContext ctxt) {
        // Copy the original context.
        TypingContext ctxt0 = ctxt;
        // Unwrap [name].
        Name name0 = trivial<Name>(name);
        // Look up the signature for [name].
        Datatype sig = ctxt.lookup(name0);
        // Bring the bound type variables into scope.
        ctxt0 = exposeQuantifiers(sig, ctxt);
        // Decompose the signature, and check each parameter against it...
        List<Datatype> domain = typeUtils.domain(sig);
        if (parameters.length != domain.length) {
          return Pair<TypeResult, Mod>(
              TypeResult(typeUtils.unitType, ctxt),
              alg.errorModule(
                  TypeSignatureMismatchError(
                      domain.length, parameters.length, location),
                  location: location));
        }
        List<Pat> parameters0 = new List<Pat>(domain.length);
        for (int i = 0; i < domain.length; i++) {
          Pair<TypeResult, Pat> result =
              checkBinder<Pat>(parameters[i], domain[i], ctxt0);
          ctxt0 = ctxt0.union(result.fst.outputContext);
          parameters0[i] = result.snd;
        }

        // Check the body against the codomain.
        Datatype codomain = typeUtils.codomain(sig);
        Pair<Datatype, Exp> body0 = check<Exp>(body, codomain, ctxt0);

        return Pair<TypeResult, Mod>(TypeResult(typeUtils.unitType, ctxt),
            alg.functionDef(name0, parameters0, body0.snd, location: location));
      };

  Type<Mod> typename(Type<Name> binder, List<Type<Name>> typeParameters,
          Type<Datatype> type,
          {Location location}) =>
      (TypingContext ctxt) {
        // Copy the original context.
        TypingContext ctxt0 = ctxt;
        // Unwrap [binder].
        Name binder0 = trivial<Name>(binder);
        // Unwrap [typeParameters].
        List<Quantifier> typeParameters0 =
            new List<Quantifier>(typeParameters.length);
        for (int i = 0; i < typeParameters0.length; i++) {
          Name name = trivial<Name>(typeParameters[i]);
          Quantifier q = Quantifier(name.id);
          typeParameters0[i] = q;
          ctxt0 = ctxt0.remember(q);
        }
        // Unwrap [type].
        Datatype type0 = unwrap<Datatype>(type, ctxt0);

        return Pair<TypeResult, Mod>(
            TypeAliasResult(binder0, typeParameters0, type0, ctxt), null);
      };

  Type<Mod> module(List<Type<Mod>> members, {Location location}) =>
      (TypingContext ctxt) {
        List<Mod> members0 = new List<Mod>();
        for (int i = 0; i < members.length; i++) {
          Pair<TypeResult, Mod> result = typeCheck(members[i], ctxt);
          TypeResult typeResult = result.fst;
          // Update context.
          ctxt = typeResult.outputContext;

          // Only add the member if it hasn't been eliminated.
          if (result.snd != null) {
            members0.add(result.snd);
          }
        }

        return Pair<TypeResult, Mod>(TypeResult(typeUtils.unitType, ctxt),
            alg.module(members0, location: location));
      };

  // Expressions.
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
        // TODO only build of the substitution map, if it is needed.
        Map<int, Datatype> subst = new Map<int, Datatype>();
        for (int i = 0; i < domain.length; i++) {
          Datatype formal = domain[i];
          Datatype actual = types[i];
          subst.addAll(unifyS(formal, actual));
        }

        // Instantiate the function type, if necessary.
        if (typeUtils.isForallType(fnType)) {
          // Order the type arguments.
          List<int> order = subst.keys.toList()..sort();
          List<Datatype> arguments = new List<Datatype>(order.length);
          for (int i = 0; i < arguments.length; i++) {
            arguments[i] = subst[order[i]];
          }
          // Perform the instantiation.
          fnType = typeUtils.instantiate(fnType, arguments);
        }
        Datatype returnType = typeUtils.codomain(fnType);

        return Pair<TypeResult, Exp>(TypeResult(returnType, ctxt),
            alg.apply(fn0, arguments0, location: location));
      };

  Type<Exp> lambda(List<Type<Pat>> parameters, Type<Exp> body,
          {Location location}) =>
      (TypingContext ctxt) {
        // Synthesise types for the parameters.
        List<Pat> parameters0 = new List<Pat>(parameters.length);
        List<Datatype> domain = new List<Datatype>(parameters.length);
        for (int i = 0; i < parameters0.length; i++) {
          Pair<TypeResult, Pat> result = synthesisePattern(parameters[i], ctxt);
          TypeResult tres = result.fst;
          domain[i] = tres.type;
          parameters0[i] = result.snd;
          // Update the context (TODO: perhaps update the context after _all_
          // binders have had their types synthesised).
          ctxt = ctxt.union(tres.outputContext);
        }
        // Synthesise a type for [body]
        Pair<Datatype, Exp> result = synthesise<Exp>(body, ctxt);
        // Construct function type.
        Datatype fnType = ArrowType(domain, result.fst);

        return Pair<TypeResult, Exp>(TypeResult(fnType, ctxt),
            alg.lambda(parameters0, result.snd, location: location));
      };

  Type<Exp> tuple(List<Type<Exp>> components, {Location location}) =>
      (TypingContext ctxt) {
        // Synthesise a type for each component.
        List<Exp> components0 = new List<Exp>(components.length);
        List<Datatype> types = new List<Datatype>(components.length);
        for (int i = 0; i < components0.length; i++) {
          Pair<Datatype, Exp> result = synthesise<Exp>(components[i], ctxt);
          types[i] = result.fst;
          components0[i] = result.snd;
        }

        // Make tuple type.
        Datatype tupleType = TupleType(types);
        return Pair<TypeResult, Exp>(TypeResult(tupleType, ctxt),
            alg.tuple(components0, location: location));
      };

  Type<Exp> ifthenelse(
          Type<Exp> condition, Type<Exp> thenBranch, Type<Exp> elseBranch,
          {Location location}) =>
      (TypingContext ctxt) {
        // Synthesise a type for the condition.
        Pair<Datatype, Exp> r0 = synthesise<Exp>(condition, ctxt);
        // Synthesise a type for the then branch.
        Pair<Datatype, Exp> r1 = synthesise<Exp>(thenBranch, ctxt);
        // Synthesise a type for the else branch.
        Pair<Datatype, Exp> r2 = synthesise<Exp>(elseBranch, ctxt);

        // Unify the branch types.
        Datatype branchType = unify(r1.fst, r2.fst);

        return Pair<TypeResult, Exp>(TypeResult(branchType, ctxt),
            alg.ifthenelse(r0.snd, r1.snd, r2.snd, location: location));
      };

  Type<Exp> let(List<Pair<Type<Pat>, Type<Exp>>> bindings, Type<Exp> body,
          {BindingMethod bindingMethod = BindingMethod.Parallel,
          Location location}) =>
      (TypingContext ctxt) {
        TypingContext ctxt0 = ctxt; // Copy the original context.

        List<Pair<Pat, Exp>> bindings0 =
            new List<Pair<Pat, Exp>>(bindings.length);
        // The name resolution pass ought to guarantee that all the bindings in the
        // group are independent, hence it ought to be safe to populate the context
        // as we go. Furthermore, it should imply that we can ignore the "binding
        // method".
        for (int i = 0; i < bindings0.length; i++) {
          Type<Pat> pat = bindings[i].fst;
          Pair<TypeResult, Pat> r0 = synthesisePattern(pat, ctxt0);
          Datatype type = r0.fst.type;
          ctxt0 = ctxt0.union(r0.fst.outputContext);

          Type<Exp> exp = bindings[i].snd;
          Pair<Datatype, Exp> r1 = check<Exp>(exp, type, ctxt0);

          bindings0[i] = Pair<Pat, Exp>(r0.snd, r1.snd);
        }

        // Synthesise a type for the [body].
        Pair<Datatype, Exp> result = synthesise<Exp>(body, ctxt0);
        Datatype type = result.fst;
        Exp body0 = result.snd;

        return Pair<TypeResult, Exp>(
            TypeResult(type, ctxt),
            alg.let(bindings0, body0,
                bindingMethod: bindingMethod, location: location));
      };

  Type<Exp> match(Type<Exp> scrutinee, List<Pair<Type<Pat>, Type<Exp>>> cases,
          {Location location}) =>
      (TypingContext ctxt) {
        // Synthesise a type for the scrutinee.
        Pair<Datatype, Exp> r0 = synthesise<Exp>(scrutinee, ctxt);
        Exp scrutinee0 = r0.snd;
        Datatype scrutineeType = r0.fst;

        // Check the types of the patterns against the scrutinee type, and
        // synthesise a common type for branches.
        Datatype branchType = Skolem();
        List<Pair<Pat, Exp>> cases0 = new List<Pair<Pat, Exp>>(cases.length);
        for (int i = 0; i < cases0.length; i++) {
          // Copy the original context
          TypingContext ctxt0 = ctxt;

          Type<Pat> pat = cases[i].fst;
          Pair<TypeResult, Pat> r1 = synthesisePattern(pat, ctxt0);

          // Unify the scrutinee type and synthesised type.
          Datatype type = r1.fst.type;
          scrutineeType = unify(scrutineeType, type);

          // Synthesise a type for the case.
          ctxt0 = ctxt0.union(r1.fst.outputContext);
          Type<Exp> exp = cases[i].snd;
          Pair<Datatype, Exp> r2 = synthesise<Exp>(exp, ctxt0);

          // Unify the resulting type with [branchType].
          branchType = unify(branchType, r2.fst);

          // Save the progressed case.
          cases0[i] = Pair<Pat, Exp>(r1.snd, r2.snd);
        }
        return Pair<TypeResult, Exp>(TypeResult(branchType, ctxt),
            alg.match(scrutinee0, cases0, location: location));
      };

  // Patterns.
  Type<Pat> boolPattern(bool b, {Location location}) =>
      (TypingContext ctxt) => Pair<TypeResult, Pat>(
          TypeResult(typeUtils.boolType, ctxt),
          alg.boolPattern(b, location: location));

  Type<Pat> intPattern(int n, {Location location}) =>
      (TypingContext ctxt) => Pair<TypeResult, Pat>(
          TypeResult(typeUtils.intType, ctxt),
          alg.intPattern(n, location: location));

  Type<Pat> stringPattern(String s, {Location location}) =>
      (TypingContext ctxt) => Pair<TypeResult, Pat>(
          TypeResult(typeUtils.stringType, ctxt),
          alg.stringPattern(s, location: location));

  Type<Pat> wildcard({Location location}) =>
      (TypingContext ctxt) => Pair<TypeResult, Pat>(
          TypeResult(Skolem(), ctxt), alg.wildcard(location: location));

  Type<Pat> varPattern(Type<Name> name, {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [name].
        Name name0 = trivial<Name>(name);

        // Invent a type for [name0] and bind it in the context.
        Datatype type = Skolem();
        ctxt = ctxt.bind(name0, type);

        return Pair<TypeResult, Pat>(
            TypeResult(type, ctxt), alg.varPattern(name0, location: location));
      };

  Type<Pat> tuplePattern(List<Type<Pat>> components, {Location location}) =>
      (TypingContext ctxt) {
        // Synthesise a type for each subpattern.
        List<Pat> components0 = new List<Pat>(components.length);
        List<Datatype> types = new List<Datatype>(components.length);
        for (int i = 0; i < components0.length; i++) {
          Pair<TypeResult, Pat> result = synthesisePattern(components[i], ctxt);
          types[i] = result.fst.type;
          ctxt = ctxt.union(result.fst.outputContext);
          components0[i] = result.snd;
        }
        // Construct the tuple type.
        Datatype tupleType = TupleType(types);
        return Pair<TypeResult, Pat>(TypeResult(tupleType, ctxt),
            alg.tuplePattern(components0, location: location));
      };

  Type<Pat> hasTypePattern(Type<Pat> pattern, Type<Datatype> type,
          {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [type].
        Datatype type0 = trivial<Datatype>(type);

        // Check the type of pattern against [type0].
        Pair<TypeResult, Pat> result = checkPattern(pattern, type0, ctxt);

        return Pair<TypeResult, Pat>(result.fst,
            alg.hasTypePattern(result.snd, type0, location: location));
      };

  // Type construction.
  Type<Datatype> intType({Location location}) => (TypingContext ctxt) {
        return Pair<TypeResult, Datatype>(
            TypeResult(typeUtils.intType, ctxt), typeUtils.intType);
      };

  Type<Datatype> boolType({Location location}) => (TypingContext ctxt) {
        return Pair<TypeResult, Datatype>(
            TypeResult(typeUtils.boolType, ctxt), typeUtils.boolType);
      };

  Type<Datatype> stringType({Location location}) => (TypingContext ctxt) {
        return Pair<TypeResult, Datatype>(
            TypeResult(typeUtils.stringType, ctxt), typeUtils.stringType);
      };

  Type<Datatype> typeVar(Type<Name> name, {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [name].
        Name name0 = trivial<Name>(name);

        // Look up the quantifier for [name].
        Quantifier q = ctxt.recall(name0);

        // Construct the type variable.
        Datatype typeVar = TypeVariable.bound(q);
        return Pair<TypeResult, Datatype>(TypeResult(typeVar, ctxt), typeVar);
      };

  Type<Datatype> forallType(List<Type<Name>> quantifiers, Type<Datatype> type,
          {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap the quantifiers, and add them to the context.
        List<Quantifier> quantifiers0 =
            new List<Quantifier>(quantifiers.length);
        for (int i = 0; i < quantifiers0.length; i++) {
          Name name = trivial<Name>(quantifiers[i]);
          Quantifier q = Quantifier(name.id);
          quantifiers0[i] = q;
          ctxt = ctxt.remember(q);
        }

        // Unwrap the body [type].
        Datatype body0 = unwrap<Datatype>(type, ctxt);

        Datatype forallType = ForallType.complete(quantifiers0, body0);
        return Pair<TypeResult, Datatype>(
            TypeResult(forallType, ctxt), forallType);
      };

  Type<Datatype> arrowType(List<Type<Datatype>> domain, Type<Datatype> codomain,
          {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap the [domain] components.
        List<Datatype> domain0 = new List<Datatype>(domain.length);
        for (int i = 0; i < domain.length; i++) {
          domain0[i] = unwrap<Datatype>(domain[i], ctxt);
        }
        // Unwrap the [codomain].
        Datatype codomain0 = unwrap<Datatype>(codomain, ctxt);

        // Construct the arrow type.
        Datatype fnType = ArrowType(domain0, codomain0);

        return Pair<TypeResult, Datatype>(TypeResult(fnType, ctxt), fnType);
      };

  Type<Datatype> typeConstr(Type<Name> name, List<Type<Datatype>> arguments,
          {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [name].
        Name name0 = trivial<Name>(name);

        // Unwrap [arguments].
        // TODO: check arity.
        List<Datatype> arguments0 = new List<Datatype>(arguments.length);
        for (int i = 0; i < arguments0.length; i++) {
          arguments0[i] = unwrap<Datatype>(arguments[i], ctxt);
        }

        // Construct the type.
        Datatype type = TypeConstructor.of(name0.id, arguments0);
        return Pair<TypeResult, Datatype>(TypeResult(type, ctxt), type);
      };

  Type<Datatype> tupleType(List<Type<Datatype>> components,
          {Location location}) =>
      (TypingContext ctxt) {
        // Unwrap [components].
        List<Datatype> components0 = new List<Datatype>(components.length);
        for (int i = 0; i < components0.length; i++) {
          components0[i] = unwrap<Datatype>(components[i], ctxt);
        }
        // Construct the tuple type.
        Datatype tupleType = TupleType(components0);
        return Pair<TypeResult, Datatype>(
            TypeResult(tupleType, ctxt), tupleType);
      };
}
