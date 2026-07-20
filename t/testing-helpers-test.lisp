;;;; t/testing-helpers-test.lisp

(in-package #:cl-boundary-kit/test)

(defmacro with-boundary-calls ((calls &rest call-specs) &body body)
  `(let ((,calls (list ,@(mapcar (lambda (spec)
                                   `(cl-boundary-kit:boundary-call-plist ,@spec))
                                 call-specs))))
     ,@body))

(it "filter-recorded-calls-returns-matching-calls-without-signaling"
  (with-boundary-calls (calls
                        (:get (list "a") :result 1)
                        (:set (list "a" 2))
                        (:get (list "b") :result 3))
    (expect (= 2 (length (filter-recorded-calls calls :get))) :to-be-truthy)
    (expect (equal (list (boundary-call-plist :get (list "a") :result 1))
                   (filter-recorded-calls calls :get :arguments (list "a"))) :to-be-truthy)
    (expect (null (filter-recorded-calls calls :delete)) :to-be-truthy)))

(it "count-recorded-calls-counts-matches-without-signaling"
  (with-boundary-calls (calls
                        (:get (list "a"))
                        (:get (list "b"))
                        (:set (list "a" 1)))
    (expect (= 2 (count-recorded-calls calls :get)) :to-be-truthy)
    (expect (= 1 (count-recorded-calls calls :get :arguments (list "a"))) :to-be-truthy)
    (expect (= 0 (count-recorded-calls calls :delete)) :to-be-truthy)))

(it "assert-no-recorded-call-holds-when-absent-and-signals-when-present"
  (with-boundary-calls (calls
                        (:get (list "a"))
                        (:set (list "a" 1)))
    (expect (eq calls (assert-no-recorded-call calls :delete)) :to-be-truthy)
    ;; A different argument list means no match, so the assertion still holds.
    (expect (eq calls (assert-no-recorded-call calls :get :arguments (list "z"))) :to-be-truthy)
    (signals error
      (assert-no-recorded-call calls :get))))

(it "recorded-call-operations-returns-operations-in-order"
  (with-boundary-calls (calls
                        (:get (list "a"))
                        (:set (list "a" 1))
                        (:get (list "b")))
    (expect (equal (list :get :set :get) (recorded-call-operations calls)) :to-be-truthy)))

(it "recorded-call-results-returns-results-in-order"
  (with-boundary-calls (calls
                        (:get (list "a") :result 1)
                        (:get (list "b") :result 2))
    (expect (equal (list 1 2) (recorded-call-results calls)) :to-be-truthy)))

(it "assert-recorded-operations-checks-the-exact-ordered-operation-list"
  (with-boundary-calls (calls
                        (:get (list "a"))
                        (:set (list "a" 1))
                        (:get (list "b")))
    (expect (eq calls (assert-recorded-operations calls :get :set :get)) :to-be-truthy)
    ;; A missing or extra operation, or a wrong order, fails.
    (signals error (assert-recorded-operations calls :get :set))
    (signals error (assert-recorded-operations calls :get :get :set))
    (signals error (assert-recorded-operations calls :get :set :get :delete))))

