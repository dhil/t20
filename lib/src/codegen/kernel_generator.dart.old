// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart';
import 'package:kernel/transformations/continuation.dart' as transform;

import '../errors/errors.dart' show unhandled;

import 'ir.dart';
import 'platform.dart';

class KernelGenerator {
  final Platform platform;

  KernelGenerator(this.platform);

  Component compile(Module module) {
    //print("${module.toString()}");
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

    Component component = platform.platform;

    Procedure mainProcedure;
    if (module.hasMain) {
      mainProcedure = main(module.main.kernelNode);
      procedures.add(mainProcedure);
    }
    Library library = Library(Uri(scheme: "file", path: "."),
        name: "t20app", procedures: procedures, fields: fields);
    library.parent = component;
    CanonicalName name = library.reference.canonicalName;
    if (name != null && name.parent != component.root) {
      component.root.adoptChild(name);
    }

    component.computeCanonicalNamesForLibrary(library);
    component.libraries.add(library);

    if (mainProcedure != null) {
      component.mainMethodName = mainProcedure.reference;
    }

    return component;
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

  Procedure main(Procedure mainProcedure) {
    // Generates:
    //   void main(List<String> args) async {
    //     String file = args[0];
    //     Component c  = Component();
    //     BinaryBuilder(File(file).readAsBytesSync()).readSingleFileComponent(c);
    //     c = entryPoint(c);
    //     IOSink sink = File("transformed.dill").openWrite();
    //     BinaryPrinter(sink).writeComponentFile(c);
    //     await sink.flush();
    //     await sink.close();
    //   }

    Class fileCls = platform.getClass(
        PlatformPathBuilder.dart.library("io").target("File").build());

    VariableDeclaration args = VariableDeclaration("args",
        type: InterfaceType(platform.coreTypes.listClass,
            <DartType>[InterfaceType(platform.coreTypes.stringClass)]));
    VariableDeclaration file = VariableDeclaration("file0",
        initializer: subscript(VariableGet(args), 0),
        type: InterfaceType(platform.coreTypes.stringClass));

    Class componentCls = platform.getClass(
        PlatformPathBuilder.kernel.library("ast").target("Component").build());
    VariableDeclaration component = VariableDeclaration("component",
        type: InterfaceType(componentCls),
        initializer: construct(componentCls, Arguments.empty()));

    Class binaryBuilder = platform.getClass(PlatformPathBuilder.kernel
        .library("ast_from_binary")
        .target("BinaryBuilder")
        .build());
    Expression readBytesAsSync = MethodInvocation(
        construct(fileCls, Arguments(<Expression>[VariableGet(file)]),
            isFactory: true),
        Name("readAsBytesSync"),
        Arguments.empty());
    Statement readComponent = ExpressionStatement(MethodInvocation(
        construct(binaryBuilder, Arguments(<Expression>[readBytesAsSync])),
        Name("readSingleFileComponent"),
        Arguments(<Expression>[VariableGet(component)])));

    //VariableDeclaration componentArg = VariableDeclaration("componentArg");
    Expression entryPoint = VariableGet(component); // MethodInvocation(
    // FunctionExpression(FunctionNode(
    //     ReturnStatement(VariableGet(componentArg)),
    //     positionalParameters: <VariableDeclaration>[componentArg])),
    // Name("call"),
    // Arguments(<Expression>[VariableGet(componentArg)]));

    // c = entryPoint(c);
    Statement runTransformation =
        ExpressionStatement(StaticInvocation(mainProcedure, Arguments.empty()));
        //    ExpressionStatement(VariableSet(component, entryPoint));

    // Class ioSink = platform.getClass(
    //     PlatformPathBuilder.dart.library("io").target("IOSink").build());
    VariableDeclaration sink = VariableDeclaration("sink",
        initializer: MethodInvocation(
            construct(fileCls,
                Arguments(<Expression>[StringLiteral("transformed.dill")]),
                isFactory: true),
            Name("openWrite"),
            Arguments.empty()));

    Class binaryPrinter = platform.getClass(PlatformPathBuilder.kernel
        .library("ast_to_binary")
        .target("BinaryPrinter")
        .build());
    Statement writeComponent = ExpressionStatement(MethodInvocation(
        construct(binaryPrinter, Arguments(<Expression>[VariableGet(sink)])),
        Name("writeComponentFile"),
        Arguments(<Expression>[VariableGet(component)])));

    Statement flush = ExpressionStatement(AwaitExpression(
        MethodInvocation(VariableGet(sink), Name("flush"), Arguments.empty())));
    Statement close = ExpressionStatement(AwaitExpression(
        MethodInvocation(VariableGet(sink), Name("close"), Arguments.empty())));

    // Construct the main procedure.
    Procedure main = Procedure(
        Name("main"),
        ProcedureKind.Method,
        FunctionNode(
            Block(<Statement>[
              file,
              component,
              sink,
              readComponent,
              runTransformation,
              writeComponent,
              flush,
              close
            ]),
            positionalParameters: <VariableDeclaration>[args],
            returnType: const VoidType(),
            asyncMarker: AsyncMarker.Async),
        isStatic: true);
    main = transform.transformProcedure(platform.coreTypes, main);

    return main;
  }

  InvocationExpression subscript(Expression receiver, int index) =>
      MethodInvocation(
          receiver,
          Name("[]"),
          Arguments(<Expression>[IntLiteral(index)]));

  InvocationExpression construct(Class cls, Arguments arguments,
      {Name constructor, bool isFactory: false}) {
    if (constructor == null) constructor = Name("");
    // Lookup the constructor.
    if (isFactory) {
      for (int i = 0; i < cls.procedures.length; i++) {
        Procedure target = cls.procedures[i];
        if (target.kind == ProcedureKind.Factory &&
            target.name.name == constructor.name) {
          // Construct the invocation expression.
          return StaticInvocation(target, arguments);
        }
      }
    } else {
      for (int i = 0; i < cls.constructors.length; i++) {
        Constructor target = cls.constructors[i];
        if (target.name.name == constructor.name) {
          // Construct the invocation expression.
          return ConstructorInvocation(target, arguments);
        }
      }
    }

    throw isFactory
        ? "No such factory constructor '$constructor' in $cls."
        : "No such factory constructor '$constructor' in $cls.";
  }
}
