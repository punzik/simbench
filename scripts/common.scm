(cond-expand
 (guile
  (define-module (common))

  (import (srfi srfi-1)
          (srfi srfi-26)
          (srfi srfi-28)
          (srfi srfi-60)
          (ice-9 textual-ports))

  (export log2 clog2 round-to
          one? power-of-two?
          transpose
          number->string-binary
          number->string-binary-slice
          number->string-hex
          number->bits
          string-c-radix->number
          has-duplicates? find-duplicates
          insert-between
          string-replace-text
          string-split-str
          string-split-trim
          get-word
          substitute
          read-template

          make-mux-selectors))
 (else
  (error "Guile is required")))

;;; Log2
(define (log2 x)
  (/ (log x) (log 2)))

;;; Ceiling of log2 ($clog2 function in SV)
(define (clog2 x)
  (inexact->exact (ceiling (log2 x))))

;;; Check a number is a power of two
(define (power-of-two? x)
  (let ((l (round (log2 x))))
    (= (expt 2 l) x)))

;;; Check for (x == 1)
(define (one? x) (= x 1))

;;; Round to the 'n' decimal place
(define (round-to n num)
  (let ((k (expt 10 n)))
    (/ (round (* num k)) k)))

;;; Transpose of matrix (list of lists)
(define (transpose m)
  (apply map (cons list m)))

;;; Convert number to binary string of length 'len'
(define (number->string-binary n len)
  (list->string
   (reverse
    (map (lambda (x) (if x #\1 #\0))
         (list-tabulate len (lambda (i) (bit-set? i n)))))))

;;; Convert number to binary and slice from msb to lsb
(define (number->string-binary-slice n msb lsb)
  (list->string
   (reverse
    (drop
     (map (lambda (x) (if x #\1 #\0))
          (list-tabulate (+ msb 1) (lambda (i) (bit-set? i n))))
     lsb))))

;;; Convert number to hex with length l (padded left with 0)
(define (number->string-hex n l)
  (let* ((s (number->string n 16))
         (sl (string-length s)))
    (if (<= l sl)
        s
        (string-append (make-string (- l sl) #\0) s))))

;;; Convert number to bit list
(define (number->bits x len)
  (map (lambda (n) (if (bit-set? n x) 1 0)) (iota len)))

;;; Convert arbitrary radix string in C-format (0x, 0b 0..) to number
(define (string-c-radix->number str)
  (if (and str (string? str))
      (let ((str (string-trim-both str)))
        (cond
         ((string-every #\0 str) 0)
         ((string-prefix? "0x" str)
          (string->number (substring str 2) 16))
         ((string-prefix? "0b" str)
          (string->number (substring str 2) 2))
         ((string-prefix? "0" str)
          (string->number (substring str 1) 8))
         (else
          (string->number str 10))))
      #f))

;;; Check list for duplicates
(define (has-duplicates? items less)
  (if (< (length items) 2)
      #f
      (let ((sorted (sort items less)))
        (any (lambda (a b) (and (not (less a b))
                           (not (less b a))))
             sorted
             (append (cdr sorted)
                     `(,(car sorted)))))))

;;; Return first duplicated item or #f if no duplicates
(define (find-duplicates items less)
  (if (null? items)
      #f
      (let ((sorted (sort items less)))
        (let loop ((item (car sorted))
                   (rest (cdr sorted)))
          (cond
           ((null? rest) #f)
           ((and (not (less item (car rest)))
                 (not (less (car rest) item))) item)
           (else (loop (car rest) (cdr rest))))))))

;;; In the list b0 leaves only the last most significant (other than b1) bit
(define (bits-first-diff-msb b0 b1)
  (let loop ((b0 (reverse b0))
             (b1 (reverse b1))
             (keep '()))
    (if (null? b0)
        keep
        (let ((b0b (car b0))
              (b0s (cdr b0)))
          (if (= b0b (car b1))
              (loop b0s (cdr b1) (cons #f keep))
              (append (make-list (length b0s) #f) (cons b0b keep)))))))

;;; Return bit lists of address selectors
;;; If list item is #f then bit is not care
;;; First element of each list is a address
;;; Example:
;;; (make-mux-selectors '(#x10 #x20 #x30)) ->
;;;   ((#x30 #f #f #f #f  1 1)
;;;    (#x20 #f #f #f #f  0 1)
;;;    (#x10 #f #f #f #f #f 0))
(define (make-mux-selectors addrs)
  (let ((bit-width (apply max (map integer-length addrs)))
        (addrs (sort addrs >)))
    (map
     (lambda (addr)
       (let ((others (remove (cut = addr <>) addrs))
             (abits (number->bits addr bit-width)))
         (cons
          addr
          (apply map
                 (lambda bits
                   (let ((abit (car bits))
                         (obits (cdr bits)))
                     (if (every not obits) #f abit)))
                 (cons
                  abits
                  (map
                   (lambda (other)
                     (let ((obits (number->bits other bit-width)))
                       (bits-first-diff-msb abits obits)))
                   others))))))
     addrs)))

;;; Insert object between list items
(define (insert-between lst x)
  (if (or (null? lst)
          (null? (cdr lst)))
      lst
      (cons* (car lst) x
             (insert-between (cdr lst) x))))

;;; Racket-like string-replace
(define* (string-replace-text str from to #:key (all #t))
  (let ((flen (string-length from))
        (tlen (string-length to)))
    (let replace ((str str) (idx 0))
      (if (>= idx (string-length str))
          str
          (let ((occ (string-contains str from idx)))
            (if occ
                (let ((str (string-replace str to occ (+ occ flen))))
                  (if all
                      (replace str (+ occ tlen 1))
                      str))
                str))))))

;;; Substitute template
(define (substitute text template-format subst-list)
  (fold (lambda (s out)
          (string-replace-text
           out
           (format template-format (first s))
           (format "~a" (second s))))
        text subst-list))

;;; Read template and substitute replacements
;;; Returns list of strings (lines)
(define (read-template template-file template-format subst-list)
  (let ((ls (call-with-input-file template-file
              (lambda (port)
                (let loop ((l '()))
                  (let ((s (get-line port)))
                    (if (eof-object? s)
                        (reverse l)
                        (loop (cons s l)))))))))
    (map (lambda (str)
           (substitute str template-format subst-list))
         ls)))

;;; Split the string STR into a list of the substrings delimited by DELIMITER
(define (string-split-str str delimiter)
  (if (string-null? str)
      '()
      (let ((didx (string-contains str delimiter)))
        (if didx
            (cons (substring str 0 didx)
                  (string-split-str
                   (substring str (+ didx (string-length delimiter)))
                   delimiter))
            (list str)))))

;;; Split string and remove empty itemes
(define (string-split-trim str pred?)
  (remove string-null?
          (string-split str pred?)))

;;; Get word delimited by pred? from port
(define* (get-word port #:optional (pred? char-whitespace?))
  (let get-word-rec ((chlist '()))
    (let ((c (get-char port)))
      (if (eof-object? c)
          (if (null? chlist)
              #f
              (list->string (reverse chlist)))
          (if (pred? c)
              (if (null? chlist)
                  (get-word-rec chlist)
                  (list->string (reverse chlist)))
              (get-word-rec (cons c chlist)))))))
