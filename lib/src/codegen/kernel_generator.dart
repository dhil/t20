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

  Component compile(Module module) {
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

    Library library = Library(Uri(scheme: "app", path: "."),
        name: "t20lib", procedures: procedures, fields: fields);
    return Component(libraries: <Library>[library]);
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

    return null; // Impossible!
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

    return null; // Impossible!
  }

  Procedure compileLetFun(LetFun letfun) {
    ProcedureKind kind = ProcedureKind.Method;
    Name name = Name(letfun.binder.uniqueName);

    List<VariableDeclaration> parameters = new List<VariableDeclaration>();
    for (int i = 0; i < letfun.parameters.length; i++) {
      FormalParameter param = letfun.parameters[i];
      VariableDeclaration varDecl =
          localDeclaration(param.binder /* TODO: translate type. */);
      param.kernelNode = varDecl;
      parameters.add(varDecl);
    }

    Statement body = compileComputation(letfun.body);
    FunctionNode funNode = FunctionNode(body, positionalParameters: parameters);

    letfun.kernelNode = Procedure(name, kind, funNode, isStatic: true);
    return letfun.kernelNode;
  }

  Field compileToplevelLetVal(LetVal letval) {
    // Construct name.
    Name name = Name(letval.binder.uniqueName);
    // Compile the body.
    Expression body = compileTailComputation(letval.tailComputation);
    // Construct a field node.
    Field field = Field(name,
        initializer: body,
        type: const DynamicType() /* TODO */,
        isStatic: true);

    letval.kernelNode = field;
    return field;
  }

  VariableDeclaration compileLetVal(LetVal letval) {
    // Construct a variable declaration.
    VariableDeclaration varDecl =
        localDeclaration(letval.binder /* TODO: translate type */
            );
    letval.kernelNode = varDecl;
    // Compile the initialising expression.
    varDecl.initializer = compileTailComputation(letval.tailComputation);
    // Construct the initialiser.
    return varDecl;
  }

  // Compilation of computations.
  Block compileComputation(Computation comp) {
    List<Statement> statements = new List<Statement>();
    // Translate each binding.
    if (comp.bindings != null) {
      for (int i = 0; i < comp.bindings.length; i++) {
        Statement stmt = compileBinding(comp.bindings[i]);
        statements.add(stmt);
      }
    }

    // Translate the tail computation.
    Expression result = compileTailComputation(comp.tailComputation);
    // Insert a return statement.
    statements.add(ReturnStatement(result));

    return Block(statements);
  }

  // Compilation of tail computations.
  Expression compileTailComputation(TailComputation tc) {
    switch (tc.tag) {
      case APPLY: // InvocationExpression
        return compileApply(tc as Apply);
        break;
      case IF: // IfStatement
        If ifexpr = tc;
        return compileIf(ifexpr);
        break;
      case RETURN:
        Return ret = tc;
        return compileValue(ret.value);
        break;
      default:
        unhandled("KernelGenerator.compileTailComputation", tc.tag);
    }
    return null; // Impossible!
  }

  Expression compileIf(If ifthenelse) {
    // Decide whether to compile to expression form using the ternary operator ?
    // or statement form using if-then-else.
    Expression cond = compileValue(ifthenelse.condition);
    if (ifthenelse.isSimple) {
      // Construct a "conditional expression", i.e. "cond ? tt : ff".  Since the
      // conditional is "simple", we know that neither subtree introduces any
      // new bindings, therefore we can compile each branch as an expression.
      Expression tt =
          compileTailComputation(ifthenelse.thenBranch.tailComputation);
      Expression ff =
          compileTailComputation(ifthenelse.elseBranch.tailComputation);
      return ConditionalExpression(
          cond, tt, ff, const DynamicType() /* TODO proper typing. */);
    } else {
      // Since the conditional is complex (opposite of the vaguely defined
      // notion of being "simple") either branch may introduce new bindings
      // (i.e. statements) in the image of the translation. Therefore, we must
      // compile each branch as a block.
      Block tt = compileComputation(ifthenelse.thenBranch);
      Block ff = compileComputation(ifthenelse.elseBranch);

      // Construct the if node.
      IfStatement ifnode = IfStatement(cond, tt, ff);
      // ... now we got a statement, but we need to return an expression. The
      // standard way to "turn" a statement into an expression is to introduce
      // an application, where the abstractor is a nullary abstraction, whose
      // body is the statement.
      return force(thunk(ifnode));
    }
  }

  // Lifts a statement into the expression language.
  FunctionExpression thunk(Statement body,
      [DartType staticType = const DynamicType()]) {
    FunctionNode fun = FunctionNode(body, returnType: staticType);
    FunctionExpression abs = FunctionExpression(fun);
    return abs;
  }

  // Applies a thunk.
  InvocationExpression force(FunctionExpression thunk) {
    return MethodInvocation(thunk, Name("call"), Arguments.empty());
  }

  InvocationExpression compileApply(Apply apply) {
    // Determine what kind of invocation to perform.
    if (apply.abstractor is Variable) {
      Variable v = apply.abstractor;
      if (v.declarator.bindingSite is LetFun) {
        LetFun fun = v.declarator.bindingSite;
        return compileStaticApply(fun.kernelNode, apply.arguments);
      } else if (v.declarator.bindingSite is PrimitiveFunction) {
        return compileStaticApply(
            primitiveFunction(v.declarator.sourceName), apply.arguments);
      } else if (v.declarator.bindingSite is LetVal) {
        // Must be a function expression.
        LetVal letval = v.declarator.bindingSite;
        Expression receiver;
        if (letval.kernelNode is VariableDeclaration) {
          receiver = VariableGet(letval.kernelNode);
        } else if (letval.kernelNode is Field) {
          receiver = StaticGet(letval.kernelNode);
        } else {
          unhandled("KernelGenerator.compileApply", letval.kernelNode);
        }
        return compileLambdaApply(receiver, apply.arguments);
      } else {
        unhandled("KernelGenerator.compileApply", apply);
      }
    } else if (apply.abstractor is PrimitiveFunction) {
      PrimitiveFunction primitive = apply.abstractor;
      return compileStaticApply(
          primitiveFunction(primitive.binder.sourceName), apply.arguments);
    } else {
      unhandled("KernelGenerator.compileApply", apply);
    }
    return null; // Impossible!
  }

  MethodInvocation compileLambdaApply(
      Expression lambda, List<Value> valueArguments) {
    Arguments arguments = compileArguments(valueArguments);
    return MethodInvocation(lambda, Name("call"), arguments);
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
    return StaticInvocation(
        primitiveFunction(primitive.binder.sourceName), arguments);
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

    return null; // Impossible!
  }

  Expression compileVariable(Variable v) {
    // The variable may be either a reference to a 1) toplevel function, 2)
    // primitive function, 3) toplevel let, 4) local let, or 5) a formal
    // parameter.

    if (v.declarator.bindingSite is LetFun) {
      // 1) Function.
      LetFun fun = v.declarator.bindingSite;
      // [v] is a reference to the function.
      return StaticGet(fun.kernelNode);
    } else if (v.declarator.bindingSite is PrimitiveFunction) {
      // 2) Primitive function.
      return StaticGet(primitiveFunction(v.declarator.sourceName));
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
        unhandled("KernelGenerator.compileVariable", let.kernelNode);
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

  Procedure primitiveFunction(String primitiveName) {
    PlatformPathBuilder builder = PlatformPathBuilder.core;
    Procedure proc;
    switch (primitiveName) {
      case "+":
        PlatformPath path = builder.library("num").target("+").build();
        Procedure plus = platform.getProcedure(path);
        proc = plus;
        break;
      case "-":
        PlatformPath path = builder.library("num").target("-").build();
        Procedure minus = platform.getProcedure(path);
        proc = minus;
        break;
      case "print":
        PlatformPath path = builder.target("print").build();
        proc = platform.getProcedure(path);
        break;
      case "int-eq?":
        PlatformPath path = builder.library("num").target("==").build();
        proc = platform.getProcedure(path);
        break;
      case "string-eq?":
        PlatformPath path = builder.library("String").target("==").build();
        proc = platform.getProcedure(path);
        break;
      case "bool-eq?":
        PlatformPath path = builder.library("Object").target("==").build();
        proc = platform.getProcedure(path);
        break;
      default:
        unhandled("KernelGenerator.compilePrimitiveApply", primitiveName);
    }

    // TODO check for null?
    return proc;
  }

  VariableDeclaration localDeclaration(TypedBinder binder,
          [DartType staticType = const DynamicType()]) =>
      VariableDeclaration(binder.uniqueName, type: staticType);
}
