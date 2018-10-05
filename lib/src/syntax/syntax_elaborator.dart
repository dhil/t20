// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart'
    show LocatedError, UnsupportedTypeElaborationMethodError;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;

abstract class SyntaxElaborator<T> implements SexpVisitor<T> {
  List<LocatedError> get errors;
}

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
}
