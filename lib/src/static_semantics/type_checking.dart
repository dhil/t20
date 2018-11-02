// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../builtins.dart';
import '../errors/errors.dart' show LocatedError;

import '../fp.dart' show Pair, Triple, Either;
import '../immutable_collections.dart';
import '../location.dart';
import '../utils.dart' show Gensym;

import '../ast/algebra.dart';
import '../ast/datatype.dart';
import '../ast/name.dart';
import '../ast/traversals.dart' show AccumulatingContextualTransformation;

import 'type_utils.dart';
import 'unification.dart';

class AlgebraicDatatype {
  Datatype _type;
  Name name;
  List<Quantifier> quantifiers;
  List<DataConstructor> dataConstructors;

  AlgebraicDatatype(this.name, this.quantifiers, this.dataConstructors);

  Datatype get asType {
    _type ??= TypeConstructor.of(name.id,
        quantifiers.map((Quantifier q) => TypeVariable.bound(q)).toList());
    return _type;
  }
}

class DataConstructor {
  Name name;
  Datatype type;

  DataConstructor._(this.name, this.type);

  factory DataConstructor(
      Name name, AlgebraicDatatype adt, List<Datatype> domain) {
    Datatype ft = ArrowType(domain, adt.asType);
    if (adt.quantifiers.length > 0) {
      ForallType forall = ForallType();
      forall.quantifiers = adt.quantifiers;
      forall.body = ft;
      ft = forall;
    }
    return DataConstructor._(name, ft);
  }
}

class TypeAlias {
  Name name;
  List<Quantifier> quantifiers;
  Datatype type;

  TypeAlias(this.name, this.quantifiers, this.type);
}

class TypeResult {
  Datatype type; // Type resulting from check or synthesis.
  TypeAlias typeAlias; // Might be null.
  List<AlgebraicDatatype> adts; // Might be null.
  // List<Pair<int, Datatype>> dataConstructors; // Might be null.

  TypeResult.just(this.type);
}

enum Mode { CHECKING, SYNTHESIS }

class TypeContext {
  final Mode _mode;
  final ImmutableMap<int, Quantifier> quantifiers; // ident -> quantifier.
  final ImmutableMap<int, Datatype> environment; // ident -> type.
  final ImmutableMap<int, TypeAlias> typeAliases; // ident -> typename.
  // ImmutableMap<int, Object> interfaces;         // ident -> interfaces

  Mode get mode => _mode;

  TypeContext(this._mode, this.quantifiers, this.environment, this.typeAliases);
}

typedef Type<T> = Pair<TypeResult, T> Function(TypeContext);

abstract class TypeChecker<Mod, Exp, Pat>
    extends AccumulatingContextualTransformation<TypeResult, TypeContext, Name,
        Mod, Exp, Pat, Datatype> {
  final TAlgebra<Name, Mod, Exp, Pat, Datatype> _alg;
  TAlgebra<Name, Mod, Exp, Pat, Datatype> get alg => _alg;
  TypeChecker(this._alg);

  Pair<TypeResult, T> typeCheck<T>(Type<T> obj, TypeContext ctxt) {
    return obj(ctxt);
  }

  Type<Mod> module(List<Type<Mod>> members, {Location location}) =>
      (TypeContext ctxt) {
        List<Mod> members0 = new List<Mod>(members.length);
        for (int i = 0; i < members.length; i++) {
          Pair<TypeResult, Mod> result = typeCheck(members[i], ctxt);
          members0[i] = result.snd;
          // TODO update context.
        }
        return null;
      };

  Type<Exp> boolLit(bool b, {Location location}) =>
      (TypeContext _) => Pair<TypeResult, Exp>(
          TypeResult.just(boolType), alg.boolLit(b, location: location));
  Type<Exp> intLit(int n, {Location location}) =>
      (TypeContext _) => Pair<TypeResult, Exp>(
          TypeResult.just(intType), alg.intLit(n, location: location));
  Type<Exp> stringLit(String s, {Location location}) =>
      (TypeContext _) => Pair<TypeResult, Exp>(
          TypeResult.just(stringType), alg.stringLit(s, location: location));
}
