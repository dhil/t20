// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show LinkedHashMap;

import '../errors/errors.dart' show unhandled;
import '../location.dart' show Location;
import '../module_environment.dart';

import 'ast.dart';
import 'closure.dart' show freeVariables;

Binder freshBinder(TopModule origin, Datatype type) {
  Binder binder = Binder.fresh()..type = type;
  return binder;
}

class ScratchSpace {
  // Parallel lists.
  List<Binder> _sources;
  List<Binder> get sources => _sources;
  void addSource(Binder binder) {
    _sources ??= new List<Binder>();
    sources.add(binder);
  }

  List<Expression> _initialisers;
  List<Expression> get initialisers => _initialisers;
  void addInitialiser(Expression init) {
    _initialisers ??= new List<Expression>();
    initialisers.add(init);
  }

  // Parallel lists.
  List<Binder> _binders;
  List<Binder> get binders => _binders;
  void addBinder(Binder binder) {
    _binders ??= new List<Binder>();
    binders.add(binder);
  }

  List<Expression> _bodies;
  List<Expression> get bodies => _bodies;
  void addBody(Expression body) {
    _bodies ??= new List<Expression>();
    bodies.add(body);
  }

  ScratchSpace();

  bool get isValid => binders == bodies || binders.length == bodies.length;

  Expression build(Expression continuation, [bool buildSources = false]) {
    if (binders == null && !buildSources) return continuation;

    if (binders != null) {
      assert(binders.length == bodies.length);
      // Builds the continuation bottom-up; starting with the provided continuation.
      for (int i = binders.length - 1; 0 <= i; i--) {
        Binder binder = binders[i];
        Expression body = bodies[i];
        continuation = DLet(binder, body, continuation);
      }
    }

    if (buildSources) {
      assert(sources.length == initialisers.length);
      for (int i = sources.length - 1; 0 <= i; i--) {
        Binder binder = sources[i];
        Expression body = initialisers[i];
        continuation = DLet(binder, body, continuation);
      }
    }

    return continuation;
  }
}

ScratchSpace desugarParameters(
    List<Pattern> parameters, PatternDesugarer pattern) {
  ScratchSpace workSpace = new ScratchSpace();
  for (int i = 0; i < parameters.length; i++) {
    Pattern pat = parameters[i];
    Binder source = pattern.desugar(pat, workSpace);
    // Wildcard patterns do not inspect their source. However, for parameters we
    // must provide one.
    if (source == null) {
      source = freshBinder(pat.origin, pat.type);
    }
    workSpace.addSource(source);
  }
  return workSpace;
}

class ModuleDesugarer {
  PatternDesugarer pattern;
  ExpressionDesugarer expression;

  ModuleDesugarer(ModuleEnvironment environment) {
    PatternDesugarer pattern = PatternDesugarer(environment);
    ExpressionDesugarer expr = ExpressionDesugarer(environment, pattern);
    pattern.expression = expr;

    this.pattern = pattern;
    this.expression = expr;
  }

  TopModule desugar(TopModule module) {
    List<ModuleMember> members = new List<ModuleMember>();
    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member0 = module.members[i];
      ModuleMember desugaredMember = member(module.members[i]);
      members.add(desugaredMember);

      // Update the main if need-be.
      if (module.hasMain &&
          member0 is FunctionDeclaration &&
          identical(module.main, member0)) {
        module.main = desugaredMember as Declaration;
      }
    }
    module.members = members;
    return module;
  }

  ModuleMember member(ModuleMember member) {
    switch (member.tag) {
      case ModuleTag.DATATYPE_DEFS:
        return member; // TODO.
        //unhandled("ModuleDesugarer.member", member.tag);
        break;
      case ModuleTag.FUNC_DEF:
        return function(member as FunctionDeclaration);
        break;
      case ModuleTag.VALUE_DEF:
        return value(member as ValueDeclaration);
        break;
      case ModuleTag.CONSTR:
      case ModuleTag.SIGNATURE:
      case ModuleTag.TYPENAME:
        return member; // Identity.
        break;
      default:
        unhandled("ModuleDesugarer.member", member.tag);
    }

    return null; // Impossible!
  }

  LetFunction function(FunctionDeclaration fundecl) {
    // The declaration may be virtual.
    if (fundecl.isVirtual) {
      assert(fundecl is VirtualFunctionDeclaration);
      return LetVirtualFunction(
          fundecl.signature, fundecl.binder, fundecl.location);
    }

    // Non-virtual declaration.
    // Desugar the parameters.
    ScratchSpace workSpace = desugarParameters(fundecl.parameters, pattern);
    List<FormalParameter> parameters = new List<FormalParameter>();
    if (workSpace.sources != null) {
      for (int i = 0; i < workSpace.sources.length; i++) {
        Binder binder = workSpace.sources[i];
        parameters.add(FormalParameter(binder));
      }
    }

    // Desugar the body.
    Expression body = expression.desugar(fundecl.body);
    // Join with any bindings produced by the parameter desugaring.
    body = workSpace.build(body);

    return LetFunction(
        fundecl.signature, fundecl.binder, parameters, body, fundecl.location);
  }

  ValueDeclaration value(ValueDeclaration val) {
    if (val.isVirtual) {
      assert(val is VirtualValueDeclaration);
      return val;
    }

    // Homomorphism.
    val.body = expression.desugar(val.body);
    return val;
  }
}

