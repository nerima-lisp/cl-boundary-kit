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

(it "real-clock-is-available"
  (let ((clock (make-clock)))
    (expect (numberp (clock-now clock)) :to-be-truthy)
    (expect (numberp (clock-monotonic clock)) :to-be-truthy)))

(it "make-clock-rejects-non-function-collaborators"
  (signals error
    (make-clock :now-fn :bad))
  (signals error
    (make-clock :monotonic-fn :bad)))
