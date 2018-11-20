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
  final bool _trace;
  TypeChecker([this._trace = false]);

  Result<ModuleMember, TypeError> typeCheck(ModuleMember module) {
    _TypeChecker typeChecker = _TypeChecker(new Unifier(_trace), _trace);
    typeChecker.typeCheck(module, new TypingContext());
    Result<ModuleMember, TypeError> result;
    if (typeChecker.errors.length > 0) {
      result = Result<ModuleMember, TypeError>.failure(typeChecker.errors);
    } else {
      result = Result<ModuleMember, TypeError>.success(module);
    }

    return Result<ModuleMember, TypeError>.success(module);
  }
}

class _TypeChecker {
  List<TypeError> errors = new List<TypeError>();
  final bool trace;
  final Unifier unifier;

  _TypeChecker(this.unifier, [this.trace]);

  Datatype error(TypeError err, Location location) {
    errors.add(err);
    return ErrorType(err, location);
  }

  Pair<Substitution, Datatype> lift(Datatype type) {
    return Pair<Substitution, Datatype>(Substitution.empty(), type);
  }

  // Main entry point.
  ModuleMember typeCheck(ModuleMember member, TypingContext initialContext) {
    Pair<Substitution, Datatype> result =
        inferModule(member, Substitution.empty());
    return member;
  }

