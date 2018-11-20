// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast_expressions.dart';
import '../ast/ast_module.dart';
import '../ast/ast_patterns.dart';
import '../ast/datatype.dart';

import '../errors/errors.dart';
import '../fp.dart' show Pair;
import '../location.dart';
import '../result.dart';
import '../utils.dart' show Gensym;

import 'substitution.dart' show Substitution;
import 'type_utils.dart' as typeUtils;
import 'unification.dart';

class TypingContext {}

class TypeChecker {
  Result<ModuleMember, LocatedError> typeCheck(ModuleMember module) {
    _TypeChecker typeChecker = _TypeChecker();
    typeChecker.typeCheck(module, new TypingContext());
    Result<ModuleMember, LocatedError> result;
    if (typeChecker.errors.length > 0) {
      result = Result<ModuleMember, LocatedError>.failure(typeChecker.errors);
    } else {
      result = Result<ModuleMember, LocatedError>.success(module);
    }

    return Result<ModuleMember, LocatedError>.success(module);
  }
}

class _TypeChecker {
  List<LocatedError> errors = new List<LocatedError>();

  Datatype error(LocatedError err, Location location) {
    errors.add(err);
    return ErrorType(err, location);
  }

  // Main entry point.
  ModuleMember typeCheck(ModuleMember member, TypingContext initialContext) {
    Pair<Substitution, Datatype> result =
        inferModule(member, Substitution.empty());
    return member;
  }

  Pair<Substitution, Datatype> inferModule(
      ModuleMember member, Substitution subst) {
    switch (member.tag) {
      case ModuleTag.CONSTR:
      case ModuleTag.DATATYPE_DEFS:
      case ModuleTag.OPEN:
        return Pair<Substitution, Datatype>(
            Substitution.empty(), typeUtils.unitType);
        break;
      case ModuleTag.TOP:
        TopModule module = member as TopModule;
        for (int i = 0; i < module.members.length; i++) {
          inferModule(module.members[i],
              subst.size == 0 ? subst : Substitution.empty());
        }
        return Pair<Substitution, Datatype>(
            Substitution.empty(), typeUtils.unitType);
        break;
      case ModuleTag.FUNC_DEF:
        return inferFunctionDefinition(member as FunctionDeclaration, subst);
        break;
      case ModuleTag.VALUE_DEF:
        return inferValueDefinition(member as ValueDeclaration, subst);
        break;
      default:
        unhandled("inferModule", member.tag);
    }
    return null;
  }

  Pair<Substitution, Datatype> inferFunctionDefinition(
      FunctionDeclaration funDef, Substitution subst) {
    if (funDef is VirtualFunctionDeclaration) {
      return Pair<Substitution, Datatype>(
          Substitution.empty(), funDef.signature.type);
    }
    Datatype sig = funDef.signature.type;
    if (!typeUtils.isFunctionType(sig)) {
      LocatedError err = TypeExpectationError(funDef.signature.location);
      error(err, funDef.signature.location);
      return null; // TODO.
    }
    // Check the formal parameters.
    List<Datatype> domain = typeUtils.domain(sig);
    List<Pattern> parameters = funDef.parameters;
    if (domain.length != parameters.length) {
      LocatedError err =
          ArityMismatchError(domain.length, parameters.length, funDef.location);
      error(err, funDef.location);
      return null; // TODO.
    }
    for (int i = 0; i < parameters.length; i++) {
      checkPattern(parameters[i], domain[i], subst);
    }
    // Check the body type against the declared type.
    checkExpression(funDef.body, typeUtils.codomain(sig), subst);

    return null; // TODO.
  }

  Pair<Substitution, Datatype> inferValueDefinition(
      ValueDeclaration valDef, Substitution subst) {
    Datatype sig = valDef.signature.type;
    // Check the body against the declared type.
    checkExpression(valDef.body, sig, subst);
    return null; // TODO.
  }

