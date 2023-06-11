#!/usr/bin/env -S guile -e "(@@ (register-gen) main)" -s
!#

;; -*- geiser-scheme-implementation: guile -*-

;;; How to use module:
;; (add-to-load-path "./")
;; (import (register-gen))
;; (display (config-file->text-doc "./test.regs"))

(define-module (register-gen))

(export
 config-file->verilog
 config-file->c-header
 config-file->text-doc)

(add-to-load-path (dirname (current-filename)))

(import
 (srfi srfi-1)                          ; Lists
 (srfi srfi-9)                          ; Records
 (srfi srfi-11)                         ; let-values
 (srfi srfi-26)                         ; cut/cute
 (srfi srfi-28)                         ; Simple format
 (common)
 (optargs))

;;; Possible access mode list
(define MODES '(r w rw hs unused))

;;; Default access mode
(define DEFAULT-MODE 'rw)

;;; Count of indentation spaces
(define INDENT 2)

;;; Width of test field
(define TEXT_WIDTH 80)
(define MINIMUM_COL_WIDTH 4)

;;; Default module name suffix
(define MODULE_SUFFIX "_reg")

;;;
;;; Print to stderr
;;;
(define (warning . rest)
  (display "Warning: " (current-error-port))
  (display (apply format rest) (current-error-port))
  (newline (current-error-port)))

(define (error . rest)
  (display "Error: " (current-error-port))
  (display (apply format rest) (current-error-port))
  (newline (current-error-port))
  (exit EXIT_FAILURE))

;;;
;;; Register config structure
;;;
(define-record-type <config>
  (config module-name base
          address-width data-width
          byte-width byte-enable
          registers registered-selector)
  config?
  (module-name config-module-name)
  (base config-base)
  (address-width config-awidth)
  (data-width config-dwidth)
  (byte-width config-bwidth)
  (byte-enable config-ben)
  (registers config-regs)
  (registered-selector config-registered?))

;;; Get data bytres count
(define (config-bytes cfg)
  (/ (config-dwidth cfg)
     (config-bwidth cfg)))

;;; Get byte-selection address width
(define (config-bytes-awidth cfg)
  (clog2 (config-bytes cfg)))

;;;
;;; Register structure
;;;
(define-record-type <register>
  (register name info offset read-notify bits)
  register?
  (name register-name)
  (info register-info)
  (offset register-offset)
  (bits register-bits)
  (read-notify register-read-notify?))

;;;
;;; Bitfield structure
;;;
(define-record-type <bitfield>
  (bitfield name wname info lsb
            msb mode reset values)
  bitfield?
  (name bitfield-name)
  (wname bitfield-wname)
  (info bitfield-info)
  (lsb bitfield-lsb)
  (msb bitfield-msb)
  (mode bitfield-mode)
  (reset bitfield-reset)
  (values bitfield-values))

;;;
;;; Bitfield values structure
;;;
(define-record-type <bitfield-value>
  (bfvalue name value info)
  bfvalue?
  (name bfvalue-name)
  (value bfvalue-value)
  (info bfvalue-info))

;;; Return count of used bits in a register
(define (register-used-width reg)
  (let ((bits (register-bits reg)))
    (if (null? bits)
        0
        (+ 1 (fold max 0 (map bitfield-msb bits))))))

;;; Returns #t if register bitfield need storage (trigger)
(define (register-need-variable? reg)
  (any (lambda (bf)
         (member (bitfield-mode bf) '(w rw hs)))
       (register-bits reg)))

;;; Returns bitfield width
(define (bitfield-width bf)
  (- (bitfield-msb bf) (bitfield-lsb bf) -1))

;;; Check bitfield for crossing bytes boundary
(define (cross-bytes-boundry? msb lsb bwidth)
  (not (= (floor (/ msb bwidth))
          (floor (/ lsb bwidth)))))

;;;
;;; Useful functions
;;;

;;; Returns x or default if x is null or #f
(define (ifnull x default)
  (if (or (not x)
          (null? x))
      default
      x))

;;; Like assq but ignore non-list items
(define (assq* v l)
  (find (lambda (x) (and (list? x) (eq? v (car x)))) l))

;;; Like assq* but return all matches (in order)
(define (assq+ v l)
  (filter (lambda (x) (and (list? x) (eq? v (car x)))) l))

;;; assq* + cdr + default function
(define (assq*-cdr v l def)
  (let ((x (assq* v l)))
    (if (or (not x)
            (null? x))
        def
        (cdr x))))

;;; assq* + cadr + default function
(define (assq*-cadr v l def)
  (let ((x (assq* v l)))
    (if (or (not x)
            (null? x))
        def
        (cadr x))))

;;; assq* + cadr + default function
(define (assq*-cadr-f v l def-fn)
  (let ((x (assq* v l)))
    (if (or (not x)
            (null? x))
        (def-fn)
        (cadr x))))
;;;
;;; Print with indentationm
;;;   (-> [indent] format-string [parameters])
(define (->> . fmt)
  (cond
   ((null? fmt) #f)
   ((number? (car fmt))
    (let ((indent (car fmt))
          (rest (cdr fmt)))
      (when (not (null? rest))
        (display (list->string (make-list (* indent INDENT) #\space)))
        (display (apply format rest)))))
   (else
    (display (apply format fmt)))))

;;;
;;; Println with indentationm
;;;   (-> [indent] format-string [parameters])
;;;
(define (-> . fmt)
  (apply ->> fmt)
  (newline))

;;;
;;; ----------------------------------------------------------------------
;;; --------------------------- CONFIG PARSER ----------------------------
;;; ----------------------------------------------------------------------
;;;

;;;
;;; Parse bits list
;;;
(define (parse-bit-list bit-list reg-name dwidth default-mode)
  (let loop ((bit-list bit-list) (lsb 0) (bits '()))
    (if (null? bit-list)
        (if (null? bits)
            (error "No bitfield specified in register '~a'" reg-name)
            (reverse bits))
        (let ((bit-raw (cdr (car bit-list))))
          (let* ((blen (car bit-raw))
                 (msb (+ lsb blen -1))
                 (name (ifnull (find string? bit-raw) ""))
                 (mode (ifnull (find (lambda (x) (any (lambda (xx) (eq? x xx)) MODES)) bit-raw) default-mode))
                 (reset (assq*-cadr 'reset bit-raw 0))
                 (wname (if (eq? mode 'w) #f (cadr (ifnull (assq* 'write-name bit-raw) '(#f #f)))))
                 (info (assq*-cdr 'info bit-raw '("")))
                 (values
                  (map (lambda (info-lst)
                         (let ((value (car info-lst))
                               (vname (find string? info-lst))
                               (info (assq*-cadr 'info info-lst "")))
                           (if vname
                               (bfvalue vname value info)
                               (error "Bitfield value must have name (~a/~a)" reg-name name))))
                       (assq*-cdr 'values bit-raw '())))
                 (dup-value (find-duplicates (map bfvalue-name values) string<?)))
            (cond
             ;; Check duplicate name
             ((any (lambda (x) (string=? name (bitfield-name x))) bits)
              (error "Duplicate bitfield '~a' in register '~a'" name reg-name))
             ;; Check bit range
             ((or (<= blen 0) (>= msb dwidth))
              (error "Bitfield '~a' is out of range in register '~a'" name reg-name))
             ;; Check bit values
             (dup-value
              (error "Duplicate value '~a` in bitfield '~a', register '~a'" dup-value name reg-name))
             ;; All is OK
             (else
              (loop (cdr bit-list) (+ lsb blen)
                    (cons (bitfield name wname info lsb msb mode reset values) bits)))))))))

;;;
;;; Parse registers list
;;;
(define (parse-reg-list reg-list awidth dwidth bwidth offset)
  (let ((bytes (/ dwidth bwidth)))
    (let loop ((reg-list reg-list) (offset offset) (regs '()))
      (if (null? reg-list)
          (reverse regs)
          (let ((reg-raw (car reg-list)))
            (if (eq? (car reg-raw) 'offset)

                ;; Set offset
                (let ((offset (cadr reg-raw)))
                  (if (not (zero? (remainder offset bytes)))
                      (error "Offset ~a is not aligned to register width" offset)
                      (loop (cdr reg-list) offset regs)))

                ;; Add register
                (let ((name (ifnull (find string? reg-raw) ""))
                      (mode (ifnull (find (lambda (x) (any (lambda (xx) (eq? x xx)) MODES)) reg-raw) DEFAULT-MODE))
                      (info (cdr (ifnull (assq* 'info reg-raw) '(#f ""))))
                      (bit-list (assq+ 'bits reg-raw))
                      (read-notify (if (memq 'read-notify reg-raw) #t #f)))

                  (cond
                   ;; Check duplicate name
                   ((any (lambda (x) (string=? name (register-name x))) regs)
                    (error "Duplicate register '~a'" name))
                   ;; Check address depth
                   ((and awidth
                         (> offset (- (expt 2 awidth) (/ dwidth 4))))
                    (error "Register '~a' offset is out of address range" name))
                   ;; all is OK
                   (else
                    (let ((reg (register name info offset read-notify
                                         (parse-bit-list bit-list name dwidth mode))))
                      (loop (cdr reg-list) (+ offset bytes) (cons reg regs))))))))))))

;;;
;;; Parse reg config file
;;;
(define (parse-config-file file override-module-name override-base-address registered-selectors)
  (let ((config-list (with-input-from-file file read)))
    (let ((module-name
           (if override-module-name
               override-module-name
               (let ((w (assq* 'name config-list)))
                 (if w
                     (second w)
                     (string-append
                      (car (string-split (basename file) #\.)) MODULE_SUFFIX)))))
          (dwidth (assq*-cadr-f 'data-width config-list
                                (lambda () (warning "Data width will be set to 32 bit") 32)))
          (awidth (assq*-cadr-f 'address-width config-list
                                (lambda () (warning "Address width will be calculated automatically") #f)))
          (base
           (if override-base-address
               override-base-address
               (assq*-cadr-f 'base config-list
                             (lambda () (warning "Base address will be set to 0") 0))))
          (bwidth (assq*-cadr-f 'byte-width config-list (lambda () 8)))
          (ben (if (memq 'byte-enable config-list) #t #f))
          (reg-list (reverse
                     (fold (lambda (x l)
                             (if (and
                                  (list? x)
                                  (or (eq? (car x) 'reg)
                                      (eq? (car x) 'offset)))
                                 (cons x l)
                                 l))
                           '() config-list))))

      (when (not (integer? (/ dwidth bwidth)))
        (error "The data width is not a multiple of the byte width"))

      (let ((regs (parse-reg-list reg-list awidth dwidth bwidth 0)))
        (config
         module-name
         base
         (if awidth
             awidth
             ;; Calculate needed address width
             (clog2
              (+ (/ dwidth bwidth)
                 (fold max 0 (map register-offset regs)))))
         dwidth bwidth ben regs
         registered-selectors)))))

;;;
;;; ----------------------------------------------------------------------
;;; -------------------------- VERILOG BACKEND ---------------------------
;;; ----------------------------------------------------------------------
;;;

;;;
;;; Print module header and ports
;;;
(define (print-verilog-module-header cfg)
  (let ((regs (config-regs cfg))
        (awidth (config-awidth cfg))
        (dwidth (config-dwidth cfg))
        (bytes (config-bytes cfg)))

    (-> 0 "// This file is auto-generated. Do not edit")
    (->)
    (-> 0 "module ~a" (config-module-name cfg))
    (-> 1 "(input wire clock,")
    (-> 1 " input wire reset,")
    (->)
    (-> 1 " /* ---- Access bus ---- */")
    (-> 1 " /* verilator lint_off UNUSED */")
    (-> 1 " input wire [~a:0] ~a,"
        (- awidth 1)
        (if (config-registered? cfg) "i_la_addr" "i_addr"))
    (-> 1 " input wire [~a:0] i_data," (- dwidth 1))
    (-> 1 " output wire [~a:0] o_data," (- dwidth 1))
    (when (config-ben cfg)
      (-> 1 " input wire [~a:0] i_ben," (- bytes 1)))
    (-> 1 " input wire i_write,")
    (-> 1 " input wire i_read,")
    (-> 1 " /* verilator lint_on UNUSED */")

    (for-each
     (lambda (reg last)
       (let ((reg-name (register-name reg))
             (reg-bits (register-bits reg)))
         (->)
         (-> 1 " /* ---- '~a' ---- */" reg-name)

         (when (register-read-notify? reg)
           (-> 1 " output wire o_~a__rnotify~a"
               reg-name
               (if (and last
                        (or (null? reg-bits)
                            (every (cut eq? 'unused <>)
                                   (map bitfield-mode reg-bits))))
                   ");" ",")))

         (for-each
          (lambda (bit last)
            (let* ((name (bitfield-name bit))
                   (mode (bitfield-mode bit))
                   (lsb (bitfield-lsb bit))
                   (msb (bitfield-msb bit))
                   (msb0 (- msb lsb)))

              (cond
               ;; Read-only
               ((eq? mode 'r)
                (-> 1 " input wire ~ai_~a_~a~a"
                    (if (zero? msb0) "" (format "[~a:0] " msb0))
                    reg-name name
                    (if last ");" ",")))

               ;;  Write only
               ((eq? mode 'w)
                (-> 1 " output wire ~ao_~a_~a~a"
                    (if (zero? msb0) "" (format "[~a:0] " msb0))
                    reg-name name
                    (if last ");" ",")))

               ;; Read/write
               ((eq? mode 'rw)
                (-> 1 " input wire ~ai_~a_~a,"
                    (if (zero? msb0) "" (format "[~a:0] " msb0))
                    reg-name name)
                (let ((wname (bitfield-wname bit)))
                  (-> 1 " output wire ~ao_~a_~a~a"
                      (if (zero? msb0) "" (format "[~a:0] " msb0))
                      reg-name
                      (if wname wname name)
                      (if last ");" ","))))

               ;; Handshake output
               ((eq? mode 'hs)
                (-> 1 " output wire ~ao_~a_~a_hsreq,"
                    (if (zero? msb0) "" (format "[~a:0] " msb0))
                    reg-name name)
                (-> 1 " input wire ~ai_~a_~a_hsack,"
                    (if (zero? msb0) "" (format "[~a:0] " msb0))
                    reg-name name)
                (-> 1 " input wire ~ai_~a_~a~a"
                    (if (zero? msb0) "" (format "[~a:0] " msb0))
                    reg-name name
                    (if last ");" ","))))))
          reg-bits
          (reverse (cons last (cdr (map (lambda x #f) reg-bits)))))))
     regs
     ;; List of #f with last element of #t
     (reverse (cons #t (cdr (map (lambda x #f) regs)))))
    (->)))

;;;
;;; Print write address decoder
;;;
(define (print-verilog-address-selector cfg)
  (let ((regs (config-regs cfg))
        (awidth (config-awidth cfg))
        (dwidth (config-dwidth cfg))
        (bytes-awidth (config-bytes-awidth cfg))
        (registered (config-registered? cfg)))

    (-> 1 "/* ---- Address decoder ---- */")
    ;; Selector wires
    (for-each
     (cute -> 1 "~a ~a_select;" (if registered "reg" "wire") <>)
     (map register-name regs))
    (->)

    ;; Assign
    (let ((selectors (make-mux-selectors
                      (map register-offset regs))))
      (for-each
       (lambda (reg)
         (let* ((offset (register-offset reg))
                (name (register-name reg))
                (selector (cdr (assq offset selectors))))
           (if (every not selector)
               (-> 1 "assign ~a_select = 1'b1;" name)
               (begin
                 (if registered
                     (begin
                       (-> 1 "always @(posedge clock)")
                       (-> 2 "if (reset)")
                       (-> 3 "~a_select <= 1'b0;" name)
                       (-> 2 "else")
                       (-> 3 "~a_select <= " name))
                     (-> 1 "assign ~a_select =" name))

                 (let loop ((bits selector)
                            (n 0)
                            (need-and-sign #f))
                   (if (null? bits) #f
                       (begin
                         (let ((bit (car bits)))
                           (loop (cdr bits) (+ n 1)
                                 (if bit
                                     (begin
                                       (when need-and-sign (-> " &&"))
                                       (->> (if registered 4 2)
                                            "~a[~a] == 1'b~a"
                                            (if registered "i_la_addr" "i_addr")
                                            n bit)
                                       #t)
                                     need-and-sign))))))
                 (-> ";")))
           (->)))
       regs))))

;;;
;;; Print variables and write assigmnent for W/WR bitfield
;;;
(define (print-variables-wr bf reg-name byte-enable bwidth bytes)
  (let* ((wname (bitfield-wname bf))
         (name (if wname wname (bitfield-name bf)))
         (lsb (bitfield-lsb bf))
         (msb (bitfield-msb bf))
         (reset (bitfield-reset bf))
         (msb0 (- msb lsb))
         (bn (format "~a_~a" reg-name name)))

    ;; Declare variables
    (-> 1 "reg ~a~a;"
        (if (zero? msb0) "" (format "[~a:0] " msb0))
        bn)
    (-> 1 "assign o_~a = ~a;" bn bn)
    (->)

    ;; Assign variable
    (-> 1 "always @(posedge clock)")
    (-> 2 "if (reset)")
    (-> 3 "~a <= ~a'b0;" bn (+ 1 msb0))
    (-> 2 "else")

    (if byte-enable
        ;; If need byte-enabled write
        (begin
          (-> 3 "if (~a_select && i_write) begin" reg-name)
          (for-each
           (lambda (byte)
             (let ((byte-lsb (* byte bwidth))
                   (byte-msb (+ (* byte bwidth) (- bwidth 1))))
               (when (and (>= msb byte-lsb)
                          (<= lsb byte-msb))
                 (let* ((msb-s (if (> msb byte-msb) byte-msb msb))
                        (lsb-s (if (< lsb byte-lsb) byte-lsb lsb))
                        (msb-v (- msb-s lsb))
                        (lsb-v (- lsb-s lsb)))
                   (-> 4 "if (i_ben[~a]) ~a~a <= i_data[~a];"
                       byte
                       bn
                       (if (= msb lsb)
                           ""
                           (if (= msb-v lsb-v)
                               (format "[~a]" lsb-v)
                               (format "[~a:~a]" msb-v lsb-v)))
                       (if (= msb-s lsb-s)
                           (format "~a" lsb-s)
                           (format "~a:~a" msb-s lsb-s)))))))
           (iota bytes))
          (-> 3 "end"))
        ;; Write whole word
        (begin
          (-> 3 "if (~a_select && i_write)" reg-name)
          (-> 4 "~a <= i_data[~a];"
              bn
              (if (zero? msb0)
                  (format "~a" lsb)
                  (format "~a:~a" msb lsb)))))
    (->)))

;;;
;;; Print variables and write assigmnent for HS bitfield
;;;
(define (print-variables-hs bf reg-name byte-enable bwidth bytes)
  (let* ((name (bitfield-name bf))
         (lsb (bitfield-lsb bf))
         (msb (bitfield-msb bf))
         (msb0 (- msb lsb))
         (bv (format "~a_~a_hsreq" reg-name name))
         (br (format "i_~a_~a_hsack" reg-name name)))

    ;; Declare variables
    (-> 1 "reg ~a~a;" (if (zero? msb0) "" (format "[~a:0] " msb0)) bv)
    (-> 1 "assign o_~a = ~a;" bv bv)
    (->)

    ;; Assign variable
    (-> 1 "always @(posedge clock)")
    (-> 2 "if (reset)")
    (-> 3 "~a <= ~a'b0;" bv (+ 1 msb0))

    (if byte-enable
        ;; If need byte-enabled write
        (begin
          (-> 2 "else begin")
          (for-each
           (lambda (byte)
             (let ((byte-lsb (* byte bwidth))
                   (byte-msb (+ (* byte bwidth) (- bwidth 1))))
               (when (and (>= msb byte-lsb)
                          (<= lsb byte-msb))
                 (let* ((msb-s (if (> msb byte-msb) byte-msb msb))
                        (lsb-s (if (< lsb byte-lsb) byte-lsb lsb))
                        (msb-v (- msb-s lsb))
                        (lsb-v (- lsb-s lsb))
                        (vrange (if (= msb lsb)
                                    ""
                                    (if (= msb-v lsb-v)
                                        (format "[~a]" lsb-v)
                                        (format "[~a:~a]" msb-v lsb-v)))))
                   (-> 3 "if (~a_select && i_write && i_ben[~a]) ~a~a <= i_data[~a];"
                       reg-name byte
                       bv vrange
                       (if (= msb-s lsb-s)
                           (format "~a" lsb-s)
                           (format "~a:~a" msb-s lsb-s)))

                   (-> 3 "else ~a~a <= ~a~a & (~~~a~a);"
                       bv vrange
                       bv vrange
                       br vrange)))))
           (iota bytes))
          (-> 2 "end"))
        ;; Write whole word
        (begin
          (-> 2 "else")
          (-> 3 "if (~a_select && i_write)" reg-name)
          (-> 4 "~a <= i_data[~a];"
              bv
              (if (zero? msb0)
                  (format "~a" lsb)
                  (format "~a:~a" msb lsb)))
          (-> 3 "else")
          (-> 4 "~a <= ~a & (~~~a);" bv bv br)))
    (->)))

;;;
;;; Print register variables and write logic
;;;
(define (print-verilog-variables cfg)
  ;; Print registers variables
  (for-each
   (lambda (reg)
     (let ((reg-name (register-name reg))
           (need-variable (register-need-variable? reg))
           (read-notify (register-read-notify? reg)))
       (when (or need-variable read-notify)
         (->)
         (-> 1 "/* ---- '~a' ---- */" reg-name)

         (when need-variable
           (for-each
            (lambda (bit)
              (let* ((mode (bitfield-mode bit)))
                (cond
                 ;; Write-only and read/write bitfield
                 ((or (eq? mode 'w)
                      (eq? mode 'rw))
                  (print-variables-wr bit reg-name
                                      (config-ben cfg)
                                      (config-bwidth cfg)
                                      (config-bytes cfg)))

                 ;; Handshake bitfield
                 ((eq? mode 'hs)
                  (print-variables-hs bit reg-name
                                      (config-ben cfg)
                                      (config-bwidth cfg)
                                      (config-bytes cfg))))))
            (register-bits reg)))

         ;; Read-notify flag
         (when read-notify
           (-> 1 "assign o_~a__rnotify = ~a_select & i_read;" reg-name reg-name)
           (->)))))
   (config-regs cfg)))

;;;
;;; Print registers read multiplexer
;;;
(define (print-verilog-read-mux- cfg)
  (let ((regs (config-regs cfg))
        (awidth (config-awidth cfg))
        (dwidth (config-dwidth cfg))
        (bytes-awidth (config-bytes-awidth cfg)))

    (-> 1 "/* ---- Read multiplexer ---- */")
    (-> 1 "reg [~a:0] data_read;" (- dwidth 1))
    (-> 1 "assign o_data = data_read;")
    (->)

    ;; Mux
    (-> 1 "always @(*)")
    (-> 2 "case (i_addr[~a:~a])" (- awidth 1) bytes-awidth)
    (for-each
     (lambda (reg)
       (let* ((high-zero-bits (- dwidth (register-used-width reg)))
              (bits (if (zero? high-zero-bits)
                        (register-bits reg)
                        (append (register-bits reg)
                                `(,(bitfield "" #f ""
                                             (- dwidth high-zero-bits)
                                             (- dwidth 1)
                                             'unused 0 '())))))
              (reg-name (register-name reg)))

         ;; Reg address case
         (-> 3 "/* '~a' */" reg-name)
         (-> 3 "~a'b~a: begin"
             (- awidth bytes-awidth)
             (number->string-binary-slice
              (register-offset reg)
              (- awidth 1)
              bytes-awidth))

         (for-each
          (lambda (bf)
            (let ((bf-name (bitfield-name bf))
                  (mode (bitfield-mode bf))
                  (msb (bitfield-msb bf))
                  (lsb (bitfield-lsb bf))
                  (width (bitfield-width bf)))
              (let ((range (if (one? width)
                               (number->string msb)
                               (format "~a:~a" msb lsb))))
                (cond
                 ;; Unused bits
                 ((or (eq? mode 'unused)
                      (eq? mode 'w))
                  (-> 4 "data_read[~a] = ~a'b0;"
                      range width))

                 ;; Read and reaad/write bits
                 ((or (eq? mode 'r)
                      (eq? mode 'rw)
                      (eq? mode 'hs))
                  (-> 4 "data_read[~a] = i_~a_~a;"
                      range reg-name bf-name))))))
          bits)

         (-> 3 "end")
         (->)))
     regs)

    (-> 3 "default: data_read = ~a'b0;" dwidth)
    (-> 2 "endcase")))


(define (print-verilog-read-mux cfg)
  (let ((regs (config-regs cfg))
        (awidth (config-awidth cfg))
        (dwidth (config-dwidth cfg))
        (bytes-awidth (config-bytes-awidth cfg)))

    (-> 1 "/* ---- Read multiplexer ---- */")
    (for-each
     (cute -> 1 "reg [~a:0] data_~a;" (- dwidth 1) <>)
     (map register-name regs))
    (->)

    (-> 1 "assign o_data = ")
    (for-each
     (lambda (name n)
       (-> 2 "data_~a~a" name (if (zero? n) ";" " |")))
     (map register-name regs)
     (reverse (iota (length regs))))
    (->)

    (-> 1 "always @(*) begin")
    (for-each
     (cut -> 2 "data_~a = ~a'd0;" <> dwidth)
     (map register-name regs))
    (->)
    (for-each
     (lambda (reg)
       (let ((bits
               (filter (lambda (bf)
                         (let ((mode (bitfield-mode bf)))
                           (or (eq? mode 'r)
                               (eq? mode 'rw)
                               (eq? mode 'hs))))
                       (register-bits reg)))
             (reg-name (register-name reg)))

         (when (not (null? bits))
           (-> 2 "if (~a_select) begin" reg-name)
           (for-each
            (lambda (bf)
              (let ((bf-name (bitfield-name bf))
                    (msb (bitfield-msb bf))
                    (lsb (bitfield-lsb bf))
                    (width (bitfield-width bf)))
                (let ((range (if (one? width)
                                 (number->string msb)
                                 (format "~a:~a" msb lsb))))
                  (-> 3 "data_~a[~a] = i_~a_~a;"
                      reg-name range reg-name bf-name))))
            bits)
           (-> 2 "end")
           (->))))
     regs)
    (-> 1 "end")
    (->)))

;;;
;;; Print module footer
;;;
(define (print-verilog-module-footer cfg)
  (-> 0 "endmodule // ~a" (config-module-name cfg)))

;;;
;;; Convert config to verilog module
;;;
(define (config->verilog cfg)
  (with-output-to-string
    (lambda ()
      (print-verilog-module-header cfg)
      (print-verilog-address-selector cfg)
      (print-verilog-variables cfg)
      (print-verilog-read-mux cfg)
      (print-verilog-module-footer cfg))))

;;;
;;; ----------------------------------------------------------------------
;;; ------------------------- TEXT DOC BACKEND ---------------------------
;;; ----------------------------------------------------------------------
;;;

;;; Mode -> Name of mode
(define mode-names
  '((r "RO") (w "WO") (rw "RW") (hs "HS") (unused "unused")))

;;; String alignment with spaces
(define (string-align width align text)
  (let ((l (string-length text)))
    (if (>= l width)
        text
        (cond
         ((eq? align 'left)
          (string-append text (make-string (- width l) #\space)))
         ((eq? align 'right)
          (string-append (make-string (- width l) #\space) text))
         (else
          (let* ((al (round (/ (- width l) 2)))
                 (ar (- (- width l) al)))
            (string-append (make-string al #\space)
                           text
                           (make-string ar #\space))))))))

;;; Wrap string by words boundary
;;; Return list of strings with length less of equal 'width'
(define (string-word-wrap width str)
  (let ((make-sentence
         (lambda (words)
           (fold (lambda (word sent)
                   (if (string-null? sent)
                       word
                       (string-append sent " " word)))
                 "" words)))
        (words (string-split str #\space)))

    (let loop ((words-left '())
               (words-right words))
      (if (null? words-right)
          (list (make-sentence (reverse words-left)))
          (let* ((word (car words-right))
                 (left-width (string-length
                              (make-sentence
                               (cons word words-left)))))
            (cond
             ;; Crack word
             ((and (> left-width width)
                   (null? words-left))
              (cons (substring word 0 width)
                    (string-word-wrap
                     width
                     (make-sentence
                      (cons (substring word width)
                            (cdr words-right))))))

             ;; Split
             ((> left-width width)
              (cons (make-sentence (reverse words-left))
                    (string-word-wrap
                     width
                     (make-sentence words-right))))

             ;; Next word
             (else
              (loop (cons word words-left)
                    (cdr words-right)))))))))

;;;
;;; Make text table as list of strings
;;;
(define* (make-text-table header
                          header-align
                          body
                          body-align
                          word-wrap
                          max-width
                          minimum-col-width
                          #:key (paragraph-indent-width 1))

  ;; Word wrap each column in row
  (define (row-word-wrap widths wraps row)
    (map (lambda (width wrap col)
           (if wrap
               (fold (lambda (cell ret)
                       (append ret (string-word-wrap
                                    (- width paragraph-indent-width)
                                    cell)))
                     '() col)
               col))
         widths wraps row))

  ;; Make columns lengths equal
  (define (normalize-columns-in-row row)
    (let ((col-length (apply max (map length row))))
      (map (lambda (col)
             (let ((l (length col)))
               (if (< l col-length)
                   (append col (make-list (- col-length l) ""))
                   col)))
           row)))

  ;; Align columns width
  (define (align-columns width-lst wrap-lst table-width minimum-width)
    (let ((var-count (apply + (map (lambda (wrap) (if wrap 1 0)) wrap-lst))))
      (if (zero? var-count)
          (values width-lst wrap-lst)
          (let* ((w-fixed (apply + (map (lambda (w wrap) (if wrap 0 w))
                                        width-lst wrap-lst)))
                 (col-w-var (floor (/ (- table-width w-fixed) var-count)))
                 (col-w-var (if (< col-w-var minimum-width) minimum-width col-w-var)))
            (if (any (lambda (w wrap) (and wrap (<= w col-w-var))) width-lst wrap-lst)
                (let-values
                    (((width-lst wrap-lst)
                      (unzip2
                       (map (lambda (w.wrap)
                              (if (and (cadr w.wrap)
                                       (<= (car w.wrap) col-w-var))
                                  `(,(car w.wrap) #f)
                                  w.wrap))
                            (zip width-lst wrap-lst)))))
                  (align-columns width-lst wrap-lst table-width minimum-width))
                (values
                 (map (lambda (w wrap) (if wrap col-w-var w)) width-lst wrap-lst)
                 wrap-lst))))))

  ;; Convert row data to text table lines
  (define (row->string-list widths align row-list)
    (map (lambda (row n)
           (apply string-append
                  (cons "|"
                        (fold-right
                         (lambda (cell wrap w a ret)
                           (let ((text-width
                                  (if (and wrap (> n 0))
                                      (- w paragraph-indent-width)
                                      w)))
                             (cons* " "
                                    (make-string (- w text-width) #\space)
                                    (string-align text-width a cell)
                                    " |" ret)))
                         '()
                         row
                         word-wrap
                         widths
                         align))))
         row-list
         (iota (length row-list))))

  ;; Check integrity
  (let ((col-count (length header)))
    (when (not
           (every (lambda (x) (= col-count (length x)))
                  (cons* header-align body-align word-wrap body)))
      (error "in function make-text-table: wrong length of arguments")))

  (let ((table-text-width (- max-width (+ (* (length header) 3) 1)))
        ;; Calculate column widths
        (widths0
         (map (cut apply max <>)
              (transpose
               (map (lambda (row)
                      (map (lambda (col wrap)
                             (+
                              (apply max (map string-length col))
                              (if (and wrap (> (length col) 1))
                                  paragraph-indent-width 0)))
                           row word-wrap))
                    (cons (map list header) body))))))
    ;; Align columns
    (let-values
        (((widths wraps)
          (align-columns widths0 word-wrap table-text-width minimum-col-width)))

      (let (;; Word wrap header
            (header
             (transpose
              (normalize-columns-in-row
               (row-word-wrap widths wraps (map list header)))))

            ;; Word wrap body
            (body
             (map (lambda (row)
                    (transpose
                     (normalize-columns-in-row
                      (row-word-wrap widths wraps row))))
                  body))

            ;; Make separator
            (separator
             (fold (lambda (w n ret)
                     (string-append
                      ret
                      (make-string (+ w 2) #\-)
                      (if (zero? n) "|" "+")))
                   "|"
                   widths
                   (reverse (iota (length widths))))))

        ;; Make table lines
        (append
         (row->string-list widths header-align header)
         `(,separator)
         (apply append
                (map (cut row->string-list widths body-align <>) body)))))))

;;; Make table from register data
;;; Each row is a list of columns list
;;; Columns is a list of row cells (strings)
(define (register->table reg dwidth)
  (map (lambda (bf)
         (let ((name (bitfield-name bf))
               (wname (bitfield-wname bf))
               (msb (bitfield-msb bf))
               (lsb (bitfield-lsb bf))
               (mode (bitfield-mode bf))
               (info (bitfield-info bf))
               (reset (bitfield-reset bf))
               (unused (eq? (bitfield-mode bf) 'unused)))

           (list
            ;; Column 'Bits'
            `(,(if (= msb lsb) (number->string lsb) (format "~a:~a" msb lsb)))

            ;; Column 'Name'
            (cons
             (if unused "-" (string-upcase name))
             (if wname `(,(string-upcase wname)) '()))

            ;; Column 'Mode'
            (cons
             (if unused ""
                 (if wname
                     (second (assq 'r mode-names))
                     (second (assq mode mode-names))))
             (if wname `(,(second (assq 'w mode-names))) '()))

            ;; Column 'Reset'
            `(,(if unused ""
                   (cond
                    ((= reset 0) "0")
                    ((= reset 1) "1")
                    (else (format "0x~a" (number->string reset 16))))))

            ;; Column 'Info'
            info)))
       (sort (register-bits reg)
             (lambda (a b)
               (> (bitfield-lsb a)
                  (bitfield-lsb b))))))

;;;
;;; Print register description
;;;
(define (print-register-table reg awidth dwidth)
  (let ((name (register-name reg))
        (offset (register-offset reg))
        (info (register-info reg))
        (bits (register-bits reg)))

    ;; Print header name
    (let* ((header (format "~a Register (0x~a)"
                           (string-upcase name)
                           (number->string-hex
                            offset
                            (ceiling (/ awidth 4)))))
           (hline (string-map (lambda (x) #\-) header)))
      (-> header)
      (-> hline))

    ;; Print description
    (when (not (null? info))
      (->)
      ;; (-> "  Description:")
      (for-each (cut -> "  ~a" <>)
                (fold (lambda (s ret)
                        (append ret (string-word-wrap (- TEXT_WIDTH 2) s)))
                      '() info)))
    (->)

    ;; Print bitfields table
    (for-each
     (cut -> "  ~a" <>)
     (make-text-table '("Bits" "Name" "Mode" "Reset" "Description")
                      '(center center center center center)
                      (register->table reg dwidth)
                      '(right left left left left)
                      '(#f #f #f #f #t)
                      (- TEXT_WIDTH 2)
                      MINIMUM_COL_WIDTH))))

;;;
;;; Print register address map
;;;
(define (print-register-map-table cfg)
  (let ((awidth (config-awidth cfg))
        (dwidth (config-dwidth cfg))
        (regs (sort (config-regs cfg)
                    (lambda (a b)
                      (< (register-offset a)
                         (register-offset b))))))

    ;; Print header
    (let* ((header (format "Register map of ~a (base: 0x~a)"
                           (string-upcase (config-module-name cfg))
                           (number->string (config-base cfg) 16)))
           (hline (string-map (lambda (x) #\=) header)))
      (-> header)
      (-> hline)
      (->))

    ;; Make table body
    (let ((body
           (map (lambda (reg)
                  `((,(format "0x~a"
                              (number->string-hex
                               (register-offset reg)
                               (ceiling (/ awidth 4)))))
                    (,(string-upcase (register-name reg)))
                    (,(let ((info (register-info reg)))
                        (if (null? info) "" (car info))))))
                regs)))

      ;; Print table
      (for-each
       (cut -> "  ~a" <>)
       (make-text-table '("Offset" "Name" "Description")
                        '(center center center)
                        body
                        '(left left left)
                        '(#f #f #t)
                        (- TEXT_WIDTH 2)
                        MINIMUM_COL_WIDTH)))))

;;;
;;; Convert config to text document
;;;
(define (config->text-doc cfg)
  (with-output-to-string
    (lambda ()
      (print-register-map-table cfg)
      (newline)
      (let ((awidth (config-awidth cfg))
            (dwidth (config-dwidth cfg))
            (regs (sort (config-regs cfg)
                        (lambda (a b)
                          (< (register-offset a)
                             (register-offset b))))))
        (for-each
         (lambda (reg)
           (newline)
           (print-register-table reg awidth dwidth)
           (newline))
         regs)))))

;;;
;;; ----------------------------------------------------------------------
;;; ------------------------- C-HEADER BACKEND ---------------------------
;;; ----------------------------------------------------------------------
;;;

(define (config->c-header cfg)
  (with-output-to-string
    (lambda ()
      (let ((reg-prefix (string-upcase (config-module-name cfg)))
            (dwidth (config-dwidth cfg))
            (awidth (config-awidth cfg))
            (regs (config-regs cfg)))
        (-> "#ifndef _~a_H_" reg-prefix)
        (-> "#define _~a_H_" reg-prefix)
        (->)
        (-> "#define ~a_BASE 0x~a"
            reg-prefix
            (number->string (config-base cfg) 16))
        (->)

        (for-each
         (lambda (reg)
           (let ((reg-name (string-upcase (register-name reg))))
             (-> "/* -- Register '~a' -- */" reg-name)

             ;; Print register
             (-> "#define ~a_~a (*(volatile uint~a_t*)(~a_BASE + 0x~a))"
                 reg-prefix reg-name dwidth reg-prefix
                 (number->string-hex (register-offset reg)
                                     (ceiling (/ awidth 4))))
             (for-each
              (lambda (bf)
                (let ((bf-name (string-upcase (bitfield-name bf)))
                      (msb (bitfield-msb bf))
                      (lsb (bitfield-lsb bf))
                      (values (bitfield-values bf)))
                  (if (= msb lsb)
                      (-> "#define ~a_~a_~a (1 << ~a)"
                          reg-prefix reg-name bf-name msb)
                      (begin
                        (let ((mask (- (expt 2 (+ msb 1))
                                       (expt 2 lsb))))
                          (-> "#define ~a_~a_~a__MASK 0x~a"
                              reg-prefix reg-name bf-name
                              (number->string-hex mask (/ dwidth 4)))
                          (-> "#define ~a_~a_~a__SHIFT ~a"
                              reg-prefix reg-name bf-name lsb)
                          (for-each
                           (lambda (value)
                             (-> "#define ~a_~a_~a_~a 0x~a"
                                 reg-prefix reg-name bf-name
                                 (string-upcase (bfvalue-name value))
                                 (number->string
                                  (logand mask (ash (bfvalue-value value) lsb))
                                  16)))
                           values))))))
              (filter (lambda (bf)
                        (not (eq? 'unused (bitfield-mode bf))))
                      (register-bits reg)))

             (->)))
         regs)
        (-> "#endif // _~a_H_" reg-prefix)))))

;;;
;;; ----------------------------------------------------------------------
;;; ---------------------------- ENTRY POINT------------------------------
;;; ----------------------------------------------------------------------
;;;

(define (print-help app-name)
  (with-output-to-port (current-error-port)
    (lambda ()
      (-> "Usage: ~a [OPTION]... <FILE>" app-name)
      (-> "Make CPU/perepheral IO registers map. FILE - is a register description file.")
      (-> "By default tool prints source code of Verilog module.")
      (-> "")
      (-> "Options:")
      (-> "  -m, --module NAME    Set module name and registers prefix in C-header.")
      (-> "  -t, --text           Print text documentation.")
      (-> "  -c, --header         Print C-header.")
      (-> "  -b, --base NUM       Registers base address.")
      (-> "  -r, --registered     Make registered selectors.")
      (-> "  -h, --help           Print this message and exit")
      (-> "")
      (-> "Source code and issue tracker: <https://github.com/punzik/>"))))

;;; Convert arbitrary radix string in C-format to number
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

;;;
;;; Exported function
;;;
(define* (config-file->verilog file #:key (module-name #f) (registered #f))
  (config->verilog
   (parse-config-file file module-name #f registered)))

(define* (config-file->c-header file #:key (module-name #f) (base #f))
  (config->c-header
   (parse-config-file file module-name base #f)))

(define* (config-file->text-doc file #:key (module-name #f) (base #f))
  (config->text-doc
   (parse-config-file file module-name base #f)))

;;;
;;; Main
;;;
(define (main args)
  (debug-disable 'backtrace)
  (let-values
      (((opts rest err)
        (parse-opts (cdr args)
                    '(("module" #\m) required)
                    '(("text" #\t) none)
                    '(("header" #\c) none)
                    '(("base" #\b) required)
                    '(("registered" #\r) none)
                    '(("help" #\h) none))))

    (if err
        (begin
          (error "Unknown option\n")
          (print-help (car args))
          (exit -1))

        (let ((opt-module (option-get opts "module"))
              (opt-text (option-get opts "text"))
              (opt-header (option-get opts "header"))
              (opt-base (option-get opts "base"))
              (opt-registered (option-get opts "registered"))
              (opt-help (option-get opts "help"))
              (opt-rest rest))

          (cond
           (opt-help
            (print-help (car args)))

           ((null? opt-rest)
            (print-help (car args))
            (error "No input files"))

           (else
            (let ((cfg (parse-config-file (car opt-rest)
                                          opt-module
                                          (string-c-radix->number opt-base)
                                          opt-registered)))
              (cond
               (opt-text
                (display (config->text-doc cfg)))
               (opt-header
                (display (config->c-header cfg)))
               (else
                (display (config->verilog cfg)))))))))))
