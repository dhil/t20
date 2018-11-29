// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart';
import '../ast/monoids.dart';

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

class _TypeChecker {
  List<TypeError> errors = new List<TypeError>();
  final bool trace;

  _TypeChecker(this.trace);

  Datatype error(TypeError err, Location location) {
    errors.add(err);
    return ErrorType(err, location);
  }

  Pair<OrderedContext, Datatype> lift(Datatype type) {
    return Pair<OrderedContext, Datatype>(OrderedContext.empty(), type);
  }

  // // Skolem management.
  // // Current type level.
  // int _currentLevel = 1;
  // // Increases the type-level by one.
  // void enter() {
  //   if (trace) {
  //     print("level incr: $_currentLevel --> ${_currentLevel+1}");
  //   }
  //   ++_currentLevel;
  // }

  // // Decreases the type level by one.
  // void leave() {
  //   if (trace) {
  //     print("level decr: $_currentLevel --> ${_currentLevel-1}");
  //   }
  //   --_currentLevel;
  // }

  // // Updates the level of the provided [skolem].
  // void update(Skolem skolem) {
  //   if (trace) {
  //     print("update: $skolem --> $_currentLevel");
  //   }
  //   skolem.level = _currentLevel;
  // }

  // // Factory method for skolems/existential variables.
  // Skolem skolem() {
  //   return Skolem();
  // }

  // Main entry point.
  ModuleMember typeCheck(ModuleMember member) {
    Pair<OrderedContext, Datatype> result =
        inferModule(member, OrderedContext.empty());
    return member;
  }

  Pair<OrderedContext, Datatype> inferModule(
      ModuleMember member, OrderedContext ctxt) {
    if (trace) {
      print("infer module: $member");
    }
    switch (member.tag) {
      case ModuleTag.CONSTR:
      case ModuleTag.DATATYPE_DEFS:
      case ModuleTag.OPEN:
        return Pair<OrderedContext, Datatype>(ctxt, typeUtils.unitType);
        break;
      case ModuleTag.TOP:
        TopModule module = member as TopModule;
        for (int i = 0; i < module.members.length; i++) {
          Pair<OrderedContext, Datatype> result =
              inferModule(module.members[i], ctxt);
          ctxt = result.fst;
        }
        return Pair<OrderedContext, Datatype>(ctxt, typeUtils.unitType);
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
  }

  Pair<OrderedContext, Datatype> inferFunctionDefinition(
      FunctionDeclaration funDef, OrderedContext ctxt) {
    if (funDef is VirtualFunctionDeclaration) {
      return Pair<OrderedContext, Datatype>(ctxt, funDef.signature.type);
    }
    Datatype sig = funDef.signature.type;
    if (!typeUtils.isFunctionType(sig)) {
      TypeError err = TypeExpectationError(funDef.signature.location);
      return Pair<OrderedContext, Datatype>(
          ctxt, error(err, funDef.signature.location));
    }
    // Check the formal parameters.
    List<Datatype> domain = typeUtils.domain(sig);
    List<Pattern> parameters = funDef.parameters;
    if (domain.length != parameters.length) {
      TypeError err =
          ArityMismatchError(domain.length, parameters.length, funDef.location);
      return Pair<OrderedContext, Datatype>(ctxt, error(err, funDef.location));
    }

    Pair<ScopedEntry, OrderedContext> result =
        checkManyPatterns(parameters, domain, ctxt);
    ScopedEntry scope = result.fst;
    ctxt = result.snd;

    // Check the body type against the declared type.
    ctxt = checkExpression(funDef.body, typeUtils.codomain(sig), ctxt);

    // Drop [scope].
    if (scope != null) {
      ctxt = ctxt.drop(scope);
    }

    // Ascription ascription = Ascription(funDef, sig);
    // ctxt.insertLast(ascription);
    return Pair<OrderedContext, Datatype>(ctxt, sig);
  }

  Pair<OrderedContext, Datatype> inferValueDefinition(
      ValueDeclaration valDef, OrderedContext ctxt) {
    Datatype sig = valDef.signature.type;
    // Check the body against the declared type.
    ctxt = checkExpression(valDef.body, sig, ctxt);

    // Ascription ascription = Ascription(valDef, sig);
    // ctxt.insertLast(ascription);
    return Pair<OrderedContext, Datatype>(ctxt, sig);
  }

  Pair<OrderedContext, Datatype> inferExpression(
      Expression exp, OrderedContext ctxt) {
    if (trace) {
      print("infer expression: $exp");
    }
    switch (exp.tag) {
      case ExpTag.BOOL:
        return Pair<OrderedContext, Datatype>(ctxt, typeUtils.boolType);
        break;
      case ExpTag.INT:
        return Pair<OrderedContext, Datatype>(ctxt, typeUtils.intType);
        break;
      case ExpTag.STRING:
        return Pair<OrderedContext, Datatype>(ctxt, typeUtils.stringType);
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
        return Pair<OrderedContext, Datatype>(ctxt, type);
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
  }

  Pair<OrderedContext, Datatype> inferApply(Apply appl, OrderedContext ctxt) {
    // Infer a type for the abstractor.
    Pair<OrderedContext, Datatype> result =
        inferExpression(appl.abstractor, ctxt);
    ctxt = result.fst;
    // Eliminate foralls.
    return apply(appl.arguments, ctxt.apply(result.snd), ctxt, appl.location);
  }

  Pair<OrderedContext, Datatype> apply(List<Expression> arguments,
      Datatype type, OrderedContext ctxt, Location location) {
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
        return Pair<OrderedContext, Datatype>(ctxt, type.codomain);
      }
      ctxt = checkMany<Expression>(
          checkExpression, arguments, fnType.domain, ctxt);
      return Pair<OrderedContext, Datatype>(ctxt, fnType.codomain);
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

      return Pair<OrderedContext, Datatype>(ctxt, codomain);
    }

    // ERROR.
    unhandled("apply", "$arguments, $type");
  }

