// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20_runtime;

import 'dart:io' show exit, File, IOSink, stderr;
import 'package:kernel/ast.dart'
    show
        Arguments,
        AsExpression,
        AssertBlock,
        AssertInitializer,
        AssertStatement,
        AwaitExpression,
        BasicLiteral,
        Block,
        BoolConstant,
        BoolLiteral,
        BottomType,
        BreakStatement,
        Catch,
        CheckLibraryIsLoaded,
        Class,
        Combinator,
        Component,
        ConditionalExpression,
        Constant,
        ConstantExpression,
        Constructor,
        ConstructorInvocation,
        ContinueSwitchStatement,
        DartType,
        DirectMethodInvocation,
        DirectPropertyGet,
        DirectPropertySet,
        DoStatement,
        DoubleConstant,
        DoubleLiteral,
        DynamicType,
        EmptyStatement,
        Expression,
        ExpressionStatement,
        Field,
        FieldInitializer,
        ForInStatement,
        ForStatement,
        FunctionDeclaration,
        FunctionExpression,
        FunctionNode,
        FunctionType,
        IfStatement,
        Initializer,
        InstanceConstant,
        Instantiation,
        IntConstant,
        InterfaceType,
        IntLiteral,
        InvalidExpression,
        InvalidInitializer,
        InvalidType,
        IsExpression,
        LabeledStatement,
        Let,
        Library,
        LibraryDependency,
        LibraryPart,
        ListConstant,
        ListLiteral,
        LoadLibrary,
        LocalInitializer,
        LogicalExpression,
        MapConstant,
        MapEntry,
        MapLiteral,
        Member,
        MethodInvocation,
        Name,
        NamedExpression,
        NamedType,
        Node,
        Not,
        NullConstant,
        NullLiteral,
        PartialInstantiationConstant,
        Procedure,
        ProcedureKind,
        PropertyGet,
        PropertySet,
        RedirectingFactoryConstructor,
        RedirectingInitializer,
        Rethrow,
        ReturnStatement,
        SetLiteral,
        Statement,
        StaticGet,
        StaticInvocation,
        StaticSet,
        StringConcatenation,
        StringConstant,
        StringLiteral,
        SuperInitializer,
        SuperMethodInvocation,
        SuperPropertyGet,
        SuperPropertySet,
        Supertype,
        SwitchCase,
        SwitchStatement,
        SymbolConstant,
        SymbolLiteral,
        TearOffConstant,
        ThisExpression,
        Throw,
        TreeNode,
        TryCatch,
        TryFinally,
        Typedef,
        TypedefType,
        TypeLiteral,
        TypeLiteralConstant,
        TypeParameter,
        TypeParameterType,
        UnevaluatedConstant,
        VariableDeclaration,
        VariableGet,
        VariableSet,
        VoidType,
        WhileStatement,
        YieldStatement;
import 'package:kernel/binary/ast_from_binary.dart';
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/text/ast_to_text.dart' show componentToString;
import 'package:kernel/visitor.dart'
    show ExpressionVisitor1, StatementVisitor1, DartTypeVisitor1, Visitor;

// Error classes.
class PatternMatchFailure extends Object {
  String message;
  PatternMatchFailure([this.message]) : super();

  String toString() => message ?? "Pattern match failure";
}

class T20Error extends Object {
  Object error;
  T20Error(this.error) : super();

  String toString() => error?.toString ?? "error";
}

class Obvious extends Object {
  final int id;
  Obvious([this.id = 2]) : super();

  String toString() => "Obvious($id)";
}

A error<A>(String message) => throw T20Error(message);

// Finite iteration / corecursion.
R iterate<R>(int m, R Function(R) f, R z) {
  int n = m;
  R result = z;
  for (int i = 0; i < n; i++) {
    result = f(result);
  }
  return result;
}

// Main driver.
void t20main(Component Function(Component) main, List<String> args) async {
  String file = args[0];
  Component c = Component();
  BinaryBuilder(File(file).readAsBytesSync()).readSingleFileComponent(c);
  c = runTransformation(main, c);
  IOSink sink = File("transformed.dill").openWrite();
  BinaryPrinter(sink).writeComponentFile(c);
  await sink.flush();
  await sink.close();
}

// void main(List<String> args) => t20main(<main_from_source>, args);

Component runTransformation(
    Component Function(Component) main, Component argument) {
  try {
    return main(argument);
  } on T20Error catch (e) {
    stderr.writeln(e.toString());
    exit(1);
  } catch (e, s) {
    stderr.writeln("fatal error: $e");
    stderr.writeln(s.toString());
    exit(1);
  }
  return null; // Impossible!
}

//=== Kernel Eliminators, match closures, and recursors.
class KernelMatchClosure<R> implements Visitor<R> {
  final int id;

  const KernelMatchClosure([this.id = 2]);

  R defaultCase(Node node) => throw PatternMatchFailure();

  @override
  R defaultExpression(Expression node) {
    throw new UnsupportedError("defaultExpression");
  }

