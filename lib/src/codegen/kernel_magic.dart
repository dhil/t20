// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart';

import '../ast/ast.dart'
    show DataConstructor, DatatypeDescriptor, TypeConstructor;

import '../errors/errors.dart' show unhandled;

import 'platform.dart';

// Provides a mapping between the internal representation of Kernel and the
// actual external representation.
class KernelRepr {
  final Platform platform;

  KernelRepr(this.platform);

  InvocationExpression invoke(
      DataConstructor dataConstructor, List<Expression> arguments) {
    Constructor clsConstructor;
    switch (dataConstructor.binder.sourceName) {
      case "IntLiteral":
        clsConstructor = platform
            .getClass(PlatformPathBuilder.kernel.target("IntLiteral").build())
            .constructors[0];
        break;
      default:
        unhandled("KernelRepr.invoke", dataConstructor.binder.sourceName);
    }

    return ConstructorInvocation(clsConstructor, Arguments(arguments));
  }

  // Property name mapping.
  Map<String, List<Name>> propertyMap = <String, List<Name>>{
    "IntLiteral": <Name>[Name("value")]
  };

  Name project(DataConstructor dataConstructor, int label) {
    assert(label > 0);
    // Computes the name for PropertyGet.
    return propertyMap[dataConstructor.binder.sourceName][label - 1];
  }
}
