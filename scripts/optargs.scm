(define-module (optargs))

(import (srfi srfi-1)
        (srfi srfi-11)
        (srfi srfi-37))

(export parse-opts
        option-get)

;;;
;;; TODO: Write docs
;;;
(define (option-get opts name)
  (let ((opt (assoc name opts)))
    (if opt
        (cdr opt)
        #f)))

(define (option-set opts name value)
  (if (assoc name opts)
      (map (lambda (opt)
             (if (equal? (car opt) name)
                 (cons name value)
                 opt))
           opts)
      (alist-cons name value opts)))

(define (option-add opts name value)
  (if (assoc name opts)
      (option-set opts name
                  (cons value
                        (option-get opts name)))
      (alist-cons name `(,value) opts)))

;;; opt-spec - '(("option" #\o) [none | required | optional | multiple])
(define (parse-opts args . opt-spec)
  (args-fold
   ;; args
   args
   ;; options
   (map (lambda (spec)
          (let* ((names (list-ref spec 0))
                 (type (list-ref spec 1))
                 (name (car names))
                 (req? (eq? type 'required))
                 (opt? (eq? type 'optional))
                 (many? (eq? type 'multiple)))
            (option names (or many? req?) opt?
                    (if many?
                        (lambda (opt nm arg opts rest error)
                          (values (if arg
                                      (option-add opts name arg)
                                      opts)
                                  rest
                                  error))
                        (lambda (opt nm arg opts rest error)
                          (values (option-set opts name (if arg arg #t)) rest error))))))
        opt-spec)
   ;; unrecognized options
   (lambda (opt name arg opts rest error)
     (values opts rest name))
   ;; operands
   (lambda (operand opts rest error)
     (values opts (cons operand rest) error))
   ;; seeds
   '() '() #f))
