// I'm using PCF as a prototype language for assessing whether object algebras
// are a worthwhile implementation strategy for the IR of T20.

import 'dart:collection';

// A product type.
class Pair<A, B> {
  final A fst;
  final B snd;

  Pair(this.fst, this.snd);

  A get $1 => fst;
  B get $2 => snd;
}

// Multi-sorted algebra.
abstract class TermAlgebra<Exp, Type> {
  Exp intlit(int x);
  Exp var_(String name);

  Exp lam(Pair<String, Type> binder, Exp body);
  Exp app(Exp fn, Exp arg);

  Exp pair(Exp a, Exp b);
  // Exp fst(Exp e);
  // Exp snd(Exp e);
}

// Single-sorted algebra.
abstract class TypeAlgebra<T> {
  T arrow(T domain, T codomain);
  T integer();
  T product(T a, T b);
  T unit();
}

// A "pretty" printer object algebra.
class TermPrinter extends TermAlgebra<String, String> {
  String intlit(int x) => x.toString();
  String var_(String name) => name;

  String lam(Pair<String, String> binder, String body) {
    return "(\\${binder.fst} : ${binder.snd}. $body)";
  }

  String app(String fn, String arg) => "($fn $arg)";

  String pair(String a, String b) => "($a, $b)";
  // String fst(String e) => "(fst $e)";
  // String snd(String e) => "(snd $e)";
}

class TypePrinter extends TypeAlgebra<String> {
  String arrow(String domain, String codomain) => "$domain -> $codomain";
  String integer() => "Int";
  String product(String a, String b) => "($a * $b)";
  String unit() => "()";
}

// An "untyped evaluation" object algebra.
abstract class Value {}

class Closure<Exp> implements Value {
  final Map<String, Value> env;
  final String binder;
  final Exp comp;

  Closure(this.env, this.binder, this.comp);

  String toString() {
    return "<closure>";
  }
}

class IntLit implements Value {
  final int n;
  IntLit(this.n);

  String toString() {
    return n.toString();
  }
}

class Unit implements Value {
  String toString() {
    return "()";
  }
}

class VPair extends Pair<Value, Value> implements Value {
  VPair(Value a, Value b) : super(a, b);

  String toString() {
    return "($fst, $snd)";
  }
}

class Prim implements Value {
  final String name;
  Prim(this.name);

  String toString() {
    return "<primitive $name>";
  }
}

abstract class Evaluable {
  Value eval(Map<String, Value> env);
}

class EvaluableInt extends Evaluable {
  final int x;
  EvaluableInt(this.x);

  Value eval(Map<String, Value> _) => IntLit(x);
}

class EvaluableVar extends Evaluable {
  final String name;

  EvaluableVar(this.name);

  Value eval(Map<String, Value> env) {
    if (env.containsKey(name)) {
      return env[name];
    } else {
      throw "unbound variable $name";
    }
  }
}

class EvaluableLam extends Evaluable {
  final String binder;
  final Evaluable body;
  EvaluableLam(this.binder, this.body);

  Value eval(Map<String, Value> env) {
    Map<String, Value> env0 = Map<String, Value>.of(env);
    return Closure(env0, binder, body);
  }
}

class EvaluableApp extends Evaluable {
  final Evaluable fn;
  final Evaluable arg;

  EvaluableApp(this.fn, this.arg);

  Value eval(Map<String, Value> env) {
    Value fval = fn.eval(env);
    Value argval = arg.eval(env);
    if (fval is Prim) {
      Prim v = fval;
      switch (v.name) {
        case "_add":
          return _add(argval);
        case "_fst":
          return _fst(argval);
        case "_snd":
          return _snd(argval);
        case "_println":
          return _println(argval);
        default:
          throw "primitive error.";
      }
    }

    return call(fval, argval);
  }

  Value call(Value fval, Value argval) {
    if (fval is Closure) {
      Closure clo = fval;
      Map<String, Value> fenv = clo.env;
      fenv[clo.binder] = argval;
      return clo.comp.eval(fenv);
    } else {
      throw "evaluation error.";
    }
  }

  Value _add(Value argval) {
    if (argval is VPair) {
      if (argval.$1 is IntLit && argval.$2 is IntLit) {
        IntLit x = argval.$1 as IntLit;
        IntLit y = argval.$2 as IntLit;
        return IntLit(x.n + y.n);
      } else {
        throw "type error.";
      }
    } else {
      throw "evaluation error (argument is not a pair).";
    }
  }

  Value _fst(Value argval) {
    throw "not yet implemented.";
  }

  Value _snd(Value argval) {
    throw "not yet implemented.";
  }

  Value _println(Value argval) {
    print("$argval");
    return Unit();
  }
}

class EvaluablePair extends Evaluable {
  final Evaluable fst;
  final Evaluable snd;

  EvaluablePair(this.fst, this.snd);

  Value eval(Map<String, Value> env) =>
      VPair(fst.eval(env), this.snd.eval(env));
}

// Anonymous objects would significant reduce the required boilerplate.
class TermEval extends TermAlgebra<Evaluable, Null> {
  Evaluable intlit(int x) => EvaluableInt(x);
  Evaluable var_(String name) => EvaluableVar(name);

  Evaluable lam(Pair<String, Null> binder, Evaluable body) =>
      EvaluableLam(binder.$1, body);
  Evaluable app(Evaluable fn, Evaluable arg) => EvaluableApp(fn, arg);
  Evaluable pair(Evaluable a, Evaluable b) => EvaluablePair(a, b);
}

class NullAlgebra extends TypeAlgebra<Null> {
  Null arrow(Null domain, Null codomain) => null;
  Null integer() => null;
  Null unit() => null;
  Null product(Null a, Null b) => null;
}

// Examples.
Exp identity<Exp, Type>(TermAlgebra<Exp, Type> tm, TypeAlgebra<Type> ty) {
  return tm.lam(Pair("x", ty.integer()), tm.var_("x"));
}

Exp add<Exp, Type>(TermAlgebra<Exp, Type> tm, TypeAlgebra<Type> ty) {
  return tm.lam(Pair("x", ty.product(ty.integer(), ty.integer())),
      tm.app(tm.var_("_add"), tm.var_("x")));
}

Exp forty<Exp, Type>(TermAlgebra<Exp, Type> tm) {
  return tm.intlit(40);
}

Exp two<Exp, Type>(TermAlgebra<Exp, Type> tm) {
  return tm.intlit(2);
}

Exp println<Exp, Type>(TermAlgebra<Exp, Type> tm, TypeAlgebra<Type> ty) {
  return tm.lam(
      Pair("x", ty.integer()), tm.app(tm.var_("_println"), tm.var_("x")));
}

Exp example0<Exp, Type>(TermAlgebra<Exp, Type> tm, TypeAlgebra<Type> ty) {
  return tm.app(
      println(tm, ty),
      tm.app(
          add(tm, ty), tm.pair(forty(tm), tm.app(identity(tm, ty), two(tm)))));
}

void main() {
  String pretty = example0(new TermPrinter(), new TypePrinter());
  print("$pretty");
  Evaluable val = example0(new TermEval(), new NullAlgebra());
  Map<String, Value> initialEnv = new Map<String, Value>();
  initialEnv["_println"] = Prim("_println");
  initialEnv["_add"] = Prim("_add");
  print("${val.eval(initialEnv)}");
}
