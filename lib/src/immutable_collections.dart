// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:built_collection/built_collection.dart' as built;

// Immutable map.
abstract class ImmutableMap<K, V> {
  factory ImmutableMap.empty() = BuiltMap<K, V>.empty; //_NaiveImmutableMap<K, V>.empty;
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

  ImmutableMap<K, T> map<T>(T Function(K, V) mapper);
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

  _NaiveImmutableMap<K, T> map<T>(T Function(K, V) mapper) {
    return _NaiveImmutableMap.using(_underlying
        .map((K key, V value) => MapEntry<K, T>(key, mapper(key, value))));
  }

  V lookup(K key) => _underlying[key];
}

// Immutable map based on BuiltMap from the built_collection library.
class BuiltMap<K, V> implements ImmutableMap<K, V> {
  // Underlying map.
  final built.BuiltMap<K, V> _map;

  BuiltMap.empty() : _map = new built.BuiltMap<K, V>(<K, V>{});
  BuiltMap._(this._map);

  bool containsKey(K key) => _map.containsKey(key);
  bool get isEmpty => _map.isEmpty;
  int get size => _map.length;
  Iterable<MapEntry<K, V>> get entries => _map.entries;

  ImmutableMap<K, T> map<T>(T Function(K, V) f) {
    built.BuiltMap<K, T> map =
        _map.map((K key, V value) => MapEntry<K, T>(key, f(key, value)));
    return BuiltMap._(map);
  }

  ImmutableMap<K, V> put(K key, V value) {
    built.MapBuilder<K, V> builder = _map.toBuilder();
    builder[key] = value;
    return BuiltMap._(builder.build());
  }

  V lookup(K key) => _map[key];

  ImmutableMap<K, V> remove(K key) {
    built.MapBuilder<K, V> builder = _map.toBuilder();
    builder.remove(key);
    return BuiltMap._(builder.build());
  }

  // For common keys, the values in other takes precedence.
  ImmutableMap<K, V> union(ImmutableMap<K, V> other) {
    if (other is! BuiltMap<K, V>) {
      throw "expected 'other' to be an instance of 'BuiltMap'.";
    }
    built.MapBuilder<K, V> thisBuilder = _map.toBuilder();
    Map<K, V> otherMap = (other as BuiltMap<K, V>)._map.toMap();

    thisBuilder.addAll(otherMap);
    return BuiltMap<K, V>._(thisBuilder.build());
  }
}

// Immutable list.
typedef Mapper<S, T> = T Function(S);

abstract class ImmutableList<T> {
  factory ImmutableList.empty() = _Nil<T>;
  factory ImmutableList.singleton(T x) = _Cons<T>.singleton;
  factory ImmutableList.of(List<T> xs) {
    ImmutableList<T> ys = ImmutableList<T>.empty();
    for (int i = xs.length - 1; 0 <= i; i--) {
      ys = ys.cons(xs[i]);
    }
    return ys;
  }

  T get head;
  ImmutableList<T> get tail;
  ImmutableList<T> cons(T x);
  ImmutableList<T> concat(ImmutableList<T> ys);
  ImmutableList<R> map<R>(Mapper<T, R> fn);
  ImmutableList<R> reverseMap<R>(Mapper<T, R> fn);
  ImmutableList<T> reverse();
  ImmutableList<T> intersperse(T sep);
  ImmutableList<T> where(bool Function(T) predicate);
  A foldl<A>(A Function(A, T) fn, A z);
  A foldr<A>(A Function(T, A) fn, A z);

  List<T> toList({bool growable: true});

  bool get isEmpty;
  int get length;
}

class _ConsIterator<T> implements Iterator<T> {
  ImmutableList<T> _xs;
  T current;

  _ConsIterator(this._xs);

  bool moveNext() {
    if (_xs.isEmpty) return false;
    current = _xs.head;
    _xs = _xs.tail;
    return true;
  }
}

class _Cons<T> implements ImmutableList<T> {
  final int _length;
  int get length => _length;
  bool get isEmpty => false;

  final T _data;
  final ImmutableList<T> _tail;

  _Cons(this._data, ImmutableList<T> tail)
      : _length = tail.length + 1,
        this._tail = tail;

  _Cons.singleton(this._data)
      : this._length = 1,
        this._tail = ImmutableList<T>.empty();

  T get head => _data;
  ImmutableList<T> get tail => _tail;

  ImmutableList<T> cons(T x) {
    return _Cons(x, this);
  }

  ImmutableList<T> concat(ImmutableList<T> ys) {
    return foldr<ImmutableList<T>>(
        (T x, ImmutableList<T> ys) => ys.cons(x), ys);
  }

  ImmutableList<R> map<R>(Mapper<T, R> fn) {
    return foldr<ImmutableList<R>>(
        (T x, ImmutableList<R> ys) => ys.cons(fn(x)), ImmutableList<R>.empty());
  }

  static ImmutableList<T> _consl<T>(ImmutableList<T> tail, T x) {
    return tail.cons(x);
  }

