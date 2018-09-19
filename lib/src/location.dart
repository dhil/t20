// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.location;

class Location {
  final String fileName;
  final int line;
  final int column;

  const Location(this.fileName, this.line, this.column);
}
