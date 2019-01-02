// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'ast/ast.dart'; // TODO remove.
import 'ast/ast_builder.dart'; // TODO remove.
import 'compilation_unit.dart';
import 'errors/errors.dart'; // TODO remove.
import 'errors/error_reporting.dart'; // TODO remove.

import 'codegen/ir.dart' as ir show Primitive, PrimitiveFunction, TypedBinder;

import 'result.dart';

import 'syntax/sexp.dart';
import 'syntax/parse_sexp.dart';

// TODO remove the machinery for parsing data types out of this module.
Datatype parseDatatype(String sexp, VirtualModule module,
    {BuildContext context}) {
  // Parse source.
  Result<Sexp, SyntaxError> parseResult =
      Parser.sexp().parse(new StringSource(sexp, module.name), trace: false);
  if (!parseResult.wasSuccessful) {
    report(parseResult.errors);
    throw "fatal error: parseDatatype parse failed.";
  }

  // Elaborate.
  Result<Datatype, LocatedError> buildResult = new ASTBuilder()
      .buildDatatype(parseResult.result, origin: module, context: context);
  if (!buildResult.wasSuccessful) {
    report(buildResult.errors);
    throw "fatal error: parseDatatype build failed.";
  }

  return buildResult.result;
}

VirtualFunctionDeclaration makeVirtualFunctionDeclaration(
    VirtualModule module, String name, String rawType) {
  Datatype type = parseDatatype(rawType, module);
  VirtualFunctionDeclaration decl =
      VirtualFunctionDeclaration(module, name, type);
  return decl;
}

// ident -> class
// Map<int, ClassDescriptor> makeBuiltinClasses(VirtualModule module) {
//   final Map<String, Map<String, String>> rawClasses =
//       <String, Map<String, String>>{
//     // TODO patch up types when support for constraints has been implemented.
//     "Mappable": <String, String>{
//       "map":
//           "(forall ('a 'b 'f 'temp2) (=> ([Mappable 'f]) (-> (-> 'a 'b) 'f 'temp2)))"
//     },
//     "Foldable": <String, String>{
//       "fold-right":
//           "(forall ('a 'b 'f) (=> ([Foldable 'f]) [-> (-> 'a 'b 'b) 'f 'b 'b]))",
//       "fold-left":
//           "(forall ('a 'b 'temp) (=> ([Foldable 'f]) [-> (-> 'a 'b 'a) 'a 'temp 'a]))"
//     },
//     "Equatable": <String, String>{
//       "eq?": "(forall 'a (=> ([Equatable 'a]) [-> 'a 'a Bool]))"
//     },
//   };

//   final Map<int, ClassDescriptor> classes =
//       rawClasses.map((String key, Map<String, String> val) {
//     // Class binder.
//     Binder binder = Binder.primitive(module, key);
//     // Create virtual declarations.
//     List<VirtualFunctionDeclaration> decls =
//         new List<VirtualFunctionDeclaration>();
//     List<MapEntry<String, String>> entries = val.entries.toList();
//     for (int i = 0; i < entries.length; i++) {
//       VirtualFunctionDeclaration decl = makeVirtualFunctionDeclaration(
//           module, entries[i].key, entries[i].value);
//       decls.add(decl);
//     }
//     // Create the class.
//     ClassDescriptor classDesc = ClassDescriptor(binder, decls);
//     return MapEntry<int, ClassDescriptor>(binder.ident, classDesc);
//   });

//   return classes;
// }

// final Map<int, ClassDescriptor> classes = makeBuiltinClasses(module);

// ident -> declaration
// Map<int, Declaration> makeBuiltinDeclarations() {
//   final Map<String, String> rawFunDeclarations = <String, String>{
//     // Arithmetics.
//     "+": "(-> Int Int Int)",
//     "-": "(-> Int Int Int)",
//     "*": "(-> Int Int Int)",
//     "/": "(-> Int Int Int)",
//     "mod": "(-> Int Int Int)",
//     // Relational. TODO replace by classes.
//     "=": "(forall 'a (-> 'a 'a Bool))",
//     "!=": "(forall 'a (-> 'a 'a Bool))",
//     "<": "(forall 'a (-> 'a 'a Bool))",
//     ">": "(forall 'a (-> 'a 'a Bool))",
//     "<=": "(forall 'a (-> 'a 'a Bool))",
//     ">=": "(forall 'a (-> 'a 'a Bool))",
//     // Type specific relational operations.
//     "bool-eq?": "(-> Bool Bool Bool)",
//     "int-eq?": "(-> Int Int Bool)",
//     "int-less?": "(-> Int Int Bool)",
//     "int-greater?": "(-> Int Int Bool)",
//     "string-eq?": "(-> String String Bool)",
//     "string-less?": "(-> String String Bool)",
//     "string-greater?": "(-> String String Bool)",
//     // Boolean.
//     "&&": "(-> Bool Bool Bool)",
//     "||": "(-> Bool Bool Bool)",
//     // Auxiliary.
//     "error": "(forall 'a (-> String 'a))"
//   };

