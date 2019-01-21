// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' hide DynamicType, Expression, Let;
import 'package:kernel/ast.dart' as kernel show DynamicType, Expression, Let;
import 'package:kernel/transformations/continuation.dart' as transform;

import '../ast/ast.dart';
import '../errors/errors.dart' show unhandled;
import '../module_environment.dart';
import '../typing/type_utils.dart' as typeUtils;

import 'platform.dart';

VariableDeclaration translateBinder(Binder binder) {
  VariableDeclaration v =
      VariableDeclaration(binder.toString()); // TODO translate type.
  binder.asKernelNode = v;
  return v;
}

VariableDeclaration translateFormalParameter(FormalParameter parameter) =>
    translateBinder(parameter.binder);

class KernelGenerator {
  final Platform platform;
  final ModuleEnvironment environment;
  ModuleKernelGenerator module;

  KernelGenerator(this.platform, ModuleEnvironment environment)
      : this.environment = environment {
    this.module =
        ModuleKernelGenerator(platform, environment, new DartTypeGenerator());
  }

  Component compile(List<TopModule> modules) {
    // Compile each module separately.
    List<Library> libraries = new List<Library>();
    Procedure main;
    Library mainLib;
    for (int i = 0; i < modules.length; i++) {
      TopModule module0 = modules[i];
      Library library = module.compile(module0);

      // Virtual modules may compile to "null".
      if (library != null) {
        libraries.add(library);

        // Remember the latest main procedure and its enclosing library.
        if (module0.hasMain) {
          main = (module0.main as LetFunction).asKernelNode;
          mainLib = library;
        }
      }
    }

    // Compile the main procedure.
    if (main != null && mainLib != null) {
      main = new MainProcedureKernelGenerator(platform).compile(main);
      mainLib.procedures.add(main);
    }

    // Put everything together.
    Component component = compose(main, libraries, platform.platform);
    return component;
  }

  Component compose(
      Procedure main, List<Library> libraries, Component platform) {
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

    if (main != null) {
      platform.mainMethodName = main.reference;
    }

    return platform;
  }
}

class MainProcedureKernelGenerator {
  final Platform platform;

  MainProcedureKernelGenerator(this.platform);

  Procedure compile(Procedure mainProcedure) {
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
    kernel.Expression readBytesAsSync = MethodInvocation(
        construct(fileCls, Arguments(<kernel.Expression>[VariableGet(file)]),
            isFactory: true),
        Name("readAsBytesSync"),
        Arguments.empty());
    Statement readComponent = ExpressionStatement(MethodInvocation(
        construct(
            binaryBuilder, Arguments(<kernel.Expression>[readBytesAsSync])),
        Name("readSingleFileComponent"),
        Arguments(<kernel.Expression>[VariableGet(component)])));

    //VariableDeclaration componentArg = VariableDeclaration("componentArg");
    kernel.Expression entryPoint = VariableGet(component); // MethodInvocation(
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
            construct(
                fileCls,
                Arguments(
                    <kernel.Expression>[StringLiteral("transformed.dill")]),
                isFactory: true),
            Name("openWrite"),
            Arguments.empty()));

    Class binaryPrinter = platform.getClass(PlatformPathBuilder.kernel
        .library("ast_to_binary")
        .target("BinaryPrinter")
        .build());
    Statement writeComponent = ExpressionStatement(MethodInvocation(
        construct(
            binaryPrinter, Arguments(<kernel.Expression>[VariableGet(sink)])),
        Name("writeComponentFile"),
        Arguments(<kernel.Expression>[VariableGet(component)])));

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

  InvocationExpression subscript(kernel.Expression receiver, int index) =>
      MethodInvocation(receiver, Name("[]"),
          Arguments(<kernel.Expression>[IntLiteral(index)]));

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

class SegregationResult {
  final List<DatatypeDeclarations> datatypes;
  final List<Declaration> termDeclarations;
  final List<BoilerplateTemplate> templates;

  SegregationResult(this.datatypes, this.termDeclarations, this.templates);
}

class AlgebraicDatatypeKernelGenerator {
  final Platform platform;
  final ModuleEnvironment environment;
  final DartTypeGenerator type;
  final Supertype objectType;
  final SuperInitializer objectInitializer;

