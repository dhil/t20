// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast_types.dart';
import '../errors/errors.dart';
import '../location.dart';
import '../unicode.dart' as unicode;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;
import 'syntax_elaborator.dart';


// TODO: These constants are intrinsic to the compiler; possibly useful
// elsewhere.
class Typenames {
  static const String arrow = "->";
  static const String bool = "Bool";
  static const String int = "Int";
  static const String string = "String";
  static const String forall = "forall";
  static const String tuple = "*";

  static bool isBaseTypename(String typeName) {
    return typeName == Typenames.bool ||
        typeName == Typenames.int ||
        typeName == Typenames.string;
  }
}

class TypeElaborator extends BaseElaborator<Datatype> {
  TypeElaborator() : super("TypeElaborator");

  Datatype visitAtom(Atom atom) {
    assert(atom != null);
    Location loc = atom.location;
    String value = atom.value;
    // Check whether atom is a primitive type, i.e. Bool, Int, or String.
    if (Typenames.isBaseTypename(value)) {
      switch (atom.value) {
        case Typenames.bool:
          return BoolType(loc);
        case Typenames.int:
          return IntType(loc);
        case Typenames.string:
          return StringType(loc);
        default:
          assert(false);
          return null;
      }
    } else if (isValidTypeVariable(value)) {
      return TypeVariable(value, loc);
    } else {
      // Must be a user-defined type (i.e. nullary type application).
      if (value.length > 0 && unicode.isAsciiLetter(value.codeUnitAt(0))) {
        return TypeConstructor.nullary(atom.value, loc);
      } else {
        // Error: invalid type.
        return InvalidType(loc);
      }
    }
  }

  Datatype visitError(Error error) {
    assert(error != null);
    // Precondition: the error must already have been reported / collected at
    // this point.
    return InvalidType(error.location);
  }

  Datatype visitList(SList list) {
    assert(list != null);
    if (list.length > 0 && list[0] is Atom) {
      Atom head = list[0];
      // Function type: (-> T* T).
      if (head.value == Typenames.arrow) {
        return functionType(head, list);
      }

      // Forall type: (forall id+ T).
      if (head.value == Typenames.forall) {
        return forallType(head, list);
      }

      // Tuple type: (* T*).
      if (head.value == Typenames.tuple) {
        return tupleType(head, list);
      }

      // Otherwise assume we got our hands on a type constructor.
      // Type constructor: (K T*).
      // TODO: Validate constructor name.
      return typeConstructor(head, list);
    } else {
      // Error empty.
      Location location = list.location;
      error(ExpectedValidTypeError(location));
      return InvalidType(location);
    }
  }

  Datatype functionType(Atom arrow, SList list) {
    assert(arrow == Typenames.arrow);
    if (list.length < 2) {
      // Error: -> requires at least one argument.
      error(InvalidFunctionTypeError(arrow.location));
      return InvalidType(list.location);
    }

    if (list.length == 2) {
      // Nullary function.
      Datatype codomain = list[1].visit(this);
      return FunctionType.thunk(codomain, list.location);
    } else {
      // N-ary function.
      Datatype codomain = list.last.visit(this);
      List<Datatype> domain = new List<Datatype>();
      for (int i = 1; i < list.length - 1; i++) {
        domain.add(list[i].visit(this));
      }
      return FunctionType(domain, codomain, list.location);
    }
  }

  Datatype forallType(Atom forall, SList list) {
    assert(forall == Typenames.forall);
    if (list.length != 3) {
      // Error: forall requires exactly two arguments.
      error(InvalidForallTypeError(forall.location));
      return InvalidType(list.location);
    } else {
      List<Quantifier> qs = quantifiers(list[1]);
      Datatype body = list[2].visit(this);
      return ForallType(qs, body, list.location);
    }
  }

  // Either 'a or ('a 'b 'c ...)
  List<Quantifier> quantifiers(Sexp sexp) {
    List<Quantifier> qs = new List<Quantifier>();
    // Either one or "many" quantifiers.
    if (sexp is Atom) {
      qs.add(quantifier(sexp));
    } else if (sexp is SList) {
      SList sexps = sexp;
      for (int i = 0; i < sexps.length; i++) {
        if (sexps[i] is Atom) {
          Atom atom = sexps[i];
          qs.add(quantifier(atom));
        } else {
          // Syntax error.
          error(ExpectedQuantifierError(sexps.location));
        }
      }
      // TODO: Maybe perform this check on [sexps] to avoid cascading errors.
      if (qs.isEmpty) {
        error(EmptyQuantifierList(sexps.location));
      }
    } else {
      error(ExpectedQuantifiersError(sexp.location));
    }
    return qs;
  }

  Quantifier quantifier(Atom atom) {
    String value = atom.value;
    Location location = atom.location;
    if (!isValidTypeVariable(value)) {
      // Syntax error.
      error(InvalidQuantifierError(value, location));
    }
    return Quantifier(value, location);
  }

  // Quanfitier _dummyQuantifier() {
  //   return Quantifier("dummy", Location.dummy);
  // }

  Datatype typeConstructor(Atom constr, SList list) {
    // If the list is a singleton, then apply the elaboration rule for atoms on
    // [constr].
    if (list.length == 1) {
      return constr.visit(this);
    }

    // TODO: is valid constructor name?
    String constructorName = constr.value;

    return null;
  }

  Datatype tupleType(Atom tuple, SList list) {
    assert(tuple == Typenames.tuple);
    List<Datatype> components = new List<Datatype>();
    for (int i = 1; i < list.length; i++) {
      components.add(list[i].visit(this));
    }
    return TupleType(components, list.location);
  }

  bool isValidTypeVariable(String name) {
    assert(name != null);
    return name.length > 0 && name.codeUnitAt(0) == unicode.APOSTROPHE;
  }
}

