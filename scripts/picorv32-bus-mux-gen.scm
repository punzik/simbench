#!/usr/bin/env -S guile -e "main" -s
!#

;; -*- geiser-scheme-implementation: guile -*-

(add-to-load-path (dirname (current-filename)))

(import
 (srfi srfi-1)                          ; Lists
 (srfi srfi-11)                         ; let-values
 (srfi srfi-28)                         ; Simple format
 (common)
 (optargs))

;;; Default address width
(define ADDR_WIDTH 32)

;;; Default data width
(define DATA_WIDTH 32)

;;; Count of indentation spaces
(define INDENT 2)

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

;;; Print to stderr
(define (warning . rest)
  (display "Warning: " (current-error-port))
  (display (apply format rest) (current-error-port))
  (newline (current-error-port)))

(define (error . rest)
  (display "Error: " (current-error-port))
  (display (apply format rest) (current-error-port))
  (newline (current-error-port)))

(define (error-and-exit . rest)
  (apply error rest)
  (exit EXIT_FAILURE))

;;; Println with indentationm
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

(define (-> . fmt)
  (apply ->> fmt)
  (newline))

;;;
;;; ----------------------------------------------------------------------
;;; -------------------------- VERILOG BACKEND ---------------------------
;;; ----------------------------------------------------------------------
;;;

;;; Print module header
(define (print-verilog-module-header slaves module-name)
  (let ((slaves-count (length slaves)))
    (-> 0 "// This file is auto-generated. Do not edit")
    (->)
    (-> 0 "// Slaves address ranges:")
    (for-each
     (lambda (slave n)
       (let ((b (car slave))
             (s (cdr slave)))
         (-> 0 "//   ~a - 0x~a-0x~a"
             n
             (number->string-hex b (/ ADDR_WIDTH 4))
             (number->string-hex (- (+ b s) 1) (/ ADDR_WIDTH 4)))))
     slaves
     (iota slaves-count))
    (->)
    (-> 0 "// i_slave_rdata bits:")
    (for-each
     (lambda (n)
       (-> 0 "//   ~a: i_slave_rdata[~a:~a]"
           n
           (- (* (+ n 1) DATA_WIDTH) 1)
           (* n DATA_WIDTH)))
     (iota slaves-count))
    (->)
    (-> 0 "module ~a" module-name)
    (-> 1 "(input wire clock,")
    (-> 1 " input wire reset,")
    (->)
    (-> 1 " // PicoRV32 memory interface")
    (-> 1 " // Look-ahead address and multiplexed signals")
    (-> 1 " // Some bits of address may not be used")
    (-> 1 " /* verilator lint_off UNUSED */")
    (-> 1 " input wire [~a:0] i_la_addr," (- ADDR_WIDTH 1))
    (-> 1 " /* verilator lint_on UNUSED */")
    (-> 1 " output wire [~a:0] o_rdata," (- DATA_WIDTH 1))
    (-> 1 " input wire i_valid,")
    (-> 1 " output wire o_ready,")
    (->)
    (-> 1 " // Slaves interface")
    (-> 1 " input wire [~a:0] i_slave_rdata," (- (* slaves-count DATA_WIDTH) 1))
    (-> 1 " output wire [~a:0] o_slave_valid," (- slaves-count 1))
    (-> 1 " input wire [~a:0] i_slave_ready);" (- slaves-count 1))
    (->)))

;;; Print module footer
(define (print-verilog-module-footer module-name)
  (-> 0 "endmodule // ~a" module-name)
  (-> 0 "`default_nettype wire"))

;;; Print selectors
(define (print-verilog-selectors slaves)
  (let ((count (length slaves))
        (addrs (map car slaves)))

    (-> 1 "wire [~a:0] selector;" (- count 1))
    (-> 1 "reg [~a:0] selector_reg;" (- count 1))
    (->)
    (-> 1 "always @(posedge clock)")
    (-> 2 "if (reset)")
    (-> 3 "selector_reg <= ~a'd0;" count)
    (-> 2 "else")
    (-> 3 "if (!i_valid)")
    (-> 4 "selector_reg <= selector;")
    (->)

    (let ((selectors (make-mux-selectors addrs)))
      (for-each
       (lambda (addr n)
         (let ((selector (cdr (assq addr selectors))))
           (if (every not selector)
               (-> 1 "assign selector[~a] = 1'b1;" n)
               (begin
                 (-> 1 "assign selector[~a] =" n)
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
                                       (->> 2 "i_la_addr[~a] == 1'b~a" n bit)
                                       #t)
                                     need-and-sign))))))
                 (-> ";")))
           (->)))
       addrs (iota count)))))