class ExpressionDesugarer {
  ModuleEnvironment environment;
  PatternDesugarer pattern;
  MatchCompiler matchCompiler;

  DecisionTreeCompiler _decisionTree;
  DecisionTreeCompiler get decisionTree {
    // Lazily instantiated.
    _decisionTree ??= DecisionTreeCompiler(environment, this);
    return _decisionTree;
  }

  ExpressionDesugarer(ModuleEnvironment environment, PatternDesugarer pattern) {
    this.environment = environment;
    this.pattern = pattern;
    this.matchCompiler = MatchCompiler(environment, this, pattern);
  }

  Expression desugar(Expression exp) {
    switch (exp.tag) {
      // Identity cases.
      case ExpTag.BOOL:
      case ExpTag.INT:
      case ExpTag.STRING:
      case ExpTag.VAR:
        return exp;
        break;
      // Homomorphism cases.
      case ExpTag.APPLY:
        Apply apply = exp as Apply;
        apply.abstractor = desugar(apply.abstractor);
        apply.arguments = apply.arguments.map(desugar).toList();
        return apply;
        break;
      case ExpTag.IF:
        If ifexpr = exp as If;
        ifexpr.condition = desugar(ifexpr.condition);
        ifexpr.thenBranch = desugar(ifexpr.thenBranch);
        ifexpr.elseBranch = desugar(ifexpr.elseBranch);
        return ifexpr;
        break;
      case ExpTag.TUPLE:
        Tuple tuple = exp as Tuple;
        tuple.components = tuple.components.map(desugar).toList();
        return tuple;
        break;
      case ExpTag.TYPE_ASCRIPTION:
        unhandled("ExpressionDesugarer.desugar", exp.tag);
        break;
      // "Interesting" cases.
      case ExpTag.LAMBDA:
        return lambda(exp as Lambda);
        break;
      case ExpTag.LET:
        return let(exp as Let);
        break;
      case ExpTag.MATCH:
        return match(exp as Match);
        break;
      default:
        unhandled("ExpressionDesugarer.desugar", exp.tag);
    }

    return null; // Impossible!
  }

  DLambda lambda(Lambda lambda) {
    // Desugar the parameters.
    ScratchSpace workSpace = desugarParameters(lambda.parameters, pattern);
    List<FormalParameter> parameters = new List<FormalParameter>();
    if (workSpace.sources != null) {
      for (int i = 0; i < workSpace.sources.length; i++) {
        Binder binder = workSpace.sources[i];
        parameters.add(FormalParameter(binder));
      }
    }

    // Desugar the body.
    Expression body = desugar(lambda.body);
    // Join with any bindings produced by the parameter desugaring.
    body = workSpace.build(body);

    DLambda target = DLambda(parameters, body, lambda.location);
    // target.type = lambda.type;

    return target;
  }

  Expression let(Let letexpr) {
    // Desugar each binding.
    ScratchSpace workSpace = ScratchSpace();
    for (int i = 0; i < letexpr.valueBindings.length; i++) {
      Binding binding = letexpr.valueBindings[i];

      // Desugar the body expression [e_i].
      Expression body = desugar(binding.expression);

      // Desugar the pattern [b_i].
      Binder source = pattern.desugar(binding.pattern, workSpace);
      if (source == null) {
        source = freshBinder(binding.pattern.origin, binding.pattern.type);
      }
      workSpace.addSource(source);
      workSpace.addInitialiser(body);
    }

    // Desugar the continuation [e'].
    Expression continuation = desugar(letexpr.body);
    // Builds: let b_i = e_i in e'.
    return workSpace.build(continuation, true);
  }

