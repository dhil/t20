// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This is a collection of utilities. One day it might be broken into several
// self-contained files.

library t20.utils;

import 'fp.dart';


class Gensym {
  static int _i = 0;
  static int _j = 0;
  static int freshInt() {
    return ++Gensym._i;
  }

  static int freshNegativeInt() {
    return --Gensym._j;
  }

  static String freshString([String prefix = null]) {
    if (prefix == null) prefix = "_";

    StringBuffer buffer = new StringBuffer(prefix);
    int suffix = Gensym.freshInt();
    buffer.write("_");
    buffer.write(suffix.toString());
    return buffer.toString();
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

  static String stringify<T>(String separator, List<T> elements, [String Function(T) convert]) {
    if (elements == null) return "null";
    if (convert == null) convert = (T x) => "$x";
    return elements.map(convert).join(separator);
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

  // Computes the multi-set differences xs \ ys and ys \ xs.
  static Pair<List<T>, List<T>> diff<T>(List<T> xs, List<T> ys, int Function(T, T) compare) {
    // Precondition `xs' and `ys' are sorted.
    Iterator<T> itxs = xs.iterator;
    Iterator<T> itys = ys.iterator;

    List<T> xsDelta = new List<T>(); // [ x \in xs | x \notin ys ].
    List<T> ysDelta = new List<T>(); // [ y \in ys | y \notin xs ].

    bool xsHasMore = itxs.moveNext();
    bool ysHasMore = itys.moveNext();

    while (xsHasMore && ysHasMore) {
      T x = itxs.current;
      T y = itys.current;
      int result = compare(x, y);
      if (result < 0) {
        // We have x < y, so x \notin ys
        xsDelta.add(x);
        xsHasMore = itxs.moveNext();
      } else if (result == 0) {
        // We have x = y, so x \in ys and y \in xs.
        xsHasMore = itxs.moveNext();
        ysHasMore = itys.moveNext();
      } else {
        // We have x > y, so y \notin xs.
        ysDelta.add(y);
        ysHasMore = itys.moveNext();
      }
    }

    // Any remaining elements in xs must be in the delta.
    while (xsHasMore) {
      xsDelta.add(itxs.current);
      xsHasMore = itxs.moveNext();
    }

    // Any remaining elements in ys must be in the delta.
    while (ysHasMore) {
      ysDelta.add(itys.current);
      ysHasMore = itys.moveNext();
    }

    return Pair<List<T>, List<T>>(xsDelta, ysDelta);
  }
}
