;;;; t/testing-helpers-test.lisp

(in-package #:cl-boundary-kit/test)

(defmacro with-boundary-calls ((calls &rest call-specs) &body body)
  `(let ((,calls (list ,@(mapcar (lambda (spec)
                                   `(cl-boundary-kit:boundary-call-plist ,@spec))
                                 call-specs))))
     ,@body))

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
