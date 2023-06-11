#!/usr/bin/env guile
!#

;; -*- geiser-scheme-implementation: guile -*-

(use-modules
 (ice-9 binary-ports)
 (ice-9 format)
 (srfi srfi-11)
 (rnrs bytevectors))

(define (print-verilog-header binary-file mem-size)
  (let ((words (call-with-input-file binary-file
                 (lambda (port)
                   (bytevector->uint-list
                    (get-bytevector-all port) 'little 4)))))
    (for-each
     (lambda (x)
       (format #t "~8,'0x\n" x))
     (append words
             (make-list (- mem-size (length words)) 0)))))

(let ((args (command-line)))
  (if (not (= (length args) 3))
      (format #t "Usage: ~a <BINARY_FILE_NAME> <MEM_SIZE_KB>\n" (car args))
      (let ((file-name (cadr args))
            (mem-size (floor (/ (string->number (caddr args)) 4))))
        (print-verilog-header file-name mem-size))))