  Pair<Substitution, Datatype> inferModule(
      ModuleMember member, Substitution subst) {
    if (trace) {
      print("infer module: $member");
    }
    switch (member.tag) {
      case ModuleTag.CONSTR:
      case ModuleTag.DATATYPE_DEFS:
      case ModuleTag.OPEN:
        return lift(typeUtils.unitType);
        break;
      case ModuleTag.TOP:
        TopModule module = member as TopModule;
        for (int i = 0; i < module.members.length; i++) {
          inferModule(module.members[i],
              subst.size == 0 ? subst : Substitution.empty());
        }
        return lift(typeUtils.unitType);
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
  }

  Pair<Substitution, Datatype> inferFunctionDefinition(
      FunctionDeclaration funDef, Substitution sigma) {
    if (funDef is VirtualFunctionDeclaration) {
      return lift(funDef.signature.type);
    }
    Datatype sig = funDef.signature.type;
    if (!typeUtils.isFunctionType(sig)) {
      TypeError err = TypeExpectationError(funDef.signature.location);
      return Pair<Substitution, Datatype>(
          sigma, error(err, funDef.signature.location));
    }
    // Check the formal parameters.
    List<Datatype> domain = typeUtils.domain(sig);
    List<Pattern> parameters = funDef.parameters;
    if (domain.length != parameters.length) {
      TypeError err =
          ArityMismatchError(domain.length, parameters.length, funDef.location);
      return Pair<Substitution, Datatype>(sigma, error(err, funDef.location));
    }
    for (int i = 0; i < parameters.length; i++) {
      checkPattern(parameters[i], domain[i], sigma);
    }
    // Check the body type against the declared type.
    checkExpression(funDef.body, typeUtils.codomain(sig), sigma);

    return lift(sig);
  }

  Pair<Substitution, Datatype> inferValueDefinition(
      ValueDeclaration valDef, Substitution sigma) {
    Datatype sig = valDef.signature.type;
    // Check the body against the declared type.
    // checkExpression(valDef.body, sig, sigma);
    Pair<Substitution, Datatype> result = inferExpression(valDef.body, sigma);
    Substitution sigma0 = result.fst;
    Substitution sigma1 = subsumes(sig, sigma0.apply(result.snd), sigma0);
    return lift(sig);
  }

  Pair<Substitution, Datatype> inferExpression(
      Expression exp, Substitution subst) {
    if (trace) {
      print("infer expression: $exp");
    }
    switch (exp.tag) {
      case ExpTag.BOOL:
        return lift(typeUtils.boolType);
        break;
      case ExpTag.INT:
        return lift(typeUtils.intType);
        break;
      case ExpTag.STRING:
        return lift(typeUtils.stringType);
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
        return lift((exp as Variable).declarator.type);
        break;
      case ExpTag.TYPE_ASCRIPTION:
        throw "Not yet impleemented.";
        break;
      default:
        unhandled("inferExpression", exp.tag);
    }
  }

  Pair<Substitution, Datatype> inferApply(Apply appl, Substitution sigma) {
    // Infer a type for the abstractor.
    Pair<Substitution, Datatype> result =
        inferExpression(appl.abstractor, sigma);
    // Eliminate foralls.
    return apply(appl.arguments, result.snd, result.fst);
  }

  Pair<Substitution, Datatype> apply(
      List<Expression> arguments, Datatype type, Substitution sigma) {
    if (trace) {
      print("apply: $arguments, $type");
    }
    // TODO better error reporting.
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
      Datatype body = guessInstantiation(type.quantifiers, type.body);
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
    Substitution sigma1 = unifier.unify(type, fnType);
    Substitution sigma2 = sigma0.combine(sigma1);
    return Pair<Substitution, Datatype>(sigma2, sigma2.apply(a));
  }

  Pair<Substitution, Datatype> inferMatch(Match match, Substitution sigma) {
    // Infer a type for the scrutinee.
    Pair<Substitution, Datatype> result =
        inferExpression(match.scrutinee, sigma);
    Datatype scrutineeType = result.snd;
    // Check the patterns (left hand sides) against the inferd type for the
    // scrutinee. Check the clause bodies (right hand sides) against the type of
    // their left hand sides.
    if (match.cases.length == 0) {
      return lift(Skolem());
    } else {
      Substitution sigma0 = Substitution.empty();
      Datatype branchType;
      for (int i = 0; i < match.cases.length; i++) {
        Case case0 = match.cases[i];
        checkPattern(case0.pattern, scrutineeType, sigma);
        if (branchType == null) {
          // First case.
          Pair<Substitution, Datatype> result =
              inferExpression(case0.expression, sigma);
          sigma0 = sigma0.combine(result.fst);
          branchType = result.snd;
        } else {
          // Any subsequent case.
          Substitution sigma1 =
              checkExpression(case0.expression, branchType, sigma);
          sigma0 = sigma0.combine(sigma1);
        }
      }
      return Pair<Substitution, Datatype>(sigma0, branchType);
    }
  }

  Pair<Substitution, Datatype> inferLet(Let let, Substitution sigma) {
    // Infer a type for each of the value bindings.
    Substitution sigma0 = sigma;
    Substitution sigma1 = Substitution.empty();
    for (int i = 0; i < let.valueBindings.length; i++) {
      Binding binding = let.valueBindings[i];
      // Infer a type for the expression (right hand side)
      Pair<Substitution, Datatype> result =
          inferExpression(binding.expression, sigma0);
      Substitution sigma2 = result.fst;
      Datatype expType = result.snd;
      // Check the pattern (left hand side) against the inferd type.
      Substitution sigma3 = checkPattern(binding.pattern, expType, sigma2);
      sigma1 = sigma1.combine(sigma3);
      // TODO: Check whether there are any free type/skolem variables in
      // [expType] as the type theory does not admit let generalisation.
    }
    // Infer a type for the continuation (body).
    return inferExpression(let.body, sigma1);
  }

  Pair<Substitution, Datatype> inferLambda(Lambda lambda, Substitution sigma) {
    // Infer types for the parameters.
    List<Datatype> domain = new List<Datatype>(lambda.parameters.length);
    Substitution sigma0 = Substitution.empty();
    for (int i = 0; i < lambda.parameters.length; i++) {
      Pair<Substitution, Datatype> result =
          inferPattern(lambda.parameters[i], sigma);
      sigma0 = sigma0.combine(result.fst);
      domain[i] = result.snd;
    }
    // Infer a type for the body.
    Pair<Substitution, Datatype> result = inferExpression(lambda.body, sigma0);
    Substitution sigma1 = result.fst;
    Datatype codomain = result.snd;

    // Construct the arrow type.
    ArrowType ft = sigma1.apply(ArrowType(domain, codomain));
    return Pair<Substitution, Datatype>(sigma1, ft);
  }

  Pair<Substitution, Datatype> inferIf(If ifthenelse, Substitution sigma) {
    // Check that the condition has type bool.
    Substitution sigma1 =
        checkExpression(ifthenelse.condition, typeUtils.boolType, sigma);
    // Infer a type for each branch.
    Pair<Substitution, Datatype> resultTrueBranch =
        inferExpression(ifthenelse.thenBranch, sigma);
    Substitution sigma2 = resultTrueBranch.fst;
    Datatype tt = sigma2.apply(resultTrueBranch.snd);
    Pair<Substitution, Datatype> resultFalseBranch =
        inferExpression(ifthenelse.elseBranch, null);
    sigma2 = resultFalseBranch.fst;
    Datatype ff = sigma2.apply(resultFalseBranch.snd);
    // Check that types agree.
    Substitution sigma3 = unifier.unify(tt, ff);

    return Pair<Substitution, Datatype>(sigma3, tt);
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
      Substitution sigma) {
    if (xs.length != types.length) {
      Location loc = Location.dummy();
      TypeError err = ArityMismatchError(types.length, xs.length, loc);
      error(err, loc);
      return sigma;
    }

    Substitution sigma0;
    for (int i = 0; i < types.length; i++) {
      Substitution sigma1 = check(xs[i], types[i], sigma);
      sigma0 = sigma0 == null ? sigma1 : sigma0.combine(sigma1);
    }
    return sigma0;
  }

  Substitution checkExpression(
      Expression exp, Datatype type, Substitution sigma) {
    if (trace) {
      print("check expression: $exp : $type");
    }
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
      // Substitution sigma0 = Substitution.empty();
      // for (int i = 0; i < forallType.quantifiers.length; i++) {
      //   sigma0 = sigma0.bind(
      //       TypeVariable.bound(forallType.quantifiers[i]), Skolem());
      // }
      // return checkExpression(exp, sigma0.apply(forallType.body), sigma);
      return checkExpression(exp, forallType.body, sigma);
    }

    // check e t sigma = subsumes e t' sigma', where (t', sigma') = infer e sigma
    Substitution subst0;
    Pair<Substitution, Datatype> result = inferExpression(exp, sigma);
    return subsumes(result.snd, type, result.fst);
  }

