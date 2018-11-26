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
    Datatype result = inferModule(member, OrderedContext.empty());
    return member;
  }

  Datatype inferModule(ModuleMember member, OrderedContext ctxt) {
    if (trace) {
      print("infer module: $member");
    }
    switch (member.tag) {
      case ModuleTag.CONSTR:
      case ModuleTag.DATATYPE_DEFS:
      case ModuleTag.OPEN:
        return typeUtils.unitType;
        break;
      case ModuleTag.TOP:
        TopModule module = member as TopModule;
        for (int i = 0; i < module.members.length; i++) {
          inferModule(module.members[i], ctxt);
        }
        return typeUtils.unitType;
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

  Datatype inferFunctionDefinition(
      FunctionDeclaration funDef, OrderedContext ctxt) {
    if (funDef is VirtualFunctionDeclaration) {
      return funDef.signature.type;
    }
    Datatype sig = funDef.signature.type;
    if (!typeUtils.isFunctionType(sig)) {
      TypeError err = TypeExpectationError(funDef.signature.location);
      return error(err, funDef.signature.location);
    }
    // Check the formal parameters.
    List<Datatype> domain = typeUtils.domain(sig);
    List<Pattern> parameters = funDef.parameters;
    if (domain.length != parameters.length) {
      TypeError err =
          ArityMismatchError(domain.length, parameters.length, funDef.location);
      return error(err, funDef.location);
    }

    ScopedEntry scope = checkManyPatterns(parameters, domain, ctxt);
    // Check the body type against the declared type.
    ctxt = checkExpression(funDef.body, typeUtils.codomain(sig), ctxt);
    // Drop [scope].
    ctxt.drop(scope);

    Ascription ascription = Ascription(funDef, sig);
    ctxt.insertLast(ascription);
    return sig;
  }

  Datatype inferValueDefinition(ValueDeclaration valDef, OrderedContext ctxt) {
    Datatype sig = valDef.signature.type;
    // Check the body against the declared type.
    ctxt = checkExpression(valDef.body, sig, ctxt);

    Ascription ascription = Ascription(valDef, sig);
    ctxt.insertLast(ascription);
    return sig;
  }

  Datatype inferExpression(Expression exp, OrderedContext ctxt) {
    if (trace) {
      print("infer expression: $exp");
    }
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
        Variable v = exp as Variable;
        ScopedEntry entry = ctxt.lookup(v.ident);
        if (entry is Ascription) {
          return entry.type;
        } else {
          // ERROR.
          print("$ctxt");
          throw "Variable $v is not in scope!";
        }
        break;
      case ExpTag.TYPE_ASCRIPTION:
        throw "Not yet impleemented.";
        break;
      default:
        unhandled("inferExpression", exp.tag);
    }
  }

  Datatype inferApply(Apply appl, OrderedContext ctxt) {
    // Infer a type for the abstractor.
    Datatype result = inferExpression(appl.abstractor, ctxt);
    // Eliminate foralls.
    return apply(appl.arguments, result, ctxt, appl.location);
  }

  Datatype apply(List<Expression> arguments, Datatype type, OrderedContext ctxt,
      Location location) {
    if (trace) {
      print("apply: $arguments, $type");
    }
    // apply xs* (\/qs+.t) ctxt = apply xs* (t[qs+ -> as+]) ctxt
    if (type is ForallType) {
      Pair<Existential, Datatype> result =
          guessInstantiation(type.quantifiers, type.body, ctxt);
      Datatype body = result.snd;
      return apply(arguments, body, ctxt, location);
    }

    // apply xs* (ts* -> t) ctxt = (ctxt', t ctxt'), where ctxt' = check* xs* ts* ctxt
    if (type is ArrowType) {
      ArrowType fnType = type;
      if (type.arity != arguments.length) {
        TypeError err =
            ArityMismatchError(type.arity, arguments.length, location);
        errors.add(err);
        return type.codomain;
      }
      checkMany<Expression>(checkExpression, arguments, fnType.domain, ctxt);
      return fnType.codomain;
    }

    if (type is Skolem) {
      Skolem a = type;
      // Construct a function type whose immediate constituents are skolem
      // variables.
      Existential fnEx = ctxt.lookup(a.ident) as Existential;

      Skolem codomain = Skolem();
      Existential codomainEx = Existential(codomain);
      ctxt.insertBefore(codomainEx, fnEx);

      List<Datatype> domain = new List<Datatype>();
      for (int i = 0; i < arguments.length; i++) {
        Skolem skolem = Skolem();
        domain.add(skolem);

        Existential ex = Existential(skolem);
        ctxt.insertBefore(ex, fnEx);
      }

      ArrowType fnType = ArrowType(domain, codomain);
      // Solve a = (a0,...,aN-1) -> aN.
      fnEx.solve(fnType);

      // Check each argument.
      for (int i = 0; i < domain.length; i++) {
        checkExpression(arguments[i], domain[i], ctxt);
      }

      return codomain;
    }

    // ERROR.
    unhandled("apply", "$arguments, $type");
  }

  Datatype inferMatch(Match match, OrderedContext ctxt) {
    // Infer a type for the scrutinee.
    Datatype scrutineeType = inferExpression(match.scrutinee, ctxt);
    // Check the patterns (left hand sides) against the inferd type for the
    // scrutinee. Check the clause bodies (right hand sides) against the type of
    // their left hand sides.
    if (match.cases.length == 0) {
      Skolem skolem = Skolem();
      Existential ex = Existential(skolem);
      ctxt.insertLast(ex);
      return skolem;
    } else {
      Datatype branchType;
      for (int i = 0; i < match.cases.length; i++) {
        Case case0 = match.cases[i];
        ScopedEntry entry = checkPattern(case0.pattern, scrutineeType, ctxt);
        if (branchType == null) {
          // First case.
          Datatype branchType = inferExpression(case0.expression, ctxt);
        } else {
          // Any subsequent case.
          ctxt = checkExpression(case0.expression, branchType, ctxt);
        }
        // Drop the scope.
        ctxt.drop(entry);
      }
      return branchType;
    }
  }

  Datatype inferLet(Let let, OrderedContext ctxt) {
    // Infer a type for each of the value bindings.
    for (int i = 0; i < let.valueBindings.length; i++) {
      Binding binding = let.valueBindings[i];
      // Infer a type for the expression (right hand side)
      Datatype expType = inferExpression(binding.expression, ctxt);
      // Check the pattern (left hand side) against the inferd type.
      checkPattern(binding.pattern, expType, ctxt);
    }
    // Infer a type for the continuation (body).
    return inferExpression(let.body, ctxt);
  }

  Datatype inferLambda(Lambda lambda, OrderedContext ctxt) {
    // Infer types for the parameters.
    Pair<ScopedEntry, List<Datatype>> result =
        inferManyPatterns(lambda.parameters, ctxt);
    ScopedEntry scopeMarker = result.fst;
    List<Datatype> domain = result.snd;

    // Check the body against the existential.
    Skolem codomain = Skolem();
    Existential codomainEx = Existential(codomain);
    if (scopeMarker != null) {
      ctxt.insertBefore(codomainEx, scopeMarker);
    } else {
      ctxt.insertLast(codomainEx);
    }
    checkExpression(lambda.body, codomain, ctxt);

    // Drop the scope.
    ctxt.drop(scopeMarker);

    // Construct the arrow type.
    ArrowType ft = ArrowType(domain, codomain);
    return ft;
  }

  Datatype inferIf(If ifthenelse, OrderedContext ctxt) {
    // Check that the condition has type bool.
    ctxt = checkExpression(ifthenelse.condition, typeUtils.boolType, ctxt);
    // Infer a type for each branch.
    Datatype tt = inferExpression(ifthenelse.thenBranch, ctxt);
    Datatype ff = inferExpression(ifthenelse.elseBranch, ctxt);
    // Check that types agree.
    ctxt = subsumes(ctxt.apply(tt), ctxt.apply(ff), ctxt);

    return tt;
  }

  Datatype inferTuple(Tuple tuple, OrderedContext ctxt) {
    List<Expression> components = tuple.components;
    // If there are no subexpression, then return the canonical unit type.
    if (components.length == 0) {
      return typeUtils.unitType;
    }
    // Infer a type for each subexpression.
    List<Datatype> componentTypes = new List<Datatype>(components.length);
    OrderedContext ctxt0 = OrderedContext.empty();
    for (int i = 0; i < components.length; i++) {
      Datatype component = inferExpression(components[i], ctxt);
      componentTypes[i] = component;
    }
    return TupleType(componentTypes);
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
        ScopedEntry scopeMarker =
            checkManyPatterns(lambda.parameters, fnType.domain, ctxt);
        ctxt = checkExpression(lambda.body, fnType.codomain, ctxt);
        if (scopeMarker != null) {
          ctxt.drop(scopeMarker);
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
        ctxt.insertLast(q0);
      }
      ctxt = checkExpression(exp, forallType.body, ctxt);
      if (scopeMarker != null) {
        ctxt.drop(scopeMarker);
      }
      return ctxt;
    }

    if (type is BoolType && exp is BoolLit ||
        type is IntType && exp is IntLit ||
        type is StringType && exp is StringLit) {
      return ctxt;
    }

    // check e t ctxt = subsumes e t' ctxt', where (t', ctxt') = infer e ctxt
    Datatype left = inferExpression(exp, ctxt);
    return subsumes(ctxt.apply(left), ctxt.apply(type), ctxt);
  }

  ScopedEntry checkManyPatterns(
      List<Pattern> patterns, List<Datatype> types, OrderedContext ctxt) {
    ScopedEntry first;
    for (int i = 0; i < patterns.length; i++) {
      ScopedEntry e = checkPattern(patterns[i], types[i], ctxt);
      first ??= e;
    }
    return first;
  }

  ScopedEntry checkPattern(Pattern pat, Datatype type, OrderedContext ctxt) {
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
      print("===> $pat");
      VariablePattern v = pat;
      v.type = type;
      Ascription ascription = Ascription(pat, type);
      ctxt.insertLast(ascription);
      return ascription;
    }

    // check (, ps*) (, ts*) ctxt = check* ps* ts* ctxt
    if (pat is TuplePattern && type is TupleType) {
      if (pat.components.length != type.components.length) {
        TypeError err = CheckTuplePatternError(type.toString(), pat.location);
        errors.add(err);
        return null;
      }

      if (pat.components.length == 0) return null;

      ScopedEntry marker =
          checkManyPatterns(pat.components, type.components, ctxt);
      // Store the type.
      pat.type = ctxt.apply(type);

      return marker;
    }

    // Infer a type for [pat].
    Pair<ScopedEntry, Datatype> result = inferPattern(pat, ctxt);

    try {
      subsumes(result.snd, type, ctxt);
    } on TypeError catch (e) {
      errors.add(e);
      return null;
    }
    return null;
  }

  Pair<ScopedEntry, Datatype> inferPattern(Pattern pat, OrderedContext ctxt) {
    switch (pat.tag) {
      case PatternTag.BOOL:
        return Pair<ScopedEntry, Datatype>(null, typeUtils.boolType);
        break;
      case PatternTag.INT:
        return Pair<ScopedEntry, Datatype>(null, typeUtils.intType);
        break;
      case PatternTag.STRING:
        return Pair<ScopedEntry, Datatype>(null, typeUtils.stringType);
        break;
      case PatternTag.CONSTR:
        return inferConstructorPattern(pat as ConstructorPattern, ctxt);
        break;
      case PatternTag.HAS_TYPE:
        // Check the pattern type against the annotation.
        HasTypePattern hasType = pat as HasTypePattern;
        ScopedEntry entry = checkPattern(hasType.pattern, hasType.type, ctxt);
        return Pair<ScopedEntry, Datatype>(entry, hasType.type);
        break;
      case PatternTag.TUPLE:
        return inferTuplePattern((pat as TuplePattern), ctxt);
        break;
      case PatternTag.VAR:
        print("$pat");
        VariablePattern varPattern = pat as VariablePattern;
        Datatype type = Skolem();
        varPattern.type = type;
        Ascription ascription = Ascription(varPattern, type);
        ctxt.insertLast(ascription);
        return Pair<ScopedEntry, Datatype>(ascription, type);
        break;
      case PatternTag.WILDCARD:
        Skolem skolem = Skolem();
        Existential ex = Existential(skolem);
        ctxt.insertLast(ex);
        return Pair<ScopedEntry, Datatype>(ex, skolem);
        break;
      default:
        unhandled("inferPattern", pat.tag);
    }
  }

  Pair<ScopedEntry, List<Datatype>> inferManyPatterns(
      List<Pattern> patterns, OrderedContext ctxt) {
    ScopedEntry scopeMarker;
    List<Datatype> types = new List<Datatype>();
    for (int i = 0; i < patterns.length; i++) {
      Pair<ScopedEntry, Datatype> result = inferPattern(patterns[i], ctxt);
      scopeMarker ??= result.fst;
      types.add(result.snd);
    }

    return Pair<ScopedEntry, List<Datatype>>(scopeMarker, types);
  }

  Pair<ScopedEntry, Datatype> inferTuplePattern(
      TuplePattern tuplePattern, OrderedContext ctxt) {
    // TODO.
    return null;
  }

  Pair<ScopedEntry, Datatype> inferConstructorPattern(
      ConstructorPattern constr, OrderedContext ctxt) {
    // // Get the induced type.
    // Datatype type = constr
    //     .type; // guaranteed to be compatible with `type_utils' function type api.
    // // Arity check.
    // List<Datatype> domain = typeUtils.domain(type);
    // if (domain.length != constr.components.length) {
    //   TypeError err = ArityMismatchError(
    //       domain.length, constr.components.length, constr.location);
    //   return Pair<ScopedEntryt Datatype>(null, error(err, constr.location));
    // }
    // // Check each subpattern.
    // ScopedEntry scopeMarker = checkManyPatterns(constr.components, domain);

    // return Pair<ScopedEntry, Datatype>(
    //     scopeMarker, TypeConstructor.from(constr.declarator.declarator, components));
    return null;
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
      Pair<Existential, Datatype> result =
          guessInstantiation(a.quantifiers, a.body, ctxt);
      Existential first = result.fst;
      Datatype type = result.snd;

      Marker marker = Marker(first.skolem);
      ctxt.insertBefore(marker, first);

      ctxt = subsumes(type, b, ctxt);

      // Drop [marker].
      ctxt.drop(marker);
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
      ctxt.drop(scopeMarker);
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

  Pair<Existential, Datatype> guessInstantiation(
      List<Quantifier> quantifiers, Datatype type, OrderedContext ctxt) {
    Existential scopeMarker;
    Substitution sigma = Substitution.empty();
    for (int i = 0; i < quantifiers.length; i++) {
      Quantifier q = quantifiers[i];
      Skolem skolem = Skolem();
      sigma = sigma.bind(TypeVariable.bound(q), skolem);
      Existential ex = Existential(skolem);
      ctxt.insertLast(ex);
      scopeMarker ??= ex;
    }
    return Pair<Existential, Datatype>(scopeMarker, sigma.apply(type));
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

    // %a <:= %b, if level(%a) <= level(%b).
    if (b is Skolem) {
      Existential exB = ctxt.lookup(b.ident) as Existential;
      if (exB == null) {
        throw SkolemEscapeError(b.syntheticName);
      }

      if (exB.isSolved) {
        throw "$b has already been solved!";
      }

      exB.solve(a);
      return ctxt;
    }

    // %a <:= bs* -> b, if %a' <:= b ctxt', where
    // %a = %as* -> %a'
    // ctxt' = bs* <: %as*
    if (b is ArrowType) {
      Skolem codomain = Skolem();
      Existential codomainEx = Existential(codomain);
      ctxt.insertBefore(codomainEx, exA);

      List<Datatype> domain = List<Datatype>();
      for (int i = 0; i < b.arity; i++) {
        Skolem skolem = Skolem();
        domain.add(skolem);
        Existential ex = Existential(skolem);
        ctxt.insertBefore(ex, exA);
      }

      exA.solve(ArrowType(domain, codomain));

      for (int i = 0; i < domain.length; i++) {
        ctxt = subsumes(b.domain[i], domain[i], ctxt);
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
        ctxt.insertLast(q0);
        scopeMarker ??= q0;
      }
      ctxt = instantiateLeft(a, b.body, ctxt);
      // Exit the scope.
      ctxt.drop(scopeMarker);
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
        ctxt.insertBefore(ex, exA);
      }
      exA.solve(TupleType(components));

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
        ctxt.insertBefore(ex, exA);
      }
      exA.solve(TypeConstructor.from(b.declarator, arguments));

      for (int i = 0; i < arguments.length; i++) {
        ctxt = instantiateLeft(arguments[i], b.arguments[i], ctxt);
      }
      return ctxt;
    }

    // %a <:= b, if b is a monotype.
    exA.solve(b);
    return ctxt;

    //throw "InstantiateLeft error!";
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

    // %a <=: %b, if level(%b) <= level(%a)
    if (a is Skolem) {
      Existential exA = ctxt.lookup(a.ident) as Existential;
      if (exA == null) {
        throw SkolemEscapeError(a.syntheticName);
      }
      if (exA.isSolved) {
        throw "$a has already been solved!";
      }

      exA.solve(b);
      return ctxt;
    }

    // \/qs.a <=: %b, if a[%bs/qs] <=: %a.
    if (a is ForallType) {
      Pair<Existential, Datatype> result =
          guessInstantiation(a.quantifiers, a.body, ctxt);
      Existential ex = result.fst;
      Datatype type = result.snd;

      Marker marker = Marker(ex.skolem);
      ctxt.insertBefore(marker, ex);

      ctxt = instantiateRight(type, b, ctxt);

      // Drop the scope.
      ctxt.drop(marker);

      return ctxt;
    }

    // as* -> a <=: %b, if %a' ctxt' <=: %b'
    // %b = %bs* -> %b'
    // ctxt' = %bs* <: %as*
    if (a is ArrowType) {
      Skolem codomain = Skolem();
      Existential codomainEx = Existential(codomain);
      ctxt.insertBefore(codomainEx, exB);

      List<Datatype> domain = List<Datatype>();
      for (int i = 0; i < a.arity; i++) {
        Skolem skolem = Skolem();
        domain.add(skolem);
        Existential ex = Existential(skolem);
        ctxt.insertBefore(ex, exB);
      }

      exB.solve(ArrowType(domain, codomain));

      for (int i = 0; i < domain.length; i++) {
        ctxt = subsumes(domain[i], a.domain[i], ctxt);
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
        ex.insertBefore(exB);
      }
      b.solve(TupleType(components));

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
        ex.insertBefore(exB);
      }
      exB.solve(TypeConstructor.from(a.declarator, arguments));

      for (int i = 0; i < arguments.length; i++) {
        ctxt = instantiateRight(a.arguments[i], arguments[i], ctxt);
      }
      return ctxt;
    }

    // a <=: %b, if a is a monotype.
    exB.solve(a);
    return ctxt;

    //throw "InstantiateRight error!";
  }
}
