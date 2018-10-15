// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:core';
import 'dart:core' as core;
import '../ast/ast_common.dart';
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
  static const String boolean = "Bool";
  static const String integer = "Int";
  static const String string = "String";
  static const String forall = "forall";
  static const String tuple = "*";

  static bool isBaseTypename(String typeName) {
    switch (typeName) {
      case Typenames.boolean:
      case Typenames.integer:
      case Typenames.string:
        return true;
      default:
        return false;
    }
  }
}

class TypeElaborator extends BaseElaborator<Datatype> {
  TypeElaborator _belowToplevelElaborator;
  TypeElaborator() : super("TypeElaborator");
  TypeElaborator._(String name) : super(name);

  TypeElaborator belowToplevelElaborator() {
    _belowToplevelElaborator ??= new BelowToplevelTypeElaborator();
    return _belowToplevelElaborator;
  }

  Datatype visitAtom(Atom atom) {
    assert(atom != null);
    Location loc = atom.location;
    String value = atom.value;
    // Check whether atom is a primitive type, i.e. Bool, Int, or String.
    switch (atom.value) {
      case Typenames.boolean:
        return BoolType(loc);
      case Typenames.integer:
        return IntType(loc);
      case Typenames.string:
        return StringType(loc);
      default:
        if (isValidTypeVariableName(value)) {
          return TypeVariable(Name(value, loc), loc);
        } else {
          // Must be a user-defined type (i.e. nullary type application).
          if (isValidTypeConstructorName(value)) {
            return TypeConstructor.nullary(Name(value, loc), loc);
          } else {
            // Error: invalid type.
            return InvalidType(loc);
          }
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
    assert(arrow.value == Typenames.arrow);
    if (list.length < 2) {
      // Error: -> requires at least one argument.
      error(InvalidFunctionTypeError(arrow.location));
      return InvalidType(list.location);
    }

    if (list.length == 2) {
      // Nullary function.
      Datatype codomain = list[1].accept<Datatype>(this);
      return FunctionType.thunk(codomain, list.location);
    } else {
      // N-ary function.
      Datatype codomain = list.last.accept<Datatype>(this);
      List<Datatype> domain = new List<Datatype>();
      for (int i = 1; i < list.length - 1; i++) {
        domain.add(expect<Sexp, Datatype>(signatureDatatype, list[i],
            makeErrorNode: invalidType));
      }
      return FunctionType(domain, codomain, list.location);
    }
  }

  Datatype forallType(Atom forall, SList list) {
    assert(forall.value == Typenames.forall);
    if (list.length != 3) {
      // Error: forall requires exactly two arguments.
      error(InvalidForallTypeError(forall.location));
      return InvalidType(list.location);
    } else {
      List<TypeParameter> qs =
          expectMany(quantifier, list[1], 0, makeErrorNode: dummyTypeParameter);
      Datatype body = expect(datatype, list[2], makeErrorNode: invalidType);
      return ForallType(qs, body, list.location);
    }
  }

  // Either 'a or ('a 'b 'c ...)
  // List<TypeParameter> quantifiers(Sexp sexp) {
  //   List<TypeParameter> qs = new List<TypeParameter>();
  //   // Either one or "many" quantifiers.
  //   if (sexp is Atom) {
  //     qs.add(quantifier(sexp));
  //   } else if (sexp is SList) {
  //     SList sexps = sexp;
  //     for (int i = 0; i < sexps.length; i++) {
  //       if (sexps[i] is Atom) {
  //         Atom atom = sexps[i];
  //         qs.add(quantifier(atom));
  //       } else {
  //         // Syntax error.
  //         error(ExpectedQuantifierError(sexps.location));
  //       }
  //     }
  //     // TODO: Maybe perform this check on [sexps] to avoid cascading errors.
  //     if (qs.isEmpty) {
  //       error(EmptyQuantifierList(sexps.location));
  //     }
  //   } else {
  //     error(ExpectedQuantifiersError(sexp.location));
  //   }
  //   return qs;
  // }

  // TypeParameter quantifier(Atom atom) {
  //   String value = atom.value;
  //   Location location = atom.location;
  //   if (!isValidTypeVariableName(value)) {
  //     // Syntax error.
  //     error(InvalidQuantifierError(value, location));
  //   }
  //   return TypeParameter(Name(value, location), location);
  // }

  // Quanfitier _dummyQuantifier() {
  //   return Quantifier("dummy", Location.dummy);
  // }

  Datatype typeConstructor(Atom constr, SList list) {
    // If the list is a singleton, then apply the elaboration rule for atoms on
    // [constr].
    if (list.length == 1) {
      return constr.accept<Datatype>(this);
    }

    if (!isValidIdentifier(constr.value)) {
      return errorNode(
          badSyntax(constr.location, <String>["constructor name"]));
    }
    Name constructorName = Name(constr.value, constr.location);
    List<Datatype> typeArguments =
        expectMany(datatype, list, 1, makeErrorNode: invalidType);

    return TypeConstructor(constructorName, typeArguments, list.location);
  }

  Datatype tupleType(Atom tuple, SList list) {
    assert(tuple.value == Typenames.tuple);
    List<Datatype> components =
        expectMany(datatype, list, 1, makeErrorNode: invalidType);
    return TupleType(components, list.location);
  }

  // InvalidType badSyntax(Location location, [List<String> expectations = null]) {
  //   T20Error err;
  //   if (expectations == null) {
  //     err = BadSyntaxError(location);
  //   } else {
  //     err = BadSyntaxWithExpectationError(expectations, location);
  //   }
  //   error(err);
  //   return InvalidType(location);
  // }

  InvalidType errorNode(LocatedError err) {
    return invalidType(err.location);
  }

  InvalidType invalidType(Location location) {
    return InvalidType(location);
  }

  TypeParameter dummyTypeParameter(Location location) {
    return TypeParameter(Name.fresh("dummy", location), location);
  }
}

class BelowToplevelTypeElaborator extends TypeElaborator {
  BelowToplevelTypeElaborator() : super._("BelowToplevelTypeElaborator");

  Datatype forallType(Atom head, SList list) {
    return errorNode(badSyntax(head.location));
  }
}
