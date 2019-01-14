// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

//import 'dart:collection' show DoubleLinkedQueue, Queue;

//import 'package:kernel/ast.dart';

import '../errors/errors.dart' show unhandled, T20Error;
import '../location.dart' show Location;
import '../module_environment.dart';

import 'ast.dart';

// Maintains a list of mutable variables.
// class Heap {
//   List<MutableVariableDeclaration> memory;

//   MutableVariableDeclaration allocate(Binder binder, [Expression initialiser]) {
//     MutableVariableDeclaration variable =
//         MutableVariableDeclaration(binder, initialiser);
//     memory.add(variable);
//     return variable;
//   }

//   Heap() : memory = new List<MutableVariableDeclaration>();
// }

// abstract class Desugarer<S extends T20Node, T extends T20Node> {
//   const Desugarer();
//   T desugar(S node, Block space);
// }

// class ScratchSpace {
//   List<Register> _registers;
//   List<Register> get registers => _registers;
//   Queue<Expression> _stack;
//   Queue<Expression> get stack => _stack;

//   void addExpression(Expression expr) {
//     _stack ??= new DoubleLinkedQueue<Expression>();
//     stack.addLast(expr);
//   }

//   Register allocate(Binder binder) {
//     _registers ??= new List<Register>();
//     Register register = Register(binder);
//     registers.add(register);
//     return register;
//   }
// }

// void copyInto(ScratchSpace space, Block block) {
//   if (space.registers != null) {
//     block.allocateMany(space.registers);
//   }

//   if (space.stack != null) {
//     Expression expr;
//     while ((expr = space.stack.removeFirst()) != null) {
//       block.addStatement(expr);
//     }
//   }
// }

// Register recycleIn(Binder binder, ScratchSpace space) {
//   Declaration bindingSite = binder.bindingOccurrence;
//   Register register = space.allocate(binder);
//   // Adjust the declarator.
//   for (int i = 0; i < bindingSite.uses.length; i++) {
//     Variable v = bindingSite.uses[i];
//     v.declarator = register;
//   }
//   register.mergeUses(bindingSite.uses);
//   bindingSite.binder = null;
//   return register;
// }

