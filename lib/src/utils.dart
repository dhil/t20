// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This is a collection of utilities. One day it might be broken into several
// self-contained files.

library t20.utils;

import 'dart:collection';

import 'fp.dart';


class Gensym {
  static int _i = 0;
  static int freshInt() {
    return ++Gensym._i;
  }

  static String freshString([String prefix = null]) {
    if (prefix != null) {
      StringBuffer buffer = new StringBuffer(prefix);
      int suffix = Gensym.freshInt();
      buffer.write("_");
      buffer.write(suffix.toString());
      return buffer.toString();
    }
  }
}

class ListUtils {
  static List<T> intersperse<T>(T separator, List<T> elements) {
    assert(elements != null);
    if (elements.length == 0) return elements;

    final List<T> xs = new List<T>();
    final int ubound = elements.length - 1;
    for (int i = 0; i < ubound; i++) {
      xs.add(elements[i]);
      xs.add(separator);
    }
    xs.add(elements.last);
    return xs;
  }

  static List<T> insertBeforeLast<T>(T elem, List<T> elements) {
    assert(elements != null);
    if (elements.length == 0) {
      elements.add(elem);
      return elements;
    }

    elements.insert(elements.length - 1, elem);
    return elements;
  }

  static Map<A,B> assocToMap<A, B>(List<Pair<A, B>> assocList) {
    assert(assocList != null);
    Map<A, B> map = Map<A, B>();
    for (int i = 0; i < assocList.length; i++) {
      Pair<A, B> pair = assocList[i];
      map[pair.$1] = pair.$2;
    }
    return map;
  }
}
