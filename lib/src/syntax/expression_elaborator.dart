// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast_common.dart';
import '../ast/ast_types.dart';
import '../ast/ast_expressions.dart';
import '../errors/errors.dart';
import '../location.dart';
import '../unicode.dart' as unicode;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;
import 'syntax_elaborator.dart';

class SpecialForms {
  static const String ifthenelse = "if";
  static const String lambda = "lambda";
  static const String let = "let";
  static const String letstar = "let*";
  static const String match = "match";
  static const String tuple = ",";
  static Set<String> forms = Set.of(<String>[
    SpecialForms.lambda,
    SpecialForms.let,
    SpecialForms.letstar,
    SpecialForms.ifthenelse,
    SpecialForms.match,
    SpecialForms.tuple
  ]);

  bool isSpecialForm(String name) {
    return SpecialForms.forms.contains(name);
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
          return null;
        case SpecialForm.lambda:
          return null;
        case SpecialForm.let:
          return null;
        case SpecialForm.letstar:
          return null;
        case SpecialForm.match:
          return null;
        case SpecialForm.tuple:
          return null;
        default:
          // Application.
          return null.
      }
    }

    // Otherwise it is an application.
    return null;
  }

  Expression error(Error error) {
    return null;
  }
}
