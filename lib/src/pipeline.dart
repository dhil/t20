// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.pipeline;

import 'dart:io';

import '../settings.dart';

import 'errors/error_reporting.dart';
import 'errors/errors.dart';
import 'io/bytestream.dart';
import 'compilation_unit.dart';
import 'syntax/parse_sexp.dart';

bool compile(List<String> filePaths, Settings settings) {
  RandomAccessFile currentFile;
  try {
    for (String path in filePaths) {
      File file = new File(path);
      currentFile = file.openSync(mode: FileMode.read);

      // Parse source.
      Parser parser = Parser.sexp();
      Result<Sexp, SyntaxError> result = parser.parse(
          new FileSource(currentFile),
          trace: settings.trace["parser"] || settings.verbose);

      if (!result.wasSuccessful) {
        report(result.errors);
        return false;
      }
    }
  } catch (err, stack) {
    stderr.writeln("Fatal error: $err");
    stderr.writeln("$stack");
  } finally {
    if (currentFile != null) currentFile.closeSync();
  }
  return true;
}
