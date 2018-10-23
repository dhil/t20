// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

// Immutable map.
abstract class ImmutableMap<K, V> {
  factory ImmutableMap.empty() = _NaiveImmutableMap.empty<K, V>;
  factory ImmutableMap.of(Map<K, V> mutableMap) {
    ImmutableMap<K, V> map = ImmutableMap<K, V>.empty();
    for (MapEntry<K, V> entry in mutableMap.entries) {
      map = map.put(entry.key, entry.value);
    }
    return map;
  }

  bool containsKey(K key);
  bool get isEmpty;
  int get size;
  Iterable<MapEntry<K, V>> get entries;

  ImmutableMap<K, V> put(K key, V value);
  V lookup(K key);
  ImmutableMap<K, V> remove(K key);
  // For common keys, the values in other takes precedence.
  ImmutableMap<K, V> union(ImmutableMap<K, V> other);
}

// TODO the current implementation is inefficient and is only intended to serve
// as a prototype. It should be replaced by an efficient version based on
// red-black trees.
class _NaiveImmutableMap<K, V> implements ImmutableMap<K, V> {
  final Map<K, V> _underlying;

  _NaiveImmutableMap.empty() : _underlying = new Map<K, V>();
  _NaiveImmutableMap.using(this._underlying);

  int get size => _underlying.length;
  bool get isEmpty => _underlying.isEmpty;
  bool containsKey(K key) => _underlying.containsKey(key);
  Iterable<MapEntry<K, V>> get entries => _underlying.entries;

  _NaiveImmutableMap<K, V> put(K key, V value) {
    Map<K, V> copy = Map<K, V>.of(_underlying);
    copy[key] = value;
    return _NaiveImmutableMap.using(copy);
  }

  _NaiveImmutableMap<K, V> remove(K key) {
    Map<K, V> copy = Map<K, V>.of(_underlying);
    copy.remove(key);
    return _NaiveImmutableMap.using(copy);
  }

  _NaiveImmutableMap<K, V> union(ImmutableMap<K, V> other) {
    Map<K, V> copy = Map<K, V>.of(_underlying);
    for (MapEntry<K, V> entry in other.entries) {
      copy[entry.key] = entry.value;
    }
    return _NaiveImmutableMap.using(copy);
  }

  V lookup(K key) => _underlying[key];
}
