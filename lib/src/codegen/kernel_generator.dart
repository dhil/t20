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
import '../utils.dart' show Gensym;

import 'kernel_magic.dart';
import 'platform.dart';

typedef MethodBodyBuilder = Statement Function(VariableDeclaration);
typedef SuperInitializerBuilder = SuperInitializer Function(Class);
typedef FieldInitializerBuilder = Initializer Function(
    int, VariableDeclaration);

class VisitorBuilder {
  final Platform platform;
  VisitorBuilder(Platform platform) : this.platform = platform;

  // Class header.
  List<TypeParameter> typeParameters;
  VisitorBuilder typeParameter(TypeParameter typeParameter) {
    typeParameters ??= new List<TypeParameter>();
    typeParameters.add(typeParameter);
    return this;
  }

  VisitorBuilder manyTypeParameters(List<TypeParameter> typeParameters0) {
    if (typeParameters == null)
      typeParameters = typeParameters0;
    else
      typeParameters.addAll(typeParameters0);
    return this;
  }

  Supertype supertype;
  SuperInitializer superInitializer;
  VisitorBuilder parent(Class parent,
      {List<DartType> typeArguments = const <DartType>[],
      SuperInitializerBuilder superInitializer}) {
    if (typeArguments.length > 0 &&
        parent.typeParameters.length != typeArguments.length) {
      throw ArgumentError.value(typeArguments, "typeArguments",
          "The number of provided type arguments differs from the expectation");
    }

    // If no type arguments were provided, but the parent class is
    // parameterised, then fill the blanks with dynamic.
    if (typeArguments.length == 0 && parent.typeParameters.length > 0) {
      typeArguments = new List<DartType>();
      for (int i = 0; i < parent.typeParameters.length; i++) {
        typeArguments.add(const kernel.DynamicType());
      }
    }

    // Construct the super type.
    supertype = Supertype(parent, typeArguments);

    // Construct a super initializer.
    if (superInitializer == null) {
      // If no builder was provided, then attempt to pick the default constructor.
      SuperInitializer initializer;
      for (int i = 0; i < parent.constructors.length; i++) {
        Constructor constructor = parent.constructors[i];
        if (constructor.name.name.compareTo("") == 0) {
          if (constructor.function.requiredParameterCount == 0) {
            initializer = SuperInitializer(constructor, Arguments.empty());
            break;
          }
        }
      }

      if (initializer == null) {
        throw ArgumentError.value(parent, "parent",
            "The provided parent class has no default constructor with (positional) arity 0. Either provide a parent class with a default constructor or provide a super initializer builder.");
      }

      // Remember the initializer.
      this.superInitializer = initializer;
    } else {
      this.superInitializer = superInitializer(parent);
      if (this.superInitializer == null) {
        throw ArgumentError.value(superInitializer, "superInitializer",
            "The provided super initializer builder built a `null' initializer.");
      }
    }
    return this;
  }

  List<Field> fields;
  VisitorBuilder field(Field field, [Initializer initializer]) {
    fields ??= new List<Field>();
    fields.add(field);
    return this;
  }

  Constructor clsConstructor;
  VisitorBuilder constructor(
      {Name name,
      List<VariableDeclaration> parameters = const <VariableDeclaration>[],
      FieldInitializerBuilder field}) {
    if (name == null) name = Name("");
    FunctionNode funNode =
        FunctionNode(EmptyStatement(), positionalParameters: parameters);
    // Initializer list.
    List<Initializer> initializers;
    if (field != null) {
      initializers = new List<Initializer>();
      for (int i = 0; i < parameters.length; i++) {
        Initializer initializer = field(i, parameters[i]);
        if (initializer == null) {
          throw ArgumentError.value(field, "field",
              "The provided field initializer builder built a `null' initializer.");
        }
        initializers.add(initializer);
      }
    }
    clsConstructor = Constructor(funNode,
        name: name, isSynthetic: true, initializers: initializers);
    return this;
  }

  // Class body.
  List<Procedure> procedures;
  VisitorBuilder method(DartType returnType, DartType nodeType, String nodeName,
      {MethodBodyBuilder body,
      bool isAbstract = false,
      bool visitSuffix = true}) {
    procedures ??= new List<Procedure>();
    // Construct the method parameter.
    VariableDeclaration node = VariableDeclaration("node", type: nodeType);

    // Construct the body of function node.
    Statement body0;
    if (body == null) {
      body0 = ReturnStatement(NullLiteral());
    } else {
      body0 = body(node);
      if (body0 == null) {
        throw ArgumentError.value(body, "body",
            "The provided method body builder built a `null' body.");
      }
    }

    // Construct the function node and the procedure.
    FunctionNode funNode = FunctionNode(body0,
        positionalParameters: <VariableDeclaration>[node],
        returnType: returnType);

    String name = visitSuffix ? "visit$nodeName" : nodeName;
    Procedure method = Procedure(Name(name), ProcedureKind.Method, funNode,
        isAbstract: isAbstract);
    procedures.add(method);
    return this;
  }

