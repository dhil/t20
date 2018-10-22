// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'ast/name.dart';

import 'fp.dart' show Pair;
import 'location.dart';

final Map<String, String> _rawBuiltins = {
  // Arithmetics.
  "+": "(-> Int Int Int)",
  "-": "(-> Int Int Int)",
  "*": "(-> Int Int Int)",
  "/": "(-> Int Int Int)",
  "mod": "(-> Int Int Int)",
  // Logical.
  "=": "(forall 'a (-> 'a 'a Bool))",
  "!=": "(forall 'a (-> 'a 'a Bool))",
  "<": "(forall 'a (-> 'a 'a Bool))",
  ">": "(forall 'a (-> 'a 'a Bool))",
  "<=": "(forall 'a (-> 'a 'a Bool))",
  ">=": "(forall 'a (-> 'a 'a Bool))",
  // Boolean.
  "&&": "(-> Bool Bool Bool))",
  "||": "(-> Bool Bool Bool))",
  // Auxiliary.
  "error": "(forall 'a (-> String 'a))",

  // Specials.
  "map": "(forall ('a 'b) (=> (Mappable 'm) (-> (-> 'a 'b) ('m 'a) ('m 'b))))"
};

final Map<int, Name> _builtinsNameMap =
    _rawBuiltins.map((String sourceName, String _) {
  final Name name = Name.primitive(sourceName);
  return MapEntry<int, Name>(name.id, name);
});

class Builtin {
  // bool isPrimitive(String rawName) {
  //   return _rawBuiltins.contains(rawName);
  // }

  static Map<int, Name> get termNameMap => _builtinsNameMap;
  static Map<int, Name> get typeNameMap => new Map<int, Name>();
}