  Pair<Substitution, Datatype> inferExpression(
      Expression exp, Substitution subst) {
    switch (exp.tag) {
      case ExpTag.BOOL:
        return Pair<Substitution, Datatype>(
            Substitution.empty(), typeUtils.boolType);
        break;
      case ExpTag.INT:
        return Pair<Substitution, Datatype>(
            Substitution.empty(), typeUtils.intType);
        break;
      case ExpTag.STRING:
        return Pair<Substitution, Datatype>(
            Substitution.empty(), typeUtils.stringType);
        break;
      case ExpTag.APPLY:
        return inferApply(exp as Apply, subst);
        break;
      case ExpTag.IF:
        return inferIf(exp as If, subst);
        break;
      case ExpTag.LAMBDA:
        return inferLambda(exp as Lambda, subst);
        break;
      case ExpTag.LET:
        return inferLet(exp as Let, subst);
        break;
      case ExpTag.MATCH:
        return inferMatch(exp as Match, subst);
        break;
      case ExpTag.TUPLE:
        return inferTuple<Expression>(
            (exp as Tuple).components, inferExpression, subst);
        break;
      case ExpTag.VAR:
        return Pair<Substitution, Datatype>(
            Substitution.empty(), (exp as Variable).declarator.type);
        break;
      case ExpTag.TYPE_ASCRIPTION:
        throw "Not yet impleemented.";
        break;
      default:
        unhandled("inferExpression", exp.tag);
    }
  }

  Pair<Substitution, Datatype> inferApply(Apply appl, Substitution sigma) {
    // // Infer a type for the abstractor expression (left hand side).
    // Pair<Substitution, Datatype> result =
    //     inferExpression(apply.abstractor, null);
    // Datatype fnType = result.snd;
    // // Check that [fnType] is a function type, otherwise signal an error.
    // if (!typeUtils.isFunctionType(fnType)) {
    //   LocatedError err = TypeExpectationError(apply.abstractor.location);
    //   error(err, apply.location);
    //   return null; // TODO.
    // }
    // // Infer a type each argument expression.
    // final int numArguments = apply.arguments.length;
    // List<Datatype> parameterTypes = typeUtils.domain(fnType);
    // if (parameterTypes.length != numArguments) {
    //   LocatedError err = ArityMismatchError(
    //       parameterTypes.length, numArguments, apply.abstractor.location);
    //   error(err, apply.abstractor.location);
    //   return null; // TODO.
    // }
    // List<Datatype> argumentTypes = new List<Datatype>(numArguments);
    // for (int i = 0; i < numArguments; i++) {
    //   Pair<Substitution, Datatype> result =
    //       inferExpression(apply.arguments[i], null);
    //   Datatype argumentType = result.snd;
    //   argumentTypes[i] = typeUtils.stripQuantifiers(argumentType);
    //   // if (typeUtils.isForallType(argumentType) &&
    //   //     typeUtils.isFunctionType(argumentType)) {
    //   //   argumentTypes[i] = typeUtils.unrigidify(argumentType);
    //   // } else {
    //   //   argumentTypes[i] = argumentType;
    //   // }
    // }
    // // Check that the domain of [fnType] agrees with [argumentTypes].
    // Map<int, Datatype> subst =
    //     unifyMany(typeUtils.domain(fnType), argumentTypes);
    // // Check whether the function type needs to be instantiated.
    // if (typeUtils.isForallType(fnType)) {
    //   // Instantiate [fnType].
    //   // TODO instantiation mismatch error.
    //   fnType = substitute(fnType, subst);
    // }
    Pair<Substitution, Datatype> result =
        inferExpression(appl.abstractor, sigma);
    return apply(appl.arguments, result.snd, result.fst);
  }

