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
  TypeElaborator toplevelTypeElaborator = new TypeElaborator();
  TypeElaborator belowToplevelTypeElaborator;
  final Map<Name, Datatype> signatures = new Map<Name, Datatype>();
  final Set<Name> declaredNames = new Set<Name>();
  final Map<Name, TermDeclaration> declarations =
      new Map<Name, TermDeclaration>();
  final Map<Name, TypeDeclaration> typeDeclarations =
      new Map<Name, TypeDeclaration>();
  final List<String> keywords = <String>[
    ":",
    "define",
    "define-datatype",
    "define-typename",
    "include"
  ];

  ModuleElaborator() : super("ModuleElaborator") {
    belowToplevelTypeElaborator =
        toplevelTypeElaborator.belowToplevelElaborator();
  }

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
      LocatedError err = EmptyListAtToplevelError(list.location);
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
        // The [signature] and [datatypeDeclaration] methods are allowed to return null.
        members.add(member);
      }
    }
    // Add any errors caught by other elaborators.
    manyErrors(toplevelTypeElaborator.errors);
    manyErrors(belowToplevelTypeElaborator.errors);

    // Semantic checks.
    checkSemantics();
    return TopModule(members, toplevel.location);
  }

  LocatedError _nakedExpressionError(Location location) {
    LocatedError err = NakedExpressionAtToplevelError(location);
    error(err);
    return err;
  }

  ErrorModule badSyntax(Location location, [List<String> expectations = null]) {
    LocatedError err;
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
      Atom atom = list[1];
      Name name = identifier(atom);
      if (name is DummyName) return null;
      if (signatures.containsKey(name)) {
        LocatedError err =
            DuplicateTypeSignatureError(atom.value, list.location);
        error(err);
        return ErrorModule(err, list.location);
      }

      Datatype type = list[2].visit(toplevelTypeElaborator);
      signatures[name] = type;
      return null;
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
      ValueDeclaration valueDeclaration =
          ValueDeclaration(ident, body, list.location);
      declare(ident, valueDeclaration);
      return valueDeclaration;
    }

    if (list[1] is SList) {
      // (define (name P*) E+
      SList idArgs = list[1];
      if (idArgs.length == 0) {
        // Syntax error.
        return badSyntax(idArgs.location);
      }

      Name ident = identifier(idArgs[0]);
      List<Pattern> parameters = new List<Object>();
      for (int i = 1; i < idArgs.length; i++) {
        parameters.add(idArgs[i].visit(null /* PatternElaborator() */));
      }

      if (list.length < 3) {
        Location loc = list.location.end;
        return badSyntax(loc, <String>["expression"]);
      }

      List<Expression> expressions = new List<Expression>();
      for (int i = 2; i < list.length; i++) {
        expressions.add(list[i].visit(null /* ExpressionElaborator() */));
      }

      FunctionDeclaration functionDeclaration =
          FunctionDeclaration(ident, parameters, expressions, list.location);
      declare(ident, functionDeclaration);
      return functionDeclaration;
    }

    // Syntax error.
    return badSyntax(list[1].location);
  }

  ModuleMember datatypeDeclaration(Atom defineDatatype, SList list) {
    assert(defineDatatype.value == "define-datatype");
    // (define-datatype name (K T*)* or (define-datatype (name q+) (K T*)*
    if (list.length < 2) {
      return badSyntax(list.location);
    }

    DatatypeDeclaration datatypeDeclaration;
    if (list[1] is Atom) {
      // No type parameters.
      datatypeDeclaration = DatatypeDeclaration(typeIdentifier(list[1]),
          const <TypeParameter>[], dataConstructors(list), list.location);
    } else if (list[1] is SList) {
      // Expect type parameters.
      SList idParams = list[1];
      if (idParams.length < 2) {
        return badSyntax(idParams.location, <String>[
          "an identifier",
          "an identifier and a non-empty sequence of type parameters"
        ]);
      }

      Name name = typeIdentifier(idParams[0]);
      List<TypeParameter> typeParameters = new List<TypeParameter>();
      for (int i = 1; i < idParams.length; i++) {
        typeParameters.add(belowToplevelTypeElaborator.quantifier(idParams[i]));
      }

      // Constructors.
      Map<Name, List<Datatype>> constructors = new Map<Name, List<Datatype>>();
      if (list.length > 2) {
        constructors = dataConstructors(list);
      } else {
        constructors = new Map<Name, List<Datatype>>();
      }

      // TODO: derive clause.

      datatypeDeclaration = DatatypeDeclaration(
          name, typeParameters, constructors, list.location);
    } else {
      return badSyntax(list[1].location, <String>[
        "an identifier",
        "an identifier and a non-empty sequence of type parameters"
      ]);
    }
    declare(datatypeDeclaration.name, datatypeDeclaration);
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
        return DummyName(name.location);
      }
      return Name(name.value, name.location);
    } else {
      badSyntax(sexp.location, <String>["identifier"]);
      return DummyName(sexp.location);
    }
  }

  Name typeIdentifier(Sexp sexp) {
    assert(sexp != null);
    if (sexp is Atom) {
      Atom name = sexp;
      if (!isValidTypeName(name.value)) {
        badSyntax(name.location);
        return DummyName(name.location);
      }
      return Name(name.value, name.location);
    } else {
      badSyntax(sexp.location);
      return DummyName(sexp.location);
    }
  }

  Map<Name, List<Datatype>> dataConstructors(SList list) {
    assert(list != null);
    Map<Name, List<Datatype>> constructors = new Map<Name, List<Datatype>>();
    for (int i = 2; i < list.length; i++) {
      if (list[i] is SList) {
        SList constr = list[i];
        if (constr.length == 0) {
          badSyntax(constr.location, <String>["data constructor"]);
          continue;
        }

        if (constr[0] is Atom) {
          Name name = identifier(constr[0]);
          declare(name, null);
          List<Datatype> types = new List<Datatype>();
          for (int i = 1; i < constr.length; i++) {
            types.add(constr[i].visit(belowToplevelTypeElaborator));
          }

          constructors[name] = types;
        } else {
          badSyntax(constr[0].location, <String>["data constructor"]);
          continue;
        }
      } else if (list[i] is Atom) {
        // Nullary data constructor.
        Atom atom = list[i];
        Name name = identifier(atom);
        declare(name, null);
        constructors[name] = const <Datatype>[];
      }
    }
    return constructors;
  }

  // TypeParameter quantifier(Atom atom) {
  //   String value = atom.value;
  //   Location location = atom.location;
  //   if (!isValidTypeVariableName(value)) {
  //     // Syntax error.
  //     error(InvalidQuantifierError(value, location));
  //   }
  //   return TypeParameter(Name(value, location), location);
  // }

  void declare(Name name, Declaration declaration) {
    assert(name != null);
    if (name is DummyName) return;
    if (declaration is TermDeclaration) {
      if (declarations.containsKey(name) || declaredNames.contains(name)) {
        error(MultipleDeclarationsError(name.text, name.location));
        return;
      }
      declarations[name] = declaration;
      declaredNames.add(name);
    } else if (declaration is TypeDeclaration) {
      if (typeDeclarations.containsKey(name)) {
        error(MultipleDeclarationsError(name.text, name.location));
        return;
      }
      typeDeclarations[name] = declaration;
    } else {
      declaredNames.add(name);
    }
  }

  void checkSemantics() {}
}
