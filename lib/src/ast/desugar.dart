// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
//   T desugar(S node, ScratchSpace space);
// }

List<FormalParameter> desugarParameters(
    PatternDesugarer pattern, List<Pattern> parameters, ScratchSpace space) {
  List<FormalParameter> parameters0 = new List<FormalParameter>();
  for (int i = 0; i < parameters.length; i++) {
    Pattern pat = parameters[i];
    Binder xb = Binder.fresh(pat.origin)..type = pat.type;
    FormalParameter parameter = FormalParameter(xb);
    pattern.desugar(parameter, pat, space);
    parameters0.add(parameter);
  }
  return parameters0;
}

class ModuleDesugarer {
  PatternDesugarer pattern;
  ExpressionDesugarer expression;

  Desugarer(ModuleEnvironment environment) {
    expression = ExpressionDesugarer(environment);
    pattern = PatternDesugarer(environment, expression);
    expression.pattern = pattern;
  }

  List<T20Error> desugar(TopModule module) {
    ScratchSpace heap = new GlobalSpace();
    module.space = heap;
    List<ModuleMember> members0 = new List<ModuleMember>();
    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member = module.members[i];
      switch (member.tag) {
        case ModuleTag.FUNC_DEF:
          member =
              desugarFunctionDeclaration(heap, member as FunctionDeclaration);
          break;
        case ModuleTag.VALUE_DEF:
          unhandled("Not yet implemented", member.tag);
          break;
        case ModuleTag.CONSTR:
          unhandled("Not yet implemented", member.tag);
          break;
        case ModuleTag.DATATYPE_DEFS:
          unhandled("Not yet implemented", member.tag);
          break;
        case ModuleTag.SIGNATURE:
        case ModuleTag.TYPENAME:
          // Ignored.
          break;
        default:
          unhandled("Desugarer.module", member.tag);
      }

      // Add the desugared member.
      members0.add(member);
    }

    // Replace members with their desugarings.
    module.members = members0;

    // Return [null] to signal success.
    return null;
  }

  LetFunction desugarFunctionDeclaration(
      ScratchSpace _, FunctionDeclaration decl) {
    // The declaration may be virtual.
    if (decl.isVirtual) {
      return LetVirtualFunction(decl.signature, decl.binder, decl.location);
    }

    // Allocate an empty local frame.
    Frame frame = Frame.empty();

    // Desugar parameters.
    List<FormalParameter> parameters0 =
        desugarParameters(pattern, decl.parameters, frame);

    // Desugar the body.
    frame.expression = expression.desugar(decl.body, frame);

    return LetFunction(
        decl.signature, decl.binder, parameters0, frame, decl.location);
  }
}

class PatternDesugarer {
  ExpressionDesugarer expression; // Lazily instantiated.
  ModuleEnvironment environment;

  PatternDesugarer(this.environment, [this.expression]);

  Binder freshBinder(TopModule origin, Datatype type) {
    Binder xb = Binder.fresh(origin);
    xb.type = type;
    return xb;
  }

  Binder freshBinderFor(Pattern pattern) {
    return freshBinder(pattern.origin, pattern.type);
  }

  void desugar(Declaration source, Pattern pattern, ScratchSpace space) {
    switch (pattern.tag) {
      // Literal patterns.
      case PatternTag.BOOL:
      case PatternTag.INT:
      case PatternTag.STRING:
        basePattern(source, pattern, space);
        break;
      // Variable patterns.
      case PatternTag.WILDCARD:
        // Do nothing.
        break;
      case PatternTag.VAR:
        // Micro-optimisation: Avoid introducing an intermediate trivial binding
        // by replacing the binder of the [source] by the binder of [pat].
        VariablePattern pat = pattern as VariablePattern;
        source.binder = pat.binder;
        source.binder.bindingOccurrence = source;
        break;
      // Compound patterns.
      case PatternTag.HAS_TYPE:
        desugar(source, (pattern as HasTypePattern).pattern, space);
        break;
      case PatternTag.CONSTR:
        break;
      case PatternTag.TUPLE:
        break;
      default:
        unhandled("PatternDesugarer.desugar", pattern.tag);
    }
  }

