// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart';

import 'package:kernel/text/ast_to_text.dart' show componentToString;

import './kernel_bottomup_folder.dart' show KernelBottomupFolder;

import './kernel_eliminator.dart' show KernelEliminator;

import './kernel_match_closure.dart' show KernelMatchClosure;

import './visitor1.dart' show Visitor1;

class Matcher extends KernelMatchClosure<Node> {
  const Matcher(int id) : super(id);

  @override
  Node visitIntLiteral(IntLiteral node) => new IntLiteral(42);

  @override
  Node defaultCase(Node node) => node;
}

List<Node> compose(List<Node> a, List<Node> b) {
  List<Node> result = new List(a.length + b.length);
  for (int i = 0; i < a.length; ++i) {
    result[i] = a[i];
  }
  for (int i = 0; i < b.length; ++i) {
    result[a.length + i] = b[i];
  }
  return result;
}

class FoldFunction extends Visitor1<List<Node>, List<Node>> {
  @override
  defaultNode(Node node, List<Node> arg) {
    if (node is TreeNode) {
      return handleAnyTreeNode(node, arg);
    }
    return <Node>[node];
  }

  @override
  defaultBasicLiteral(BasicLiteral node, List<Node> arg) {
    return handleAnyTreeNode(node, arg);
  }

  @override
  defaultConstant(Constant node, List<Node> arg) => <Node>[node];

  @override
  defaultConstantReference(Constant node, List<Node> arg) => <Node>[node];

  @override
  defaultDartType(DartType node, List<Node> arg) => <Node>[node];

  @override
  defaultExpression(Expression node, List<Node> arg) {
    return handleAnyTreeNode(node, arg);
  }

  @override
  defaultInitializer(Initializer node, List<Node> arg) {
    return handleAnyTreeNode(node, arg);
  }

  @override
  defaultMember(Member node, List<Node> arg) {
    return handleAnyTreeNode(node, arg);
  }

  @override
  defaultMemberReference(Member node, List<Node> arg) {
    return handleAnyTreeNode(node, arg);
  }

  @override
  defaultStatement(Statement node, List<Node> arg) {
    return handleAnyTreeNode(node, arg);
  }

  @override
  defaultTreeNode(TreeNode node, List<Node> arg) {
    return handleAnyTreeNode(node, arg);
  }

  List<Node> handleAnyTreeNode(TreeNode node, List<Node> arg) {
    Node transformed =
        node.accept(const KernelEliminator(const Matcher(424242)));

    // Should be added after the "functional" part if we may destroy the
    // original tree.
    if (node is! Component && node != transformed) {
      // Components don't have parents.
      node.replaceWith(transformed);
    }

    return <Node>[transformed];
  }
}

KernelBottomupFolder<List<Node>> folder =
    new KernelBottomupFolder(new FoldFunction(), compose, <Node>[]);

main() {
  VariableDeclaration x =
      new VariableDeclaration("x", type: const DynamicType());
  Procedure foo = new Procedure(
      new Name("foo"),
      ProcedureKind.Method,
      new FunctionNode(
          new ReturnStatement(new MethodInvocation(new VariableGet(x),
              new Name("+"), new Arguments([new IntLiteral(0)]))),
          positionalParameters: [x]),
      isStatic: true);
  Procedure entryPoint = new Procedure(
      new Name("main"),
      ProcedureKind.Method,
      new FunctionNode(new Block([
        new ExpressionStatement(
            new StaticInvocation(foo, new Arguments([new IntLiteral(1)])))
      ])),
      isStatic: true);
  Library library = new Library(new Uri(scheme: "file", path: "foo.dart"),
      procedures: [foo, entryPoint]);
  Component component = new Component(libraries: [library])
    ..mainMethod = entryPoint;

  print("// Before:");
  print(componentToString(component));
  print("");

  Component transformed = folder.visitComponent(component).first;

  print("// After:");
  print(componentToString(transformed));
}
