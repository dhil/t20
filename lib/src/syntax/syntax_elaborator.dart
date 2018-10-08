// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show Set;

import '../ast/ast_common.dart' show Name;
import '../ast/ast.dart';
import '../errors/errors.dart'
    show BadSyntaxError, LocatedError, UnsupportedTypeElaborationMethodError;
import '../location.dart';
import '../result.dart';
import '../unicode.dart' as unicode;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;

import 'type_elaborator.dart';

abstract class SyntaxElaborator<T> implements SexpVisitor<T> {
  List<LocatedError> get errors;
}

typedef Elab<S extends Sexp, T> = Result<T, LocatedError> Function(S);

abstract class BaseElaborator<T> implements SyntaxElaborator<T> {
  final String elaboratorName;
  List<LocatedError> _errors;

  List<LocatedError> get errors => _errors;

  BaseElaborator(this.elaboratorName);

  T visitAtom(Atom _) {
    assert(false);
    throw UnsupportedTypeElaborationMethodError(elaboratorName, "visitAtom");
  }

  T visitError(Error _) {
    assert(false);
    throw UnsupportedTypeElaborationMethodError(elaboratorName, "visitError");
  }

  T visitList(SList _) {
    assert(false);
    throw UnsupportedTypeElaborationMethodError(elaboratorName, "visitList");
  }

  T visitString(StringLiteral _) {
    assert(false);
    throw UnsupportedTypeElaborationMethodError(elaboratorName, "visitString");
  }

  T visitToplevel(Toplevel _) {
    assert(false);
    throw UnsupportedTypeElaborationMethodError(elaboratorName, "visitModule");
  }

  void error(LocatedError error) {
    _errors ??= new List<LocatedError>();
    _errors.add(error);
  }

  void manyErrors(List<LocatedError> errors) {
    if (errors == null) return;
    if (_errors == null) {
      _errors = errors;
    } else {
      _errors.addAll(errors);
    }
  }

  // Elaboration API.
  LocatedError badSyntax(Location location, [List<String> expectations = null]) {
    LocatedError err = BadSyntaxError(location, expectations);
    error(err);
    return err;
  }

  T expect<S extends Sexp, T>(Elab<S, T> elab, S sexp,
      {int position = -1, T Function(Location) makeErrorNode = null}) {
    assert(elab != null && sexp != null);
    Result<T, LocatedError> result;
    if (sexp is SList) {
      SList list = sexp;
      if (position < 0) {
        result = elab(sexp);
      } else if (position < list.length) {
        result = elab(list[position]);
      } else {
        return makeErrorNode != null ? makeErrorNode(sexp.location) : null;
      }
    } else {
      result = elab(sexp);
    }

    if (result.wasSuccessful) {
      return result.result;
    } else {
      manyErrors(result.errors);
      return makeErrorNode != null ? makeErrorNode(sexp.location) : null;
    }
  }

  List<T> expectMany<S extends Sexp, T>(Elab<S, T> elab, SList list, int start,
      {int end = -1, T Function(Location) makeErrorNode = null}) {
    assert(elab != null && list != null && start >= 0 && end <= list.length);
    List<T> results = new List<T>();
    if (end < 0) end = list.length;

    for (int i = start; i < end; i++) {
      results.add(expect<Sexp, T>(elab, list,
          position: i, makeErrorNode: makeErrorNode));
    }

    return results;
  }

  List<T> expectManyOne<S extends Sexp, T>(
      Elab<S, T> elab, SList list, int start,
      {int end = -1, T Function(Location) makeErrorNode = null}) {
    assert(elab != null && list != null && start >= 0);
    List<T> results =
        expectMany(elab, list, start, end: end, makeErrorNode: makeErrorNode);
    if (results.length > 0) {
      return results;
    } else {
      badSyntax(list.location);
      return <T>[];
    }
  }

  final Set<int> allowedIdentSymbols = Set.of(const <int>[
    unicode.AT,
    unicode.LOW_LINE,
    unicode.HYPHEN_MINUS,
    unicode.PLUS_SIGN,
    unicode.ASTERISK,
    unicode.SLASH,
    unicode.DOLLAR_SIGN,
    unicode.BANG,
    unicode.QUESTION_MARK,
    unicode.EQUALS_SIGN,
    unicode.LESS_THAN_SIGN,
    unicode.GREATER_THAN_SIGN,
    unicode.COLON
  ]);

  bool isValidNumber(String text) {
    assert(text != null);
    // TODO: Support hexadecimal digits.
    return isValidInteger(text);
  }

