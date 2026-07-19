;;;; t/clock-test.lisp

(in-package #:cl-boundary-kit/test)

(it "fake-clock-advances"
  (let ((clock (make-fake-clock :start 10)))
    (expect (= (clock-now clock) 10) :to-be-truthy)
    (advance-fake-clock clock 7)
    (expect (= (clock-now clock) 17) :to-be-truthy)
    (expect (= (clock-monotonic clock) 17) :to-be-truthy)))

(it "fake-clock-supports-independent-monotonic-time"
  (let ((clock (make-fake-clock :start 10 :monotonic-start 100)))
    (expect (= (clock-now clock) 10) :to-be-truthy)
    (expect (= (clock-monotonic clock) 100) :to-be-truthy)
    (advance-fake-clock clock 7 :monotonic-delta 3)
    (expect (= (clock-now clock) 17) :to-be-truthy)
    (expect (= (clock-monotonic clock) 103) :to-be-truthy)))

;;; Regression: MAKE-FAKE-CLOCK's NOW-FN/MONOTONIC-FN closures used to close
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
