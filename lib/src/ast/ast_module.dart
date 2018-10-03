// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import 'ast_types.dart';
import 'ast_expressions.dart';

//
// Module / top-level language.
//
abstract class ModuleVisitor<T> {
  T visitDatatype(DatatypeDefinition def);
  T visitFunction(FunctionDefinition def);
  T visitInclude(Include include);
  T visitValue(ValueDefinition def);
}

abstract class Module {
  T visit<T>(ModuleVisitor<T> v);
}

class ValueDefinition implements Module {
  String name;
  Expression body;
  Location location;

  ValueDefinition(this.name, this.body, this.location);
  T visit<T>(ModuleVisitor<T> v) {
    return v.visitValue(this);
  }
}

class FunctionDefinition implements Module {
  String name;
  List<Object> parameters;
  Expression body;
  Location location;

  FunctionDefinition(this.name, this.parameters, this.body, this.location);

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitFunction(this);
  }
}

class DatatypeDefinition implements Module {
  String name;
  List<Object> typeParameters;
  List<Object> constructors;
  Location location;

  DatatypeDefinition(
      this.name, this.typeParameters, this.constructors, this.location);

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitDatatype(this);
  }
}

class Include implements Module {
  String module;
  Location location;

  Include(this.module, this.location);

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitInclude(this);
  }
}
