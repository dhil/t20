// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart';

import '../ast/ast.dart'
    show DataConstructor, DatatypeDescriptor, TypeConstructor;

import '../errors/errors.dart' show unhandled;

import 'platform.dart';

abstract class _KernelNode {
  Class getClass(Platform platform);
  Expression project(Expression receiver, int index);
  Expression invoke(Platform platform, List<Expression> arguments);
}

// class _KernelCompatNode {
// }

class _KernelNodeCompat implements _KernelNode {
  final String externalName;

  _KernelNodeCompat(String name, List<Name> properties)
      : externalName = name,
        _propertyMapping = properties;

  Class _cls;
  Class getClass(Platform platform) {
    _cls ??= platform.getClass(
        PlatformPathBuilder.kernel.library("ast").target(externalName).build());
    return _cls;
  }

  // Translation of properties.
  List<Name> _propertyMapping;
  Name toPropertyName(int index) => _propertyMapping[index - 1];

  Expression project(Expression receiver, int index) =>
      PropertyGet(receiver, toPropertyName(index));

  Expression invoke(Platform platform, List<Expression> arguments) {
    Constructor constructor = defaultConstructor(platform);
    return ConstructorInvocation(constructor, Arguments(arguments));
  }

  Constructor defaultConstructor(Platform platform) {
    Class cls = getClass(platform);
    for (int i = 0; i < cls.constructors.length; i++) {
      Constructor constr = cls.constructors[i];
      if (constr.name.name.compareTo("") == 0) return constr;
    }

    throw ArgumentError("$cls has no default constructor.");
  }
}

class _KernelProcedureNode extends _KernelNodeCompat {
  _KernelProcedureNode()
      : super("Procedure", <Name>[
          Name("name"),
          Name("kind"),
          Name("function"),
          Name("isAbstract"),
          Name("isStatic")
        ]);

  Expression invoke(Platform platform, List<Expression> arguments) {
    Constructor constructor = defaultConstructor(platform);
    Arguments args =
        Arguments(arguments.sublist(0, 2), named: <NamedExpression>[
      NamedExpression("isAbstract", arguments[3]),
      NamedExpression("isStatic", arguments[4])
    ]);
    return ConstructorInvocation(constructor, args);
  }
}

class _KernelFieldNode extends _KernelNodeCompat {
  _KernelFieldNode()
      : super("Field", <Name>[
          Name("name"),
          Name("initializer"),
          Name("isConst"),
          Name("isFinal"),
          Name("isStatic")
        ]);

  Expression invoke(Platform platform, List<Expression> arguments) {
    Constructor constructor = defaultConstructor(platform);
    Arguments args = Arguments(<Expression>[
      arguments[0]
    ], named: <NamedExpression>[
      NamedExpression("initializer", arguments[1]),
      NamedExpression("isConst", arguments[2]),
      NamedExpression("isFinal", arguments[3]),
      NamedExpression("isStatic", arguments[4])
    ]);
    return ConstructorInvocation(constructor, args);
  }
}

class _KernelVariableDeclarationNode extends _KernelNodeCompat {
  _KernelVariableDeclarationNode()
      : super("Field", <Name>[
          Name("name"),
          Name("initializer"),
          Name("isConst"),
          Name("isFinal"),
        ]);

  Expression invoke(Platform platform, List<Expression> arguments) {
    Constructor constructor = defaultConstructor(platform);
    Arguments args = Arguments(<Expression>[
      arguments[0]
    ], named: <NamedExpression>[
      NamedExpression("initializer", arguments[1]),
      NamedExpression("isConst", arguments[2]),
      NamedExpression("isFinal", arguments[3])
    ]);
    return ConstructorInvocation(constructor, args);
  }
}

class _KernelShamNode implements _KernelNode {
  _KernelNodeCompat actual;

  _KernelShamNode(this.actual);

  Class getClass(Platform platform) => actual.getClass(platform);

  Expression project(Expression receiver, int index) => receiver;

  Expression invoke(Platform platform, List<Expression> arguments) =>
      arguments[0];
}