  Pair<OrderedContext, Datatype> inferMatch(Match match, OrderedContext ctxt) {
    // Infer a type for the scrutinee.
    Pair<OrderedContext, Datatype> result =
        inferExpression(match.scrutinee, ctxt);
    ctxt = result.fst;
    Datatype scrutineeType = result.snd;
    // Check the patterns (left hand sides) against the inferd type for the
    // scrutinee. Check the clause bodies (right hand sides) against the type of
    // their left hand sides.
    if (match.cases.length == 0) {
      Skolem skolem = Skolem();
      Existential ex = Existential(skolem);
      ctxt = ctxt.insertLast(ex);
      return Pair<OrderedContext, Datatype>(ctxt, skolem);
    } else {
      Datatype branchType;
      for (int i = 0; i < match.cases.length; i++) {
        Case case0 = match.cases[i];
        Pair<ScopedEntry, OrderedContext> result =
            checkPattern(case0.pattern, scrutineeType, ctxt);
        ScopedEntry entry = result.fst;
        ctxt = result.snd;
        if (branchType == null) {
          // First case.
          Pair<OrderedContext, Datatype> result =
              inferExpression(case0.expression, ctxt);
          ctxt = result.fst;
          branchType = result.snd;
        } else {
          // Any subsequent case.
          Pair<OrderedContext, Datatype> result =
              inferExpression(case0.expression, ctxt);
          ctxt = result.fst;
          Datatype otherBranchType = result.snd;
          // Check that [otherBranchType] <: [branchType].
          ctxt = subsumes(otherBranchType, branchType, ctxt);
        }
        // Drop the scope.
        if (entry != null) {
          ctxt = ctxt.drop(entry);
        }
      }
      return Pair<OrderedContext, Datatype>(ctxt, branchType);
    }
  }

  Pair<OrderedContext, Datatype> inferLet(Let let, OrderedContext ctxt) {
    // Infer a type for each of the value bindings.
    for (int i = 0; i < let.valueBindings.length; i++) {
      Binding binding = let.valueBindings[i];
      // Infer a type for the expression (right hand side)
      Pair<OrderedContext, Datatype> result0 =
          inferExpression(binding.expression, ctxt);
      ctxt = result0.fst;
      Datatype expType = result0.snd;
      // Check the pattern (left hand side) against the inferd type.
      Pair<ScopedEntry, OrderedContext> result1 =
          checkPattern(binding.pattern, expType, ctxt);
      ctxt = result1.snd;
    }
    // Infer a type for the continuation (body).
    return inferExpression(let.body, ctxt);
  }

  Pair<OrderedContext, Datatype> inferLambda(
      Lambda lambda, OrderedContext ctxt) {
    // Infer types for the parameters.
    Triple<ScopedEntry, OrderedContext, List<Datatype>> result =
        inferManyPatterns(lambda.parameters, ctxt);
    ScopedEntry scopeMarker = result.fst;
    ctxt = result.snd;
    List<Datatype> domain = result.thd;

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
    return Pair<OrderedContext, Datatype>(ctxt, ft);
  }

