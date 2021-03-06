// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' show VariableDeclaration;

import '../location.dart';
import '../utils.dart' show Gensym;

import 'ast.dart' show Datatype, Declaration, TopModule, KernelNode, T20Node;
import 'identifiable.dart';

class Binder implements Identifiable, KernelNode {
  TopModule get origin => (bindingOccurrence as T20Node)?.origin;
  Declaration bindingOccurrence;
  final String _sourceName;
  final Location _location;

  final int _ident;
  int get ident => _ident;
  int get intern => _sourceName?.hashCode ?? 0;

  // TODO introduce a subclass for typed binders.
  Datatype _type;
  void set type(Datatype type) => _type = type;
  Datatype get type => _type;

  Location get location => _location ?? Location.dummy();
  String get sourceName => _sourceName ?? "<synthetic>";

  Binder.fromSource(String sourceName, Location location)
      : this.raw(null, Gensym.freshInt(), sourceName, location, null);
  Binder.fresh() : this.fromSource(null, null);
  Binder.primitive(String name)
      : this.fromSource(name, null);
  Binder.raw(this.bindingOccurrence, this._ident, this._sourceName,
      this._location, this._type);
  Binder.refresh(Binder binder)
      : this.raw(binder.bindingOccurrence, Gensym.freshInt(), binder._sourceName,
            Location.dummy(), binder.type);

  String toString() {
    if (_sourceName == null) {
      return "#_$ident";
    } else {
      return "${_sourceName}_$ident";
    }
  }

  int get hashCode {
    int hash = 1;
    hash = hash * 13 + (_location == null ? 0 : _location.hashCode);
    hash = hash * 17 + ident;
    hash = hash * 31 + (_sourceName == null ? 0 : _sourceName.hashCode);
    return hash;
  }

  VariableDeclaration asKernelNode;
}
