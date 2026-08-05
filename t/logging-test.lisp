;;;; t/logging-test.lisp

(in-package #:cl-boundary-kit/test)

(defun log-event-plist (timestamp level message fields)
  (list :timestamp timestamp
        :level level
        :message message
        :fields fields))

(defun assert-log-event (event timestamp level message fields)
  (expect event :to-equal (log-event-plist timestamp level message fields)))

(describe "logger"
  (it "logger-produces-event"
    (let ((logger (make-logger :timestamp-fn (lambda () 1234))))
      (let ((event (logger-log logger :info "hello" :user "take")))
        (assert-log-event event 1234 :info "hello" '(:user "take")))))

  (it "logger-level-helpers-supply-the-matching-level"
    (let ((logger (make-test-logger :timestamp-fn (lambda () 7))))
      (assert-log-event (logger-debug logger "d" :k 1) 7 :debug "d" '(:k 1))
      (assert-log-event (logger-info logger "i") 7 :info "i" '())
      (assert-log-event (logger-warn logger "w") 7 :warn "w" '())
      (assert-log-event (logger-error logger "e") 7 :error "e" '())
      ;; Each helper still records through the normal logging path.
      (expect (recording-log-events logger) :to-have-length 4)))

  (it "make-logger-rejects-non-function-collaborators"
    (signals error
      (make-logger :sink-fn :bad))
    (signals error
      (make-logger :timestamp-fn :bad))))

(describe "test logger"
  (it "test-logger-records-emitted-events"
    (let ((logger (make-test-logger :timestamp-fn (lambda () 88))))
      (let ((event (logger-log logger :info "captured" :request-id "req-7")))
        (let ((events (recording-log-events logger)))
          (expect event :not :to-be (first events))
          (expect events :to-have-length 1)
          (assert-log-event (first events) 88 :info "captured" '(:request-id "req-7"))))))

  (it "make-test-logger-rejects-non-function-timestamp"
    (signals error
      (make-test-logger :timestamp-fn :bad))))

(describe "recording logger"
  (it "recording-logger-records-events"
    (let* ((forwarded '())
           (delegate (make-logger
                      :timestamp-fn (lambda () 99)
                      :sink-fn (lambda (event)
                                 (push event forwarded))))
           (logger (make-recording-logger :delegate delegate)))
      (logger-log logger :warn "hello" :user "take")
      (let ((events (recording-log-events logger)))
        (expect events :to-have-length 1)
        (expect forwarded :to-have-length 1)
        (expect (first forwarded) :to-equal (first events))
        (assert-log-event (first events) 99 :warn "hello" '(:user "take")))))

  (it "recording-logger-preserves-event-through-nested-delegates"
    (let* ((sink-events '())
           (base (make-logger
                  :timestamp-fn (lambda () 7)
                  :sink-fn (lambda (event)
                             (push event sink-events))))
           (inner (make-recording-logger :delegate base))
           (outer (make-recording-logger :delegate inner)))
      (logger-log outer :info "nested")
      (let ((outer-events (recording-log-events outer))
            (inner-events (recording-log-events inner)))
        (expect outer-events :to-have-length 1)
        (expect inner-events :to-have-length 1)
        (expect sink-events :to-have-length 1)
        (expect (first outer-events) :to-equal (first inner-events))
        (expect (first sink-events) :to-equal (first outer-events)))))

  (it "recording-logger-returns-independent-recorded-and-forwarded-events"
    (let* ((forwarded '())
           (logger (make-recording-logger
                    :delegate (make-logger
                               :timestamp-fn (lambda () 55)
                               :sink-fn (lambda (event)
                                          (push event forwarded))))))
      (let ((event (logger-log logger :info "same" :request-id "req-2")))
        (let ((events (recording-log-events logger)))
          (expect event :to-equal (first forwarded))
          (expect event :to-equal (first events))
          (expect event :not :to-be (first forwarded))
          (expect event :not :to-be (first events))))))

  (it "recording-log-events-returns-independent-event-snapshots"
    (let* ((logger (make-test-logger :timestamp-fn (lambda () 10)))
           (payload (list :secret "ok"))
           (event (logger-log logger :info "safe" :payload payload)))
      (setf (getf event :message) "mutated"
            (getf (getf event :fields) :payload) :changed
            (getf payload :secret) "changed")
      (let ((events (recording-log-events logger)))
        (assert-log-event (first events) 10 :info "safe" '(:payload (:secret "ok"))))))

  (it "logger-sink-receives-an-independent-event-copy"
    (let ((logger (make-logger
                   :timestamp-fn (lambda () 11)
                   :sink-fn (lambda (event)
                              (setf (getf event :message) "mutated")))))
      (assert-log-event (logger-log logger :info "safe") 11 :info "safe" '())))

  (it "recording-logger-preserves-attempted-event-on-sink-failure"
    (let* ((logger (make-recording-logger
                    :delegate (make-logger
                               :timestamp-fn (lambda () 321)
                               :sink-fn (lambda (event)
                                          (declare (ignore event))
                                          (error "sink failed"))))))
      (signals error
        (logger-log logger :error "boom" :request-id "req-1"))
      (let ((events (recording-log-events logger)))
        (expect events :to-have-length 1)
        (assert-log-event (first events) 321 :error "boom" '(:request-id "req-1")))))

  (it "make-recording-logger-rejects-non-logger-delegate"
    (signals error
      (make-recording-logger :delegate :bad))))

(describe "recording-log-events and reset"
  (it-each ((recording-log-events)
            (reset-recording-log-events))
      "~A signals for unsupported logger types"
      (operation)
    (expect (lambda () (funcall operation (make-logger))) :to-throw "Unsupported logger type"))

  ;; Regression: wrapping a self-recording (:TEST-kind) delegate used to
  ;; double-record every event -- once on the wrapper, once on the delegate's
  ;; own history -- because the recording dispatch recursed through the
  ;; delegate's public %LOGGER-EMIT-EVENT, re-entering the delegate's own
  ;; recording path. Nesting RECORDING-LOGGERs is a different, intentional
  ;; case (each level records its own copy while cascading to the innermost
  ;; real sink) and must keep working -- see
  ;; recording-logger-preserves-event-through-nested-delegates above.
  (it "recording-logger-does-not-double-record-a-self-recording-delegate"
    (let* ((delegate (make-test-logger))
           (logger (make-recording-logger :delegate delegate)))
      (logger-log logger :info "hello")
      (expect (recording-log-events logger) :to-have-length 1)
      (expect (recording-log-events delegate) :to-have-length 0)))

  (it "reset-recording-log-events-clears-history-and-returns-the-logger"
    (let ((logger (make-test-logger)))
      (logger-log logger :info "one")
      (logger-log logger :info "two")
      (expect (recording-log-events logger) :to-have-length 2)
      (expect (reset-recording-log-events logger) :to-be logger)
      (expect (recording-log-events logger) :to-be-null)
      (logger-log logger :info "three")
      (expect (recording-log-events logger) :to-have-length 1)))

  (it "reset-recording-log-events-clears-a-test-logger-history"
    (let ((logger (make-test-logger)))
      (logger-log logger :info "hello")
      (expect (recording-log-events logger) :to-have-length 1)
      (expect (reset-recording-log-events logger) :to-be logger)
      (expect (recording-log-events logger) :to-be-null)))

  (it "reset-recording-log-events-clears-a-recording-logger-history"
    (let ((logger (make-recording-logger)))
      (logger-log logger :info "hello")
      (expect (reset-recording-log-events logger) :to-be logger)
      (expect (recording-log-events logger) :to-be-null))))
