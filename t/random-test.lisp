;;;; t/random-test.lisp

(in-package #:cl-boundary-kit/test)

(it "deterministic-random-source-is-repeatable"
  (let ((source-a (make-deterministic-random-source :seed 42))
        (source-b (make-deterministic-random-source :seed 42)))
    (expect (= (random-source-random source-a 1000)
           (random-source-random source-b 1000)) :to-be-truthy)
    (expect (= (random-source-random source-a 1000)
           (random-source-random source-b 1000)) :to-be-truthy)))

(it "random-source-produces-bounded-values"
  (let ((source (make-random-source :state (make-random-state t))))
    (expect (< (random-source-random source 10) 10) :to-be-truthy)
    (expect (>= (random-source-random source 10) 0) :to-be-truthy)))

(it "random-source-rejects-invalid-state"
  (signals error
    (make-random-source :state 42))
  (signals error
    (make-random-source :state "not-a-random-state")))

(it "random-source-rejects-non-positive-limits"
  (let ((source (make-random-source :state (make-random-state t))))
    (signals error
      (random-source-random source 0))
    (signals error
      (random-source-random source -5))
    (signals error
      (random-source-random source 0.0d0))
    (signals error
      (random-source-random source -1.5d0))))

(it "deterministic-random-source-supports-real-limits"
  (let ((source (make-deterministic-random-source :seed 7))
        (limit 1.5d0))
    (let ((value (random-source-random source limit)))
      (expect (realp value) :to-be-truthy)
      (expect (>= value 0.0d0) :to-be-truthy)
      (expect (< value limit) :to-be-truthy))))

(it "deterministic-random-source-real-limit-stays-below-limit"
  ;; Regression: a real limit must stay strictly below LIMIT even when the
  ;; internal state reaches its maximum value (MODULUS-1). With MODULUS 2 the
  ;; odd LCG multiplier makes the state alternate 0,1,0,1..., so the maximum
  ;; state is guaranteed to be exercised within a few steps.
  (let ((source (make-deterministic-random-source :seed 1 :modulus 2))
        (limit 1.0d0))
    (dotimes (i 8)
      (let ((value (random-source-random source limit)))
        (expect (>= value 0.0d0) :to-be-truthy)
        (expect (< value limit) :to-be-truthy)))))

(it "deterministic-random-source-rejects-invalid-modulus"
  (signals error
    (make-deterministic-random-source :seed 1 :modulus 1))
  (signals error
    (make-deterministic-random-source :seed 1 :modulus 0))
  (signals error
    (make-deterministic-random-source :seed 1 :modulus 1.5d0)))

(it "deterministic-random-source-rejects-non-positive-limits"
  (let ((source (make-deterministic-random-source :seed 9)))
    (signals error
      (random-source-random source 0))
    (signals error
      (random-source-random source -5))
    (signals error
      (random-source-random source 0.0d0))
    (signals error
      (random-source-random source -1.5d0))))

(it "test-random-source-consumes-queued-values"
  (let ((source (make-test-random-source :values '(3 1 0))))
    (expect (= 3 (random-source-random source 10)) :to-be-truthy)
    (expect (= 1 (random-source-random source 10)) :to-be-truthy)
    (expect (= 0 (random-source-random source 10)) :to-be-truthy)))

(it "test-random-source-supports-real-limits"
  (let ((source (make-test-random-source :values '(0.25d0 1.25d0))))
    (expect (= 0.25d0 (random-source-random source 1.0d0)) :to-be-truthy)
    (expect (= 1.25d0 (random-source-random source 1.5d0)) :to-be-truthy)))

(it "test-random-source-rejects-non-list-values"
  (signals error
    (make-test-random-source :values #(1 2 3))))

(it "test-random-source-signals-when-values-are-exhausted"
  (let ((source (make-test-random-source :values '(1))))
    (expect (= 1 (random-source-random source 10)) :to-be-truthy)
    (signals error
      (random-source-random source 10))))

(it "test-random-source-rejects-values-outside-the-requested-limit"
  (signals error
    (random-source-random (make-test-random-source :values '(10)) 10))
  (signals error
    (random-source-random (make-test-random-source :values '(-1)) 10))
  (signals error
    (random-source-random (make-test-random-source :values '(1.5d0)) 10))
  (signals error
    (random-source-random (make-test-random-source :values '(2.0d0)) 2.0d0)))

(it "recording-random-source-records-limit-and-result"
  (let* ((delegate (make-test-random-source :values '(3 7)))
         (source (make-recording-random-source :delegate delegate)))
    (expect (= (random-source-random source 10) 3) :to-be-truthy)
    (expect (= (random-source-random source 20) 7) :to-be-truthy)
    (expect (equal (recording-random-source-calls source)
               (list (boundary-call-plist :random (list 10) :result 3)
                     (boundary-call-plist :random (list 20) :result 7))) :to-be-truthy)))

(it "make-recording-random-source-defaults-to-a-real-delegate"
  (let ((source (make-recording-random-source)))
    (expect (< (random-source-random source 10) 10) :to-be-truthy)
    (expect (>= (random-source-random source 10) 0) :to-be-truthy)))

(it "make-recording-random-source-rejects-non-random-source-delegate"
  (signals error
    (make-recording-random-source :delegate :bad)))

(it "recording-random-source-calls-signals-for-unsupported-source-types"
  (signals error
    (recording-random-source-calls (make-random-source :state (make-random-state t)))))