  @override
  R visitNamedType(NamedType node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSupertype(Supertype node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitName(Name node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitRedirectingFactoryConstructorReference(
      RedirectingFactoryConstructor node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitProcedureReference(Procedure node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitConstructorReference(Constructor node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitFieldReference(Field node) {
    throw new PatternMatchFailure();
  }

  @override
  R defaultMemberReference(Member node) {
    throw new UnsupportedError("defaultMemberReference");
  }

  @override
  R visitUnevaluatedConstantReference(UnevaluatedConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTypeLiteralConstantReference(TypeLiteralConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTearOffConstantReference(TearOffConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitPartialInstantiationConstantReference(
      PartialInstantiationConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitInstanceConstantReference(InstanceConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitListConstantReference(ListConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitMapConstantReference(MapConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSymbolConstantReference(SymbolConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitStringConstantReference(StringConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitDoubleConstantReference(DoubleConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitIntConstantReference(IntConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitBoolConstantReference(BoolConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitNullConstantReference(NullConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R defaultConstantReference(Constant node) {
    throw new UnsupportedError("defaultConstantReference");
  }

  @override
  R visitTypedefReference(Typedef node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitClassReference(Class node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitUnevaluatedConstant(UnevaluatedConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTypeLiteralConstant(TypeLiteralConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTearOffConstant(TearOffConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitPartialInstantiationConstant(PartialInstantiationConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitInstanceConstant(InstanceConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitListConstant(ListConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitMapConstant(MapConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSymbolConstant(SymbolConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitStringConstant(StringConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitDoubleConstant(DoubleConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitIntConstant(IntConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitBoolConstant(BoolConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitNullConstant(NullConstant node) {
    throw new PatternMatchFailure();
  }

  @override
  R defaultConstant(Constant node) {
    throw new UnsupportedError("defaultConstant");
  }

  @override
  R visitTypedefType(TypedefType node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTypeParameterType(TypeParameterType node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitFunctionType(FunctionType node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitInterfaceType(InterfaceType node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitBottomType(BottomType node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitVoidType(VoidType node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitDynamicType(DynamicType node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitInvalidType(InvalidType node) {
    throw new PatternMatchFailure();
  }

  @override
  R defaultDartType(DartType node) {
    throw new UnsupportedError("defaultDartType");
  }

  @override
  R defaultTreeNode(TreeNode node) {
    throw new UnsupportedError("defaultTreeNode");
  }

  @override
  R defaultNode(Node node) {
    throw new UnsupportedError("defaultNode");
  }

  @override
  R visitComponent(Component node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitMapEntry(MapEntry node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitCatch(Catch node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSwitchCase(SwitchCase node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitNamedExpression(NamedExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitArguments(Arguments node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitFunctionNode(FunctionNode node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTypeParameter(TypeParameter node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTypedef(Typedef node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitLibraryPart(LibraryPart node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitCombinator(Combinator node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitLibraryDependency(LibraryDependency node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitLibrary(Library node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitAssertInitializer(AssertInitializer node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitLocalInitializer(LocalInitializer node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitRedirectingInitializer(RedirectingInitializer node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSuperInitializer(SuperInitializer node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitFieldInitializer(FieldInitializer node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitInvalidInitializer(InvalidInitializer node) {
    throw new PatternMatchFailure();
  }

  @override
  R defaultInitializer(Initializer node) {
    throw new UnsupportedError("defaultInitializer");
  }

  @override
  R visitClass(Class node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitRedirectingFactoryConstructor(RedirectingFactoryConstructor node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitField(Field node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitProcedure(Procedure node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitConstructor(Constructor node) {
    throw new PatternMatchFailure();
  }

  @override
  R defaultMember(Member node) {
    throw new UnsupportedError("defaultMember");
  }

  @override
  R visitFunctionDeclaration(FunctionDeclaration node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitVariableDeclaration(VariableDeclaration node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitYieldStatement(YieldStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTryFinally(TryFinally node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTryCatch(TryCatch node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitReturnStatement(ReturnStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitIfStatement(IfStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitContinueSwitchStatement(ContinueSwitchStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSwitchStatement(SwitchStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitForInStatement(ForInStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitForStatement(ForStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitDoStatement(DoStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitWhileStatement(WhileStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitBreakStatement(BreakStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitLabeledStatement(LabeledStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitAssertStatement(AssertStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitEmptyStatement(EmptyStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitAssertBlock(AssertBlock node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitBlock(Block node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitExpressionStatement(ExpressionStatement node) {
    throw new PatternMatchFailure();
  }

  @override
  R defaultStatement(Statement node) {
    throw new UnsupportedError("defaultStatement");
  }

  @override
  R visitCheckLibraryIsLoaded(CheckLibraryIsLoaded node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitLoadLibrary(LoadLibrary node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitInstantiation(Instantiation node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitLet(Let node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitNullLiteral(NullLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitBoolLiteral(BoolLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitDoubleLiteral(DoubleLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitIntLiteral(IntLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitStringLiteral(StringLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitConstantExpression(ConstantExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitFunctionExpression(FunctionExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitAwaitExpression(AwaitExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitMapLiteral(MapLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSetLiteral(SetLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitListLiteral(ListLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitThrow(Throw node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitRethrow(Rethrow node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitThisExpression(ThisExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitTypeLiteral(TypeLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSymbolLiteral(SymbolLiteral node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitAsExpression(AsExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitIsExpression(IsExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitStringConcatenation(StringConcatenation node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitConditionalExpression(ConditionalExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitLogicalExpression(LogicalExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitNot(Not node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitConstructorInvocation(ConstructorInvocation node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitStaticInvocation(StaticInvocation node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSuperMethodInvocation(SuperMethodInvocation node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitDirectMethodInvocation(DirectMethodInvocation node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitMethodInvocation(MethodInvocation node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitStaticSet(StaticSet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitStaticGet(StaticGet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSuperPropertySet(SuperPropertySet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitSuperPropertyGet(SuperPropertyGet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitDirectPropertySet(DirectPropertySet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitDirectPropertyGet(DirectPropertyGet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitPropertySet(PropertySet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitPropertyGet(PropertyGet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitVariableSet(VariableSet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitVariableGet(VariableGet node) {
    throw new PatternMatchFailure();
  }

  @override
  R visitInvalidExpression(InvalidExpression node) {
    throw new PatternMatchFailure();
  }

  @override
  R defaultBasicLiteral(BasicLiteral node) {
    throw new UnsupportedError("defaultBasicLiteral");
  }
}

class KernelEliminator<R> implements Visitor<R> {
  final KernelMatchClosure<R> match;

  const KernelEliminator(this.match);

  R visit(Node node) {
    R result;
    try {
      result = node.accept(match);
    } on PatternMatchFailure catch (e) {
      try {
        result = match.defaultCase(node);
      } on PatternMatchFailure {
        throw T20Error(e);
      } on Obvious catch (e) {
        if (e.id == match.id) {
          rethrow;
        } else {
          throw T20Error(e);
        }
      } catch (e) {
        throw T20Error(e);
      }
    } catch (e) {
      throw T20Error(e);
    }

    if (result == null) {
      throw "fisk";
    }
    return result;
  }

  @override
  R defaultExpression(Expression node) {
    throw new UnsupportedError("defaultExpression");
  }

  @override
  R visitNamedType(NamedType node) {
    return visit(node);
  }

  @override
  R visitSupertype(Supertype node) {
    return visit(node);
  }

  @override
  R visitName(Name node) {
    return visit(node);
  }

  @override
  R visitRedirectingFactoryConstructorReference(
      RedirectingFactoryConstructor node) {
    return visit(node);
  }

  @override
  R visitProcedureReference(Procedure node) {
    return visit(node);
  }

  @override
  R visitConstructorReference(Constructor node) {
    return visit(node);
  }

  @override
  R visitFieldReference(Field node) {
    return visit(node);
  }

  @override
  R defaultMemberReference(Member node) {
    throw new UnsupportedError("defaultMemberReference");
  }

  @override
  R visitUnevaluatedConstantReference(UnevaluatedConstant node) {
    return visit(node);
  }

  @override
  R visitTypeLiteralConstantReference(TypeLiteralConstant node) {
    return visit(node);
  }

  @override
  R visitTearOffConstantReference(TearOffConstant node) {
    return visit(node);
  }

  @override
  R visitPartialInstantiationConstantReference(
      PartialInstantiationConstant node) {
    return visit(node);
  }

  @override
  R visitInstanceConstantReference(InstanceConstant node) {
    return visit(node);
  }

  @override
  R visitListConstantReference(ListConstant node) {
    return visit(node);
  }

  @override
  R visitMapConstantReference(MapConstant node) {
    return visit(node);
  }

  @override
  R visitSymbolConstantReference(SymbolConstant node) {
    return visit(node);
  }

  @override
  R visitStringConstantReference(StringConstant node) {
    return visit(node);
  }

  @override
  R visitDoubleConstantReference(DoubleConstant node) {
    return visit(node);
  }

  @override
  R visitIntConstantReference(IntConstant node) {
    return visit(node);
  }

  @override
  R visitBoolConstantReference(BoolConstant node) {
    return visit(node);
  }

  @override
  R visitNullConstantReference(NullConstant node) {
    return visit(node);
  }

  @override
  R defaultConstantReference(Constant node) {
    throw new UnsupportedError("defaultConstantReference");
  }

  @override
  R visitTypedefReference(Typedef node) {
    return visit(node);
  }

  @override
  R visitClassReference(Class node) {
    return visit(node);
  }

  @override
  R visitUnevaluatedConstant(UnevaluatedConstant node) {
    return visit(node);
  }

  @override
  R visitTypeLiteralConstant(TypeLiteralConstant node) {
    return visit(node);
  }

  @override
  R visitTearOffConstant(TearOffConstant node) {
    return visit(node);
  }

  @override
  R visitPartialInstantiationConstant(PartialInstantiationConstant node) {
    return visit(node);
  }

  @override
  R visitInstanceConstant(InstanceConstant node) {
    return visit(node);
  }

  @override
  R visitListConstant(ListConstant node) {
    return visit(node);
  }

  @override
  R visitMapConstant(MapConstant node) {
    return visit(node);
  }

  @override
  R visitSymbolConstant(SymbolConstant node) {
    return visit(node);
  }

  @override
  R visitStringConstant(StringConstant node) {
    return visit(node);
  }

  @override
  R visitDoubleConstant(DoubleConstant node) {
    return visit(node);
  }

  @override
  R visitIntConstant(IntConstant node) {
    return visit(node);
  }

  @override
  R visitBoolConstant(BoolConstant node) {
    return visit(node);
  }

  @override
  R visitNullConstant(NullConstant node) {
    return visit(node);
  }

  @override
  R defaultConstant(Constant node) {
    throw new UnsupportedError("defaultConstant");
  }

  @override
  R visitTypedefType(TypedefType node) {
    return visit(node);
  }

  @override
  R visitTypeParameterType(TypeParameterType node) {
    return visit(node);
  }

  @override
  R visitFunctionType(FunctionType node) {
    return visit(node);
  }

  @override
  R visitInterfaceType(InterfaceType node) {
    return visit(node);
  }

  @override
  R visitBottomType(BottomType node) {
    return visit(node);
  }

  @override
  R visitVoidType(VoidType node) {
    return visit(node);
  }

  @override
  R visitDynamicType(DynamicType node) {
    return visit(node);
  }

  @override
  R visitInvalidType(InvalidType node) {
    return visit(node);
  }

  @override
  R defaultDartType(DartType node) {
    throw new UnsupportedError("defaultDartType");
  }

  @override
  R defaultTreeNode(TreeNode node) {
    throw new UnsupportedError("defaultTreeNode");
  }

  @override
  R defaultNode(Node node) {
    throw new UnsupportedError("defaultNode");
  }

  @override
  R visitComponent(Component node) {
    return visit(node);
  }

  @override
  R visitMapEntry(MapEntry node) {
    return visit(node);
  }

  @override
  R visitCatch(Catch node) {
    return visit(node);
  }

  @override
  R visitSwitchCase(SwitchCase node) {
    return visit(node);
  }

  @override
  R visitNamedExpression(NamedExpression node) {
    return visit(node);
  }

  @override
  R visitArguments(Arguments node) {
    return visit(node);
  }

  @override
  R visitFunctionNode(FunctionNode node) {
    return visit(node);
  }

  @override
  R visitTypeParameter(TypeParameter node) {
    return visit(node);
  }

  @override
  R visitTypedef(Typedef node) {
    return visit(node);
  }

  @override
  R visitLibraryPart(LibraryPart node) {
    return visit(node);
  }

  @override
  R visitCombinator(Combinator node) {
    return visit(node);
  }

  @override
  R visitLibraryDependency(LibraryDependency node) {
    return visit(node);
  }

  @override
  R visitLibrary(Library node) {
    return visit(node);
  }

  @override
  R visitAssertInitializer(AssertInitializer node) {
    return visit(node);
  }

  @override
  R visitLocalInitializer(LocalInitializer node) {
    return visit(node);
  }

  @override
  R visitRedirectingInitializer(RedirectingInitializer node) {
    return visit(node);
  }

  @override
  R visitSuperInitializer(SuperInitializer node) {
    return visit(node);
  }

  @override
  R visitFieldInitializer(FieldInitializer node) {
    return visit(node);
  }

  @override
  R visitInvalidInitializer(InvalidInitializer node) {
    return visit(node);
  }

  @override
  R defaultInitializer(Initializer node) {
    throw new UnsupportedError("defaultInitializer");
  }

  @override
  R visitClass(Class node) {
    return visit(node);
  }

  @override
  R visitRedirectingFactoryConstructor(RedirectingFactoryConstructor node) {
    return visit(node);
  }

  @override
  R visitField(Field node) {
    return visit(node);
  }

  @override
  R visitProcedure(Procedure node) {
    return visit(node);
  }

  @override
  R visitConstructor(Constructor node) {
    return visit(node);
  }

  @override
  R defaultMember(Member node) {
    throw new UnsupportedError("defaultMember");
  }

  @override
  R visitFunctionDeclaration(FunctionDeclaration node) {
    return visit(node);
  }

  @override
  R visitVariableDeclaration(VariableDeclaration node) {
    return visit(node);
  }

  @override
  R visitYieldStatement(YieldStatement node) {
    return visit(node);
  }

  @override
  R visitTryFinally(TryFinally node) {
    return visit(node);
  }

  @override
  R visitTryCatch(TryCatch node) {
    return visit(node);
  }

  @override
  R visitReturnStatement(ReturnStatement node) {
    return visit(node);
  }

  @override
  R visitIfStatement(IfStatement node) {
    return visit(node);
  }

  @override
  R visitContinueSwitchStatement(ContinueSwitchStatement node) {
    return visit(node);
  }

  @override
  R visitSwitchStatement(SwitchStatement node) {
    return visit(node);
  }

  @override
  R visitForInStatement(ForInStatement node) {
    return visit(node);
  }

  @override
  R visitForStatement(ForStatement node) {
    return visit(node);
  }

  @override
  R visitDoStatement(DoStatement node) {
    return visit(node);
  }

  @override
  R visitWhileStatement(WhileStatement node) {
    return visit(node);
  }

  @override
  R visitBreakStatement(BreakStatement node) {
    return visit(node);
  }

  @override
  R visitLabeledStatement(LabeledStatement node) {
    return visit(node);
  }

  @override
  R visitAssertStatement(AssertStatement node) {
    return visit(node);
  }

  @override
  R visitEmptyStatement(EmptyStatement node) {
    return visit(node);
  }

  @override
  R visitAssertBlock(AssertBlock node) {
    return visit(node);
  }

  @override
  R visitBlock(Block node) {
    return visit(node);
  }

  @override
  R visitExpressionStatement(ExpressionStatement node) {
    return visit(node);
  }

  @override
  R defaultStatement(Statement node) {
    throw new UnsupportedError("defaultStatement");
  }

  @override
  R visitCheckLibraryIsLoaded(CheckLibraryIsLoaded node) {
    return visit(node);
  }

  @override
  R visitLoadLibrary(LoadLibrary node) {
    return visit(node);
  }

  @override
  R visitInstantiation(Instantiation node) {
    return visit(node);
  }

  @override
  R visitLet(Let node) {
    return visit(node);
  }

  @override
  R visitNullLiteral(NullLiteral node) {
    return visit(node);
  }

  @override
  R visitBoolLiteral(BoolLiteral node) {
    return visit(node);
  }

  @override
  R visitDoubleLiteral(DoubleLiteral node) {
    return visit(node);
  }

  @override
  R visitIntLiteral(IntLiteral node) {
    return visit(node);
  }

  @override
  R visitStringLiteral(StringLiteral node) {
    return visit(node);
  }

  @override
  R visitConstantExpression(ConstantExpression node) {
    return visit(node);
  }

  @override
  R visitFunctionExpression(FunctionExpression node) {
    return visit(node);
  }

  @override
  R visitAwaitExpression(AwaitExpression node) {
    return visit(node);
  }

  @override
  R visitMapLiteral(MapLiteral node) {
    return visit(node);
  }

  @override
  R visitSetLiteral(SetLiteral node) {
    return visit(node);
  }

  @override
  R visitListLiteral(ListLiteral node) {
    return visit(node);
  }

  @override
  R visitThrow(Throw node) {
    return visit(node);
  }

  @override
  R visitRethrow(Rethrow node) {
    return visit(node);
  }

  @override
  R visitThisExpression(ThisExpression node) {
    return visit(node);
  }

  @override
  R visitTypeLiteral(TypeLiteral node) {
    return visit(node);
  }

  @override
  R visitSymbolLiteral(SymbolLiteral node) {
    return visit(node);
  }

  @override
  R visitAsExpression(AsExpression node) {
    return visit(node);
  }

  @override
  R visitIsExpression(IsExpression node) {
    return visit(node);
  }

  @override
  R visitStringConcatenation(StringConcatenation node) {
    return visit(node);
  }

  @override
  R visitConditionalExpression(ConditionalExpression node) {
    return visit(node);
  }

  @override
  R visitLogicalExpression(LogicalExpression node) {
    return visit(node);
  }

  @override
  R visitNot(Not node) {
    return visit(node);
  }

  @override
  R visitConstructorInvocation(ConstructorInvocation node) {
    return visit(node);
  }

  @override
  R visitStaticInvocation(StaticInvocation node) {
    return visit(node);
  }

  @override
  R visitSuperMethodInvocation(SuperMethodInvocation node) {
    return visit(node);
  }

  @override
  R visitDirectMethodInvocation(DirectMethodInvocation node) {
    return visit(node);
  }

  @override
  R visitMethodInvocation(MethodInvocation node) {
    return visit(node);
  }

  @override
  R visitStaticSet(StaticSet node) {
    return visit(node);
  }

  @override
  R visitStaticGet(StaticGet node) {
    return visit(node);
  }

  @override
  R visitSuperPropertySet(SuperPropertySet node) {
    return visit(node);
  }

  @override
  R visitSuperPropertyGet(SuperPropertyGet node) {
    return visit(node);
  }

  @override
  R visitDirectPropertySet(DirectPropertySet node) {
    return visit(node);
  }

  @override
  R visitDirectPropertyGet(DirectPropertyGet node) {
    return visit(node);
  }

  @override
  R visitPropertySet(PropertySet node) {
    return visit(node);
  }

  @override
  R visitPropertyGet(PropertyGet node) {
    return visit(node);
  }

  @override
  R visitVariableSet(VariableSet node) {
    return visit(node);
  }

  @override
  R visitVariableGet(VariableGet node) {
    return visit(node);
  }

  @override
  R visitInvalidExpression(InvalidExpression node) {
    return visit(node);
  }

  @override
  R defaultBasicLiteral(BasicLiteral node) {
    throw new UnsupportedError("defaultBasicLiteral");
  }
}

abstract class MemberVisitor1<R, T> {
  const MemberVisitor1();

  R defaultMember(Member node, T arg) => null;

  R visitConstructor(Constructor node, T arg) => defaultMember(node, arg);
  R visitProcedure(Procedure node, T arg) => defaultMember(node, arg);
  R visitField(Field node, T arg) => defaultMember(node, arg);
  R visitRedirectingFactoryConstructor(
      RedirectingFactoryConstructor node, T arg) {
    return defaultMember(node, arg);
  }
}

abstract class InitializerVisitor1<R, T> {
  const InitializerVisitor1();

  R defaultInitializer(Initializer node, T arg) => null;

  R visitInvalidInitializer(InvalidInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitFieldInitializer(FieldInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitSuperInitializer(SuperInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitRedirectingInitializer(RedirectingInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitLocalInitializer(LocalInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitAssertInitializer(AssertInitializer node, T arg) =>
      defaultInitializer(node, arg);
}

class TreeVisitor1<R, T>
    implements
        ExpressionVisitor1<R, T>,
        StatementVisitor1<R, T>,
        MemberVisitor1<R, T>,
        InitializerVisitor1<R, T> {
  const TreeVisitor1();

  R defaultTreeNode(TreeNode node, T arg) => null;

  // Expressions
  R defaultExpression(Expression node, T arg) => defaultTreeNode(node, arg);
  R defaultBasicLiteral(BasicLiteral node, T arg) =>
      defaultExpression(node, arg);
  R visitInvalidExpression(InvalidExpression node, T arg) =>
      defaultExpression(node, arg);
  R visitVariableGet(VariableGet node, T arg) => defaultExpression(node, arg);
  R visitVariableSet(VariableSet node, T arg) => defaultExpression(node, arg);
  R visitPropertyGet(PropertyGet node, T arg) => defaultExpression(node, arg);
  R visitPropertySet(PropertySet node, T arg) => defaultExpression(node, arg);
  R visitDirectPropertyGet(DirectPropertyGet node, T arg) =>
      defaultExpression(node, arg);
  R visitDirectPropertySet(DirectPropertySet node, T arg) =>
      defaultExpression(node, arg);
  R visitSuperPropertyGet(SuperPropertyGet node, T arg) =>
      defaultExpression(node, arg);
  R visitSuperPropertySet(SuperPropertySet node, T arg) =>
      defaultExpression(node, arg);
  R visitStaticGet(StaticGet node, T arg) => defaultExpression(node, arg);
  R visitStaticSet(StaticSet node, T arg) => defaultExpression(node, arg);
  R visitMethodInvocation(MethodInvocation node, T arg) =>
      defaultExpression(node, arg);
  R visitDirectMethodInvocation(DirectMethodInvocation node, T arg) =>
      defaultExpression(node, arg);
  R visitSuperMethodInvocation(SuperMethodInvocation node, T arg) =>
      defaultExpression(node, arg);
  R visitStaticInvocation(StaticInvocation node, T arg) =>
      defaultExpression(node, arg);
  R visitConstructorInvocation(ConstructorInvocation node, T arg) =>
      defaultExpression(node, arg);
  R visitNot(Not node, T arg) => defaultExpression(node, arg);
  R visitLogicalExpression(LogicalExpression node, T arg) =>
      defaultExpression(node, arg);
  R visitConditionalExpression(ConditionalExpression node, T arg) =>
      defaultExpression(node, arg);
  R visitStringConcatenation(StringConcatenation node, T arg) =>
      defaultExpression(node, arg);
  R visitIsExpression(IsExpression node, T arg) => defaultExpression(node, arg);
  R visitAsExpression(AsExpression node, T arg) => defaultExpression(node, arg);
  R visitSymbolLiteral(SymbolLiteral node, T arg) =>
      defaultExpression(node, arg);
  R visitTypeLiteral(TypeLiteral node, T arg) => defaultExpression(node, arg);
  R visitThisExpression(ThisExpression node, T arg) =>
      defaultExpression(node, arg);
  R visitRethrow(Rethrow node, T arg) => defaultExpression(node, arg);
  R visitThrow(Throw node, T arg) => defaultExpression(node, arg);
  R visitListLiteral(ListLiteral node, T arg) => defaultExpression(node, arg);
  R visitSetLiteral(SetLiteral node, T arg) => defaultExpression(node, arg);
  R visitMapLiteral(MapLiteral node, T arg) => defaultExpression(node, arg);
  R visitAwaitExpression(AwaitExpression node, T arg) =>
      defaultExpression(node, arg);
  R visitFunctionExpression(FunctionExpression node, T arg) =>
      defaultExpression(node, arg);
  R visitConstantExpression(ConstantExpression node, arg) =>
      defaultExpression(node, arg);
  R visitStringLiteral(StringLiteral node, T arg) =>
      defaultBasicLiteral(node, arg);
  R visitIntLiteral(IntLiteral node, T arg) => defaultBasicLiteral(node, arg);
  R visitDoubleLiteral(DoubleLiteral node, T arg) =>
      defaultBasicLiteral(node, arg);
  R visitBoolLiteral(BoolLiteral node, T arg) => defaultBasicLiteral(node, arg);
  R visitNullLiteral(NullLiteral node, T arg) => defaultBasicLiteral(node, arg);
  R visitLet(Let node, T arg) => defaultExpression(node, arg);
  R visitInstantiation(Instantiation node, T arg) =>
      defaultExpression(node, arg);
  R visitLoadLibrary(LoadLibrary node, T arg) => defaultExpression(node, arg);
  R visitCheckLibraryIsLoaded(CheckLibraryIsLoaded node, T arg) =>
      defaultExpression(node, arg);

  // Statements
  R defaultStatement(Statement node, T arg) => defaultTreeNode(node, arg);
  R visitExpressionStatement(ExpressionStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitBlock(Block node, T arg) => defaultStatement(node, arg);
  R visitAssertBlock(AssertBlock node, T arg) => defaultStatement(node, arg);
  R visitEmptyStatement(EmptyStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitAssertStatement(AssertStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitLabeledStatement(LabeledStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitBreakStatement(BreakStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitWhileStatement(WhileStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitDoStatement(DoStatement node, T arg) => defaultStatement(node, arg);
  R visitForStatement(ForStatement node, T arg) => defaultStatement(node, arg);
  R visitForInStatement(ForInStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitSwitchStatement(SwitchStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitContinueSwitchStatement(ContinueSwitchStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitIfStatement(IfStatement node, T arg) => defaultStatement(node, arg);
  R visitReturnStatement(ReturnStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitTryCatch(TryCatch node, T arg) => defaultStatement(node, arg);
  R visitTryFinally(TryFinally node, T arg) => defaultStatement(node, arg);
  R visitYieldStatement(YieldStatement node, T arg) =>
      defaultStatement(node, arg);
  R visitVariableDeclaration(VariableDeclaration node, T arg) =>
      defaultStatement(node, arg);
  R visitFunctionDeclaration(FunctionDeclaration node, T arg) =>
      defaultStatement(node, arg);

  // Members
  R defaultMember(Member node, T arg) => defaultTreeNode(node, arg);
  R visitConstructor(Constructor node, T arg) => defaultMember(node, arg);
  R visitProcedure(Procedure node, T arg) => defaultMember(node, arg);
  R visitField(Field node, T arg) => defaultMember(node, arg);
  R visitRedirectingFactoryConstructor(
      RedirectingFactoryConstructor node, T arg) {
    return defaultMember(node, arg);
  }

  // Classes
  R visitClass(Class node, T arg) => defaultTreeNode(node, arg);

  // Initializers
  R defaultInitializer(Initializer node, T arg) => defaultTreeNode(node, arg);
  R visitInvalidInitializer(InvalidInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitFieldInitializer(FieldInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitSuperInitializer(SuperInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitRedirectingInitializer(RedirectingInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitLocalInitializer(LocalInitializer node, T arg) =>
      defaultInitializer(node, arg);
  R visitAssertInitializer(AssertInitializer node, T arg) =>
      defaultInitializer(node, arg);

  // Other tree nodes
  R visitLibrary(Library node, T arg) => defaultTreeNode(node, arg);
  R visitLibraryDependency(LibraryDependency node, T arg) =>
      defaultTreeNode(node, arg);
  R visitCombinator(Combinator node, T arg) => defaultTreeNode(node, arg);
  R visitLibraryPart(LibraryPart node, T arg) => defaultTreeNode(node, arg);
  R visitTypedef(Typedef node, T arg) => defaultTreeNode(node, arg);
  R visitTypeParameter(TypeParameter node, T arg) => defaultTreeNode(node, arg);
  R visitFunctionNode(FunctionNode node, T arg) => defaultTreeNode(node, arg);
  R visitArguments(Arguments node, T arg) => defaultTreeNode(node, arg);
  R visitNamedExpression(NamedExpression node, T arg) =>
      defaultTreeNode(node, arg);
  R visitSwitchCase(SwitchCase node, T arg) => defaultTreeNode(node, arg);
  R visitCatch(Catch node, T arg) => defaultTreeNode(node, arg);
  R visitMapEntry(MapEntry node, T arg) => defaultTreeNode(node, arg);
  R visitComponent(Component node, T arg) => defaultTreeNode(node, arg);
}

class ConstantVisitor1<R, T> {
  R defaultConstant(Constant node, T arg) => null;

  R visitNullConstant(NullConstant node, T arg) => defaultConstant(node, arg);
  R visitBoolConstant(BoolConstant node, T arg) => defaultConstant(node, arg);
  R visitIntConstant(IntConstant node, T arg) => defaultConstant(node, arg);
  R visitDoubleConstant(DoubleConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitStringConstant(StringConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitSymbolConstant(SymbolConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitMapConstant(MapConstant node, T arg) => defaultConstant(node, arg);
  R visitListConstant(ListConstant node, T arg) => defaultConstant(node, arg);
  R visitInstanceConstant(InstanceConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitPartialInstantiationConstant(
          PartialInstantiationConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitTearOffConstant(TearOffConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitTypeLiteralConstant(TypeLiteralConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitUnevaluatedConstant(UnevaluatedConstant node, T arg) =>
      defaultConstant(node, arg);
}

class MemberReferenceVisitor1<R, T> {
  const MemberReferenceVisitor1();

  R defaultMemberReference(Member node, T arg) => null;

  R visitFieldReference(Field node, T arg) => defaultMemberReference(node, arg);
  R visitConstructorReference(Constructor node, T arg) =>
      defaultMemberReference(node, arg);
  R visitProcedureReference(Procedure node, T arg) =>
      defaultMemberReference(node, arg);
  R visitRedirectingFactoryConstructorReference(
      RedirectingFactoryConstructor node, T arg) {
    return defaultMemberReference(node, arg);
  }
}

class Visitor1<R, T> extends TreeVisitor1<R, T>
    implements
        DartTypeVisitor1<R, T>,
        ConstantVisitor1<R, T>,
        MemberReferenceVisitor1<R, T> {
  const Visitor1();

  /// The catch-all case, except for references.
  R defaultNode(Node node, T arg) => null;
  R defaultTreeNode(TreeNode node, T arg) => defaultNode(node, arg);

  // DartTypes
  R defaultDartType(DartType node, T arg) => defaultNode(node, arg);
  R visitInvalidType(InvalidType node, T arg) => defaultDartType(node, arg);
  R visitDynamicType(DynamicType node, T arg) => defaultDartType(node, arg);
  R visitVoidType(VoidType node, T arg) => defaultDartType(node, arg);
  R visitBottomType(BottomType node, T arg) => defaultDartType(node, arg);
  R visitInterfaceType(InterfaceType node, T arg) => defaultDartType(node, arg);
  R visitFunctionType(FunctionType node, T arg) => defaultDartType(node, arg);
  R visitTypeParameterType(TypeParameterType node, T arg) =>
      defaultDartType(node, arg);
  R visitTypedefType(TypedefType node, T arg) => defaultDartType(node, arg);

  // Constants
  R defaultConstant(Constant node, T arg) => defaultNode(node, arg);
  R visitNullConstant(NullConstant node, T arg) => defaultConstant(node, arg);
  R visitBoolConstant(BoolConstant node, T arg) => defaultConstant(node, arg);
  R visitIntConstant(IntConstant node, T arg) => defaultConstant(node, arg);
  R visitDoubleConstant(DoubleConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitStringConstant(StringConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitSymbolConstant(SymbolConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitMapConstant(MapConstant node, T arg) => defaultConstant(node, arg);
  R visitListConstant(ListConstant node, T arg) => defaultConstant(node, arg);
  R visitInstanceConstant(InstanceConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitPartialInstantiationConstant(
          PartialInstantiationConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitTearOffConstant(TearOffConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitTypeLiteralConstant(TypeLiteralConstant node, T arg) =>
      defaultConstant(node, arg);
  R visitUnevaluatedConstant(UnevaluatedConstant node, T arg) =>
      defaultConstant(node, arg);

  // Class references
  R visitClassReference(Class node, T arg) => null;
  R visitTypedefReference(Typedef node, T arg) => null;

  // Constant references
  R defaultConstantReference(Constant node, T arg) => null;
  R visitNullConstantReference(NullConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitBoolConstantReference(BoolConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitIntConstantReference(IntConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitDoubleConstantReference(DoubleConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitStringConstantReference(StringConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitSymbolConstantReference(SymbolConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitMapConstantReference(MapConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitListConstantReference(ListConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitInstanceConstantReference(InstanceConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitPartialInstantiationConstantReference(
          PartialInstantiationConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitTearOffConstantReference(TearOffConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitTypeLiteralConstantReference(TypeLiteralConstant node, T arg) =>
      defaultConstantReference(node, arg);
  R visitUnevaluatedConstantReference(UnevaluatedConstant node, T arg) =>
      defaultConstantReference(node, arg);

  // Member references
  R defaultMemberReference(Member node, T arg) => null;
  R visitFieldReference(Field node, T arg) => defaultMemberReference(node, arg);
  R visitConstructorReference(Constructor node, T arg) =>
      defaultMemberReference(node, arg);
  R visitProcedureReference(Procedure node, T arg) =>
      defaultMemberReference(node, arg);
  R visitRedirectingFactoryConstructorReference(
      RedirectingFactoryConstructor node, T arg) {
    return defaultMemberReference(node, arg);
  }

  R visitName(Name node, T arg) => defaultNode(node, arg);
  R visitSupertype(Supertype node, T arg) => defaultNode(node, arg);
  R visitNamedType(NamedType node, T arg) => defaultNode(node, arg);
}

class KernelBottomupFolder<R> implements Visitor<R> {
  final Visitor1<R, R> function;

  final R Function(R, R) compose;

  final R unit;

  final List<R> results = <R>[];

  KernelBottomupFolder(this.function, this.compose, this.unit);

  R visit(Node node, R Function(R) functionOnNode) {
    int resultsCount = results.length;
    node.visitChildren(this);
    R result = unit;
    for (int i = resultsCount; i < results.length; ++i) {
      result = compose(result, results[i]);
    }
    results.length = resultsCount;
    result = functionOnNode(result);
    results.add(result);
    return result;
  }

  @override
  R defaultExpression(Expression node) {
    throw new UnsupportedError("defaultExpression");
  }

  @override
  R visitNamedType(NamedType node) {
    return visit(node, (R result) {
      return function.visitNamedType(node, result);
    });
  }

  @override
  R visitSupertype(Supertype node) {
    return visit(node, (R result) {
      return function.visitSupertype(node, result);
    });
  }

  @override
  R visitName(Name node) {
    return visit(node, (R result) {
      return function.visitName(node, result);
    });
  }

  @override
  R visitRedirectingFactoryConstructorReference(
      RedirectingFactoryConstructor node) {
    return null;
  }

  @override
  R visitProcedureReference(Procedure node) {
    return null;
  }

  @override
  R visitConstructorReference(Constructor node) {
    return null;
  }

  @override
  R visitFieldReference(Field node) {
    return null;
  }

  @override
  R defaultMemberReference(Member node) {
    throw new UnsupportedError("defaultMemberReference");
  }

  @override
  R visitUnevaluatedConstantReference(UnevaluatedConstant node) {
    return null;
  }

  @override
  R visitTypeLiteralConstantReference(TypeLiteralConstant node) {
    return null;
  }

  @override
  R visitTearOffConstantReference(TearOffConstant node) {
    return null;
  }

  @override
  R visitPartialInstantiationConstantReference(
      PartialInstantiationConstant node) {
    return null;
  }

  @override
  R visitInstanceConstantReference(InstanceConstant node) {
    return null;
  }

  @override
  R visitListConstantReference(ListConstant node) {
    return null;
  }

  @override
  R visitMapConstantReference(MapConstant node) {
    return null;
  }

  @override
  R visitSymbolConstantReference(SymbolConstant node) {
    return null;
  }

  @override
  R visitStringConstantReference(StringConstant node) {
    return null;
  }

  @override
  R visitDoubleConstantReference(DoubleConstant node) {
    return null;
  }

  @override
  R visitIntConstantReference(IntConstant node) {
    return null;
  }

  @override
  R visitBoolConstantReference(BoolConstant node) {
    return null;
  }

  @override
  R visitNullConstantReference(NullConstant node) {
    return null;
  }

  @override
  R defaultConstantReference(Constant node) {
    throw new UnsupportedError("defaultConstantReference");
  }

  @override
  R visitTypedefReference(Typedef node) {
    return null;
  }

  @override
  R visitClassReference(Class node) {
    return null;
  }

  @override
  R visitUnevaluatedConstant(UnevaluatedConstant node) {
    return visit(node, (R result) {
      return function.visitUnevaluatedConstant(node, result);
    });
  }

  @override
  R visitTypeLiteralConstant(TypeLiteralConstant node) {
    return visit(node, (R result) {
      return function.visitTypeLiteralConstant(node, result);
    });
  }

  @override
  R visitTearOffConstant(TearOffConstant node) {
    return visit(node, (R result) {
      return function.visitTearOffConstant(node, result);
    });
  }

  @override
  R visitPartialInstantiationConstant(PartialInstantiationConstant node) {
    return visit(node, (R result) {
      return function.visitPartialInstantiationConstant(node, result);
    });
  }

  @override
  R visitInstanceConstant(InstanceConstant node) {
    return visit(node, (R result) {
      return function.visitInstanceConstant(node, result);
    });
  }

  @override
  R visitListConstant(ListConstant node) {
    return visit(node, (R result) {
      return function.visitListConstant(node, result);
    });
  }

  @override
  R visitMapConstant(MapConstant node) {
    return visit(node, (R result) {
      return function.visitMapConstant(node, result);
    });
  }

  @override
  R visitSymbolConstant(SymbolConstant node) {
    return visit(node, (R result) {
      return function.visitSymbolConstant(node, result);
    });
  }

  @override
  R visitStringConstant(StringConstant node) {
    return visit(node, (R result) {
      return function.visitStringConstant(node, result);
    });
  }

  @override
  R visitDoubleConstant(DoubleConstant node) {
    return visit(node, (R result) {
      return function.visitDoubleConstant(node, result);
    });
  }

  @override
  R visitIntConstant(IntConstant node) {
    return visit(node, (R result) {
      return function.visitIntConstant(node, result);
    });
  }

  @override
  R visitBoolConstant(BoolConstant node) {
    return visit(node, (R result) {
      return function.visitBoolConstant(node, result);
    });
  }

  @override
  R visitNullConstant(NullConstant node) {
    return visit(node, (R result) {
      return function.visitNullConstant(node, result);
    });
  }

  @override
  R defaultConstant(Constant node) {
    throw new UnsupportedError("defaultConstant");
  }

  @override
  R visitTypedefType(TypedefType node) {
    return visit(node, (R result) {
      return function.visitTypedefType(node, result);
    });
  }

  @override
  R visitTypeParameterType(TypeParameterType node) {
    return visit(node, (R result) {
      return function.visitTypeParameterType(node, result);
    });
  }

  @override
  R visitFunctionType(FunctionType node) {
    return visit(node, (R result) {
      return function.visitFunctionType(node, result);
    });
  }

  @override
  R visitInterfaceType(InterfaceType node) {
    return visit(node, (R result) {
      return function.visitInterfaceType(node, result);
    });
  }

  @override
  R visitBottomType(BottomType node) {
    return visit(node, (R result) {
      return function.visitBottomType(node, result);
    });
  }

  @override
  R visitVoidType(VoidType node) {
    return visit(node, (R result) {
      return function.visitVoidType(node, result);
    });
  }

  @override
  R visitDynamicType(DynamicType node) {
    return visit(node, (R result) {
      return function.visitDynamicType(node, result);
    });
  }

  @override
  R visitInvalidType(InvalidType node) {
    return visit(node, (R result) {
      return function.visitInvalidType(node, result);
    });
  }

  @override
  R defaultDartType(DartType node) {
    throw new UnsupportedError("defaultDartType");
  }

  @override
  R defaultTreeNode(TreeNode node) {
    throw new UnsupportedError("defaultTreeNode");
  }

  @override
  R defaultNode(Node node) {
    throw new UnsupportedError("defaultNode");
  }

  @override
  R visitComponent(Component node) {
    return visit(node, (R result) {
      return function.visitComponent(node, result);
    });
  }

  @override
  R visitMapEntry(MapEntry node) {
    return visit(node, (R result) {
      return function.visitMapEntry(node, result);
    });
  }

  @override
  R visitCatch(Catch node) {
    return visit(node, (R result) {
      return function.visitCatch(node, result);
    });
  }

  @override
  R visitSwitchCase(SwitchCase node) {
    return visit(node, (R result) {
      return function.visitSwitchCase(node, result);
    });
  }

  @override
  R visitNamedExpression(NamedExpression node) {
    return visit(node, (R result) {
      return function.visitNamedExpression(node, result);
    });
  }

  @override
  R visitArguments(Arguments node) {
    return visit(node, (R result) {
      return function.visitArguments(node, result);
    });
  }

  @override
  R visitFunctionNode(FunctionNode node) {
    return visit(node, (R result) {
      return function.visitFunctionNode(node, result);
    });
  }

  @override
  R visitTypeParameter(TypeParameter node) {
    return visit(node, (R result) {
      return function.visitTypeParameter(node, result);
    });
  }

  @override
  R visitTypedef(Typedef node) {
    return visit(node, (R result) {
      return function.visitTypedef(node, result);
    });
  }

  @override
  R visitLibraryPart(LibraryPart node) {
    return visit(node, (R result) {
      return function.visitLibraryPart(node, result);
    });
  }

  @override
  R visitCombinator(Combinator node) {
    return visit(node, (R result) {
      return function.visitCombinator(node, result);
    });
  }

  @override
  R visitLibraryDependency(LibraryDependency node) {
    return visit(node, (R result) {
      return function.visitLibraryDependency(node, result);
    });
  }

  @override
  R visitLibrary(Library node) {
    return visit(node, (R result) {
      return function.visitLibrary(node, result);
    });
  }

  @override
  R visitAssertInitializer(AssertInitializer node) {
    return visit(node, (R result) {
      return function.visitAssertInitializer(node, result);
    });
  }

  @override
  R visitLocalInitializer(LocalInitializer node) {
    return visit(node, (R result) {
      return function.visitLocalInitializer(node, result);
    });
  }

  @override
  R visitRedirectingInitializer(RedirectingInitializer node) {
    return visit(node, (R result) {
      return function.visitRedirectingInitializer(node, result);
    });
  }

  @override
  R visitSuperInitializer(SuperInitializer node) {
    return visit(node, (R result) {
      return function.visitSuperInitializer(node, result);
    });
  }

  @override
  R visitFieldInitializer(FieldInitializer node) {
    return visit(node, (R result) {
      return function.visitFieldInitializer(node, result);
    });
  }

  @override
  R visitInvalidInitializer(InvalidInitializer node) {
    return visit(node, (R result) {
      return function.visitInvalidInitializer(node, result);
    });
  }

  @override
  R defaultInitializer(Initializer node) {
    throw new UnsupportedError("defaultInitializer");
  }

  @override
  R visitClass(Class node) {
    return visit(node, (R result) {
      return function.visitClass(node, result);
    });
  }

  @override
  R visitRedirectingFactoryConstructor(RedirectingFactoryConstructor node) {
    return visit(node, (R result) {
      return function.visitRedirectingFactoryConstructor(node, result);
    });
  }

  @override
  R visitField(Field node) {
    return visit(node, (R result) {
      return function.visitField(node, result);
    });
  }

  @override
  R visitProcedure(Procedure node) {
    return visit(node, (R result) {
      return function.visitProcedure(node, result);
    });
  }

  @override
  R visitConstructor(Constructor node) {
    return visit(node, (R result) {
      return function.visitConstructor(node, result);
    });
  }

  @override
  R defaultMember(Member node) {
    throw new UnsupportedError("defaultMember");
  }

  @override
  R visitFunctionDeclaration(FunctionDeclaration node) {
    return visit(node, (R result) {
      return function.visitFunctionDeclaration(node, result);
    });
  }

  @override
  R visitVariableDeclaration(VariableDeclaration node) {
    return visit(node, (R result) {
      return function.visitVariableDeclaration(node, result);
    });
  }

  @override
  R visitYieldStatement(YieldStatement node) {
    return visit(node, (R result) {
      return function.visitYieldStatement(node, result);
    });
  }

  @override
  R visitTryFinally(TryFinally node) {
    return visit(node, (R result) {
      return function.visitTryFinally(node, result);
    });
  }

  @override
  R visitTryCatch(TryCatch node) {
    return visit(node, (R result) {
      return function.visitTryCatch(node, result);
    });
  }

  @override
  R visitReturnStatement(ReturnStatement node) {
    return visit(node, (R result) {
      return function.visitReturnStatement(node, result);
    });
  }

  @override
  R visitIfStatement(IfStatement node) {
    return visit(node, (R result) {
      return function.visitIfStatement(node, result);
    });
  }

  @override
  R visitContinueSwitchStatement(ContinueSwitchStatement node) {
    return visit(node, (R result) {
      return function.visitContinueSwitchStatement(node, result);
    });
  }

  @override
  R visitSwitchStatement(SwitchStatement node) {
    return visit(node, (R result) {
      return function.visitSwitchStatement(node, result);
    });
  }

  @override
  R visitForInStatement(ForInStatement node) {
    return visit(node, (R result) {
      return function.visitForInStatement(node, result);
    });
  }

  @override
  R visitForStatement(ForStatement node) {
    return visit(node, (R result) {
      return function.visitForStatement(node, result);
    });
  }

  @override
  R visitDoStatement(DoStatement node) {
    return visit(node, (R result) {
      return function.visitDoStatement(node, result);
    });
  }

  @override
  R visitWhileStatement(WhileStatement node) {
    return visit(node, (R result) {
      return function.visitWhileStatement(node, result);
    });
  }

  @override
  R visitBreakStatement(BreakStatement node) {
    return visit(node, (R result) {
      return function.visitBreakStatement(node, result);
    });
  }

  @override
  R visitLabeledStatement(LabeledStatement node) {
    return visit(node, (R result) {
      return function.visitLabeledStatement(node, result);
    });
  }

  @override
  R visitAssertStatement(AssertStatement node) {
    return visit(node, (R result) {
      return function.visitAssertStatement(node, result);
    });
  }

  @override
  R visitEmptyStatement(EmptyStatement node) {
    return visit(node, (R result) {
      return function.visitEmptyStatement(node, result);
    });
  }

  @override
  R visitAssertBlock(AssertBlock node) {
    return visit(node, (R result) {
      return function.visitAssertBlock(node, result);
    });
  }

  @override
  R visitBlock(Block node) {
    return visit(node, (R result) {
      return function.visitBlock(node, result);
    });
  }

  @override
  R visitExpressionStatement(ExpressionStatement node) {
    return visit(node, (R result) {
      return function.visitExpressionStatement(node, result);
    });
  }

  @override
  R defaultStatement(Statement node) {
    throw new UnsupportedError("defaultStatement");
  }

  @override
  R visitCheckLibraryIsLoaded(CheckLibraryIsLoaded node) {
    return visit(node, (R result) {
      return function.visitCheckLibraryIsLoaded(node, result);
    });
  }

  @override
  R visitLoadLibrary(LoadLibrary node) {
    return visit(node, (R result) {
      return function.visitLoadLibrary(node, result);
    });
  }

  @override
  R visitInstantiation(Instantiation node) {
    return visit(node, (R result) {
      return function.visitInstantiation(node, result);
    });
  }

  @override
  R visitLet(Let node) {
    return visit(node, (R result) {
      return function.visitLet(node, result);
    });
  }

  @override
  R visitNullLiteral(NullLiteral node) {
    return visit(node, (R result) {
      return function.visitNullLiteral(node, result);
    });
  }

  @override
  R visitBoolLiteral(BoolLiteral node) {
    return visit(node, (R result) {
      return function.visitBoolLiteral(node, result);
    });
  }

  @override
  R visitDoubleLiteral(DoubleLiteral node) {
    return visit(node, (R result) {
      return function.visitDoubleLiteral(node, result);
    });
  }

  @override
  R visitIntLiteral(IntLiteral node) {
    return visit(node, (R result) {
      return function.visitIntLiteral(node, result);
    });
  }

  @override
  R visitStringLiteral(StringLiteral node) {
    return visit(node, (R result) {
      return function.visitStringLiteral(node, result);
    });
  }

  @override
  R visitConstantExpression(ConstantExpression node) {
    return visit(node, (R result) {
      return function.visitConstantExpression(node, result);
    });
  }

  @override
  R visitFunctionExpression(FunctionExpression node) {
    return visit(node, (R result) {
      return function.visitFunctionExpression(node, result);
    });
  }

  @override
  R visitAwaitExpression(AwaitExpression node) {
    return visit(node, (R result) {
      return function.visitAwaitExpression(node, result);
    });
  }

  @override
  R visitMapLiteral(MapLiteral node) {
    return visit(node, (R result) {
      return function.visitMapLiteral(node, result);
    });
  }

  @override
  R visitSetLiteral(SetLiteral node) {
    return visit(node, (R result) {
      return function.visitSetLiteral(node, result);
    });
  }

  @override
  R visitListLiteral(ListLiteral node) {
    return visit(node, (R result) {
      return function.visitListLiteral(node, result);
    });
  }

  @override
  R visitThrow(Throw node) {
    return visit(node, (R result) {
      return function.visitThrow(node, result);
    });
  }

  @override
  R visitRethrow(Rethrow node) {
    return visit(node, (R result) {
      return function.visitRethrow(node, result);
    });
  }

  @override
  R visitThisExpression(ThisExpression node) {
    return visit(node, (R result) {
      return function.visitThisExpression(node, result);
    });
  }

  @override
  R visitTypeLiteral(TypeLiteral node) {
    return visit(node, (R result) {
      return function.visitTypeLiteral(node, result);
    });
  }

  @override
  R visitSymbolLiteral(SymbolLiteral node) {
    return visit(node, (R result) {
      return function.visitSymbolLiteral(node, result);
    });
  }

  @override
  R visitAsExpression(AsExpression node) {
    return visit(node, (R result) {
      return function.visitAsExpression(node, result);
    });
  }

  @override
  R visitIsExpression(IsExpression node) {
    return visit(node, (R result) {
      return function.visitIsExpression(node, result);
    });
  }

  @override
  R visitStringConcatenation(StringConcatenation node) {
    return visit(node, (R result) {
      return function.visitStringConcatenation(node, result);
    });
  }

  @override
  R visitConditionalExpression(ConditionalExpression node) {
    return visit(node, (R result) {
      return function.visitConditionalExpression(node, result);
    });
  }

  @override
  R visitLogicalExpression(LogicalExpression node) {
    return visit(node, (R result) {
      return function.visitLogicalExpression(node, result);
    });
  }

  @override
  R visitNot(Not node) {
    return visit(node, (R result) {
      return function.visitNot(node, result);
    });
  }

  @override
  R visitConstructorInvocation(ConstructorInvocation node) {
    return visit(node, (R result) {
      return function.visitConstructorInvocation(node, result);
    });
  }

  @override
  R visitStaticInvocation(StaticInvocation node) {
    return visit(node, (R result) {
      return function.visitStaticInvocation(node, result);
    });
  }

  @override
  R visitSuperMethodInvocation(SuperMethodInvocation node) {
    return visit(node, (R result) {
      return function.visitSuperMethodInvocation(node, result);
    });
  }

  @override
  R visitDirectMethodInvocation(DirectMethodInvocation node) {
    return visit(node, (R result) {
      return function.visitDirectMethodInvocation(node, result);
    });
  }

  @override
  R visitMethodInvocation(MethodInvocation node) {
    return visit(node, (R result) {
      return function.visitMethodInvocation(node, result);
    });
  }

  @override
  R visitStaticSet(StaticSet node) {
    return visit(node, (R result) {
      return function.visitStaticSet(node, result);
    });
  }

  @override
  R visitStaticGet(StaticGet node) {
    return visit(node, (R result) {
      return function.visitStaticGet(node, result);
    });
  }

  @override
  R visitSuperPropertySet(SuperPropertySet node) {
    return visit(node, (R result) {
      return function.visitSuperPropertySet(node, result);
    });
  }

  @override
  R visitSuperPropertyGet(SuperPropertyGet node) {
    return visit(node, (R result) {
      return function.visitSuperPropertyGet(node, result);
    });
  }

  @override
  R visitDirectPropertySet(DirectPropertySet node) {
    return visit(node, (R result) {
      return function.visitDirectPropertySet(node, result);
    });
  }

  @override
  R visitDirectPropertyGet(DirectPropertyGet node) {
    return visit(node, (R result) {
      return function.visitDirectPropertyGet(node, result);
    });
  }

  @override
  R visitPropertySet(PropertySet node) {
    return visit(node, (R result) {
      return function.visitPropertySet(node, result);
    });
  }

  @override
  R visitPropertyGet(PropertyGet node) {
    return visit(node, (R result) {
      return function.visitPropertyGet(node, result);
    });
  }

  @override
  R visitVariableSet(VariableSet node) {
    return visit(node, (R result) {
      return function.visitVariableSet(node, result);
    });
  }

  @override
  R visitVariableGet(VariableGet node) {
    return visit(node, (R result) {
      return function.visitVariableGet(node, result);
    });
  }

  @override
  R visitInvalidExpression(InvalidExpression node) {
    return visit(node, (R result) {
      return function.visitInvalidExpression(node, result);
    });
  }

  @override
  R defaultBasicLiteral(BasicLiteral node) {
    throw new UnsupportedError("defaultBasicLiteral");
  }
}


class CaseSplitter extends Visitor1<Node, Node> {
  @override
  defaultNode(Node node, _) {
    if (node is TreeNode) {
      return handleAnyTreeNode(node, null);
    }
    return node;
  }

  @override
  defaultBasicLiteral(BasicLiteral node, _) {
    return handleAnyTreeNode(node, null);
  }

  @override
  defaultConstant(Constant node, _) => node;

  @override
  defaultConstantReference(Constant node, _) => node;

  @override
  defaultDartType(DartType node, _) => node;

  @override
  defaultExpression(Expression node, _) {
    return handleAnyTreeNode(node, null);
  }

  @override
  defaultInitializer(Initializer node, _) {
    return handleAnyTreeNode(node, null);
  }

  @override
  defaultMember(Member node, _) {
    return handleAnyTreeNode(node, null);
  }

  @override
  defaultMemberReference(Member node, _) {
    return handleAnyTreeNode(node, null);
  }

  @override
  defaultStatement(Statement node, _) {
    return handleAnyTreeNode(node, null);
  }

  @override
  defaultTreeNode(TreeNode node, _) {
    return handleAnyTreeNode(node, null);
  }

  final dynamic expression;
  final dynamic statement;

  Node handleAnyTreeNode(TreeNode node, _) {
    Node transformed;
    if (node is Expression) {
      transformed = expression(node);
    } else if (node is Statement) {
      transformed = statement(node);
    } else {
      transformed = node;
    }

    // Should be added after the "functional" part if we may destroy the
    // original tree.

    if (node is! Component && !identical(node, transformed)) {
      // Components don't have parents.
      node.replaceWith(transformed);
    }

    return transformed;
  }

  CaseSplitter(this.statement, this.expression);
}

// (transform-component! component id silly-intliteral-transform)
// (define (silly-intliteral-transform exp)
//    (match exp
//     [(IntLiteral value) (IntLiteral (+ 1 value))]
//     [node node]))
Component transformComponentBang(Component component, Statement Function(Statement) transformStatement, Expression Function(Expression) transformExpression) {
  KernelBottomupFolder<Node> folder =
      new KernelBottomupFolder(new CaseSplitter(transformStatement, transformExpression), (a, b) => null, null);
  return folder.visitComponent(component);
}


// Expression transformLiteral(Expression node) {
//   iterate(6, (i) => print(i.toString()), null);
//   return node;
// }

// main() {
//   VariableDeclaration x =
//       new VariableDeclaration("x", type: const DynamicType());
//   Procedure foo = new Procedure(
//       new Name("foo"),
//       ProcedureKind.Method,
//       new FunctionNode(
//           new ReturnStatement(new MethodInvocation(new VariableGet(x),
//               new Name("+"), new Arguments([new IntLiteral(0)]))),
//           positionalParameters: [x]),
//       isStatic: true);
//   Procedure entryPoint = new Procedure(
//       new Name("main"),
//       ProcedureKind.Method,
//       new FunctionNode(new Block([
//         new ExpressionStatement(
//             new StaticInvocation(foo, new Arguments([new IntLiteral(1)])))
//       ])),
//       isStatic: true);
//   Library library = new Library(new Uri(scheme: "file", path: "foo.dart"),
//       procedures: [foo, entryPoint]);
//   Component component = new Component(libraries: [library])
//     ..mainMethod = entryPoint;

//   print("// Before:");
//   print(componentToString(component));
//   print("");

//   Component transformed = transformComponentBang(component, (x) => x, transformLiteral);

//   print("// After:");
//   print(componentToString(transformed));
// }