  ImmutableList<R> reverseMap<R>(Mapper<T, R> fn) {
    return foldl<ImmutableList<R>>(
        (ImmutableList<R> ys, T x) => ys.cons(fn(x)), ImmutableList<R>.empty());
  }

  ImmutableList<T> reverse() {
    return foldl<ImmutableList<T>>(_consl, ImmutableList<T>.empty());
  }

  ImmutableList<T> where(bool Function(T) predicate) {
    return foldr<ImmutableList<T>>((T x, ImmutableList<T> xs) {
      if (predicate(x))
        return xs.cons(x);
      else
        return xs;
    }, ImmutableList<T>.empty());
  }

  ImmutableList<T> intersperse(T sep) {
    return foldr((T x, ImmutableList<T> xs) => xs.cons(sep).cons(x),
        ImmutableList<T>.empty());
  }

  A foldl<A>(A Function(A, T) fn, A z) {
    ImmutableList<T> xs = this;
    final int len = length;
    A acc = z;
    for (int i = 0; i < len; i++) {
      acc = fn(acc, xs.head);
      xs = xs.tail;
    }
    return acc;
  }

  A foldr<A>(A Function(T, A) fn, A z) {
    List<T> xs = toList(growable: false);
    A acc = z;
    for (int i = length - 1; 0 <= i; i--) {
      acc = fn(xs[i], acc);
    }
    return acc;
  }

  List<T> toList({bool growable: true}) {
    ImmutableList<T> xs = this;
    List<T> ys =
        growable ? (new List<T>()..length = length) : new List<T>(length);
    int len = length;
    for (int i = 0; i < len; i++) {
      ys[i] = xs.head;
      xs = xs.tail;
    }
    return ys;
  }

  Iterator<T> get iterator => _ConsIterator<T>(this);

  String toString() {
    final StringBuffer buf = new StringBuffer()..write("[");
    final int len = length;
    ImmutableList<T> xs = this;
    for (int i = 0; i < len; i++) {
      if (i + 1 == len) {
        buf.write(xs.head);
      } else {
        buf.write("${xs.head}, ");
      }
      xs = xs.tail;
    }
    buf.write("]");
    return buf.toString();
  }
}

class _NilIterator<T> implements Iterator<T> {
  bool moveNext() => false;
  T get current => null;
}

class _Nil<T> implements ImmutableList<T> {
  int get length => 0;
  bool get isEmpty => true;
  T get head => throw "head of empty.";
  ImmutableList<T> get tail => throw "tail of empty";

  List<T> toList({bool growable: true}) => growable ? new List<T>(0) : <T>[];

  ImmutableList<T> cons(T x) => _Cons(x, this);
  ImmutableList<R> map<R>(Mapper<T, R> _) => ImmutableList<R>.empty();
  ImmutableList<R> reverseMap<R>(Mapper<T, R> fn) => map<R>(fn);
  ImmutableList<T> reverse() => this;
  ImmutableList<T> intersperse(T _) => this;
  ImmutableList<T> where(bool Function(T) _) {
    return this;
  }

  ImmutableList<T> concat(ImmutableList<T> ys) => ys;

  A foldl<A>(A Function(A, T) _, A z) => z;
  A foldr<A>(A Function(T, A) _, A z) => z;
  Iterator<T> get iterator => _NilIterator<T>();

  String toString() {
    return "[]";
  }
}

class DoublyList<T> {
  final T element;
  final ImmutableList<T> _pred;
  final ImmutableList<T> _succ;

  bool get isEmpty => _pred.isEmpty && _succ.isEmpty;
  bool get isInitial => _pred.isEmpty;
  bool get isFinal => _succ.isEmpty;

  DoublyList._(this._pred, this.element, this._succ);
  factory DoublyList.singleton(T element) {
    ImmutableList<T> nil = ImmutableList<T>.empty();
    return DoublyList<T>._(nil, element, nil);
  }
  factory DoublyList.empty() {
    ImmutableList<T> nil = ImmutableList<T>.empty();
    return DoublyList._(nil, null, nil);
  }

  DoublyList<T> get predecessor {
    if (isInitial) return this;

    T prevElement = _pred.head;
    return DoublyList<T>._(_pred.tail, prevElement, _succ.cons(element));
  }

  DoublyList<T> get successor {
    if (isFinal) return this;

    T nextElement = _succ.head;
    return DoublyList<T>._(_pred.cons(element), nextElement, _succ.tail);
  }

  DoublyList<T> insertAfter(T newElement) {
    if (isEmpty) {
      return DoublyList<T>._(_pred, newElement, _succ);
    } else {
      return DoublyList<T>._(_pred, newElement, _succ.cons(element));
    }
  }

  DoublyList<T> insertBefore(T newElement) {
    if (isEmpty) {
      return DoublyList<T>._(_pred, newElement, _succ);
    } else {
      return DoublyList<T>._(_pred.cons(newElement), element, _succ);
    }
  }
}