  Expression match(Match match) {
    if (match.cases.length == 0) {
      // let x = scrutinee in matchFailure.
      Binder xb = freshBinder(match.origin, match.scrutinee.type);
      return DLet(
          xb, desugar(match.scrutinee), pattern.matchFailure(match.location));
    }

    // Type-directed match compilation.
    Datatype scrutineeType = match.scrutinee.type;
    if (scrutineeType is BoolType ||
        scrutineeType is IntType ||
        scrutineeType is StringType) {
      // Decision tree compilation.
      Binder scrutinee = freshBinder(match.origin, scrutineeType);
      return DLet(scrutinee, desugar(match.scrutinee),
          decisionTree.desugar(scrutinee, match.cases, match.location));
    }

    if (scrutineeType is TupleType) {
      // Due to the shallowness of the pattern language, the first case will
      // always be a complete/exhaustive match.
      ScratchSpace workSpace = ScratchSpace();
      Pattern pat = match.cases[0].pattern;
      Binder source = pattern.desugar(pat, workSpace);
      if (source == null) {
        source = freshBinder(pat.origin, pat.type);
      }
      workSpace.addSource(source);
      workSpace.addInitialiser(desugar(match.scrutinee));

      return workSpace.build(match.cases[0].expression, true);
    }

    if (scrutineeType is TypeConstructor) {
      // Not a simple "desugaring". This requires introduction of closures and
      // eliminator application. The match compiler handles all of that.
      return matchCompiler.compile(scrutineeType, match);
    }

    unhandled("ExpressionDesugarer.match", scrutineeType);

    return null; // Impossible!
  }
}

class MatchCompiler {
  ModuleEnvironment environment;
  ExpressionDesugarer expression;
  PatternDesugarer pattern;

  MatchCompiler(this.environment, this.expression, this.pattern);

  Expression compile(TypeConstructor scrutineeType, Match match) {
    assert(match.cases.length > 0 &&
        scrutineeType.declarator is DatatypeDescriptor);
    // TODO optimise for |cases| < k, where k is some predetermined constant, e.g. 5.

    // General transformation:
    // (match scrutinee cases+) => let x = scrutinee in eliminate(closure(x, cases)).

    // Steps:
    // Compute the closure of match.cases.
    // Create a MatchClosure object.
    // Create a elimination node.
    // Let bind the scrutinee.

    Datatype resultType = match.type;

    MatchClosureDefaultCase defaultCase0;
    List<MatchClosureCase> cases = new List<MatchClosureCase>();
    Set<int> seenConstructors = Set<int>();
    int n =
        (scrutineeType.declarator as DatatypeDescriptor).constructors.length;
    List<Variable> fvs = List<Variable>();
    for (int i = 0; i < match.cases.length; i++) {
      Case case0 = match.cases[i];
      Pattern pat = case0.pattern;

      if (pat is WildcardPattern || pat is VariablePattern) {
        // Catch-all pattern.
        Binder xb;
        if (pat is VariablePattern) {
          xb = pat.binder;
        } else {
          xb = freshBinder(pat.origin, pat.type);
        }
        // Desugar the right hand side expression.
        Expression exp = expression.desugar(case0.expression);
        // Monotonically increase the information about free variables.
        fvs.addAll(freeVariables(exp));
        // Compile the default case.
        defaultCase0 = defaultCase(xb, exp, resultType);
        break; // Exhaustive match.
      } else if (pat is ConstructorPattern) {
        DataConstructor constructor = pat.declarator;
        if (!seenConstructors.contains(constructor.binder.ident)) {
          // Desugar the right hand side expression.
          Expression exp = expression.desugar(case0.expression);
          // Monotonically increase the information about free variables.
          fvs.addAll(freeVariables(exp));

          // Compile the case.
          cases.add(regularCase(scrutineeType, pat, exp, resultType));
          // Remember the constructor.
          seenConstructors.add(constructor.binder.ident);
          if (cases.length == n) break; // Exhaustive.
        } else {
          // Redundant match.
        }
      } else {
        unhandled("MatchCompiler.compile", pat);
      }
    }

    // Computes a list of captured local variables and freshens the binders of
    // captured variables.
    ClosureResult cloResult = computeClosure(fvs);

    MatchClosure clo = MatchClosure(resultType, scrutineeType, cases,
        defaultCase0, cloResult.binders, match.location);

    Expression scrutinee = expression.desugar(match.scrutinee);
    Binder scrutineeBinder = freshBinder(match.origin, scrutineeType);
    Variable scrutineeVar = Variable(scrutineeBinder);

    // Put everything together.
    Expression exp = DLet(scrutineeBinder, scrutinee,
        Eliminate(scrutineeVar, clo, cloResult.variables, scrutineeType));
    return exp;
  }

