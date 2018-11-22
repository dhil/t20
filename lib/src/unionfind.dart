// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// An implementation of the union-find algorithm based on an adaption of the
// Disjoint Sets data structure as detailed in [CLSR §21.2-3].

// An equivalence class is modelled as set of points.
class Point<A> {
  _Node<A> link;
  Point._(this.link);
}

abstract class _Node<A> {}

class _InfoNode<A> implements _Node<A> {
  // Number of elements in the equivalence class.
  int size;
  A data;
  _InfoNode(this.size, this.data);
}

class _LinkNode<A> implements _Node<A> {
  Point<A> point;
  _LinkNode(this.point);
}

// Creates an equivalence class containing only [data].
Point<A> singleton<A>(A data) {
  return new Point<A>._(new _InfoNode<A>(1, data));
}

// Returns the representative point of the equivalence class.
Point<A> representative<A>(Point<A> point) {
  if (point.link is _InfoNode<A>) {
    return point;
  } else {
    _LinkNode<A> node = point.link;
    Point<A> pointRepr = representative<A>(node.point);
    if (!identical(pointRepr, point)) {
      // Path compression.
      node.point = pointRepr;
    }
    return pointRepr;
  }
}

// Returns the representative data of the equivalence class.
A find<A>(Point<A> point) {
  if (point.link is _InfoNode<A>) {
    _InfoNode<A> node = point.link;
    return node.data;
  } else {
    _LinkNode<A> node = point.link;
    return find<A>(representative<A>(node.point));
  }
}

// Changes the representative data of the equivalence class.
void change<A>(Point<A> point, A data) {
  if (point.link is _InfoNode<A>) {
    _InfoNode<A> node = point.link;
    node.data = data;
  } else {
    _LinkNode<A> node = point.link;
    change<A>(representative(node.point), data);
  }
}

// Determines whether two points belong to the same equivalence class.
bool equivalent<A>(Point<A> point1, Point<A> point2) {
  return identical(representative(point1), representative(point2));
}

// Unites two equivalence classes.
void union<A>(Point<A> point1, Point<A> point2) {
  if (equivalent(point1, point2)) return;

  Point<A> point1Repr = representative(point1);
  Point<A> point2Repr = representative(point2);

  // The link of each representative point is guaranteed to be an instance of
  // [_InfoNode].
  _InfoNode<A> info1 = point1Repr.link;
  _InfoNode<A> info2 = point2Repr.link;

  if (info1.size >= info2.size) {
    point2.link = _LinkNode<A>(point1);
    info1.size += info2.size;
    info1.data = info2.data;
  } else {
    point1.link = _LinkNode<A>(point2);
    info2.size += info1.size;
  }
}
