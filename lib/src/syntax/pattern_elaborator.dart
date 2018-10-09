// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../fp.dart' show Pair;
import '../location.dart';
import '../result.dart' show Result;
import '../unicode.dart' as unicode;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;
import 'syntax_elaborator.dart';

class PatternElaborator extends BaseElaborator<Pattern> {
  PatternElaborator() : super("PatternElaborator");

  Pattern visitString(StringLiteral string) {
    // TODO parse string literal.
    return StringPattern(string.value, string.location);
  }

  Pattern visitAtom(Atom atom) {
    assert(atom != null);

    String value = atom.value;
    Location location = atom.location;

    // Integer literal.
    if (isValidNumber(value)) {
      int denotation = int.parse(value);
      return IntPattern(denotation, location);
    }

    // Might be a boolean.
    if (isValidBoolean(value)) {
      return BoolPattern(denoteBool(value), location);
    }

    // Wildcard pattern.
    if (isWildcard(value)) {
      return WildcardPattern(location);
    }

    // Variable pattern.
    Name name = expect(identifier, atom);
    return VariablePattern(name, location);
  }

  Pattern visitList(SList list) {
    assert(list != null);
    if (list.length == 0) {
      badSyntax(list.location.end);
      return null;
    }

    // Has type pattern.
    // [P : T]
    if (list.length > 1 && list[1] is Atom && (list[1] as Atom).value == ":") {
      return expect<SList, Pattern>(hasType, list);
    }

    // Constructor or tuple pattern.
    if (list[0] is SList) {
      return expect<SList, Pattern>(constructorOrTuple, list);
    }

    if (list.length == 1 && list[0] is Atom) {
      Atom atom = list[0];
      return expect<Atom, Pattern>(pattern, atom);
    }

    badSyntax(list[1].location);
    return null;
  }

  Result<Pattern, LocatedError> hasType(SList list) {
    assert(list != null);
    if (list.length < 3) {
      LocatedError err = BadSyntaxError(list.location.end);
      return Result.failure(<LocatedError>[err]);
    }

    if (list.length > 3) {
      LocatedError err = BadSyntaxError(list[3].location);
      return Result.failure(<LocatedError>[err]);
    }

    Pattern pat = expect<Sexp, Pattern>(constructorPattern, list[0]);
    String _ = expect<Sexp, String>(colon, list[1]);
    Datatype type = expect<Sexp, Datatype>(signatureDatatype, list[2]);

    return Result.success(HasTypePattern(pat, type, list.location));
  }

  Result<Pattern, LocatedError> constructorOrTuple(SList list) {
    assert(list != null);
    if (list.length < 1) {
      LocatedError err = BadSyntaxError(list.location.end);
      return Result.failure(<LocatedError>[err]);
    }

    if (list[0] is Atom) {
      Atom atom = list[0];
      if (atom.value == ",") {
        return Result.success(expect(tuple, list));
      } else {
        return Result.success(expect(dataConstructor, list));
      }
    } else {
      LocatedError err = BadSyntaxError(list[0].location);
      return Result.failure(<LocatedError>[err]);
    }
  }

  Result<String, LocatedError> colon(Sexp sexp) {
    assert(sexp != null);

    if (sexp is Atom && (sexp as Atom).value == ":") {
      Atom atom = sexp;
      return Result.success(":");
    } else {
      LocatedError err = BadSyntaxError(sexp.location, const <String>[":"]);
      return Result.failure(<LocatedError>[err]);
    }
  }

  Result<Pattern, LocatedError> constructorPattern(Sexp sexp) {
    assert(sexp != null);
    ConstructorPatternElaborator elab = new ConstructorPatternElaborator();
    Pattern pat = sexp.visit(elab);
    return Result(pat, elab.errors);
  }

  Result<Pattern, LocatedError> tuple(SList list) {
    assert(list != null && (list[0] as Atom).value == ",");
    List<VariablePattern> pats = expectMany(variablePattern, list, 1);
    return Result.success(TuplePattern(pats, list.location));
  }

  Result<Pattern, LocatedError> dataConstructor(SList list) {
    assert(list != null);
    Name name = expect(identifier, list[0]);
    List<Pattern> pats = expectMany(variablePattern, list, 1);
    return Result.success(ConstructorPattern(name, pats, list.location));
  }

  Result<Pattern, LocatedError> variablePattern(Sexp sexp) {
    assert(sexp != null);
    Name name = expect(identifier, sexp);
    return Result.success(VariablePattern(name, sexp.location));
  }
}

class ConstructorPatternElaborator extends PatternElaborator {

  Result<Pattern, LocatedError> hasType(SList list) {
    LocatedError err = BadSyntaxError(list.location);
    return Result.failure(<LocatedError>[err]);
  }
}