  Pair<OrderedContext, Datatype> inferIf(If ifthenelse, OrderedContext ctxt) {
    // Check that the condition has type bool.
    ctxt = checkExpression(ifthenelse.condition, typeUtils.boolType, ctxt);
    // Infer a type for each branch.
    Pair<OrderedContext, Datatype> trueBranchResult =
        inferExpression(ifthenelse.thenBranch, ctxt);
    Datatype tt = trueBranchResult.fst.apply(trueBranchResult.snd);

    Pair<OrderedContext, Datatype> falseBranchResult =
        inferExpression(ifthenelse.elseBranch, ctxt);
    Datatype ff = falseBranchResult.fst.apply(falseBranchResult.snd);

    // Check that types agree.
    ctxt = subsumes(tt, ff, ctxt);

    return Pair<OrderedContext, Datatype>(ctxt, tt);
  }

  Pair<OrderedContext, Datatype> inferTuple(Tuple tuple, OrderedContext ctxt) {
    List<Expression> components = tuple.components;
    // If there are no subexpression, then return the canonical unit type.
    if (components.length == 0) {
      return Pair<OrderedContext, Datatype>(ctxt, typeUtils.unitType);
    }
    // Infer a type for each subexpression.
    List<Datatype> componentTypes = new List<Datatype>(components.length);
    for (int i = 0; i < components.length; i++) {
      Pair<OrderedContext, Datatype> result =
          inferExpression(components[i], ctxt);
      ctxt = result.fst;
      componentTypes[i] = result.snd;
    }
    return Pair<OrderedContext, Datatype>(ctxt, TupleType(componentTypes));
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
        Pair<ScopedEntry, OrderedContext> result =
            checkManyPatterns(lambda.parameters, fnType.domain, ctxt);
        ScopedEntry scopeMarker = result.fst;
        ctxt = result.snd;
        ctxt = checkExpression(lambda.body, fnType.codomain, ctxt);
        if (scopeMarker != null) {
          ctxt = ctxt.drop(scopeMarker);
        }
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
    Pair<OrderedContext, Datatype> result = inferExpression(exp, ctxt);
    ctxt = result.fst;
    Datatype left = result.snd;
    return subsumes(ctxt.apply(left), ctxt.apply(type), ctxt);
  }

  Pair<ScopedEntry, OrderedContext> checkManyPatterns(
      List<Pattern> patterns, List<Datatype> types, OrderedContext ctxt) {
    ScopedEntry first;
    for (int i = 0; i < patterns.length; i++) {
      Pair<ScopedEntry, OrderedContext> result =
          checkPattern(patterns[i], types[i], ctxt);
      first ??= result.fst;
      ctxt = result.snd;
    }
    return Pair<ScopedEntry, OrderedContext>(first, ctxt);
  }

  Pair<ScopedEntry, OrderedContext> checkPattern(
      Pattern pat, Datatype type, OrderedContext ctxt) {
    if (trace) {
      print("check pattern: $pat : $type");
    }

    // Literal pattern check against their respective base types.
    if (pat is BoolPattern && type is BoolType ||
        pat is IntPattern && type is IntType ||
        pat is StringPattern && type is StringType) {
      return null;
    }

    // check x t ctxt = ctxt.
    if (pat is VariablePattern) {
      VariablePattern v = pat;
      v.type = type;
      // Ascription ascription = Ascription(pat, type);
      // ctxt.insertLast(ascription);
      return Pair<ScopedEntry, OrderedContext>(null, ctxt);
    }

    // check (, ps*) (, ts*) ctxt = check* ps* ts* ctxt
    if (pat is TuplePattern && type is TupleType) {
      if (pat.components.length != type.components.length) {
        TypeError err = CheckTuplePatternError(type.toString(), pat.location);
        errors.add(err);
        return Pair<ScopedEntry, OrderedContext>(null, ctxt);
      }

      if (pat.components.length == 0) {
        return Pair<ScopedEntry, OrderedContext>(null, ctxt);
      }

      Pair<ScopedEntry, OrderedContext> result =
          checkManyPatterns(pat.components, type.components, ctxt);
      // Store the type.
      pat.type = ctxt.apply(type);

      return result;
    }

    // Infer a type for [pat].
    Triple<ScopedEntry, OrderedContext, Datatype> result =
        inferPattern(pat, ctxt);

    try {
      return Pair<ScopedEntry, OrderedContext>(
          result.fst, subsumes(result.thd, type, result.snd));
    } on TypeError catch (e) {
      errors.add(e);
      return Pair<ScopedEntry, OrderedContext>(result.fst, result.snd);
    }
  }

