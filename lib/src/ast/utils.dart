// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show unhandled;
import '../utils.dart' show ListUtils;

import 'ast.dart';
import 'monoids.dart';

String stringOfNode(T20Node node) {
  if (node is ModuleMember) {
    StringifyModule v = StringifyModule();
    node.accept<void>(v);
    return v.toString();
  } else if (node is Expression) {
    StringifyExpression v = StringifyExpression();
    node.accept<void>(v);
    return v.toString();
  } else if (node is Pattern) {
    StringifyPattern v = StringifyPattern();
    node.accept<void>(v);
    return v.toString();
  } else if (node is Binding) {
    throw "Not yet implemented.";
  } else if (node is Case) {
    throw "Not yet implemented.";
  } else if (node is FormalParameter) {
    throw "Not yet implemented.";
  } else {
    unhandled("stringOfNode", node);
  }

  return null; // Impossible!
}

String stringOfBinder(Binder binder) => binder.toString();

abstract class BufferedWriter {
  final StringBuffer buffer;

  BufferedWriter([StringBuffer buffer])
      : this.buffer = buffer == null ? StringBuffer() : buffer;

  void lparen() => write("(");
  void rparen() => write(")");
  void lsquare() => write("[");
  void rsquare() => write("]");
  void write(String contents) => buffer.write(contents);
  void space() => buffer.write(" ");

  String toString() => buffer.toString();
}

class StringifyModule extends BufferedWriter implements ModuleVisitor<void> {
  StringifyModule([StringBuffer buffer]) : super(buffer);

  void visitDataConstructor(DataConstructor constr) {
    lparen();
    write(stringOfBinder(constr.binder));
    space();
    write(ListUtils.stringify(" ", constr.parameters));
    rparen();
  }

  void visitDatatype(DatatypeDescriptor decl) {
    lparen();
    write("define-datatype");
    space();
    if (decl.parameters.length == 0) {
      write(stringOfBinder(decl.binder));
    } else {
      lparen();
      write(stringOfBinder(decl.binder));
      space();
      write(ListUtils.stringify(" ", decl.parameters));
      rparen();
    }
    space();
    for (int i = 0; i < decl.constructors.length; i++) {
      decl.constructors[i].accept<void>(this);
      if (i + 1 < decl.constructors.length) space();
    }
    rparen();
  }

  void visitDatatypes(DatatypeDeclarations decls) {
    lparen();
    write("define-datatypes");
    space();
    for (int i = 0; i < decls.declarations.length; i++) {
      decls.declarations[i].accept<void>(this);
      if (i + 1 < decls.declarations.length) space();
    }
    rparen();
  }

  void visitError(ErrorModule err) {
    lparen();
    write("@error ${err.error}");
    rparen();
  }

  void visitFunction(FunctionDeclaration decl) {
    lparen();
    if (decl.isVirtual) {
      write("define-stub");
    } else {
      write("define");
    }
    space();
    lparen();
    write(stringOfBinder(decl.binder));
    if (decl.parameters.length > 0) {
      space();
      StringifyPattern pattern = StringifyPattern(buffer);
      for (int i = 0; i < decl.parameters.length; i++) {
        decl.parameters[i].accept<void>(pattern);
        if (i + 1 < decl.parameters.length) space();
      }
    }
    rparen();

    if (!decl.isVirtual) {
      decl.body.accept<void>(StringifyExpression(buffer));
    }
    rparen();
  }

  void visitLetFunction(LetFunction fun) {
    return null;
  }

  void visitInclude(Include include) {
    lparen();
    write("open");
    space();
    write(include.module);
    rparen();
  }

  void visitSignature(Signature sig) {
    return null;
  }

  void visitTopModule(TopModule mod) {
    return null;
  }

  void visitTypename(TypeAliasDescriptor decl) {
    return null;
  }

  void visitValue(ValueDeclaration decl) {
    return null;
  }
}