  AlgebraicDatatypeKernelGenerator(
      Platform platform, this.environment, this.type)
      : this.platform = platform,
        this.objectType =
            Supertype(platform.coreTypes.objectClass, const <DartType>[]),
        this.objectInitializer = SuperInitializer(
            platform.coreTypes.objectClass.constructors[0], Arguments.empty());

  List<Class> compile(DatatypeDeclarations datatypes) {
    // Process each datatype declaration.
    List<Class> classes;
    for (int i = 0; i < datatypes.declarations.length; i++) {
      DatatypeDescriptor descriptor = datatypes.declarations[i];
      List<Class> result = datatype(descriptor);
      if (result != null) {
        classes ??= new List<Class>();
        classes.addAll(result);
      }
    }

    return classes;
  }

  List<Class> datatype(DatatypeDescriptor descriptor) {
    List<Class> classes = new List<Class>();
    // 1) Generate an abstract class for the type.
    Class typeClass = typeConstructor(descriptor.binder, descriptor.parameters);
    // 2) Generate a subclass of the aforementioned class for each data constructor.
    List<Class> dataClasses =
        dataConstructors(descriptor.constructors, typeClass);
    // 3) Generate a visitor class, and attach accept methods to the interface
    // class and data classes.
    Class visitorClass = visitorInterface(typeClass, dataClasses);
    // 4) Generate a match closure class.
    Class matchClosureClass = matchClosureInterface(typeClass, dataClasses);
    // 5) Generate an eliminator class.
    Class eliminatorClass =
        eliminator(typeClass, dataClasses, visitorClass, matchClosureClass);
    classes.add(typeClass);
    classes.add(visitorClass);
    classes.add(matchClosureClass);
    classes.add(eliminatorClass);
    classes.addAll(dataClasses);
    return classes;
  }

  Class eliminator(Class typeClass, List<Class> dataClasses, Class visitor,
      Class matchClosure) {
    // Visitor implementation.
    List<TypeParameter> typeParameters = visitor.typeParameters.sublist(0);
    List<DartType> typeArguments = typeArgumentsOf(typeParameters);
    Supertype supertype = Supertype(visitor, typeArguments);

    // A field for storing the eliminatee.
    DartType matchClosureType = InterfaceType(matchClosure, typeArguments);
    Field match = Field(Name("match"), type: matchClosureType, isFinal: true);

    // Class template.
    Class cls = Class(
        name: "${typeClass.name}Eliminator",
        typeParameters: typeParameters,
        supertype: supertype,
        fields: <Field>[match],
        isAbstract: false);

    // Create the constructor.
    VariableDeclaration parameter =
        VariableDeclaration("match", type: matchClosureType);
    List<Initializer> initializers = <Initializer>[
      FieldInitializer(match, VariableGet(parameter)),
      SuperInitializer(visitor.constructors[0], Arguments.empty())
    ];
    FunctionNode funNode = FunctionNode(EmptyStatement(),
        positionalParameters: <VariableDeclaration>[parameter],
        returnType: InterfaceType(cls, typeArguments));
    Constructor clsConstructor = Constructor(funNode,
        name: Name(""), initializers: initializers, isSynthetic: true);

    // Attach the constructor.
    cls.constructors.add(clsConstructor);

    // Create the visit methods.
    DartType resultType = typeArguments.last;
    for (int i = 0; i < dataClasses.length; i++) {
      Class dataClass = dataClasses[i];
      Procedure visitMethod =
          dataMethod(dataClass, resultType, "visit${dataClass.name}");
      // Build the body.
      VariableDeclaration node = visitMethod.function.positionalParameters[0];
      VariableDeclaration result =
          VariableDeclaration("result", type: resultType);

      // Match case invocation.
      kernel.Expression runCase = MethodInvocation(
          PropertyGet(ThisExpression(), match.name),
          Name("${dataClass.name}"),
          Arguments(<kernel.Expression>[VariableGet(node)]));
      kernel.Expression runDefaultCase = MethodInvocation(
          PropertyGet(ThisExpression(), match.name),
          Name("defaultCase"),
          Arguments(<kernel.Expression>[VariableGet(node)]));

      Block block = Block(<Statement>[
        ExpressionStatement(VariableSet(result, runCase)),
        IfStatement(
            Not(MethodInvocation(VariableGet(result), Name("=="),
                Arguments(<kernel.Expression>[NullLiteral()]))),
            ExpressionStatement(VariableSet(result, runDefaultCase)),
            EmptyStatement()),
        IfStatement(
            MethodInvocation(VariableGet(result), Name("=="),
                Arguments(<kernel.Expression>[NullLiteral()])),
            null /* TODO throw */,
            ReturnStatement(VariableGet(result)))
      ]);
    }

    return cls;
  }

