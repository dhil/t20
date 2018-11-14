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

  Binder.fromSource(this._sourceName, this._location) : id = Gensym.freshInt();
  Binder.fresh() : this.fromSource(null, null);
  Binder.primitive(String name) : this.fromSource(name, null);
}
