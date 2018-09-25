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
  _ErrorReporter();

  void report(LocatedError error) {
    LocatedSourceString lss = getLineText(error.location.uri, error.location.startOffset);
    stderr.writeln("${lss.fileName}:${lss.line}:${lss.column}: ${error.toString()}.");
    stderr.writeln("${lss.sourceText}");
    int length = 1;
    if (error is UnterminatedStringError) {
      length = error.unterminatedString.length;
    }
    placePointer(lss.column, length);
  }

  void placePointer(int column, [int length = 1]) {
    List<int> bytes = new List<int>();
    for (int i = 0; i < column; i++) {
      bytes.add(unicode.SPACE);
    }
    for (int i = 0; i < length; i++) {
      bytes.add(unicode.HAT);
    }
    stderr.writeln(String.fromCharCodes(bytes));
  }

  String getFileName(Uri uri) {
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

  LocatedSourceString getLineText(Uri source, int startOffset) {
    RandomAccessFile file;
    ByteStream stream;
    try {
      int c;
      int line = 1;
      int column = 0;

      if (source.scheme == "data") {
        stream = ByteStream.fromString(source.data.contentText);
      } else {
        file = new File(source.toString()).openSync(mode: FileMode.read);
        stream = ByteStream.fromFile(file);
      }

      List<int> bytes = new List<int>();
      for (int offset = 0; offset < startOffset; offset++) {
        c = stream.read();
        if (c == unicode.NL) {
          column = 0;
          ++line;
          bytes.clear();
        } else {
          ++column;
          bytes.add(c);
        }
      }

      while ( (c = stream.read()) != unicode.NL && c != ByteStream.END_OF_STREAM) {
        bytes.add(c);
      }

      // Clean up.
      if (file != null) file.closeSync();
      file = null;

      // Construct the result.
      String sourceText = String.fromCharCodes(bytes);
      return LocatedSourceString(sourceText, getFileName(source), line, column);
    } finally {
      if (file != null) file.closeSync();
    }
  }
}

class LocatedSourceString {
  final String fileName;
  final int line;
  final int column;
  final String sourceText;

  const LocatedSourceString(this.sourceText, this.fileName, this.line, this.column);
}

