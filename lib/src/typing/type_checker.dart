// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../fp.dart' show Pair, Triple;
import '../location.dart';
import '../result.dart';

import 'ordered_context.dart';
import 'substitution.dart' show Substitution;
import 'type_utils.dart' as typeUtils;

class TypeChecker {
  final bool _trace;
  TypeChecker([this._trace = false]);

  Result<ModuleMember, TypeError> typeCheck(ModuleMember module) {
    _TypeChecker typeChecker = _TypeChecker(_trace);
    typeChecker.typeCheck(module);
    Result<ModuleMember, TypeError> result;
    if (typeChecker.errors.length > 0) {
      result = Result<ModuleMember, TypeError>.failure(typeChecker.errors);
    } else {
      result = Result<ModuleMember, TypeError>.success(module);
    }

    return result;
  }
}

class InferenceResult {
  OrderedContext context;
  Datatype type;

  InferenceResult(this.context, this.type);
}

class PatternInferenceResult extends InferenceResult {
  ScopedEntry marker;
  PatternInferenceResult(OrderedContext context, Datatype type, this.marker)
      : super(context, type);
}

class PatternManyInferenceResult extends PatternInferenceResult {
  List<Datatype> types;
  PatternManyInferenceResult(
      OrderedContext context, this.types, ScopedEntry marker)
      : super(context, null, marker);
}

class CheckPatternResult {
  OrderedContext context;
  ScopedEntry marker;
  CheckPatternResult(this.context, this.marker);
}

class _TypeChecker {
  List<TypeError> errors = new List<TypeError>();
  final bool trace;

  _TypeChecker(this.trace);

  Datatype error(TypeError err, Location location) {
    errors.add(err);
    return ErrorType(err, location);
  }

  // Main entry point.
  ModuleMember typeCheck(ModuleMember member) {
    InferenceResult result = inferModule(member, OrderedContext.empty());
    // TODO use result.
    result;
    return member;
  }

  OrderedContext checkMain(FunctionDeclaration main, OrderedContext ctxt) {
    // Placeholder main type.
    Datatype mainType =
        ArrowType(<Datatype>[typeUtils.unitType], typeUtils.unitType);
    return subsumes(main.type, mainType, ctxt);
  }

  InferenceResult inferModule(ModuleMember member, OrderedContext ctxt) {
    if (trace) {
      print("infer module: $member");
    }
    switch (member.tag) {
      case ModuleTag.CONSTR:
      case ModuleTag.DATATYPE_DEFS:
      case ModuleTag.OPEN:
        return InferenceResult(ctxt, typeUtils.unitType);
        break;
      case ModuleTag.TOP:
        TopModule module = member as TopModule;
        for (int i = 0; i < module.members.length; i++) {
          InferenceResult result = inferModule(module.members[i], ctxt);
          ctxt = result.context;
        }
        // Type check the main function, if one is present.
        if (module.hasMain) {
          ctxt = checkMain(module.main, ctxt);
        }
        return InferenceResult(ctxt, typeUtils.unitType);
        break;
      case ModuleTag.FUNC_DEF:
        return inferFunctionDefinition(member as FunctionDeclaration, ctxt);
        break;
      case ModuleTag.VALUE_DEF:
        return inferValueDefinition(member as ValueDeclaration, ctxt);
        break;
      default:
        unhandled("inferModule", member.tag);
    }

    return null; // Impossible!
  }

  InferenceResult inferFunctionDefinition(
      FunctionDeclaration funDef, OrderedContext ctxt) {
    if (funDef is VirtualFunctionDeclaration) {
      return InferenceResult(ctxt, funDef.signature.type);
    }
    Datatype sig = funDef.signature.type;
    if (!typeUtils.isFunctionType(sig)) {
      TypeError err = TypeExpectationError(funDef.signature.location);
      return InferenceResult(ctxt, error(err, funDef.signature.location));
    }
    // Check the formal parameters.
    List<Datatype> domain = typeUtils.domain(sig);
    List<Pattern> parameters = funDef.parameters;
    if (domain.length != parameters.length) {
      TypeError err =
          ArityMismatchError(domain.length, parameters.length, funDef.location);
      return InferenceResult(ctxt, error(err, funDef.location));
    }

    CheckPatternResult result = checkManyPatterns(parameters, domain, ctxt);
    ScopedEntry marker = result.marker;
    ctxt = result.context;

    // Check the body type against the declared type.
    ctxt = checkExpression(funDef.body, typeUtils.codomain(sig), ctxt);

    // Drop [scope].
    if (marker != null) {
      ctxt = ctxt.drop(marker);
    }

    // Ascription ascription = Ascription(funDef, sig);
    // ctxt.insertLast(ascription);
    return InferenceResult(ctxt, sig);
  }

