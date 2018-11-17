// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:kernel/binary/ast_from_binary.dart';
import 'package:kernel/binary/ast_to_binary.dart';

class KernelEmitter {
  final String platformFilePath;
  Component _platform;
  Component get platform {
    if (_platform == null) loadPlatform();
    return _platform;
  }

  KernelEmitter(this.platformFilePath);

  void loadPlatform() {
    Component component = Component();
    try {
      print("$platformFilePath");
      File platformFile = new File(platformFilePath);
      new BinaryBuilder(platformFile.readAsBytesSync())
          .readSingleFileComponent(component);
    } catch (err, stacktrace) {
      throw err;
    }
    _platform = component;
  }

  Procedure queryPlatform(String libraryName, String procedureName) {
    Component platformComponent = platform;
    Library library;
    for (int i = 0; i < platformComponent.libraries.length; i++) {
      Library lib = platformComponent.libraries[i];
      // print("${lib.name} == $libraryName");
      if (lib.name == libraryName) {
        library = lib;
        break;
      }
    }

    if (library != null) {
      for (int i = 0; i < library.procedures.length; i++) {
        Procedure proc = library.procedures[i];
        if (proc.name.name == procedureName) {
          return proc;
        }
      }
    }

    return null;
  }

  Component helloWorld() {
    Procedure printFunction = queryPlatform("dart.core", "print");
    if (printFunction == null) {
      throw "Print not found.";
    }
    Statement printStmt = ExpressionStatement(StaticInvocation(
        printFunction, Arguments(<Expression>[StringLiteral("Hello World!")])));
    FunctionNode mainFunNode = FunctionNode(printStmt);
    Procedure main = Procedure(Name("main"), ProcedureKind.Method, mainFunNode,
        isStatic: true);
    Uri libUri = Uri.file("bogusFile");
    Library helloLib = Library(libUri, procedures: <Procedure>[main]);
    Component helloComponent = Component(libraries: <Library>[helloLib]);
    helloComponent.mainMethodName = main.reference;
    return helloComponent;
  }

  void emit(Component tree, String filename) async {
    IOSink fileSink = new File(filename).openWrite();
    BinaryPrinter(fileSink).writeComponentFile(tree);
    await fileSink.flush();
    await fileSink.close();
  }
}
