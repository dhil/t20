// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart';

abstract class KernelAlgebra {
  Library library(
      {String name,
      bool isExternal: false,
      List<Expression> annotations,
      List<LibraryDependency> dependencies,
      List<LibraryPart> parts,
      List<Typedef> typedefs,
      List<Class> classes,
      List<Procedure> procedures,
      List<Field> fields,
      Uri fileUri,
      Reference reference});

  Class class$(
      {String name,
      bool isAbstract: false,
      bool isAnonymousMixin: false,
      Supertype supertype,
      Supertype mixedInType,
      List<TypeParameter> typeParameters,
      List<Supertype> implementedTypes,
      List<Constructor> constructors,
      List<Procedure> procedures,
      List<Field> fields,
      List<RedirectingFactoryConstructor> redirectingFactoryConstructors,
      Uri fileUri,
      Reference reference});

  Field field(Name name,
      {DartType type: const DynamicType(),
      Expression initializer,
      bool isCovariant: false,
      bool isFinal: false,
      bool isConst: false,
      bool isStatic: false,
      bool hasImplicitGetter,
      bool hasImplicitSetter,
      int transformerFlags: 0,
      Uri fileUri,
      Reference reference});

  Constructor constructor(FunctionNode function,
      {Name name,
      bool isConst: false,
      bool isExternal: false,
      bool isSynthetic: false,
      List<Initializer> initializers,
      int transformerFlags: 0,
      Uri fileUri,
      Reference reference});

  RedirectingFactoryConstructor redirectingFactoryConstructor(
      Reference targetReference,
      {Name name,
      bool isConst: false,
      bool isExternal: false,
      int transformerFlags: 0,
      List<DartType> typeArguments,
      List<TypeParameter> typeParameters,
      List<VariableDeclaration> positionalParameters,
      List<VariableDeclaration> namedParameters,
      int requiredParameterCount,
      Uri fileUri,
      Reference reference});

  Procedure procedure(Name name, ProcedureKind kind, FunctionNode function,
      {bool isAbstract: false,
      bool isStatic: false,
      bool isExternal: false,
      bool isConst: false,
      bool isForwardingStub: false,
      bool isForwardingSemiStub: false,
      int transformerFlags: 0,
      Uri fileUri,
      Reference reference,
      Member forwardingStubSuperTarget,
      Member forwardingStubInterfaceTarget});

  FieldInitializer fieldInitializer(Field field, Expression value);
  SuperInitializer superInitializer(Constructor target, Arguments arguments);
  RedirectingInitializer redirectingInitializer(
      Constructor target, Arguments arguments);
  LocalInitializer localInitializer(VariableDeclaration variable);

  FunctionNode functionNode(Statement body,
      {List<TypeParameter> typeParameters,
      List<VariableDeclaration> positionalParameters,
      List<VariableDeclaration> namedParameters,
      int requiredParameterCount,
      DartType returnType: const DynamicType(),
      AsyncMarker asyncMarker: AsyncMarker.Sync,
      AsyncMarker dartAsyncMarker});

  Arguments arguments(List<Expression> positional,
                      {List<DartType> types, List<NamedExpression> named});


  // Expressions.
  VariableGet variableGet(VariableDeclaration variable,
      [DartType promotedType]);

  VariableSet variableSet(VariableDeclaration variable, Expression value);

  PropertyGet propertyGet(Expression receiver, Name name,
      [Member interfaceTarget]);

  PropertySet propertySet(Expression receiver, Name name, Expression value,
      [Member interfaceTarget]);

  DirectPropertyGet directPropertyGet(Expression receiver, Member target);
  DirectPropertySet directPropertySet(
      Expression receiver, Member target, Expression value);
  DirectMethodInvocation directMethodInvocation(
      Expression receiver, Procedure target, Arguments arguments);

  SuperPropertyGet superPropertyGet(Name name, [Member interfaceTarget]);
  SuperPropertySet superPropertySet(
      Name name, Expression value, Member interfaceTarget);

  StaticGet staticGet(Member target);
  StaticSet staticSet(Member target, Expression value);

  NamedExpression namedExpression(String name, Expression value);

  MethodInvocation methodInvocation(
      Expression receiver, Name name, Arguments arguments,
      [Member interfaceTarget]);
}
