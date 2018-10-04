// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../location.dart';
import '../unicode.dart' as unicode;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;

import '../unicode.dart' as unicode;

import 'syntax_elaborator.dart';
import 'type_elaborator.dart';

class ModuleElaborator extends BaseElaborator<ModuleMember> {
  final Map<String, Datatype> signatures = new Map<String, Datatype>();
  final Set<String> declaredNames = new Set<String>();
  final List<String> keywords = <String>[
    ":",
    "define",
    "define-datatype",
    "define-typename",
    "include"
  ];

  ModuleElaborator() : super("ModuleElaborator");

  ModuleMember visitAtom(Atom atom) {
    assert(atom != null);
    Location location = atom.location;
    return ErrorModule(_nakedExpressionError(location), location);
  }

  ModuleMember visitError(Error error) {
    assert(error != null);
    // Promote the error node.
    return ErrorModule(error.error, error.location);
  }

  ModuleMember visitList(SList list) {
    assert(list != null);
    if (list.length == 0) {
      ElaborationError err = EmptyListAtToplevelError(list.location);
      return ErrorModule(err, list.location);
    }

    if (list[0] is Atom) {
      assert(list[0] != null);
      Atom head = list[0];
      switch (head.value) {
        case ":": // Signatures.
          return signature(head, list);
        case "define": // Value definition.
          return valueDeclaration(head, list);
        case "define-datatype": // Datatype definition.
          return datatypeDeclaration(head, list);
        case "define-typename": // Type alias definition.
          return typeAliasDeclaration(head, list);
        case "include": // Module inclusion.
          return include(head, list);
        default: // Error: unexpected syntax.
          return badSyntax(head.location, keywords);
      }
    } else {
      return badSyntax(list[0].location, keywords);
    }
  }

  ModuleMember visitString(StringLiteral string) {
    assert(string != null);
    Location location = string.location;
    return ErrorModule(_nakedExpressionError(location), string.location);
  }

  TopModule visitToplevel(Toplevel toplevel) {
    assert(toplevel != null);
    List<ModuleMember> members = new List<ModuleMember>();
    for (int i = 0; i < toplevel.sexps.length; i++) {
      ModuleMember member = toplevel.sexps[i].visit(this);
      if (member != null) {
        // The [signature] method is allowed to return null.
        members.add(member);
      }
    }
    return TopModule(members, toplevel.location);
  }

  ElaborationError _nakedExpressionError(Location location) {
    ElaborationError err = NakedExpressionAtToplevelError(location);
    error(err);
    return err;
  }

  ErrorModule badSyntax(Location location, [List<String> expectations = null]) {
    ElaborationError err;
    if (expectations == null) {
      err = BadSyntaxError(location);
    } else {
      err = BadSyntaxWithExpectationError(expectations, location);
    }
    error(err);
    return ErrorModule(err, location);
  }

  ModuleMember signature(Atom colon, SList list) {
    assert(colon.value == ":");
    // Allowing signatures to appear separately from their accompanying binding
    // might be a poor surface syntax design decision, but it does have some
    // notational and presentational advantages.

    // (: name T)
    if (list.length < 2) {
      return badSyntax(colon.location);
    }

    if (list.length > 2) {
      Location loc = list[2].location;
      return badSyntax(loc, <String>[list.closingBracket()]);
    }

    if (list[1] is Atom) {
      Atom name = list[1];
      if (isValidIdentifier(name.value)) {
        if (signatures.containsKey(name.value)) {
          ElaborationError err =
              DuplicateTypeSignatureError(name.value, list.location);
          error(err);
          return ErrorModule(err, list.location);
        }

        Datatype type = list[2].visit(new TypeElaborator());
        signatures[name.value] = type;
        return null;
      } else {
        return badSyntax(name.location, <String>["identifier"]);
      }
    } else {
      return badSyntax(list[1].location, <String>["identifier"]);
    }
  }

  ModuleMember valueDeclaration(Atom define, SList list) {
    assert(define.value == "define");

    if (list.length < 3) {
      return badSyntax(list[1].location,
          <String>["identifier", "identifier and parameter list"]);
    }

    if (list[1] is Atom) {
      // (define name E)
      Name ident = identifier(list[1]);
      if (list.length > 3) {
        return badSyntax(list[3].location, <String>[list.closingBracket()]);
      }

      // Expression body = list[2].visit(new ExpressionElaborator());
      var body = null;
      return ValueDeclaration(ident, body, list.location);
    }
    // or (define (name P*) E+
    return null;
  }

  ModuleMember datatypeDeclaration(Atom defineDatatype, SList list) {
    assert(defineDatatype.value == "define-datatype");
    // (define-datatype name (K T*)*
    // or (define-datatype (name q+) (K T*)*
    return null;
  }

  ModuleMember typeAliasDeclaration(Atom defineTypename, SList list) {
    assert(defineTypename.value == "define-typename");
    // (define-typename name T)
    // or (define-typename (name q+) T
    return null;
  }

  ModuleMember include(Atom keyword, SList list) {
    assert(keyword.value == "include");
    // (include uri)
    return null;
  }

  Name identifier(Sexp sexp) {
    assert(sexp != null);
    if (sexp is Atom) {
      Atom name = sexp;
      if (!isValidIdentifier(name.value)) {
        badSyntax(name.location, <String>["identifier"]);
        return null;
      }
      return Name(name.value, name.location);
    } else {
      badSyntax(sexp.location, <String>["identifier"]);
      return null;
    }
  }
}
