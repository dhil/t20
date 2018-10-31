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
import '../fp.dart' show Pair, Triple;
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

class TypeResult {
  Datatype type; // Type resulting from check or synthesis.
}

class TypeContext {
  ImmutableMap<int, Quantifier> quantifiers; // ident -> quantifier.
  ImmutableMap<int, Datatype> environment;   // ident -> type.
}

abstract class TypeChecker<Mod, Exp, Pat> extends AccumulatingContextualTransformation<
    TypeResult, TypeContext, Name, Mod, Exp, Pat, Datatype> {
  final TAlgebra<Name, Mod, Exp, Pat, Datatype> _alg;
  TAlgebra<Name, Mod, Exp, Pat, Datatype> get alg => _alg;
  TypeChecker(this._alg);
}
