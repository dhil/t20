// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast/binder.dart';
import 'ast/datatype.dart';
import 'errors/errors.dart' show unhandled;
import 'typing/type_utils.dart' as typeUtils;
import 'utils.dart' show StringUtils;

String _surfaceName(String primitiveName, String datatypeName) {
  // Normalisation of [datatypeName].
  String normalisedTypeName = StringUtils.uncapitalise(datatypeName);
  return "$normalisedTypeName-$primitiveName";
}

abstract class Derivable {
  Datatype computeType(TypeDescriptor desc);

  // Transliterates [name] to an instance of [Derivable]. Returns [null] if
  // [name] does not map to any known instance.
  static Derivable fromString(String name) {
    switch (name) {
      case "map":
        return const Map();
      case "map!":
        return const MapBang();
      case "fold-left":
        return const FoldLeft();
      case "fold-right":
        return const FoldRight();
      case "cata":
        return const Catamorphism();
      default:
        return null;
    }
  }

  String surfaceName(String typeName);
}

class Map implements Derivable {
  const Map();

  Datatype computeType(TypeDescriptor desc) {
    Datatype mapType;
    if (desc.parameters.length == 0) {
      // (K -> K) K K
      Datatype type = desc.type;
      mapType = ArrowType(<Datatype>[
        ArrowType(<Datatype>[type], type),
        type
      ], type);
    } else {
      // (K a -> K b) (K a) (K b).
      List<Quantifier> as = desc.parameters;
      Datatype asType = desc.type;

      List<Quantifier> bs = typeUtils.freshenQuantifiers(as);
      List<TypeVariable> bsArgs = typeUtils.typeVariables(bs);
      Datatype bsType = TypeConstructor.from(desc, bsArgs);

      Datatype funType = ArrowType(<Datatype>[asType], bsType);
      Datatype codomain = bsType;

      List<Quantifier> quantifiers0 = new List<Quantifier>()
        ..addAll(as)
        ..addAll(bs);

      mapType = ForallType.complete(
          quantifiers0, ArrowType(<Datatype>[funType, asType], codomain));
    }

    return mapType;
  }

  String surfaceName(String typeName) => _surfaceName("map", typeName);

  int get hashCode => super.hashCode * 2;

  bool operator ==(Object other) =>
      identical(this, other) || other != null && other is Map;
}

class MapBang extends Map {
  const MapBang() : super();

  int get hashCode => super.hashCode * 3;

  String surfaceName(String typeName) => _surfaceName("map!", typeName);

  bool operator ==(Object other) =>
      identical(this, other) || other != null && other is MapBang;
}

class FoldLeft implements Derivable {
  const FoldLeft();

  Datatype computeType(TypeDescriptor desc) {
    // (acc K -> acc) acc K -> acc
    Quantifier acc = Quantifier.fresh(desc.binder.origin);
    List<Quantifier> quantifiers = new List<Quantifier>()
      ..addAll(desc.parameters)
      ..add(acc);
    Datatype accType = TypeVariable.bound(acc);
    Datatype type = desc.type;

    Datatype funType = ArrowType(<Datatype>[
      ArrowType(<Datatype>[accType, type], accType),
      accType,
      type
    ], accType);
    return ForallType.complete(quantifiers, funType);
  }

  String surfaceName(String typeName) => _surfaceName("fold-left", typeName);

  int get hashCode => super.hashCode * 5;

  bool operator ==(Object other) =>
      identical(this, other) || other != null && other is FoldLeft;
}

class FoldRight implements Derivable {
  const FoldRight();

  Datatype computeType(TypeDescriptor desc) {
    // (K acc -> acc) K acc -> acc
    Quantifier acc = Quantifier.fresh(desc.binder.origin);
    List<Quantifier> quantifiers = new List<Quantifier>()
      ..addAll(desc.parameters)
      ..add(acc);
    Datatype accType = TypeVariable.bound(acc);
    Datatype type = desc.type;

    Datatype funType = ArrowType(<Datatype>[
      ArrowType(<Datatype>[type, accType], accType),
      type,
      accType
    ], accType);
    return ForallType.complete(quantifiers, funType);
  }

  String surfaceName(String typeName) => _surfaceName("fold-right", typeName);

  int get hashCode => super.hashCode * 7;

  bool operator ==(Object other) =>
      identical(this, other) || other != null && other is FoldRight;
}

class Catamorphism implements Derivable {
  const Catamorphism();

  Datatype computeType(TypeDescriptor desc) {
    // (K acc -> acc) K acc -> acc
    Quantifier acc = Quantifier.fresh(desc.binder.origin);
    List<Quantifier> quantifiers = new List<Quantifier>()
      ..addAll(desc.parameters)
      ..add(acc);
    Datatype accType = TypeVariable.bound(acc);
    Datatype type = desc.type;

    Datatype funType = ArrowType(<Datatype>[
      ArrowType(<Datatype>[type, accType], accType),
      type,
      accType
    ], accType);
    return ForallType.complete(quantifiers, funType);
  }

  String surfaceName(String typeName) => _surfaceName("cata", typeName);

  int get hashCode => super.hashCode * 11;
  bool operator ==(Object other) =>
    identical(this, other) || other != null && other is Catamorphism;
}
