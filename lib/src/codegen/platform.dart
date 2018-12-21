// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:kernel/ast.dart';
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

  Procedure getProcedure(PlatformPath path) {
    Component platformComponent = platform;
    // First find the enclosing library.
    Library library;
    for (int i = 0; i < platformComponent.libraries.length; i++) {
      Library lib = platformComponent.libraries[i];
      if (lib.name == path.library) {
        library = lib;
        break;
      }
    }

    // Second find the target procedure.
    if (library != null) {
      for (int i = 0; i < library.procedures.length; i++) {
        Procedure proc = library.procedures[i];
        if (proc.name.name == path.target) {
          return proc;
        }
      }
    }

    return null;
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

  static PlatformPathBuilder get core => PlatformPathBuilder._dart().library("core");
  static PlatformPathBuilder package(String pkgname) => PlatformPathBuilder._pkg(pkgname);

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
