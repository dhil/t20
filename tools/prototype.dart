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

// Generic boilerplate.
abstract class List<A> {
  R accept<R>(ListVisitor<A, R> v);
}

class Cons<A> implements List<A> {
  A $1;
  List<A> $2;

  Cons(this.$1, this.$2);

  R accept<R>(ListVisitor<A, R> v) => v.visitCons(this);
}

class Nil<A> implements List<A> {
  R accept<R>(ListVisitor<A, R> v) => v.visitNil(this);
}

abstract class ListVisitor<A, R> {
  R visitCons(Cons<A> node);
  R visitNil(Nil<A> node);
}

abstract class ListMatchClosure<A, R> {
  ListMatchClosure();

  R cons(Cons<A> node);
  R nil(Nil<A> node);

  R defaultCase(List<A> node) => null;
}

class ListEliminator<A, R> implements ListVisitor<A, R> {
  ListMatchClosure<A, R> match;

  ListEliminator(this.match);

  R visitCons(Cons<A> node) {
    R result = match.cons(node) ?? match.defaultCase(node);
    if (result == null) {
      throw PatternMatchFailure();
    } else {
      return result;
    }
  }

  R visitNil(Nil<A> node) {
    R result = match.nil(node) ?? match.defaultCase(node);
    if (result == null) {
      throw PatternMatchFailure();
    } else {
      return result;
    }
  }
}

// Concrete boilerplate.
class ConcreteListMatchClosure extends ListMatchClosure<int, int> {
  final int y;
  ConcreteListMatchClosure(this.y) : super();

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
  ConcreteListMatchClosure2() : super();

  bool cons(Cons<int> node) => null;
  bool nil(Nil<int> node) => null;

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

void main() {
  int result = foo(41);
  print(result);
  bool result0 = bar(41);
  print(result0);
}
