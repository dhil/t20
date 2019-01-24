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

import './prototype.dart' show Obvious, PatternMatchFailure, T20Error;

import './kernel_match_closure.dart' show KernelMatchClosure;

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
