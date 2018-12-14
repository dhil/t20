// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:kernel/binary/ast_from_binary.dart';

// An abstraction for querying the SDK VM platform.
class Platform {
  final String _vmPlatformDillPath;

  Component _platform;
  Component get platform {
    _platform ??= _loadPlatform();
    return _platform;
  }

  Component _loadPlatform() {
    Component component = Component();
    try {
      File platformFile = new File(_vmPlatformDillPath);
      new BinaryBuilder(platformFile.readAsBytesSync())
          .readSingleFileComponent(component);
    } catch (err) {
      throw err;
    }
    return component;
  }

  Platform(this._vmPlatformDillPath);

  Procedure getProcedure(PlatformPath path) {
    return null;
  }

  PlatformPathBuilder get core => PlatformPathBuilder().library("core");
}

class PlatformPath {
  final String path;
  final String target;
  const PlatformPath(this.path, this.target);
}

class PlatformPathBuilder {
  StringBuffer _path;
  String _target;

  PlatformPathBuilder() : _path = StringBuffer()..write("dart");

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
