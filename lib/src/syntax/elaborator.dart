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

class Types {
  static const String arrow = "->";
  static const String bool = "Bool";
  static const String int = "Int";
  static const String string = "String";
  static const String forall = "forall";
  static const String tuple = "tuple";

  static bool isBaseTypename(String typeName) {
    return typeName == Types.bool ||
        typeName == Types.int ||
        typeName == Types.string;
  }
}

class TypeElaborator implements SexpVisitor<ast.T20Type> {
  ast.T20Type visitAtom(Atom atom) {
    Location loc = atom.location;
    String value = atom.value;
    // Check whether atom is a primitive type, i.e. Bool, Int, or String.
    if (Types.isBaseTypename(value)) {
      switch (atom.value) {
        case Types.bool:
          return ast.BoolType(loc);
        case Types.int:
          return ast.IntType(loc);
        case Types.string:
          return ast.StringType(loc);
        default:
          assert(false);
          return null;
      }
    } else {
      // Must be a user-defined type (i.e. nullary type application).
      if (value.length > 0 && unicode.isAsciiLetter(value.codeUnitAt(0))) {
        return ast.TypeConstructor.nullary(atom.value, loc);
      } else {
        // Error: invalid type.
        return ast.InvalidType(loc);
      }
    }
  }

  ast.T20Type visitError(Error error) {
    assert(error != null);
    // Precondition: the error must already have been reported / collected at
    // this point.
    return ast.InvalidType(error.location);
  }

  ast.T20Type visitList(SList list) {
    assert(list != null);
    if (list.length > 0 && list[0] is Atom) {
      Atom first = list[0];
      // Function type: (-> T* T).
      if (first.value == Types.arrow) {
        if (list.length < 2) {
          // Error: -> requires at least one argument.
          return null;
        } else if (list.length == 2) {
          // Nullary function.
          ast.T20Type codomain = list[1].visit(this);
          return ast.FunctionType.thunk(codomain, list.location);
        } else {
          // N-ary function.
          ast.T20Type codomain = list.last.visit(this);
          List<ast.T20Type> domain = new List<ast.T20Type>();
          for (int i = 1; i < list.length - 1; i++) {
            domain.add(list[i].visit(this));
          }
          return ast.FunctionType(domain, codomain, list.location);
        }
      }

      // Forall type: (forall id+ T).
      if (first.value == Types.forall) {
        if (list.length != 3) {
          // Error: forall requires exactly two arguments.
          return null;
        } else {
          var quantifiers =
              list[1].visit(null); // TODO: specialised quantifier visitor?
          ast.T20Type body = list[2].visit(this);
          return ast.ForallType(quantifiers, body, list.location);
        }
      }
    } else {
      // Error empty.
    }

    // Tuple type: (tuple T*).
    // Type constructor: (K T*).
    // -- special case: (K) where K = Bool | Int | String.
    return null;
  }

  ast.T20Type visitString(StringLiteral string) {
    assert(false);
    throw UnsupportedTypeElaborationMethodError(
        "TypeElaborator", "visitString");
    return null;
  }

  ast.T20Type visitToplevel(Toplevel toplevel) {
    assert(false);
    throw UnsupportedTypeElaborationMethodError(
        "TypeElaborator", "visitToplevel");
    return null;
  }
}