  Class typeConstructor(Binder binder, List<Quantifier> qs) {
    // Generate type parameters.
    List<TypeParameter> typeParameters = typeParametersOf(qs);
    Class cls = Class(
        name: binder.toString(),
        isAbstract: true,
        typeParameters: typeParameters,
        supertype: objectType);
    return cls;
  }

  List<Class> dataConstructors(
      List<DataConstructor> constructors, Class parentClass) {
    List<Class> classes = new List<Class>();
    for (int i = 0; i < constructors.length; i++) {
      classes.add(dataConstructor(constructors[i], parentClass));
    }
    return classes;
  }

  Class dataConstructor(DataConstructor constructor, Class parentClass) {
    List<DartType> typeArguments = new List<DartType>();
    for (int i = 0; i < parentClass.typeParameters.length; i++) {
      typeArguments.add(TypeParameterType(parentClass.typeParameters[i]));
    }
    Supertype supertype = Supertype(parentClass, typeArguments);

    // Create the class template.
    Class cls = Class(
        name: constructor.binder.toString(),
        supertype: supertype,
        typeParameters: parentClass.typeParameters);

    // Create class fields, field initializers, and constructor parameters.
    List<Initializer> initializers = new List<Initializer>();
    List<VariableDeclaration> parameters = List<VariableDeclaration>();
    for (int i = 0; i < constructor.parameters.length; i++) {
      String name = "\$${i + 1}";
      DartType fieldType = type.compile(constructor.parameters[i]);
      Field field = Field(Name(name), type: fieldType, isFinal: true);
      cls.fields.add(field);

      VariableDeclaration parameter =
          VariableDeclaration(name, type: fieldType);
      parameters.add(parameter);

      FieldInitializer initializer =
          FieldInitializer(field, VariableGet(parameter));
      initializers.add(initializer);
    }

    // Create the class constructor.
    DartType returnType = InterfaceType(cls, typeArguments);
    FunctionNode funNode = FunctionNode(EmptyStatement(),
        positionalParameters: parameters, returnType: returnType);
    initializers.add(objectInitializer);
    Constructor clsConstructor = Constructor(funNode,
        name: Name(""), isSynthetic: true, initializers: initializers);

    // Attach the constructor to the class template.
    cls.constructors.add(clsConstructor);
    return cls;
  }

  Class interfaceClassTemplate(Class typeClass, String suffix,
      {bool isAbstract = true, Supertype supertype}) {
    // Create a fresh type parameter for the "return type" of the template.
    TypeParameter resultTypeParameter = TypeParameter(
        "\$R", const kernel.DynamicType(), const kernel.DynamicType());
    // Copy the type parameters from [typeClass] and add [resultTypeParameter]
    // to the tail.
    List<TypeParameter> typeParameters = typeClass.typeParameters.sublist(0)
      ..add(resultTypeParameter);

    // Class template.
    String name = "${typeClass.name}$suffix";
    Class cls = Class(
        name: name,
        typeParameters: typeParameters,
        supertype: supertype ?? objectType,
        isAbstract: isAbstract);

    // Create the default constructor.
    DartType returnType = InterfaceType(cls, typeArgumentsOf(typeParameters));
    FunctionNode funNode =
        FunctionNode(EmptyStatement(), returnType: returnType);
    Constructor clsConstructor = Constructor(funNode,
        name: Name(""),
        isSynthetic: true,
        initializers: <Initializer>[objectInitializer]);

    // Attach the default constructor.
    cls.constructors.add(clsConstructor);

    return cls;
  }

