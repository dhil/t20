// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show LinkedHashMap;

import 'ast/ast.dart'
    show
        Binder,
        LetFunction,
        ModuleMember,
        TopModule,
        VirtualModule;

import 'compiler_constants.dart' show ModuleConstants;

enum Origin { DART_LIST, KERNEL, PRELUDE, STRING, CUSTOM }

class ModuleEnvironment {
  LinkedHashMap<String, VirtualModule> _virtualModules;

  List<TopModule> _modules;
  Map<String, TopModule> _availableModules;

  ModuleEnvironment()
      : _modules = new List<TopModule>(),
        _virtualModules = new Map<String, VirtualModule>(),
        _availableModules = new Map<String, TopModule>();

  TopModule find(String name) {
    return _availableModules[name];
  }

  void store(TopModule module) {
    if (module is VirtualModule) {
      _virtualModules[module.name] = module;
    } else {
      _modules.add(module);
    }
    _availableModules[module.name] = module;
  }

  VirtualModule get dartList => _virtualModules[ModuleConstants.DART_LIST];
  VirtualModule get kernel => _virtualModules[ModuleConstants.KERNEL];
  VirtualModule get prelude => _virtualModules[ModuleConstants.PRELUDE];
  VirtualModule get string => _virtualModules[ModuleConstants.STRING];

  List<TopModule> get modules {
    List<TopModule> allModules = new List<TopModule>()
      ..addAll(_virtualModules.values)
      ..addAll(_modules);
    return allModules;
  }

  bool isKernelModule(TopModule module) =>
      module != null && identical(module, kernel);

  Origin originOf(Binder binder) {
    if (binder.origin == null)
      throw "Logical error: The binder ${binder} has no origin.";
    if (identical(binder.origin, prelude)) return Origin.PRELUDE;
    if (identical(binder.origin, kernel)) return Origin.KERNEL;
    if (identical(binder.origin, dartList)) return Origin.DART_LIST;
    if (identical(binder.origin, string)) return Origin.STRING;

    return Origin.CUSTOM;
  }

  bool isPrimitive(Binder binder) => originOf(binder) != Origin.CUSTOM;

  bool isGlobal(Binder binder) {
    if (binder.bindingOccurrence is LetFunction) {
      LetFunction fun = binder.bindingOccurrence;
      return identical(fun.binder, binder);
    }

    // if (binder.bindingOccurrence is FunctionDeclaration) {
    //   FunctionDeclaration fun = binder.bindingOccurrence;
    //   return identical(fun.binder, binder);
    // }

    return binder.bindingOccurrence is ModuleMember;
  }

  bool isLocal(Binder binder) => !isGlobal(binder);
}
