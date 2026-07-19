;;;; t/property-invariants-test.lisp
;;;;
;;;; Property-based invariants and micro-benchmarks built on cl-weave 0.8.0's
;;;; generative testing (`it-property`, `gen-*`) and `benchmark` facilities.
;;;; Generative tests exercise the boundary abstractions across a wide space of
;;;; randomized inputs -- reproducibly, via CL_WEAVE_PROPERTY_SEED -- to surface
;;;; latent edge-case bugs that fixed examples cannot.

(in-package #:cl-boundary-kit/test)

;;; Deterministic random: two sources seeded identically must agree, and every
;;; integer draw must land in [0, LIMIT).  This fuzzes the LCG state update and
;;; the `(mod state limit)` reduction for off-by-one / range escapes.
(it-property "deterministic-random-sources-agree-and-stay-in-integer-range"
    ((seed (gen-integer :min 0 :max 1000000))
     (limit (gen-integer :min 1 :max 4096))
     (draws (gen-integer :min 1 :max 24)))
  (let ((a (make-deterministic-random-source :seed seed))
        (b (make-deterministic-random-source :seed seed)))
    (dotimes (i draws)
      (let ((va (random-source-random a limit))
            (vb (random-source-random b limit)))
        (expect (= va vb) :to-be-truthy)
        (expect (and (integerp va) (<= 0 va) (< va limit)) :to-be-truthy)))))

;;; The real-limit branch scales STATE/MODULUS into [0, LIMIT); check it never
;;; reaches or exceeds LIMIT and never goes negative across many seeds.
(it-property "deterministic-random-real-draws-stay-below-the-limit"
    ((seed (gen-integer :min 0 :max 1000000))
     (limit (gen-integer :min 1 :max 4096))
     (draws (gen-integer :min 1 :max 24)))
  (let ((source (make-deterministic-random-source :seed seed))
        (real-limit (float limit 1.0d0)))
    (dotimes (i draws)
      (let ((v (random-source-random source real-limit)))
        (expect (and (realp v) (<= 0 v) (< v real-limit)) :to-be-truthy)))))

;;; A recording boundary must record every invocation exactly once, in order,
;;; echoing the operation.  Running this over random operation streams also
;;; re-checks that the returned snapshot is an independent copy.
(it-property "recording-boundary-records-every-invocation-in-order"
    ((ops (gen-list (gen-keyword '("ping" "pong" "noop" "sync" "flush"))
                    :min-length 1 :max-length 12)))
  (let ((boundary (make-recording-boundary
                   :handler (lambda (operation &rest args)
                              (list :op operation :args args)))))
    (dolist (op ops)
      (recording-boundary-invoke boundary op 1 2))
    (let ((calls (recording-boundary-calls boundary)))
      (expect (= (length calls) (length ops)) :to-be-truthy)
      (expect (equal (mapcar (lambda (call) (getf call :operation)) calls) ops)
              :to-be-truthy)
      ;; Mutating the snapshot must not corrupt the boundary's own history.
      (when calls
        (setf (getf (first calls) :operation) :tampered)
        (expect (eq (getf (first (recording-boundary-calls boundary)) :operation)
                    (first ops))
                :to-be-truthy)))))

;;; Advancing a fake clock by an arbitrary list of non-negative deltas must be
;;; exactly additive and monotonic.
(it-property "fake-clock-advances-additively-and-monotonically"
    ((start (gen-integer :min 0 :max 100000))
     (deltas (gen-list (gen-integer :min 0 :max 500) :min-length 0 :max-length 16)))
  (let ((clock (make-fake-clock :start start))
        (expected start))
    (expect (= (clock-now clock) start) :to-be-truthy)
    (dolist (delta deltas)
      (advance-fake-clock clock delta)
      (incf expected delta)
      (expect (= (clock-now clock) expected) :to-be-truthy))))

;;; The native filesystem must round-trip arbitrary UTF-8 content unchanged.
;;; This directly fuzzes the multibyte read fix (FILE-LENGTH counts octets, so
;;; a naive buffer over-allocates for non-ASCII text).
(it-property "native-filesystem-round-trips-arbitrary-utf8-content"
    ((content (gen-string :min-length 0 :max-length 48
                          :alphabet "aeiouzZ09
	caf\U000000E9\U000003BB\U0001F600\U00002603")))
  (let* ((directory (merge-pathnames #P"cl-boundary-kit-property/"
                                     (uiop:temporary-directory)))
         (path (merge-pathnames #P"content.txt" directory))
         (fs (make-filesystem)))
    (ensure-directories-exist directory)
    (unwind-protect
         (progn
           (filesystem-store-file fs path content :external-format :utf-8)
           (let ((read-back (filesystem-read-file fs path :external-format :utf-8)))
             (expect (string= read-back content) :to-be-truthy)
             (expect (= (length read-back) (length content)) :to-be-truthy)))
      (ignore-errors (delete-file path))
      (ignore-errors (uiop:delete-empty-directory directory)))))

;;; Demonstrate cl-weave's benchmark facility on the recording hot path.  The
;;; assertion is structural (sample count), not wall-clock, so it stays stable
;;; in CI while still exercising the measurement API end to end.
(it "recording-boundary-invocation-is-benchmarkable"
  (let* ((boundary (make-recording-boundary
                    :handler (lambda (operation &rest args)
                               (declare (ignore args))
                               operation)))
         (result (benchmark (:warmup 1 :samples 5 :iterations 50)
                   (recording-boundary-invoke boundary :ping 1 2))))
    (expect (= 5 (length (benchmark-result-samples result))) :to-be-truthy)))

;;; Security (generative): the Prolog parser must bound *every* untrusted input.
;;; For arbitrarily deep nesting it either parses within the configured limits
;;; or rejects with a catchable, bounded `prolog-parser-resource-error` -- never
;;; hanging, overflowing the control stack, or raising an unbounded condition.
(it-property "untrusted-nested-prolog-source-is-always-bounded-by-parser-limits"
    ((depth (gen-integer :min 1 :max 80)))
  (let ((source (with-output-to-string (stream)
                  (dotimes (i depth) (write-string "f(" stream))
                  (write-string "x" stream)
                  (dotimes (i depth) (write-string ")" stream))))
        (cl-prolog:*max-prolog-parser-depth* 16)
        (cl-prolog:*max-prolog-tokens* 64))
    (handler-case
        ;; Parsed within limits: a well-formed term is returned.
        (expect (cl-prolog:read-prolog-term source) :to-be-truthy)
      (cl-prolog:prolog-parser-resource-error (condition)
        ;; Rejected: the failure is bounded and carries a positive limit.
        (expect (plusp (cl-prolog:prolog-parser-resource-error-limit condition))
                :to-be-truthy)))))

;;; Mutation testing (cl-weave): verify our test oracles are strong enough to
;;; catch injected faults.  The boundary-value oracle for an in-range predicate
;;; -- the same shape the deterministic-random property tests rely on -- must
;;; kill every mutant the arithmetic/comparison/boolean operators can inject.
(it "in-range-oracle-kills-every-injected-mutant"
  (let ((results
          (cl-weave:run-mutations
           '(lambda (value limit) (and (<= 0 value) (< value limit)))
           (lambda (form mutation)
             (declare (ignore mutation))
             ;; A faithful in-range predicate accepts 0 and LIMIT-1 and rejects
             ;; -1 and LIMIT.  A mutant survives only if it still does all four.
             (let ((predicate (eval form)))
               (and (funcall predicate 0 5)
                    (funcall predicate 4 5)
                    (not (funcall predicate -1 5))
                    (not (funcall predicate 5 5))))))))
    (expect (cl-weave:assert-mutation-score results 1.0) :to-be-truthy)))
