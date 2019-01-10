// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../settings.dart' show Settings;

import 'ast/ast.dart' show TopModule;
import 'compiler_constants.dart' show ModuleConstants;
import 'compilation_unit.dart' show StringSource;
import 'errors/errors.dart' show T20Error;
import 'frontend_compiler.dart';
import 'module_environment.dart';
import 'result.dart';

abstract class _EmbeddedModule {
  String get asTextual;
  String get name;

  StringSource get asSource => StringSource(asTextual, name);
}

// Prelude module.
class _Prelude extends _EmbeddedModule {
  String get name => ModuleConstants.PRELUDE;
  String get asTextual => '''
;; Arithmetics.
(: + (-> Int Int Int))
(define-stub (+ _ _))

(: - (-> Int Int Int))
(define-stub (- _ _))

(: * (-> Int Int Int))
(define-stub (* _ _))

(: / (-> Int Int Int))
(define-stub (/ _ _))

(: mod (-> Int Int Int))
(define-stub (mod _ _))

;; Polymorphic relational operators.
(: = (-> 'a 'a Bool))
(define-stub (= _ _))

(: != (-> 'a 'a Bool))
(define-stub (!= _ _))

(: < (-> 'a 'a Bool))
(define-stub (< _ _))

(: > (-> 'a 'a Bool))
(define-stub (> _ _))

(: <= (-> 'a 'a Bool))
(define-stub (<= _ _))

(: >= (-> 'a 'a Bool))
(define-stub (>= _ _))

;; Type specific relational operators.

(: bool-eq? (-> Bool Bool Bool))
(define-stub (bool-eq? _ _))

(: int-eq? (-> Int Int Bool))
(define-stub (int-eq? _ _))

(: int-less? (-> Int Int Bool))
(define-stub (int-less? _ _))

(: int-greater? (-> Int Int Bool))
(define-stub (int-greater? _ _))

;; Logical operations.
(: && (-> Bool Bool Bool))
(define-stub (&& _ _))

(: || (-> Bool Bool Bool))
(define-stub (|| _ _))

;; Auxiliary.
(: error (-> String 'a))
(define-stub (error _ _))

(: print (-> String (*)))
(define-stub (print _ _))

;; Iteration.
(: iterate (-> Int [-> 'a 'a] 'a 'a))
(define-stub (iterate _ _ _))
''';
}

// String module.
class _String extends _EmbeddedModule {
  String get name => ModuleConstants.STRING;
  String get asTextual => '''
;; Operations on (Dart) strings.
(: length (-> String Int))
(define-stub (length _ _))

(: concat (-> String String String))
(define-stub (concat _ _))

(: eq? (-> String String Bool))
(define-stub (eq? _ _))

(: less? (-> String String Bool))
(define-stub (less? _ _))

(: greater? (-> String String Bool))
(define-stub (greater? _ _))
''';
}

// Dart list module.
class _DartList extends _EmbeddedModule {
  String get name => ModuleConstants.DART_LIST;
  String get asTextual => '''
;; Dart-List is an "abstract" data type that is intended to map onto a
;; dart.core::List object.
(define-datatype (Dart-List 'a))

(define-datatype Void) ;; TODO define as (define-typename Void (*))

(: add! (=> ([Ground 'a]) [-> 'a (Dart-List 'a) Void]))
(define-stub (add! _ _))

(: set! (=> ([Ground 'a]) [-> Int 'a (Dart-List 'a) Void]))
(define-stub (set! _ _ _))

(: nth! (-> Int (Dart-List 'a) 'a))
(define-stub (nth! _ _))

(: length (-> (Dart-List 'a) Int))
(define-stub (length _))

(: map! (=> ([Ground 'a]) (-> [-> 'a 'b] (Dart-List 'a) (Dart-List 'b))))
(define-stub (map! _))
''';
}

// Kernel module.
class _Kernel extends _EmbeddedModule {
  String get name => ModuleConstants.KERNEL;
  String get asTextual => '''
;; Models a subset of Kernel.

(open Dart-List)

;; Dart type.
(define-datatype Dart-Type
  [DynamicType])

;; A public or private name.
(define-datatype Name [Name String])

(define-datatypes
  ;; Expressions.
  {Expression
   ;; Pure expressions without subexpressions
   [BoolLiteral Bool]
   [IntLiteral Int]
   [NullLiteral]
   [StringLiteral String]
   [TypeLiteral Dart-Type]
   [ThisExpression]
   ;; Impure expressions without subexpressions
   [InvalidExpression String]
   ;; [SuperPropertyGet Name]
   [StaticGet Name]
   ;; Pure if final
   [VariableGet Bool Name] ;; (is final, name)
   ;; Unary expressions
   [VariableSet Name Expression]
   [PropertyGet Expression Name]
   [StaticSet Name Expression]
   [Not Expression]
   [Throw Expression]
   ;; Binary expressions
   [PropertySet Expression Name Expression]
   ;; Invocations
   [MethodInvocation Expression Name Arguments]
   ;; Others
   [ConditionalExpression Expression Expression Expression]}
  ;; Arguments structure.
  {Arguments
   [Arguments (Dart-List Expression) (Dart-List Dart-Type)]}
  ;; Statements.
  {Statement
   [ExpressionStatement Expression]
   [VariableDeclaration Name Expression]
   [Block (Dart-List Statement)]
   [IfStatement Expression Statement Statement]}
  ;; Function nodes.
  {FunctionNode
   [FunctionNode Statement (Dart-List Dart-Type) (Dart-List Void) Dart-Type]} ;; TODO: the third argument should be a list of VariableDeclarations.
  ;; Procedures.
  {Procedure
   [Procedure Name FunctionNode Bool Bool]} ;; (Name, FunctionNode, isAbstract, isStatic)
  )

;; Libraries.
(define-datatype Library
  [Library String (Dart-List Procedure)]) ;; TODO add (atleast) classes and fields.

;; Components.
(define-datatype Component
  [Component (Dart-List Library)])
''';
}

// Bootstrapping mechanism.
Result<ModuleEnvironment, T20Error> bootstrap(
    {ModuleEnvironment initialEnv, Settings settings}) {
  // Set up defaults.
  initialEnv ??= ModuleEnvironment();
  settings ??= Settings();

  // Prepare the modules.
  List<_EmbeddedModule> modules = <_EmbeddedModule>[
      _Prelude(),
      _String(),
      _DartList(),
      _Kernel()
  ];

  // Initialise a frontend compiler.
  FrontendCompiler compiler = FrontendCompiler(initialEnv, settings);

  // Compile each module.
  List<T20Error> errors;
  for (int i = 0; i < modules.length; i++) {
    _EmbeddedModule module = modules[i];
    List<T20Error> result = compiler.compile(module.asSource, isVirtual: true);
    if (result != null) {
      errors ??= new List<T20Error>();
      errors.addAll(result);
    }
  }

  if (errors == null) {
    return Result<ModuleEnvironment, T20Error>.success(compiler.environment);
  } else {
    return Result<ModuleEnvironment, T20Error>.failure(errors);
  }
}