  Pair<Substitution, Datatype> apply(
      List<Expression> arguments, Datatype type, Substitution sigma) {
    // if (type is! ArrowType) {
    //   // TODO error.
    //   return null;
    // }

    // ArrowType fnType = type;
    // if (fnType.arity != arguments.length) {
    //   // TODO error.
    //   return null;
    // }

    // apply xs* (\/qs+.t) sigma = apply xs* (t[qs+ -> as+]) sigma
    if (type is ForallType) {
      Datatype body = guessInstantiation(type);
      return apply(arguments, body, sigma);
    }

    // apply xs* (ts* -> t) sigma = (sigma', t sigma'), where sigma' = check* xs* ts* sigma
    if (type is ArrowType) {
      ArrowType fnType = type;
      Substitution sigma0 = checkMany<Expression>(
          checkExpression, arguments, fnType.domain, sigma);
      return Pair<Substitution, Datatype>(
          sigma0, sigma0.apply(fnType.codomain));
    }

    // Base case.
    // apply xs* t sigma = (sigma''', a sigma''')
    // where a is fresh
    //       (sigma', ts*) = infer* xs* sigma
    //       sigma'' = t ~ (ts* -> a)
    //       sigma''' = sigma' ++ sigma''
    TypeVariable a = TypeVariable.unbound();
    // infer*
    Substitution sigma0 = Substitution.empty();
    List<Datatype> domain = new List<Datatype>();
    for (int i = 0; i < arguments.length; i++) {
      Pair<Substitution, Datatype> result =
          inferExpression(arguments[i], sigma);
      sigma0 = sigma0.combine(result.fst);
      domain.add(result.snd);
    }
    // unify
    ArrowType fnType = ArrowType(domain, a);
    Substitution sigma1 = unify0(type, fnType);
    Substitution sigma2 = sigma0.combine(sigma1);
    return Pair<Substitution, Datatype>(sigma2, sigma2.apply(a));
  }

  Pair<Substitution, Datatype> inferMatch(Match match, Substitution subst) {
    // Infer a type for the scrutinee.
    Pair<Substitution, Datatype> result =
        inferExpression(match.scrutinee, null);
    Datatype scrutineeType = result.snd;
    // Check the patterns (left hand sides) against the inferd type for the
    // scrutinee. Check the clause bodies (right hand sides) against the type of
    // their left hand sides.
    Datatype branchType = Skolem();
    for (int i = 0; i < match.cases.length; i++) {
      Case case0 = match.cases[i];
      checkPattern(case0.pattern, scrutineeType, null);
      // branchType = checkExpression(case0.expression, branchType, null);
    }

    // return branchType;
    return null; // TODO.
  }

  Pair<Substitution, Datatype> inferLet(Let let, Substitution subst) {
    // Infer a type for each of the value bindings.
    for (int i = 0; i < let.valueBindings.length; i++) {
      Binding binding = let.valueBindings[i];
      // Infer a type for the expression (right hand side)
      Pair<Substitution, Datatype> result =
          inferExpression(binding.expression, null);
      Datatype expType = result.snd;
      // Check the pattern (left hand side) against the inferd type.
      checkPattern(binding.pattern, expType, null);
      // TODO: Check whether there are any free type/skolem variables in
      // [expType] as the type theory does not admit let generalisation.
    }
    // Infer a type for the continuation (body).
    Pair<Substitution, Datatype> result = inferExpression(let.body, null);
    Datatype bodyType = result.snd;
    // return bodyType;
    return null; // TODO.
  }

  Pair<Substitution, Datatype> inferLambda(Lambda lambda, Substitution subst) {
    // Infer types for the parameters.
    List<Datatype> domain = new List<Datatype>(lambda.parameters.length);
    for (int i = 0; i < lambda.parameters.length; i++) {
      Pair<Substitution, Datatype> result =
          inferPattern(lambda.parameters[i], null);
      domain[i] = result.snd;
    }
    // Infer a type for the body.
    Pair<Substitution, Datatype> result = inferExpression(lambda.body, null);
    Datatype codomain = result.snd;

    // Construct the arrow type.
    ArrowType ft = ArrowType(domain, codomain);

    // return ft;
    return null; // TODO.
  }

  Pair<Substitution, Datatype> inferIf(If ifthenelse, Substitution subst) {
    // Check that the condition has type bool.
    checkExpression(ifthenelse.condition, typeUtils.boolType, null);
    // Infer a type for each branch.
    Pair<Substitution, Datatype> resultTrueBranch =
        inferExpression(ifthenelse.thenBranch, null);
    Datatype tt = resultTrueBranch.snd;
    Pair<Substitution, Datatype> resultFalseBranch =
        inferExpression(ifthenelse.elseBranch, null);
    Datatype ff = resultFalseBranch.snd;
    // Check that types agree.
    // Datatype branchType = unify(tt, ff);
    // return branchType;
    return null; // TODO.
  }