  InferenceResult inferValueDefinition(
      ValueDeclaration valDef, OrderedContext ctxt) {
    Datatype sig = valDef.signature.type;
    // Check the body against the declared type.
    ctxt = checkExpression(valDef.body, sig, ctxt);

    // Ascription ascription = Ascription(valDef, sig);
    // ctxt.insertLast(ascription);
    return InferenceResult(ctxt, sig);
  }

  InferenceResult inferExpression(Expression exp, OrderedContext ctxt) {
    if (trace) {
      print("infer expression: $exp");
    }
    switch (exp.tag) {
      case ExpTag.BOOL:
        return InferenceResult(ctxt, typeUtils.boolType);
        break;
      case ExpTag.INT:
        return InferenceResult(ctxt, typeUtils.intType);
        break;
      case ExpTag.STRING:
        return InferenceResult(ctxt, typeUtils.stringType);
        break;
      case ExpTag.APPLY:
        return inferApply(exp as Apply, ctxt);
        break;
      case ExpTag.IF:
        return inferIf(exp as If, ctxt);
        break;
      case ExpTag.LAMBDA:
        return inferLambda(exp as Lambda, ctxt);
        break;
      case ExpTag.LET:
        return inferLet(exp as Let, ctxt);
        break;
      case ExpTag.MATCH:
        return inferMatch(exp as Match, ctxt);
        break;
      case ExpTag.TUPLE:
        return inferTuple((exp as Tuple), ctxt);
        break;
      case ExpTag.VAR:
        Datatype type = (exp as Variable).declarator.type;
        return InferenceResult(ctxt, type);
        // Variable v = exp as Variable;
        // ScopedEntry entry = ctxt.lookup(v.ident);
        // if (entry is Ascription) {
        //   return entry.type;
        // } else {
        //   // ERROR.
        //   print("$ctxt");
        //   throw "Variable $v is not in scope!";
        // }
        break;
      case ExpTag.TYPE_ASCRIPTION:
        throw "Not yet impleemented.";
        break;
      default:
        unhandled("inferExpression", exp.tag);
    }

    return null; // Impossible!
  }

  InferenceResult inferApply(Apply appl, OrderedContext ctxt) {
    // Infer a type for the abstractor.
    InferenceResult result = inferExpression(appl.abstractor, ctxt);
    ctxt = result.context;
    // Eliminate foralls.
    return apply(appl.arguments, ctxt.apply(result.type), ctxt, appl.location);
  }

  InferenceResult apply(List<Expression> arguments, Datatype type,
      OrderedContext ctxt, Location location) {
    if (trace) {
      print("apply: $arguments, $type");
    }
    // apply xs* (\/qs+.t) ctxt = apply xs* (t[qs+ -> as+]) ctxt
    if (type is ForallType) {
      Triple<Existential, OrderedContext, Datatype> result =
          guessInstantiation(type.quantifiers, type.body, ctxt);
      ctxt = result.snd;
      Datatype body = result.thd;
      return apply(arguments, body, ctxt, location);
    }

    // apply xs* (ts* -> t) ctxt = (ctxt', t ctxt'), where ctxt' = check* xs* ts* ctxt
    if (type is ArrowType) {
      ArrowType fnType = type;
      if (fnType.arity != arguments.length) {
        TypeError err =
            ArityMismatchError(fnType.arity, arguments.length, location);
        errors.add(err);
        return InferenceResult(ctxt, type.codomain);
      }
      ctxt = checkMany<Expression>(
          checkExpression, arguments, fnType.domain, ctxt);
      return InferenceResult(ctxt, fnType.codomain);
    }

    if (type is Skolem) {
      Skolem a = type;
      // Construct a function type whose immediate constituents are skolem
      // variables.
      Existential fnEx = ctxt.lookup(a.ident) as Existential;

      Skolem codomain = Skolem();
      Existential codomainEx = Existential(codomain);
      ctxt = ctxt.insertBefore(codomainEx, fnEx);

      List<Datatype> domain = new List<Datatype>();
      for (int i = 0; i < arguments.length; i++) {
        Skolem skolem = Skolem();
        domain.add(skolem);

        Existential ex = Existential(skolem);
        ctxt = ctxt.insertBefore(ex, fnEx);
      }

      ArrowType fnType = ArrowType(domain, codomain);
      // Solve a = (a0,...,aN-1) -> aN.
      fnEx.solve(fnType);

      // Check each argument.
      for (int i = 0; i < domain.length; i++) {
        ctxt = checkExpression(arguments[i], domain[i], ctxt);
      }

      return InferenceResult(ctxt, codomain);
    }

    // ERROR.
    unhandled("apply", "$arguments, $type");
    return null;
  }

