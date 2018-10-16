// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show LocatedError;
import '../fp.dart' show Option, Pair;
import '../location.dart' show Location;

abstract class ModuleAlgebra<Name, Mod, Exp, Pat, Typ> {
  Mod datatype(Pair<Name, List<Name>> name,
      List<Pair<Name, List<Typ>>> constructors, List<Name> deriving,
      {Location location});

  Mod value(Name name, Exp body, {Location location});
  Mod function(Name name, List<Pat> parameters, Exp body, {Location location});
  Mod typename(Pair<Name, List<Name>> name, Typ type, {Location location});
  Mod signature(Name name, Typ type, {Location location});

  Mod error(LocatedError error, {Location location});
}

enum BindingMethod { Parallel, Sequential }

abstract class ExpAlgebra<Name, Exp, Pat, Typ> {
  // Constants.
  Exp boolean(bool b, {Location location});
  Exp integer(int n, {Location location});
  Exp string(String s, {Location location});

  Exp var_(Name name, {Location location});
  Exp apply(Exp fn, List<Exp> arguments, {Location location});
  Exp lambda(List<Pat> parameters, Exp body, {Location location});
  Exp let(List<Pair<Pat, Exp>> bindings, Exp body,
      {BindingMethod bindingMethod = BindingMethod.Parallel,
      Location location});
  Exp tuple(List<Exp> components, {Location location});
  Exp ifthenelse(Exp condition, Exp thenBranch, Exp elseBranch,
      {Location location});
  Exp match(Exp scrutinee, List<Pair<Pat, Exp>> cases, {Location location});
  Exp typeAscription(Exp exp, Typ type, {Location location});

  Exp error(LocatedError error, {Location location});
}

abstract class PatternAlgebra<Name, Pat, Typ> {
  Pat hasType(Pat pattern, Typ type, {Location location});
  Pat boolean(bool b, {Location location});
  Pat integer(int n, {Location location});
  Pat string(String s, {Location location});
  Pat wildcard({Location location});
  Pat var_(Name name, {Location location});
  Pat constr(Name name, List<Pat> parameters, {Location location});
  Pat tuple(List<Pat> components, {Location location});

  Pat error(LocatedError error, {Location location});
}

abstract class TypeAlgebra<Name, Typ> {
  Typ integer({Location location});
  Typ boolean({Location location});
  Typ string({Location location});
  Typ var_(Name name, {Location location});
  // Typ typeParameter(Name name, {Location location});
  Typ forall(List<Name> quantifiers, Typ type, {Location location});
  Typ arrow(List<Typ> domain, Typ codomain, {Location location});
  Typ constr(Name name, List<Typ> arguments, {Location location});
  Typ tuple(List<Typ> components, {Location location});

  Typ error(LocatedError error, {Location location});
}

abstract class NameAlgebra<Name> {
  // Name declareTermName(String name, {Location location});
  // Name declareTypeName(String name, {Location location});
  Name termName(String name, {Location location});
  Name typeName(String name, {Location location});
  //void declareConstructorName(String name);
  // Option<Name> lookupTermName(String name);
  // Option<Name> lookupTypeName(String name);

  Name error(LocatedError error, {Location location});
}
