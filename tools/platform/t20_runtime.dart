// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20_runtime;

import 'dart:io' show exit, File, IOSink, stderr;
import 'package:kernel/ast.dart' show Component;
import 'package:kernel/binary/ast_from_binary.dart';
import 'package:kernel/binary/ast_to_binary.dart';

// Error classes.
class PatternMatchFailure extends Object {
  String message;
  PatternMatchFailure([this.message]) : super();

  String toString() => message ?? "Pattern match failure";
}

class T20Error extends Object {
  Object error;
  T20Error(this.error) : super();

  String toString() => error?.toString ?? "error";
}

class Obvious extends Object {
  final int id;
  Obvious(this.id) : super();

  String toString() => "Obvious($id)";
}

A error<A>(String message) => throw T20Error(message);

// Finite iteration / corecursion.
R iterate<R>(int n, R Function(R) f, R z) {
  R result = z;
  for (int i = 0; i < n; i++) {
    result = f(result);
  }
  return result;
}

// Main driver.
void t20main(Component Function(Component) main, List<String> args) async {
  String file = args[0];
  Component c  = Component();
  BinaryBuilder(File(file).readAsBytesSync()).readSingleFileComponent(c);
  c = runTransformation(main, c);
  IOSink sink = File("transformed.dill").openWrite();
  BinaryPrinter(sink).writeComponentFile(c);
  await sink.flush();
  await sink.close();
}

// void main(List<String> args) => t20main(<main_from_source>, args);

Component runTransformation(
    Component Function(Component) main, Component argument) {
  try {
    return main(argument);
  } on T20Error catch (e) {
    stderr.writeln(e.toString());
    exit(1);
  } catch (e, s) {
    stderr.writeln("fatal error: $e");
    stderr.writeln(s.toString());
    exit(1);
  }
  return null; // Impossible!
}
