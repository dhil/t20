// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart';

import '../ast/ast.dart'
    show DataConstructor, DatatypeDescriptor, TypeConstructor;

import '../errors/errors.dart' show unhandled;

import 'platform.dart';

abstract class _KernelCompatNode {
  Class getClass(Platform platform);
}

abstract class _KernelTypeCompatNode {
  DartType asDartType(Platform platform);
}

class _CompatNode {
  final String externalName;

  _CompatNode(String name) : externalName = name;

  Class _cls;
  Class getClass(Platform platform) {
    _cls ??= platform.getClass(
        PlatformPathBuilder.kernel.library("ast").target(externalName).build());
    return _cls;
  }
}

abstract class _KernelDataCompatNode implements _KernelCompatNode {
  Expression project(Expression receiver, int index);
  Expression invoke(Platform platform, List<Expression> arguments);
}

class _DataCompatNode extends _CompatNode implements _KernelDataCompatNode {
  _DataCompatNode(String name, List<Name> properties)
      : _propertyMapping = properties,
        super(name);

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

class _ProcedureCompatNode extends _DataCompatNode {
  _ProcedureCompatNode()
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

class _FieldCompatNode extends _DataCompatNode {
  _FieldCompatNode()
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

class _VariableDeclarationCompatNode extends _DataCompatNode {
  _VariableDeclarationCompatNode()
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

class _DataShamNode implements _KernelDataCompatNode {
  _DataCompatNode actual;

  _DataShamNode(this.actual);

  Class getClass(Platform platform) => actual.getClass(platform);

  Expression project(Expression receiver, int index) => receiver;

  Expression invoke(Platform platform, List<Expression> arguments) =>
      arguments[0];
}

Map<String, _KernelDataCompatNode> buildCompatibilityMap() {
  Map<String, _KernelDataCompatNode> compatMap =
      <String, _KernelDataCompatNode>{
    // Literals.
    "BoolLiteral": _DataCompatNode("BoolLiteral", <Name>[Name("value")]),
    "IntLiteral": _DataCompatNode("IntLiteral", <Name>[Name("value")]),
    "StringLiteral": _DataCompatNode("StringLiteral", <Name>[Name("value")]),
    "NullLiteral": _DataCompatNode("NullLiteral", null),
    "ThisExpression": _DataCompatNode("ThisExpression", null),
    "TypeLiteral": _DataCompatNode("TypeLiteral", <Name>[Name("type")]),
    // Logical expressions.
    "Not": _DataCompatNode("Not", <Name>[Name("operand")]),
    "LogicalExpression": _DataCompatNode("LogicalExpression",
        <Name>[Name("left"), Name("operator"), Name("right")]),
    // Impure expressions.
    "InvalidExpression":
        _DataCompatNode("InvalidExpression", <Name>[Name("message")]),
    "StaticGet": _DataCompatNode("StaticGet", <Name>[Name("target")]),
    "PropertyGet":
        _DataCompatNode("PropertyGet", <Name>[Name("receiver"), Name("name")]),
    "PropertySet": _DataCompatNode(
        "PropertySet", <Name>[Name("receiver"), Name("name"), Name("value")]),
    "StaticSet":
        _DataCompatNode("StaticSet", <Name>[Name("target"), Name("value")]),
    "VariableGet": _DataCompatNode("VariableGet", <Name>[Name("variable")]),
    "VariableSet":
        _DataCompatNode("VariableSet", <Name>[Name("variable"), Name("value")]),
    "NamedExpression":
        _DataCompatNode("NamedExpression", <Name>[Name("name"), Name("value")]),
    "MethodInvocation": _DataCompatNode("MethodInvocation",
        <Name>[Name("receiver"), Name("name"), Name("arguments")]),
    "StaticInvocation": _DataCompatNode(
        "StaticInvocation", <Name>[Name("target"), Name("arguments")]),

    // Statements
    "Block": _DataCompatNode("Block", <Name>[Name("statements")]),
    "ExpressionStatement":
        _DataCompatNode("ExpressionStatement", <Name>[Name("expression")]),
    "IfStatement": _DataCompatNode("IfStatement",
        <Name>[Name("condition"), Name("then"), Name("otherwise")]),

    // Arguments.
    "Arguments":
        _DataCompatNode("Arguments", <Name>[Name("positional"), Name("named")]),

    // Variables.
    "VariableDeclaration": _VariableDeclarationCompatNode(),

    // Members.
    "Field": _FieldCompatNode(),
    "Procedure": _ProcedureCompatNode()
  };

  // Add sham nodes.
  Map<String, _KernelDataCompatNode> shamMap = <String, _KernelDataCompatNode>{
    "FieldMember": _DataShamNode(compatMap["Field"]),
    "ProcedureMember": _DataShamNode(compatMap["Procedure"]),
    "VariableDeclarationStatement":
        _DataShamNode(compatMap["VariableDeclaration"])
  };

  // Merge.
  compatMap.addAll(shamMap);

  return compatMap;
}

class _TypeCompatNode extends _CompatNode implements _KernelTypeCompatNode {
  _TypeCompatNode(String name) : super(name);

  DartType asDartType(Platform platform) =>
      InterfaceType(getClass(platform), const <DartType>[]);
}

Map<String, _KernelTypeCompatNode> buildTypeCompabilityMap() {
  return <String, _KernelTypeCompatNode>{
    "Arguments": _TypeCompatNode("Arguments"),
    "Expression": _TypeCompatNode("Expression"),
    "Field": _TypeCompatNode("Field"),
    "Procedure": _TypeCompatNode("Procedure"),
    "Statement": _TypeCompatNode("Statement"),
  }; // TODO add TypeShamNode.
}

// Provides a mapping between the internal representation of Kernel and the
// actual external representation.
class KernelRepr {
  final Platform platform;

  Map<String, _KernelDataCompatNode> _kernelNodes;
  Map<String, _KernelDataCompatNode> get kernelNodes {
    _kernelNodes ??= buildCompatibilityMap();
    return _kernelNodes;
  }

  Map<String, _KernelTypeCompatNode> _kernelTypeNodes;
  Map<String, _KernelTypeCompatNode> get kernelTypeNodes {
    _kernelTypeNodes ??= buildTypeCompabilityMap();
    return _kernelTypeNodes;
  }

  KernelRepr(this.platform);

  InvocationExpression invoke(
      DataConstructor dataConstructor, List<Expression> arguments) {
    _KernelDataCompatNode compat =
        kernelNodes[dataConstructor.binder.sourceName];
    return compat.invoke(platform, arguments);
  }

  Expression project(
      DataConstructor dataConstructor, int label, Expression receiver) {
    assert(label > 0);
    _KernelDataCompatNode compat =
        kernelNodes[dataConstructor.binder.sourceName];
    return compat.project(receiver, label);
  }

  DartType getType(TypeConstructor constructor) {
    _KernelTypeCompatNode compat =
        kernelTypeNodes[constructor.declarator.binder.sourceName];
    return compat.asDartType(platform);
  }

  Class getDataClass(DataConstructor dataConstructor) {
    _KernelDataCompatNode compat =
        kernelNodes[dataConstructor.binder.sourceName];
    return compat.getClass(platform);
  }
}
