// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// import 'ast_common.dart' show Name;
// import 'ast_types.dart' show Datatype;

import 'binder.dart';
import 'datatype.dart';

abstract class Declaration {
  Datatype get type;
  Binder get binder;
  bool get isVirtual;
  int get ident;
}

// abstract class TermDeclaration extends Declaration {
//   Datatype get type;
// }
// abstract class TypeDeclaration extends Declaration {}