  InferenceResult inferMatch(Match match, OrderedContext ctxt) {
    // Infer a type for the scrutinee.
    InferenceResult result = inferExpression(match.scrutinee, ctxt);
    ctxt = result.context;
    Datatype scrutineeType = result.type;
    // Check the patterns (left hand sides) against the inferd type for the
    // scrutinee. Check the clause bodies (right hand sides) against the type of
    // their left hand sides.
    if (match.cases.length == 0) {
      Skolem skolem = Skolem();
      Existential ex = Existential(skolem);
      ctxt = ctxt.insertLast(ex);
      return InferenceResult(ctxt, skolem);
    } else {
      Datatype branchType;
      for (int i = 0; i < match.cases.length; i++) {
        Case case0 = match.cases[i];
        CheckPatternResult result =
            checkPattern(case0.pattern, scrutineeType, ctxt);
        ScopedEntry entry = result.marker;
        ctxt = result.context;
        if (branchType == null) {
          // First case.
          InferenceResult result = inferExpression(case0.expression, ctxt);
          ctxt = result.context;
          branchType = result.type;
        } else {
          // Any subsequent case.
          InferenceResult result = inferExpression(case0.expression, ctxt);
          ctxt = result.context;
          Datatype otherBranchType = result.type;
          // Check that [otherBranchType] <: [branchType].
          ctxt = subsumes(otherBranchType, branchType, ctxt);
        }
        // Drop the scope.
        if (entry != null) {
          ctxt = ctxt.drop(entry);
        }
      }
      return InferenceResult(ctxt, branchType);
    }
  }

  InferenceResult inferLet(Let let, OrderedContext ctxt) {
    // Infer a type for each of the value bindings.
    for (int i = 0; i < let.valueBindings.length; i++) {
      Binding binding = let.valueBindings[i];
      // Infer a type for the expression (right hand side)
      InferenceResult result0 = inferExpression(binding.expression, ctxt);
      ctxt = result0.context;
      Datatype expType = result0.type;
      // Check the pattern (left hand side) against the inferd type.
      CheckPatternResult result1 = checkPattern(binding.pattern, expType, ctxt);
      ctxt = result1.context;
    }
    // Infer a type for the continuation (body).
    return inferExpression(let.body, ctxt);
    // TODO drop the scope?
  }

  InferenceResult inferLambda(Lambda lambda, OrderedContext ctxt) {
    // Infer types for the parameters.
    PatternManyInferenceResult result =
        inferManyPatterns(lambda.parameters, ctxt);
    ScopedEntry scopeMarker = result.marker;
    ctxt = result.context;
    List<Datatype> domain = result.types;

    // Check the body against the existential.
    Skolem codomain = Skolem();
    Existential codomainEx = Existential(codomain);
    if (scopeMarker != null) {
      ctxt = ctxt.insertBefore(codomainEx, scopeMarker);
    } else {
      ctxt = ctxt.insertLast(codomainEx);
    }
    ctxt = checkExpression(lambda.body, codomain, ctxt);

    // Drop the scope.
    if (scopeMarker != null) {
      ctxt = ctxt.drop(scopeMarker);
    }

    // Construct the arrow type.
    ArrowType ft = ArrowType(domain, codomain);
    return InferenceResult(ctxt, ft);
  }

  InferenceResult inferIf(If ifthenelse, OrderedContext ctxt) {
    // Check that the condition has type bool.
    ctxt = checkExpression(ifthenelse.condition, typeUtils.boolType, ctxt);
    // Infer a type for each branch.
    InferenceResult trueBranchResult =
        inferExpression(ifthenelse.thenBranch, ctxt);
    Datatype tt = trueBranchResult.context.apply(trueBranchResult.type);

    InferenceResult falseBranchResult =
        inferExpression(ifthenelse.elseBranch, ctxt);
    Datatype ff = falseBranchResult.context.apply(falseBranchResult.type);

    // Check that types agree.
    ctxt = subsumes(tt, ff, ctxt);

    return InferenceResult(ctxt, tt);
  }

  InferenceResult inferTuple(Tuple tuple, OrderedContext ctxt) {
    List<Expression> components = tuple.components;
    // If there are no subexpression, then return the canonical unit type.
    if (components.length == 0) {
      return InferenceResult(ctxt, typeUtils.unitType);
    }
    // Infer a type for each subexpression.
    List<Datatype> componentTypes = new List<Datatype>(components.length);
    for (int i = 0; i < components.length; i++) {
      InferenceResult result = inferExpression(components[i], ctxt);
      ctxt = result.context;
      componentTypes[i] = result.type;
    }
    return InferenceResult(ctxt, TupleType(componentTypes));
  }

