// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/algebra.dart';
import '../errors/errors.dart';

import 'sexp.dart';

class Elaborator<Mod, Exp, Pat, Typ> implements SexpVisitor<Mod> {
  final ModuleAlgebra<Mod, Exp, Pat, Typ> mod;
  final ExpAlgebra<Exp, Pat, Typ> exp;
  final PatternAlgebra<Pat, Typ> pat;
  final TypeAlgebra<Typ> typ;

  Elaborator(this.mod, this.exp, this.pat, this.typ);

  Mod elaborate(Sexp program) {
    return program.accept(this);
  }

  Mod visitToplevel(Toplevel top) {
    for (int i = 0; i < top.sexps.length; i++) {}
    return null;
  }

  // Combinators.
  Mod moduleMember(Sexp sexp) {
    if (sexp is SList) {
      SList list = sexp;
      if (list.length > 0) {
        if (list[0] is Atom) {
          Atom atom = list[0];
          switch (atom.value) {
            case "define":
              return valueDefinition(atom, list);
            case "define-datatype":
              return datatypeDefinition(atom, list);
            case "define-typename":
              return typename(atom, list);
            case "open":
              return inclusion(atom, list);
            case ":":
              return signature(atom, list);
            default:
              return mod.error(BadSyntaxError(atom.location, <String>[
                "define",
                "define-datatype",
                "define-typename",
                "open",
                ": (signature)"
              ]));
          }
        }
      }
    }
    return mod.error(NakedExpressionAtToplevelError(sexp.location));
  }

  Mod valueDefinition(Atom head, SList list) {
    assert(head.value == "define");
    return null;
  }

  Mod datatypeDefinition(Atom head, SList list) {
    assert(head.value == "define-datatype");
    return null;
  }

  Mod typename(Atom head, SList list) {
    assert(head.value == "define-typename");
    return null;
  }

  Mod inclusion(Atom head, SList list) {
    assert(head.value == "open");
    return null;
  }

  Mod signature(Atom head, SList list) {
    assert(head.value == ":");
    return null;
  }

  // Unused visitor methods.
  Mod visitAtom(Atom _) {
    assert(false);
    throw UnsupportedElaborationMethodError("elaborator", "visitAtom");
  }

  Mod visitError(Error _) {
    assert(false);
    throw UnsupportedElaborationMethodError("elaborator", "visitError");
  }

  Mod visitList(SList _) {
    assert(false);
    throw UnsupportedElaborationMethodError("elaborator", "visitList");
  }

  Mod visitString(StringLiteral _) {
    assert(false);
    throw UnsupportedElaborationMethodError("elaborator", "visitString");
  }
}
