// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import '../utils.dart' show Gensym;

import 'ast.dart' show TopModule;
import 'identifiable.dart';

class Binder implements Identifiable {
  TopModule origin;
  final String _sourceName;
  final Location _location;
  final int _ident;
  int get ident => _ident;
  int get intern => _sourceName?.hashCode ?? 0;

  Location get location => _location ?? Location.dummy();
  String get sourceName => _sourceName ?? "<synthetic>";

  Binder.fromSource(TopModule origin, String sourceName, Location location)
      : this.raw(origin, Gensym.freshInt(), sourceName, location);
  Binder.fresh(TopModule origin) : this.fromSource(origin, null, null);
  Binder.primitive(TopModule origin, String name)
      : this.fromSource(origin, name, null);
  Binder.raw(this.origin, this._ident, this._sourceName, this._location);

  String toString() {
    if (_sourceName == null) {
      return "syn$ident";
    } else {
      return "$_sourceName$ident";
    }
  }

  int get hashCode {
    int hash = 1;
    hash = hash * 13 + (_location == null ? 0 : _location.hashCode);
    hash = hash * 17 + ident;
    hash = hash * 31 + (_sourceName == null ? 0 : _sourceName.hashCode);
    return hash;
  }
}
