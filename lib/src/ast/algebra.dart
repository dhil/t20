// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show LocatedError;
import '../fp.dart' show Pair, Quadruple;
import '../location.dart' show Location;

abstract class ModuleAlgebra<Name, Mod, Exp, Pat, Typ> {
  // Mod datatype(Name name, List<Name> typeParameters,
  //     List<Pair<Name, List<Typ>>> constructors, List<Name> deriving,
  //     {Location location});
  Mod datatypes(
      List<Quadruple<Name, List<Name>, List<Pair<Name, List<Typ>>>, List<Name>>>
          defs,
      {Location location});

  Mod valueDef(Name name, Exp body, {Location location});
  Mod functionDef(Name name, List<Pat> parameters, Exp body,
      {Location location});
  Mod stub(Name name, List<Pat> parameters, {Location location});
  Mod foreign(Name name, List<Pat> parameters, String uri, {Location location});
  Mod module(List<Mod> members, String name, {Location location});
  Mod typename(Name name, List<Name> typeParameters, Typ type,
      {Location location});
  Mod signature(Name name, Typ type, {Location location});
  Mod open(String moduleName, {Location location});

  Mod errorModule(LocatedError error, {Location location});
}

enum BindingMethod { Parallel, Sequential }

abstract class ExpAlgebra<Name, Exp, Pat, Typ> {
  // Constants.
  Exp boolLit(bool b, {Location location});
  Exp intLit(int n, {Location location});
  Exp stringLit(String s, {Location location});

  Exp varExp(Name name, {Location location});
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

  Exp errorExp(LocatedError error, {Location location});
}

abstract class PatternAlgebra<Name, Pat, Typ> {
  Pat hasTypePattern(Pat pattern, Typ type, {Location location});
  Pat boolPattern(bool b, {Location location});
  Pat intPattern(int n, {Location location});
  Pat stringPattern(String s, {Location location});
  Pat wildcard({Location location});
  Pat varPattern(Name name, {Location location});
  Pat constrPattern(Name name, List<Pat> parameters, {Location location});
  Pat tuplePattern(List<Pat> components, {Location location});
  Pat obviousPattern({Location location});

  Pat errorPattern(LocatedError error, {Location location});
}

abstract class TypeAlgebra<Name, Typ> {
  Typ intType({Location location});
  Typ boolType({Location location});
  Typ stringType({Location location});
  Typ typeVar(Name name, {Location location});
  Typ forallType(List<Name> quantifiers, Typ type, {Location location});
  Typ arrowType(List<Typ> domain, Typ codomain, {Location location});
  Typ typeConstr(Name name, List<Typ> arguments, {Location location});
  Typ tupleType(List<Typ> components, {Location location});
  Typ constraintType(List<Pair<Name, Typ>> constraints, Typ body,
      {Location location});

  Typ errorType(LocatedError error, {Location location});
}

abstract class NameAlgebra<Name> {
  // Name declareTermName(String name, {Location location});
  // Name declareTypeName(String name, {Location location});
  Name termName(String name, {Location location});
  Name typeName(String name, {Location location});
  //void declareConstructorName(String name);
  // Option<Name> lookupTermName(String name);
  // Option<Name> lookupTypeName(String name);

  Name errorName(LocatedError error, {Location location});
}

// One algebra to rule them all...
abstract class TAlgebra<Name, Mod, Exp, Pat, Typ>
    implements
        NameAlgebra<Name>,
        ModuleAlgebra<Name, Mod, Exp, Pat, Typ>,
        ExpAlgebra<Name, Exp, Pat, Typ>,
        PatternAlgebra<Name, Pat, Typ>,
        TypeAlgebra<Name, Typ> {}
