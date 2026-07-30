;;;; t/clock-test.lisp

(in-package #:cl-boundary-kit/test)

(it "fake-clock-advances"
  (let ((clock (make-fake-clock :start 10)))
    (expect (= (clock-now clock) 10) :to-be-truthy)
    (advance-fake-clock clock 7)
    (expect (= (clock-now clock) 17) :to-be-truthy)
    (expect (= (clock-monotonic clock) 17) :to-be-truthy)))

(it "fake-clock-supports-independent-monotonic-time" (let ((clock (make-fake-clock :start 10 :monotonic-start 100))) (expect (= (clock-now clock) 10) :to-be-truthy) (expect (= (clock-monotonic clock) 100) :to-be-truthy) (advance-fake-clock clock 7 :monotonic-delta 3) (expect (= (clock-now clock) 17) :to-be-truthy) (expect (= (clock-monotonic clock) 103) :to-be-truthy))) (it "fake-clock-defaults-wall-clock-start-independently"
  (let ((clock (apply (symbol-function 'make-fake-clock)
                      (list :monotonic-start 100))))
    (expect (= (clock-now clock) 0) :to-be-truthy)
    (expect (= (clock-monotonic clock) 100) :to-be-truthy))) ;;; Regression: MAKE-FAKE-CLOCK's NOW-FN/MONOTONIC-FN closures used to close
;;; over the initial START/MONOTONIC-START values instead of reading the
;;; mutable slots, so CLOCK-NOW-FN/CLOCK-MONOTONIC-FN (the public readers
;;; inherited from CLOCK) stayed frozen at construction time even after
;;; ADVANCE-FAKE-CLOCK, diverging from CLOCK-NOW/CLOCK-MONOTONIC.
(it "fake-clock-now-fn-and-monotonic-fn-track-advances"
  (let ((clock (make-fake-clock :start 10)))
    (advance-fake-clock clock 7)
    (expect (= (funcall (cl-boundary-kit::clock-now-fn clock)) 17) :to-be-truthy)
    (expect (= (funcall (cl-boundary-kit::clock-monotonic-fn clock)) 17) :to-be-truthy)))

(it "real-clock-is-available"
  (let ((clock (make-clock)))
    (expect (numberp (clock-now clock)) :to-be-truthy)
    (expect (numberp (clock-monotonic clock)) :to-be-truthy)))

(it "make-clock-rejects-non-function-collaborators"
  (signals error
    (make-clock :now-fn :bad))
  (signals error
    (make-clock :monotonic-fn :bad)))

;;; Regression: MAKE-FAKE-CLOCK/ADVANCE-FAKE-CLOCK performed no validation of
;;; their numeric arguments, unlike every sibling fake/test constructor
;;; (MAKE-DETERMINISTIC-RANDOM-SOURCE's modulus, MAKE-TEST-RANDOM-SOURCE's
;;; values). A non-number silently "succeeded" at construction time and only
;;; surfaced a confusing TYPE-ERROR later, deep in whatever arithmetic a
;;; caller did with the bad CLOCK-NOW/CLOCK-MONOTONIC result.
(it "make-fake-clock-rejects-non-number-start-values"
  (signals error
    (make-fake-clock :start "not-a-number"))
  (signals error
    (make-fake-clock :monotonic-start "not-a-number")))

(it "advance-fake-clock-rejects-non-number-deltas"
  (let ((clock (make-fake-clock)))
    (signals error
      (advance-fake-clock clock "not-a-number"))
    (signals error
      (advance-fake-clock clock 1 :monotonic-delta "not-a-number"))))

(it "call-with-elapsed-returns-the-result-and-monotonic-duration"
  (let ((clock (make-fake-clock :start 0 :monotonic-start 100)))
    (multiple-value-bind (result elapsed)
        (call-with-elapsed clock
                           (lambda () (advance-fake-clock clock 5 :monotonic-delta 7) :done))
      (expect (eq :done result) :to-be-truthy)
      (expect (= 7 elapsed) :to-be-truthy))))

(it "call-with-elapsed-reports-zero-when-the-clock-does-not-advance"
  (let ((clock (make-fake-clock :start 0)))
    (multiple-value-bind (result elapsed)
        (call-with-elapsed clock (lambda () :done))
      (expect (eq :done result) :to-be-truthy)
      (expect (= 0 elapsed) :to-be-truthy))))

(it "call-with-elapsed-rejects-a-non-function-thunk" (signals error (call-with-elapsed (make-fake-clock) :bad))) (it "fake-clock-defaults-start-when-monotonic-start-is-supplied" (let ((clock (make-fake-clock :monotonic-start 100))) (expect (= (clock-now clock) 0) :to-be-truthy) (expect (= (clock-monotonic clock) 100) :to-be-truthy)))
