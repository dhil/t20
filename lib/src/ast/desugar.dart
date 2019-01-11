// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show DoubleLinkedQueue, Queue;

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

class ScratchSpace {
  List<Register> _registers;
  List<Register> get registers => _registers;
  Queue<Expression> _stack;
  Queue<Expression> get stack => _stack;

  void addExpression(Expression expr) {
    _stack ??= new DoubleLinkedQueue<Expression>();
    stack.addLast(expr);
  }

  Register allocate(Binder binder) {
    _registers ??= new List<Register>();
    Register register = Register(binder);
    registers.add(register);
    return register;
  }
}

void copyInto(ScratchSpace space, Block block) {
  if (space.registers != null) {
    block.allocateMany(space.registers);
  }

  if (space.stack != null) {
    Expression expr;
    while ((expr = space.stack.removeFirst()) != null) {
      block.addStatement(expr);
    }
  }
}

Register recycleIn(Binder binder, ScratchSpace space) {
  Declaration bindingSite = binder.bindingOccurrence;
  Register register = space.allocate(binder);
  // Adjust the declarator.
  for (int i = 0; i < bindingSite.uses.length; i++) {
    Variable v = bindingSite.uses[i];
    v.declarator = register;
  }
  register.mergeUses(bindingSite.uses);
  bindingSite.binder = null;
  return register;
}

