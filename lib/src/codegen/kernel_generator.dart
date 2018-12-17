// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart';

import '../errors/errors.dart' show unhandled;

import 'ir.dart';
import 'platform.dart';

class KernelGenerator {
  final Platform platform;

  KernelGenerator(this.platform);

  Library compile(Module module) {
    List<Field> fields = new List<Field>(); // Top-level values.
    List<Procedure> procedures = new List<Procedure>(); // Top-level functions.
    // TODO include classes aswell.
    for (int i = 0; i < module.bindings.length; i++) {
      Member member = compileToplevelBinding(module.bindings[i]);
      if (member is Procedure) {
        procedures.add(member);
      } else if (member is Field) {
        fields.add(member);
      } else {
        unhandled("KernelGenerator.compile", module.bindings[i]);
      }
    }
    return null;
  }

  // Compilation of bindings.
  Member compileToplevelBinding(Binding binding) {
    switch (binding.tag) {
      case LET_FUN:
        return compileLetFun(binding as LetFun);
        break;
      case LET_VAL:
        return compileToplevelLetVal(binding as LetVal);
        break;
      default:
        unhandled("KernelGenerator.compileToplevelBinding", binding.tag);
    }

    return null;
  }

  Statement compileBinding(Binding binding) {
    switch (binding.tag) {
      case LET_FUN:
        throw "Function declaration below top-level.";
        break;
      case LET_VAL:
        return compileLetVal(binding as LetVal);
        break;
      default:
        unhandled("KernelGenerator.compileBinding", binding.tag);
    }

    return null;
  }

  Procedure compileLetFun(LetFun letfun) {
    ProcedureKind kind = ProcedureKind.Method;
    Name name = Name(letfun.binder.uniqueName);

    List<VariableDeclaration> parameters = new List<VariableDeclaration>();
    for (int i = 0; i < letfun.parameters.length; i++) {
      FormalParameter param = letfun.parameters[i];
      VariableDeclaration varDecl = VariableDeclaration(
          param.binder.uniqueName /* TODO: translate type. */);
      param.kernelNode = varDecl;
      parameters.add(varDecl);
    }

    Statement body = compileComputation(letfun.body);
    FunctionNode funNode = FunctionNode(body, positionalParameters: parameters);

    letfun.kernelNode = Procedure(name, kind, funNode, isStatic: true);
    return letfun.kernelNode;
  }

  Field compileToplevelLetVal(LetVal letval) {
    return null;
  }

  VariableDeclaration compileLetVal(LetVal letval) {
    return null;
  }

  // Compilation of computations.
  Block compileComputation(Computation comp) {
    List<Statement> statements = new List<Statement>();
    // Translate each binding.
    for (int i = 0; i < comp.bindings.length; i++) {
      Statement stmt = compileBinding(comp.bindings[i]);
      statements.add(stmt);
    }

    // Translate the tail computation.
    statements
        .add(ReturnStatement(compileTailComputation(comp.tailComputation)));

    return Block(statements);
  }

  // Compilation of tail computations.
  Expression compileTailComputation(TailComputation tc) {
    switch (tc.tag) {
      case APPLY: // InvocationExpression
        return compileApply(tc as Apply);
        break;
      case IF: // IfStatement
        throw "Not yet implemented.";
        break;
      case RETURN:
        throw "Not yet implemented.";
        break;
      default:
        unhandled("KernelGenerator.compileTailComputation", tc.tag);
    }
    return null;
  }

  InvocationExpression compileApply(Apply apply) {
    // Determine what kind of invocation to perform.
    if (apply.abstractor is Variable) {
      Variable v = apply.abstractor;
      if (v.declarator.bindingSite is LetFun) {
        LetFun fun = v.declarator.bindingSite;
        return compileStaticApply(fun.kernelNode, apply.arguments);
      } else if (v.declarator.bindingSite is PrimitiveFunction) {
        return compilePrimitiveApply(v.declarator.bindingSite, apply.arguments);
      } else {
        unhandled("KernelGenerator.compileApply", apply);
      }
    } else if (apply.abstractor is PrimitiveFunction) {
      return compilePrimitiveApply(apply.abstractor, apply.arguments);
    } else {
      unhandled("KernelGenerator.compileApply", apply);
    }
    return null; // Impossible!
  }

  Arguments compileArguments(List<Value> valueArguments) {
    // Translate each argument.
    List<Expression> arguments = new List<Expression>();
    for (int i = 0; i < valueArguments.length; i++) {
      arguments.add(compileValue(valueArguments[i]));
    }
    return Arguments(arguments);
  }

  StaticInvocation compilePrimitiveApply(
      PrimitiveFunction primitive, List<Value> valueArguments) {
    Arguments arguments = compileArguments(valueArguments);
    switch (primitive.binder.sourceName) {
      case "+":
        PlatformPath path =
            PlatformPathBuilder.core.library("num").target("+").build();
        Procedure plus = platform.getProcedure(path);
        return StaticInvocation(plus, arguments);
        break;
      case "-":
        PlatformPath path =
            PlatformPathBuilder.core.library("num").target("-").build();
        Procedure minus = platform.getProcedure(path);
        return StaticInvocation(minus, arguments);
        break;
      default:
        unhandled("KernelGenerator.compilePrimitiveApply",
            primitive.binder.sourceName);
    }
    return null; // Impossible!
  }

  StaticInvocation compileStaticApply(
          Procedure target, List<Value> valueArguments) =>
      StaticInvocation(target, compileArguments(valueArguments));

  // Compilation of values.
  Expression compileValue(Value w) {
    switch (w.tag) {
      case BOOL:
        BoolLit b = w;
        return BoolLiteral(b.value);
        break;
      case INT:
        IntLit n = w;
        return IntLiteral(n.value);
        break;
      case STRING:
        StringLit s = w;
        return StringLiteral(s.value);
        break;
      case VAR:
        return compileVariable(w as Variable);
        break;
      default:
        unhandled("KernelGenerator.compileValue", w.tag);
    }

    return null;
  }

  Expression compileVariable(Variable v) {
    // The variable may be either a reference to a 1) toplevel function, 2) primitive function, 3) toplevel
    // let, 4) local let, or 5) a formal parameter.

    if (v.declarator.bindingSite is LetFun) {
      // 1) Function.
      LetFun fun = v.declarator.bindingSite;
      // [v] is a reference to the function.
      return StaticGet(fun.kernelNode);
    } else if (v.declarator.bindingSite is PrimitiveFunction) {
      // 2) Primitive function.
      throw "not yet implemented.";
    } else if (v.declarator.bindingSite is LetVal) {
      // 3) or 4) let bound value.
      LetVal let = v.declarator.bindingSite;
      if (let.kernelNode is Field) {
        // 3) Toplevel value.
        Field field = let.kernelNode;
        return StaticGet(field);
      } else if (let.kernelNode is VariableDeclaration) {
        // 4) Local value.
        VariableDeclaration decl = let.kernelNode;
        return VariableGet(decl);
      } else {
        unhandled("KernelGenerator.compileVariable", let);
      }
    } else if (v.declarator.bindingSite is FormalParameter) {
      // 5) Formal parameter.
      FormalParameter param = v.declarator.bindingSite;
      return VariableGet(param.kernelNode);
    } else {
      unhandled("KernelGenerator.compileVariable", v.declarator.bindingSite);
    }

    return null; // Impossible!
  }
}
