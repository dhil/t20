// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast/ast_builder.dart';
import 'ast/ast_declaration.dart';
import 'ast/ast_module.dart';
import 'ast/binder.dart';
import 'ast/datatype.dart';
import 'compilation_unit.dart';
import 'errors/errors.dart'; // TODO remove.
import 'errors/error_reporting.dart'; // TODO remove.

import 'result.dart';

import 'syntax/sexp.dart';
import 'syntax/parse_sexp.dart';

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
      "map": "(forall ('a 'b 'f 'temp2) (=> ([Mappable 'f]) (-> (-> 'a 'b) 'f 'temp2)))"
    },
    "Foldable": <String, String>{
      "fold-right": "(forall ('a 'b 'f) (=> ([Foldable 'f]) [-> (-> 'a 'b 'b) 'f 'b 'b]))",
      "fold-left": "(forall ('a 'b 'temp) (=> ([Foldable 'f]) [-> (-> 'a 'b 'a) 'a 'temp 'a]))"
    },
    "Equatable": <String, String>{
      "eq?": "(forall 'a (=> ([Equatable 'a]) [-> 'a 'a Bool]))"
    },
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