  MatchClosureDefaultCase defaultCase(
      Binder xb, Expression desugaredExp, Datatype resultType) {
    return MatchClosureDefaultCase(xb, desugaredExp);
  }

  MatchClosureCase regularCase(Datatype inputType, ConstructorPattern pattern,
      Expression desugaredExp, Datatype resultType) {
    ScratchSpace workSpace = ScratchSpace();
    Binder binder =
        expression.pattern.constructor(pattern, workSpace, true, inputType);
    Expression exp = workSpace.build(desugaredExp);
    return MatchClosureCase(binder, pattern.declarator, exp);
  }

  Binder refresh(Binder binder) => Binder.refresh(binder);

  ClosureResult computeClosure(List<Variable> freeVariables) {
    // Freshen the binders of [freeVariables].
    List<Variable> variables = List<Variable>();
    Map<int, ClosureVariable> binderMap = LinkedHashMap<int,
        ClosureVariable>(); // Crucially, remembers the insertion order.
    for (int i = 0; i < freeVariables.length; i++) {
      Variable v = freeVariables[i];
      // Don't capture global variables.
      if (environment.isLocal(v.binder)) {
        ClosureVariable cv = binderMap[v.ident];
        // If there is no fresh binder for [v], then create one.
        if (cv == null) {
          cv = ClosureVariable(refresh(v.binder));
          binderMap[v.ident] = cv;
          variables.add(Variable(v.binder));
        }
        // Adjust the variable's binder.
        v.binder = cv.binder;
      }
    }
    return ClosureResult(variables, binderMap.values.toList());
  }
}

class ClosureResult {
  List<Variable> variables;
  List<ClosureVariable> binders;
  ClosureResult(this.variables, this.binders);
}

class CaseNormalisationResult {
  List<Case> cases;
  Case defaultCase;
  CaseNormalisationResult(this.cases, this.defaultCase);
}

class DecisionTreeCompiler {
  ExpressionDesugarer expression;
  ModuleEnvironment environment;

  DecisionTreeCompiler(this.environment, this.expression);

  int boolCompare(bool x, bool y) {
    if (x == y)
      return 0;
    else if (x)
      return 1;
    else
      return -1;
  }

  int intCompare(int x, int y) {
    if (x == y)
      return 0;
    else if (x < y)
      return -1;
    else
      return 1;
  }

  int stringCompare(String x, String y) => x.compareTo(y);

  Expression desugar(Binder scrutinee, List<Case> cases, [Location location]) {
    Datatype type = scrutinee.type;
    CaseNormalisationResult result;
    if (type is BoolType) {
      result = normalise(cases, type, boolCompare, 2, location);
    } else if (type is IntType) {
      result = normalise(cases, type, intCompare, null, location);
    } else if (type is StringType) {
      result = normalise(cases, type, stringCompare, null, location);
    } else {
      unhandled("DecisionTreeCompiler.desugar", type);
    }
    return compile(
        scrutinee, result.cases, 0, cases.length - 1, result.defaultCase);
  }