;;; Print one range body
(define (print-verilog-body slaves)
  (let ((slaves-count (length slaves)))
    (-> 1 "assign o_slave_valid = selector_reg & {~a{i_valid}};" slaves-count)
    (-> 1 "assign o_ready = |(i_slave_ready & selector_reg);")
    (->)
    (-> 1 "assign o_rdata =")
    (for-each
     (lambda (n)
       (->> 2 "(i_slave_rdata[~a:~a] & {~a{selector_reg[~a]}})"
            (- (* DATA_WIDTH (+ n 1)) 1)
            (* DATA_WIDTH n)
            DATA_WIDTH
            n)
       (-> "~a" (if (= n (- slaves-count 1)) ";" " |")))
     (iota slaves-count))
    (->)))

;;; Print formal
(define (print-verilog-formal slaves module-name)
  (let ((slaves-count (length slaves)))
    (-> 0 "`ifdef FORMAL")
    (->)

    (-> 1 "always @(*) begin : formal_selector")
    (-> 2 "integer ones, n;")
    (-> 2 "ones = 0;")
    (->)
    (-> 2 "// Check for selector is zero or one-hot value")
    (-> 2 "for (n = 0; n < ~a; n = n + 1)" slaves-count)
    (-> 3 "if (selector[n] == 1'b1)")
    (-> 4 "ones = ones + 1;")
    (->)
    (-> 2 "assert(ones < 2);")
    (->)
    (-> 2 "// Check for correct address ranges decode")
    (for-each
     (lambda (slave n)
       (let ((b (car slave))
             (s (cdr slave)))
         (-> 2 "if (i_la_addr >= ~a'h~a && i_la_addr <= ~a'h~a)"
             ADDR_WIDTH (number->string b 16)
             ADDR_WIDTH (number->string (- (+ b s) 1) 16))
         (-> 3 "assert(selector[~a] == 1'b1);" n)))
     slaves
     (iota slaves-count))
    (-> 1 "end")
    (->)

    (-> 1 "// Check multiplexer")
    (-> 1 "always @(*) begin : formal_mux")
    (-> 2 "case (selector_reg)")
    (for-each
     (lambda (n)
       (-> 3 "~a'b~a: begin"
           slaves-count
           (list->string
            (map (lambda (x) (if (= x n) #\1 #\0))
                 (reverse (iota slaves-count)))))
       (-> 4 "assert(o_rdata == i_slave_rdata[~a:~a]);"
           (- (* (+ n 1) DATA_WIDTH) 1)
           (* n DATA_WIDTH))
       (-> 4 "assert(o_ready == i_slave_ready[~a]);" n)
       (-> 4 "assert(o_slave_valid[~a] == i_valid);" n)
       (-> 3 "end")
       )
     (iota slaves-count))
    (-> 3 "~a'b~a: begin" slaves-count (make-string slaves-count #\0))
    (-> 4 "assert(o_rdata == ~a'd0);" DATA_WIDTH)
    (-> 4 "assert(o_ready == 1'b0);")
    (-> 4 "assert(o_slave_valid == ~a'd0);" slaves-count)
    (-> 3 "end")
    (-> 2 "endcase")
    (-> 1 "end")
    (->)

    (-> 1 "// Assume module is not in reset state")
    (-> 1 "always @(*) assume(reset == 1'b0);")
    (->)
    (-> 1 "// Make flag that the past is valid")
    (-> 1 "reg have_past = 1'b0;")
    (-> 1 "always @(posedge clock) have_past <= 1'b1;")
    (->)
    (-> 1 "// Check for selector_reg is valid and stable when i_valid is 1")
    (-> 1 "always @(posedge clock) begin")
    (-> 2 "if (have_past)")
    (-> 3 "if (i_valid)")
    (-> 4 "if ($rose(i_valid))")
    (-> 5 "assert(selector_reg == $past(selector));")
    (-> 4 "else")
    (-> 5 "assert($stable(selector_reg));")
    (-> 1 "end")
    (->)

    (-> 0 "`endif // FORMAL")
    (->)))

;;; Print verilog code for slaves
(define (print-verilog slaves module-name)
  (print-verilog-module-header slaves module-name)
  (print-verilog-selectors slaves)
  (print-verilog-body slaves)
  (print-verilog-formal slaves module-name)
  (print-verilog-module-footer module-name))

(define (print-sby-script module-name)
  (-> "# To run formal verification call SymbiYosys:")
  (-> "# $ sby -f ~a.sby" module-name)
  (->)
  (-> "[options]")
  (-> "mode prove")
  (->)
  (-> "[engines]")
  (-> "smtbmc boolector")
  (->)
  (-> "[script]")
  (-> "read -vlog95 -formal ~a.v" module-name)
  (-> "prep -top ~a" module-name)
  (->)
  (-> "[files]")
  (-> "~a.v" module-name))

;;;
;;; Main
;;;

;;; Check for slave address ranges for intersection
(define (slaves-intersected? slaves)
  (let ((sorted (sort slaves (lambda (a b) (< (car a) (car b))))))
    (let check ((slave (car sorted))
                (slaves (cdr sorted)))
      (if (null? slaves)
          #f
          (let ((next (car slaves)))
            (let ((b0 (car slave))
                  (s0 (cdr slave))
                  (b1 (car next)))
              (if (> (+ b0 s0) b1)
                  #t
                  (check next (cdr slaves)))))))))

(define (print-help app-name)
  (with-output-to-port (current-error-port)
    (lambda ()
      (-> "Usage: ~a [OPTION]... [FILE]" app-name)
      (-> "Make verilog module of PicoRV bus multiplexer.")
      (-> "Optional FILE - is an address spaces description file.")
      (-> "")
      (-> "Options:")
      (-> "  -s, --slave ADDRESS_RANGE     Add slave address range")
      (-> "  -m, --module MODULE_NAME      Verilog module name (optional)")
      (-> "  -f, --formal                  Print script (sby) for SymbiYosys")
      (-> "  -h, --help                    Print this message and exit")
      (-> "")
      (-> "Where ADDRESS_RANGE is string of BASE_ADDRESS+LENGTH")
      (-> "")
      (-> "Generate mux for two address ranges [0..0x0fff] and [0x1000..0x1fff]:")
      (-> "  ~a -s 0x0+0x1000 -s 0x1000+0x1000" app-name)
      (-> "")
      (-> "If FILE is specified --slave (-s) option will ignored.")
      (-> "")
      (-> "Source code and issue tracker: <https://github.com/punzik/>"))))


(define (main args)
  (debug-disable 'backtrace)
  (let-values
      (((opts rest err)
        (parse-opts (cdr args)
                    '(("slave" #\s) multiple)
                    '(("module" #\m) required)
                    '(("help" #\h) none)
                    '(("formal" #\f) none))))

    (if err
        (begin
          (error "Unknown option\n")
          (print-help (car args))
          (exit -1))

        (let ((slaves (option-get opts "slave"))
              (mod-name (option-get opts "module"))
              (help (option-get opts "help"))
              (formal (option-get opts "formal"))
              (file-name (if (null? rest) #f (car rest))))

          (if (or help (not slaves))
              (print-help (car args))
              (let-values
                  (((slaves mod-name)
                    (if file-name
                        ;; Read config from file
                        (let ((cfg (with-input-from-file file-name read)))
                          (values
                           (map (lambda (sl) (cons (car sl) (cadr sl)))
                                (filter list? cfg))
                           (if mod-name
                               mod-name
                               (find string? cfg))))
                        ;; Use arguments
                        (values
                         (sort
                          (map (lambda (slave-opt)
                                 (let ((base+size (string-split slave-opt #\+)))
                                   (if (not (= (length base+size) 2))
                                       (error-and-exit "Wrong slave format")
                                       (let ((base (string-c-radix->number (first base+size)))
                                             (size (string-c-radix->number (second base+size))))
                                         (if (not (and base size))
                                             (error-and-exit "Wrong address/size number format '~a+~a'" base size)
                                             (cons base size))))))
                               slaves)
                          (lambda (a b) (< (car a) (car b))))
                         mod-name))))

                (let ((module-name
                       (if mod-name
                           mod-name
                           (format "picorv32_busmux_1x~a" (length slaves)))))

                  ;; Check slaves integrity
                  (cond
                   ;; Address space size is zero
                   ((any (lambda (slave) (zero? (cdr slave))) slaves)
                    (error-and-exit "Address space size is zero"))

                   ;; Address space size is not power of two
                   ((any (lambda (slave) (not (power-of-two? (cdr slave)))) slaves)
                    (error-and-exit "Address space size is not power of two"))

                   ;; Base address is not divisible by address space size
                   ((any (lambda (slave) (not
                                     (zero?
                                      (remainder (car slave)
                                                 (cdr slave)))))
                         slaves)
                    (error-and-exit "Base address is not divisible by address space size"))

                   ;; Address range is not in range of 2^ADDR_WIDTH
                   ((any (lambda (slave)
                           (> (+ (car slave) (cdr slave))
                              (expt 2 ADDR_WIDTH)))
                         slaves)
                    (error-and-exit "Slave address is out of ~a bit range" ADDR_WIDTH))

                   ;; Address ranges intersected
                   ((slaves-intersected? slaves)
                    (error-and-exit "Slave address ranges is intersected"))

                   ;; All OK
                   (else
                    (if formal
                        (print-sby-script module-name)
                        (print-verilog slaves module-name)))))))))))
