// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:kernel/core_types.dart';
import 'package:kernel/binary/ast_from_binary.dart';

// An abstraction for querying the SDK VM platform.
class Platform {
  final String _platformDillPath;

  Component _platform;
  Component get platform {
    _platform ??= _loadPlatform();
    return _platform;
  }

  Component _loadPlatform() {
    Component component = Component();
    try {
      File platformFile = new File(_platformDillPath);
      new BinaryBuilder(platformFile.readAsBytesSync())
          .readSingleFileComponent(component);
    } catch (err) {
      throw err;
    }
    return component;
  }

  Platform(this._platformDillPath);

  Library getLibrary(PlatformPath path) {
    Component platformComponent = platform;
    for (int i = 0; i < platformComponent.libraries.length; i++) {
      Library lib = platformComponent.libraries[i];
      if (lib.name == path.library) {
        return lib;
      }
    }

    return null;
  }

  Procedure getProcedure(PlatformPath path) {
    // First find the enclosing library.
    Library library = getLibrary(path);

    // Second find the target procedure.
    if (library != null) {
      for (int i = 0; i < library.procedures.length; i++) {
        Procedure proc = library.procedures[i];
        if (proc.name.name == path.target) {
          return proc;
        }
      }
    }

    warn("procedure", path.toString());
    return null;
  }

  Class getClass(PlatformPath path) {
    // First find the enclosing library.
    Library library = getLibrary(path);

    // Second find the target procedure.
    if (library != null) {
      for (int i = 0; i < library.classes.length; i++) {
        Class cls = library.classes[i];
        if (cls.name == path.target) {
          return cls;
        }
      }
    }

    warn("class", path.toString());
    return null;
  }

  static CoreTypes _coreTypes = null;
  CoreTypes get coreTypes {
    _coreTypes ??= CoreTypes(platform);
    return _coreTypes;
  }

  void warn(String kind, String target) {
    stderr.writeln("warning: could not resolve '$target' as $kind");
  }
}

class PlatformPath {
  final String library;
  final String target;
  const PlatformPath(this.library, this.target);

  String toString() => "$library.$target";
}

class PlatformPathBuilder {
  StringBuffer _path;
  String _target;

  PlatformPathBuilder._dart() : this._("dart");
  PlatformPathBuilder._pkg(String pkgname) : this._(pkgname);
  PlatformPathBuilder._(String scheme) : _path = StringBuffer()..write(scheme);

  static PlatformPathBuilder get dart => PlatformPathBuilder._dart();
  static PlatformPathBuilder get core =>
      PlatformPathBuilder.dart.library("core");
  static PlatformPathBuilder get kernel =>
      PlatformPathBuilder.package("kernel");
  static PlatformPathBuilder get t20 => PlatformPathBuilder._pkg("t20_runtime");
  static PlatformPathBuilder package(String pkgname) =>
      PlatformPathBuilder._pkg(pkgname);

  PlatformPath build() {
    if (target == null) {
      throw "no target set.";
    }
    return PlatformPath(_path.toString(), _target);
  }

  PlatformPathBuilder library(String libraryName) {
    if (_path.length > 0) _path.write(".");
    _path.write(libraryName);
    return this;
  }

  PlatformPathBuilder target(String name) {
    _target = name;
    return this;
  }
}
