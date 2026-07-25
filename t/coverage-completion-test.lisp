;;;; t/coverage-completion-test.lisp
;;;;
;;;; Direct unit tests that exercise the individual decision branches of the
;;;; internal helpers, so every logic path (branch coverage) is taken. These
;;;; complement the boundary-level behaviour tests, which drive the happy paths
;;;; but do not reach every predicate rejection arm.

(in-package #:cl-boundary-kit/test)

;;; --- network redaction shape predicates and dispatch -------------------

(it "redact-network-value-traverses-every-supported-shape"
  (flet ((redact (value) (cl-boundary-kit::%redact-network-value value)))
    (with-soft-assertions
      ;; atom pass-through
      (expect (redact 42) :to-be 42)
      ;; sensitive plist key redacted, ordinary key kept
      (expect (equal (redact '(:authorization "s" :accept "j"))
                     '(:authorization :redacted :accept "j"))
              :to-be-truthy)
      ;; sensitive alist key redacted
      (expect (equal (redact '((:token . "s") (:ok . "j")))
                     '((:token . :redacted) (:ok . "j")))
              :to-be-truthy)
      ;; proper list of scalars traversed element-wise
      (expect (equal (redact '("a" "b")) '("a" "b")) :to-be-truthy)
      ;; odd-length "plist" fails the plist predicate and is treated as a list
      (expect (equal (redact '(:a 1 :b)) '(:a 1 :b)) :to-be-truthy)
      ;; a non-symbol/string key fails the plist and alist predicates
      (expect (equal (redact '(1 2)) '(1 2)) :to-be-truthy)
      ;; dotted pair rebuilt through the fallback arm
      (expect (equal (redact '(1 . 2)) '(1 . 2)) :to-be-truthy))))

(it "network-shape-predicates-reject-malformed-structure"
  (with-soft-assertions
    (expect (cl-boundary-kit::%network-plist-p '(:a 1 :b 2)) :to-be-truthy)
    (expect (cl-boundary-kit::%network-plist-p '(:a 1 :b)) :to-be nil)  ; odd
    (expect (cl-boundary-kit::%network-plist-p '(1 2)) :to-be nil)      ; bad key
    (expect (cl-boundary-kit::%network-alist-p '((:a . 1))) :to-be-truthy)
    (expect (cl-boundary-kit::%network-alist-p '(1 2)) :to-be nil)      ; entry not a cons
    (expect (cl-boundary-kit::%network-alist-p '((1 . 2))) :to-be nil)  ; key not symbol/string
    (expect (cl-boundary-kit::%proper-list-p '(1 2 3)) :to-be-truthy)
    (expect (cl-boundary-kit::%proper-list-p '(1 . 2)) :to-be nil)))

(it "network-sensitive-field-p-classifies-key-kinds"
  (expect (cl-boundary-kit::%network-sensitive-field-p :authorization) :to-be-truthy)
  (expect (cl-boundary-kit::%network-sensitive-field-p "Authorization") :to-be-truthy)
  (expect (cl-boundary-kit::%network-sensitive-field-p :accept) :to-be nil)
  ;; the non-symbol/non-string arm returns NIL
  (expect (cl-boundary-kit::%network-sensitive-field-p 42) :to-be nil))

;;; --- environment value/presence extraction and normalization ----------

(it "environment-value-from-call-covers-every-arm"
  (flet ((v (values default) (cl-boundary-kit::%environment-value-from-call values default)))
    (expect (v '() :d) :to-be :d)                 ; no values -> default
    (expect (v '(:x t) :d) :to-be :x)             ; present-p secondary true -> value
    (expect (v '(:x nil) :d) :to-be :d)           ; present-p secondary nil -> default
    (expect (v '(nil) :d) :to-be :d)              ; single NIL value -> default
    (expect (v '(:x) :d) :to-be :x)))             ; single non-nil value -> value

(it "environment-presence-from-call-covers-every-arm"
  (flet ((p (values) (cl-boundary-kit::%environment-presence-from-call values)))
    (expect (p '()) :to-be nil)                   ; no values -> absent
    (expect (p '(:x t)) :to-be-truthy)            ; explicit present-p secondary
    (expect (p '(:x)) :to-be-truthy)              ; single non-nil -> present
    (expect (p '(nil)) :to-be nil)))              ; single NIL -> absent

(it "normalize-environment-values-cps-covers-empty-alist-and-plist-inputs"
  (flet ((n (input) (cl-boundary-kit::%normalize-environment-values-cps input #'identity)))
    (expect (n '()) :to-be nil)                                   ; empty
    (expect (equal (n '((:a . 1))) '((:a . 1))) :to-be-truthy)   ; already an alist
    (expect (equal (n '(:a 1 :b 2)) '((:a . 1) (:b . 2))) :to-be-truthy))  ; plist -> alist
  (signals-error-message-contains "INITIAL-VALUES must be an alist or plist"
    (cl-boundary-kit::%normalize-environment-values-cps '(:a 1 :b) #'identity)))  ; odd

;;; --- args-nth and random validation branches --------------------------

(it "args-nth-rejects-a-non-integer-or-negative-index"
  (let ((args (make-test-args :arguments (list "a" "b"))))
    (signals-error-message-contains "ARGS-NTH index must be a non-negative integer"
      (args-nth args -1))
    (signals-error-message-contains "ARGS-NTH index must be a non-negative integer"
      (args-nth args :bad))
    ;; out-of-range returns NIL rather than signaling
    (expect (args-nth args 9) :to-be nil)))

(it "random-source-random-rejects-a-non-positive-limit"
  (let ((source (make-random-source)))
    (signals-error-message-contains "limit must be positive"
      (random-source-random source 0))
    (signals-error-message-contains "limit must be positive"
      (random-source-random source -5))))

;;; --- test-filesystem entry helpers ------------------------------------

(it "copy-test-file-content-copies-strings-and-passes-other-values-through"
  (let ((original "abc"))
    (expect (equal (cl-boundary-kit::%copy-test-file-content original) "abc") :to-be-truthy)
    ;; a copy, not the same object
    (expect (eq (cl-boundary-kit::%copy-test-file-content original) original) :to-be nil))
  ;; non-string content passes through unchanged (the else arm)
  (expect (cl-boundary-kit::%copy-test-file-content 42) :to-be 42))

(it "directory-path-prefix-normalizes-empty-slash-and-bare-directories"
  (flet ((p (d) (cl-boundary-kit::%directory-path-prefix d)))
    (expect (equal (p "") "") :to-be-truthy)             ; empty stays empty
    (expect (equal (p "/a/b/") "/a/b/") :to-be-truthy)   ; already slash-terminated
    (expect (equal (p "/a/b") "/a/b/") :to-be-truthy)))  ; slash appended

;;; --- metric and rate-limiter validation -------------------------------

(it "metrics-count-and-timing-validate-their-arguments"
  (let ((metrics (make-test-metrics)))
    (signals-error-message-contains "Metric name must be a non-nil symbol or a string"
      (metrics-count metrics 42 1))
    (signals-error-message-contains "must be a real number"
      (metrics-count metrics "hits" :bad))
    (signals-error-message-contains "Metric timing milliseconds must be a non-negative real number"
      (metrics-timing metrics "latency" -1))))

(it "make-test-rate-limiter-validates-capacity-and-refill-rate"
  (signals-error-message-contains "Rate limiter capacity must be a positive real number"
    (make-test-rate-limiter :capacity 0))
  (signals-error-message-contains "Rate limiter refill rate must be a non-negative real number"
    (make-test-rate-limiter :refill-rate -1)))

;;; --- validation guards: exercise each AND/OR operand's false branch ----

(it "random-source-random-rejects-a-non-real-limit"
  ;; Complements the non-positive-limit test: here REALP itself fails, taking
  ;; the other branch of the (and (realp limit) (> limit 0)) guard.
  (signals-error-message-contains "limit must be positive"
    (random-source-random (make-random-source) "not-a-number")))

(it "make-deterministic-random-source-rejects-non-integer-and-too-small-moduli"
  (signals-error-message-contains "modulus must be an integer greater than 1"
    (make-deterministic-random-source :modulus 1))       ; integer but not > 1
  (signals-error-message-contains "modulus must be an integer greater than 1"
    (make-deterministic-random-source :modulus 3.5)))    ; not an integer

(it "metrics-count-rejects-a-nil-symbol-name"
  ;; NIL is a symbol, so it takes the (and (symbolp name) name) arm where the
  ;; second conjunct is false.
  (signals-error-message-contains "Metric name must be a non-nil symbol or a string"
    (metrics-count (make-test-metrics) nil 1)))

(it "make-test-rate-limiter-rejects-non-real-capacity-and-refill-rate"
  (signals-error-message-contains "capacity must be a positive real number"
    (make-test-rate-limiter :capacity :not-real))
  (signals-error-message-contains "refill rate must be a non-negative real number"
    (make-test-rate-limiter :refill-rate :not-real)))
