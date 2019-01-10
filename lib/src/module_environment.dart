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

class Summary {
  // Reference to the module.
  TopModule module;

  Summary(this.module);

  Map<int, TypeDescriptor> getTypeDescriptors([bool useInternAsKey = false]) {
    Map<int, TypeDescriptor> typeDescriptors = Map<int, TypeDescriptor>();

    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member = module.members[i];
      TypeDescriptor descriptor;
      switch (member.tag) {
        case ModuleTag.DATATYPE_DEFS:
          DatatypeDeclarations datatypes = member as DatatypeDeclarations;
          for (int j = 0; j < datatypes.declarations.length; j++) {
            TypeDescriptor descriptor = datatypes.declarations[j];
            int key = useInternAsKey
                ? descriptor.binder.sourceName.hashCode
                : descriptor.ident;
            typeDescriptors[key] = descriptor;
          }
          break;
        case ModuleTag.TYPENAME:
          TypeDescriptor descriptor = member as TypeDescriptor;
          int key = useInternAsKey
              ? descriptor.binder.sourceName.hashCode
              : descriptor.ident;
          typeDescriptors[key] = descriptor;
          break;
        default:
        // Do nothing.
      }
    }

    return typeDescriptors;
  }

  Map<int, Declaration> getDeclarations([bool useInternAsKey = false]) {
    Map<int, Declaration> declarations = Map.fromIterable(
        module.members.where((ModuleMember member) => member is Declaration),
        key: (dynamic decl) => useInternAsKey
            ? (decl as Declaration).binder.intern
            : (decl as Declaration).binder.ident,
        value: (dynamic decl) => decl as Declaration);
    return declarations;
  }
}

class ModuleEnvironment {
  // VirtualModule _builtinsModule;
  LinkedHashMap<String, VirtualModule> _virtualModules;

  List<TopModule> _modules;
  Map<String, Summary> summaries;

  ModuleEnvironment()
      : _modules = new List<TopModule>(),
        _virtualModules = new Map<String, VirtualModule>(),
        summaries = new Map<String, Summary>();

  Summary find(String name) {
    return summaries[name];
  }

  void store(TopModule module) {
    if (module is VirtualModule) {
      _virtualModules[module.name] = module;
    } else {
      _modules.add(module);
    }
    summaries[module.name] = Summary(module);
  }

  VirtualModule get dartList => _virtualModules[ModuleConstants.DART_LIST];
  VirtualModule get kernel => _virtualModules[ModuleConstants.KERNEL];
  VirtualModule get prelude => _virtualModules[ModuleConstants.PRELUDE];
  VirtualModule get string => _virtualModules[ModuleConstants.STRING];

  Summary summaryOf(TopModule module) {
    if (module == null) return null;

    Summary summary = find(module.name);
    if (summary != null && identical(module, summary.module)) {
      return summary;
    } else {
      return Summary(module);
    }
  }

  List<TopModule> get modules {
    List<TopModule> allModules = new List<TopModule>()
      ..addAll(_virtualModules.values)
      ..addAll(_modules);
    return allModules;
  }
}