class StringifyExpression extends BufferedWriter
    implements ExpressionVisitor<void> {
  StringifyExpression([StringBuffer buffer]) : super(buffer);

  // Literals.
  void visitBool(BoolLit boolean) {
    if (boolean.value) {
      write("#t");
    } else {
      write("#f");
    }
  }

  void visitInt(IntLit integer) => write(integer.value.toString());
  void visitString(StringLit string) {
    write('"');
    write(string.value);
    write('"');
  }

  // Expressions.
  void visitApply(Apply apply) {
    lparen();
    apply.abstractor.accept<void>(this);
    if (apply.arguments.length > 0) {
      space();
      for (int i = 0; i < apply.arguments.length; i++) {
        apply.arguments[i].accept<void>(this);
        if (i + 1 < apply.arguments.length) space();
      }
    }
    rparen();
  }

  void visitIf(If ifthenelse) {
    lparen();
    write("if");
    space();
    ifthenelse.condition.accept<void>(this);
    space();
    ifthenelse.thenBranch.accept<void>(this);
    space();
    ifthenelse.elseBranch.accept<void>(this);
    rparen();
  }

  void visitLambda(Lambda lambda) {
    lparen();
    write("lambda");
    space();

    lparen();
    if (lambda.parameters.length > 0) {
      StringifyPattern pattern = StringifyPattern(buffer);
      for (int i = 0; i < lambda.parameters.length; i++) {
        lambda.parameters[i].accept<void>(pattern);
        if (i + 1 < lambda.parameters.length) space();
      }
    }
    rparen();

    lambda.body.accept<void>(this);
    rparen();
  }

  void visitLet(Let binding) {
    lparen();
    write("let");
    space();
    lparen();
    StringifyPattern pattern = StringifyPattern(buffer);
    for (int i = 0; i < binding.valueBindings.length; i++) {
      Binding b = binding.valueBindings[i];
      lsquare();
      b.pattern.accept<void>(pattern);
      space();
      b.expression.accept<void>(this);
      rsquare();
      if (i + 1 < binding.valueBindings.length) space();
    }
    rparen();
    binding.body.accept<void>(this);
    rparen();
  }

  void visitMatch(Match match) {
    lparen();
    write("match");
    space();
    match.scrutinee.accept<void>(this);
    if (match.cases.length > 0) {
      space();
      StringifyPattern pattern = StringifyPattern(buffer);
      for (int i = 0; i < match.cases.length; i++) {
        Case case0 = match.cases[i];
        lsquare();
        case0.pattern.accept<void>(pattern);
        space();
        case0.expression.accept<void>(this);
        rsquare();
        if (i + 1 < match.cases.length) space();
      }
    }
    rparen();
  }

  void visitTuple(Tuple tuple) {
    lparen();
    write(",");
    if (tuple.components.length > 0) {
      space();
      for (int i = 0; i < tuple.components.length; i++) {
        tuple.components[i].accept<void>(this);
        if (i + 1 < tuple.components.length) space();
      }
    }
    rparen();
  }

  void visitVariable(Variable v) => write(stringOfBinder(v.binder));
  void visitTypeAscription(TypeAscription ascription) {
    lparen();
    write(":");
    space();
    ascription.exp.accept<void>(this);
    space();
    write(ascription.type.toString());
    rparen();
  }

  void visitError(ErrorExpression e) {
    lparen();
    write("@error ${e.error}");
    rparen();
  }

  // Desugared nodes.
  void visitDLambda(DLambda lambda) {
    lparen();
    write("dlambda");
    space();

    lparen();
    if (lambda.parameters.length > 0) {
      for (int i = 0; i < lambda.parameters.length; i++) {
        FormalParameter parameter = lambda.parameters[i];
        write(stringOfBinder(parameter.binder));
        if (i + 1 < lambda.parameters.length) space();
      }
    }
    rparen();

    lambda.body.accept<void>(this);
    rparen();
  }

  void visitDLet(DLet let) {
    lparen();
    write("let");
    space();
    write(stringOfBinder(let.binder));
    space();
    let.body.accept<void>(this);
    space();
    let.continuation.accept<void>(this);
    rparen();
  }

  void visitProject(Project project) {
    lparen();
    write("\$${project.label}");
    space();
    project.receiver.accept<void>(this);
    rparen();
  }

  void visitMatchClosure(MatchClosure clo) {
    lparen();
    write("match-closure");
    space();
    lparen();
    for (int i = 0; i < clo.context.length; i++) {
      write(stringOfBinder(clo.context[i]));
      if (i + 1 < clo.context.length) space();
    }
    rparen();
    space();
    clo.scrutinee.accept<void>(this);
    space();
    lparen();
    StringifyModule module = StringifyModule(buffer);
    for (int i = 0; i < clo.cases.length; i++) {
      clo.cases[i].accept<void>(module);
      if (i + 1 < clo.cases.length) space();
    }
    rparen();
    rparen();
  }
}

