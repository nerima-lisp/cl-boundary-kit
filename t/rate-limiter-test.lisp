;;;; t/rate-limiter-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "test rate limiter"
  (it "test-rate-limiter-permits-up-to-capacity-then-throttles"
    (let ((limiter (make-test-rate-limiter :capacity 2)))
      (expect (rate-limiter-available limiter) :to-be 2)
      (expect (rate-limiter-allow-p limiter) :to-be t)
      (expect (rate-limiter-allow-p limiter) :to-be t)
      (expect (rate-limiter-allow-p limiter) :to-be-null)
      (expect (rate-limiter-available limiter) :to-be 0)))

  (it "test-rate-limiter-refills-over-time"
    (let* ((now 0)
           (limiter (make-test-rate-limiter :capacity 1 :refill-rate 1
                                            :now-fn (lambda () now))))
      (expect (rate-limiter-allow-p limiter) :to-be t)
      (expect (rate-limiter-allow-p limiter) :to-be-null)
      (setf now 1)
      (expect (rate-limiter-allow-p limiter) :to-be t)))

  (it "test-rate-limiter-refill-never-exceeds-capacity"
    (let* ((now 0)
           (limiter (make-test-rate-limiter :capacity 2 :refill-rate 1
                                            :now-fn (lambda () now))))
      (rate-limiter-allow-p limiter)
      (rate-limiter-allow-p limiter)
      (setf now 100)
      (expect (rate-limiter-available limiter) :to-be 2)))

  (it "make-test-rate-limiter-rejects-invalid-capacity-and-refill-rate"
    (signals error
      (make-test-rate-limiter :capacity 0))
    (signals error
      (make-test-rate-limiter :refill-rate -1)))

  (it "test-rate-limiter-available-stays-within-zero-and-capacity"
    (let ((limiter (make-test-rate-limiter :capacity 3 :refill-rate 0)))
      (with-soft-assertions
        (expect (rate-limiter-available limiter) :to-be 3)
        (rate-limiter-allow-p limiter)
        (expect (rate-limiter-available limiter) :to-be 2)
        (rate-limiter-allow-p limiter)
        (expect (rate-limiter-available limiter) :to-be 1)
        (rate-limiter-allow-p limiter)
        (expect (rate-limiter-available limiter) :to-be 0)
        (expect (rate-limiter-allow-p limiter) :to-be-null)
        (expect (rate-limiter-available limiter) :to-be 0)))))

(describe "rate limiter"
  (it "make-rate-limiter-wires-injected-collaborators"
    (let* ((allowed t)
           (limiter (make-rate-limiter
                     :allow-fn (lambda () allowed)
                     :available-fn (lambda () 5))))
      (expect (rate-limiter-allow-p limiter) :to-be t)
      (expect (rate-limiter-available limiter) :to-be 5)
      (setf allowed nil)
      (expect (rate-limiter-allow-p limiter) :to-be-null)))

  (it "make-rate-limiter-rejects-non-function-collaborators"
    (signals error
      (make-rate-limiter :allow-fn :bad :available-fn (lambda () 0)))))

(describe "recording rate limiter"
  (it "recording-rate-limiter-records-checks"
    (let ((limiter (make-recording-rate-limiter :delegate (make-test-rate-limiter :capacity 1))))
      (rate-limiter-allow-p limiter)
      (rate-limiter-available limiter)
      (expect (recording-rate-limiter-calls limiter)
              :to-have-recorded-calls
              (list (boundary-call-plist :allow-p '() :result t)
                    (boundary-call-plist :available '() :result 0)))))

  (it "make-recording-rate-limiter-rejects-a-non-rate-limiter-delegate"
    (signals error
      (make-recording-rate-limiter :delegate :bad)))

  (it-each ((recording-rate-limiter-calls)
            (reset-recording-rate-limiter-calls))
      "~A signals for unsupported limiter types"
      (operation)
    (expect (lambda () (funcall operation (make-test-rate-limiter))) :to-throw "Unsupported rate limiter type"))

  (deftest-reset-recording-clears-history
      "reset-recording-rate-limiter-calls-clears-history-and-returns-the-limiter"
      (limiter (make-recording-rate-limiter))
      (recording-rate-limiter-calls reset-recording-rate-limiter-calls)
    (rate-limiter-allow-p limiter)))

(describe "call-if-allowed"
  (it "call-if-allowed-runs-the-thunk-only-while-quota-remains"
    (let ((limiter (make-test-rate-limiter :capacity 1)))
      (expect (call-if-allowed limiter (lambda () :ran)) :to-be :ran)
      ;; Quota exhausted -> falls back.
      (expect (call-if-allowed limiter (lambda () :ran) (lambda () :throttled)) :to-be :throttled)
      ;; No fallback -> returns NIL when throttled.
      (expect (call-if-allowed limiter (lambda () :ran)) :to-be-null)))

  (it "call-if-allowed-rejects-non-function-thunks"
    (signals error
      (call-if-allowed (make-test-rate-limiter) :bad))
    (signals error
      (call-if-allowed (make-test-rate-limiter) (lambda () :ok) :bad))))
