// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import '../string_pool.dart';
import '../utils.dart' show Gensym;

final StringPool _sharedPool = new StringPool();

class Name {
  static const int UNRESOLVED = -1;
  final Location location;
  final int intern;

  int _id;
  int get id => _id;
  bool get isResolved => _id != UNRESOLVED;
  String get sourceName => _sharedPool[intern];

  Name.of(this.intern, this._id, this.location);
  Name.resolved(String name, int id, Location location)
      : this.of(_sharedPool.intern(name), id, location);
  Name.unresolved(String name, Location location)
      : this.of(_sharedPool.intern(name), UNRESOLVED, location);
  Name.primitive(String name)
      : this.resolved(name, Gensym.freshInt(), Location.primitive());

  void set resolve(int id) => _id = id;

  static int computeIntern(String name) {
    return _sharedPool.computeIntern(name);
  }
}
