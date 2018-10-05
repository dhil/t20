// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';

import 'ast_common.dart' show Name;
import 'ast_types.dart' show Datatype;

abstract class Declaration {
  Location location;
  Name name;
}

abstract class TermDeclaration extends Declaration {
  Datatype type;
}
abstract class TypeDeclaration extends Declaration {}