  Substitution checkPattern(Pattern pat, Datatype type, Substitution sigma) {
    if (trace) {
      print("check pattern: $pat : $type");
    }
    // Infer a type for [pat].
    Pair<Substitution, Datatype> result = inferPattern(pat, sigma);
    return subsumes(result.snd, type, result.fst);
  }

  Pair<Substitution, Datatype> inferPattern(Pattern pat, Substitution sigma) {
    switch (pat.tag) {
      case PatternTag.BOOL:
        return lift(typeUtils.boolType);
        break;
      case PatternTag.INT:
        return lift(typeUtils.intType);
        break;
      case PatternTag.STRING:
        return lift(typeUtils.stringType);
        break;
      case PatternTag.CONSTR:
        return inferConstructorPattern(pat as ConstructorPattern, sigma);
        break;
      case PatternTag.HAS_TYPE:
        // Check the pattern type against the annotation.
        HasTypePattern hasType = pat as HasTypePattern;
        Substitution sigma1 =
            checkPattern(hasType.pattern, hasType.type, sigma);
        return Pair<Substitution, Datatype>(sigma1, hasType.type);
        break;
      case PatternTag.TUPLE:
        return inferTuple<Pattern>(
            (pat as TuplePattern).components, inferPattern, sigma);
        break;
      case PatternTag.VAR:
        VariablePattern varPattern = pat as VariablePattern;
        varPattern.type = Skolem();
        return lift(varPattern.type);
        break;
      case PatternTag.WILDCARD:
        return lift(Skolem());
        break;
      default:
        unhandled("inferPattern", pat.tag);
    }
  }

