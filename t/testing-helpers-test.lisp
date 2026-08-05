;;;; t/testing-helpers-test.lisp

(in-package #:cl-boundary-kit/test)

(defmacro with-boundary-calls ((calls &rest call-specs) &body body)
  `(let ((,calls (list ,@(mapcar (lambda (spec)
                                   `(cl-boundary-kit:boundary-call-plist ,@spec))
                                 call-specs))))
     ,@body))

(defvar *recorded-call-sequence* nil)

(describe "recorded call query and accessor helpers"
  (it "filter-recorded-calls-returns-matching-calls-without-signaling"
    (with-boundary-calls (calls
                          (:get (list "a") :result 1)
                          (:set (list "a" 2))
                          (:get (list "b") :result 3))
      (expect (length (filter-recorded-calls calls :get)) :to-be 2)
      (expect (filter-recorded-calls calls :get :arguments (list "a"))
              :to-have-recorded-calls (list (boundary-call-plist :get (list "a") :result 1)))
      (expect (filter-recorded-calls calls :delete) :to-be-null)))

  (it "count-recorded-calls-counts-matches-without-signaling"
    (with-boundary-calls (calls
                          (:get (list "a"))
                          (:get (list "b"))
                          (:set (list "a" 1)))
      (expect (count-recorded-calls calls :get) :to-be 2)
      (expect (count-recorded-calls calls :get :arguments (list "a")) :to-be 1)
      (expect (count-recorded-calls calls :delete) :to-be 0)))

  (it "assert-no-recorded-call-holds-when-absent-and-signals-when-present"
    (with-boundary-calls (calls
                          (:get (list "a"))
                          (:set (list "a" 1)))
      (expect (assert-no-recorded-call calls :delete) :to-be calls)
      ;; A different argument list means no match, so the assertion still holds.
      (expect (assert-no-recorded-call calls :get :arguments (list "z")) :to-be calls)
      (signals error
        (assert-no-recorded-call calls :get))))

  (it "recorded-call-operations-returns-operations-in-order"
    (with-boundary-calls (calls
                          (:get (list "a"))
                          (:set (list "a" 1))
                          (:get (list "b")))
      (expect (recorded-call-operations calls) :to-equal (list :get :set :get))))

  (it "recorded-call-results-returns-results-in-order"
    (with-boundary-calls (calls
                          (:get (list "a") :result 1)
                          (:get (list "b") :result 2))
      (expect (recorded-call-results calls) :to-equal (list 1 2))))

  (it "assert-recorded-operations-checks-the-exact-ordered-operation-list"
    (with-boundary-calls (calls
                          (:get (list "a"))
                          (:set (list "a" 1))
                          (:get (list "b")))
      (expect (assert-recorded-operations calls :get :set :get) :to-be calls)
      ;; A missing or extra operation, or a wrong order, fails.
      (signals error (assert-recorded-operations calls :get :set))
      (signals error (assert-recorded-operations calls :get :get :set))
      (signals error (assert-recorded-operations calls :get :set :get :delete))))

  (it "nth-recorded-call-and-last-recorded-call-return-single-calls"
    (with-boundary-calls (calls
                          (:get (list "a") :result 1)
                          (:set (list "a" 2))
                          (:get (list "b") :result 3))
      (expect (nth-recorded-call calls 0) :to-equal (boundary-call-plist :get (list "a") :result 1))
      (expect (nth-recorded-call calls 5) :to-be-null)
      (expect (last-recorded-call calls) :to-equal (boundary-call-plist :get (list "b") :result 3))
      (expect (last-recorded-call '()) :to-be-null)))

  (it "nth-recorded-call-rejects-a-negative-index"
    (signals error
      (nth-recorded-call '() -1)))

  ;; The test above only exercises a negative integer index, taking the AND's
  ;; other operand's false branch; a non-integer takes INTEGERP's own false
  ;; branch.
  (it "nth-recorded-call-rejects-a-non-integer-index"
    (signals error
      (nth-recorded-call '() 1.5))))

(describe "event helpers"
  (it "event-helpers-match-events-by-key-value-constraints"
    (let ((events (list (list :level :info :message "start")
                        (list :level :error :message "boom")
                        (list :level :info :message "done"))))
      (expect (find-event events :level :error) :to-equal (list :level :error :message "boom"))
      (expect (find-event events :level :debug) :to-be-null)
      (expect (count-events events :level :info) :to-be 2)
      (expect (assert-event-present events :level :error :message "boom") :to-equal (list :level :error :message "boom"))
      (expect (assert-no-event events :level :debug) :to-be events)
      (signals error (assert-event-present events :level :debug))
      (signals error (assert-no-event events :level :error))))

  (it "event-values-pulls-a-key-from-every-event-in-order"
    (let ((events (list (list :level :info :message "a")
                        (list :level :error :message "b")
                        (list :level :info :message "c"))))
      (expect (event-values events :level) :to-equal (list :info :error :info))
      (expect (event-values events :message) :to-equal (list "a" "b" "c"))
      ;; Missing key yields NIL for each event.
      (expect (event-values events :absent) :to-equal (list nil nil nil))))

  (it "event-helpers-work-with-the-fire-and-forget-boundary-captures"
    (let ((metrics (make-test-metrics)))
      (metrics-count metrics "hits" 3)
      (metrics-gauge metrics "queue" 7)
      (expect (assert-event-present (recording-metric-events metrics) :name "queue") :to-equal (list :type :gauge :name "queue" :value 7))
      (expect (count-events (recording-metric-events metrics) :type :count) :to-be 1)))

  (it "assert-event-count-checks-the-exact-number-of-matching-events"
    (let ((events (list (list :level :info) (list :level :error) (list :level :info))))
      (expect (assert-event-count events 2 :level :info) :to-be events)
      (expect (assert-event-count events 0 :level :debug) :to-be events)
      (signals error (assert-event-count events 1 :level :info)))))

(describe "single recorded call lookup and field accessors"
  (it "find-recorded-call-returns-the-first-matching-call-or-nil"
    (with-boundary-calls (calls
                          (:get (list "a") :result 1)
                          (:set (list "a" 2))
                          (:get (list "b") :result 3))
      (expect (find-recorded-call calls :get) :to-equal (boundary-call-plist :get (list "a") :result 1))
      (expect (find-recorded-call calls :get :arguments (list "b")) :to-equal (boundary-call-plist :get (list "b") :result 3))
      (expect (find-recorded-call calls :delete) :to-be-null)))

  (it "single-call-field-accessors-pull-fields-out-of-one-recorded-call"
    (with-boundary-calls (calls
                          (:get (list "a") :result 1)
                          (:set (list "b" 2) :result t))
      (let ((call (last-recorded-call calls)))
        (expect (recorded-call-operation call) :to-be :set)
        (expect (recorded-call-arguments call) :to-equal (list "b" 2))
        (expect (recorded-call-result call) :to-be t)))))

(describe "assert-recorded-call-order"
  (it "assert-recorded-call-order-holds-for-an-ordered-subsequence"
    (with-boundary-calls (calls
                          (:open (list "f"))
                          (:read (list "f"))
                          (:close (list "f")))
      (expect (assert-recorded-call-order calls :open :close) :to-be calls)
      (expect (assert-recorded-call-order calls :open :read :close) :to-be calls)))

  (it "assert-recorded-call-order-signals-when-the-order-is-violated-or-missing"
    (with-boundary-calls (calls
                          (:close (list "f"))
                          (:open (list "f")))
      (signals error
        (assert-recorded-call-order calls :open :close))
      (signals error
        (assert-recorded-call-order calls :open :read :close)))))

(describe "boundary-call-plist"
  (it "boundary-call-plist-includes-result-when-supplied"
    (expect (cl-boundary-kit:boundary-call-plist
             :write-file
             (list #P"example.txt" :content "hello")
             :result t)
            :to-equal '(:operation :write-file
                        :arguments (#P"example.txt" :content "hello")
                        :result t)))

  (it "boundary-call-plist-omits-result-when-not-supplied"
    (expect (cl-boundary-kit:boundary-call-plist :get (list "PATH"))
            :to-equal '(:operation :get :arguments ("PATH"))))

  (it "boundary-call-plist-signals-when-arguments-are-not-a-list"
    (signals error
      (cl-boundary-kit:boundary-call-plist :get "PATH"))))

(describe "assert-recorded-call"
  (it "assert-recorded-call-matches-operation-arguments-and-result"
    (with-boundary-calls (calls
                          (:write-file (list #P"example.txt" :content "hello")
                                       :result t))
      (expect (cl-boundary-kit:assert-recorded-call
           calls
           :write-file
           :arguments (list #P"example.txt" :content "hello")
           :result t) :to-be-truthy)))

  (it "assert-recorded-call-allows-operation-only-checks"
    (with-boundary-calls (calls
                          (:get (list "PATH")
                                :result "/usr/bin"))
      (expect (cl-boundary-kit:assert-recorded-call calls :get) :to-be-truthy)))

  ;; The tests above only ever see one call per operation, so ASSERT-RECORDED-
  ;; CALL's loop always finds its match on the first matching iteration;
  ;; exercise a second, later match for the same operation being skipped once
  ;; MATCHING-CALL is already set.
  (it "assert-recorded-call-returns-the-first-match-among-several"
    (with-boundary-calls (calls
                          (:get (list "PATH") :result "/usr/bin")
                          (:get (list "HOME") :result "/home/x"))
      (expect (getf (cl-boundary-kit:assert-recorded-call calls :get) :arguments) :to-equal (list "PATH"))))

  (it "assert-recorded-call-signals-when-call-is-missing"
    (signals error
      (cl-boundary-kit:assert-recorded-call
       (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp"))
       :set
       :arguments (list "HOME" :value "/srv"))))

  ;; The test above only supplies :ARGUMENTS; also cover the failure message
  ;; when an explicit :RESULT expectation is supplied too.
  (it "assert-recorded-call-signals-when-call-is-missing-with-a-result-expectation"
    (signals error
      (cl-boundary-kit:assert-recorded-call
       (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp"))
       :set
       :arguments (list "HOME" :value "/srv")
       :result t))))

(describe "assert-recorded-call-count"
  (it "assert-recorded-call-count-matches-repeated-calls"
    (with-boundary-calls (calls
                          (:get (list "PATH") :result "/bin")
                          (:get (list "HOME") :result "/tmp")
                          (:get (list "PATH") :result "/usr/bin"))
      (expect (length (cl-boundary-kit:assert-recorded-call-count
                      calls
                      :get
                      2
                      :arguments (list "PATH"))) :to-be 2)))

  (it "assert-recorded-call-count-supports-explicit-nil-result-checks"
    (with-boundary-calls (calls
                          (:noop nil :result nil)
                          (:noop nil :result :ok))
      (expect (length (cl-boundary-kit:assert-recorded-call-count
                      calls
                      :noop
                      1
                      :result nil)) :to-be 1)))

  (it "assert-recorded-call-count-signals-when-match-count-differs"
    (signals error
      (cl-boundary-kit:assert-recorded-call-count
       (list (cl-boundary-kit:boundary-call-plist :get (list "PATH") :result "/bin"))
       :get
       2
       :arguments (list "PATH")))))

(describe "assert-recorded-call-sequence"
  (before-each
    (setf *recorded-call-sequence*
          (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp")
                (cl-boundary-kit:boundary-call-plist :set (list "HOME" :value "/srv") :result t))))

  (it "assert-recorded-call-sequence-matches-full-call-history"
    (expect (cl-boundary-kit:assert-recorded-call-sequence
             *recorded-call-sequence*
             (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp")
                   (cl-boundary-kit:boundary-call-plist :set (list "HOME" :value "/srv") :result t)))
            :to-equal *recorded-call-sequence*))

  (it "assert-recorded-call-sequence-allows-prefix-checks"
    (expect (cl-boundary-kit:assert-recorded-call-sequence
             *recorded-call-sequence*
             (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp"))
             :exact-length nil)
            :to-equal *recorded-call-sequence*))

  (it "assert-recorded-call-sequence-supports-partial-expectations"
    (expect (cl-boundary-kit:assert-recorded-call-sequence
             *recorded-call-sequence*
             (list '(:operation :get)
                   '(:operation :set :result t)))
            :to-equal *recorded-call-sequence*))

  (it "assert-recorded-call-sequence-signals-on-order-mismatch"
    (signals error
      (cl-boundary-kit:assert-recorded-call-sequence
       *recorded-call-sequence*
       (list (cl-boundary-kit:boundary-call-plist :set (list "HOME" :value "/srv") :result t)
             (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp")))))

  (it "assert-recorded-call-sequence-signals-when-expectation-misses-operation"
    (signals error
      (cl-boundary-kit:assert-recorded-call-sequence
       nil
       (list '(:arguments ("HOME"))))))

  ;; Regression: with :EXACT-LENGTH NIL, the LOOP driving this check used
  ;; parallel `for ... in` clauses over both EXPECTED-CALLS and CALLS, so it
  ;; silently stopped as soon as the shorter CALLS list ran out instead of
  ;; flagging that an expected trailing call never happened.
  (it "assert-recorded-call-sequence-signals-when-expectations-outrun-calls"
    (signals error
      (with-boundary-calls (calls
                            (:get (list "HOME") :result "/tmp"))
        (cl-boundary-kit:assert-recorded-call-sequence
         calls
         (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp")
               (cl-boundary-kit:boundary-call-plist :set (list "HOME" :value "/srv") :result t))
         :exact-length nil))))

  ;; Error branches of the sequence assertion and event-constraint validation.

  (it "assert-recorded-call-sequence-rejects-non-list-expected-calls"
    (expect (lambda () (assert-recorded-call-sequence '() 42)) :to-throw "expected EXPECTED-CALLS to be a list"))

  (it "assert-recorded-call-sequence-rejects-a-non-plist-expectation"
    (expect (lambda () (assert-recorded-call-sequence '() (list 42))) :to-throw "Recorded call expectation must be a plist"))

  (it "assert-recorded-call-sequence-reports-a-length-mismatch"
    (expect (lambda () (assert-recorded-call-sequence '() (list (list :operation :ping)))) :to-throw "Expected recorded call sequence length"))

  (it "assert-recorded-call-sequence-reports-calls-ending-early-when-length-is-not-exact"
    (expect (lambda () (assert-recorded-call-sequence '() (list (list :operation :ping)) :exact-length nil)) :to-throw "but calls ended after"))

  (it "assert-recorded-call-sequence-reports-a-mismatch-entry"
    (expect (lambda ()
              (assert-recorded-call-sequence (list (list :operation :pong))
                                             (list (list :operation :ping))))
            :to-throw "Recorded call mismatch at index")))

(describe "event constraint validation"
  (it "count-events-rejects-odd-length-constraints"
    (expect (lambda () (count-events (list (list :topic :a)) :lonely-key)) :to-throw "Event constraints must be a plist")))
