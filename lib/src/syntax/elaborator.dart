// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.elaborator;

import '../ast/ast.dart' as ast;
import '../errors/errors.dart';
import '../location.dart';
import '../result.dart';
import '../unicode.dart' as unicode;
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

  // Object visitInt(IntLiteral integer) {
  //   return null;
  // }

  Object visitList(SList list) {
    return null;
  }

  // Object visitPair(Pair pair) {
  //   return null;
  // }

  Object visitString(StringLiteral string) {
    return null;
  }

  Object visitToplevel(Toplevel toplevel) {
    return null;
  }
}

class TypeElaborator implements SexpVisitor<ast.T20Type> {
  ast.T20Type visitAtom(Atom atom) {
    // Check whether atom is a primitive type, i.e. Bool, Int, or String.
    if (atom.value == "Bool" || atom.value == "Int" || atom.value == "String") {
      Location loc = atom.location;
      switch (atom.value) {
        case "Bool":
          return ast.BoolType(loc);
        case "Int":
          return ast.IntType(loc);
        case "String":
          return ast.StringType(loc);
        default:
          assert(false);
          return null;
      }
    } else {
      // Must be a user-defined type (i.e. nullary type application).
      String value = atom.value;
      if (value.length > 0 && unicode.isAsciiLetter(value.codeUnitAt(0))) {
        return ast.TypeConstructor.nullary(atom.value, atom.location);
      } else {
        // Error: invalid type.
        return null;
      }
    }
  }

  ast.T20Type visitError(Error error) {
    // Precondition: the error must already have been reported / collected at
    // this point.
    return ast.InvalidType(error.location);
  }

  ast.T20Type visitList(SList list) {
    // Function type: (-> T* T).
    // Forall type: (forall id* T).
    // Tuple type: (tuple T*).
    // Type constructor: (K T*).
    // -- special case: (K) where K = Bool | Int | String.
    return null;
  }

  ast.T20Type visitString(StringLiteral string) {
    throw UnsupportedTypeElaborationMethodError("TypeElaborator", "visitString");
    return null;
  }

  ast.T20Type visitToplevel(Toplevel toplevel) {
    throw UnsupportedTypeElaborationMethodError("TypeElaborator", "visitToplevel");
    return null;
  }
}