  OrderedContext checkMany<T>(
      OrderedContext Function(T, Datatype, OrderedContext) check,
      List<T> xs,
      List<Datatype> types,
      OrderedContext ctxt) {
    if (xs.length != types.length) {
      Location loc = Location.dummy();
      TypeError err = ArityMismatchError(types.length, xs.length, loc);
      error(err, loc);
      return ctxt;
    }

    for (int i = 0; i < types.length; i++) {
      ctxt = check(xs[i], types[i], ctxt);
    }

    return ctxt;
  }

  OrderedContext checkExpression(
      Expression exp, Datatype type, OrderedContext ctxt) {
    if (trace) {
      print("check expression: $exp : $type");
    }
    // check (\xs*. e) (ts* -> t) ctxt = check e t ctxt',
    // where ctxt' = check*(xs*, ts*)
    //       check* [] [] _ = []
    //       check* (x :: xs) (t :: ts) ctxt = (check x t ctxt) ++ (check* xs ts ctxt)

    if (type is ArrowType) {
      if (exp is Lambda) {
        // TODO arity check.
        Lambda lambda = exp;
        ArrowType fnType = type;
        CheckPatternResult result =
            checkManyPatterns(lambda.parameters, fnType.domain, ctxt);
        ScopedEntry scopeMarker = result.marker;
        ctxt = result.context;
        ctxt = checkExpression(lambda.body, fnType.codomain, ctxt);
        if (scopeMarker != null) {
          ctxt = ctxt.drop(scopeMarker);
        }
        lambda.type = ctxt.apply(type);
        return ctxt;
      }
    }

    // check e (\/qs+.t) ctxt = check e (t[qs+ -> %sa+]) ctxt.
    if (type is ForallType) {
      ForallType forallType = type;
      QuantifiedVariable scopeMarker;
      for (int i = 0; i < forallType.quantifiers.length; i++) {
        Quantifier q = forallType.quantifiers[i];
        QuantifiedVariable q0 = QuantifiedVariable(q);
        scopeMarker ??= q0;
        ctxt = ctxt.insertLast(q0);
      }
      ctxt = checkExpression(exp, forallType.body, ctxt);
      if (scopeMarker != null) {
        ctxt = ctxt.drop(scopeMarker);
      }
      return ctxt;
    }

    if (type is BoolType && exp is BoolLit ||
        type is IntType && exp is IntLit ||
        type is StringType && exp is StringLit) {
      return ctxt;
    }

    // check e t ctxt = subsumes e t' ctxt', where (t', ctxt') = infer e ctxt
    InferenceResult result = inferExpression(exp, ctxt);
    ctxt = result.context;
    Datatype left = result.type;
    ctxt = subsumes(ctxt.apply(left), ctxt.apply(type), ctxt);

    exp.type = ctxt.apply(type);
    return ctxt;
  }

  CheckPatternResult checkManyPatterns(
      List<Pattern> patterns, List<Datatype> types, OrderedContext ctxt) {
    ScopedEntry marker;
    for (int i = 0; i < patterns.length; i++) {
      CheckPatternResult result = checkPattern(patterns[i], types[i], ctxt);
      marker ??= result.marker;
      ctxt = result.context;
    }
    return CheckPatternResult(ctxt, marker);
  }

  CheckPatternResult checkPattern(
      Pattern pat, Datatype type, OrderedContext ctxt) {
    if (trace) {
      print("check pattern: $pat : $type");
    }

    // Literal pattern check against their respective base types.
    if (pat is BoolPattern && type is BoolType ||
        pat is IntPattern && type is IntType ||
        pat is StringPattern && type is StringType) {
      return CheckPatternResult(ctxt, null);
    }

    // check x t ctxt = ctxt.
    if (pat is VariablePattern) {
      VariablePattern v = pat;
      v.type = ctxt.apply(type);
      // Ascription ascription = Ascription(pat, type);
      // ctxt.insertLast(ascription);
      return CheckPatternResult(ctxt, null);
    }

    // check (, ps*) (, ts*) ctxt = check* ps* ts* ctxt
    if (pat is TuplePattern && type is TupleType) {
      if (pat.components.length != type.components.length) {
        TypeError err = CheckTuplePatternError(type.toString(), pat.location);
        errors.add(err);
        return CheckPatternResult(ctxt, null);
      }

      if (pat.components.length == 0) {
        return CheckPatternResult(ctxt, null);
      }

      CheckPatternResult result =
          checkManyPatterns(pat.components, type.components, ctxt);
      // Store the type.
      pat.type = result.context.apply(type);

      return result;
    }

    // Infer a type for [pat].
    PatternInferenceResult result = inferPattern(pat, ctxt);
    ctxt = result.context;

    try {
      ctxt = subsumes(result.type, type, ctxt);
    } on TypeError catch (e) {
      errors.add(e);
    }
    return CheckPatternResult(ctxt, result.marker);
  }

