;;;; t/clock-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "clock"
  (it "fake-clock-advances"
    (let ((clock (make-fake-clock :start 10)))
      (expect (clock-now clock) :to-be 10)
      (advance-fake-clock clock 7)
      (expect (clock-now clock) :to-be 17)
      (expect (clock-monotonic clock) :to-be 17)))

  (it "fake-clock-supports-independent-monotonic-time"
    (let ((clock (make-fake-clock :start 10 :monotonic-start 100)))
      (expect (clock-now clock) :to-be 10)
      (expect (clock-monotonic clock) :to-be 100)
      (advance-fake-clock clock 7 :monotonic-delta 3)
      (expect (clock-now clock) :to-be 17)
      (expect (clock-monotonic clock) :to-be 103)))

  (it "fake-clock-defaults-wall-clock-start-independently"
    (let ((clock (apply (symbol-function 'make-fake-clock)
                        (list :monotonic-start 100))))
      (expect (clock-now clock) :to-be 0)
      (expect (clock-monotonic clock) :to-be 100)))

  (it "fake-clock-now-fn-and-monotonic-fn-track-advances"
    (let ((clock (make-fake-clock :start 10)))
      (advance-fake-clock clock 7)
      (expect (funcall (cl-boundary-kit::clock-now-fn clock)) :to-be 17)
      (expect (funcall (cl-boundary-kit::clock-monotonic-fn clock)) :to-be 17)))

  (it "real-clock-is-available"
    (let ((clock (make-clock)))
      (expect (clock-now clock) :to-be-type-of 'number)
      (expect (clock-monotonic clock) :to-be-type-of 'number)))

  (it "make-clock-rejects-non-function-collaborators"
    (signals error
      (make-clock :now-fn :bad))
    (signals error
      (make-clock :monotonic-fn :bad)))

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
        (expect result :to-be :done)
        (expect elapsed :to-be 7))))

  (it "call-with-elapsed-reports-zero-when-the-clock-does-not-advance"
    (let ((clock (make-fake-clock :start 0)))
      (multiple-value-bind (result elapsed)
          (call-with-elapsed clock (lambda () :done))
        (expect result :to-be :done)
        (expect elapsed :to-be 0))))

  (it "call-with-elapsed-rejects-a-non-function-thunk"
    (signals error (call-with-elapsed (make-fake-clock) :bad)))

  (it "fake-clock-defaults-start-when-monotonic-start-is-supplied"
    (let ((clock (make-fake-clock :monotonic-start 100)))
      (expect (clock-now clock) :to-be 0)
      (expect (clock-monotonic clock) :to-be 100))))
