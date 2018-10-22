// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show Map;

class StringPool {
  final Map<int,String> _pool = new Map<int,String>();
  final int bitmask = 0x3F;

  int intern(String s) {
    final int id = computeIntern(s);
    _pool[id] = s;
    return id;
  }

  // Returns null if [internId] is not associated with a string in this pool.
  String lookup(int internId) {
    return _pool[internId];
  }

  String operator[](int internId) {
    return _pool[internId];
  }

  int computeIntern(String s) {
    return s.hashCode;
  }
}
