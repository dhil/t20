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

import 'package:kernel/visitor.dart'
    show ExpressionVisitor1, StatementVisitor1, DartTypeVisitor1;

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
