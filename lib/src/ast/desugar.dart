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

class ModuleDesugarer {
  PatternDesugarer pattern;
  ExpressionDesugarer expression;

  Desugarer(ModuleEnvironment environment) {
    expression = ExpressionDesugarer();
    pattern = PatternDesugarer(environment, expression);
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
    List<FormalParameter> parameters0 = new List<FormalParameter>();
    for (int i = 0; i < decl.parameters.length; i++) {
      Pattern parameter = decl.parameters[i];
    }

    // Desugar the body.
    frame.expression = decl.body;

    return LetFunction(
        decl.signature, decl.binder, parameters0, frame, decl.location);
  }
}

class PatternDesugarer {
  final ExpressionDesugarer expression;
  final ModuleEnvironment environment;

  PatternDesugarer(this.environment, this.expression);

  Binder freshBinder(TopModule origin, Datatype type) {
    Binder xb = Binder.fresh(origin);
    xb.type = type;
    return xb;
  }

  Binder freshBinderFor(Pattern pattern) {
    return freshBinder(pattern.origin, pattern.type);
  }

  Binder desugar(Pattern pattern, ScratchSpace space) {
    Binder xb = freshBinderFor(pattern);

    switch (pattern.tag) {
      // Literal patterns.
      case PatternTag.BOOL:
      case PatternTag.INT:
      case PatternTag.STRING:
        basePattern(xb, pattern, space);
        break;
      // Variable patterns.
      case PatternTag.WILDCARD:
      case PatternTag.VAR:
        break;
      // Compound patterns.
      case PatternTag.HAS_TYPE:
        break;
      case PatternTag.CONSTR:
        break;
      case PatternTag.TUPLE:
        break;
      default:
        unhandled("PatternDesugarer.desugar", pattern.tag);
    }

    return xb;
  }

  void basePattern(Binder xb, Pattern pattern, ScratchSpace space) {
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

    //
    Expression x = Variable(null /* TODO */);
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
  const ExpressionDesugarer();
}
