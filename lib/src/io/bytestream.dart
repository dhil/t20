// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.io;

import 'dart:io';

abstract class ByteStream {
  static const END_OF_STREAM = -1;
  factory ByteStream.fromFilePath(String path) = AutoClosingFileStream;
  factory ByteStream.fromFile(RandomAccessFile handle, {int bufferSize}) =
      FileStream;
  factory ByteStream.fromString(String string) = StringStream;
  bool get atEnd;
  int peek();
  int read();
}

class StringStream implements ByteStream {
  final String _source;
  int _ptr = 0;

  StringStream(this._source);

  bool get atEnd => _ptr == _source.length;

  int peek() {
    if (_ptr == _source.length) return ByteStream.END_OF_STREAM;
    return _source.codeUnitAt(_ptr);
  }

  int read() {
    if (_ptr == _source.length) return ByteStream.END_OF_STREAM;
    return _source.codeUnitAt(_ptr++);
  }
}

class FileStream implements ByteStream {
  static const int DEFAULT_BUFFER_SIZE = 4096;
  final RandomAccessFile _handle;
  final List<int> _buffer;
  int _bufferPtr = 0;
  int _bufferEnd = 0;

  bool get atEnd {
    if (_bufferPtr == _bufferEnd) _fill();
    return _bufferPtr == _bufferEnd;
  }

  int peek() {
    if (_bufferPtr == _bufferEnd) _fill();
    if (_bufferPtr == _bufferEnd) return ByteStream.END_OF_STREAM;
    return _buffer[_bufferPtr];
  }

  int read() {
    if (_bufferPtr == _bufferEnd) _fill();
    if (_bufferPtr == _bufferEnd) return ByteStream.END_OF_STREAM;
    return _buffer[_bufferPtr++];
  }

  void _fill() {
    _bufferEnd = _handle.readIntoSync(_buffer, 0);
    _bufferPtr = 0;
  }

  FileStream(this._handle, {int bufferSize = FileStream.DEFAULT_BUFFER_SIZE})
      : _buffer = new List<int>(bufferSize);
}

class AutoClosingFileStream extends FileStream {
  bool _closed = false;

  AutoClosingFileStream(String path)
      : super(new File(path).openSync(mode: FileMode.read));

  void _fill() {
    if (_closed) return;
    super._fill();
  }

  int read() {
    if (_closed) return ByteStream.END_OF_STREAM;

    int c = super.read();
    if (c == ByteStream.END_OF_STREAM) {
      _handle.closeSync();
      _closed = true;
    }
    return c;
  }
}