  PatternInferenceResult inferPattern(Pattern pat, OrderedContext ctxt) {
    switch (pat.tag) {
      case PatternTag.BOOL:
        return PatternInferenceResult(ctxt, typeUtils.boolType, null);
        break;
      case PatternTag.INT:
        return PatternInferenceResult(ctxt, typeUtils.intType, null);
        break;
      case PatternTag.STRING:
        return PatternInferenceResult(ctxt, typeUtils.stringType, null);
        break;
      case PatternTag.CONSTR:
        return inferConstructorPattern(pat as ConstructorPattern, ctxt);
        break;
      case PatternTag.HAS_TYPE:
        // Check the pattern type against the annotation.
        HasTypePattern hasType = pat as HasTypePattern;
        CheckPatternResult result =
            checkPattern(hasType.pattern, hasType.type, ctxt);
        return PatternInferenceResult(
            result.context, hasType.type, result.marker);
        break;
      case PatternTag.TUPLE:
        return inferTuplePattern((pat as TuplePattern), ctxt);
        break;
      case PatternTag.VAR:
        VariablePattern varPattern = pat as VariablePattern;
        Datatype type = Skolem();
        varPattern.type = type;
        Existential ex = Existential(type);
        ctxt = ctxt.insertLast(ex);
        // Ascription ascription = Ascription(varPattern, type);
        // ctxt.insertLast(ascription);
        return PatternInferenceResult(ctxt, type, ex);
        break;
      case PatternTag.WILDCARD:
        Skolem skolem = Skolem();
        Existential ex = Existential(skolem);
        ctxt = ctxt.insertLast(ex);
        return PatternInferenceResult(ctxt, skolem, ex);
        break;
      default:
        unhandled("inferPattern", pat.tag);
    }

    return null; // Impossible!
  }

  PatternManyInferenceResult inferManyPatterns(
      List<Pattern> patterns, OrderedContext ctxt) {
    ScopedEntry scopeMarker;
    List<Datatype> types = new List<Datatype>();
    for (int i = 0; i < patterns.length; i++) {
      PatternInferenceResult result = inferPattern(patterns[i], ctxt);
      scopeMarker ??= result.marker;
      ctxt = result.context;
      types.add(result.type);
    }

    return PatternManyInferenceResult(ctxt, types, scopeMarker);
  }

  PatternInferenceResult inferTuplePattern(
      TuplePattern tuplePattern, OrderedContext ctxt) {
    List<TuplePattern> components = tuplePattern.components;
    // Infer a type for each subpattern.
    PatternManyInferenceResult result = inferManyPatterns(components, ctxt);
    return PatternInferenceResult(
        result.context, TupleType(result.types), result.marker);
  }

  PatternInferenceResult inferConstructorPattern(
      ConstructorPattern constr, OrderedContext ctxt) {
    // Get the induced type.
    Datatype type = constr
        .type; // guaranteed to be compatible with `type_utils' function type api.
    // Arity check.
    if (typeUtils.arity(type) != constr.arity) {
      TypeError err = ArityMismatchError(
          typeUtils.arity(type), constr.arity, constr.location);
      return PatternInferenceResult(ctxt, error(err, constr.location), null);
    }
    // Check whether the induced type has any type parameters.
    ScopedEntry marker;
    if (type is ForallType) {
      ForallType forallType = type;
      Triple<Existential, OrderedContext, Datatype> result =
          guessInstantiation(forallType.quantifiers, forallType.body, ctxt);
      marker = result.fst;
      ctxt = result.snd;
      type = result.thd;
    }
    // Check each subpattern.
    if (constr.arity > 0) {
      List<Datatype> domain = typeUtils.domain(type);
      for (int i = 0; i < constr.components.length; i++) {
        Pattern component = constr.components[i];
        if (!(component is VariablePattern || component is WildcardPattern)) {
          throw "Deep pattern matching is not supported.";
        }
        CheckPatternResult result = checkPattern(component, domain[i], ctxt);
        ctxt = result.context;
      }
    }

    return PatternInferenceResult(ctxt, typeUtils.codomain(type), marker);
  }

