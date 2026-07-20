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

(it "reset-recording-random-source-calls-clears-history-and-returns-the-source"
  (let ((source (make-recording-random-source :delegate (make-test-random-source :values '(1 2)))))
    (random-source-random source 10)
    (expect (= (length (recording-random-source-calls source)) 1) :to-be-truthy)
    (expect (eq (reset-recording-random-source-calls source) source) :to-be-truthy)
    (expect (null (recording-random-source-calls source)) :to-be-truthy)))

(it "reset-recording-random-source-calls-signals-for-unsupported-source-types"
  (signals error
    (reset-recording-random-source-calls (make-random-source :state (make-random-state t)))))

(it "random-source-element-picks-an-element-by-the-drawn-index"
  (let ((source (make-test-random-source :values '(0 2))))
    (expect (eq :a (random-source-element source #(:a :b :c))) :to-be-truthy)
    (expect (eq :c (random-source-element source '(:a :b :c))) :to-be-truthy)))

(it "random-source-element-rejects-an-empty-sequence"
  (signals error
    (random-source-element (make-test-random-source :values '(0)) #())))

(it "random-source-boolean-maps-a-two-value-draw-to-a-boolean"
  (let ((source (make-test-random-source :values '(0 1))))
    (expect (eq t (random-source-boolean source)) :to-be-truthy)
    (expect (null (random-source-boolean source)) :to-be-truthy)))

(it "random-source-element-on-a-recording-source-records-the-integer-draw"
  (let ((source (make-recording-random-source
                 :delegate (make-test-random-source :values '(1)))))
    (expect (eq :b (random-source-element source #(:a :b :c))) :to-be-truthy)
    (expect (equal (recording-random-source-calls source)
                   (list (boundary-call-plist :random (list 3) :result 1))) :to-be-truthy)))

(it "random-source-shuffle-permutes-deterministically-without-mutating-the-input"
  ;; Fisher-Yates draws limits 3 then 2 (for a length-3 sequence). With draws
  ;; 0 and 0 the resulting order is fully determined.
  (let* ((source (make-test-random-source :values '(0 0)))
         (input (list :a :b :c))
         (result (random-source-shuffle source input)))
    (expect (equal (list :b :c :a) result) :to-be-truthy)
    ;; The input list is left untouched.
    (expect (equal (list :a :b :c) input) :to-be-truthy)))

(it "random-source-shuffle-preserves-the-sequence-type-and-handles-empty-input"
  (let ((source (make-test-random-source :values '(0 0))))
    (expect (vectorp (random-source-shuffle source #(:a :b :c))) :to-be-truthy))
  (expect (null (random-source-shuffle (make-test-random-source) '())) :to-be-truthy))

(it "random-source-bytes-draws-a-byte-vector-deterministically"
  (let* ((source (make-test-random-source :values '(0 255 128)))
         (bytes (random-source-bytes source 3)))
    (expect (typep bytes '(simple-array (unsigned-byte 8) (*))) :to-be-truthy)
    (expect (equalp #(0 255 128) bytes) :to-be-truthy)))

(it "random-source-bytes-with-count-zero-returns-an-empty-vector"
  (expect (zerop (length (random-source-bytes (make-test-random-source) 0))) :to-be-truthy))

(it "random-source-bytes-rejects-a-negative-count"
  (signals error
    (random-source-bytes (make-test-random-source) -1)))

(it "random-source-sample-draws-distinct-elements-deterministically"
  ;; Partial Fisher-Yates for count 2 over a length-3 sequence draws limits 3
  ;; then 2. Draws 0 and 0 pick index 0 then index 1.
  (let* ((source (make-test-random-source :values '(0 0)))
         (result (random-source-sample source #(:a :b :c) 2)))
    (expect (equal (list :a :b) result) :to-be-truthy)))

(it "random-source-sample-handles-the-boundary-counts"
  (expect (null (random-source-sample (make-test-random-source) #(:a :b :c) 0)) :to-be-truthy)
  (let ((source (make-test-random-source :values '(0 0 0))))
    (expect (= 3 (length (random-source-sample source #(:a :b :c) 3))) :to-be-truthy)))

(it "random-source-sample-rejects-an-out-of-range-count"
  (signals error
    (random-source-sample (make-test-random-source) #(:a :b) 3))
  (signals error
    (random-source-sample (make-test-random-source) #(:a :b) -1)))