  Pair<Substitution, Datatype> inferTuple<T>(
      List<T> components,
      Pair<Substitution, Datatype> Function(T, Substitution) infer,
      Substitution sigma) {
    // If there are no subexpression, then return the canonical unit type.
    if (components.length == 0) {
      return Pair<Substitution, Datatype>(
          Substitution.empty(), typeUtils.unitType);
    }
    // Infer a type for each subexpression.
    List<Datatype> componentTypes = new List<Datatype>(components.length);
    Substitution sigma0 = Substitution.empty();
    for (int i = 0; i < components.length; i++) {
      Pair<Substitution, Datatype> result = infer(components[i], sigma);
      sigma0 = sigma0.combine(result.fst);
      componentTypes[i] = result.snd;
    }
    return Pair<Substitution, Datatype>(sigma0, TupleType(componentTypes));
  }

  Substitution checkMany<T>(
      Substitution Function(T, Datatype, Substitution) check,
      List<T> xs,
      List<Datatype> types,
      Substitution subst) {
    if (xs.length != types.length) {
      // TODO error.
      return null;
    }

    Substitution subst0;
    for (int i = 0; i < types.length; i++) {
      Substitution sigma0 = check(xs[i], types[i], subst);
      subst0 = subst0 == null ? sigma0 : subst0.combine(sigma0);
    }
    return subst0;
  }

  Substitution checkExpression(
      Expression exp, Datatype type, Substitution sigma) {
    // check (\xs*. e) (ts* -> t) sigma = check e t sigma',
    // where sigma' = check*(xs*, ts*)
    //       check* [] [] _ = []
    //       check* (x :: xs) (t :: ts) sigma = (check x t sigma) ++ (check* xs ts sigma)

    if (type is ArrowType) {
      if (exp is Lambda) {
        Lambda lambda = exp;
        ArrowType fnType = type;
        Substitution sigma0 = checkMany<Pattern>(
            checkPattern, lambda.parameters, fnType.domain, sigma);
        return checkExpression(lambda.body, fnType.codomain, sigma0);
      }
    }

    // check e (\/qs+.t) sigma = check e (t[qs+ -> %a+]) sigma.
    if (type is ForallType) {
      ForallType forallType = type;
      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < forallType.quantifiers.length; i++) {
        sigma0 = sigma0.bindVar(
            TypeVariable.bound(forallType.quantifiers[i]), Skolem());
      }
      return checkExpression(exp, sigma0.apply(forallType.body), sigma);
    }

    // check e t sigma = subsumes e t' sigma', where (t', sigma') = infer e sigma
    Substitution subst0;
    Pair<Substitution, Datatype> result = inferExpression(exp, sigma);
    return subsumes(result.snd, type, result.fst);

