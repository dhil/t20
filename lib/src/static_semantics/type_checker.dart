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
    Datatype type = synthesiseModule(member, initialContext);
    return member;
  }

  Datatype synthesiseModule(ModuleMember member, TypingContext context) {
    switch (member.tag) {
      case ModuleTag.CONSTR:
      case ModuleTag.DATATYPE_DEFS:
      case ModuleTag.OPEN:
        return typeUtils.unitType;
        break;
      case ModuleTag.TOP:
        TopModule module = member as TopModule;
        for (int i = 0; i < module.members.length; i++) {
          synthesiseModule(module.members[i], context);
        }
        return typeUtils.unitType;
        break;
      case ModuleTag.FUNC_DEF:
        return synthesiseFunctionDefinition(
            member as FunctionDeclaration, context);
        break;
      case ModuleTag.VALUE_DEF:
        return synthesiseValueDefinition(member as ValueDeclaration, context);
        break;
      default:
        unhandled("synthesiseModule", member.tag);
    }
    return null;
  }

  Datatype synthesiseFunctionDefinition(
      FunctionDeclaration funDef, TypingContext context) {
    if (funDef is VirtualFunctionDeclaration) return funDef.signature.type;
    Datatype sig = funDef.signature.type;
    if (!typeUtils.isFunctionType(sig)) {
      LocatedError err = TypeExpectationError(funDef.signature.location);
      return error(err, funDef.signature.location);
    }
    // Check the formal parameters.
    List<Datatype> domain = typeUtils.domain(sig);
    List<Pattern> parameters = funDef.parameters;
    if (domain.length != parameters.length) {
      LocatedError err =
          ArityMismatchError(domain.length, parameters.length, funDef.location);
      return error(err, funDef.location);
    }
    for (int i = 0; i < parameters.length; i++) {
      checkPattern(parameters[i], domain[i], context);
    }
    // Check the body type against the declared type.
    checkExpression(funDef.body, typeUtils.codomain(sig), context);

    return sig;
  }

  Datatype synthesiseValueDefinition(
      ValueDeclaration valDef, TypingContext context) {
    Datatype sig = valDef.signature.type;
    // Check the body against the declared type.
    checkExpression(valDef.body, sig, context);
    return valDef.signature.type;
  }

  Datatype synthesiseExpression(Expression exp, TypingContext context) {
    switch (exp.tag) {
      case ExpTag.BOOL:
        return typeUtils.boolType;
        break;
      case ExpTag.INT:
        return typeUtils.intType;
        break;
      case ExpTag.STRING:
        return typeUtils.stringType;
        break;
      case ExpTag.APPLY:
        return synthesiseApply(exp as Apply, context);
        break;
      case ExpTag.IF:
        return synthesiseIf(exp as If, context);
        break;
      case ExpTag.LAMBDA:
        return synthesiseLambda(exp as Lambda, context);
        break;
      case ExpTag.LET:
        return synthesiseLet(exp as Let, context);
        break;
      case ExpTag.MATCH:
        return synthesiseMatch(exp as Match, context);
        break;
      case ExpTag.TUPLE:
        return synthesiseTuple<Expression>(
            (exp as Tuple).components, synthesiseExpression, context);
        break;
      case ExpTag.VAR:
        return (exp as Variable).declarator.type;
        break;
      case ExpTag.TYPE_ASCRIPTION:
        break;
      default:
        unhandled("synthesiseExpression", exp.tag);
    }
  }

  Datatype synthesiseApply(Apply apply, TypingContext context) {
    // Synthesise a type for the abstractor expression (left hand side).
    Datatype fnType = synthesiseExpression(apply.abstractor, context);
    // Synthesise a type each argument expression.
    List<Datatype> argumentTypes = new List<Datatype>(apply.arguments.length);
    for (int i = 0; i < apply.arguments.length; i++) {
      argumentTypes[i] = synthesiseExpression(apply.arguments[i], context);
    }
    // Check that [fnType] is a function type, otherwise signal an error.
    if (!typeUtils.isFunctionType(fnType)) {
      LocatedError err = TypeExpectationError(apply.abstractor.location);
      return error(err, apply.location);
    }
    // Check that the domain of [fnType] agrees with [argumentTypes].
    Map<int, Datatype> subst =
        unifyMany(typeUtils.domain(fnType), argumentTypes);
    // Check whether the function type needs to be instantiated.
    if (typeUtils.isForallType(fnType)) {
      // Instantiate [fnType].
      // TODO instantiation mismatch error.
      fnType = substitute(fnType, subst);
    }

    return typeUtils.codomain(fnType);
  }

  Datatype synthesiseMatch(Match match, TypingContext context) {
    // Synthesise a type for the scrutinee.
    Datatype scrutineeType = synthesiseExpression(match.scrutinee, context);
    // Check the patterns (left hand sides) against the synthesised type for the
    // scrutinee. Check the clause bodies (right hand sides) against the type of
    // their left hand sides.
    Datatype branchType = Skolem();
    for (int i = 0; i < match.cases.length; i++) {
      Case case0 = match.cases[i];
      checkPattern(case0.pattern, scrutineeType, context);
      branchType = checkExpression(case0.expression, branchType, context);
    }

    return branchType;
  }

  Datatype synthesiseLet(Let let, TypingContext context) {
    // Synthesise a type for each of the value bindings.
    for (int i = 0; i < let.valueBindings.length; i++) {
      Binding binding = let.valueBindings[i];
      // Synthesise a type for the expression (right hand side)
      Datatype expType = synthesiseExpression(binding.expression, context);
      // Check the pattern (left hand side) against the synthesised type.
      checkPattern(binding.pattern, expType, context);
      // TODO: Check whether there are any free type/skolem variables in
      // [expType] as the type theory does not admit let generalisation.
    }
    // Synthesise a type for the continuation (body).
    Datatype bodyType = synthesiseExpression(let, context);
    return bodyType;
  }

  Datatype synthesiseLambda(Lambda lambda, TypingContext context) {
    // Synthesise types for the parameters.
    List<Datatype> domain = new List<Datatype>(lambda.parameters.length);
    for (int i = 0; i < lambda.parameters.length; i++) {
      domain[i] = synthesisePattern(lambda.parameters[i], context);
    }
    // Synthesise a type for the body.
    Datatype codomain = synthesiseExpression(lambda.body, context);

    // Construct the arrow type.
    ArrowType ft = ArrowType(domain, codomain);

    return ft;
  }

  Datatype synthesiseIf(If ifthenelse, TypingContext context) {
    // Check that the condition has type bool.
    checkExpression(ifthenelse.condition, typeUtils.boolType, context);
    // Synthesise a type for each branch.
    Datatype tt = synthesiseExpression(ifthenelse.thenBranch, context);
    Datatype ff = synthesiseExpression(ifthenelse.elseBranch, context);
    // Check that types agree.
    Datatype branchType = unify(tt, ff);
    return branchType;
  }

  Datatype synthesiseTuple<T>(List<T> components,
      Datatype Function(T, TypingContext) synthesise, TypingContext context) {
    // If there are no subexpression, then return the canonical unit type.
    if (components.length == 0) return typeUtils.unitType;
    // Synthesise a type for each subexpression.
    List<Datatype> componentTypes = new List<Datatype>(components.length);
    for (int i = 0; i < components.length; i++) {
      componentTypes[i] = synthesise(components[i], context);
    }
    return TupleType(componentTypes);
  }

  Datatype checkExpression(
      Expression exp, Datatype type, TypingContext context) {
    // Synthesise a type for [exp].
    Datatype expType = synthesiseExpression(exp, context);
    // Unify [expType] and [type].
    Datatype resultType = unify(expType, type);
    // TODO handle unification errors.
    return resultType;
  }

  Datatype checkPattern(Pattern pat, Datatype type, TypingContext context) {
    // Synthesise a type for [pat].
    Datatype patType = synthesisePattern(pat, context);
    // Unify [patType] and [type].
    Datatype resultType = unify(patType, type);
    // TODO handle unification errors.
    return resultType;
  }

  Datatype synthesisePattern(Pattern pat, TypingContext context) {
    switch (pat.tag) {
      case PatternTag.BOOL:
        return typeUtils.boolType;
        break;
      case PatternTag.INT:
        return typeUtils.intType;
        break;
      case PatternTag.STRING:
        return typeUtils.stringType;
        break;
      case PatternTag.CONSTR:
        return synthesiseConstructorPattern(pat as ConstructorPattern, context);
        break;
      case PatternTag.HAS_TYPE:
        // Check the pattern type against the annotation.
        HasTypePattern hasType = pat as HasTypePattern;
        return checkPattern(hasType.pattern, hasType.type, context);
        break;
      case PatternTag.TUPLE:
        return synthesiseTuple<Pattern>(
            (pat as TuplePattern).components, synthesisePattern, context);
        break;
      case PatternTag.VAR:
      case PatternTag.WILDCARD:
        return Skolem();
        break;
      default:
        unhandled("synthesisePattern", pat.tag);
    }
  }

  Datatype synthesiseConstructorPattern(
      ConstructorPattern constr, TypingContext context) {
    // Get the induced type.
    Datatype type = constr
        .type; // guaranteed to be compatible with `type_utils' function type api.
    // Arity check.
    List<Datatype> domain = typeUtils.domain(type);
    if (domain.length != constr.components.length) {
      LocatedError err = ArityMismatchError(
          domain.length, constr.components.length, constr.location);
      return error(err, constr.location);
    }
    // Synthesise a type for each subpattern and check it against the induced type.
    Map<int, Datatype> subst = new Map<int, Datatype>();
    for (int i = 0; i < constr.components.length; i++) {
      Datatype componentType = synthesisePattern(constr.components[i], context);
      subst.addAll(unifyS(componentType, domain[i]));
    }
    // Instantiate the type.
    type = substitute(type, subst);
    return type;
  }
}
