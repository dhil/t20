// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show LinkedHashMap;

//import 'ast/binder.dart' show Binder;
import 'ast/ast.dart'
    show
        DatatypeDeclarations,
        Declaration,
        ModuleMember,
        ModuleTag,
        TopModule,
        VirtualModule,
        TypeDescriptor;

import 'compiler_constants.dart' show ModuleConstants;

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
}