  CaseNormalisationResult normalise<T>(List<Case> cases, Datatype type,
      int Function(T, T) compare, int inhabitants, Location location) {
    List<Case> result = new List<Case>();
    Case catchAll;
    bool exhaustive = false;

    if (type is! BoolType && type is! IntType && type is! StringType) {
      unhandled("DecisionTreeCompiler.normalise", type);
    }

    Set<T> seen = Set<T>();
    for (int i = 0; i < cases.length; i++) {
      Case c = cases[i];
      if (c.pattern is WildcardPattern || c.pattern is VariablePattern) {
        catchAll = c;
        exhaustive = true;
        break;
      }

      if (c.pattern is BaseValuePattern<T>) {
        BaseValuePattern<T> pat = c.pattern as BaseValuePattern<T>;
        if (!seen.contains(pat.value)) {
          result.add(c);
          seen.add(pat.value);
        } else {
          // TODO: Signal redundant pattern?
        }
        continue;
      }

      unhandled("DecisionTreeCompiler.normalise", c.pattern);
    }

    // Sort the cases.
    result.sort((Case x, Case y) => compare(
        ((x.pattern) as BaseValuePattern<T>).value,
        ((y.pattern) as BaseValuePattern<T>).value));

    // TODO emit incomplete pattern match warning?
    if (!exhaustive && inhabitants != null) {
      exhaustive = seen.length == inhabitants;
    }

    if (catchAll == null) {
      catchAll =
          Case(WildcardPattern(), expression.pattern.matchFailure(location));
    }

    return CaseNormalisationResult(result, catchAll);
  }

  // Compiles a sorted list of base patterns into a well-balanced binary search
  // tree.
  Expression compile(Binder scrutinee, List<Case> cases, int start, int end,
      Case defaultCase) {
    int mid = (start + (end - start)) ~/ 2;
    Case c;
    // Two base cases:
    // 1) compile scrutinee [] defaultCase = compile scrutinee [defaultCase] _
    if (start > end) {
      return immediate(defaultCase, scrutinee);
    } else {
      // print("$mid");
      c = cases[mid];
    }
    // 2) compile scrutinee [case] _ = if (eq? scrutinee w) desugar case.body else continuation.
    //                                 where w = [|case.pattern.value|].
    if (start < end) {
      Pattern pat = c.pattern;

      // // Immediate match.
      // if (pat is VariablePattern || pat is WildcardPattern) {
      //   return immediate(c, scrutinee);
      // }

      // Potential match.
      Expression w;
      Expression eq;
      if (pat is IntPattern) {
        w = IntLit(pat.value, pat.location);
        eq =
            Variable(environment.prelude.manifest.findByName("int-eq?").binder);
      } else if (pat is StringPattern) {
        w = StringLit(pat.value, pat.location);
        eq = Variable(environment.string.manifest.findByName("eq?").binder);
      } else {
        unhandled("DecisionTreeCompiler.compile", pat);
      }
      Expression condition = Apply(eq, <Expression>[Variable(scrutinee), w]);

      return If(condition, expression.desugar(c.expression), immediate(defaultCase, scrutinee));
    }

    // Inductive case:
    // compile scrutinee cases = (if (= scrutinee w) (compile scrutinee [cmid]) else (if (< scrutinee w) (compile scrutinee left(cases)) else (compile scrutinee right(cases)))).
    //                         where  cmid = cases[cases.length / 2]
    //                                  w = [|cmid.pattern.value|];
    //                         left cases = [ c | c <- cases, c.pattern.value < cmid.pattern.value ]
    //                        right cases = [ c | c <- cases, c.pattern.value > cmid.pattern.value ]
    Pattern pat = c.pattern;

    // // Immediate match.
    // if (pat is VariablePattern || pat is WildcardPattern) {
    //   // Delegate to the base case.
    //   return immediate(c, scrutinee);
    // }

    // Potential match.
    Expression w;
    Expression less;
    Expression eq;

    if (pat is IntPattern) {
      w = IntLit(pat.value, pat.location);
      less =
          Variable(environment.prelude.manifest.findByName("int-less?").binder);
      eq = Variable(environment.prelude.manifest.findByName("int-eq?").binder);
    } else if (pat is StringPattern) {
      w = StringLit(pat.value, pat.location);
      less = Variable(environment.string.manifest.findByName("less?").binder);
      eq = Variable(environment.string.manifest.findByName("eq?").binder);
    } else {
      unhandled("DecisionTreeCompiler.compile", pat);
    }

    List<Expression> arguments = <Expression>[Variable(scrutinee), w];
    If testExp = If(
        Apply(eq, arguments),
        expression.desugar(c.expression),
        If(
            Apply(less, arguments),
            compile(scrutinee, cases, start, mid - 1, defaultCase),
            compile(scrutinee, cases, mid + 1, end, defaultCase)));
    return testExp;
  }

  Expression immediate(Case c, Binder scrutinee) {
    Pattern pat = c.pattern;
    if (pat is VariablePattern) {
      // Bind the scrutinee.
      Binder binder = pat.binder;
      return DLet(
          binder, Variable(scrutinee), expression.desugar(c.expression));
    } else if (pat is WildcardPattern) {
      return expression.desugar(c.expression);
    } else {
      unhandled("DecisionTreeCompiler.immediate", pat);
    }

    return null; // Impossible!
  }
}