class StringifyPattern extends BufferedWriter implements PatternVisitor<void> {
  StringifyPattern([StringBuffer buffer]) : super(buffer);

  void visitBool(BoolPattern b) => write(b.value ? "#t" : "#f");

  void visitConstructor(ConstructorPattern constr) {
    lparen();
    write(stringOfBinder(constr.declarator.binder));
    if (constr.arity > 0) {
      space();
      for (int i = 0; i < constr.components.length; i++) {
        constr.components[i].accept<void>(this);
      }
    }
    rparen();
  }

  void visitError(ErrorPattern e) {
    lparen();
    write("@error ${e.error}");
    rparen();
  }

  void visitHasType(HasTypePattern t) {
    lparen();
    t.pattern.accept<void>(this);
    space();
    write(":");
    space();
    write(t.type.toString());
    rparen();
  }

  void visitInt(IntPattern i) => write(i.value.toString());
  void visitString(StringPattern s) {
    write('"');
    write(s.value);
    write('"');
  }

  void visitTuple(TuplePattern t) {
    lparen();
    write(",");
    if (t.components.length > 0) {
      space();
      for (int i = 0; i < t.components.length; i++) {
        t.components[i].accept<void>(this);
      }
    }
    rparen();
  }

  void visitVariable(VariablePattern v) => write(stringOfBinder(v.binder));
  void visitWildcard(WildcardPattern w) => write("_");
}

// Reductions.

class ReduceModule<T> extends ModuleVisitor<T> {
  Monoid<T> get m => null;

  T visitDataConstructor(DataConstructor _) => m.empty;
  T visitDatatype(DatatypeDescriptor _) => m.empty;
  T visitDatatypes(DatatypeDeclarations _) => m.empty;
  T visitError(ErrorModule err) => m.empty;

  T visitFunction(FunctionDeclaration decl) {
    T acc = m.empty;

    if (decl.parameters != null) {
      ReducePattern<T> pattern;
      for (int i = 0; i < decl.parameters.length; i++) {
        acc = m.compose(acc, decl.parameters[i].accept<T>(pattern));
      }
    }

    if (!decl.isVirtual) {
      ReduceExpression<T> expression;
      acc = m.compose(acc, decl.body.accept<T>(expression));
      return acc;
    } else {
      return acc;
    }
  }

  T visitLetFunction(LetFunction fun) {
    if (!fun.isVirtual) {
      ReduceExpression<T> expression;
      return fun.body.accept<T>(expression);
    } else {
      return m.empty;
    }
  }

  T visitInclude(Include _) => m.empty;

  T visitSignature(Signature _) => m.empty;

  T visitTopModule(TopModule mod) {
    T acc = m.empty;
    for (int i = 0; i < mod.members.length; i++) {
      T result = mod.accept<T>(this);
      acc = m.compose(acc, result);
    }
    return acc;
  }

