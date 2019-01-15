// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' hide DynamicType, Expression, Let;
import 'package:kernel/ast.dart' as kernel show DynamicType, Expression, Let;
import 'package:kernel/transformations/continuation.dart' as transform;

import '../ast/ast.dart';
import '../errors/errors.dart' show unhandled;
import '../module_environment.dart';

import 'platform.dart';

// Archivist is a helper class for querying the origin of binders.
enum Origin { DART_LIST, KERNEL, PRELUDE, STRING, CUSTOM }

class Archivist {
  ModuleEnvironment environment;

  Archivist(this.environment);

  bool isKernelModule(TopModule module) =>
      identical(module.origin, environment.kernel);

  Origin originOf(Binder binder) {
    if (binder.origin == null)
      throw "Logical error: The binder ${binder} has no origin.";
    if (identical(binder.origin, environment.prelude)) return Origin.PRELUDE;
    if (identical(binder.origin, environment.kernel)) return Origin.KERNEL;
    if (identical(binder.origin, environment.dartList)) return Origin.DART_LIST;
    if (identical(binder.origin, environment.string)) return Origin.STRING;

    return Origin.CUSTOM;
  }

  bool isPrimitive(Binder binder) => originOf(binder) != Origin.CUSTOM;

  bool isGlobal(Binder binder) {
    if (binder.bindingOccurrence is LetFunction) {
      LetFunction fun = binder.bindingOccurrence;
      return identical(fun.binder, binder);
    }

    return binder.bindingOccurrence is ModuleMember;
  }

  bool isLocal(Binder binder) => !isGlobal(binder);
}

VariableDeclaration translateBinder(Binder binder) {
  VariableDeclaration v =
      VariableDeclaration(binder.toString()); // TODO translate type.
  binder.asKernelNode = v;
  return v;
}

VariableDeclaration translateFormalParameter(FormalParameter parameter) {
  return translateBinder(parameter.binder);
}

class KernelGenerator {
  final Platform platform;
  final Archivist archivist;
  ModuleKernelGenerator module;

  KernelGenerator(this.platform, ModuleEnvironment environment)
      : archivist = Archivist(environment) {
    this.module = ModuleKernelGenerator(platform, archivist);
  }

  Component compile(List<TopModule> modules) {
    List<Library> libraries = new List<Library>();
    Procedure main;
    for (int i = 0; i < modules.length; i++) {
      TopModule module0 = modules[i];
      Library library = module.compile(module0);
      if (library != null) {
        libraries.add(library);

        if (module0.hasMain) {
          main = ((module0.main) as LetFunction).asKernelNode; // TODO.
          // library.procedures.add(mainProcedure);
        }
      }
    }

    Component component = compose(main, libraries, platform.platform);
    return component;
  }

  Component compose(
      Procedure main, List<Library> libraries, Component platform) {
    if (main != null) {
      // TODO.
    }

    for (int i = 0; i < libraries.length; i++) {
      Library library = libraries[i];
      CanonicalName name = library.reference.canonicalName;
      if (name != null && name.parent != platform.root) {
        platform.root.adoptChild(name);
      } else {
        // TODO error?
      }

      platform.computeCanonicalNamesForLibrary(library);
      platform.libraries.add(library);
    }

    return platform;
  }
}

class ModuleKernelGenerator {
  Platform platform;
  Archivist archivist;
  ExpressionKernelGenerator expression;

  ModuleKernelGenerator(Platform platform, Archivist archivist) {
    this.archivist = archivist;
    this.platform = platform;
    expression = ExpressionKernelGenerator(platform, archivist);
  }

