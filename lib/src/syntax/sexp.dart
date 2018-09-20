// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.sexp;

import '../location.dart';

abstract class SexpVisitor<T> {
  T visitAtom<T>(Atom atom);
  T visitInt<T>(IntLiteral integer);
  T visitList<T>(SList list);
  T visitString<T>(StringLiteral string);
  T visitToplevel<T>(Toplevel toplevel);
}

abstract class Sexp {
  Location get location;

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

class SList implements Sexp {
  final Location location;
  final List<Sexp> sexps;

  const SList(List<Sexp> sexps, this.location)
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

class Toplevel extends SList {
  const Toplevel(List<Sexp> sexps, Location location) : super(sexps, location);

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitToplevel(this);
  }
}
