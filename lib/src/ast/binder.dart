// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import '../utils.dart' show Gensym;

class Binder {
  final String _sourceName;
  final Location _location;
  final int id;

  Location get location => _location ?? Location.dummy();
  String get sourceName => _sourceName ?? "<synthetic>";

  Binder.fromSource(String sourceName, Location location)
      : this.raw(Gensym.freshInt(), sourceName, location);
  Binder.fresh() : this.fromSource(null, null);
  Binder.primitive(String name) : this.fromSource(name, null);
  Binder.raw(this.id, this._sourceName, this._location);

  String toString() {
    if (_sourceName == null) {
      return "syn$id";
    } else {
      return "$_sourceName$id";
    }
  }

  int get hashCode {
    int hash = 1;
    hash = hash * 13 + (_location == null ? 0 : _location.hashCode);
    hash = hash * 17 + id;
    hash = hash * 31 + (_sourceName == null ? 0 : _sourceName.hashCode);
    return hash;
  }
}