  Library compile(TopModule module) {
    // Do nothing for the (virtual) kernel module.
    if (archivist.isKernelModule(module)) return null;

    // Process each member.
    Library library = emptyLibrary(module.name);
    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member = module.members[i];
      switch (member.tag) {
        // No-ops.
        case ModuleTag.CONSTR:
        case ModuleTag.SIGNATURE:
        case ModuleTag.TYPENAME:
          // Ignore.
          break;
        case ModuleTag.DATATYPE_DEFS:
          // TODO.
          break;
        case ModuleTag.FUNC_DEF:
          Procedure procedure = function(member as LetFunction);
          if (procedure != null) {
            library.procedures.add(procedure);
          }
          break;
        case ModuleTag.VALUE_DEF:
          Field field = value(member as ValueDeclaration);
          if (field != null) {
            library.fields.add(field);
          }
          break;
        default:
          unhandled("ModuleKernelGenerator.compile", member.tag);
      }
    }
    return library;
  }

  Library emptyLibrary(String name) {
    return Library(Uri(scheme: "file", path: "."), name: name);
  }

  Procedure function(LetFunction fun) {
    // TODO check whether [fun] is virtual.

    // Build the function node.
    FunctionNode node =
        expression.functionNode(fun.parameters, fun.body, fun.type);
    // Build the procedure node.
    Name name = Name(fun.binder.toString());
    Procedure procedure =
        Procedure(name, ProcedureKind.Method, node, isStatic: true);
    // Store the procedure node.
    fun.asKernelNode = procedure;
    return procedure;
  }

  Field value(ValueDeclaration val) {
    // TODO check whether [val] is virtual.

    // Build the [Field] node.
    DartType type = const kernel.DynamicType(); // TODO.
    Field node = Field(Name(val.binder.toString()),
        initializer: expression.compile(val.body), type: type);

    // Store the node.
    val.asKernelNode = node;
    return node;
  }
}

class ExpressionKernelGenerator {
  final Archivist archivist;
  final Platform platform;
  final InvocationKernelGenerator invoke;

  ExpressionKernelGenerator(this.platform, this.archivist)
      : this.invoke = InvocationKernelGenerator();

  kernel.Expression compile(Expression exp) {
    switch (exp.tag) {
      // Literals.
      case ExpTag.BOOL:
        return BoolLiteral((exp as BoolLit).value);
        break;
      case ExpTag.INT:
        return IntLiteral((exp as IntLit).value);
        break;
      case ExpTag.STRING:
        return StringLiteral((exp as StringLit).value);
        break;
      // Local and global variables.
      case ExpTag.VAR:
        return getVariable(exp as Variable);
        break;
      // Homomorphisms (more or less).
      case ExpTag.IF:
        If ifexp = exp as If;
        return ConditionalExpression(
            compile(ifexp.condition),
            compile(ifexp.thenBranch),
            compile(ifexp.elseBranch),
            const kernel.DynamicType()); // TODO: translate type.
        break;
      case ExpTag.LET:
        DLet letexp = exp as DLet;
        VariableDeclaration v = translateBinder(letexp.binder);
        v.initializer = compile(letexp.body);
        return kernel.Let(v, compile(letexp.continuation));
        break;
      case ExpTag.LAMBDA:
        return lambda(exp as DLambda);
        break;
      case ExpTag.PROJECT:
        return project(exp as Project);
        break;
      case ExpTag.TUPLE:
        return tuple(exp as Tuple);
        break;
      // Interesting cases.
      case ExpTag.APPLY:
        return apply(exp as Apply);
        break;
      case ExpTag.TYPE_ASCRIPTION:
        throw "Not yet implemented.";
        break;
      default:
        unhandled("ExpressionKernelGenerator.compile", exp.tag);
    }

    return null; // Impossible!
  }