// List<Register> desugarParameters(
//     PatternDesugarer pattern, List<Pattern> parameters, ScratchSpace space) {
//   List<Register> parameters0 = new List<Register>();
//   for (int i = 0; i < parameters.length; i++) {
//     Pattern pat = parameters[i];
//     Register parameter = pattern.desugar(pat, space);
//     parameters0.add(parameter);
//   }
//   return parameters0;
// }

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
    if (binders == null) return continuation;

    assert(binders.length == bodies.length);
    assert(buildSources == false ||
        binders.length == sources.length &&
            sources.length == initialisers.length);
    // Builds continuation bottom-up; starting with the provided continuation.
    for (int i = binders.length - 1; 0 <= i; i--) {
      Binder binder = binders[i];
      Expression body = bodies[i];
      continuation = DLet(binder, body, continuation);
      if (buildSources) {
        binder = sources[i];
        body = initialisers[i];
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
      source = Binder.fresh(pat.origin)..type = pat.type;
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
      ModuleMember member0 = member(module.members[i]);
      members.add(member0);
    }
    module.members = members;
    return module;
  }

  ModuleMember member(ModuleMember member) {
    switch (member.tag) {
      case ModuleTag.CONSTR:
        unhandled("ModuleDesugarer.member", member.tag);
        break;
      case ModuleTag.DATATYPE_DEFS:
        unhandled("ModuleDesugarer.member", member.tag);
        break;
      case ModuleTag.FUNC_DEF:
        return function(member as FunctionDeclaration);
        break;
      case ModuleTag.VALUE_DEF:
        return value(member as ValueDeclaration);
        break;
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
  PatternDesugarer pattern; // Lazily instantiated.

  DecisionTreeCompiler _decisionTree;
  DecisionTreeCompiler get decisionTree {
    // Lazily instantiated.
    _decisionTree ??= DecisionTreeCompiler(environment, this);
    return _decisionTree;
  }

  ExpressionDesugarer(this.environment, [this.pattern]);

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
    target.type = lambda.type;

    return target;
  }

  DLet let(Let letexpr) {
    // Desugar each binding.
    ScratchSpace workSpace = ScratchSpace();
    for (int i = 0; i < letexpr.valueBindings.length; i++) {
      Binding binding = letexpr.valueBindings[i];

      // Desugar the body expression [e_i].
      Expression body = desugar(binding.expression);

      // Desugar the pattern [b_i].
      Binder source = pattern.desugar(binding.pattern, workSpace);
      if (source == null) {
        source = Binder.fresh(binding.pattern.origin)
          ..type = binding.pattern.type;
      }
      workSpace.addSource(source);
      workSpace.addInitialiser(body);
    }

    // Desugar the continuation [e'].
    Expression continuation = desugar(letexpr.body);
    // Builds: let b_i = e_i in e'.
    return workSpace.build(continuation);
  }

  Expression match(Match match) {
    // Type-directed match compilation.
    Datatype scrutineeType = match.scrutinee.type;
    if (scrutineeType is BoolType ||
        scrutineeType is IntType ||
        scrutineeType is StringType) {
      // Decision tree compilation.
      Binder scrutinee = Binder.fresh(match.origin)..type = scrutineeType;
      return decisionTree.desugar(
          Variable(scrutinee), match.cases, match.location);
    }

    if (scrutineeType is TupleType) {
      // Compile the first clause.
    }

    if (scrutineeType is TypeConstructor) {
      throw "Not yet implemented.";
    }

    unhandled("ExpressionDesugarer.match", scrutineeType);
  }
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

  Expression desugar(Variable scrutinee, List<Case> cases,
      [Location location]) {
    Datatype type = scrutinee.declarator.type;
    if (type is BoolType) {
      cases = normalise(cases, type, boolCompare, 2);
    } else if (type is IntType) {
      cases = normalise(cases, type, intCompare, null);
    } else if (type is StringType) {
      cases = normalise(cases, type, stringCompare, null);
    } else {
      unhandled("DecisionTreeCompiler.desugar", type);
    }
    return compile(scrutinee, cases, 0, cases.length,
        expression.pattern.matchFailure(location));
  }

  List<Case> normalise<T>(List<Case> cases, Datatype type,
      int Function(T, T) compare, int inhabitants) {
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
    // Add the catch all case, if any.
    if (catchAll != null) {
      result.add(catchAll);
    }

    // TODO emit incomplete pattern match warning?
    if (!exhaustive && inhabitants != null) {
      exhaustive = seen.length == inhabitants;
    }

    return result;
  }

  // Compiles a sorted list of base patterns into a well-balanced binary search
  // tree.
  Expression compile(Variable scrutinee, List<Case> cases, int start, int end,
      Expression continuation) {
    int length = end - start + 1;
    // Two base cases:
    // 1) compile _ [] continuation = continuation.
    if (length == 0) return continuation;
    // 2) compile scrutinee [case] continuation = if (eq? scrutinee w) desugar case.body else continuation.
    //                                          where w = [|case.pattern.value|].
    if (length == 1) {
      int mid = length ~/ 2;
      Case c = cases[mid];
      Pattern pat = c.pattern;

      // Immediate match.
      if (pat is VariablePattern) {
        // Bind the scrutinee.
        Binder binder = pat.binder;
        return DLet(binder, scrutinee, expression.desugar(c.expression));
      } else if (pat is WildcardPattern) {
        return expression.desugar(c.expression);
      }

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
      Expression condition = Apply(eq, <Expression>[scrutinee, w]);

      return If(condition, expression.desugar(c.expression), continuation);
    }

    // Inductive case:
    // compile scrutinee cases = (if (= scrutinee w) (compile scrutinee [cmid]) else (if (< scrutinee w) (compile scrutinee left(cases)) else (compile scrutinee right(cases)))).
    //                         where  cmid = cases[cases.length / 2]
    //                                  w = [|cmid.pattern.value|];
    //                         left cases = [ c | c <- cases, c.pattern.value < cmid.pattern.value ]
    //                        right cases = [ c | c <- cases, c.pattern.value > cmid.pattern.value ]
    int mid = length ~/ 2;
    Case c = cases[mid];
    Pattern pat = c.pattern;

    // Immediate match.
    if (pat is VariablePattern || pat is WildcardPattern) {
      // Delegate to the base case.
      return compile(scrutinee, cases, mid, mid, continuation);
    }

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

    List<Expression> arguments = <Expression>[scrutinee, w];
    If testExp = If(
        Apply(eq, arguments),
        expression.desugar(c.expression),
        If(
            Apply(less, arguments),
            compile(scrutinee, cases, start, mid - 1, continuation),
            compile(scrutinee, cases, mid + 1, end, continuation)));
    return testExp;
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
        throw "Not yet implemented!";
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

    Binder binder = Binder.fresh(pat.origin)..type = pat.type;
    // [|p|] = (if (eq? p.value d) d else fail)
    //     where d is a declaration.
    Binder dummy = Binder.fresh(pat.origin)..type = pat.type;
    Expression x = Variable(binder);
    Expression exp = If(
        Apply(equals, <Expression>[operand, x]), x, matchFailure(pat.location));
    space.addBinder(dummy);
    space.addBody(exp);

    return binder;
  }

  Binder tuple(TuplePattern tuple, ScratchSpace space) {
    Binder source = Binder.fresh(tuple.origin)..type = tuple.type;
    for (int i = 0; i < tuple.components.length; i++) {
      Pattern component = tuple.components[i];
      assert(component is WildcardPattern || component is VariablePattern);
      Binder binder = desugar(component, space);
      if (binder != null) {
        space.addBinder(binder);
        space.addBody(Project(Variable(source), i));
      }
    }
    return source;
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

// class ModuleDesugarer {
//   PatternDesugarer pattern;
//   ExpressionDesugarer expression;

//   Desugarer(ModuleEnvironment environment) {
//     expression = ExpressionDesugarer(environment);
//     pattern = PatternDesugarer(environment, expression);
//     expression.pattern = pattern;
//   }

//   List<T20Error> desugar(TopModule module) {
//     List<ModuleMember> members0 = new List<ModuleMember>();
//     for (int i = 0; i < module.members.length; i++) {
//       ModuleMember member = module.members[i];
//       switch (member.tag) {
//         case ModuleTag.FUNC_DEF:
//           member =
//               desugarFunctionDeclaration(null, member as FunctionDeclaration);
//           break;
//         case ModuleTag.VALUE_DEF:
//           unhandled("Not yet implemented", member.tag);
//           break;
//         case ModuleTag.CONSTR:
//           unhandled("Not yet implemented", member.tag);
//           break;
//         case ModuleTag.DATATYPE_DEFS:
//           unhandled("Not yet implemented", member.tag);
//           break;
//         case ModuleTag.SIGNATURE:
//         case ModuleTag.TYPENAME:
//           // Ignored.
//           break;
//         default:
//           unhandled("Desugarer.module", member.tag);
//       }

//       // Add the desugared member.
//       members0.add(member);
//     }

//     // Replace members with their desugarings.
//     module.members = members0;

//     // Return [null] to signal success.
//     return null;
//   }

//   LetFunction desugarFunctionDeclaration(Block _, FunctionDeclaration decl) {
//     LetFunction target;
//     // The declaration may be virtual.
//     if (decl.isVirtual) {
//       assert(decl is VirtualFunctionDeclaration);
//       target = LetVirtualFunction(decl.signature, decl.binder, decl.location);
//     } else {
//       // Allocate an empty work space for bindings.
//       ScratchSpace space = ScratchSpace();

//       // Desugar parameters.
//       List<Register> parameters =
//           desugarParameters(pattern, decl.parameters, space);

//       // Allocate an empty local frame.
//       Block block = Block.empty();
//       copyInto(space, block);

//       // Desugar the body.
//       block.expression = expression.desugar(decl.body, block);

//       target = LetFunction(
//           decl.signature, decl.binder, parameters, block, decl.location);
//     }
//     // Teardown.
//     decl.signature = null;
//     decl.binder = null;
//     decl.expression = null;
//     decl.parent = null;

//     return target;
//   }
// }

// class PatternDesugarer {
//   ExpressionDesugarer expression; // Lazily instantiated.
//   ModuleEnvironment environment;

//   PatternDesugarer(this.environment, [this.expression]);

//   Binder freshBinder(TopModule origin, Datatype type) {
//     Binder xb = Binder.fresh(origin);
//     xb.type = type;
//     return xb;
//   }

//   Binder freshBinderFor(Pattern pattern) {
//     return freshBinder(pattern.origin, pattern.type);
//   }

//   Register desugar(Pattern pattern, ScratchSpace space) {
//     switch (pattern.tag) {
//       // Literal patterns.
//       case PatternTag.BOOL:
//       case PatternTag.INT:
//       case PatternTag.STRING:
//         return basePattern(pattern, space);
//         break;
//       // Variable patterns.
//       case PatternTag.WILDCARD:
//         // Allocate a "dummy" variable.
//         Binder dummy = Binder.fresh(pattern.origin)..type = pattern.type;
//         return space.allocate(dummy);
//         break;
//       case PatternTag.VAR:
//         // Micro-optimisation: Avoid introducing an intermediate trivial binding
//         // by replacing the binder of the [source] by the binder of [pat].
//         VariablePattern pat = pattern as VariablePattern;
//         return recycleIn(pat.binder, space);
//         break;
//       // Compound patterns.
//       case PatternTag.HAS_TYPE:
//         return desugar((pattern as HasTypePattern).pattern, space);
//         break;
//       case PatternTag.CONSTR:
//         throw "Not yet implemented!";
//         break;
//       case PatternTag.TUPLE:
//         return tuple(pattern as TuplePattern, space);
//         break;
//       default:
//         unhandled("PatternDesugarer.desugar", pattern.tag);
//     }
//   }

//   Register basePattern(Pattern pattern, ScratchSpace space) {
//     Expression equals;
//     Expression operand;

//     if (pattern is BoolPattern) {
//       equals = Variable(environment.prelude.manifest.findByName("bool-eq?"));
//       operand = BoolLit(pattern.value, pattern.location);
//     } else if (pattern is IntPattern) {
//       equals = Variable(environment.prelude.manifest.findByName("int-eq?"));
//       operand = IntLit(pattern.value, pattern.location);
//     } else if (pattern is StringPattern) {
//       equals = Variable(environment.string.manifest.findByName("eq?"));
//       operand = StringLit(pattern.value, pattern.location);
//     } else {
//       unhandled("PatternDesugarer.basePattern", pattern);
//     }

//     Binder binder = Binder.fresh(pattern.origin)..type = pattern.type;
//     Register source = space.allocate(binder);

//     // [|p|] = (if (eq? p.value d) d else fail)
//     //     where d is a declaration.
//     Expression x = Variable(source);
//     Expression exp = If(Apply(equals, <Expression>[operand, x]), x,
//         matchFailure(pattern.location));
//     space.addExpression(exp);

//     return source;
//   }

//   Register tuple(TuplePattern tuple, ScratchSpace space) {
//     Binder binder = Binder.fresh(tuple.origin)..type = tuple.type;
//     Register source = space.allocate(binder);

//     for (int i = 0; i < tuple.components.length; i++) {
//       Pattern pat = tuple.components[i];
//       assert(pat is VariablePattern || pat is WildcardPattern);
//       if (pat is VariablePattern) {
//         Register register = desugar(pat, space);
//         Expression select =
//             SetVariable(Variable(register), Project(Variable(source), i));
//         space.addExpression(select);
//       }
//     }
//     return source;
//   }

//   Expression matchFailure([Location location]) {
//     String loc = location == null && !location.isSynthetic
//         ? location.toString()
//         : "no location";
//     String message = "Pattern matching failure ($loc).";
//     return Apply(Variable(environment.prelude.manifest.findByName("error")),
//         <Expression>[StringLit(message)]);
//   }
// }

// class ExpressionResult {
//   bool anormalised;
//   Expression expr;

//   ExpressionResult(this.anormalised, this.expr);
// }

// class ExpressionDesugarer {
//   ModuleEnvironment environment;
//   PatternDesugarer pattern; // Lazily instantiated.
//   ExpressionDesugarer(this.environment, [this.pattern]);

//   Expression desugar(Expression expr, Block block) {
//     ScratchSpace space = ScratchSpace();
//     Expression desugared = normalise(expr, space);

//     return expr;
//   }

//   // (Selectively) a-normalise.
//   Expression normalise(Expression expr, ScratchSpace space) {
//     switch (expr.tag) {
//       // Identity desugaring.
//       case ExpTag.BOOL:
//       case ExpTag.INT:
//       case ExpTag.STRING:
//       case ExpTag.VAR:
//         return expr;
//         break;
//       // Homomorphisms.
//       case ExpTag.APPLY:
//         // Apply apply = expr as Apply;
//         // apply.abstractor = desugar(apply.abstractor, block);
//         // List<Expression> arguments0 = new List<Expression>();
//         // for (int i = 0; i < apply.arguments.length; i++) {
//         //   arguments0.add(desugar(apply.arguments[i], block));
//         // }
//         // desugared = apply;
//         break;
//       case ExpTag.IF:
//         return ifexpr(expr as If, space);
//         break;
//       case ExpTag.TUPLE:
//         return tuple(expr as Tuple, space);
//         break;
//       // Interesting desugarings.
//       case ExpTag.LAMBDA:
//         // desugared = lambda(expr as Lambda, block);
//         break;
//       case ExpTag.LET:
//         // desugared = let(expr as Let, block);
//         break;
//       case ExpTag.MATCH:
//         throw "Not yet implemented.";
//         break;
//       default:
//         unhandled("ExpressionDesugarer.desugar", expr.tag);
//     }
//   }

//   Expression ifexpr(If expr, ScratchSpace space) {
//     expr.condition = normalise(expr.condition, space);
//     ScratchSpace thenSpace = ScratchSpace();
//     Block thenBlock = Block.empty();
//     thenBlock.expression = normalise(expr.thenBranch, thenSpace);
//     expr.thenBranch = thenBlock;

//     ScratchSpace elseSpace = ScratchSpace();
//     Block elseBlock = Block.empty();
//     elseBlock.expression = normalise(expr.elseBranch, elseSpace);
//     copyInto(elseSpace, elseBlock);
//     expr.elseBranch = elseBlock;
//     return expr; // TODO need to return a variable.
//   }

//   Expression tuple(Tuple tuple, ScratchSpace space) {
//     List<Expression> components0 = new List<Expression>();
//     for (int i = 0; i < tuple.components.length; i++) {
//       Expression component = tuple.components[i];
//       Expression expr = normalise(tuple.components[i], space);
//       components0.add(expr);
//     }
//     tuple.components = components0;
//     return tuple;
//   }

//   DLambda lambda(Lambda lambda, ScratchSpace _) {
//     // Allocate an empty work space for bindings.
//     ScratchSpace space = ScratchSpace();

//     // Desugar each parameter.
//     List<Register> parameters =
//         desugarParameters(pattern, lambda.parameters, space);

//     // Allocate an empty frame.
//     Block block = Block.empty();
//     copyInto(space, block);

//     // Desugar the body.
//     block.expression = desugar(lambda.body, block);

//     return DLambda(parameters, block, lambda.location);
//   }

//   Expression let(Let letexpr, ScratchSpace space) {
//     // Desugar each binding.
//     for (int i = 0; i < letexpr.valueBindings.length; i++) {
//       Binding binding = letexpr.valueBindings[i];

//       Expression expr = normalise(binding.expression, space);
//       Register register = pattern.desugar(binding.pattern, space);

//       // Add the binding.
//       space.addExpression(SetVariable(Variable(register), expr));
//     }

//     // Desugar the continuation.
//     return normalise(letexpr.body, space);
//   }

//   bool isPure(Expression expr) {
//     switch (expr.tag) {
//       case ExpTag.BOOL:
//       case ExpTag.INT:
//       case ExpTag.STRING:
//       case ExpTag.VAR:
//       case ExpTag.LAMBDA:
//         return true;
//       case ExpTag.APPLY:
//         Apply apply = expr as Apply;
//         return isPure(apply.abstractor) && apply.arguments.every(isPure);
//         break;
//       case ExpTag.TUPLE:
//         Tuple tuple = expr as Tuple;
//         return tuple.components.every(isPure);
//       default:
//         return false; // Conservative decision.
//     }
//   }
// }
