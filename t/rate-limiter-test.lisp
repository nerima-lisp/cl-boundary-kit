;;;; t/rate-limiter-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-rate-limiter-permits-up-to-capacity-then-throttles"
  (let ((limiter (make-test-rate-limiter :capacity 2)))
    (expect (= 2 (rate-limiter-available limiter)) :to-be-truthy)
    (expect (eq t (rate-limiter-allow-p limiter)) :to-be-truthy)
    (expect (eq t (rate-limiter-allow-p limiter)) :to-be-truthy)
    (expect (null (rate-limiter-allow-p limiter)) :to-be-truthy)
    (expect (= 0 (rate-limiter-available limiter)) :to-be-truthy)))

(it "test-rate-limiter-refills-over-time"
  (let* ((now 0)
         (limiter (make-test-rate-limiter :capacity 1 :refill-rate 1
                                          :now-fn (lambda () now))))
    (expect (eq t (rate-limiter-allow-p limiter)) :to-be-truthy)
    (expect (null (rate-limiter-allow-p limiter)) :to-be-truthy)
    (setf now 1)
    (expect (eq t (rate-limiter-allow-p limiter)) :to-be-truthy)))

(it "test-rate-limiter-refill-never-exceeds-capacity"
  (let* ((now 0)
         (limiter (make-test-rate-limiter :capacity 2 :refill-rate 1
                                          :now-fn (lambda () now))))
    (rate-limiter-allow-p limiter)
    (rate-limiter-allow-p limiter)
    (setf now 100)
    (expect (= 2 (rate-limiter-available limiter)) :to-be-truthy)))

(it "make-test-rate-limiter-rejects-invalid-capacity-and-refill-rate"
  (signals error
    (make-test-rate-limiter :capacity 0))
  (signals error
    (make-test-rate-limiter :refill-rate -1)))

(it "make-rate-limiter-wires-injected-collaborators"
  (let* ((allowed t)
         (limiter (make-rate-limiter
                   :allow-fn (lambda () allowed)
                   :available-fn (lambda () 5))))
    (expect (eq t (rate-limiter-allow-p limiter)) :to-be-truthy)
    (expect (= 5 (rate-limiter-available limiter)) :to-be-truthy)
    (setf allowed nil)
    (expect (null (rate-limiter-allow-p limiter)) :to-be-truthy)))

(it "make-rate-limiter-rejects-non-function-collaborators"
  (signals error
    (make-rate-limiter :allow-fn :bad :available-fn (lambda () 0))))

(it "recording-rate-limiter-records-checks"
  (let ((limiter (make-recording-rate-limiter :delegate (make-test-rate-limiter :capacity 1))))
    (rate-limiter-allow-p limiter)
    (rate-limiter-available limiter)
    (expect (equal (recording-rate-limiter-calls limiter)
                   (list (boundary-call-plist :allow-p '() :result t)
                         (boundary-call-plist :available '() :result 0))) :to-be-truthy)))

(it "make-recording-rate-limiter-rejects-a-non-rate-limiter-delegate"
  (signals error
    (make-recording-rate-limiter :delegate :bad)))

(it-each ((recording-rate-limiter-calls)
          (reset-recording-rate-limiter-calls))
    "~A signals for unsupported limiter types"
    (operation)
  (expect (lambda () (funcall operation (make-test-rate-limiter)))
          :to-signal-message-containing "Unsupported rate limiter type"))

(deftest-reset-recording-clears-history
    "reset-recording-rate-limiter-calls-clears-history-and-returns-the-limiter"
    (limiter (make-recording-rate-limiter))
    (recording-rate-limiter-calls reset-recording-rate-limiter-calls)
  (rate-limiter-allow-p limiter))

(it "call-if-allowed-runs-the-thunk-only-while-quota-remains"
  (let ((limiter (make-test-rate-limiter :capacity 1)))
    (expect (eq :ran (call-if-allowed limiter (lambda () :ran))) :to-be-truthy)
    ;; Quota exhausted -> falls back.
    (expect (eq :throttled (call-if-allowed limiter (lambda () :ran) (lambda () :throttled))) :to-be-truthy)
    ;; No fallback -> returns NIL when throttled.
    (expect (null (call-if-allowed limiter (lambda () :ran))) :to-be-truthy)))

(it "call-if-allowed-rejects-non-function-thunks"
  (signals error
    (call-if-allowed (make-test-rate-limiter) :bad))
  (signals error
    (call-if-allowed (make-test-rate-limiter) (lambda () :ok) :bad)))

(it "test-rate-limiter-available-stays-within-zero-and-capacity"
  (let ((limiter (make-test-rate-limiter :capacity 3 :refill-rate 0)))
    (with-soft-assertions
      (expect (= 3 (rate-limiter-available limiter)) :to-be-truthy)
      (rate-limiter-allow-p limiter)
      (expect (= 2 (rate-limiter-available limiter)) :to-be-truthy)
      (rate-limiter-allow-p limiter)
      (expect (= 1 (rate-limiter-available limiter)) :to-be-truthy)
      (rate-limiter-allow-p limiter)
      (expect (= 0 (rate-limiter-available limiter)) :to-be-truthy)
      (expect (null (rate-limiter-allow-p limiter)) :to-be-truthy)
      (expect (= 0 (rate-limiter-available limiter)) :to-be-truthy))))
