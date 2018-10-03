// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart'
    show T20Error, UnsupportedTypeElaborationMethodError;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;

abstract class SyntaxElaborator<T> implements SexpVisitor<T> {
  final String elaboratorName;
  List<T20Error> _errors;

  List<T20Error> get errors => _errors;

  SyntaxElaborator(this.elaboratorName);

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

  void error(T20Error error) {
    _errors ??= new List<T20Error>();
    _errors.add(error);
  }
}