  Class build(String className, {bool isAbstract = false}) {
    // If the no parent class was provided, then assume the parent is intended
    // to be "Object".
    if (identical(supertype, null)) {
      Class objectClass = platform.coreTypes.objectClass;
      supertype = Supertype(objectClass, const <DartType>[]);
      superInitializer =
          SuperInitializer(objectClass.constructors[0], Arguments.empty());
    }

    // If no constructor has been specified, then attempt to build the default
    // constructor.
    if (identical(clsConstructor, null)) {
      constructor();
    }

    // Build a class description.
    Class target = Class(
        name: className,
        isAbstract: isAbstract,
        typeParameters: typeParameters,
        supertype: supertype,
        fields: fields,
        procedures: procedures,
        constructors: <Constructor>[clsConstructor]);

    // Retrofit the return type of the constructor.
    DartType returnType = InterfaceType(target,
        typeParameters.map((TypeParameter p) => TypeParameterType(p)).toList());
    clsConstructor.function.returnType = returnType;

    return target;
  }
}

VariableDeclaration translateBinder(Binder binder, DartTypeGenerator type) {
  VariableDeclaration v =
      VariableDeclaration(binder.toString()); // TODO translate type.
  binder.asKernelNode = v;
  return v;
}

VariableDeclaration translateFormalParameter(
        FormalParameter parameter, DartTypeGenerator type) =>
    translateBinder(parameter.binder, type);

InvocationExpression subscript(kernel.Expression receiver, int index) =>
    MethodInvocation(receiver, Name("[]"),
        Arguments(<kernel.Expression>[IntLiteral(index)]));

class KernelGenerator {
  final bool demoMode;
  final Platform platform;
  final ModuleEnvironment environment;
  ModuleKernelGenerator module;

