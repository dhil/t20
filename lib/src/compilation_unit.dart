// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.compilation_unit;

import 'dart:io';

import 'io/bytestream.dart';

abstract class Source {
  Uri get uri;
  ByteStream openStream();
}

class FileSource implements Source {
  RandomAccessFile _sourceFile;

  FileSource(RandomAccessFile sourceFile) {
    if (sourceFile == null) throw new ArgumentError.notNull("sourceFile");
    this._sourceFile = sourceFile;
  }

  ByteStream openStream() {
    return new ByteStream.fromFile(_sourceFile);
  }

  Uri get uri => Uri.file(_sourceFile.path);
}

class StringSource implements Source {
  String _contents;

  StringSource(String contents) {
    if (contents == null) throw new ArgumentError.notNull("contents");
    _contents = contents;
  }

  ByteStream openStream() {
    return new ByteStream.fromString(_contents);
  }

  Uri get uri => Uri.dataFromString(_contents);
}
