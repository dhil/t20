// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../fp.dart' show Pair;
import '../location.dart' show Location;

abstract class ModuleAlgebra<Mod, Exp, Pat, Typ> {
  Mod datatype(Pair<String, List<Typ>> name,
      List<Pair<String, List<Typ>>> constructors, List<String> deriving,
      {Location location});

  Mod value(String name, Exp body);
  Mod function(String name, List<Pat> parameters, Exp body);
  Mod typename(Pair<String, List<String>> name, Typ type, {Location location});
  Mod signature(String name, Typ type, {Location location});

  Mod error(Object error, {Location location});
}

abstract class ExpAlgebra<Exp, Pat, Typ> {
  // Constants.
  Exp boolean(bool b, {Location location});
  Exp integer(int n, {Location location});
  Exp string(String s, {Location location});

  Exp var_(String name, {Location location});
  Exp apply(Exp fn, List<Exp> arguments, {Location location});
  Exp let(List<Pair<Pat, Exp>> bindings, Exp body,
      {int kind = 0, Location location});
  Exp tuple(List<Exp> components, {Location location});
  Exp ifthenelse(Exp condition, Exp thenBranch, Exp elseBranch,
      {Location location});
  Exp match(Exp scrutinee, List<Pair<Pat, Exp>> cases, {Location location});
  Exp typeAscription(Exp exp, Typ type, {Location location});

  Exp error(Object error, {Location location});
}

abstract class PatternAlgebra<Pat, Typ> {
  Pat hasType(Pat pattern, Typ type, {Location location});
  Pat boolean(bool b, {Location location});
  Pat integer(int n, {Location location});
  Pat string(String s, {Location location});
  Pat wildcard({Location location});
  Pat var_(String name, {Location location});
  Pat constr(String name, List<Pat> parameters, {Location location});
  Pat tuple(List<Pat> components, {Location location});

  Pat error(Object error, {Location location});
}

abstract class TypeAlgebra<Typ> {
  Typ integer({Location location});
  Typ boolean({Location location});
  Typ string({Location location});
  Typ var_(String name, {Location location});
  Typ typeParameter(String name, {Location location});
  Typ forall(List<String> quantifiers, Typ type, {Location location});
  Typ arrow(Typ domain, Typ codomain, {Location location});
  Typ constr(String name, List<Typ> arguments, {Location location});
  Typ tuple(List<Typ> components, {Location location});

  Typ error(Object error, {Location location});
}