(it "nth-recorded-call-and-last-recorded-call-return-single-calls"
  (with-boundary-calls (calls
                        (:get (list "a") :result 1)
                        (:set (list "a" 2))
                        (:get (list "b") :result 3))
    (expect (equal (boundary-call-plist :get (list "a") :result 1)
                   (nth-recorded-call calls 0)) :to-be-truthy)
    (expect (null (nth-recorded-call calls 5)) :to-be-truthy)
    (expect (equal (boundary-call-plist :get (list "b") :result 3)
                   (last-recorded-call calls)) :to-be-truthy)
    (expect (null (last-recorded-call '())) :to-be-truthy)))

(it "nth-recorded-call-rejects-a-negative-index"
  (signals error
    (nth-recorded-call '() -1)))

(it "event-helpers-match-events-by-key-value-constraints"
  (let ((events (list (list :level :info :message "start")
                      (list :level :error :message "boom")
                      (list :level :info :message "done"))))
    (expect (equal (list :level :error :message "boom")
                   (find-event events :level :error)) :to-be-truthy)
    (expect (null (find-event events :level :debug)) :to-be-truthy)
    (expect (= 2 (count-events events :level :info)) :to-be-truthy)
    (expect (equal (list :level :error :message "boom")
                   (assert-event-present events :level :error :message "boom")) :to-be-truthy)
    (expect (eq events (assert-no-event events :level :debug)) :to-be-truthy)
    (signals error (assert-event-present events :level :debug))
    (signals error (assert-no-event events :level :error))))

(it "event-values-pulls-a-key-from-every-event-in-order"
  (let ((events (list (list :level :info :message "a")
                      (list :level :error :message "b")
                      (list :level :info :message "c"))))
    (expect (equal (list :info :error :info) (event-values events :level)) :to-be-truthy)
    (expect (equal (list "a" "b" "c") (event-values events :message)) :to-be-truthy)
    ;; Missing key yields NIL for each event.
    (expect (equal (list nil nil nil) (event-values events :absent)) :to-be-truthy)))

(it "event-helpers-work-with-the-fire-and-forget-boundary-captures"
  (let ((metrics (make-test-metrics)))
    (metrics-count metrics "hits" 3)
    (metrics-gauge metrics "queue" 7)
    (expect (equal (list :type :gauge :name "queue" :value 7)
                   (assert-event-present (recording-metric-events metrics) :name "queue")) :to-be-truthy)
    (expect (= 1 (count-events (recording-metric-events metrics) :type :count)) :to-be-truthy)))

(it "assert-event-count-checks-the-exact-number-of-matching-events"
  (let ((events (list (list :level :info) (list :level :error) (list :level :info))))
    (expect (eq events (assert-event-count events 2 :level :info)) :to-be-truthy)
    (expect (eq events (assert-event-count events 0 :level :debug)) :to-be-truthy)
    (signals error (assert-event-count events 1 :level :info))))

(it "find-recorded-call-returns-the-first-matching-call-or-nil"
  (with-boundary-calls (calls
                        (:get (list "a") :result 1)
                        (:set (list "a" 2))
                        (:get (list "b") :result 3))
    (expect (equal (boundary-call-plist :get (list "a") :result 1)
                   (find-recorded-call calls :get)) :to-be-truthy)
    (expect (equal (boundary-call-plist :get (list "b") :result 3)
                   (find-recorded-call calls :get :arguments (list "b"))) :to-be-truthy)
    (expect (null (find-recorded-call calls :delete)) :to-be-truthy)))

(it "single-call-field-accessors-pull-fields-out-of-one-recorded-call"
  (with-boundary-calls (calls
                        (:get (list "a") :result 1)
                        (:set (list "b" 2) :result t))
    (let ((call (last-recorded-call calls)))
      (expect (eq :set (recorded-call-operation call)) :to-be-truthy)
      (expect (equal (list "b" 2) (recorded-call-arguments call)) :to-be-truthy)
      (expect (eq t (recorded-call-result call)) :to-be-truthy))))

(it "assert-recorded-call-order-holds-for-an-ordered-subsequence"
  (with-boundary-calls (calls
                        (:open (list "f"))
                        (:read (list "f"))
                        (:close (list "f")))
    (expect (eq calls (assert-recorded-call-order calls :open :close)) :to-be-truthy)
    (expect (eq calls (assert-recorded-call-order calls :open :read :close)) :to-be-truthy)))

(it "assert-recorded-call-order-signals-when-the-order-is-violated-or-missing"
  (with-boundary-calls (calls
                        (:close (list "f"))
                        (:open (list "f")))
    (signals error
      (assert-recorded-call-order calls :open :close))
    (signals error
      (assert-recorded-call-order calls :open :read :close))))

(it "boundary-call-plist-includes-result-when-supplied"
  (expect (equal (cl-boundary-kit:boundary-call-plist
              :write-file
              (list #P"example.txt" :content "hello")
              :result t)
             '(:operation :write-file
               :arguments (#P"example.txt" :content "hello")
               :result t)) :to-be-truthy))

(it "boundary-call-plist-omits-result-when-not-supplied"
  (expect (equal (cl-boundary-kit:boundary-call-plist
              :get
              (list "PATH"))
             '(:operation :get
               :arguments ("PATH"))) :to-be-truthy))

(it "boundary-call-plist-signals-when-arguments-are-not-a-list"
  (signals error
    (cl-boundary-kit:boundary-call-plist :get "PATH")))

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

(it "assert-recorded-call-signals-when-call-is-missing"
  (signals error
    (cl-boundary-kit:assert-recorded-call
     (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp"))
     :set
     :arguments (list "HOME" :value "/srv"))))

(it "assert-recorded-call-count-matches-repeated-calls"
  (with-boundary-calls (calls
                        (:get (list "PATH") :result "/bin")
                        (:get (list "HOME") :result "/tmp")
                        (:get (list "PATH") :result "/usr/bin"))
    (expect (= 2
           (length (cl-boundary-kit:assert-recorded-call-count
                    calls
                    :get
                    2
                    :arguments (list "PATH")))) :to-be-truthy)))

(it "assert-recorded-call-count-supports-explicit-nil-result-checks"
  (with-boundary-calls (calls
                        (:noop nil :result nil)
                        (:noop nil :result :ok))
    (expect (= 1
           (length (cl-boundary-kit:assert-recorded-call-count
                    calls
                    :noop
                    1
                    :result nil))) :to-be-truthy)))

(it "assert-recorded-call-count-signals-when-match-count-differs"
  (signals error
    (cl-boundary-kit:assert-recorded-call-count
     (list (cl-boundary-kit:boundary-call-plist :get (list "PATH") :result "/bin"))
     :get
     2
     :arguments (list "PATH"))))

(it "assert-recorded-call-sequence-matches-full-call-history"
  (with-boundary-calls (calls
                        (:get (list "HOME") :result "/tmp")
                        (:set (list "HOME" :value "/srv") :result t))
    (expect (equal calls
               (cl-boundary-kit:assert-recorded-call-sequence
                calls
                (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp")
                      (cl-boundary-kit:boundary-call-plist :set (list "HOME" :value "/srv") :result t)))) :to-be-truthy)))

(it "assert-recorded-call-sequence-allows-prefix-checks"
  (with-boundary-calls (calls
                        (:get (list "HOME") :result "/tmp")
                        (:set (list "HOME" :value "/srv") :result t))
    (expect (equal calls
               (cl-boundary-kit:assert-recorded-call-sequence
                calls
                (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp"))
                :exact-length nil)) :to-be-truthy)))

(it "assert-recorded-call-sequence-supports-partial-expectations"
  (with-boundary-calls (calls
                        (:get (list "HOME") :result "/tmp")
                        (:set (list "HOME" :value "/srv") :result t))
    (expect (equal calls
               (cl-boundary-kit:assert-recorded-call-sequence
                calls
                (list '(:operation :get)
                      '(:operation :set :result t)))) :to-be-truthy)))

(it "assert-recorded-call-sequence-signals-on-order-mismatch"
  (signals error
    (with-boundary-calls (calls
                          (:get (list "HOME") :result "/tmp")
                          (:set (list "HOME" :value "/srv") :result t))
      (cl-boundary-kit:assert-recorded-call-sequence
       calls
       (list (cl-boundary-kit:boundary-call-plist :set (list "HOME" :value "/srv") :result t)
             (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp"))))))

(it "assert-recorded-call-sequence-signals-when-expectation-misses-operation"
  (signals error
    (cl-boundary-kit:assert-recorded-call-sequence
     nil
     (list '(:arguments ("HOME"))))))

;;; Regression: with :EXACT-LENGTH NIL, the LOOP driving this check used
;;; parallel `for ... in` clauses over both EXPECTED-CALLS and CALLS, so it
;;; silently stopped as soon as the shorter CALLS list ran out instead of
;;; flagging that an expected trailing call never happened.
(it "assert-recorded-call-sequence-signals-when-expectations-outrun-calls"
  (signals error
    (with-boundary-calls (calls
                          (:get (list "HOME") :result "/tmp"))
      (cl-boundary-kit:assert-recorded-call-sequence
       calls
       (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp")
             (cl-boundary-kit:boundary-call-plist :set (list "HOME" :value "/srv") :result t))
       :exact-length nil))))
