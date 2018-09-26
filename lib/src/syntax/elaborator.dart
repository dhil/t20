// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.elaborator;

import '../ast/ast.dart';
import '../result.dart';
import 'sexp.dart';

class Elaborator {
  Result<Object, Object> elaborate(Sexp program) {
    Object ast = program.visit<Object>(new _Elaborate());
    Result<Object, Object> result = new Result<Object, Object>(ast, []);
    return result;
  }
}

class _Elaborate implements SexpVisitor<Object> {
  Object visitAtom(Atom atom) {
    return null;
  }

  Object visitError(Error error) {
    return null;
  }

  Object visitInt(IntLiteral integer) {
    return null;
  }

  Object visitList(SList list) {
    return null;
  }

  Object visitPair(Pair pair) {
    return null;
  }

  Object visitString(StringLiteral string) {
    return null;
  }

  Object visitToplevel(Toplevel toplevel) {
    return null;
  }
}
