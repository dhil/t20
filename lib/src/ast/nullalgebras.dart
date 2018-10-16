// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show LocatedError;
import '../fp.dart' show Option, Pair;
import '../location.dart' show Location;

import 'algebra.dart';

class NullModule<Name, Exp, Pat, Typ> extends ModuleAlgebra<Name, Null, Exp, Pat, Typ> {
  Null datatype(Pair<Name, List<Name>> name,
      List<Pair<Name, List<Typ>>> constructors, List<Name> deriving,
      {Location location}) => null;

  Null value(Name name, Exp body, {Location location}) => null;
  Null function(Name name, List<Pat> parameters, Exp body, {Location location}) => null;
  Null typename(Pair<Name, List<Name>> name, Typ type, {Location location}) => null;
  Null signature(Name name, Typ type, {Location location}) => null;

  Null error(LocatedError error, {Location location}) => null;
}

class NullExp<Name, Pat, Typ> extends ExpAlgebra<Name, Null, Pat, Typ> {
  // Constants.
  Null boolean(bool b, {Location location}) => null;
  Null integer(int n, {Location location}) => null;
  Null string(String s, {Location location}) => null;

  Null var_(Name name, {Location location}) => null;
  Null apply(Null fn, List<Null> arguments, {Location location}) => null;
  Null lambda(List<Pat> parameters, Null body, {Location location}) => null;
  Null let(List<Pair<Pat, Null>> bindings, Null body,
      {BindingMethod bindingMethod = BindingMethod.Parallel,
      Location location}) => null;
  Null tuple(List<Null> components, {Location location}) => null;
  Null ifthenelse(Null condition, Null thenBranch, Null elseBranch,
      {Location location}) => null;
  Null match(Null scrutinee, List<Pair<Pat, Null>> cases, {Location location}) => null;
  Null typeAscription(Null exp, Typ type, {Location location}) => null;

  Null error(LocatedError error, {Location location}) => null;
}

class NullPattern<Name, Typ> extends PatternAlgebra<Name, Null, Typ> {
  Null hasType(Null pattern, Typ type, {Location location}) => null;
  Null boolean(bool b, {Location location}) => null;
  Null integer(int n, {Location location}) => null;
  Null string(String s, {Location location}) => null;
  Null wildcard({Location location}) => null;
  Null var_(Name name, {Location location}) => null;
  Null constr(Name name, List<Null> parameters, {Location location}) => null;
  Null tuple(List<Null> components, {Location location}) => null;

  Null error(LocatedError error, {Location location}) => null;
}

class NullType<Name> extends TypeAlgebra<Name, Null> {
  Null integer({Location location}) => null;
  Null boolean({Location location}) => null;
  Null string({Location location}) => null;
  Null var_(Name name, {Location location}) => null;
  Null forall(List<Name> quantifiers, Null type, {Location location}) => null;
  Null arrow(List<Null> domain, Null codomain, {Location location}) => null;
  Null constr(Name name, List<Null> arguments, {Location location}) => null;
  Null tuple(List<Null> components, {Location location}) => null;

  Null error(LocatedError error, {Location location}) => null;
}

class NullName extends NameAlgebra<Null> {
  Null termName(String name, {Location location}) => null;
  Null typeName(String name, {Location location}) => null;

  Null error(LocatedError error, {Location location}) => null;
}