Map<String, _KernelNode> buildCompatibilityMap() {
  Map<String, _KernelNode> compatMap = <String, _KernelNode>{
    // Literals.
    "BoolLiteral": _KernelNodeCompat("BoolLiteral", <Name>[Name("value")]),
    "IntLiteral": _KernelNodeCompat("IntLiteral", <Name>[Name("value")]),
    "StringLiteral": _KernelNodeCompat("StringLiteral", <Name>[Name("value")]),
    "NullLiteral": _KernelNodeCompat("NullLiteral", null),
    "ThisExpression": _KernelNodeCompat("ThisExpression", null),
    "TypeLiteral": _KernelNodeCompat("TypeLiteral", <Name>[Name("type")]),
    // Logical expressions.
    "Not": _KernelNodeCompat("Not", <Name>[Name("operand")]),
    "LogicalExpression": _KernelNodeCompat("LogicalExpression",
        <Name>[Name("left"), Name("operator"), Name("right")]),
    // Impure expressions.
    "InvalidExpression":
        _KernelNodeCompat("InvalidExpression", <Name>[Name("message")]),
    "StaticGet": _KernelNodeCompat("StaticGet", <Name>[Name("target")]),
    "PropertyGet": _KernelNodeCompat(
        "PropertyGet", <Name>[Name("receiver"), Name("name")]),
    "PropertySet": _KernelNodeCompat(
        "PropertySet", <Name>[Name("receiver"), Name("name"), Name("value")]),
    "StaticSet":
        _KernelNodeCompat("StaticSet", <Name>[Name("target"), Name("value")]),
    "VariableGet": _KernelNodeCompat("VariableGet", <Name>[Name("variable")]),
    "VariableSet": _KernelNodeCompat(
        "VariableSet", <Name>[Name("variable"), Name("value")]),
    "NamedExpression": _KernelNodeCompat(
        "NamedExpression", <Name>[Name("name"), Name("value")]),
    "MethodInvocation": _KernelNodeCompat("MethodInvocation",
        <Name>[Name("receiver"), Name("name"), Name("arguments")]),
    "StaticInvocation": _KernelNodeCompat(
        "StaticInvocation", <Name>[Name("target"), Name("arguments")]),

    // Statements
    "Block": _KernelNodeCompat("Block", <Name>[Name("statements")]),
    "ExpressionStatement":
        _KernelNodeCompat("ExpressionStatement", <Name>[Name("expression")]),
    "IfStatement": _KernelNodeCompat("IfStatement",
        <Name>[Name("condition"), Name("then"), Name("otherwise")]),

    // Arguments.
    "Arguments": _KernelNodeCompat(
        "Arguments", <Name>[Name("positional"), Name("named")]),

    // Variables.
    "VariableDeclaration": _KernelVariableDeclarationNode(),

    // Members.
    "Field": _KernelFieldNode(),
    "Procedure": _KernelProcedureNode()
  };

  // Add sham nodes.
  Map<String, _KernelNode> shamMap = <String, _KernelNode>{
    "FieldMember": _KernelShamNode(compatMap["Field"]),
    "ProcedureMember": _KernelShamNode(compatMap["Procedure"]),
    "VariableDeclarationStatement":
        _KernelShamNode(compatMap["VariableDeclaration"])
  };

  // Merge.
  compatMap.addAll(shamMap);

  return compatMap;
}

class _KernelTypeNode {

}

Map<String, _KernelTypeNode> buildTypeCompabilityMap() {
  return null;
}

// Provides a mapping between the internal representation of Kernel and the
// actual external representation.
class KernelRepr {
  final Platform platform;

  Map<String, _KernelNode> _kernelNodes;
  Map<String, _KernelNode> get kernelNodes {
    _kernelNodes ??= buildCompatibilityMap();
    return _kernelNodes;
  }

  // Map<String, _KernelTypeNode> get kernelTypeNodes {
  //   _kernelTypeNodes ??= buildTypeCompabilityMap();
  //   return _kernelTypeNodes;
  // }

  KernelRepr(this.platform);

  InvocationExpression invoke(
      DataConstructor dataConstructor, List<Expression> arguments) {
    _KernelNode compat = kernelNodes[dataConstructor.binder.sourceName];
    return compat.invoke(platform, arguments);
  }

  Expression project(
      DataConstructor dataConstructor, int label, Expression receiver) {
    assert(label > 0);
    _KernelNode compat = kernelNodes[dataConstructor.binder.sourceName];
    return compat.project(receiver, label);
  }

  DartType getType(TypeConstructor constructor) {
    Class cls;
    switch (constructor.declarator.binder.sourceName) {
      case "Expression":
        cls = platform.getClass(PlatformPathBuilder.kernel
            .library("ast")
            .target("Expression")
            .build());
        break;
      default:
        unhandled("KernelRepr.typeConstructor",
            constructor.declarator.binder.sourceName);
    }
    return InterfaceType(cls, <DartType>[]);
  }

  Class getDataClass(DataConstructor dataConstructor) {
    _KernelNode compat = kernelNodes[dataConstructor.binder.sourceName];
    return compat.getClass(platform);
  }
}
