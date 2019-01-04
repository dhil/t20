(load "datatype.ss")

(define dart-type? (lambda (_) #t))

(define-datatype Expression expr?
  ;; Pure expressions without subexpressions
  [SymbolLiteral (value string?)]
  [TypeLiteral (type dart-type?)]
  [ThisExpression]
  [StringLiteral (value string?)]
  [IntLiteral (value integer?)]
  [DoubleLiteral (value real?)]
  [BoolLiteral (value boolean?)]
  [NullLiteral]
  ;; Impure expressions without subexpressions
  [InvalidExpression (message string?)]
  [SuperPropertyGet (name string?)]
  [StaticGet (name string?)]
  [Rethrow]
  ;; Pure if final
  [VariableGet (is-final boolean?) (name string?)]
  ;; Unary expressions
  [VariableSet (name string?) (value expr?)]
  [PropertyGet (receiver expr?) (name string?)]
  [DirectPropertyGet (receiver expr?)]
  [SuperPropertySet (name string?) (value expr?)]
  [StaticSet (name string?) (value expr?)]
  [Not (operand expr?)]
  [IsExpression (operand expr?) (type dart-type?)]
  [AsExpression (operand expr?) (type dart-type?)]
  [Throw (expression expr?)]
  ;; Binary expressions
  [PropertySet (receiver expr?) (name string?) (value expr?)]
  [DirectPropertySet (receiver expr?) (value expr?)]
  ;; Invocations
  [MethodInvocation (receiver expr?) (name string?)
    (arguments (list-of expr?))]
  ;; Others
  [ConditionalExpression (e0 expr?) (e1 expr?) (e2 expr?)])

(define-datatype Statement stmt?
  [ExpressionStatement (expression expr?)]
  [VariableDeclaration (name string?) (initializer expr?)]
  [Block (statements (list-of stmt?))]
  [IfStatement (condition expr?) (then stmt?) (otherwise stmt?)])

(define (transform-expr expr)
  (cases Expression expr
    ;; Pure expressions without subexpressions
    [SymbolLiteral (v)
      (values expr '() #f)]
    ;; Impure expressions without subexpressions
    [InvalidExpression (m)
      (values expr '() #f)]
    ;; Pure if final
    [VariableGet (is-final x)
      (values expr '() #f)]
    ;; Unary expressions
    [VariableSet (x e)
      (let-values ([(e^ stmts has-await) (transform-expr e)])
        (values (VariableSet x e^) stmts has-await))]
    ;; Binary expressions
    [PropertySet (e0 p e1)
      (let-values ([(e1^ stmts1 has-await1) (transform-expr value)]
                   [(e0^ stmts0 has-await0)
                    (if has-await1 (transform-expr+ e0) (transform-expr e0))])
        (values
          (PropertySet e0^ p e1^)
          (append stmts1 stmts0)
          (or has-await0 has-await1)))]
    [MethodInvocation (e m e*)
      (let-values ([(e^* stmts1 has-await1) (transform-expr* e*)]
                   [(e^ stmts0 has-await0)
                    (if has-await1 (transform-expr+ e0) (transform-expr e0))])
        (values
          (MethodInvocation e^ m e^*)
          (append stmts1 stmts0)
          (or has-await0 has-await1)))]
    [ConditionalExpression (e0 e1 e2)
      (let-values ([(e2^ stmts2 has-await2) (transform-expr e2)]
                   [(e1^ stmts1 has-await1) (transform-expr e1)]
                   [(e0^ stmts0 has-await0)
                    (if (or has-await1 has-await2)
                        (transform-expr+ e0)
                        (transform-expr e0))])
        (if (and (null? stmts1) (null? stmts2))
            (values
              (ConditionalExpression e0^ e1^ e2^)
              stmts0
              (or has-await0 has-await1 has-await2))
            (let ([tmp (gensym)]
                  [then (ExpressionStatement (VariableSet tmp e1^))]
                  [otherwise (ExpressionStatement (VariableSet tmp e2^))])
              (values
                (VariableGet tmp)
                (append stmts0
                  (list 
                    (VariableDeclaration tmp expr)
                    (IfStatement e0^
                      (if (null? stmts1)
                          then
                          (Block append stmts1 (list then)))
                      (if (null? stmts2)
                          otherwise
                          (Block append stmts2 (list otherwise))))))
                (or has-await0 has-await1 has-await2)))))]))
              

(define (transform-expr* exprs)
  (letrec ([help
             (lambda (exprs xform)
               (if (null? exprs)
                   (values '() '() #f)
                   (let-values ([(e0 stmts0 has-await0) (cform (car exprs))]
                                [(e1 stmts1 has-await1)
                                 (help
                                   (cdr exprs)
                                   (if has-await0 transform-expr+ xform))])
                     (values
                       (cons e0 e1)
                       (append stmts1 stmts0)
                       (or has-await0 has-await1)))))])
    (let-values ([(exprs^ stmts has-await) (help (reverse exprs) transform-expr)])
      (values (reverse exprs^) stmts has-await))))

(define (name expr stmts has-await)
  (let ([tmp (gensym)])
    (values
      (VariableGet tmp)
      (cons (VariableDeclaration tmp expr) stmts)
      has-await)))

(define (transform-expr+ expr)
  (cases Expression expr
    ;; Pure expressions without subexpressions
    [SymbolLiteral (v)
      (values expr '() #f)]
    ;; Impure expressions without subexpressions
    [InvalidExpression (m)
      (name expr '() #f)]
    ;; Pure if final
    [VariableGet (is-final x)
      (if is-final
          (values expr '() #f)
          (name expr '() #f))]
    ;; Unary expressions
    [VariableSet (x e)
      (let-values ([(e^ stmts has-await) (transform-expr e)])
        (name (VariableSet x e^) stmts has-await))]
    ;; Binary expressions
    [PropertySet (e0 name e1)
      (let-values ([(e1^ stmts1 has-await1) (transform-expr value)]
                   [(e0^ stmts0 has-await0)
                    (if has-await1 (transform-expr+ e0) (transform-expr e0))])
        (name
          (PropertySet e0^ name e1^)
          (append stmts1 stmts0)
          (or has-await0 has-await1)))]))