  Pair<Substitution, Datatype> inferConstructorPattern(
      ConstructorPattern constr, Substitution sigma) {
    // Get the induced type.
    Datatype type = constr
        .type; // guaranteed to be compatible with `type_utils' function type api.
    // Arity check.
    List<Datatype> domain = typeUtils.domain(type);
    if (domain.length != constr.components.length) {
      TypeError err = ArityMismatchError(
          domain.length, constr.components.length, constr.location);
      return Pair<Substitution, Datatype>(sigma, error(err, constr.location));
    }
    // Infer a type for each subpattern and check it against the induced type.
    Substitution sigma1 = Substitution.empty();
    List<Datatype> components = new List<Datatype>();
    for (int i = 0; i < constr.components.length; i++) {
      Pair<Substitution, Datatype> result =
          inferPattern(constr.components[i], sigma);
      sigma1 = sigma1.combine(result.fst);
      components.add(result.snd);
    }
    return Pair<Substitution, Datatype>(
        sigma1, TypeConstructor.from(constr.declarator.declarator, components));
  }

  Substitution subsumes(Datatype type0, Datatype type1, Substitution sigma) {
    if (trace) {
      print("subsumes: $type0 <: $type1");
    }
    // subsumes (\/qs+. t) t' sigma = subsumes t (t'[qs+ -> as+]) sigma, where as+ are fresh.
    if (type0 is ForallType) {
      ForallType forallType = type0;
      Datatype type2 =
          guessInstantiation(forallType.quantifiers, forallType.body);
      return subsumes(type2, type1, sigma);
    }

    // subsumes t (\/qs+. t') sigma = subsumes (t[qs+ -> %as+]) t' sigma, where %as+ are fresh skolems.
    if (type1 is ForallType) {
      ForallType forallType = type1;
      Datatype type2 =
          guessInstantiation(forallType.quantifiers, type0, useSkolem: true);
      return subsumes(type2, type1.body, sigma);
    }

    // subsumes (ts1* -> t2) (ts3* -> t4) sigma = subsumes* (ts3 sigma') (ts1 sigma') sigma',
    // where sigma' = subsumes* t2 t4 sigma.
    if (type0 is ArrowType && type1 is ArrowType) {
      Substitution sigma0 = subsumes(type0.codomain, type1.codomain, sigma);
      List<Datatype> domain0 = sigma0.applyMany(type0.domain);
      List<Datatype> domain1 = sigma0.applyMany(type1.domain);
      return subsumesMany(domain1, domain0, sigma0);
    }

    // subsumes (* ts1*) (* ts2*) sigma = subsumesMany ts1* ts2* sigma
    if (type0 is TupleType && type1 is TupleType) {
      return subsumesMany(type0.components, type1.components, sigma);
    }

    // subsumes (C ts1*) (K ts2*) sigma = subsumesMany ts1* ts2* sigma, if C = K.
    if (type0 is TypeConstructor && type1 is TypeConstructor) {
      if (type0.ident != type1.ident) {
        Location loc = Location.dummy();
        TypeError err = TypeExpectationError(loc);
        error(err, loc);
        return sigma;
      }
      return subsumesMany(type0.arguments, type1.arguments, sigma);
    }

    // Base case.
    return unifier.unify(type0, type1);
  }

  Substitution subsumesMany(
      List<Datatype> types1, List<Datatype> types2, Substitution sigma) {
    if (types1.length != types2.length) {
      // TODO error.
      return sigma;
    }

    Substitution sigma0 = Substitution.empty();
    for (int i = 0; i < types1.length; i++) {
      Substitution sigma1 = subsumes(types1[i], types2[i], sigma);
      sigma0 = sigma0.combine(sigma1);
    }
    return sigma0;
  }

  Datatype guessInstantiation(List<Quantifier> quantifiers, Datatype type,
      {bool useSkolem = false}) {
    Substitution subst = Substitution.empty();
    for (int i = 0; i < quantifiers.length; i++) {
      Quantifier q = quantifiers[i];
      subst.bind(
          TypeVariable.bound(q), useSkolem ? Skolem() : TypeVariable.unbound());
    }
    return subst.apply(type);
  }
}
