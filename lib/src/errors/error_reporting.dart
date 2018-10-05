// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.errors.reporting;

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
  const int maxReports = 5;
  try {
    for (int i = 0; i < maxReports && i < errors.length; i++) {
      reporter.report(errors[i]);
    }
  } catch (err, stack) {
    reportInternal(err, stack);
  }
}

// Naïve implementation of error reporting.
class _ErrorReporter {
  _ErrorReporter();

  void report(LocatedError error) {
    LocatedSourceString lss =
        getLineText(error.location.uri, error.location.startOffset);
    String errorKind = getErrorKind(error);
    stderr.writeln(
        "\u001B[31m\u001B[1m${lss.fileName}:${lss.line}:${lss.column} $errorKind: ${error.toString()}.\u001B[0m");
    int length = computePointerLength(error);
    stderr.writeln("${lss.sourceText}");
    placePointer(lss.column, unicode.HAT, length);
  }

  void placePointer(int column, [int symbol = unicode.HAT, int length = 1]) {
    List<int> bytes = new List<int>();
    for (int i = 0; i < column; i++) {
      bytes.add(unicode.SPACE);
    }
    for (int i = 0; i < length; i++) {
      if (i == 0) {
        bytes.add(0x2514);
      } else {
        bytes.add(0x2500);
      }
        //bytes.add(symbol);
    }
    stderr.writeln("\u001B[1m${String.fromCharCodes(bytes)} This.\u001B[0m");
  }

  int computePointerLength(LocatedError error) {
    if (error is UnterminatedStringError) {
      return error.unterminatedString.length;
    }

    if (error is HasName) {
      return (error as HasName).name.length;
    }

    return 1;
  }

  String getErrorKind(LocatedError error) {
    if (error is SyntaxError) return "syntax error";
    return "error";
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

      // Open the stream.
      if (source.scheme == "data") {
        stream = ByteStream.fromString(source.data.contentText);
      } else {
        file = new File(source.toString()).openSync(mode: FileMode.read);
        stream = ByteStream.fromFile(file);
      }

      // Move the file pointer up to [startOffset]. Remember everything up to a
      // newline in [bytes].
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

      // Read the remainder of the line.
      while (
          (c = stream.read()) != unicode.NL && c != ByteStream.END_OF_STREAM) {
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

  const LocatedSourceString(
      this.sourceText, this.fileName, this.line, this.column);
}