  Class matchClosureInterface(Class typeClass, List<Class> dataClasses) {
    // Match closure interface.
    Class matchClosure = interfaceClassTemplate(typeClass, "MatchClosure");
    TypeParameter resultTypeParameter = matchClosure.typeParameters.last;

    // Add a method for each data constructor.
    DartType resultType = TypeParameterType(resultTypeParameter);
    for (int i = 0; i < dataClasses.length; i++) {
      Class dataClass = dataClasses[i];
      Procedure method = dataMethod(dataClass, resultType, dataClass.name);
      matchClosure.procedures.add(method);
    }

    // Add a method for default / catch-all cases.
    matchClosure.procedures
        .add(dataMethod(typeClass, resultType, "defaultCase"));
    return matchClosure;
  }

  Class visitorInterface(Class typeClass, List<Class> dataClasses) {
    // Visitor interface.
    Class visitor = interfaceClassTemplate(typeClass, "Visitor");
    TypeParameter resultTypeParameter = visitor.typeParameters.last;

    // Add an accept method to [typeClass] and [dataClasses].
    DartType visitorResultType = TypeParameterType(resultTypeParameter);
    for (int i = -1; i < dataClasses.length; i++) {
      Class cls;
      if (i < 0) {
        cls = typeClass;
      } else {
        cls = dataClasses[i];
      }

      // Construct a visit method signature for [cls] (only if [cls] is a data
      // class).
      Procedure visitInterfaceTarget;
      if (!identical(cls, typeClass)) {
        // Each visit method has return type [R], where [R] is a class-wide type
        // parameter.
        String name = "visit${cls.name}";
        visitInterfaceTarget = dataMethod(cls, visitorResultType, name);
        visitor.procedures.add(visitInterfaceTarget);
      }

      // Construct and attach an accept method.
      cls.procedures.add(acceptMethod(visitor, visitInterfaceTarget, cls,
          isAbstract: identical(cls, typeClass)));
    }
    return visitor;
  }

  Procedure acceptMethod(
      Class visitor, Procedure interfaceTarget, Class dataClass,
      {bool isAbstract = false}) {
    TypeParameter resultTypeParameter = TypeParameter(
        "\$R", const kernel.DynamicType(), const kernel.DynamicType());

    List<DartType> typeArguments = typeArgumentsOf(visitor.typeParameters);
    TypeParameterType visitorResultType =
        TypeParameterType(resultTypeParameter);
    typeArguments.add(visitorResultType);

    VariableDeclaration visitorParameter =
        VariableDeclaration("v", type: InterfaceType(visitor, typeArguments));

    Statement body;
    if (isAbstract) {
      // R accept<R>(Visitor<A,...,R> v);
      body = EmptyStatement();
    } else {
      // R accept<R>(Visitor<A,...,R> v) => v.visitNode<R>(this);
      String targetVisitMethod = "visit${dataClass.name}";
      body = ReturnStatement(MethodInvocation(
          VariableGet(visitorParameter),
          Name(targetVisitMethod),
          Arguments(<kernel.Expression>[ThisExpression()]),
          interfaceTarget));
    }

    FunctionNode funNode = FunctionNode(body,
        positionalParameters: <VariableDeclaration>[visitorParameter],
        returnType: visitorResultType,
        typeParameters: <TypeParameter>[resultTypeParameter]);

    return Procedure(Name("accept"), ProcedureKind.Method, funNode,
        isAbstract: isAbstract);
  }

  Procedure dataMethod(Class cls, DartType resultType, String name,
      {bool isAbstract = false}) {
    // Create the method parameter.
    DartType nodeType = InterfaceType(cls, typeArgumentsOf(cls.typeParameters));
    VariableDeclaration parameter = VariableDeclaration("node", type: nodeType);

    // Create the method function node and procedure.
    FunctionNode funNode = FunctionNode(ReturnStatement(NullLiteral()),
        positionalParameters: <VariableDeclaration>[parameter],
        returnType: resultType);
    return Procedure(Name(name), ProcedureKind.Method, funNode,
        isAbstract: isAbstract);
  }