  KernelGenerator(Platform platform, ModuleEnvironment environment,
      {this.demoMode = false})
      : this.environment = environment,
        this.platform = platform {
    this.module = ModuleKernelGenerator(platform, environment,
        new KernelRepr(platform), new DartTypeGenerator());
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
      main = new MainProcedureKernelGenerator(platform)
          .compile(main, demoMode: demoMode);
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

  Procedure compile(Procedure mainProcedure, {bool demoMode = false}) {
    VariableDeclaration args = VariableDeclaration("args",
        type: InterfaceType(platform.coreTypes.listClass,
            <DartType>[InterfaceType(platform.coreTypes.stringClass)]));
    Statement body;
    if (demoMode) {
      body = demo(mainProcedure);
    } else {
      body = transformation(mainProcedure, args);
    }

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

    // Construct the main procedure.
    Procedure main = Procedure(
        Name("main"),
        ProcedureKind.Method,
        FunctionNode(body,
            positionalParameters: <VariableDeclaration>[args],
            returnType: const VoidType(),
            asyncMarker: AsyncMarker.Async),
        isStatic: true);
    main = transform.transformProcedure(platform.coreTypes, main);

    return main;
  }

  Statement demo(Procedure mainProcedure) {
    return ExpressionStatement(
        StaticInvocation(mainProcedure, Arguments.empty()));
  }

  Statement transformation(Procedure mainProcedure, VariableDeclaration args) {
    Class fileCls = platform.getClass(
        PlatformPathBuilder.dart.library("io").target("File").build());

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
    // kernel.Expression entryPoint = VariableGet(component); // MethodInvocation(
    // FunctionExpression(FunctionNode(
    //     ReturnStatement(VariableGet(componentArg)),
    //     positionalParameters: <VariableDeclaration>[componentArg])),
    // Name("call"),
    // Arguments(<Expression>[VariableGet(componentArg)]));

    // c = entryPoint(c);
    Statement runTransformation = ExpressionStatement(VariableSet(
        component,
        StaticInvocation(mainProcedure,
            Arguments(<kernel.Expression>[VariableGet(component)]))));
    //    ExpressionStatement(VariableSet(component, entryPoint));

    // Class ioSink = platform.getClass(
    //     PlatformPathBuilder.dart.library("io").target("IOSink").build());
    VariableDeclaration sink = VariableDeclaration("sink",
        initializer: MethodInvocation(
            construct(
                fileCls,
                Arguments(
                    <kernel.Expression>[StringLiteral("a.transformed.dill")]),
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

    return Block(<Statement>[
      file,
      component,
      sink,
      readComponent,
      runTransformation,
      writeComponent,
      flush,
      close
    ]);
  }

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

class AlgebraicDatatypeKernelGenerator {
  final Platform platform;
  final ModuleEnvironment environment;
  final KernelRepr magic;
  final DartTypeGenerator type;

  AlgebraicDatatypeKernelGenerator(
      Platform platform, this.environment, this.magic, this.type)
    : this.platform = platform;

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
    Class matchClosureClass =
        matchClosureInterface(typeClass, dataClasses, visitorClass);
    // 5) Generate an eliminator class.
    Class eliminatorClass =
        eliminator(typeClass, dataClasses, visitorClass, matchClosureClass);
    classes.add(typeClass);
    classes.add(visitorClass);
    classes.add(matchClosureClass);
    classes.add(eliminatorClass);
    classes.addAll(dataClasses);
    // Store the generated classes.
    descriptor.asKernelNode = typeClass;
    descriptor.eliminatorClass = eliminatorClass;
    descriptor.matchClosureClass = matchClosureClass;
    descriptor.visitorClass = visitorClass;
    return classes;
  }

  Class eliminator(Class typeClass, List<Class> dataClasses, Class visitor,
      Class matchClosure) {
    VisitorBuilder elim = VisitorBuilder(platform);

    // Compute the type parameters.
    List<TypeParameter> typeParameters =
        type.copyTypeParameters(visitor.typeParameters);

    // Add a field for storing the match closure.
    Field match = Field(Name("match"),
        type: InterfaceType(matchClosure, typeArgumentsOf(typeParameters)),
        isFinal: true);

    // Constructor.
    VariableDeclaration matchParam = VariableDeclaration("match",
        type: InterfaceType(matchClosure, typeArgumentsOf(typeParameters)));
    Initializer matchFieldInitializerBuilder(int _, VariableDeclaration v) =>
        FieldInitializer(match, VariableGet(v));

    // Create the visit methods.
    Statement visit(VariableDeclaration node) {
      // Construct the logic for matching on the [node].
      // try {
      //  return node.accept(match);
      // } on PatternMatchFailure catch (exn) {
      //    try {
      //      return match.defaultCase(node);
      //    } on PatternMatchFailure catch (_) {
      //      throw exn;
      //    }
      // }

      Class t20error =
          platform.getClass(PlatformPathBuilder.t20.target("T20Error").build());
      Class patternMatchFailure = platform.getClass(
          PlatformPathBuilder.t20.target("PatternMatchFailure").build());
      DartType exnType = InterfaceType(patternMatchFailure, const <DartType>[]);

      kernel.Expression match = PropertyGet(ThisExpression(), Name("match"));
      kernel.Expression runCase = MethodInvocation(VariableGet(node),
          Name("accept"), Arguments(<kernel.Expression>[match]));

      // Logic for running the default case.
      kernel.Expression runDefaultCase = MethodInvocation(
          match,
          Name("defaultCase"),
          Arguments(<kernel.Expression>[VariableGet(node)]));
      VariableDeclaration exn = VariableDeclaration("exn", type: exnType);
      ConstructorInvocation invokeT20error = ConstructorInvocation(
          t20error.constructors[0],
          Arguments(<kernel.Expression>[VariableGet(exn)]));
      Catch catchPatternMatchFailure = Catch(
          VariableDeclaration("_", type: exnType),
          ExpressionStatement(Throw(invokeT20error)),
          guard: exnType);
      TryCatch defaultGuard = TryCatch(
          ReturnStatement(runDefaultCase), <Catch>[catchPatternMatchFailure],
          isSynthetic: true);

      // Logic for running the constructor case.
      catchPatternMatchFailure = Catch(exn, defaultGuard, guard: exnType);
      TryCatch caseGuard = TryCatch(
          ReturnStatement(runCase), <Catch>[catchPatternMatchFailure],
          isSynthetic: true);

      return caseGuard;
    }

    List<TypeParameter> typeParameters0 =
        typeParameters.sublist(0, typeParameters.length - 1);
    for (int i = 0; i < dataClasses.length; i++) {
      Class dataClass = dataClasses[i];
      DartType nodeType =
          InterfaceType(dataClass, typeArgumentsOf(typeParameters0));
      DartType resultType = TypeParameterType(typeParameters.last);
      elim.method(resultType, nodeType, "${dataClass.name}", body: visit);
    }

    // Construct the eliminator class.
    Class eliminatorClass = elim
        .manyTypeParameters(typeParameters)
        .parent(visitor, typeArguments: typeArgumentsOf(typeParameters))
        .field(match)
        .constructor(parameters: <VariableDeclaration>[
      matchParam
    ], field: matchFieldInitializerBuilder).build(
            "${typeClass.name}Eliminator");

    return eliminatorClass;
  }

  Class typeConstructor(Binder binder, List<Quantifier> qs) {
    // Abuse the visitor builder to build a non-visitor class.
    VisitorBuilder builder = VisitorBuilder(platform);
    return builder
        .manyTypeParameters(typeParametersOf(qs))
        .build(binder.toString(), isAbstract: true);
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
    // Abuse the visitor builder to build a non-visitor class.
    VisitorBuilder dataCon = VisitorBuilder(platform);

    List<TypeParameter> typeParameters =
        type.copyTypeParameters(parentClass.typeParameters);

    // Create class fields, and constructor parameters.
    List<VariableDeclaration> parameters = new List<VariableDeclaration>();
    for (int i = 0; i < constructor.parameters.length; i++) {
      String name = "\$${i + 1}";

      DartType fieldType = type.compile(constructor.parameters[i]);
      Field field = Field(Name(name), type: fieldType, isFinal: true);
      dataCon.field(field);

      VariableDeclaration parameter =
          VariableDeclaration("#x$i", type: fieldType);
      parameters.add(parameter);
    }

    // Utility function for initialising each class member.
    Initializer memberInitializer(int i, VariableDeclaration v) =>
        FieldInitializer(dataCon.fields[i], VariableGet(v));

    // Create the class template.
    Class cls = dataCon
        .manyTypeParameters(typeParameters)
        .parent(parentClass, typeArguments: typeArgumentsOf(typeParameters))
        .constructor(parameters: parameters, field: memberInitializer)
        .build("${constructor.binder}", isAbstract: true);

    // Derive toString method.
    cls.procedures.add(deriveToString(constructor));

    // Store the generated class on [constructor].
    constructor.asKernelNode = cls;
    return cls;
  }

  Procedure deriveToString(DataConstructor constructor) {
    // Derives a toString method for the data [constructor].
    List<kernel.Expression> components = <kernel.Expression>[
      StringLiteral(constructor.binder.sourceName)
    ];
    if (constructor.parameters.length > 0) {
      components.add(StringLiteral("("));
      for (int i = 0; i < constructor.parameters.length; i++) {
        kernel.Expression exp =
            PropertyGet(ThisExpression(), Name("\$${i + 1}"));
        components.add(exp);
        if (i + 1 < constructor.parameters.length) {
          components.add(StringLiteral(", "));
        }
      }
      components.add(StringLiteral(")"));
    }

    FunctionNode funNode = FunctionNode(
        ReturnStatement(StringConcatenation(components)),
        returnType: InterfaceType(platform.coreTypes.stringClass));
    return Procedure(Name("toString"), ProcedureKind.Method, funNode);
  }

  Statement matchCaseBodyBuilder(VariableDeclaration node) {
    Class patternMatchFailure = platform.getClass(
        PlatformPathBuilder.t20.target("PatternMatchFailure").build());
    ConstructorInvocation invokePatternMatchFailure = ConstructorInvocation(
        patternMatchFailure.constructors[0], Arguments.empty());
    return ReturnStatement(Throw(invokePatternMatchFailure));
  }

  Class matchClosureInterface(
      Class typeClass, List<Class> dataClasses, Class visitor) {
    // Construct the match closure interface for [typeClass].
    VisitorBuilder matchClosure = VisitorBuilder(platform);

    List<TypeParameter> typeParameters =
        type.copyTypeParameters(visitor.typeParameters);
    TypeParameter resultTypeParameter = typeParameters.last;

    // Add a visit method for each data class.
    DartType resultType = TypeParameterType(resultTypeParameter);
    for (int i = 0; i < dataClasses.length; i++) {
      Class dataClass = dataClasses[i];
      List<DartType> nodeTypeArguments =
          typeArgumentsOf(typeParameters.sublist(0, typeParameters.length - 1));
      DartType nodeType = InterfaceType(dataClass, nodeTypeArguments);

      matchClosure.method(resultType, nodeType, dataClass.name,
          body: matchCaseBodyBuilder);
    }

    // Add a default case method.
    List<DartType> nodeTypeArguments =
        typeArgumentsOf(typeParameters.sublist(0, typeParameters.length - 1));
    DartType nodeType = InterfaceType(typeClass, nodeTypeArguments);
    matchClosure.method(resultType, nodeType, "defaultCase",
        body: matchCaseBodyBuilder, visitSuffix: false);

    // Generate the class.
    Class closureClass = matchClosure
        .manyTypeParameters(typeParameters)
        .parent(visitor, typeArguments: typeArgumentsOf(typeParameters))
        .constructor()
        .build("${typeClass.name}MatchClosure", isAbstract: true);
    return closureClass;
  }

  Class visitorInterface(Class typeClass, List<Class> dataClasses) {
    VisitorBuilder builder = VisitorBuilder(platform);

    // Create a fresh type parameter for the "return type" of the visit methods.
    TypeParameter resultTypeParameter = type.freshTypeParameter("\$R");
    // Copy the type parameters from [typeClass] and add [resultTypeParameter]
    // to the tail.
    List<TypeParameter> typeParameters = type
        .copyTypeParameters(typeClass.typeParameters)
          ..add(resultTypeParameter);

    // Add visit methods.
    List<DartType> typeArguments =
        typeArgumentsOf(typeParameters.sublist(0, typeParameters.length - 1));
    for (int i = 0; i < dataClasses.length; i++) {
      Class dataClass = dataClasses[i];
      DartType returnType = TypeParameterType(resultTypeParameter);
      DartType nodeType = InterfaceType(dataClass, typeArguments);

      // Add an abstract "visit{dataClass.name}" method.
      builder.method(returnType, nodeType, dataClass.name, isAbstract: true);
    }

    // Build the visitor class.
    Class visitorClass = builder
        .manyTypeParameters(typeParameters) // Register type parameters.
        .constructor() // Add a default constructor.
        .build("${typeClass.name}Visitor", isAbstract: true);

    // Add accept methods to each data class.
    Procedure accept(Class visitor, Class visitee, bool isAbstract) {
      // Each accept method is parameterised by return type of the visitor.
      TypeParameter returnTypeParameter = type.freshTypeParameter("\$R");
      DartType returnType = TypeParameterType(returnTypeParameter);
      List<DartType> typeArguments = typeArgumentsOf(visitee.typeParameters)
        ..add(TypeParameterType(returnTypeParameter));

      // Each accept method takes a single argument as input. The argument is a
      // visitor instance.
      VariableDeclaration v =
          VariableDeclaration("v", type: InterfaceType(visitor, typeArguments));

      Statement body;
      if (isAbstract) {
        body = EmptyStatement();
      } else {
        MethodInvocation visitNode = MethodInvocation(
            VariableGet(v),
            Name("visit${visitee.name}"),
            Arguments(<kernel.Expression>[ThisExpression()]));
        body = ReturnStatement(visitNode);
      }

      FunctionNode funNode = FunctionNode(body,
          positionalParameters: <VariableDeclaration>[v],
          typeParameters: <TypeParameter>[returnTypeParameter],
          returnType: returnType);
      return Procedure(Name("accept"), ProcedureKind.Method, funNode,
          isAbstract: isAbstract);
    }

    for (int i = 0; i < dataClasses.length; i++) {
      Class dataClass = dataClasses[i];
      Procedure acceptMethod = accept(visitorClass, dataClass, false);
      dataClass.procedures.add(acceptMethod);
    }

    // Add an abstract accept method to [typeClass].
    Procedure acceptMethod = accept(visitorClass, typeClass, true);
    typeClass.procedures.add(acceptMethod);

    // Finally return the constructed visitor class.
    return visitorClass;
  }

  List<TypeParameter> typeParametersOf(List<Quantifier> qs) {
    List<TypeParameter> result = new List<TypeParameter>();
    for (int i = 0; i < qs.length; i++) {
      TypeParameter parameter =
          type.freshTypeParameter(qs[i].binder.toString());
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

class MatchClosureKernelGenerator {
  final Platform platform;
  final ModuleEnvironment environment;
  final KernelRepr magic;
  final ExpressionKernelGenerator expression;
  final DartTypeGenerator type;

  MatchClosureKernelGenerator(
      Platform platform,
      ModuleEnvironment environment,
      ExpressionKernelGenerator expression,
      KernelRepr magic,
      DartTypeGenerator type)
      : this.environment = environment,
        this.platform = platform,
        this.magic = magic,
        this.type = type,
        this.expression = expression;

  void compile(Library target, MatchClosure closure) {
    // Generates:
    // class ConcreteMatch[closure]<A,..,R> extends [parentClass]<A,...,R>;
    DatatypeDescriptor descriptor =
        closure.typeConstructor.declarator as DatatypeDescriptor;
    // Setup the [supertype] of this concrete match [closure] class.
    Class parentClass;
    if (environment.originOf(descriptor.binder) == Origin.KERNEL) {
      parentClass = platform.getClass(
          PlatformPathBuilder.t20.target("KernelMatchClosure").build());
    } else {
      parentClass = descriptor.matchClosureClass;
    }

    VisitorBuilder cls = VisitorBuilder(platform);

    // Compute the type parameters for this class.
    List<TypeParameter> typeParameters =
        typeParametersOf(closure.typeConstructor.arguments);
    // Compute the type arguments for the parent class.
    List<DartType> parentTypeArguments =
        typeArgumentsOf(closure.typeConstructor.arguments);
    // If the return type of the closure is a rigid type variable, then we need
    // to include it as a parameter too.
    TypeParameter resultTypeParameter;
    DartType resultType;
    if (closure.type is TypeVariable) {
      resultTypeParameter = type.freshTypeParameter("\$R");
      typeParameters.add(resultTypeParameter);
      resultType = TypeParameterType(resultTypeParameter);
    } else {
      resultType = type.compile(closure.type);
    }
    // Add the result type to the list of type arguments for the [parentClass].
    parentTypeArguments.add(resultType);

    // Construct the node type.
    DartType nodeType;
    if (environment.originOf(descriptor.binder) == Origin.KERNEL) {
      nodeType = magic.typeConstructor(closure.typeConstructor);
    } else {
      nodeType = InterfaceType(descriptor.asKernelNode,
          parentTypeArguments.sublist(0, parentTypeArguments.length - 1));
    }

    // The captured variables are compiled as instance fields.
    List<VariableDeclaration> parameters = new List<VariableDeclaration>();
    for (int i = 0; i < closure.context.length; i++) {
      ClosureVariable cv = closure.context[i];
      DartType cvtype = type.compile(cv.type);

      Field field = Field(Name(cv.binder.toString()), type: cvtype);
      cls.field(field);
      cv.asKernelNode = field;

      VariableDeclaration parameter = VariableDeclaration("#x$i", type: cvtype);
      parameters.add(parameter);
    }

    // Field initializer.
    Initializer capturedVariableInitializer(int i, VariableDeclaration v) =>
        FieldInitializer(cls.fields[i], VariableGet(v));

    // Compile the cases.
    for (int i = 0; i < closure.cases.length; i++) {
      MatchClosureCase case0 = closure.cases[i];

      Class dataClass;
      String caseName;
      if (environment.originOf(case0.constructor.binder) == Origin.KERNEL) {
        dataClass = magic.getDataClass(case0.constructor);
        caseName = dataClass.name;
      } else {
        dataClass = case0.constructor.asKernelNode;
        caseName = case0.constructor.binder.toString();
      }
      DartType nodeType = InterfaceType(
          dataClass, typeArgumentsOf(closure.typeConstructor.arguments));

      cls.method(resultType, nodeType, caseName,
          body: (VariableDeclaration node) {
        case0.binder.asKernelNode = node;
        return ReturnStatement(expression.compile(target, case0.body));
      });
    }

    // Compile the default case.
    if (closure.defaultCase != null) {
      MatchClosureDefaultCase defaultCase = closure.defaultCase;
      cls.method(resultType, nodeType, "defaultCase", visitSuffix: false,
          body: (VariableDeclaration node) {
        defaultCase.binder.asKernelNode = node;
        return ReturnStatement(expression.compile(target, defaultCase.body));
      });
    }

    // Construct the class.
    Class closureClass = cls
        .manyTypeParameters(typeParameters)
        .parent(parentClass, typeArguments: parentTypeArguments)
        .constructor(parameters: parameters, field: capturedVariableInitializer)
        .build("${descriptor.binder}MatchClosure");

    // Store the class.
    closure.asKernelNode = closureClass;

    // Add the class to the target library.
    target.classes.add(closureClass);
  }

  List<TypeParameter> typeParametersOf(List<Datatype> types) {
    List<TypeVariable> typeVariables =
        typeUtils.extractTypeVariablesMany(types);
    if (typeVariables == null) return <TypeParameter>[];

    List<TypeParameter> typeParameters = new List<TypeParameter>();
    for (int i = 0; i < typeVariables.length; i++) {
      TypeVariable typeVariable = typeVariables[i];
      TypeParameter parameter = type.quantifier(typeVariable.declarator);
      typeParameters.add(parameter);
    }
    return typeParameters;
  }

  List<DartType> typeArgumentsOf(List<Datatype> types) =>
      types.map(type.compile).toList();
}

class ModuleKernelGenerator {
  final Platform platform;

  final AlgebraicDatatypeKernelGenerator adt;
  final ModuleEnvironment environment;
  final ExpressionKernelGenerator expression;
  final KernelRepr magic;
  final DartTypeGenerator type;

  ModuleKernelGenerator(Platform platform, ModuleEnvironment environment,
      KernelRepr magic, DartTypeGenerator type)
      : this.environment = environment,
        this.platform = platform,
        this.magic = magic,
        this.type = type,
        this.expression =
            ExpressionKernelGenerator(platform, environment, magic, type),
        this.adt = AlgebraicDatatypeKernelGenerator(
            platform, environment, magic, type);

  Library compile(TopModule module) {
    // Target library.
    Library library = emptyLibrary(module);

    // Process module members.
    bool isKernelModule = environment.isKernelModule(module);
    List<ModuleMember> members = module.members;
    for (int i = 0; i < members.length; i++) {
      ModuleMember member = members[i];
      switch (member.tag) {
        case ModuleTag.DATATYPE_DEFS:
          // Skip all data type declarations in the Kernel module.
          if (isKernelModule) continue;
          List<Class> classes = adt.compile(member as DatatypeDeclarations);
          if (classes != null) {
            library.classes.addAll(classes);
          }
          break;
        // case ModuleTag.CONSTR:
        case ModuleTag.FUNC_DEF:
          Procedure procedure = function(library, member as LetFunction);
          // Virtual functions may compile to [null].
          if (procedure != null) {
            library.procedures.add(procedure);
          }
          break;
        case ModuleTag.VALUE_DEF:
          Field field = value(library, member as ValueDeclaration);
          if (field != null) {
            library.fields.add(field);
          }
          break;
        case ModuleTag.CONSTR:
        case ModuleTag.TYPENAME:
          // Ignore.
          break;
        default:
          unhandled("ModuleKernelGenerator.compile", member.tag);
      }
    }

    return library;
  }

  Library emptyLibrary(TopModule module) {
    return Library(module.location.uri, name: module.name);
  }

  Procedure function(Library target, LetFunction fun) {
    if (fun.isVirtual) {
      assert(fun is LetVirtualFunction);
      return virtualFunction(fun as LetVirtualFunction);
    }

    // Build the function node.
    FunctionNode node =
        expression.functionNode(target, fun.parameters, fun.body, fun.type);
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
            fun.asKernelNode = platform.getProcedure(
                PlatformPathBuilder.package("t20_runtime")
                    .target("iterate")
                    .build());
            break;
          default: // Ignore.
        }
        break;
      case Origin.STRING:
      case Origin.DART_LIST:
        // Ignore.
        break;
      case Origin.KERNEL:
        if (fun.binder.sourceName == "transform-component!") {
          fun.asKernelNode = platform.getProcedure(
              PlatformPathBuilder.package("t20_runtime")
                  .target("transformComponentBang")
                  .build());
        }
        break;
      default:
        unhandled("ModuleKernelGenerator.virtualFunction",
            environment.originOf(fun.binder));
    }
    return null;
  }

  Field value(Library target, ValueDeclaration val) {
    if (val.isVirtual) {
      throw "Compilation of virtual values has not yet been implemented.";
    }

    // Build the [Field] node.
    DartType valueType = type.compile(val.type);
    Field node = Field(Name(val.binder.toString()),
        initializer: expression.compile(target, val.body), type: valueType);

    // Store the node.
    val.asKernelNode = node;
    return node;
  }
}

class ExpressionKernelGenerator {
  final ModuleEnvironment environment;
  final KernelRepr magic;
  MatchClosureKernelGenerator mclosure;
  final Platform platform;
  final InvocationKernelGenerator invoke;
  final DartTypeGenerator type;

  ExpressionKernelGenerator(Platform platform, ModuleEnvironment environment,
      KernelRepr magic, DartTypeGenerator type)
      : this.environment = environment,
        this.invoke = InvocationKernelGenerator(environment, type, magic),
        this.magic = magic,
        this.platform = platform,
        this.type = type {
    this.mclosure =
        MatchClosureKernelGenerator(platform, environment, this, magic, type);
  }

  kernel.Expression compile(Library target, Expression exp) {
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
        return getVariable(target, exp as Variable);
        break;
      // Homomorphisms (more or less).
      case ExpTag.IF:
        If ifexp = exp as If;
        return ConditionalExpression(
            compile(target, ifexp.condition),
            compile(target, ifexp.thenBranch),
            compile(target, ifexp.elseBranch),
            type.compile(ifexp.type));
        break;
      case ExpTag.LET:
        DLet letexp = exp as DLet;
        VariableDeclaration v = translateBinder(letexp.binder, type);
        v.initializer = compile(target, letexp.body);
        return kernel.Let(v, compile(target, letexp.continuation));
        break;
      case ExpTag.LAMBDA:
        return lambda(target, exp as DLambda);
        break;
      case ExpTag.PROJECT:
        return project(target, exp as Project);
        break;
      case ExpTag.TUPLE:
        return tuple(target, exp as Tuple);
        break;
      case ExpTag.TYPE_ASCRIPTION:
        return compile(target, (exp as TypeAscription).exp);
        break;
      // Interesting cases.
      case ExpTag.APPLY:
        return apply(target, exp as Apply);
        break;
      case ExpTag.ELIM:
        return eliminate(target, exp as Eliminate);
      default:
        unhandled("ExpressionKernelGenerator.compile", exp.tag);
    }

    return null; // Impossible!
  }

  kernel.Expression apply(Library target, Apply apply) {
    // There are several different kinds of applications:
    // 1) Constructor application.
    // 2) Primitive application.
    // 3) Static function application.
    // 4) Dynamic function application (e.g. lambda application).

    // Compile each argument.
    List<kernel.Expression> arguments = List<kernel.Expression>();
    for (int i = 0; i < apply.arguments.length; i++) {
      kernel.Expression exp = compile(target, apply.arguments[i]);
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
        return invoke.dynamic$(compile(target, v), arguments);
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
      return invoke.dynamic$(compile(target, apply.abstractor), arguments);
    }
  }

  FunctionExpression lambda(Library target, DLambda lambda) {
    // Build the function node.
    FunctionNode node =
        functionNode(target, lambda.parameters, lambda.body, lambda.type);
    return FunctionExpression(node);
  }

  FunctionNode functionNode(Library target, List<FormalParameter> parameters,
      Expression body, Datatype fnType) {
    // Translate each parameter.
    List<VariableDeclaration> parameters0 = parameters
        .map((FormalParameter p) => translateFormalParameter(p, type))
        .toList();

    // Translate the [body].
    Statement body0 =
        Block(<Statement>[ReturnStatement(compile(target, body))]);

    // TODO translate [fnType] to extract return type and any type parameters.
    DartType returnType = type.compile(typeUtils.codomain(fnType));
    List<TypeParameter> typeParameters = <TypeParameter>[];

    return FunctionNode(body0,
        positionalParameters: parameters0,
        returnType: returnType,
        typeParameters: typeParameters);
  }

  kernel.Expression tuple(Library target, Tuple tuple) {
    if (tuple.isUnit) {
      return NullLiteral();
    }

    List<kernel.Expression> components = new List<kernel.Expression>();
    for (int i = 0; i < tuple.components.length; i++) {
      components.add(compile(target, tuple.components[i]));
    }
    return ListLiteral(components, isConst: false);
  }

  kernel.Expression getVariable(Library target, Variable v) {
    // To retain soundness, some primitive must be eta expanded when used as a
    // return value or as an input to a higher-order function.
    if (environment.isPrimitive(v.binder) && requiresEtaExpansion(v.binder)) {
      return etaPrimitive(v.binder);
    }

    if (v.binder.bindingOccurrence is DataConstructor) {
      DataConstructor constructor =
          v.binder.bindingOccurrence as DataConstructor;
      // Instantiate nullary constructors immediately.
      if (constructor.isNullary) {
        return invoke.constructor(constructor, const <kernel.Expression>[]);
      } else {
        // TODO, needs eta expansion.
        unhandled("ExpressionKernelGenerator.getVariable", constructor);
      }
    }

    if (environment.isGlobal(v.binder)) {
      Object d = v.declarator;
      return d is KernelNode
          ? StaticGet(d.asKernelNode)
          : throw "Logical error: expected kernel node.";
    } else if (environment.isCaptured(v.binder)) {
      return PropertyGet(ThisExpression(), Name(v.binder.toString()));
    } else {
      return VariableGet(v.binder.asKernelNode);
    }
  }

  kernel.Expression project(Library target, Project proj) {
    // Compile the receiver.
    kernel.Expression receiver = compile(target, proj.receiver);

    // There are two kinds of projections: 1) Tuple projections, 2) Data
    // constructor projections.
    if (proj is DataConstructorProject) {
      DataConstructor constructor = proj.constructor;
      // Need to handle projections from Kernel objects specially.
      if (environment.originOf(constructor.binder) == Origin.KERNEL) {
        Name propertyName = magic.project(constructor, proj.label);
        return PropertyGet(receiver, propertyName);
      }
      return PropertyGet(receiver, Name("\$${proj.label}"));
    }

    assert(proj.label > 0);
    DartType componentType = type.compile(proj.type);
    // Tuple are implemented as heterogeneous lists, therefore we need to coerce
    // projected members.
    return AsExpression(subscript(receiver, proj.label - 1), componentType);
  }

  FunctionExpression etaPrimitive(Binder primitiveBinder) {
    Declaration d = primitiveBinder.bindingOccurrence;
    if (d is LetFunction) {
      return invoke.eta(d);
    } else {
      throw "Logical error: Cannot eta expand primitive non-functions.";
    }
  }

  InvocationExpression eliminate(Library target, Eliminate elim) {
    // First compile the closure.
    mclosure.compile(target, elim.closure);

    // Secondly, instantiate the closure.
    List<kernel.Expression> variables = List<kernel.Expression>();
    for (int i = 0; i < elim.capturedVariables.length; i++) {
      variables.add(getVariable(target, elim.capturedVariables[i]));
    }
    ConstructorInvocation matchClosureInvocation = ConstructorInvocation(
        elim.closure.asKernelNode.constructors[0], Arguments(variables));

    // Instantiate the eliminator.
    Constructor eliminatorConstructor;
    if (environment.originOf(elim.constructor.declarator.binder) ==
        Origin.KERNEL) {
      Class cls = platform
          .getClass(PlatformPathBuilder.t20.target("KernelEliminator").build());
      eliminatorConstructor = cls.constructors[0];
    } else {
      eliminatorConstructor =
          (elim.constructor.declarator as DatatypeDescriptor)
              .eliminatorClass
              .constructors[0];
    }

    ConstructorInvocation eliminatorInvocation = ConstructorInvocation(
        eliminatorConstructor,
        Arguments(<kernel.Expression>[matchClosureInvocation]));
    // Run the eliminator on the scrutinee.
    return MethodInvocation(getVariable(target, elim.scrutinee), Name("accept"),
        Arguments(<kernel.Expression>[eliminatorInvocation]));
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
          case "show":
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
  final KernelRepr magic;

  InvocationKernelGenerator(this.environment, this.type, this.magic);

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
    // print("apply: ${binder.sourceName} $arguments");
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
          case "int-eq?":
          case "int-less?":
          case "int-greater?":
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
                Arguments(<kernel.Expression>[arguments[1]]));
            break;
          // Show stringifies an arbitrary object.
          case "show":
            assert(arguments.length == 1);
            return MethodInvocation(
                arguments[0], Name("toString"), Arguments.empty());
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
        // Ignore.
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
    if (environment.isPrimitive(constructor.binder)) {
      if (environment.originOf(constructor.binder) == Origin.KERNEL) {
        return magic.invoke(constructor, arguments);
      } else {
        unhandled("InvocationKernelGenerator.constructor", constructor);
      }
    }

    Class dataClass = constructor.asKernelNode;
    return ConstructorInvocation(
        dataClass.constructors[0], Arguments(arguments));
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
  final DartType dynamicType = const kernel.DynamicType();

  DartType compile(Datatype type) => dynamicType; // TODO.

  TypeParameter quantifier(Quantifier q) {
    if (identical(q.asTypeParameter, null)) {
      // Store the type parameter for later.
      q.asTypeParameter = freshTypeParameter(q.binder.toString());
    }

    return q.asTypeParameter;
  }

  TypeParameter freshTypeParameter(String name, {DartType bound}) =>
      TypeParameter(name, bound ?? dynamicType, dynamicType);

  TypeParameter copyTypeParameter(TypeParameter typeParameter) => TypeParameter(
      typeParameter.name, typeParameter.bound, typeParameter.defaultType);

  List<TypeParameter> copyTypeParameters(List<TypeParameter> typeParameters) =>
      typeParameters.map(copyTypeParameter).toList();
}
