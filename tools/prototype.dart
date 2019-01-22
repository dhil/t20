/*
Example:

(define-datatype (List 'a)
   [cons 'a (List 'a)]
   [nil])

(: foo (-> Int Int))
(define (foo y)
  (match (cons 1 nil)
  [(cons x xs) (+ x y)]
  [(nil)       y]))

(: bar (-> Int Bool))
(define (bar y)
  (match (cons 1 nil)
  [x #t]))
 */

class PatternMatchFailure {}

class Obvious {
  final int id;
  Obvious(this.id);
}

class T20Error {
  Object error;
  T20Error(this.error);

  String toString() => error.toString();
}

// Generic boilerplate.
abstract class List<A> {
  R accept<R>(ListVisitor<A, R> v);
}

class Cons<A> extends List<A> {
  A $1;
  List<A> $2;

  Cons(this.$1, this.$2);

  R accept<R>(ListVisitor<A, R> v) => v.visitCons(this);

  String toString() {
    String head = $1.toString();
    String tail = $2.toString();
    return "Cons($head, $tail)";
  }
}

class Nil<A> implements List<A> {
  R accept<R>(ListVisitor<A, R> v) => v.visitNil(this);

  String toString() => "Nil";
}

abstract class ListVisitor<A, R> {
  R visitCons(Cons<A> node);
  R visitNil(Nil<A> node);
}

abstract class ListMatchClosure<A, R> {
  final int id;
  ListMatchClosure(this.id);

  R cons(Cons<A> node) => throw PatternMatchFailure();
  R nil(Nil<A> node) => throw PatternMatchFailure();

  R defaultCase(List<A> node) => throw PatternMatchFailure();
}

class ListEliminator<A, R> implements ListVisitor<A, R> {
  ListMatchClosure<A, R> match;

  ListEliminator(this.match);

  R visitCons(Cons<A> node) {
    R result;
    try {
      result = match.cons(node);
    } on PatternMatchFailure catch (e) {
      try {
        result = match.defaultCase(node);
      } on PatternMatchFailure {
        throw T20Error(e);
      } on Obvious catch (e) {
        if (e.id == match.id) {
          rethrow;
        } else {
          throw T20Error(e);
        }
      } catch (e) {
        throw T20Error(e);
      }
    } catch (e) {
      throw T20Error(e);
    }

    return result;
  }

  R visitNil(Nil<A> node) {
    R result;
    try {
      result = match.nil(node);
    } on PatternMatchFailure catch (e) {
      try {
        result = match.defaultCase(node);
      } on PatternMatchFailure {
        throw T20Error(e);
      } on Obvious catch (e) {
        if (e.id == match.id) {
          rethrow;
        } else {
          throw T20Error(e);
        }
      } catch (e) {
        throw T20Error(e);
      }
    } catch (e) {
      throw T20Error(e);
    }

    return result;
  }
}

// Concrete boilerplate.
class ConcreteListMatchClosure extends ListMatchClosure<int, int> {
  final int y;
  ConcreteListMatchClosure(this.y) : super(34432);

  int cons(Cons<int> node) {
    int x = node.$1;
    List<int> xs = node.$2;
    return x + y;
  }

  int nil(Nil<int> node) {
    return y;
  }
}

class ConcreteListMatchClosure2 extends ListMatchClosure<int, bool> {
  ConcreteListMatchClosure2() : super(32445);

  bool defaultCase(List<int> x) => true;
}

int foo(int y) {
  List<int> scrutinee = Cons(1, Nil());
  int result = scrutinee
      .accept<int>(ListEliminator<int, int>(ConcreteListMatchClosure(y)));
  return result;
}

bool bar(int y) {
  List<int> scrutinee = Cons(1, Nil());
  bool result = scrutinee
      .accept<bool>(ListEliminator<int, bool>(ConcreteListMatchClosure2()));
  return result;
}

// List folds.
class ListFoldRight<A, R> extends ListVisitor<A, R> {
  R Function(A, R) f;
  R z;

  ListFoldRight(this.f, this.z);

  R visitCons(Cons<A> node) {
    R acc = node.$2.accept<R>(this);
    acc = f(node.$1, acc);
    return acc;
  }

  R visitNil(Nil<A> node) => z;
}

class ListFoldLeft<A, R> extends ListVisitor<A, R> {
  R Function(R, A) f;
  R acc;

  ListFoldLeft(this.f, this.acc);

  R visitCons(Cons<A> node) {
    acc = f(acc, node.$1);
    return node.$2.accept<R>(this);
  }

  R visitNil(Nil<A> node) => acc;
}

int length<A>(int acc, A _) => acc + 1;
int length1<A>(A _, int acc) => acc + 1;

List<A> cons<A>(A head, List<A> tail) => Cons<A>(head, tail);

// List transform.
class TransformList<A, R> extends ListVisitor<A, List<R>> {
  List<R> Function(List<A>) f;
  R z;

  TransformList(this.f, this.z);

  List<R> visitCons(Cons<A> node) {
    List<R> result;
    try {
      result = f(node);
    } on Obvious {
      result = Cons<R>(z, node.$2.accept<List<R>>(this));
    }
    return result;
  }

  List<R> visitNil(Nil<A> node) {
    List<R> result;
    try {
      result = f(node);
    } on Obvious {
      result = Nil<R>();
    }
    return result;
  }
}

class ListMatchClosure3<A> extends ListMatchClosure<A, List<int>> {
  ListMatchClosure3() : super(555);

  List<int> nil(Nil<A> _) => Cons<int>(1, Nil<int>());

  List<int> defaultCase(List<A> _) => throw Obvious(this.id);
}

List<int> transformList<A>(List<A> xs) =>
    xs.accept<List<int>>(ListEliminator(ListMatchClosure3()));

void main() {
  int result = foo(41);
  print(result);
  bool result0 = bar(41);
  print(result0);
  List<int> xs = Cons(1, Cons(2, Cons(3, Nil())));
  print(xs.accept<int>(ListFoldRight<int, int>(length1, 0)));
  print(xs.accept<int>(ListFoldLeft<int, int>(length, 0)));
  print("$xs");
  print(xs.accept<List<int>>(ListFoldLeft<int, List<int>>(
      (List<int> acc, int head) => cons<int>(head, acc), Nil<int>())));

  List<int> ys = xs.accept<List<int>>(TransformList<int, int>(transformList, 0));
  print("$ys");
}