class PatternDesugarer {
  ModuleEnvironment environment;
  ExpressionDesugarer expression; // Lazily instantiated.

  PatternDesugarer(this.environment, [this.expression]);

  Binder desugar(Pattern pattern, ScratchSpace space) {
    switch (pattern.tag) {
      // Literal patterns.
      case PatternTag.BOOL:
      case PatternTag.INT:
      case PatternTag.STRING:
        return basePattern(pattern, space);
        break;
      // Variable patterns.
      case PatternTag.WILDCARD:
        return null;
        break;
      case PatternTag.VAR:
        // Micro-optimisation: Avoid introducing an intermediate trivial binding
        // by replacing the binder of the [source] by the binder of [pat].
        VariablePattern pat = pattern as VariablePattern;
        return pat.binder;
        break;
      // Compound patterns.
      case PatternTag.HAS_TYPE:
        return desugar((pattern as HasTypePattern).pattern, space);
        break;
      case PatternTag.CONSTR:
        return constructor(pattern as ConstructorPattern, space);
        break;
      case PatternTag.TUPLE:
        return tuple(pattern as TuplePattern, space);
        break;
      default:
        unhandled("PatternDesugarer.desugar", pattern.tag);
    }

    return null; // Impossible!
  }

  Binder basePattern(Pattern pat, ScratchSpace space) {
    Expression equals;
    Expression operand;

    if (pat is BoolPattern) {
      equals =
          Variable(environment.prelude.manifest.findByName("bool-eq?").binder);
      operand = BoolLit(pat.value, pat.location);
    } else if (pat is IntPattern) {
      equals =
          Variable(environment.prelude.manifest.findByName("int-eq?").binder);
      operand = IntLit(pat.value, pat.location);
    } else if (pat is StringPattern) {
      equals = Variable(environment.string.manifest.findByName("eq?").binder);
      operand = StringLit(pat.value, pat.location);
    } else {
      unhandled("PatternDesugarer.basePattern", pat);
    }

    Binder binder = freshBinder(pat.origin, pat.type);
    // [|p|] = (if (eq? p.value d) d else fail)
    //     where d is a declaration.
    Binder dummy = freshBinder(pat.origin, pat.type);
    Expression x = Variable(binder);
    Expression exp = If(
        Apply(equals, <Expression>[operand, x]), x, matchFailure(pat.location));
    space.addBinder(dummy);
    space.addBody(exp);

    return binder;
  }

  Binder tuple(TuplePattern tuple, ScratchSpace space) {
    Binder source = freshBinder(tuple.origin, tuple.type);
    destruct(source, tuple.components, space);
    return source;
  }

  Binder constructor(ConstructorPattern constr, ScratchSpace space,
      [bool subvertSafetyCheck = false, Datatype inputType]) {
    Binder source = freshBinder(constr.origin, inputType ?? constr.type);

    // Verify the runtime type of [constr].
    if (!subvertSafetyCheck) {
      Binder dummy = freshBinder(source.origin, source.type);
      Expression exp = If(Is(Variable(source), constr.declarator),
          Variable(source), matchFailure(constr.location));
      space.addBinder(dummy);
      space.addBody(exp);
    }

    destruct(source, constr.components, space, constr.declarator);

    return source;
  }

  // Destructs a compound pattern.
  void destruct(Binder source, List<Pattern> constituents, ScratchSpace space,
      [DataConstructor dataConstructor]) {
    for (int i = 0; i < constituents.length; i++) {
      Pattern constituent = constituents[i];
      assert(constituent is WildcardPattern || constituent is VariablePattern);
      Binder binder = desugar(constituent, space);
      if (binder != null) {
        space.addBinder(binder);
        Project projection = dataConstructor == null
            ? Project(Variable(source), i + 1)
            : DataConstructorProject(Variable(source), i + 1, dataConstructor);
        space.addBody(projection);
      }
    }
  }

  Expression matchFailure([Location location]) {
    String loc = location == null && !location.isSynthetic
        ? location.toString()
        : "no location";
    String message = "Pattern matching failure ($loc).";
    return Apply(
        Variable(environment.prelude.manifest.findByName("error").binder),
        <Expression>[StringLit(message)]);
  }
}
