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

import './visitor1.dart' show Visitor1;

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
    return visit(node, (R result) {
      return function.visitRedirectingFactoryConstructorReference(node, result);
    });
  }

  @override
  R visitProcedureReference(Procedure node) {
    return null;
//    return visit(node, (R result) {
//      return function.visitProcedureReference(node, result);
//    });
  }

  @override
  R visitConstructorReference(Constructor node) {
    return visit(node, (R result) {
      return function.visitConstructorReference(node, result);
    });
  }

  @override
  R visitFieldReference(Field node) {
    return visit(node, (R result) {
      return function.visitFieldReference(node, result);
    });
  }

  @override
  R defaultMemberReference(Member node) {
    throw new UnsupportedError("defaultMemberReference");
  }

  @override
  R visitUnevaluatedConstantReference(UnevaluatedConstant node) {
    return visit(node, (R result) {
      return function.visitUnevaluatedConstantReference(node, result);
    });
  }

  @override
  R visitTypeLiteralConstantReference(TypeLiteralConstant node) {
    return visit(node, (R result) {
      return function.visitTypeLiteralConstantReference(node, result);
    });
  }

  @override
  R visitTearOffConstantReference(TearOffConstant node) {
    return visit(node, (R result) {
      return function.visitTearOffConstantReference(node, result);
    });
  }

  @override
  R visitPartialInstantiationConstantReference(
      PartialInstantiationConstant node) {
    return visit(node, (R result) {
      return function.visitPartialInstantiationConstantReference(node, result);
    });
  }

  @override
  R visitInstanceConstantReference(InstanceConstant node) {
    return visit(node, (R result) {
      return function.visitInstanceConstantReference(node, result);
    });
  }

  @override
  R visitListConstantReference(ListConstant node) {
    return visit(node, (R result) {
      return function.visitListConstantReference(node, result);
    });
  }

  @override
  R visitMapConstantReference(MapConstant node) {
    return visit(node, (R result) {
      return function.visitMapConstantReference(node, result);
    });
  }

  @override
  R visitSymbolConstantReference(SymbolConstant node) {
    return visit(node, (R result) {
      return function.visitSymbolConstantReference(node, result);
    });
  }

  @override
  R visitStringConstantReference(StringConstant node) {
    return visit(node, (R result) {
      return function.visitStringConstantReference(node, result);
    });
  }

  @override
  R visitDoubleConstantReference(DoubleConstant node) {
    return visit(node, (R result) {
      return function.visitDoubleConstantReference(node, result);
    });
  }

  @override
  R visitIntConstantReference(IntConstant node) {
    return visit(node, (R result) {
      return function.visitIntConstantReference(node, result);
    });
  }

  @override
  R visitBoolConstantReference(BoolConstant node) {
    return visit(node, (R result) {
      return function.visitBoolConstantReference(node, result);
    });
  }

  @override
  R visitNullConstantReference(NullConstant node) {
    return visit(node, (R result) {
      return function.visitNullConstantReference(node, result);
    });
  }

  @override
  R defaultConstantReference(Constant node) {
    throw new UnsupportedError("defaultConstantReference");
  }

  @override
  R visitTypedefReference(Typedef node) {
    return visit(node, (R result) {
      return function.visitTypedefReference(node, result);
    });
  }

  @override
  R visitClassReference(Class node) {
    return visit(node, (R result) {
      return function.visitClassReference(node, result);
    });
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
