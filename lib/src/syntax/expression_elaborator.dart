// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../location.dart';
import '../unicode.dart' as unicode;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;
import 'syntax_elaborator.dart';

class SpecialForm {
  static const String ifthenelse = "if";
  static const String lambda = "lambda";
  static const String let = "let";
  static const String letstar = "let*";
  static const String match = "match";
  static const String tuple = ",";
  static Set<String> forms = Set.of(<String>[
    SpecialForm.lambda,
    SpecialForm.let,
    SpecialForm.letstar,
    SpecialForm.ifthenelse,
    SpecialForm.match,
    SpecialForm.tuple
  ]);

  bool isSpecialForm(String name) {
    return SpecialForm.forms.contains(name);
  }
}

class ExpressionElaborator extends BaseElaborator<Expression> {
  ExpressionElaborator() : super("ExpressionElaborator");

  StringLit visitString(StringLiteral string) {
    // TODO parse string literal.
    return StringLit(string.value, string.location);
  }

  Expression atom(Atom atom) {
    assert(atom != null);
    String value = atom.value;
    Location location = atom.location;

    // Might be an integer.
    if (isValidNumber(value)) {
      int denotation = int.parse(value);
      return IntLit(denotation, location);
    }

    // Otherwise it is a variable.
    Name name = expect(identifier, atom);
    return Variable(name, location);
  }

  Expression list(SList list) {
    assert(list != null);

    if (list.length == 0) {
      badSyntax(
          list.location, const <String>["a special form", "an application"]);
    }

    // Might be a special form.
    if (list[0] is Atom) {
      Atom atom = list[0];
      switch (atom.value) {
        case SpecialForm.ifthenelse:
          return ifthenelse(atom, list);
        case SpecialForm.lambda:
          return lambda(atom, list);
        case SpecialForm.let:
        case SpecialForm.letstar:
          return null;
        case SpecialForm.match:
          return null;
        case SpecialForm.tuple:
          return tuple(atom, list);
        default:
          // Application.
          return null;
      }
    }

    // Otherwise it is an application.
    return application(list);
  }

  Expression application(SList list) {
    assert(list != null);
    Expression abstractor = expect(expression, list[0]);
    List<Expression> arguments = expectMany(expression, list, 1);
    return Apply(abstractor, arguments, list.location);
  }

  Expression ifthenelse(Atom head, SList list) {
    assert(head == SpecialForm.ifthenelse);
    // An if expression consists of exactly 3 constituents.
    if (list.length < 4) {
      badSyntax(list.location.end,
          const <String>["a then-clause and an else-clause"]);
    }

    Expression condition  = expect<Sexp, Expression>(expression, list[1]);
    Expression thenBranch = expect<Sexp, Expression>(expression, list[2]);
    Expression elseBranch = expect<Sexp, Expression>(expression, list[3]);

    return If(condition, thenBranch, elseBranch, list.location);
  }

  Expression tuple(Atom head, SList list) {
    assert(head == SpecialForm.tuple);

    List<Expression> components = expectMany(expression, list, 1);
    return Tuple(components, list.location);
  }

  Expression lambda(Atom head, SList list) {
    assert(head == SpecialForm.lambda);

    List<Pattern> parameters     = expectMany<Sexp, Pattern>(pattern, list[1], 0);
    List<Expression> expressions = expectManyOne<Sexp, Expression>(expression, list, 2);
    return Lambda(parameters, expressions, list.location);
  }
}