  // List<Procedure> visitMethodSignatures(List<Class> dataClasses,
  //     Class visitorClass, TypeParameter resultTypeParameter) {
  //   // Create a dedicated visit method for each data class.
  //   List<Procedure> methods = List<Procedure>();
  //   // Each visit method has return type [R], where [R] is a class-wide type
  //   // parameter.
  //   DartType visitMethodReturnType = TypeParameterType(resultTypeParameter);
  //   for (int i = 0; i < dataClasses.length; i++) {
  //     Class dataClass = dataClasses[i];
  //     // Create the method parameter.
  //     DartType nodeType =
  //         InterfaceType(dataClass, typeArgumentsOf(dataClass.typeParameters));
  //     VariableDeclaration parameter =
  //         VariableDeclaration("node", type: nodeType);

  //     // Create the method function node and procedure.
  //     FunctionNode funNode = FunctionNode(EmptyStatement(),
  //         positionalParameters: <VariableDeclaration>[parameter],
  //         returnType: visitMethodReturnType);
  //     Name name = Name("visit${dataClass.name}");
  //     methods.add(
  //         Procedure(name, ProcedureKind.Method, funNode, isAbstract: true));
  //   }
  //   return methods;
  // }

  List<TypeParameter> typeParametersOf(List<Quantifier> qs) {
    List<TypeParameter> result = new List<TypeParameter>();
    for (int i = 0; i < qs.length; i++) {
      DartType bound = const kernel.DynamicType();
      TypeParameter parameter = TypeParameter(
          qs[i].binder.toString(), bound, const kernel.DynamicType());
      result.add(parameter);
    }
    return result;
  }

  List<TypeParameterType> typeArgumentsOf(List<TypeParameter> parameters) {
    List<TypeParameterType> arguments = new List<TypeParameterType>();
    for (int i = 0; i < parameters.length; i++) {
      arguments.add(TypeParameterType(parameters[i]));
    }
    return arguments;
  }
}

class ModuleKernelGenerator {
  final Platform platform;
  final ModuleEnvironment environment;
  final ExpressionKernelGenerator expression;
  final DartTypeGenerator type;
  final AlgebraicDatatypeKernelGenerator adt;

  ModuleKernelGenerator(
      Platform platform, ModuleEnvironment environment, DartTypeGenerator type)
      : this.environment = environment,
        this.platform = platform,
        this.type = type,
        this.expression =
            ExpressionKernelGenerator(platform, environment, type),
        this.adt =
            AlgebraicDatatypeKernelGenerator(platform, environment, type);

  Library compile(TopModule module) {
    // Do nothing for the (virtual) kernel module.
    if (environment.isKernelModule(module)) return null;

    // Target library.
    Library library;

    // Segregate the module members. As a side effect [segregate] dispenses of
    // members that have no runtime representation.
    SegregationResult segmod = segregate(module);

    // Firstly, process datatype declarations.
    for (int i = 0; i < segmod.datatypes.length; i++) {
      List<Class> classes = adt.compile(segmod.datatypes[i]);
      if (classes != null) {
        library ??= emptyLibrary(module.name);
        library.classes.addAll(classes);
      }
    }

    // Secondly, process boilerplate templates (as they depend on the datatype
    // declarations).
    for (int i = 0; i < segmod.templates.length; i++) {
      // TODO.
    }

    // Thirdly, process term declarations (as they depend on templates).
    for (int i = 0; i < segmod.termDeclarations.length; i++) {
      Declaration decl = segmod.termDeclarations[i];

      if (decl is DataConstructor) {
        // Performed exclusively for its side effects. A class for the
        // constructor has been generated earlier.
        dataConstructor(decl);
      } else if (decl is LetFunction) {
        Procedure procedure = function(decl);
        // Virtual functions may compile to [null].
        if (procedure != null) {
          library ??= emptyLibrary(module.name);
          library.procedures.add(procedure);
        }
      } else if (decl is ValueDeclaration) {
        Field field = value(decl);
        if (field != null) {
          library ??= emptyLibrary(module.name);
          library.fields.add(field);
        }
      } else {
        unhandled("ModuleKernelGenerator.compile", decl);
      }
    }

    return library;
  }