    // // Infer a type for [exp].
    // Datatype expType = inferExpression(exp, null);
    // // Unify [expType] and [type].
    // Datatype resultType = unify(expType, type);
    // // TODO handle unification errors.
    // // return resultType;
  }

  Substitution checkPattern(Pattern pat, Datatype type, Substitution subst) {
    // Infer a type for [pat].
    Pair<Substitution, Datatype> result = inferPattern(pat, null);
    // Unify [patType] and [type].
    // Datatype resultType = unify(patType, type);
    // TODO handle unification errors.
    // return resultType;
    return null;
  }

  Pair<Substitution, Datatype> inferPattern(Pattern pat, Substitution subst) {
    switch (pat.tag) {
      case PatternTag.BOOL:
        return Pair<Substitution, Datatype>(
            Substitution.empty(), typeUtils.boolType);
        break;
      case PatternTag.INT:
        return Pair<Substitution, Datatype>(
            Substitution.empty(), typeUtils.intType);
        break;
      case PatternTag.STRING:
        return Pair<Substitution, Datatype>(
            Substitution.empty(), typeUtils.stringType);
        break;
      case PatternTag.CONSTR:
        return inferConstructorPattern(pat as ConstructorPattern, null);
        break;
      case PatternTag.HAS_TYPE:
        // Check the pattern type against the annotation.
        HasTypePattern hasType = pat as HasTypePattern;
        // return checkPattern(hasType.pattern, hasType.type, null);
        return null;
        break;
      case PatternTag.TUPLE:
        return inferTuple<Pattern>(
            (pat as TuplePattern).components, inferPattern, null);
        break;
      case PatternTag.VAR:
        VariablePattern varPattern = pat as VariablePattern;
        varPattern.type = Skolem();
        // return varPattern.type;
        return null; // TODO.
        break;
      case PatternTag.WILDCARD:
        // return Skolem();
        return null; // TODO.
        break;
      default:
        unhandled("inferPattern", pat.tag);
    }
  }

  Pair<Substitution, Datatype> inferConstructorPattern(
      ConstructorPattern constr, Substitution subst) {
    // Get the induced type.
    Datatype type = constr
        .type; // guaranteed to be compatible with `type_utils' function type api.
    // Arity check.
    List<Datatype> domain = typeUtils.domain(type);
    if (domain.length != constr.components.length) {
      LocatedError err = ArityMismatchError(
          domain.length, constr.components.length, constr.location);
      error(err, constr.location);
      return null; // TODO.
    }
    // Infer a type for each subpattern and check it against the induced type.
    // Map<int, Datatype> subst = new Map<int, Datatype>();
    // for (int i = 0; i < constr.components.length; i++) {
    //   Pair<Substitution, Datatype> result = inferPattern(constr.components[i], null);
    //   sigma = sigma.combine(result.fst);
    //   Datatype componentType = result.snd;
    //   subst.addAll(unifyS(componentType, domain[i]));
    // }
    // // Instantiate the type.
    // type = substitute(type, subst);
    // return type;
    return null; // TODO.
  }

  Substitution subsumes(Datatype type0, Datatype type1, Substitution subst) {
    // subsumes (\/qs+. t) t' = subsumes t (t'[qs+ -> as+]), where a+ are fresh.
    if (type0 is ForallType) {
      ForallType forallType = type0;
      Datatype type2 = guessInstantiation(forallType);
      return subsumes(type2, type1, subst);
    }

    // subsumes t (\/qs+. t') = subsumes t (t'[qs+ -> %as+]), where %as+ are fresh skolems.
    if (type1 is ForallType) {
      ForallType forallType = type1;
      Datatype type2 = guessInstantiation(forallType);
      return subsumes(type0, type2, subst);
    }

    // subsumes (ts1* -> t2) (ts3* -> t4) sigma = subsumes* (ts3 sigma') (ts1 sigma') sigma',
    // where sigma' = subsumes* t2 t4 sigma.
    if (type0 is ArrowType && type1 is ArrowType) {
      Substitution subst0 = subsumes(type0.codomain, type1.codomain, subst);
      List<Datatype> domain0 = subst0.applyMany(type0.domain);
      List<Datatype> domain1 = subst0.applyMany(type1.domain);
      return subsumesMany(domain1, domain0, subst0);
    }

    // subsumes (* ts1*) (* ts2*) sigma = subsumesMany ts1* ts2* sigma
    if (type0 is TupleType && type1 is TupleType) {
      return subsumesMany(type0.components, type1.components, subst);
    }

    // subsumes (C ts1*) (K ts2*) sigma = subsumesMany ts1* ts2* sigma, if C = K.
    if (type0 is TypeConstructor && type1 is TypeConstructor) {
      if (type0.ident != type1.ident) {
        // TODO error.
        return null;
      }
      return subsumesMany(type0.arguments, type1.arguments, subst);
    }

    // Base case.
    return unify0(type0, type1);
  }

  Substitution subsumesMany(
      List<Datatype> types1, List<Datatype> types2, Substitution subst) {
    if (types1.length != types2.length) {
      // TODO error.
      return null;
    }

    Substitution subst0 = Substitution.empty();
    for (int i = 0; i < types1.length; i++) {
      Substitution subst1 = subsumes(types1[i], types2[i], subst);
      subst0 = subst0.combine(subst1);
    }
    return subst0;
  }

  Datatype guessInstantiation(ForallType forallType, {bool useSkolem = false}) {
    Substitution subst = Substitution.empty();
    for (int i = 0; i < forallType.quantifiers.length; i++) {
      Quantifier q = forallType.quantifiers[i];
      subst.bindVar(
          TypeVariable.bound(q), useSkolem ? Skolem() : TypeVariable.unbound());
    }
    return subst.apply(forallType.body);
  }
}
