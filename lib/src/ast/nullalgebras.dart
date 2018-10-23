// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show LocatedError;
import '../fp.dart' show Option, Pair, Triple;
import '../location.dart' show Location;

import 'algebra.dart';

class NullModule<Name, Exp, Pat, Typ>
    extends ModuleAlgebra<Name, Null, Exp, Pat, Typ> {
  // Null datatype(Name binder, List<Name> typeParameters,
  //         List<Pair<Name, List<Typ>>> constructors, List<Name> deriving,
  //         {Location location}) =>
  //     null;

  Null datatypes(
          List<Triple<Name, List<Name>, List<Pair<Name, List<Typ>>>>> defs,
          List<Name> deriving,
          {Location location}) =>
      null;

  Null valueDef(Name name, Exp body, {Location location}) => null;
  Null functionDef(Name name, List<Pat> parameters, Exp body,
          {Location location}) =>
      null;
  Null module(List<Null> _, {Location location}) => null;
  Null typename(Name binder, List<Name> typeParameters, Typ type,
          {Location location}) =>
      null;
  Null signature(Name name, Typ type, {Location location}) => null;

  Null errorModule(LocatedError error, {Location location}) => null;
}

class NullExp<Name, Pat, Typ> extends ExpAlgebra<Name, Null, Pat, Typ> {
  // Constants.
  Null boolLit(bool b, {Location location}) => null;
  Null intLit(int n, {Location location}) => null;
  Null stringLit(String s, {Location location}) => null;

  Null varExp(Name name, {Location location}) => null;
  Null apply(Null fn, List<Null> arguments, {Location location}) => null;
  Null lambda(List<Pat> parameters, Null body, {Location location}) => null;
  Null let(List<Pair<Pat, Null>> bindings, Null body,
          {BindingMethod bindingMethod = BindingMethod.Parallel,
          Location location}) =>
      null;
  Null tuple(List<Null> components, {Location location}) => null;
  Null ifthenelse(Null condition, Null thenBranch, Null elseBranch,
          {Location location}) =>
      null;
  Null match(Null scrutinee, List<Pair<Pat, Null>> cases,
          {Location location}) =>
      null;
  Null typeAscription(Null exp, Typ type, {Location location}) => null;

  Null errorExp(LocatedError error, {Location location}) => null;
}

class NullPattern<Name, Typ> extends PatternAlgebra<Name, Null, Typ> {
  Null hasTypePattern(Null pattern, Typ type, {Location location}) => null;
  Null boolPattern(bool b, {Location location}) => null;
  Null intPattern(int n, {Location location}) => null;
  Null stringPattern(String s, {Location location}) => null;
  Null wildcard({Location location}) => null;
  Null varPattern(Name name, {Location location}) => null;
  Null constrPattern(Name name, List<Null> parameters, {Location location}) =>
      null;
  Null tuplePattern(List<Null> components, {Location location}) => null;

  Null errorPattern(LocatedError error, {Location location}) => null;
}

class NullType<Name> extends TypeAlgebra<Name, Null> {
  Null intType({Location location}) => null;
  Null boolType({Location location}) => null;
  Null stringType({Location location}) => null;
  Null typeVar(Name name, {Location location}) => null;
  Null forallType(List<Name> quantifiers, Null type, {Location location}) =>
      null;
  Null arrowType(List<Null> domain, Null codomain, {Location location}) => null;
  Null typeConstr(Name name, List<Null> arguments, {Location location}) => null;
  Null tupleType(List<Null> components, {Location location}) => null;

  Null errorType(LocatedError error, {Location location}) => null;
}

class NullName extends NameAlgebra<Null> {
  Null termName(String name, {Location location}) => null;
  Null typeName(String name, {Location location}) => null;

  Null errorName(LocatedError error, {Location location}) => null;
}

class NullAlgebra = TAlgebra<Null, Null, Null, Null, Null>
    with
        NullName,
        NullModule<Null, Null, Null, Null>,
        NullExp<Null, Null, Null>,
        NullPattern<Null, Null>,
        NullType<Null>;