  SegregationResult segregate(TopModule module) {
    List<DatatypeDeclarations> datatypes = new List<DatatypeDeclarations>();
    List<Declaration> declarations =
        new List<Declaration>(); // term declarations.
    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member = module.members[i];
      switch (member.tag) {
        case ModuleTag.DATATYPE_DEFS:
          datatypes.add(member as DatatypeDeclarations);
          break;
        case ModuleTag.CONSTR:
        case ModuleTag.FUNC_DEF:
        case ModuleTag.VALUE_DEF:
          declarations.add(member as Declaration);
          break;
        default:
        // Ignore.
      }
    }
    return SegregationResult(datatypes, declarations, module.templates);
  }

  Library emptyLibrary(String name) {
    return Library(Uri(scheme: "file", path: "."), name: name);
  }

  void dataConstructor(DataConstructor constructor) {
    // TODO.
  }

  Procedure function(LetFunction fun) {
    if (fun.isVirtual) {
      assert(fun is LetVirtualFunction);
      return virtualFunction(fun as LetVirtualFunction);
    }

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

  Procedure virtualFunction(LetVirtualFunction fun) {
    switch (environment.originOf(fun.binder)) {
      case Origin.PRELUDE:
        switch (fun.binder.sourceName) {
          case "error":
            // Generate the function: A error<A>(String message) { throw message; }.
            DartType stringType =
                InterfaceType(platform.coreTypes.stringClass, <DartType>[]);
            VariableDeclaration parameter =
                VariableDeclaration("message", type: stringType);
            FunctionNode funNode = FunctionNode(
                ExpressionStatement(Throw(VariableGet(parameter))),
                positionalParameters: <VariableDeclaration>[parameter],
                returnType: const kernel
                    .DynamicType()); // TODO return TypeParameterType(A) instead.
            Procedure node = Procedure(
                Name(fun.binder.toString()), ProcedureKind.Method, funNode,
                isStatic: true);
            // Store the node.
            fun.asKernelNode = node;
            return node;
            break;
          case "print":
            // Find the appropriate Kernel node the print function.
            PlatformPath path =
                PlatformPathBuilder.core.target("print").build();
            // Store the node.
            fun.asKernelNode = platform.getProcedure(path);
            break;
          case "iterate":
            // Generate the function:
            // A iterate<A>(int n, A Function(A) f, A z) {
            //   A x = z;
            //   for (int i = 0; i < n; i++) x = f(x);
            //   return x;
            // }.

            // The arguments.
            TypeParameter a = TypeParameter(
                "A",
                InterfaceType(platform.coreTypes.objectClass, <DartType>[]),
                const kernel.DynamicType());
            DartType intType =
                InterfaceType(platform.coreTypes.intClass, <DartType>[]);
            VariableDeclaration ndecl = VariableDeclaration("n", type: intType);
            DartType fnType = FunctionType(
                <DartType>[TypeParameterType(a)], TypeParameterType(a));
            VariableDeclaration fdecl = VariableDeclaration("f", type: fnType);
            VariableDeclaration zdecl =
                VariableDeclaration("z", type: TypeParameterType(a));

            // The body.
            VariableDeclaration xdecl = VariableDeclaration("x",
                type: TypeParameterType(a), initializer: VariableGet(zdecl));
            VariableDeclaration idecl = VariableDeclaration("i",
                type: intType, initializer: IntLiteral(0));
            kernel.Expression condition = MethodInvocation(VariableGet(idecl),
                Name("<"), Arguments(<kernel.Expression>[VariableGet(ndecl)]));
            kernel.Expression update = VariableSet(
                idecl,
                MethodInvocation(VariableGet(idecl), Name("+"),
                    Arguments(<kernel.Expression>[IntLiteral(1)])));
            Statement loopBody = ExpressionStatement(VariableSet(
                xdecl,
                MethodInvocation(VariableGet(fdecl), Name("call"),
                    Arguments(<kernel.Expression>[VariableGet(xdecl)]))));
            ForStatement loop = ForStatement(<VariableDeclaration>[idecl],
                condition, <kernel.Expression>[update], loopBody);
            Block body = Block(
                <Statement>[xdecl, loop, ReturnStatement(VariableGet(xdecl))]);

            // The function node.
            FunctionNode funNode = FunctionNode(body,
                positionalParameters: <VariableDeclaration>[
                  ndecl,
                  fdecl,
                  zdecl
                ],
                returnType: TypeParameterType(a));

            // The procedure node.
            Procedure node = Procedure(
                Name(fun.binder.toString()), ProcedureKind.Method, funNode,
                isStatic: true);

            // Store the node.
            fun.asKernelNode = node;
            return node;
            break;
          default: // Ignore.
        }
        break;
      case Origin.STRING:
      case Origin.DART_LIST:
        // Ignore.
        break;
      default:
        unhandled("ModuleKernelGenerator.virtualFunction",
            environment.originOf(fun.binder));
    }
    return null;
  }

  Field value(ValueDeclaration val) {
    if (val.isVirtual) {
      throw "Compilation of virtual values has not yet been implemented.";
    }

    // Build the [Field] node.
    DartType valueType = type.compile(val.type);
    Field node = Field(Name(val.binder.toString()),
        initializer: expression.compile(val.body), type: valueType);

    // Store the node.
    val.asKernelNode = node;
    return node;
  }
}

