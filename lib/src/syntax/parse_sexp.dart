// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax;

abstract class Parser {
  void parse(Object source);
}

class Result {
  final List<Object> errors;
  int get errorCount => errors.length;
  bool get wasSuccessful => errorCount == 0;
  final Object result;

  const Result(this.result, [errors = null])
      : this.errors = errors == null ? <Object>[] : errors;
}