List<Register> desugarParameters(
    PatternDesugarer pattern, List<Pattern> parameters, ScratchSpace space) {
  List<Register> parameters0 = new List<Register>();
  for (int i = 0; i < parameters.length; i++) {
    Pattern pat = parameters[i];
    Register parameter = pattern.desugar(pat, space);
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
    List<ModuleMember> members0 = new List<ModuleMember>();
    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member = module.members[i];
      switch (member.tag) {
        case ModuleTag.FUNC_DEF:
          member =
              desugarFunctionDeclaration(null, member as FunctionDeclaration);
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

  LetFunction desugarFunctionDeclaration(Block _, FunctionDeclaration decl) {
    // The declaration may be virtual.
    if (decl.isVirtual) {
      assert(decl is VirtualFunctionDeclaration);
      return LetVirtualFunction(decl.signature, decl.binder, decl.location);
    }

    // Allocate an empty work space for bindings.
    ScratchSpace space = ScratchSpace();

    // Desugar parameters.
    List<Register> parameters =
        desugarParameters(pattern, decl.parameters, space);

    // Allocate an empty local frame.
    Block block = Block.empty();
    copyInto(space, block);

    // Desugar the body.
    block.expression = expression.desugar(decl.body, block);

    return LetFunction(
        decl.signature, decl.binder, parameters, block, decl.location);
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

  Register desugar(Pattern pattern, ScratchSpace space) {
    switch (pattern.tag) {
      // Literal patterns.
      case PatternTag.BOOL:
      case PatternTag.INT:
      case PatternTag.STRING:
        return basePattern(pattern, space);
        break;
      // Variable patterns.
      case PatternTag.WILDCARD:
        // Allocate a "dummy" variable.
        Binder dummy = Binder.fresh(pattern.origin)..type = pattern.type;
        return space.allocate(dummy);
        break;
      case PatternTag.VAR:
        // Micro-optimisation: Avoid introducing an intermediate trivial binding
        // by replacing the binder of the [source] by the binder of [pat].
        VariablePattern pat = pattern as VariablePattern;
        return recycleIn(pat.binder, space);
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
  }

  Register basePattern(Pattern pattern, ScratchSpace space) {
    Expression equals;
    Expression operand;

    if (pattern is BoolPattern) {
      equals = Variable(environment.prelude.manifest.findByName("bool-eq?"));
      operand = BoolLit(pattern.value, pattern.location);
    } else if (pattern is IntPattern) {
      equals = Variable(environment.prelude.manifest.findByName("int-eq?"));
      operand = IntLit(pattern.value, pattern.location);
    } else if (pattern is StringPattern) {
      equals = Variable(environment.string.manifest.findByName("eq?"));
      operand = StringLit(pattern.value, pattern.location);
    } else {
      unhandled("PatternDesugarer.basePattern", pattern);
    }

    Binder binder = Binder.fresh(pattern.origin)..type = pattern.type;
    Register source = space.allocate(binder);

    // [|p|] = (if (eq? p.value d) d else fail)
    //     where d is a declaration.
    Expression x = Variable(source);
    Expression exp = If(Apply(equals, <Expression>[operand, x]), x,
        matchFailure(pattern.location));
    space.addExpression(exp);

    return source;
  }

  Register tuple(TuplePattern tuple, ScratchSpace space) {
    Binder binder = Binder.fresh(tuple.origin)..type = tuple.type;
    Register source = space.allocate(binder);

    for (int i = 0; i < tuple.components.length; i++) {
      Pattern pat = tuple.components[i];
      assert(pat is VariablePattern || pat is WildcardPattern);
      if (pat is VariablePattern) {
        Register register = desugar(pat, space);
        Expression select =
            SetVariable(Variable(register), Project(Variable(source), i));
        space.addExpression(select);
      }
    }
    return source;
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

class ExpressionResult {
  bool anormalised;
  Expression expr;

  ExpressionResult(this.anormalised, this.expr);
}

class ExpressionDesugarer {
  ModuleEnvironment environment;
  PatternDesugarer pattern; // Lazily instantiated.
  ExpressionDesugarer(this.environment, [this.pattern]);

  Expression desugar(Expression expr, Block block) {
    ScratchSpace space = ScratchSpace();
    Expression desugared = normalise(expr, space);

    return expr;
  }

  // (Selectively) a-normalise.
  Expression normalise(Expression expr, ScratchSpace space) {
    switch (expr.tag) {
      // Identity desugaring.
      case ExpTag.BOOL:
      case ExpTag.INT:
      case ExpTag.STRING:
      case ExpTag.VAR:
        return expr;
        break;
      // Homomorphisms.
      case ExpTag.APPLY:
        // Apply apply = expr as Apply;
        // apply.abstractor = desugar(apply.abstractor, block);
        // List<Expression> arguments0 = new List<Expression>();
        // for (int i = 0; i < apply.arguments.length; i++) {
        //   arguments0.add(desugar(apply.arguments[i], block));
        // }
        // desugared = apply;
        break;
      case ExpTag.IF:
        return ifexpr(expr as If, space);
        break;
      case ExpTag.TUPLE:
        return tuple(expr as Tuple, space);
        break;
      // Interesting desugarings.
      case ExpTag.LAMBDA:
        // desugared = lambda(expr as Lambda, block);
        break;
      case ExpTag.LET:
        // desugared = let(expr as Let, block);
        break;
      case ExpTag.MATCH:
        throw "Not yet implemented.";
        break;
      default:
        unhandled("ExpressionDesugarer.desugar", expr.tag);
    }
  }

  Expression ifexpr(If expr, ScratchSpace space) {
    expr.condition  = normalise(expr.condition, space);
    ScratchSpace thenSpace = ScratchSpace();
    Block thenBlock = Block.empty();
    thenBlock.expression = normalise(expr.thenBranch, thenSpace);
    expr.thenBranch = thenBlock;

    ScratchSpace elseSpace = ScratchSpace();
    Block elseBlock = Block.empty();
    elseBlock.expression = normalise(expr.elseBranch, elseSpace);
    copyInto(elseSpace, elseBlock);
    expr.elseBranch = elseBlock;
    return expr; // TODO need to return a variable.
  }

  Expression tuple(Tuple tuple, ScratchSpace space) {
    List<Expression> components0 = new List<Expression>();
    for (int i = 0; i < tuple.components.length; i++) {
      Expression component = tuple.components[i];
      Expression expr = normalise(tuple.components[i], space);
      components0.add(expr);
    }
    tuple.components = components0;
    return tuple;
  }

  DLambda lambda(Lambda lambda, ScratchSpace _) {
    // Allocate an empty work space for bindings.
    ScratchSpace space = ScratchSpace();

    // Desugar each parameter.
    List<Register> parameters =
        desugarParameters(pattern, lambda.parameters, space);

    // Allocate an empty frame.
    Block block = Block.empty();
    copyInto(space, block);

    // Desugar the body.
    block.expression = desugar(lambda.body, block);

    return DLambda(parameters, block, lambda.location);
  }

  Expression let(Let letexpr, ScratchSpace space) {
    // Desugar each binding.
    for (int i = 0; i < letexpr.valueBindings.length; i++) {
      Binding binding = letexpr.valueBindings[i];

      Expression expr = normalise(binding.expression, space);
      Register register = pattern.desugar(binding.pattern, space);

      // Add the binding.
      space.addExpression(SetVariable(Variable(register), expr));
    }

    // Desugar the continuation.
    return normalise(letexpr.body, space);
  }

  bool isPure(Expression expr) {
    switch (expr.tag) {
      case ExpTag.BOOL:
      case ExpTag.INT:
      case ExpTag.STRING:
      case ExpTag.VAR:
      case ExpTag.LAMBDA:
        return true;
      case ExpTag.APPLY:
        Apply apply = expr as Apply;
        return isPure(apply.abstractor) && apply.arguments.every(isPure);
        break;
      case ExpTag.TUPLE:
        Tuple tuple = expr as Tuple;
        return tuple.components.every(isPure);
      default:
        return false; // Conservative decision.
    }
  }
}
