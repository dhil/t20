// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show unhandled;
import '../utils.dart' show ListUtils;

import 'ast.dart';

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

  void lparen() => buffer.write("(");
  void rparen() => buffer.write(")");
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
    }
    rparen();
  }

  void visitDatatypes(DatatypeDeclarations decls) {
    lparen();
    write("define-datatypes");
    space();
    for (int i = 0; i < decls.declarations.length; i++) {
      decls.declarations[i].accept<void>(this);
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
      write("[");
      b.pattern.accept<void>(pattern);
      space();
      b.expression.accept<void>(this);
      write("]");
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
        write("[");
        case0.pattern.accept<void>(pattern);
        space();
        case0.expression.accept<void>(this);
        write("]");
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