class ExpressionKernelGenerator {
  final ModuleEnvironment environment;
  final Platform platform;
  final InvocationKernelGenerator invoke;
  final DartTypeGenerator type;

  ExpressionKernelGenerator(
      this.platform, ModuleEnvironment environment, DartTypeGenerator type)
      : this.environment = environment,
        this.invoke = InvocationKernelGenerator(environment, type),
        this.type = type;

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
            type.compile(ifexp.type));
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
        Project proj = exp as Project;
        return PropertyGet(compile(proj.receiver), Name("\$${proj.label}"));
        break;
      case ExpTag.TUPLE:
        return tuple(exp as Tuple);
        break;
      case ExpTag.TYPE_ASCRIPTION:
        return compile((exp as TypeAscription).exp);
        break;
      // Interesting cases.
      case ExpTag.APPLY:
        return apply(exp as Apply);
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
      } else if (environment.isPrimitive(v.binder)) {
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
      // function expression. Consequently, every data constructor and some
      // primitive function must be eta expanded when used a value.
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
    DartType returnType = type.compile(typeUtils.codomain(fnType));
    List<TypeParameter> typeParameters = <TypeParameter>[];

    return FunctionNode(body0,
        positionalParameters: parameters0,
        returnType: returnType,
        typeParameters: typeParameters);
  }

  kernel.Expression tuple(Tuple tuple) {
    throw "Not yet implemented.";
  }

  kernel.Expression getVariable(Variable v) {
    // To retain soundness, some primitive must be eta expanded when used as a
    // return value or as an input to a higher-order function.
    if (environment.isPrimitive(v.binder) && requiresEtaExpansion(v.binder)) {
      return etaPrimitive(v.binder);
    }

    if (environment.isGlobal(v.binder)) {
      Object d = v.declarator;
      return d is KernelNode
          ? StaticGet(d.asKernelNode)
          : throw "Logical error: expected kernel node.";
    } else {
      return VariableGet(v.binder.asKernelNode);
    }
  }

  FunctionExpression etaPrimitive(Binder primitiveBinder) {
    Declaration d = primitiveBinder.bindingOccurrence;
    if (d is LetFunction) {
      return invoke.eta(d);
    } else {
      throw "Logical error: Cannot eta expand primitive non-functions.";
    }
  }

  bool requiresEtaExpansion(Binder b) {
    switch (environment.originOf(b)) {
      case Origin.PRELUDE:
        switch (b.sourceName) {
          case "&&":
          case "||":
          case "+":
          case "-":
          case "/":
          case "*":
          case "mod":
          case "int-eq?":
          case "int-greater?":
          case "int-less?":
            return true;
            break;
          default:
            return false;
        }
        break;
      // All primitive functions from the String and Dart-List modules require
      // eta expansion when passed as an argument or returned from a function.
      case Origin.STRING:
      case Origin.DART_LIST:
        return true;
      default:
        return false;
    }
  }
}

class InvocationKernelGenerator {
  final ModuleEnvironment environment;
  final DartTypeGenerator type;

  InvocationKernelGenerator(this.environment, this.type);

