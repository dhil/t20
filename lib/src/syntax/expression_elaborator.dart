// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../fp.dart' show Pair;
import '../location.dart';
import '../result.dart' show Result;
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
  static const String typeAscription = ":";
  static Set<String> forms = Set.of(<String>[
    SpecialForm.lambda,
    SpecialForm.let,
    SpecialForm.letstar,
    SpecialForm.ifthenelse,
    SpecialForm.match,
    SpecialForm.tuple,
    SpecialForm.typeAscription
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

  Expression visitAtom(Atom atom) {
    assert(atom != null);
    String value = atom.value;
    Location location = atom.location;

    // Might be an integer.
    if (isValidNumber(value)) {
      int denotation = int.parse(value);
      return IntLit(denotation, location);
    }

    // Might be a boolean.
    if (isValidBoolean(value)) {
      return BoolLit(denoteBool(value), location);
    }

    // Otherwise it is a variable.
    Name name = expect(identifier, atom);
    return Variable(name, location);
  }

  Expression visitList(SList list) {
    assert(list != null);

    if (list.length == 0) {
      badSyntax(
          list.location, const <String>["a special form", "an application"]);
      return errorExpression(list.location);
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
          return let(atom, list);
        case SpecialForm.match:
          return match(atom, list);
        case SpecialForm.tuple:
          return tuple(atom, list);
        case SpecialForm.typeAscription:
          return typeAscription(atom, list);
        default:
          // Application.
          return application(list);
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
    assert(head.value == SpecialForm.ifthenelse);
    // An if expression consists of exactly 3 constituents.
    if (list.length < 4) {
      badSyntax(list.location.end,
          const <String>["a then-clause and an else-clause"]);
      return errorExpression(list.location);
    }

    Expression condition = expect<Sexp, Expression>(expression, list[1]);
    Expression thenBranch = expect<Sexp, Expression>(expression, list[2]);
    Expression elseBranch = expect<Sexp, Expression>(expression, list[3]);

    return If(condition, thenBranch, elseBranch, list.location);
  }

  Expression tuple(Atom head, SList list) {
    assert(head.value == SpecialForm.tuple);

    List<Expression> components = expectMany(expression, list, 1);
    return Tuple(components, list.location);
  }

  Expression lambda(Atom head, SList list) {
    assert(head.value == SpecialForm.lambda);

    List<Pattern> parameters = expectMany<Sexp, Pattern>(pattern, list[1], 0);
    List<Expression> expressions =
        expectManyOne<Sexp, Expression>(expression, list, 2);
    return Lambda(parameters, expressions, list.location);
  }

  Expression let(Atom head, SList list) {
    assert(head.value == SpecialForm.let || head.value == SpecialForm.letstar);

    // The bindings in a let expression can either be bound in parallel or sequentially.
    LetKind bindingKind;
    switch (head.value) {
      case SpecialForm.let:
        bindingKind = LetKind.Parallel;
        break;
      case SpecialForm.letstar:
        bindingKind = LetKind.Sequential;
        break;
      default:
        assert(false);
    }

    if (list.length < 3) {
      badSyntax(list.location.end, const <String>[
        "a non-empty sequence of bindings followed by a non-empty sequence of expressions"
      ]);
      return errorExpression(list.location);
    }

    List<Pair<Pattern, Expression>> bindingPairs =
        expect(valueBindings, list[1]);
    List<Expression> expressions = expectManyOne(expression, list, 2);
    return Let(bindingKind, bindingPairs, expressions, list.location);
  }

  Expression match(Atom head, SList list) {
    assert(head.value == SpecialForm.match);

    if (list.length < 2) {
      badSyntax(list.location.end, const <String>[
        "an expression followed by a sequence of match clauses"
      ]);
      return errorExpression(list.location);
    }

    Expression scrutinee = expect(expression, list[1]);
    List<Pair<Pattern, List<Expression>>> clauses = expectMany(clause, list, 2);
    return Match(scrutinee, clauses, list.location);
  }

  Expression typeAscription(Atom head, SList list) {
    assert(head.value == SpecialForm.typeAscription);
    Expression exp = expect(expression, list, position:1);
    Datatype type = expect(signatureDatatype, list, position:2);
    return TypeAscription(exp, type, list.location);
  }

  Result<List<Pair<Pattern, Expression>>, LocatedError> valueBindings(
      Sexp sexp) {
    if (sexp is SList) {
      SList list = sexp;
      List<Pair<Pattern, Expression>> pairs =
          expectManyOne(patternFollowedByExpression, list, 0);
      return Result.success(pairs);
    } else {
      LocatedError err = BadSyntaxError(
          sexp.location, const <String>["a pattern followed by an expression"]);
      return Result.failure(<LocatedError>[err]);
    }
  }

  Result<Pair<Pattern, Expression>, LocatedError> patternFollowedByExpression(
      Sexp sexp) {
    if (sexp is SList) {
      SList list = sexp;
      if (list.length < 2 || list.length > 2) {
        LocatedError err = BadSyntaxError(sexp.location,
            const <String>["a pattern followed by a single expression"]);
        return Result.failure(<LocatedError>[err]);
      }

      Pattern binder = expect(pattern, list[0]);
      Expression expr = expect(expression, list[1]);
      return Result.success(Pair<Pattern, Expression>(binder, expr));
    } else {
      LocatedError err = BadSyntaxError(sexp.location,
          const <String>["a pattern followed by a single expression"]);
      return Result.failure(<LocatedError>[err]);
    }
  }

  Result<Pair<Pattern, List<Expression>>, LocatedError> clause(Sexp sexp) {
    if (sexp is SList && (sexp as SList).length >= 2) {
      SList list = sexp;
      Pattern pat = expect(pattern, list[0]);
      List<Expression> exps = expectManyOne(expression, list, 1);
      return Result.success(Pair<Pattern, List<Expression>>(pat, exps));
    } else {
      LocatedError err = BadSyntaxError(sexp.location, const <String>[
        "a pattern followed by a non-empty sequence of expressions"
      ]);
      return Result.failure(<LocatedError>[err]);
    }
  }

  Expression errorExpression(Location location) {
    // Unit expression. TODO: introduce a proper error expression.
    return Tuple(const <Expression>[], location);
  }
}
