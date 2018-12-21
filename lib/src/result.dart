// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class Result<TRes, TErr> {
  final List<TErr> errors;
  int get errorCount => errors.length;
  bool get wasSuccessful => errorCount == 0;
  final TRes result;

  Result(this.result, [List<TErr> errors = null])
      : this.errors = errors == null ? <TErr>[] : errors;

  Result.success(TRes result) : this(result, null);
  Result.failure(List<TErr> errors) : this(null, errors);
}
