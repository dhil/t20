// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../fp.dart' show Pair;
import '../location.dart';
import '../result.dart';
import '../unicode.dart' as unicode;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;

import '../unicode.dart' as unicode;
import '../utils.dart' show ListUtils;

import 'syntax_elaborator.dart';
import 'type_elaborator.dart';

class ModuleElaborator extends BaseElaborator<ModuleMember> {
  final Map<String, Datatype> signatures = new Map<String, Datatype>();
  final Set<String> declaredNames = new Set<String>();
  final Map<String, TermDeclaration> declarations =
      new Map<String, TermDeclaration>();
  final Map<String, TypeDeclaration> typeDeclarations =
      new Map<String, TypeDeclaration>();
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
          return errorNode(badSyntax(head.location, keywords));
      }
    } else {
      return errorNode(badSyntax(list[0].location, keywords));
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

    // Semantic checks.
    checkSemantics();
    return TopModule(members, toplevel.location);
  }

  LocatedError _nakedExpressionError(Location location) {
    LocatedError err = NakedExpressionAtToplevelError(location);
    error(err);
    return err;
  }

  // ErrorModule badSyntax(Location location, [List<String> expectations = null]) {
  //   LocatedError err;
  //   if (expectations == null) {
  //     err = BadSyntaxError(location);
  //   } else {
  //     err = BadSyntaxWithExpectationError(expectations, location);
  //   }
  //   error(err);
  //   return ErrorModule(err, location);
  // }

  ModuleMember signature(Atom colon, SList list) {
    assert(colon.value == ":");
    // Allowing signatures to appear separately from their accompanying binding
    // might be a poor surface syntax design decision, but it does have some
    // notational and presentational advantages.

    // (: name T)
    if (list.length < 3) {
      return errorNode(badSyntax(colon.location));
    }

    if (list.length > 3) {
      Location loc = list[2].location;
      LocatedError err = badSyntax(loc, <String>[list.closingBracket()]);
      return errorNode(err);
    }

    if (list[1] is Atom) {
      Atom atom = list[1];
      Name name = expect(identifier, atom);
      if (name is DummyName) return null;
      if (signatures.containsKey(name.text)) {
        LocatedError err =
            DuplicateTypeSignatureError(name.text, list.location);
        error(err);
        return errorNode(err);
      }

      Datatype type = expect(signatureDatatype, list[2]);
      signatures[name.text] = type;
      return null;
    } else {
      Location location = list[1].location;
      LocatedError err = badSyntax(location, const <String>["signature"]);
      return errorNode(err);
    }
  }

  ModuleMember valueDeclaration(Atom define, SList list) {
    assert(define.value == "define");

    if (list.length < 3) {
      LocatedError err = badSyntax(list[1].location,
          <String>["identifier", "identifier and parameter list"]);
      return errorNode(err);
    }

    if (list[1] is Atom) {
      // (define name E)
      Name ident = expect(identifier, list[1]);
      if (list.length > 3) {
        LocatedError err =
            badSyntax(list[3].location, <String>[list.closingBracket()]);
        return errorNode(err);
      }

      Expression body = expect<Sexp, Expression>(expression, list[2]);
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
        LocatedError err = badSyntax(idArgs.location);
        return errorNode(err);
      }

      Name ident = expect(identifier, idArgs[0]);
      List<Pattern> parameters = expectMany(pattern, idArgs, 1);

      if (list.length < 3) {
        Location loc = list.location.end;
        LocatedError err = badSyntax(loc, <String>["expression"]);
        return errorNode(err);
      }

      List<Expression> expressions =
          expectManyOne<Sexp, Expression>(expression, list, 2);

      FunctionDeclaration functionDeclaration =
          FunctionDeclaration(ident, parameters, expressions, list.location);
      declare(ident, functionDeclaration);
      return functionDeclaration;
    }

    // Syntax error.
    LocatedError err = badSyntax(list[1].location);
    return errorNode(err);
  }

  ModuleMember datatypeDeclaration(Atom defineDatatype, SList list) {
    assert(defineDatatype.value == "define-datatype");
    // (define-datatype name (K T*)* or (define-datatype (name q+) (K T*)*
    if (list.length < 2) {
      LocatedError err = badSyntax(list.location);
      return errorNode(err);
    }

    Pair<Name, List<TypeParameter>> constructor =
        expect<Sexp, Pair<Name, List<TypeParameter>>>(typeConstructor, list[1]);

    //if (constructor == null) return null;

    // Constructors.
    Map<Name, List<Datatype>> constructors = new Map<Name, List<Datatype>>();
    if (list.length > 2) {
      constructors = dataConstructors(list);
    } else {
      constructors = new Map<Name, List<Datatype>>();
    }
    // TODO: derive clause.
    DatatypeDeclaration datatypeDeclaration = DatatypeDeclaration(
        constructor.$1, constructor.$2, constructors, list.location);
    declare(datatypeDeclaration.name, datatypeDeclaration);
    return null;
  }

  ModuleMember typeAliasDeclaration(Atom defineTypename, SList list) {
    assert(defineTypename.value == "define-typename");
    // (define-typename name T)
    // or (define-typename (name q+) T
    if (list.length < 3) {
      LocatedError err = badSyntax(list.location.end);
      return errorNode(err);
    } else if (list.length > 3) {
      return errorNode(badSyntax(list[3].location));
    } else {
      var constructor = expect<Sexp, Pair<Name, List<TypeParameter>>>(
          typeConstructor, list[1]);
      var type = expect<Sexp, Datatype>(datatype, list[2]);
      TypenameDeclaration typenameDecl = TypenameDeclaration(
          constructor.$1, constructor.$2, type, list.location);
      declare(typenameDecl.name, typenameDecl);
      return typenameDecl;
    }
  }

  ModuleMember include(Atom keyword, SList list) {
    assert(keyword.value == "include");
    // (include uri)
    return null;
  }

  // Name identifier(Sexp sexp) {
  //   assert(sexp != null);
  //   if (sexp is Atom) {
  //     Atom name = sexp;
  //     if (!isValidIdentifier(name.value)) {
  //       badSyntax(name.location, <String>["identifier"]);
  //       return DummyName(name.location);
  //     }
  //     return Name(name.value, name.location);
  //   } else {
  //     badSyntax(sexp.location, <String>["identifier"]);
  //     return DummyName(sexp.location);
  //   }
  // }

  // Name typeIdentifier(Sexp sexp) {
  //   assert(sexp != null);
  //   if (sexp is Atom) {
  //     Atom name = sexp;
  //     if (!isValidTypeName(name.value)) {
  //       badSyntax(name.location);
  //       return DummyName(name.location);
  //     }
  //     return Name(name.value, name.location);
  //   } else {
  //     badSyntax(sexp.location);
  //     return DummyName(sexp.location);
  //   }
  // }

  Map<Name, List<Datatype>> dataConstructors(SList list) {
    assert(list != null);
    List<Pair<Name, List<Datatype>>> constructors =
        expectMany(dataConstructor, list, 0);
    return ListUtils.assocToMap(constructors);
  }

  Result<Pair<Name, List<Datatype>>, LocatedError> dataConstructor(Sexp sexp) {
    assert(sexp != null);
    if (sexp is SList) {
      // N-ary constructor.
      SList list = sexp;
      Name name = expect(identifier, list[0]);
      declare(name, null);
      List<Datatype> types = expectMany(datatype, list, 1);
      return Result.success(Pair<Name, List<Datatype>>(name, types));
    } else {
      // Attempt to parse as a nullary constructor.
      Name name = expect(identifier, sexp);
      return Result.success(
          Pair<Name, List<Datatype>>(name, const <Datatype>[]));
    }
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
      if (declarations.containsKey(name.text) || declaredNames.contains(name.text)) {
        error(MultipleDeclarationsError(name.text, name.location));
        return;
      }
      declarations[name.text] = declaration;
      declaredNames.add(name.text);
    } else if (declaration is TypeDeclaration) {
      if (typeDeclarations.containsKey(name.text)) {
        error(MultipleDeclarationsError(name.text, name.location));
        return;
      }
      typeDeclarations[name.text] = declaration;
    } else {
      declaredNames.add(name.text);
    }
  }

  void checkSemantics() {}

  ModuleMember errorNode(LocatedError error) {
    return ErrorModule(error, error.location);
  }

  Result<Pair<Name, List<TypeParameter>>, LocatedError> typeConstructor(
      Sexp sexp) {
    if (sexp is Atom) {
      Atom atom = sexp;
      Name name = expect<Sexp, Name>(typeConstructorName, atom);
      return Result.success(
          Pair<Name, List<TypeParameter>>(name, const <TypeParameter>[]));
    } else if (sexp is SList) {
      SList list = sexp;
      if (list.length < 2) {
        LocatedError err = BadSyntaxError(list.location.end, const <String>[
          "type constructor followed by a non-empty sequence of quantifiers"
        ]);
        return Result.failure(<LocatedError>[err]);
      } else {
        Name name = expect<Sexp, Name>(typeConstructorName, list[0]);
        List<TypeParameter> typeParameters = expectManyOne(quantifier, list, 1);
        return Result.success(Pair(name, typeParameters));
      }
    } else {
      LocatedError err = BadSyntaxError(sexp.location, const <String>[
        "type constructor",
        "type constructor followed by a non-empty sequence of quantifiers"
      ]);
      return Result.failure(<LocatedError>[err]);
    }
  }
}