  kernel.Expression apply(Apply apply) {
    // There are several different kinds of applications:
    // 1) Constructor application.
    // 2) Primitive application.
    // 3) Static function application.
    // 4) Dynamic function application (e.g. lambda application).

    // Compile each argument.
    List<kernel.Expression> arguments = List<kernel.Expression>();
    for (int i = 0; i < apply.arguments.length; i++) {
      kernel.Expression exp = compile(apply.arguments[i]);
      arguments.add(exp);
    }

    // Determine which kind of application to perform, and delegate accordingly.
    if (apply.abstractor is Variable) {
      Variable v = apply.abstractor;
      if (v.declarator is DataConstructor) {
        return invoke.constructor(v.declarator, arguments);
      } else if (archivist.isPrimitive(v.binder)) {
        return invoke.primitive(v.binder, arguments);
      } else if (v.declarator is! LetFunction) {
        return invoke.dynamic$(compile(v), arguments);
      } else {
        return invoke.static$(
            (v.declarator as LetFunction).asKernelNode, arguments);
      }
    } else {
      // Note: Higher-order functions make it hard to statically determine the
      // application kind. Consider the following expression: `((f x) y)'. Here
      // the result of `(f x)' subsequently determines the application kind for
      // `(_ y)'. We cannot always know (statically) whether `(f x)' returns a
      // top-level function, a primitive function, a data constructor, or a
      // lambda abstraction. Therefore we conservatively treat it as a dynamic
      // function expression. Consequently, every bare top-level function, data
      // constructor, or primitive function must be eta expanded, i.e. wrapped
      // in a lambda abstraction.
      return invoke.dynamic$(compile(apply.abstractor), arguments);
    }
  }

  FunctionExpression lambda(DLambda lambda) {
    // Build the function node.
    FunctionNode node =
        functionNode(lambda.parameters, lambda.body, lambda.type);
    return FunctionExpression(node);
  }

  FunctionNode functionNode(
      List<FormalParameter> parameters, Expression body, Datatype fnType) {
    // Translate each parameter.
    List<VariableDeclaration> parameters0 =
        parameters.map(translateFormalParameter).toList();

    // Translate the [body].
    Statement body0 = Block(<Statement>[ReturnStatement(compile(body))]);

    // TODO translate [fnType] to extract return type and any type parameters.
    DartType returnType = const kernel.DynamicType();
    List<TypeParameter> typeParameters = <TypeParameter>[];

    return FunctionNode(body0,
        positionalParameters: parameters0,
        returnType: returnType,
        typeParameters: typeParameters);
  }

  kernel.Expression project(Project proj) {
    return PropertyGet(compile(proj.receiver), Name("\$${proj.label}"));
  }

  kernel.Expression tuple(Tuple tuple) {
    throw "Not yet implemented.";
  }

  kernel.Expression getVariable(Variable v) {
    // TODO selectively eta expand [v] if it is a primitive.
    if (archivist.isGlobal(v.binder)) {
      Object d = v.declarator;
      return d is KernelNode
          ? StaticGet(d.asKernelNode)
          : throw "Logical error: expected kernel node.";
    } else {
      return VariableGet(v.binder.asKernelNode);
    }
  }
}

class InvocationKernelGenerator {
  // TODO include argument types as a parallel list?
  kernel.Expression primitive(
      Binder binder, List<kernel.Expression> arguments) {
    // Determine which kind of primitive [binder] points to.
    if (binder.bindingOccurrence is DataConstructor) {
      // Delegate to [constructor].
      return constructor(binder.bindingOccurrence, arguments);
    }

    return null;
  }

  InvocationExpression constructor(
      DataConstructor constructor, List<kernel.Expression> arguments) {
    return null;
  }

  // Expects [receiver] to evaluate to a FunctionExpression (i.e. a lambda abstraction).
  MethodInvocation dynamic$(
      kernel.Expression receiver, List<kernel.Expression> arguments) {
    return MethodInvocation(receiver, Name("call"), Arguments(arguments));
  }

  StaticInvocation static$(
      Procedure procedure, List<kernel.Expression> arguments) {
    return StaticInvocation(procedure, Arguments(arguments));
  }

  // Eta expands a top-level function.
  FunctionExpression eta(LetFunction fun) {
    return null;
  }
}
