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

class TypingContext {}

class TypeChecker {
  final bool _trace;
  TypeChecker([this._trace = false]);

  Result<ModuleMember, TypeError> typeCheck(ModuleMember module) {
    _TypeChecker typeChecker = _TypeChecker(_trace);
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

  _TypeChecker(this.trace);

  Datatype error(TypeError err, Location location) {
    errors.add(err);
    return ErrorType(err, location);
  }

  Pair<Substitution, Datatype> lift(Datatype type) {
    return Pair<Substitution, Datatype>(Substitution.empty(), type);
  }


  void enter() {
    Skolem.increaseLevel();
  }

  void leave() {
    Skolem.decreaseLevel();
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
    Substitution sigma0 = Substitution.empty();
    for (int i = 0; i < parameters.length; i++) {
      Substitution sigma1 = checkPattern(parameters[i], domain[i], sigma);
      sigma0 = sigma0.combine(sigma1);
    }
    // Check the body type against the declared type.
    sigma0 = checkExpression(funDef.body, typeUtils.codomain(sig), sigma0);

    return lift(sig);
  }

  Pair<Substitution, Datatype> inferValueDefinition(
      ValueDeclaration valDef, Substitution sigma) {
    Datatype sig = valDef.signature.type;
    // Check the body against the declared type.
    // TODO somehow disallow instantiation.
    Substitution sigma0 = checkExpression(valDef.body, sig, sigma);
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
    return apply(appl.arguments, result.snd, result.fst, appl.location);
  }

  Pair<Substitution, Datatype> apply(List<Expression> arguments, Datatype type,
      Substitution sigma, Location location) {
    if (trace) {
      print("apply: $arguments, $type");
    }
    // apply xs* (\/qs+.t) sigma = apply xs* (t[qs+ -> as+]) sigma
    if (type is ForallType) {
      Datatype body = guessInstantiation(type.quantifiers, type.body);
      return apply(arguments, body, sigma, location);
    }

    // apply xs* (ts* -> t) sigma = (sigma', t sigma'), where sigma' = check* xs* ts* sigma
    if (type is ArrowType) {
      ArrowType fnType = type;
      if (type.arity != arguments.length) {
        TypeError err =
            ArityMismatchError(type.arity, arguments.length, location);
        errors.add(err);
        return Pair<Substitution, Datatype>(sigma, type.codomain);
      }
      Substitution sigma0 = checkMany<Expression>(
          checkExpression, arguments, fnType.domain, sigma);
      return Pair<Substitution, Datatype>(sigma0, fnType.codomain);
    }

    if (type is Skolem) {
      Skolem a = type;
      // Construct a function type whose immediate constituents are skolem
      // variables.
      List<Datatype> domain = new List<Datatype>();
      for (int i = 0; i < arguments.length; i++) {
        domain.add(Skolem());
      }
      Datatype codomain = Skolem();
      ArrowType fnType = ArrowType(domain, codomain);
      // Solve a = (a0,...,aN-1) -> aN.
      a.solve(fnType);
      // Check each argument.
      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < domain.length; i++) {
        Substitution sigma1 = checkExpression(arguments[i], domain[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }
      return Pair<Substitution, Datatype>(sigma0, codomain);
    }

    // ERROR.
    unhandled("apply", "$arguments, $type");
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
    List<Datatype> domain = new List<Datatype>();
    Substitution sigma0 = Substitution.empty();
    for (int i = 0; i < lambda.parameters.length; i++) {
      Pair<Substitution, Datatype> result =
          inferPattern(lambda.parameters[i], sigma);
      sigma0 = sigma0.combine(result.fst);
      domain.add(result.snd);
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
    Substitution sigma3 = subsumes(tt, ff, sigma2);

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

    if (type is BoolType && exp is BoolLit ||
        type is IntType && exp is IntLit ||
        type is StringType && exp is StringLit) {
      return sigma;
    }

    // check e t sigma = subsumes e t' sigma', where (t', sigma') = infer e sigma
    Pair<Substitution, Datatype> result = inferExpression(exp, sigma);
    sigma = result.fst;
    Datatype left = result.snd;
    return subsumes(sigma.apply(left), sigma.apply(type), sigma);
  }

  Substitution checkPattern(Pattern pat, Datatype type, Substitution sigma) {
    if (trace) {
      print("check pattern: $pat : $type");
    }

    // Literal pattern check against their respective base types.
    if (pat is BoolPattern && type is BoolType ||
        pat is IntPattern && type is IntType ||
        pat is StringPattern && type is StringType) {
      return sigma;
    }

    // check x t sigma = sigma.
    if (pat is VariablePattern) {
      pat.type = type;
      return sigma;
    }

    // check (, ps*) (, ts*) sigma = check* ps* ts* sigma
    if (pat is TuplePattern && type is TupleType) {
      if (pat.components.length != type.components.length) {
        TypeError err = CheckTuplePatternError(type.toString(), pat.location);
        errors.add(err);
        return sigma;
      }

      if (pat.components.length == 0) return sigma;

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < pat.components.length; i++) {
        Substitution sigma1 =
            checkPattern(pat.components[i], type.components[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }

      // Store the type.
      pat.type = sigma0.apply(type);

      return sigma0;
    }

    // Infer a type for [pat].
    Pair<Substitution, Datatype> result = inferPattern(pat, sigma);

    Substitution sigma0;
    try {
      sigma0 = subsumes(result.snd, type, result.fst);
    } on TypeError catch (e) {
      errors.add(e);
      return sigma;
    }
    return sigma0;
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

  // Implements the subsumption/subtyping relation <:.
  Substitution subsumes(Datatype lhs, Datatype rhs, Substitution sigma) {
    if (trace) {
      print("subsumes: $lhs <: $rhs");
    }

    Datatype a;
    Datatype b;
    if (lhs is Skolem && lhs.isSolved) {
      a = lhs.type;
    } else {
      a = lhs;
    }

    if (rhs is Skolem && rhs.isSolved) {
      b = rhs.type;
    } else {
      b = rhs;
    }

    // %a <: %b if %a = %b.
    if (a is Skolem && b is Skolem) {
      if (a.ident == b.ident) {
        return sigma;
      }
    }

    // a <: b, if a = b.
    if (a is TypeVariable && b is TypeVariable) {
      if (a.ident == b.ident) {
        return sigma;
      }
    }

    // Base types subsumes themselves.
    if (a is BoolType && b is BoolType ||
        a is IntType && b is IntType ||
        a is StringType && b is StringType) {
      return sigma;
    }

    // as* -> a <: bs* -> b, if a sigma' <: b sigma', where sigma' = bs* <:* as*
    if (a is ArrowType && b is ArrowType) {
      if (a.arity != b.arity) {
        throw ConstructorMismatchError(a.toString(), b.toString());
      }

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < a.domain.length; i++) {
        Substitution sigma1 = subsumes(b.domain[i], a.domain[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }

      return subsumes(
          sigma0.apply(a.codomain), sigma0.apply(b.codomain), sigma0);
    }

    // (* as*) <: (* bs*), if as* <: bs*.
    if (a is TupleType && b is TupleType) {
      if (a.arity != b.arity) {
        throw ConstructorMismatchError(a.toString(), b.toString());
      }

      if (a.arity == 0) return sigma;

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < a.components.length; i++) {
        Substitution sigma1 = subsumes(a.components[i], b.components[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }
      return sigma0;
    }

    // C as* <: K bs*, if C = K and as* <: bs*
    if (a is TypeConstructor && b is TypeConstructor) {
      if (a.ident != b.ident || a.arguments.length != b.arguments.length) {
        throw ConstructorMismatchError(a.toString(), b.toString());
      }

      if (a.arguments.length == 0) return sigma;

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < a.arguments.length; i++) {
        Substitution sigma1 = subsumes(a.arguments[i], b.arguments[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }
      return sigma0;
    }

    // \/qs.A <: B, if A[%as/qs] <: B
    if (a is ForallType) {
      Datatype type = guessInstantiation(a.quantifiers, a.body);
      return subsumes(type, b, sigma);
    }

    // a <: \/qs.b, if a <: b
    if (b is ForallType) {
      return subsumes(a, b.body, sigma);
    }

    // %a <: b, if %a \notin FTV(b) and %a <:= b
    if (a is Skolem && !a.isSolved) {
      if (!typeUtils.freeTypeVariables(b).contains(a.ident)) {
        return instantiateLeft(a, b, sigma);
      } else {
        throw OccursError(a.syntheticName, b.toString());
      }
    }

    // a <: %b, if %b \notin FTV(a) and a <:= %b
    if (b is Skolem && !b.isSolved) {
      if (!typeUtils.freeTypeVariables(a).contains(b.ident)) {
        return instantiateRight(a, b, sigma);
      } else {
        throw OccursError(b.syntheticName, a.toString());
      }
    }

    unhandled("subsumes", "$a <: $b");

    // // subsumes (\/qs+. t) t' sigma = subsumes t (t'[qs+ -> as+]) sigma, where as+ are fresh.
    // if (type0 is ForallType) {
    //   ForallType forallType = type0;
    //   Datatype type2 =
    //       guessInstantiation(forallType.quantifiers, forallType.body);
    //   return subsumes(type2, type1, sigma);
    // }

    // // subsumes t (\/qs+. t') sigma = subsumes (t[qs+ -> %as+]) t' sigma, where %as+ are fresh skolems.
    // if (type1 is ForallType) {
    //   ForallType forallType = type1;
    //   Datatype type2 =
    //       guessInstantiation(forallType.quantifiers, type0, useSkolem: true);
    //   return subsumes(type2, type1.body, sigma);
    // }

    // // subsumes (ts1* -> t2) (ts3* -> t4) sigma = subsumes* (ts3 sigma') (ts1 sigma') sigma',
    // // where sigma' = subsumes* t2 t4 sigma.
    // if (type0 is ArrowType && type1 is ArrowType) {
    //   Substitution sigma0 = subsumes(type0.codomain, type1.codomain, sigma);
    //   List<Datatype> domain0 = sigma0.applyMany(type0.domain);
    //   List<Datatype> domain1 = sigma0.applyMany(type1.domain);
    //   return subsumesMany(domain1, domain0, sigma0);
    // }

    // // subsumes (* ts1*) (* ts2*) sigma = subsumesMany ts1* ts2* sigma
    // if (type0 is TupleType && type1 is TupleType) {
    //   return subsumesMany(type0.components, type1.components, sigma);
    // }

    // // subsumes (C ts1*) (K ts2*) sigma = subsumesMany ts1* ts2* sigma, if C = K.
    // if (type0 is TypeConstructor && type1 is TypeConstructor) {
    //   if (type0.ident != type1.ident) {
    //     Location loc = Location.dummy();
    //     TypeError err = TypeExpectationError(loc);
    //     error(err, loc);
    //     return sigma;
    //   }
    //   return subsumesMany(type0.arguments, type1.arguments, sigma);
    // }

    // // Base case.
    // return unifier.unify(type0, type1);
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
    Substitution sigma = Substitution.empty();
    for (int i = 0; i < quantifiers.length; i++) {
      Quantifier q = quantifiers[i];
      sigma = sigma.bind(TypeVariable.bound(q), Skolem());
    }
    return sigma.apply(type);
  }

  Substitution instantiateLeft(Datatype a, Datatype b, Substitution sigma) {
    if (trace) {
      print("instantiate left: $a <:= $b");
    }
    // TODO refactor.

    // %a <:= %b, if level(%a) <= level(%b).
    if (a is Skolem && b is Skolem) {
      if (a.level <= b.level) {
        if (!a.isSolved) {
          a.sameAs(b);
          return sigma;
        }
      } else {
        // Escape error.
        throw SkolemEscapeError(b.syntheticName);
      }
    }

    // %a <:= bs* -> b, if %a' <:= b sigma', where
    // %a = %as* -> %a'
    // sigma' = bs* <: %as*
    if (a is Skolem && b is ArrowType) {
      List<Datatype> domain = List<Datatype>();
      for (int i = 0; i < b.arity; i++) {
        domain.add(Skolem());
      }
      Datatype codomain = Skolem();
      a.solve(ArrowType(domain, codomain));

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < domain.length; i++) {
        Substitution sigma1 = subsumes(b.domain[i], domain[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }

      return instantiateLeft(codomain, sigma0.apply(b.codomain), sigma0);
    }

    // %a <:= \/qs.b, if %a <:= b
    if (a is Skolem && b is ForallType) {
      return instantiateLeft(a, b.body, sigma);
    }

    // %a <:= (* bs*), if %as* <:= bs*, where
    // %a = (* %as* ), where %as* are fresh.
    if (a is Skolem && b is TupleType) {
      List<Datatype> components = new List<Datatype>();
      for (int i = 0; i < b.components.length; i++) {
        components.add(Skolem());
      }
      a.solve(TupleType(components));

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < components.length; i++) {
        Substitution sigma1 =
            instantiateLeft(components[i], b.components[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }
      return sigma0;
    }

    // %a <:= K bs*, if %as* <:= bs*, where
    // %a = K %as*, where %as* are fresh.
    if (a is Skolem && b is TypeConstructor) {
      List<Datatype> arguments = new List<Datatype>();
      for (int i = 0; i < b.arguments.length; i++) {
        arguments.add(Skolem());
      }
      a.solve(TypeConstructor.from(b.declarator, arguments));

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < arguments.length; i++) {
        Substitution sigma1 =
            instantiateLeft(arguments[i], b.arguments[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }
      return sigma0;
    }

    // %a <:= b, if b is a monotype.
    if (a is Skolem) {
      if (!a.isSolved) {
        a.solve(b);
        return sigma;
      }
    }

    throw "InstantiateLeft error!";
  }

  Substitution instantiateRight(Datatype a, Datatype b, Substitution sigma) {
    if (trace) {
      print("instantiate right: $a <=: $b");
    }
    // TODO refactor.

    // %a <=: %b, if level(%a) <= level(%b)
    if (a is Skolem && b is Skolem) {
      if (a.level <= b.level) {
        // TODO check that a is unsolved.
        if (!b.isSolved) {
          b.sameAs(a);
          return sigma;
        }
      } else {
        throw SkolemEscapeError(b.syntheticName);
      }
    }

    // \/qs.a <=: %b, if a[%bs/qs] <=: %a.
    if (a is ForallType && b is Skolem) {
      Datatype type = guessInstantiation(a.quantifiers, a.body);
      return instantiateRight(type, b, sigma);
    }

    // as* -> a <=: %b, if %a' sigma' <=: %b'
    // %b = %bs* -> %b'
    // sigma' = %bs* <: %as*
    if (a is ArrowType && b is Skolem) {
      List<Datatype> domain = List<Datatype>();
      for (int i = 0; i < a.arity; i++) {
        domain.add(Skolem());
      }
      Datatype codomain = Skolem();
      b.solve(ArrowType(domain, codomain));

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < domain.length; i++) {
        Substitution sigma1 = subsumes(domain[i], a.domain[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }

      return instantiateRight(sigma0.apply(a.codomain), codomain, sigma0);
    }

    // (* as*) <=: %b, if as* <=: %bs*, where
    // %b = (* %bs* ), where %bs* are fresh.
    if (a is TupleType && b is Skolem) {
      List<Datatype> components = new List<Datatype>();
      for (int i = 0; i < a.components.length; i++) {
        components.add(Skolem());
      }
      b.solve(TupleType(components));

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < components.length; i++) {
        Substitution sigma1 =
            instantiateRight(a.components[i], components[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }
      return sigma0;
    }

    // K as* <=: %b, if as* <:= %bs*, where
    // %b = K %bs*, where %bs* are fresh.
    if (a is TypeConstructor && b is Skolem) {
      List<Datatype> arguments = new List<Datatype>();
      for (int i = 0; i < a.arguments.length; i++) {
        arguments.add(Skolem());
      }
      b.solve(TypeConstructor.from(a.declarator, arguments));

      Substitution sigma0 = Substitution.empty();
      for (int i = 0; i < arguments.length; i++) {
        Substitution sigma1 =
            instantiateRight(a.arguments[i], arguments[i], sigma);
        sigma0 = sigma0.combine(sigma1);
      }
      return sigma0;
    }

    // a <=: %b, if a is a monotype.
    if (b is Skolem) {
      if (!b.isSolved) {
        b.solve(a);
        return sigma;
      }
    }

    throw "InstantiateRight error!";
  }
}