  bool isValidInteger(String text) {
    assert(text != null);
    if (text.length == 0) return false;

    for (int i = 0; i < text.length; i++) {
      int c = text.codeUnitAt(i);
      if (!unicode.isDigit(c)) return false;
    }
    return true;
  }

  bool isValidIdentifier(String name) {
    assert(name != null);
    if (name.length == 0) return false;

    // An identifier is not allowed to start with an underscore (_) or colon (:).
    int c = name.codeUnitAt(0);
    if (!unicode.isAsciiLetter(c) &&
        !(allowedIdentSymbols.contains(c) &&
            c != unicode.LOW_LINE &&
            c != unicode.COLON)) {
      return false;
    }

    for (int i = 1; i < name.length; i++) {
      c = name.codeUnitAt(i);
      if (!unicode.isAsciiLetter(c) &&
          !unicode.isDigit(c) &&
          !allowedIdentSymbols.contains(c)) {
        return false;
      }
    }
    return true;
  }

  bool isValidTypeVariableName(String name) {
    assert(name != null);

    if (name.length < 2) return false;
    int c = name.codeUnitAt(0);
    int k = name.codeUnitAt(1);
    if (c != unicode.APOSTROPHE) return false;
    if (!unicode.isAsciiLetter(k)) return false;

    for (int i = 1; i < name.length; i++) {
      c = name.codeUnitAt(i);
      if (!unicode.isAsciiLetter(c) && !unicode.isDigit(c)) return false;
    }

    return true;
  }

  bool isValidDataConstructorName(String name) {
    assert(name != null);
    return isValidIdentifier(name);
  }

  bool isValidTypeConstructorName(String name) {
    assert(name != null);
    if (name.length == 0) return false;
    int c = name.codeUnitAt(0);
    if (!unicode.isAsciiUpper(c)) return false;

    for (int i = 1; i < name.length; i++) {
      c = name.codeUnitAt(i);
      if (!unicode.isAsciiLetter(c)) return false;
    }
    return true;
  }

  Result<Name, LocatedError> identifier(Sexp sexp) {
    assert(sexp != null);

    if (sexp is Atom) {
      Atom atom = sexp;
      if (isValidIdentifier(atom.value)) {
        return Result.success(Name(atom.value, atom.location));
      } else {
        LocatedError err =
            BadSyntaxError(atom.location, const <String>["identifier"]);
        return Result.failure(<LocatedError>[err]);
      }
    } else {
      LocatedError err =
          BadSyntaxError(sexp.location, const <String>["identifier"]);
      return Result.failure(<LocatedError>[err]);
    }
  }

  Result<Name, LocatedError> typeVariable(Sexp sexp) {
    assert(sexp != null);

    if (sexp is Atom) {
      Atom atom = sexp;
      if (isValidTypeVariableName(atom.value)) {
        return Result.success(Name(atom.value, atom.location));
      } else {
        LocatedError err =
            BadSyntaxError(atom.location, const <String>["type variable"]);
        return Result.failure(<LocatedError>[err]);
      }
    } else {
      LocatedError err =
          BadSyntaxError(sexp.location, const <String>["type variable"]);
      return Result.failure(<LocatedError>[err]);
    }
  }

  Result<Name, LocatedError> typeConstructorName(Sexp sexp) {
    assert(sexp != null);

    if (sexp is Atom) {
      Atom atom = sexp;
      if (isValidTypeConstructorName(atom.value)) {
        return Result.success(Name(atom.value, atom.location));
      } else {
        LocatedError err =
            BadSyntaxError(atom.location, const <String>["type constructor"]);
        return Result.failure(<LocatedError>[err]);
      }
    } else {
      LocatedError err =
          BadSyntaxError(sexp.location, const <String>["type constructor"]);
      return Result.failure(<LocatedError>[err]);
    }
  }

  Result<TypeParameter, LocatedError> quantifier(Sexp sexp) {
    assert(sexp != null);

    Name name = expect(typeVariable, sexp);
    return Result.success(TypeParameter(name, sexp.location));
  }

  Result<Datatype, LocatedError> datatype(Sexp sexp) {
    assert(sexp != null);
    TypeElaborator elab = new BelowToplevelTypeElaborator();
    Datatype type = sexp.visit(elab);
    return Result<Datatype, LocatedError>(type, elab.errors);
  }

  Result<Datatype, LocatedError> signatureDatatype(Sexp sexp) {
    assert(sexp != null);
    TypeElaborator elab = new TypeElaborator();
    Datatype type = sexp.visit(elab);
    return Result(type, elab.errors);
  }
}
