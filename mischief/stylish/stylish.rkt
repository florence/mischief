#lang racket/base

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exports

(require racket/contract)

(provide

  with-stylish-port

  (contract-out

    [stylish-format
     (->*
         {string?}
         {#:expr-style expr-style?
          #:print-style print-style?
          #:left exact-nonnegative-integer?
          #:right exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       #:rest list?
       string?)]
    [stylish-printf
     (->*
         {string?}
         {#:port output-port?
          #:expr-style expr-style?
          #:print-style print-style?
          #:left exact-nonnegative-integer?
          #:right exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       #:rest list?
       void?)]

    [stylish-print
     (->*
         {any/c}
         {output-port?
          #:expr-style expr-style?
          #:print-style print-style?
          #:left exact-nonnegative-integer?
          #:right exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       void?)]
    [stylish-println
     (->*
         {any/c}
         {output-port?
          #:expr-style expr-style?
          #:print-style print-style?
          #:left exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       void?)]
    [stylish-value->string
     (->*
         {any/c}
         {#:expr-style expr-style?
          #:print-style print-style?
          #:left exact-nonnegative-integer?
          #:right exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       string?)]

    [stylish-print-expr
     (->*
         {any/c}
         {output-port?
          print-style?
          #:left exact-nonnegative-integer?
          #:right exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       void?)]
    [stylish-println-expr
     (->*
         {any/c}
         {output-port?
          print-style?
          #:left exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       void?)]
    [stylish-expr->string
     (->*
         {any/c}
         {print-style?
          #:left exact-nonnegative-integer?
          #:right exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       string?)]
    [stylish-print-separator
     (->*
         {output-port?}
         {#:indent exact-nonnegative-integer?
          #:wide? boolean?}
       void?)]
    [call-with-stylish-port
     (->*
         {output-port?
          (-> output-port? any)}
         {#:left exact-nonnegative-integer?
          #:right exact-nonnegative-integer?
          #:columns (or/c exact-nonnegative-integer? 'infinity)}
       any)]

    [stylish-quotable-value?
     (->*
         {any/c}
         {expr-style?}
       boolean?)]
    [stylish-value->expr
     (->*
         {any/c}
         {expr-style?}
       any/c)]

    [print-style? predicate/c]
    [empty-print-style print-style?]
    [current-print-style (parameter/c print-style?)]
    [set-print-style-default-printer
     (->
       print-style?
       (or/c (-> any/c output-port? void?) #false)
       print-style?)]
    [print-style-extension? predicate/c]
    [current-stylish-print-columns
     (parameter/c (or/c exact-nonnegative-integer? 'infinity))]

    (struct stylish-comment-expr {[comment any/c] [expr any/c]})
    (struct stylish-unprintable-expr {[name any/c]})

    [expr-style? predicate/c]
    [empty-expr-style expr-style?]
    [current-expr-style (parameter/c expr-style?)]
    [set-expr-style-default-convert
     (->
       expr-style?
       (or/c (-> any/c any/c) #false)
       expr-style?)]
    [expr-style-extension? predicate/c]

    (rename stylish-extend-print-style extend-print-style
      (->*
          {print-style?}
          {#:after? boolean?}
        #:rest (listof print-style-extension?)
        print-style?))
    (rename stylish-extend-expr-style extend-expr-style
      (->*
          {expr-style?}
          {#:after? boolean?}
        #:rest (listof expr-style-extension?)
        expr-style?))
    (rename stylish-expr-style-extension expr-style-extension
      (->*
          {predicate/c
           (-> any/c expr-style? any/c)}
          {(-> any/c expr-style? boolean?)
           boolean?}
        expr-style-extension?))
    (rename stylish-print-style-extension print-style-extension
      (->
        predicate/c
        (-> any/c output-port? print-style? any)
        print-style-extension?))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Imports

(require
  racket/function
  racket/port
  mischief/stylish/format
  mischief/stylish/expression
  mischief/stylish/print)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Debugging Definition

(define-syntax-rule (log-debugf fmt arg ...)
  (log-debug (format fmt arg ...)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public Definitions

(struct stylish-comment-expr [comment expr] #:transparent)
(struct stylish-unprintable-expr [name] #:transparent)

(define (stylish-printf
          #:port [port (current-output-port)]
          #:expr-style [est (current-expr-style)]
          #:print-style [pst (current-print-style)]
          #:left [left 0]
          #:right [right 0]
          #:columns [columns (current-stylish-print-columns)]
          fmt . args)
  (print-to-stylish-port 'stylish-printf port left right columns
    (lambda (port)
      (print-formatted 'stylish-printf est pst port fmt args))))

(define (stylish-format
          #:expr-style [est (current-expr-style)]
          #:print-style [pst (current-print-style)]
          #:left [left 0]
          #:right [right 0]
          #:columns [columns (current-stylish-print-columns)]
          fmt . args)
  (call-with-output-string
    (lambda (port)
      (print-to-stylish-port 'stylish-format port left right columns
        (lambda (port)
          (print-formatted 'stylish-format est pst port fmt args))))))

(define (stylish-print v [port (current-output-port)]
          #:expr-style [est (current-expr-style)]
          #:print-style [pst (current-print-style)]
          #:left [left 0]
          #:right [right 0]
          #:columns [columns (current-stylish-print-columns)])
  (define e (value->expression 'stylish-print v est))
  (log-debugf "\n===== stylish-print =====\n")
  (log-debugf "Convert:\n~e\n" v)
  (log-debugf "Print:\n~e\n" e)
  (print-to-stylish-port 'stylish-print port left right columns
    (lambda (port)
      (print-expression 'stylish-print e pst port))))

(define (stylish-println v [port (current-output-port)]
          #:expr-style [est (current-expr-style)]
          #:print-style [pst (current-print-style)]
          #:left [left 0]
          #:columns [columns (current-stylish-print-columns)])
  (define e (value->expression 'stylish-println v est))
  (log-debugf "\n===== stylish-println =====\n")
  (log-debugf "Convert:\n~e\n" v)
  (log-debugf "Print:\n~e\n" e)
  (print-to-stylish-port 'stylish-println port left 0 columns
    (lambda (port)
      (print-expression 'stylish-println e pst port)))
  (newline port))

(define (stylish-value->string v
          #:expr-style [est (current-expr-style)]
          #:print-style [pst (current-print-style)]
          #:left [left 0]
          #:right [right 0]
          #:columns [columns (current-stylish-print-columns)])
  (define e (value->expression 'stylish-print v est))
  (define s
    (call-with-output-string
      (lambda (port)
        (print-to-stylish-port 'stylish-value->string port left right columns
          (lambda (port)
            (print-expression 'stylish-value->string e pst port))))))
  (log-debugf "\n===== stylish-value->string =====\n")
  (log-debugf "Convert:\n~e\n" v)
  (log-debugf "Print:\n~e\n" e)
  (log-debugf "Return:\n~e\n" s)
  s)

(define (stylish-print-expr e
          [port (current-output-port)]
          [pst (current-print-style)]
          #:left [left 0]
          #:right [right 0]
          #:columns [columns (current-stylish-print-columns)])
  (print-to-stylish-port 'stylish-print-expr port left right columns
    (lambda (port)
      (print-expression 'stylish-print-expr e pst port)
      (void))))

(define (stylish-println-expr e
          [port (current-output-port)]
          [pst (current-print-style)]
          #:left [left 0]
          #:columns [columns (current-stylish-print-columns)])
  (print-to-stylish-port 'stylish-println-expr port left 0 columns
    (lambda (port)
      (print-expression 'stylish-println-expr e pst port)))
  (newline port))

(define (stylish-expr->string e
          [pst (current-print-style)]
          #:left [left 0]
          #:right [right 0]
          #:columns [columns (current-stylish-print-columns)])
  (call-with-output-string
    (lambda (port)
      (print-to-stylish-port 'stylish-expr->string port left right columns
        (lambda (port)
          (print-expression 'stylish-expr->string e pst port))))))

(define (call-with-stylish-port port proc
          #:left [left 0]
          #:right [right 0]
          #:columns [columns (current-stylish-print-columns)])
  (print-to-stylish-port 'call-with-stylish-port port left right columns
    proc))

(define-syntax-rule (with-stylish-port body ...)
  (call-with-stylish-port (current-output-port)
    (lambda (port)
      (parameterize {[current-output-port port]}
        body ...))))

(define (stylish-print-separator port
          #:indent [indent 0]
          #:wide? [wide? #t])
  (print-separator 'stylish-print-separator port indent wide?))

(define (stylish-quotable-value? v [est (current-expr-style)])
  (value-quotable? 'stylish-quotable-value? v est))

(define (stylish-value->expr v [est (current-expr-style)])
  (value->expression 'stylish-value->expr v est))

(define current-print-style (make-parameter empty-print-style))
(define current-expr-style (make-parameter empty-expr-style))
(define current-stylish-print-columns (make-parameter 80))

(define (stylish-extend-print-style pst
          #:after? [after? #false]
          . exts)
  (extend-print-style pst after? exts))

(define (stylish-extend-expr-style est
          #:after? [after? #false]
          . exts)
  (extend-expr-style est after? exts))

(define (stylish-print-style-extension type? printer)
  (print-style-extension type? printer))

(define (stylish-expr-style-extension
          type?
          convert
          [quotable? (const #false)]
          [prefer-quote? #true])
  (expr-style-extension type? convert quotable? prefer-quote?))