  void basePattern(Declaration source, Pattern pattern, ScratchSpace space) {
    Expression equals;
    Expression operand;

    if (pattern is BoolPattern) {
      equals = Variable(environment.prelude.manifest.findByName("bool-eq?"));
      operand = BoolLit(pattern.value, pattern.location);
    } else if (pattern is IntPattern) {
      equals = Variable(environment.prelude.manifest.findByName("int-eq?"));
      operand = IntLit(pattern.value, pattern.location);
    } else if (pattern is StringPattern) {
      equals = Variable(environment.prelude.manifest.findByName("string-eq?"));
      operand = StringLit(pattern.value, pattern.location);
    } else {
      unhandled("PatternDesugarer.basePattern", pattern);
    }

    // [|p|] = (if (eq? p.value d) d else fail)
    //     where d is a declaration.
    Expression x = Variable(source);
    Expression exp = If(Apply(equals, <Expression>[operand, x]), x,
        matchFailure(pattern.location));
    space.addStatement(exp);
  }

  Expression matchFailure([Location location]) {
    String loc = location == null && !location.isSynthetic
        ? location.toString()
        : "no location";
    String message = "Pattern matching failure ($loc).";
    return Apply(Variable(environment.prelude.manifest.findByName("error")),
        <Expression>[StringLit(message)]);
  }
}

class ExpressionDesugarer {
  ModuleEnvironment environment;
  PatternDesugarer pattern; // Lazily instantiated.
  ExpressionDesugarer(this.environment, [this.pattern]);

  Expression desugar(Expression expr, ScratchSpace space) {
    Expression desugared;
    switch (expr.tag) {
      // Identity desugaring.
      case ExpTag.BOOL:
      case ExpTag.INT:
      case ExpTag.STRING:
      case ExpTag.VAR:
        desugared = expr;
        break;
      // Homomorphisms.
      case ExpTag.APPLY:
        Apply apply = expr as Apply;
        apply.abstractor = desugar(apply.abstractor, space);
        List<Expression> arguments0 = new List<Expression>();
        for (int i = 0; i < apply.arguments.length; i++) {
          arguments0.add(desugar(apply.arguments[i], space));
        }
        desugared = apply;
        break;
      case ExpTag.IF:
        If ifexpr = expr as If;
        ifexpr.condition = desugar(ifexpr.condition, space);
        ifexpr.thenBranch = desugar(ifexpr.thenBranch, space);
        ifexpr.elseBranch = desugar(ifexpr.elseBranch, space);
        desugared = ifexpr;
        break;
      case ExpTag.TUPLE:
        Tuple tuple = expr as Tuple;
        List<Expression> components0 = new List<Expression>();
        for (int i = 0; i < tuple.components.length; i++) {
          components0.add(desugar(tuple.components[i], space));
        }
        desugared = tuple;
        break;
      // Interesting desugarings.
      case ExpTag.LAMBDA:
        desugared = lambda(expr as Lambda, space);
        break;
      case ExpTag.LET:
        desugared = let(expr as Let, space);
        break;
      case ExpTag.MATCH:
        throw "Not yet implemented.";
        break;
      default:
        unhandled("ExpressionDesugarer.desugar", expr.tag);
    }
    return expr;
  }

  DLambda lambda(Lambda lambda, ScratchSpace _) {
    // Allocate an empty frame.
    Frame frame = Frame.empty();

    // Desugar each parameter.
    List<FormalParameter> parameters =
        desugarParameters(pattern, lambda.parameters, frame);

    // Desugar the body.
    frame.expression = desugar(lambda.body, frame);

    return DLambda(parameters, frame, lambda.location);
  }

  DLet let(Let letexpr, ScratchSpace space) {
    // Desugar each binding.

    // Desugar the continuation.
    Expression body = desugar(letexpr.body, space);
    throw "Not yet implemented!";
    return DLet(null, body, letexpr.location);
  }
}