//   final Map<int, Declaration> funDeclarations =
//       rawFunDeclarations.map((String key, String val) {
//     Declaration decl = makeVirtualFunctionDeclaration(key, val);
//     return MapEntry<int, Declaration>(decl.ident, decl);
//   });

//   // Insert class members.
//   final List<ClassDescriptor> defaultClasses = classes.values.toList();
//   for (int i = 0; i < defaultClasses.length; i++) {
//     ClassDescriptor cl = defaultClasses[i];
//     for (int j = 0; j < cl.members.length; j++) {
//       VirtualFunctionDeclaration member = cl.members[j];
//       funDeclarations[member.ident] = member;
//     }
//   }

//   return funDeclarations;
// }

//final Map<int, Declaration> declarations = makeBuiltinDeclarations();

// int _startIdent = 0, _endIdent = 0;

// bool isPrimitive(int ident) => _startIdent < ident && ident < _endIdent;

// Declaration find(int ident) {
//   return declarations[ident];
// }

VirtualModule _build() {
  VirtualModule builtinsModule = VirtualModule("@builtins");
  // int _startIdent = utils.Gensym();

  final Map<String, String> rawFunDeclarations = <String, String>{
    // Arithmetics.
    "+": "(-> Int Int Int)",
    "-": "(-> Int Int Int)",
    "*": "(-> Int Int Int)",
    "/": "(-> Int Int Int)",
    "mod": "(-> Int Int Int)",
    // Polymorphic relational operators.
    "=": "(forall 'a (-> 'a 'a Bool))",
    "!=": "(forall 'a (-> 'a 'a Bool))",
    "<": "(forall 'a (-> 'a 'a Bool))",
    ">": "(forall 'a (-> 'a 'a Bool))",
    "<=": "(forall 'a (-> 'a 'a Bool))",
    ">=": "(forall 'a (-> 'a 'a Bool))",
    // Type specific relational operators.
    "bool-eq?": "(-> Bool Bool Bool)",
    "int-eq?": "(-> Int Int Bool)",
    "int-less?": "(-> Int Int Bool)",
    "int-greater?": "(-> Int Int Bool)",
    "string-eq?": "(-> String String Bool)",
    "string-less?": "(-> String String Bool)",
    "string-greater?": "(-> String String Bool)",
    // Logical operations.
    "&&": "(-> Bool Bool Bool)",
    "||": "(-> Bool Bool Bool)",
    // Auxiliary.
    "error": "(forall 'a (-> String 'a))"
  };

  for (MapEntry<String, String> entry in rawFunDeclarations.entries) {
    VirtualFunctionDeclaration member =
        makeVirtualFunctionDeclaration(builtinsModule, entry.key, entry.value);
    builtinsModule.members.add(member);
  }

  // _endIdent = utils.Gensym();
  return builtinsModule;
}

VirtualModule module = _build();

//=== IR.
Map<int, ir.Primitive> _desugaredDeclarations;
Map<int, ir.TypedBinder> _typedBinders;
Map<String, int> _sourceNameIdentMapping;

Map<int, ir.Primitive> getDesugaredDeclarations() {
  // We only desugar the built in declarations once.
  if (_desugaredDeclarations != null) return _desugaredDeclarations;

  // Start "desugaring" the front end representation of primitives.
  // Populate the [_typedBinders] map at the same time.
  _typedBinders = new Map<int, ir.TypedBinder>();
  _sourceNameIdentMapping = new Map<String, int>();
  Map<int, ir.Primitive> result = Map<int, ir.Primitive>();

  for (int i = 0; i < module.members.length; i++) {
    ModuleMember member = module.members[i];
    if (member is VirtualFunctionDeclaration) {
      VirtualFunctionDeclaration decl = member;
      ir.TypedBinder binder = ir.TypedBinder.of(decl.binder, decl.type);
      ir.Primitive prim = ir.PrimitiveFunction(binder);
      binder.bindingSite = prim;
      _typedBinders[binder.ident] = binder;
      _sourceNameIdentMapping[binder.sourceName] = binder.ident;
      result[binder.ident] = prim;
    } else {
      unhandled("builtins.getDesugaredDeclarations", member);
    }
  }

  _desugaredDeclarations = result;
  return _desugaredDeclarations;
}

Map<int, ir.TypedBinder> getPrimitiveBinders() {
  if (_typedBinders == null) getDesugaredDeclarations();
  return _typedBinders;
}

ir.Primitive getPrimitive(String name) {
  Map<int, ir.Primitive> primitives = getDesugaredDeclarations();
  final int ident = _sourceNameIdentMapping[name];
  if (ident == null) {
    throw "$name is not a primitive!";
  }
  return primitives[ident];
}