  Triple<ScopedEntry, OrderedContext, Datatype> inferPattern(
      Pattern pat, OrderedContext ctxt) {
    switch (pat.tag) {
      case PatternTag.BOOL:
        return Triple<ScopedEntry, OrderedContext, Datatype>(
            null, ctxt, typeUtils.boolType);
        break;
      case PatternTag.INT:
        return Triple<ScopedEntry, OrderedContext, Datatype>(
            null, ctxt, typeUtils.intType);
        break;
      case PatternTag.STRING:
        return Triple<ScopedEntry, OrderedContext, Datatype>(
            null, ctxt, typeUtils.stringType);
        break;
      case PatternTag.CONSTR:
        return inferConstructorPattern(pat as ConstructorPattern, ctxt);
        break;
      case PatternTag.HAS_TYPE:
        // Check the pattern type against the annotation.
        HasTypePattern hasType = pat as HasTypePattern;
        Pair<ScopedEntry, OrderedContext> result =
            checkPattern(hasType.pattern, hasType.type, ctxt);
        return Triple<ScopedEntry, OrderedContext, Datatype>(
            result.fst, result.snd, hasType.type);
        break;
      case PatternTag.TUPLE:
        return inferTuplePattern((pat as TuplePattern), ctxt);
        break;
      case PatternTag.VAR:
        VariablePattern varPattern = pat as VariablePattern;
        Datatype type = Skolem();
        varPattern.type = type;
        // Ascription ascription = Ascription(varPattern, type);
        // ctxt.insertLast(ascription);
        return Triple<ScopedEntry, OrderedContext, Datatype>(null, ctxt, type);
        break;
      case PatternTag.WILDCARD:
        Skolem skolem = Skolem();
        Existential ex = Existential(skolem);
        ctxt.insertLast(ex);
        return Triple<ScopedEntry, OrderedContext, Datatype>(ex, ctxt, skolem);
        break;
      default:
        unhandled("inferPattern", pat.tag);
    }
  }

  Triple<ScopedEntry, OrderedContext, List<Datatype>> inferManyPatterns(
      List<Pattern> patterns, OrderedContext ctxt) {
    ScopedEntry scopeMarker;
    List<Datatype> types = new List<Datatype>();
    for (int i = 0; i < patterns.length; i++) {
      Triple<ScopedEntry, OrderedContext, Datatype> result =
          inferPattern(patterns[i], ctxt);
      scopeMarker ??= result.fst;
      ctxt = result.snd;
      types.add(result.thd);
    }

    return Triple<ScopedEntry, OrderedContext, List<Datatype>>(
        scopeMarker, ctxt, types);
  }

  Triple<ScopedEntry, OrderedContext, Datatype> inferTuplePattern(
      TuplePattern tuplePattern, OrderedContext ctxt) {
    List<TuplePattern> components = tuplePattern.components;
    // Infer a type for each subpattern.
    Triple<ScopedEntry, OrderedContext, List<Datatype>> result =
        inferManyPatterns(components, ctxt);
    return Triple<ScopedEntry, OrderedContext, Datatype>(
        result.fst, result.snd, TupleType(result.thd));
  }

  Triple<ScopedEntry, OrderedContext, Datatype> inferConstructorPattern(
      ConstructorPattern constr, OrderedContext ctxt) {
    // Get the induced type.
    Datatype type = constr
        .type; // guaranteed to be compatible with `type_utils' function type api.
    // Arity check.
    List<Datatype> domain = typeUtils.domain(type);
    if (domain.length != constr.components.length) {
      TypeError err = ArityMismatchError(
          domain.length, constr.components.length, constr.location);
      return Triple<ScopedEntry, OrderedContext, Datatype>(
          null, ctxt, error(err, constr.location));
    }
    // Check the pattern against the induced type.
    Pair<ScopedEntry, OrderedContext> result = checkPattern(constr, type, ctxt);

    return Triple<ScopedEntry, OrderedContext, Datatype>(
        result.fst, result.snd, type);
  }

  // Implements the subsumption/subtyping relation <:.
  OrderedContext subsumes(Datatype lhs, Datatype rhs, OrderedContext ctxt) {
    if (trace) {
      print("subsumes: $lhs <: $rhs");
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

      ctxt = ctxt.update(exB.solve(a));
      return ctxt;
    }

    // %a <:= bs* -> b, if %a' <:= b ctxt', where
    // %a = %as* -> %a'
    // ctxt' = bs* <: %as*
    if (b is ArrowType) {
      Skolem codomain = Skolem();
      Existential codomainEx = Existential(codomain);
      ctxt = ctxt.insertBefore(codomainEx, exA);

      List<Datatype> domain = List<Datatype>();
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
      List<Datatype> components = new List<Datatype>();
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
      List<Datatype> arguments = new List<Datatype>();
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

    throw "InstantiateLeft error!";
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

      ctxt = ctxt.update(exA.solve(b));
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

      List<Datatype> domain = List<Datatype>();
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
      List<Datatype> components = new List<Datatype>();
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
      List<Datatype> arguments = new List<Datatype>();
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

    throw "InstantiateRight error!";
  }
}