  // Implements the subsumption/subtyping relation <:.
  OrderedContext subsumes(Datatype lhs, Datatype rhs, OrderedContext ctxt) {
    if (trace) {
      print("subsumes: $lhs <: $rhs");
      print("$ctxt");
    }

    if (lhs is Skolem) {
      if (ctxt.lookup(lhs.ident) == null) {
        throw "$lhs is not in scope!";
      }
    }

    if (rhs is Skolem) {
      if (ctxt.lookup(rhs.ident) == null) {
        throw "$rhs is not in scope!";
      }
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
        return ctxt;
      }
    }

    // a <: b, if a = b.
    if (a is TypeVariable && b is TypeVariable) {
      if (a.ident == b.ident) {
        return ctxt;
      }
    }

    // Base types subsumes themselves.
    if (a is BoolType && b is BoolType ||
        a is IntType && b is IntType ||
        a is StringType && b is StringType) {
      return ctxt;
    }

    // as* -> a <: bs* -> b, if a ctxt' <: b ctxt', where ctxt' = bs* <:* as*
    if (a is ArrowType && b is ArrowType) {
      if (a.arity != b.arity) {
        throw ConstructorMismatchError(a.toString(), b.toString());
      }

      for (int i = 0; i < a.domain.length; i++) {
        ctxt = subsumes(b.domain[i], a.domain[i], ctxt);
      }

      return subsumes(ctxt.apply(a.codomain), ctxt.apply(b.codomain), ctxt);
    }

    // (* as*) <: (* bs*), if as* <: bs*.
    if (a is TupleType && b is TupleType) {
      if (a.arity != b.arity) {
        throw ConstructorMismatchError(a.toString(), b.toString());
      }

      if (a.arity == 0) return ctxt;

      for (int i = 0; i < a.components.length; i++) {
        ctxt = subsumes(a.components[i], b.components[i], ctxt);
      }
      return ctxt;
    }

    // C as* <: K bs*, if C = K and as* <: bs*
    if (a is TypeConstructor && b is TypeConstructor) {
      if (a.ident != b.ident || a.arguments.length != b.arguments.length) {
        throw ConstructorMismatchError(a.toString(), b.toString());
      }

      if (a.arguments.length == 0) return ctxt;

      for (int i = 0; i < a.arguments.length; i++) {
        ctxt = subsumes(a.arguments[i], b.arguments[i], ctxt);
      }
      return ctxt;
    }

    // \/qs.A <: B, if A[%as/qs] <: B
    if (a is ForallType) {
      Triple<Existential, OrderedContext, Datatype> result =
          guessInstantiation(a.quantifiers, a.body, ctxt);
      Existential first = result.fst;
      ctxt = result.snd;
      Datatype type = result.thd;

      Marker marker = Marker(first.skolem);
      ctxt = ctxt.insertBefore(marker, first);

      ctxt = subsumes(type, b, ctxt);

      // Drop [marker].
      if (marker != null) {
        ctxt = ctxt.drop(marker);
      }
      return ctxt;
    }

    // a <: \/qs.b, if a <: b
    if (b is ForallType) {
      QuantifiedVariable scopeMarker;
      // Bring the quantifiers into scope.
      for (int i = 0; i < b.quantifiers.length; i++) {
        Quantifier q = b.quantifiers[i];
        QuantifiedVariable q0 = QuantifiedVariable(q);
        ctxt.insertLast(q0);
        scopeMarker ??= q0;
      }

      ctxt = subsumes(a, b.body, ctxt);

      // Drop [scopeMarker].
      if (scopeMarker != null) {
        ctxt = ctxt.drop(scopeMarker);
      }
      return ctxt;
    }

    // %a <: b, if %a \notin FTV(b) and %a <:= b
    if (a is Skolem && !a.isSolved) {
      if (!typeUtils.freeTypeVariables(b).contains(a.ident)) {
        return instantiateLeft(a, b, ctxt);
      } else {
        throw OccursError(a.syntheticName, b.toString());
      }
    }

    // a <: %b, if %b \notin FTV(a) and a <:= %b
    if (b is Skolem && !b.isSolved) {
      if (!typeUtils.freeTypeVariables(a).contains(b.ident)) {
        return instantiateRight(a, b, ctxt);
      } else {
        throw OccursError(b.syntheticName, a.toString());
      }
    }