  T visitTypename(TypeAliasDescriptor decl) => m.empty;

  T visitValue(ValueDeclaration decl) =>
      decl.body.accept<T>(ReduceExpression<T>());
}

class ReduceExpression<T> extends ExpressionVisitor<T> {
  Monoid<T> get m => null;

  T many(List<Expression> exps) {
    T acc = m.empty;
    for (int i = 0; i < exps.length; i++) {
      acc = m.compose(acc, exps[i].accept<T>(this));
    }
    return acc;
  }

  // Literals.
  T visitBool(BoolLit boolean) => m.empty;
  T visitInt(IntLit integer) => m.empty;
  T visitString(StringLit string) => m.empty;

  // Expressions.
  T visitApply(Apply apply) {
    T result = apply.abstractor.accept<T>(this);
    return m.compose(result, many(apply.arguments));
  }

  T visitIf(If ifthenelse) => m.compose(
      m.compose(ifthenelse.condition.accept<T>(this),
          ifthenelse.thenBranch.accept<T>(this)),
      ifthenelse.elseBranch.accept<T>(this));

  T visitLambda(Lambda lambda) {
    T acc = m.empty;
    ReducePattern<T> pattern = ReducePattern<T>();
    for (int i = 0; i < lambda.parameters.length; i++) {
      acc = m.compose(acc, lambda.parameters[i].accept<T>(pattern));
    }

    return m.compose(acc, lambda.body.accept<T>(this));
  }

  T visitLet(Let binding) {
    T acc = m.empty;
    ReducePattern<T> pattern = ReducePattern<T>();
    for (int i = 0; i < binding.valueBindings.length; i++) {
      Binding b = binding.valueBindings[i];
      acc = m.compose(acc, b.pattern.accept<T>(pattern));
      acc = m.compose(acc, b.expression.accept<T>(this));
    }
    return m.compose(acc, binding.body.accept<T>(this));
  }

  T visitMatch(Match match) {
    T acc = match.scrutinee.accept<T>(this);
    ReducePattern<T> pattern = ReducePattern<T>();
    for (int i = 0; i < match.cases.length; i++) {
      Case case0 = match.cases[i];
      acc = m.compose(acc, case0.pattern.accept<T>(pattern));
      acc = m.compose(acc, case0.expression.accept<T>(this));
    }
    return acc;
  }

  T visitTuple(Tuple tuple) => many(tuple.components);

  T visitVariable(Variable v) => m.empty;
  T visitTypeAscription(TypeAscription ascription) =>
      ascription.exp.accept<T>(this);

  T visitError(ErrorExpression e) => m.empty;

  // Desugared nodes.
  T visitDLambda(DLambda lambda) => lambda.body.accept<T>(this);

  T visitDLet(DLet let) {
    T result = let.body.accept<T>(this);
    return m.compose(result, let.continuation.accept<T>(this));
  }

  T visitProject(Project project) => project.receiver.accept<T>(this);

  T visitMatchClosure(MatchClosure clo) => throw "Not yet implemented.";
}

class ReducePattern<T> extends PatternVisitor<T> {
  Monoid<T> get m => null;

  T many(List<Pattern> patterns) {
    T acc = m.empty;
    for (int i = 0; i < patterns.length; i++) {
      acc = m.compose(acc, patterns[i].accept<T>(this));
    }
    return acc;
  }

  T visitBool(BoolPattern _) => m.empty;
  T visitInt(IntPattern _) => m.empty;
  T visitString(StringPattern _) => m.empty;

  T visitConstructor(ConstructorPattern constr) => many(constr.components);

  T visitError(ErrorPattern _) => m.empty;

  T visitHasType(HasTypePattern t) => t.pattern.accept<T>(this);

  T visitTuple(TuplePattern t) => many(t.components);

  T visitVariable(VariablePattern _) => m.empty;
  T visitWildcard(WildcardPattern _) => m.empty;
}