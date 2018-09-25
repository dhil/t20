// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.errors;

import 'dart:io';

import 'errors.dart';
import '../io/bytestream.dart';
import '../location.dart';
import '../unicode.dart' as unicode;

void reportInternal(dynamic error, StackTrace stack) {
  stderr.writeln("internal error: $error");
  stderr.writeln("$stack");
}

void report(List<LocatedError> errors) {
  _ErrorReporter reporter = new _ErrorReporter();
  try {
    for (LocatedError error in errors) {
      reporter.report(error);
    }
  } catch (err, stack) {
    reportInternal(err, stack);
  }
}

class _ErrorReporter {
  // Book keeping.
  Uri uri;
  RandomAccessFile _handle;
  ByteStream _stream;
  int offset = 0;
  int line = 1;
  int column = 0;

  _ErrorReporter();

  void report(LocatedError error) {
    if (uri != error.location.uri) {
      uri = error.location.uri;
      _stream = null;
    }
    openStream();
    LocatedSourceString lss = getLineText(error.location.startOffset);
    stderr.writeln("${lss.fileName}:${lss.line}:${lss.column}: ${error.toString()}.");
    stderr.writeln("${lss.sourceText}");
  }

  void openStream() {
    if (uri == null) throw ArgumentError.notNull("uri");
    if (_stream == null) {
      switch (uri.scheme) {
        case "data":
          _stream = ByteStream.fromString(uri.data.contentText);
          offset = 0;
          break;
        case "file":
          _stream = ByteStream.fromFilePath(uri.path);
          offset = 0;
          break;
        default:
          _stream = ByteStream.fromFilePath(uri.toString());
          offset = 0;
      }
    }
  }

  String getFileName() {
    assert(uri != null);
    switch (uri.scheme) {
      case "data":
        return "stdin";
      case "file":
        return uri.path;
      default:
        return uri.toString();
    }
  }

  int next() {
    int c = _stream.read();
    if (c == unicode.NL) {
      column = 0;
      line++;
    } else {
      column++;
    }
    return c;
  }

  LocatedSourceString getLineText(int startOffset) {
    int c;
    List<int> bytes = new List<int>();
    for (; offset < startOffset; offset++) {
      c = next();
      if (c == unicode.NL) {
        bytes.clear();
      } else {
        bytes.add(c);
      }
    }

    int column = this.column;
    int line = this.line;

    while ( (c = next()) != unicode.NL && c != ByteStream.END_OF_STREAM) {
      offset++;
      bytes.add(c);
    }
    String sourceText = String.fromCharCodes(bytes);
    return LocatedSourceString(sourceText, getFileName(), line, column);
  }
}

class LocatedSourceString {
  final String fileName;
  final int line;
  final int column;
  final String sourceText;

  const LocatedSourceString(this.sourceText, this.fileName, this.line, this.column);
}