    unhandled("subsumes", "$a <: $b");
    return null;
  }

  // OrderedContext subsumesMany(
  //     List<Datatype> types1, List<Datatype> types2, OrderedContext ctxt) {
  //   if (types1.length != types2.length) {
  //     // TODO error.
  //     return ctxt;
  //   }

  //   OrderedContext ctxt0 = OrderedContext.empty();
  //   for (int i = 0; i < types1.length; i++) {
  //     OrderedContext ctxt1 = subsumes(types1[i], types2[i], ctxt);
  //     ctxt0 = ctxt0.combine(ctxt1);
  //   }
  //   return ctxt0;
  // }

  Triple<Existential, OrderedContext, Datatype> guessInstantiation(
      List<Quantifier> quantifiers, Datatype type, OrderedContext ctxt) {
    Existential scopeMarker;
    Substitution sigma = Substitution.empty();
    for (int i = 0; i < quantifiers.length; i++) {
      Quantifier q = quantifiers[i];
      Skolem skolem = Skolem();
      sigma = sigma.bind(TypeVariable.bound(q), skolem);
      Existential ex = Existential(skolem);
      ctxt = ctxt.insertLast(ex);
      scopeMarker ??= ex;
    }
    return Triple<Existential, OrderedContext, Datatype>(
        scopeMarker, ctxt, sigma.apply(type));
  }

  OrderedContext instantiateLeft(Skolem a, Datatype b, OrderedContext ctxt) {
    if (trace) {
      print("instantiate left: $a <:= $b");
    }
    Existential exA = ctxt.lookup(a.ident);
    if (exA == null) {
      throw "$a is unbound!";
    }

    if (exA.isSolved) {
      throw "$a has already been solved!";
    }

    // TODO refactor.

    // %a <:= b, if b is a monotype.
    OrderedContext ctxt0 = ctxt.drop(exA);
    if (typeUtils.isMonoType(b, ctxt0)) {
      ctxt = ctxt.update(exA.solve(b));
      return ctxt;
    }

    // %a <:= %b, if level(%a) <= level(%b).
    if (b is Skolem) {
      Existential exB = ctxt.lookupAfter(b.ident, exA) as Existential;
      if (exB == null) {
        print("$ctxt");
        throw SkolemEscapeError(b.syntheticName);
      }

      if (exB.isSolved) {
        throw "$b has already been solved [$exB]!";
      }

      exB.equate(exA);
      // ctxt = ctxt.update(exB.solve(a));
      return ctxt;
    }

    // %a <:= bs* -> b, if %a' <:= b ctxt', where
    // %a = %as* -> %a'
    // ctxt' = bs* <: %as*
    if (b is ArrowType) {
      Skolem codomain = Skolem();
      Existential codomainEx = Existential(codomain);
      ctxt = ctxt.insertBefore(codomainEx, exA);

      List<Skolem> domain = List<Skolem>();
      for (int i = 0; i < b.arity; i++) {
        Skolem skolem = Skolem();
        domain.add(skolem);
        Existential ex = Existential(skolem);
        ctxt = ctxt.insertBefore(ex, exA);
      }

      ctxt = ctxt.update(exA.solve(ArrowType(domain, codomain)));

      for (int i = 0; i < domain.length; i++) {
        ctxt = instantiateRight(b.domain[i], domain[i], ctxt);
      }

      ctxt = instantiateLeft(codomain, ctxt.apply(b.codomain), ctxt);
      return ctxt;
    }

    // %a <:= \/qs.b, if %a <:= b
    if (b is ForallType) {
      QuantifiedVariable scopeMarker;
      for (int i = 0; i < b.quantifiers.length; i++) {
        Quantifier q = b.quantifiers[i];
        QuantifiedVariable q0 = QuantifiedVariable(q);
        ctxt = ctxt.insertLast(q0);
        scopeMarker ??= q0;
      }
      ctxt = instantiateLeft(a, b.body, ctxt);
      // Exit the scope.
      if (scopeMarker != null) {
        ctxt = ctxt.drop(scopeMarker);
      }
      return ctxt;
    }

    // %a <:= (* bs*), if %as* <:= bs*, where
    // %a = (* %as* ), where %as* are fresh.
    if (a is Skolem && b is TupleType) {
      List<Skolem> components = new List<Skolem>();
      for (int i = 0; i < b.components.length; i++) {
        Skolem skolem = Skolem();
        components.add(skolem);
        Existential ex = Existential(skolem);
        ctxt = ctxt.insertBefore(ex, exA);
      }
      ctxt = ctxt.update(exA.solve(TupleType(components)));

      for (int i = 0; i < components.length; i++) {
        ctxt = instantiateLeft(components[i], b.components[i], ctxt);
      }
      return ctxt;
    }

    // %a <:= K bs*, if %as* <:= bs*, where
    // %a = K %as*, where %as* are fresh.
    if (b is TypeConstructor) {
      List<Skolem> arguments = new List<Skolem>();
      for (int i = 0; i < b.arguments.length; i++) {
        Skolem skolem = Skolem();
        arguments.add(skolem);
        Existential ex = Existential(skolem);
        ctxt = ctxt.insertBefore(ex, exA);
      }
      ctxt =
          ctxt.update(exA.solve(TypeConstructor.from(b.declarator, arguments)));

      for (int i = 0; i < arguments.length; i++) {
        ctxt = instantiateLeft(arguments[i], b.arguments[i], ctxt);
      }
      return ctxt;
    }

    unhandled("instantiateLeft", "$a <:= $b");
    return null;
  }

  OrderedContext instantiateRight(Datatype a, Skolem b, OrderedContext ctxt) {
    if (trace) {
      print("instantiate right: $a <=: $b");
    }
    // TODO refactor.

    Existential exB = ctxt.lookup(b.ident) as Existential;
    if (exB == null) {
      throw "$b is unbound!";
    }

    if (exB.isSolved) {
      throw "$b has already been solved!";
    }

    // a <=: %b, if a is a monotype.
    OrderedContext ctxt0 = ctxt.drop(exB);
    if (typeUtils.isMonoType(a, ctxt0)) {
      ctxt = ctxt.update(exB.solve(a));
      return ctxt;
    }

    // %a <=: %b, if level(%b) <= level(%a)
    if (a is Skolem) {
      Existential exA = ctxt.lookupAfter(a.ident, exB) as Existential;
      if (exA == null) {
        throw SkolemEscapeError(a.syntheticName);
      }
      if (exA.isSolved) {
        throw "$a has already been solved!";
      }

      //ctxt = ctxt.update(exA.solve(b));
      exA.equate(exB);
      return ctxt;
    }

    // \/qs.a <=: %b, if a[%bs/qs] <=: %a.
    if (a is ForallType) {
      Triple<Existential, OrderedContext, Datatype> result =
          guessInstantiation(a.quantifiers, a.body, ctxt);
      Existential ex = result.fst;
      ctxt = result.snd;
      Datatype type = result.thd;

      Marker marker = Marker(ex.skolem);
      ctxt = ctxt.insertBefore(marker, ex);

      ctxt = instantiateRight(type, b, ctxt);

      // Drop the scope.
      if (marker != null) {
        ctxt = ctxt.drop(marker);
      }

      return ctxt;
    }

    // as* -> a <=: %b, if %a' ctxt' <=: %b'
    // %b = %bs* -> %b'
    // ctxt' = %bs* <: %as*
    if (a is ArrowType) {
      Skolem codomain = Skolem();
      Existential codomainEx = Existential(codomain);
      ctxt = ctxt.insertBefore(codomainEx, exB);

      List<Skolem> domain = List<Skolem>();
      for (int i = 0; i < a.arity; i++) {
        Skolem skolem = Skolem();
        domain.add(skolem);
        Existential ex = Existential(skolem);
        ctxt = ctxt.insertBefore(ex, exB);
      }

      ctxt = ctxt.update(exB.solve(ArrowType(domain, codomain)));

      for (int i = 0; i < domain.length; i++) {
        ctxt = instantiateLeft(domain[i], a.domain[i], ctxt);
      }

      return instantiateRight(ctxt.apply(a.codomain), codomain, ctxt);
    }

    // (* as*) <=: %b, if as* <=: %bs*, where
    // %b = (* %bs* ), where %bs* are fresh.
    if (a is TupleType) {
      List<Skolem> components = new List<Skolem>();
      for (int i = 0; i < a.components.length; i++) {
        Skolem skolem = Skolem();
        components.add(skolem);
        Existential ex = Existential(skolem);
        ctxt = ctxt.insertBefore(ex, exB);
      }
      ctxt = ctxt.update(exB.solve(TupleType(components)));

      for (int i = 0; i < components.length; i++) {
        ctxt = instantiateRight(a.components[i], components[i], ctxt);
      }
      return ctxt;
    }

    // K as* <=: %b, if as* <:= %bs*, where
    // %b = K %bs*, where %bs* are fresh.
    if (a is TypeConstructor) {
      List<Skolem> arguments = new List<Skolem>();
      for (int i = 0; i < a.arguments.length; i++) {
        Skolem skolem = Skolem();
        arguments.add(skolem);
        Existential ex = Existential(skolem);
        ctxt = ctxt.insertBefore(ex, exB);
      }
      ctxt =
          ctxt.update(exB.solve(TypeConstructor.from(a.declarator, arguments)));

      for (int i = 0; i < arguments.length; i++) {
        ctxt = instantiateRight(a.arguments[i], arguments[i], ctxt);
      }
      return ctxt;
    }

    unhandled("instantiateRight", "$a <=: $b");
    return null; // Impossible!
  }
}
