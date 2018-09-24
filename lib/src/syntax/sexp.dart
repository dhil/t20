// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.sexp;

import '../errors/errors.dart';
import '../location.dart';

abstract class SexpVisitor<T> {
  T visitAtom<T>(Atom atom);
  T visitError<T>(Error error);
  T visitInt<T>(IntLiteral integer);
  T visitList<T>(SList list);
  T visitPair(Pair pair);
  T visitString<T>(StringLiteral string);
  T visitToplevel<T>(Toplevel toplevel);
}

abstract class Sexp {
  T visit<T>(SexpVisitor<T> visitor);
}

class Atom implements Sexp {
  final Location location;
  final String value;

  const Atom(this.value, this.location);

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitAtom(this);
  }

  String toString() {
    return value;
  }
}

class IntLiteral implements Sexp {
  final Location location;
  final int value;

  const IntLiteral(this.value, this.location);

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitInt(this);
  }

  String toString() {
    return value.toString();
  }
}

enum ListBrackets {
  BRACES,
  BRACKETS,
  PARENS
}

class SList implements Sexp {
  final Location location;
  final List<Sexp> sexps;
  final ListBrackets brackets;

  const SList(List<Sexp> sexps, this.brackets, this.location)
      : this.sexps = sexps == null ? <Sexp>[] : sexps;

  int get length => sexps.length;

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitList(this);
  }

  // T visitChildren<T>(SexpVisitor<T> visitor, T Function(SList, List<T>) transform) {
  //   final List<T> children = new List<T>();
  //   for (Sexp sexp in sexps) {
  //     children.add(sexp.visit(visitor));
  //   }
  //   return transform(this, children);
  // }
}

class Pair implements Sexp {
  final Location location;
  final Sexp first;
  final Sexp second;

  const Pair(this.first, this.second, this.location);

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitPair(this);
  }
}

class StringLiteral implements Sexp {
  final Location location;
  final String value;

  const StringLiteral(this.value, this.location);

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitString(this);
  }

  String toString() {
    return value;
  }
}

class Toplevel implements Sexp {
  final List<Sexp> sexps;
  const Toplevel(this.sexps);

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitToplevel(this);
  }
}

class Error implements Sexp {
  final SyntaxError error;

  const Error(this.error);

  T visit<T>(SexpVisitor visitor) {
    return visitor.visitError(this);
  }

  String toString() {
    return error.toString();
  }
}
