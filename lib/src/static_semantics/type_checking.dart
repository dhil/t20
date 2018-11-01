// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../builtins.dart';
import '../errors/errors.dart'
    show
        DuplicateTypeSignatureError,
        LocatedError,
        MissingAccompanyingDefinitionError,
        MissingAccompanyingSignatureError,
        MultipleDeclarationsError,
        MultipleDefinitionsError,
        UnboundNameError;
import '../fp.dart' show Pair, Triple, Either;
import '../immutable_collections.dart';
import '../location.dart';
import '../utils.dart' show Gensym;

import '../ast/algebra.dart';
import '../ast/datatype.dart';
import '../ast/name.dart';
import '../ast/traversals.dart'
    show
        AccumulatingContextualTransformation,
        AccuTransformer,
        Catamorphism,
        Endomorphism,
        ListMonoid,
        Monoid,
        Morphism,
        NullMonoid,
        ContextualTransformation,
        Transformation,
        Transformer;

class UnificationVariable extends TypeVariable {
  UnificationVariable();
}

// A collection of convenient utility functions for inspecting / destructing types.
class TypeUtils {
  static List<Datatype> domain(Datatype ft) {
    if (ft is ArrowType) {
      return ft.domain;
    }

    if (ft is ForallType) {
      return domain(ft.body);
    }

    // Error.
    throw "'domain' called with non-function type argument.";
  }

  static Datatype codomain(Datatype ft) {
    if (ft is ArrowType) {
      return ft.codomain;
    }

    if (ft is ForallType) {
      return codomain(ft.body);
    }

    // Error.
    throw "'codomain' called with non-function type argument.";
  }

  static Set<int> freeTypeVariables(Datatype type) {
    Object ftv = null;
    return (type as dynamic).accept(ftv);
  }
}

// Return substitution or throw an error.
Either<Object, List<MapEntry<int, Datatype>>> unify(Datatype a, Datatype b) {
  if (a is BoolType && b is BoolType ||
      a is IntType && b is IntType ||
      a is StringType && b is StringType) {
    // Success.
  }

  // if (a is ForallType && b is ForallType) {
  // }
  return null;
}

class TypeResult {
  Datatype type; // Type resulting from check or synthesis.
}

class TypeContext {
  ImmutableMap<int, Quantifier> quantifiers; // ident -> quantifier.
  ImmutableMap<int, Datatype> environment; // ident -> type.
  // ImmutableMap<int, Object> interfaces;     // ident -> interfaces
}

abstract class TypeChecker<Mod, Exp, Pat>
    extends AccumulatingContextualTransformation<TypeResult, TypeContext, Name,
        Mod, Exp, Pat, Datatype> {
  final TAlgebra<Name, Mod, Exp, Pat, Datatype> _alg;
  TAlgebra<Name, Mod, Exp, Pat, Datatype> get alg => _alg;
  TypeChecker(this._alg);
}
