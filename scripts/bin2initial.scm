#!/usr/bin/env guile
!#

;; -*- geiser-scheme-implementation: guile -*-

(use-modules
 (ice-9 binary-ports)
 (ice-9 format)
 (srfi srfi-11)
 (rnrs bytevectors))

(define (print-verilog-header binary-file reg-name)
  (format #t "initial begin\n")
  (let ((words (call-with-input-file binary-file
                 (lambda (port)
                   (bytevector->uint-list
                    (get-bytevector-all port) 'little 4)))))
    (for-each
     (lambda (x n)
       (format #t "    ~a[~a] = 32'h~8,'0x;\n" reg-name n x))
     words (iota (length words))))
  (format #t "end\n"))

(let ((args (command-line)))
  (if (not (= (length args) 3))
      (format #t "Usage: ~a <BINARY_FILE_NAME> <RAM_REG_NAME>\n" (car args))
      (let ((file-name (cadr args))
            (reg-name (caddr args)))
        (print-verilog-header file-name reg-name))))
