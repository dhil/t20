// Immutable list data structure.

import 'dart:collection';

typedef Mapper<S, T> = T Function(S);

abstract class ImmList<T> implements Iterable<T> {
  factory ImmList.empty() = _Nil<T>;
  factory ImmList.singleton(T x) = _Cons<T>.singleton;
  factory ImmList.of(List<T> xs) {
    ImmList<T> ys = ImmList<T>.empty();
    for (int i = xs.length - 1; 0 <= i; i--) {
      ys = ys.cons(xs[i]);
    }
    return ys;
  }

  T get head;
  ImmList<T> get tail;
  ImmList<T> cons(T x);
  ImmList<T> concat(ImmList<T> ys);
  ImmList<R> map<R>(Mapper<T, R> fn);
  ImmList<R> reverseMap<R>(Mapper<T, R> fn);
  ImmList<T> reverse();
  ImmList<T> intersperse(T sep);
  ImmList<T> where(bool Function(T) predicate);
  A foldl<A>(A Function(A, T) fn, A z);
  A foldr<A>(A Function(T, A) fn, A z);

  List<T> toList({bool growable: true});

  bool get isEmpty;
  int get length;
}

class _ConsIterator<T> implements Iterator<T> {
  ImmList<T> _xs;
  T current;

  _ConsIterator(this._xs);

  bool moveNext() {
    if (_xs.isEmpty) return false;
    current = _xs.head;
    _xs = _xs.tail;
    return true;
  }
}

class _Cons<T> with IterableMixin<T> implements ImmList<T> {
  final int _length;
  int get length => _length;
  bool get isEmpty => false;

  final T _data;
  final ImmList<T> _tail;

  _Cons(this._data, ImmList<T> tail)
      : _length = tail.length + 1,
        this._tail = tail;

  _Cons.singleton(this._data)
      : this._length = 1,
        this._tail = ImmList<T>.empty();

  T get head => _data;
  ImmList<T> get tail => _tail;

  ImmList<T> cons(T x) {
    return _Cons(x, this);
  }

  ImmList<T> concat(ImmList<T> ys) {
    return foldr<ImmList<T>>((T x, ImmList<T> ys) => ys.cons(x), ys);
  }

  ImmList<R> map<R>(Mapper<T, R> fn) {
    return foldr<ImmList<R>>(
        (T x, ImmList<R> ys) => ys.cons(fn(x)), ImmList<R>.empty());
  }

  static ImmList<T> _consl<T>(ImmList<T> tail, T x) {
    return tail.cons(x);
  }

  ImmList<R> reverseMap<R>(Mapper<T, R> fn) {
    return foldl<ImmList<R>>(
        (ImmList<R> ys, T x) => ys.cons(fn(x)), ImmList<R>.empty());
  }

  ImmList<T> reverse() {
    return foldl<ImmList<T>>(_consl, ImmList<T>.empty());
  }

  ImmList<T> where(bool Function(T) predicate) {
    return foldr<ImmList<T>>((T x, ImmList<T> xs) {
      if (predicate(x))
        return xs.cons(x);
      else
        return xs;
    }, ImmList<T>.empty());
  }

  ImmList<T> intersperse(T sep) {
    return foldr(
        (T x, ImmList<T> xs) => xs.cons(sep).cons(x), ImmList<T>.empty());
  }

  A foldl<A>(A Function(A, T) fn, A z) {
    ImmList<T> xs = this;
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
    ImmList<T> xs = this;
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
    ImmList<T> xs = this;
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
    // ImmList<String> xs = this.map<String>((T x) => x.toString()).intersperse(", ");
  }
}

class _NilIterator<T> implements Iterator<T> {
  bool moveNext() => false;
  T get current => null;
}

class _Nil<T> with IterableMixin<T> implements ImmList<T> {
  int get length => 0;
  bool get isEmpty => true;
  T get head => throw "head of empty.";
  ImmList<T> get tail => throw "tail of empty";

  List<T> toList({bool growable: true}) => growable ? new List<T>(0) : <T>[];

  ImmList<T> cons(T x) => _Cons(x, this);

  ImmList<R> map<R>(Mapper<T, R> _) => ImmList<R>.empty();

  ImmList<R> reverseMap<R>(Mapper<T, R> fn) => map<R>(fn);

  ImmList<T> reverse() => this;

  ImmList<T> intersperse(T _) => this;

  ImmList<T> where(bool Function(T) _) {
    return this;
  }

  ImmList<T> concat(ImmList<T> ys) => ys;

  A foldl<A>(A Function(A, T) _, A z) => z;

  A foldr<A>(A Function(T, A) _, A z) => z;

  Iterator<T> get iterator => _NilIterator<T>();

  String toString() {
    return "[]";
  }
}

void main() {
  ImmList<int> xs = ImmList<int>.of(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  print("xs = ${xs.reverse().toString()}");
  print("xs = ${xs.toString()}");
  ImmList<int> ys = xs.where((x) => x == 10);
  print("xs = ${xs.toString()}");
  print("ys = ${ys.toString()}");
  // ImmList<int> ys = xs.tail;
  // print("xs = ${stringOfList<int>(xs.toList())}");
  // print("ys = ${stringOfList<int>(ys.toList())}");
  // ImmList<int> zs = xs.concat(ys);
  // print("xs = ${stringOfList<int>(xs.toList())}");
  // print("ys = ${stringOfList<int>(ys.toList())}");
  // print("zs = ${stringOfList<int>(zs.toList())}");
  // ImmList<String> ys0 = ys.map((_) => "A");
  // print("ys  = ${stringOfList<int>(ys.toList())}");
  // print("ys0 = ${stringOfList<String>(ys0.toList())}");

  // for (int z in zs) {
  //   print("$z");
  // }
}
