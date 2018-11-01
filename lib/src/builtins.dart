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
  // "map"  : "(forall ('a 'b) (=> (Mappable 'm) [-> (-> 'a 'b) ('m 'a) ('m 'b)]))",
  // "foldr": "(forall ('a 'b) (=> (Foldable 'f) [-> (-> 'a 'b 'b) ('f 'a) 'b 'b]))",
  // "foldl": "(forall ('a 'b) (=> (Foldable 'f) [-> (-> 'a 'b 'a) 'a ('f 'b) 'a]))"
  "map": "(forall ('a 'b) [-> (-> 'a 'b) (List 'a) (List 'b)])",
  "foldr": "(forall ('a 'b) [-> (-> 'a 'b 'b) (List 'a) 'b 'b])",
  "foldl": "(forall ('a 'b) [-> (-> 'a 'b 'a) 'a (List 'b) 'a])",

  // List constructors
  // "cons": "(forall 'a [-> 'a (List 'a) (List 'a)])"
  // "nil" : "(forall 'a [-> (*) (List 'a)])"
};

final Map<int, Name> _builtinsNameMap =
    _rawBuiltins.map((String sourceName, String _) {
  final Name name = Name.primitive(sourceName);
  return MapEntry<int, Name>(name.id, name);
});

final Set<String> _rawBuiltinTypes = Set<String>.of(<String>[
  "Bool",
  "Int",
  "String",
  "Foldable",
  "Mappable",
  // "List",
]);

final Map<int, Name> _builtinsTypeMap = _rawBuiltinTypes
    .fold(new Map<int, Name>(), (Map<int, Name> acc, String sourceName) {
  final Name name = Name.primitive(sourceName);
  acc[name.id] = name;
  return acc;
});

class Builtin {
  // bool isPrimitive(String rawName) {
  //   return _rawBuiltins.contains(rawName);
  // }

  static Map<int, Name> get termNameMap => _builtinsNameMap;
  static Map<int, Name> get typeNameMap => _builtinsTypeMap;
}