  // TODO include argument types as a parallel list?
  kernel.Expression primitive(
      Binder binder, List<kernel.Expression> arguments) {
    // Determine which kind of primitive [binder] points to.
    if (binder.bindingOccurrence is DataConstructor) {
      // Delegate to [constructor].
      return constructor(binder.bindingOccurrence, arguments,
          isPrimitive: true);
    }

    // Some primitive functions have a direct encoding into Kernel.
    switch (environment.originOf(binder)) {
      case Origin.PRELUDE:
        // Short-circuiting boolean operations.
        switch (binder.sourceName) {
          case "&&":
          case "||":
            assert(arguments.length == 2);
            return LogicalExpression(
                arguments[0], binder.sourceName, arguments[1]);
            break;
          // Integer operations.
          case "+":
          case "-":
          case "*":
          case "/":
          case "mod":
            // Binary integer operations needs to be treated specially. Let <>
            // denote a binary operator, then `(<> x y)' gets encoded as
            // `x.<>(y)'.
            assert(arguments.length == 2);
            // The division operator is named "~/" in Dart/Kernel, and the
            // modulo operator is named "%".
            String operatorName;
            if (binder.sourceName == "int-eq?") {
              operatorName = "==";
            } else if (binder.sourceName == "int-greater?") {
              operatorName = ">";
            } else if (binder.sourceName == "int-less?") {
              operatorName = "<";
            } else if (binder.sourceName == "/") {
              operatorName = "~/";
            } else if (binder.sourceName == "mod") {
              operatorName = "%";
            } else {
              operatorName = binder.sourceName;
            }

            return MethodInvocation(arguments[0], Name(operatorName),
                Arguments(arguments.sublist(1, 2)));
            break;
          default: // Ignore.
        }
        break;
      case Origin.STRING:
        switch (binder.sourceName) {
          case "concat":
            return StringConcatenation(arguments);
            break;
          // Binary operations.
          case "eq?":
          case "less?":
          case "greater?":
            // Same compilation strategy as for integer operations.
            assert(arguments.length == 2);
            String operatorName;
            if (binder.sourceName == "eq?") {
              operatorName = "==";
            } else if (binder.sourceName == "greater?") {
              operatorName = ">";
            } else {
              operatorName = "<";
            }

            return MethodInvocation(arguments[0], Name(operatorName),
                Arguments(arguments.sublist(1, 2)));
            break;
          case "length":
            assert(arguments.length == 1);
            return PropertyGet(arguments[0], Name("length"));
            break;
          default: // Ignore.
        }
        break;
      case Origin.DART_LIST:
        throw "Not yet implemented.";
        break;
      case Origin.KERNEL:
        throw "Logical error: $binder is a non-constructor originating from the virtual Kernel module.";
        break;
      case Origin.CUSTOM:
        throw "Logical error: $binder does not originate from a virtual module.";
        break;
      default:
        unhandled("InvocationKernelGenerator.primitive",
            environment.originOf(binder));
    }

    // Other primitive functions are treated just as top-level functions.
    if (binder.bindingOccurrence is LetFunction) {
      LetFunction fun = binder.bindingOccurrence;
      return static$(fun.asKernelNode, arguments);
    } else {
      throw "Cannot compile primitive application $binder $arguments.";
    }
  }

  InvocationExpression constructor(
      DataConstructor constructor, List<kernel.Expression> arguments,
      {bool isPrimitive = false}) {
    return null;
  }

  // Expects [receiver] to evaluate to a callable object.
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
    Datatype fnType = fun.type;
    List<kernel.Expression> args = List<kernel.Expression>();
    List<VariableDeclaration> params = List<VariableDeclaration>();
    List<Datatype> domain = typeUtils.domain(fnType);
    for (int i = 0; i < domain.length; i++) {
      DartType argtype = type.compile(domain[i]);
      VariableDeclaration param = VariableDeclaration("x$i", type: argtype);
      params.add(param);
      args.add(VariableGet(param));
    }

    DartType returnType = type.compile(typeUtils.codomain(fnType));

    FunctionNode node = FunctionNode(
        ReturnStatement(static$(fun.asKernelNode, args)),
        positionalParameters: params,
        returnType: returnType);
    return FunctionExpression(node);
  }
}

class DartTypeGenerator {
  DartType compile(Datatype type) => const kernel.DynamicType(); // TODO.
}
