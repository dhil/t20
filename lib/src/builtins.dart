// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'location.dart';
import 'ast/ast_builder.dart';
import 'ast/ast_declaration.dart';
import 'ast/ast_module.dart';
import 'ast/binder.dart';
import 'ast/datatype.dart';
import 'compilation_unit.dart';
import 'errors/errors.dart';
import 'errors/error_reporting.dart'; // TODO remove.

import 'io/bytestream.dart';

import 'result.dart';

import 'static_semantics/type_utils.dart' as typeUtils;
import 'syntax/sexp.dart';
import 'syntax/parse_sexp.dart';
import 'syntax/alt/elaboration.dart';

import 'fp.dart' show Pair;
import 'location.dart';

Datatype parseDatatype(String sexp) {
  // Parse source.
  Result<Sexp, SyntaxError> parseResult =
      Parser.sexp().parse(new StringSource(sexp), trace: false);
  if (!parseResult.wasSuccessful) {
    report(parseResult.errors);
    throw "fatal error: parseDatatype parse failed.";
  }

  // Elaborate.
  Result<Datatype, LocatedError> buildResult =
      new ASTBuilder().buildDatatype(parseResult.result);
  if (!buildResult.wasSuccessful) {
    report(buildResult.errors);
    throw "fatal error: parseDatatype build failed.";
  }

  return buildResult.result;
}

VirtualFunctionDeclaration makeVirtualFunctionDeclaration(
    String name, String rawType) {
  Datatype type = parseDatatype(rawType);
  Declaration decl = VirtualFunctionDeclaration(name, type);
  return decl;
}

// ident -> declaration
Map<int, Declaration> makeBuiltinDeclarations() {
  final Map<String, String> rawFunDeclarations = <String, String>{
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
    "&&": "(-> Bool Bool Bool)",
    "||": "(-> Bool Bool Bool)",
    // Auxiliary.
    "error": "(forall 'a (-> String 'a))"
  };

  final Map<int, Declaration> funDeclarations =
      rawFunDeclarations.map((String key, String val) {
    Declaration decl = makeVirtualFunctionDeclaration(key, val);
    return MapEntry<int, Declaration>(decl.binder.id, decl);
  });

  return funDeclarations;
}

final Map<int, Declaration> declarations = makeBuiltinDeclarations();

// ident -> class
Map<int, ClassDescriptor> makeBuiltinClasses() {
  final Map<String, Map<String, String>> rawClasses =
      <String, Map<String, String>>{
    // TODO patch up types when support for constraints has been implemented.
    "Mappable": <String, String>{
      "map": "(forall ('a 'b 'temp) (-> (-> 'a 'b) 'temp 'b))"
    },
    "Foldable": <String, String>{
      "fold-right": "(forall ('a 'b 'temp) [-> (-> 'a 'b 'b) 'temp 'b 'b])",
      "fold-left": "(forall ('a 'b 'temp)  [-> (-> 'a 'b 'a) 'a 'temp 'a])"
    }
  };

  final Map<int, ClassDescriptor> classes =
      rawClasses.map((String key, Map<String, String> val) {
    // Class binder.
    Binder binder = Binder.primitive(key);
    // Create virtual declarations.
    List<VirtualFunctionDeclaration> decls =
        new List<VirtualFunctionDeclaration>();
    List<MapEntry<String, String>> entries = val.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      VirtualFunctionDeclaration decl =
          makeVirtualFunctionDeclaration(entries[i].key, entries[i].value);
      decls.add(decl);
    }
    // Create the class.
    ClassDescriptor classDesc = ClassDescriptor(binder, decls);
    return MapEntry<int, ClassDescriptor>(binder.id, classDesc);
  });

  return classes;
}

final Map<int, ClassDescriptor> classes = makeBuiltinClasses();

// final arithmeticType = ArrowType(
//     <Datatype>[typeUtils.intType, typeUtils.intType], typeUtils.intType);
// final logicalType = ArrowType(<Datatype>[

// final List<Declaration> builtinDeclarations = <Declaration>{
//   // Arithmetics.
//   VirtualFunctionDeclaration(arithmeticType, "+"),
//   VirtualFunctionDeclaration(arithmeticType, "-"),
//   VirtualFunctionDeclaration(arithmeticType, "*"),
//   VirtualFunctionDeclaration(arithmeticType, "/"),
//   VirtualFunctionDeclaration(arithmeticType, "mod"),
//       // Logical.
// };

// final Map<String, String> _rawBuiltins = {
//   // Arithmetics.
//   "+": "(-> Int Int Int)",
//   "-": "(-> Int Int Int)",
//   "*": "(-> Int Int Int)",
//   "/": "(-> Int Int Int)",
//   "mod": "(-> Int Int Int)",
//   // Logical.
//   "=": "(forall 'a (-> 'a 'a Bool))",
//   "!=": "(forall 'a (-> 'a 'a Bool))",
//   "<": "(forall 'a (-> 'a 'a Bool))",
//   ">": "(forall 'a (-> 'a 'a Bool))",
//   "<=": "(forall 'a (-> 'a 'a Bool))",
//   ">=": "(forall 'a (-> 'a 'a Bool))",
//   // Boolean.
//   "&&": "(-> Bool Bool Bool))",
//   "||": "(-> Bool Bool Bool))",
//   // Auxiliary.
//   "error": "(forall 'a (-> String 'a))",

//   // Specials.
//   // "map"  : "(forall ('a 'b) (=> (Mappable 'm) [-> (-> 'a 'b) ('m 'a) ('m 'b)]))",
//   // "foldr": "(forall ('a 'b) (=> (Foldable 'f) [-> (-> 'a 'b 'b) ('f 'a) 'b 'b]))",
//   // "foldl": "(forall ('a 'b) (=> (Foldable 'f) [-> (-> 'a 'b 'a) 'a ('f 'b) 'a]))"
//   "map": "(forall ('a 'b) [-> (-> 'a 'b) (List 'a) (List 'b)])",
//   "foldr": "(forall ('a 'b) [-> (-> 'a 'b 'b) (List 'a) 'b 'b])",
//   "foldl": "(forall ('a 'b) [-> (-> 'a 'b 'a) 'a (List 'b) 'a])",

//   // List constructors
//   // "cons": "(forall 'a [-> 'a (List 'a) (List 'a)])"
//   // "nil" : "(forall 'a [-> (*) (List 'a)])"
// };

// final Map<int, Name> _builtinsNameMap =
//     _rawBuiltins.map((String sourceName, String _) {
//   final Name name = Name.primitive(sourceName);
//   return MapEntry<int, Name>(name.id, name);
// });

// final Set<String> _rawBuiltinTypes = Set<String>.of(<String>[
//   "Bool",
//   "Int",
//   "String",
//   "Foldable",
//   "Mappable",
//   // "List",
// ]);

// final Map<int, Name> _builtinsTypeMap = _rawBuiltinTypes
//     .fold(new Map<int, Name>(), (Map<int, Name> acc, String sourceName) {
//   final Name name = Name.primitive(sourceName);
//   acc[name.id] = name;
//   return acc;
// });

// class Builtin {
//   // bool isPrimitive(String rawName) {
//   //   return _rawBuiltins.contains(rawName);
//   // }

//   static Map<int, Name> get termNameMap => _builtinsNameMap;
//   static Map<int, Name> get typeNameMap => _builtinsTypeMap;
// }
