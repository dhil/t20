// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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

import 'package:kernel/visitor.dart' show Visitor;

import './prototype.dart' show PatternMatchFailure;

class KernelMatchClosure<R> implements Visitor<R> {
  final int id;

  const KernelMatchClosure(this.id);

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
