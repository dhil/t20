// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../result.dart';

class NameRefiner {
  Result<ModuleMember, LocatedError> refine(ModuleMember mod) {
    return Result(mod, <LocatedError>[]);
  }
}
