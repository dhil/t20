// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

//import 'ast/binder.dart' show Binder;
import 'ast/ast.dart'
    show
        Declaration,
        ModuleMember,
        ModuleTag,
        TopModule,
        VirtualModule,
        TypeDescriptor;

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
          descriptor = member as TypeDescriptor;
          break;
        case ModuleTag.TYPENAME:
          descriptor = member as TypeDescriptor;
          break;
        default:
        // Do nothing.
      }

      if (descriptor != null) {
        int key = useInternAsKey
            ? descriptor.binder.sourceName.hashCode
            : descriptor.ident;
        typeDescriptors[key] = descriptor;
      }
    }

    return typeDescriptors;
  }

  Map<int, Declaration> getDeclarations([bool useInternAsKey = false]) {
    Map<int, Declaration> declarations = Map<int, Declaration>();

    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member = module.members[i];
      Declaration decl;
      switch (member.tag) {
        case ModuleTag.VALUE_DEF:
          decl = member as Declaration;
          break;
        case ModuleTag.FUNC_DEF:
          decl = member as Declaration;
          break;
        case ModuleTag.CONSTR:
          decl = member as Declaration;
          break;
        default:
        // Do nothing.
      }

      if (decl != null) {
        int key = useInternAsKey ? decl.binder.sourceName.hashCode : decl.ident;
        declarations[key] = decl;
      }
    }

    return declarations;
  }
}

class ModuleEnvironment {
  VirtualModule _builtinsModule;
  List<TopModule> _modules;
  Map<String, Summary> summaries;

  ModuleEnvironment()
      : _modules = new List<TopModule>(),
        summaries = new Map<String, Summary>();

  Summary find(String name) {
    return summaries[name];
  }

  void store(TopModule module) {
    _modules.add(module);
    summaries[module.name] = Summary(module);
  }

  void set builtins(VirtualModule builtinsModule) {
    summaries[builtinsModule.name] = Summary(builtinsModule);
    _builtinsModule = builtinsModule;
  }

  VirtualModule get builtins => _builtinsModule;
  Summary get builtinsSummary {
    if (builtins == null) return null;
    return summaries[builtins.name];
  }

  List<TopModule> get modules {
    List<TopModule> allModules = new List<TopModule>();
    if (builtins != null) {
      allModules.add(builtins);
    }
    allModules.addAll(_modules);
    return allModules;
  }
}
