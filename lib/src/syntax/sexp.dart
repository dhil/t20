// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.sexp;

import '../errors/errors.dart';
import '../location.dart';

abstract class SexpVisitor<T> {
  T visitAtom(Atom atom);
  T visitError(Error error);
  // T visitInt(IntLiteral integer);
  T visitList(SList list);
  // T visitPair(Pair pair);
  T visitString(StringLiteral string);
  T visitToplevel(Toplevel toplevel);
}

abstract class Sexp {
  final Location location;
  const Sexp(this.location);
  T visit<T>(SexpVisitor<T> visitor);
}

class Atom extends Sexp {
  final String value;

  const Atom(this.value, Location location) : super(location);

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitAtom(this);
  }

  String toString() {
    return value;
  }
}

// class IntLiteral implements Sexp {
//   final Location location;
//   final int value;

//   const IntLiteral(this.value, this.location);

//   T visit<T>(SexpVisitor<T> visitor) {
//     return visitor.visitInt(this);
//   }

//   String toString() {
//     return value.toString();
//   }
// }

enum ListBrackets { BRACES, BRACKETS, PARENS }

class SList extends Sexp {
  final List<Sexp> sexps;
  final ListBrackets brackets;

  const SList(List<Sexp> sexps, this.brackets, SpanLocation location)
      : this.sexps = sexps == null ? <Sexp>[] : sexps,
        super(location);

  SpanLocation get location => super.location as SpanLocation;

  String closingBracket() {
    switch (brackets) {
      case ListBrackets.BRACES: return "}";
      case ListBrackets.BRACKETS: return "]";
      case ListBrackets.PARENS: return ")";
    }
  }

  int get length => sexps.length;
  Sexp get last => sexps.last;

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

  Sexp operator [](int index) {
    return sexps[index];
  }
}

// class Pair implements Sexp {
//   final Location location;
//   final Sexp first;
//   final Sexp second;

//   const Pair(this.first, this.second, this.location);

//   T visit<T>(SexpVisitor<T> visitor) {
//     return visitor.visitPair(this);
//   }
// }

class StringLiteral extends Sexp {
  final String value;

  const StringLiteral(this.value, Location location) : super(location);

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitString(this);
  }

  String toString() {
    return value;
  }
}

class Toplevel extends Sexp {
  final List<Sexp> sexps;
  const Toplevel(this.sexps, Location location) : super(location);

  SpanLocation get location => super.location as SpanLocation;

  T visit<T>(SexpVisitor<T> visitor) {
    return visitor.visitToplevel(this);
  }
}

class Error extends Sexp {
  final SyntaxError error;

  const Error(this.error, Location location) : super(location);

  T visit<T>(SexpVisitor visitor) {
    return visitor.visitError(this);
  }

  String toString() {
    return error.toString();
  }
}
