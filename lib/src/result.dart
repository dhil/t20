// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

class Result<TRes, TErr> {
  final List<TErr> errors;
  int get errorCount => errors.length;
  bool get wasSuccessful => errorCount == 0;
  final TRes result;

  const Result(this.result, [errors = null])
      : this.errors = errors == null ? const [] : errors;

  const Result.success(TRes result) : this(result, null);
  const Result.failure(List<TErr> errors) : this(null, errors);
}
