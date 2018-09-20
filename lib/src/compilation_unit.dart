// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.compilation_unit;

import 'dart:io';

import 'io/stream_io.dart';

abstract class Source {
  String get sourceName;
  ByteStream openInputStream();
}

class FileSource implements Source {
  RandomAccessFile _sourceFile;

  FileSource(RandomAccessFile sourceFile) {
    if (sourceFile == null) throw new ArgumentError.notNull("sourceFile");
    _sourceFile = sourceFile;
  }

  String get sourceName => _sourceFile.path;

  ByteStream openInputStream() {
    return new ByteStream.fromFile(_sourceFile);
  }
}
