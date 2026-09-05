;;;; t/coverage-completion-test.lisp
(in-package #:cl-boundary-kit/test)

(describe "network redaction shape predicates and dispatch"
  (it "redact-network-value-traverses-every-supported-shape"
    (flet ((redact (value) (cl-boundary-kit::%redact-network-value value)))
      (with-soft-assertions
        (expect (redact 42) :to-be 42)
        (expect (redact '(:authorization "s" :accept "j")) :to-equal '(:authorization :redacted :accept "j"))
        (expect (redact '((:token . "s") (:ok . "j"))) :to-equal '((:token . :redacted) (:ok . "j")))
        (expect (redact '("a" "b")) :to-equal '("a" "b"))
        (expect (redact '(:a 1 :b)) :to-equal '(:a 1 :b))
        (expect (redact '(1 2)) :to-equal '(1 2))
        (expect (redact '(1 . 2)) :to-equal '(1 . 2)))))

  (it "network-shape-predicates-reject-malformed-structure"
    (with-soft-assertions
      (expect (cl-boundary-kit::%network-plist-p '(:a 1 :b 2)) :to-be-truthy)
      (expect (cl-boundary-kit::%network-plist-p '(:a 1 :b)) :to-be nil)
      (expect (cl-boundary-kit::%network-plist-p '(1 2)) :to-be nil)
      (expect (cl-boundary-kit::%network-plist-p '(:a 1 . 2)) :to-be nil)
      (expect (cl-boundary-kit::%network-alist-p '((:a . 1))) :to-be-truthy)
      (expect (cl-boundary-kit::%network-alist-p '(1 2)) :to-be nil)
      (expect (cl-boundary-kit::%network-alist-p '((1 . 2))) :to-be nil)
      (expect (cl-boundary-kit::%network-alist-p '((:a . 1) . 2)) :to-be nil)
      (expect (cl-boundary-kit::%proper-list-p '(1 2 3)) :to-be-truthy)
      (expect (cl-boundary-kit::%proper-list-p '(1 . 2)) :to-be nil)))

  (it "record-network-call-rejects-an-unsupported-boundary-type"
    (expect (lambda ()
              (cl-boundary-kit::%record-network-call
               (make-network-boundary :request-fn (lambda (request &key timeout)
                                                    (declare (ignore request timeout))
                                                    nil))
               '(:method :get) nil nil))
            :to-throw "Unsupported network boundary type"))

  (it "network-sensitive-field-p-classifies-key-kinds"
    (expect (cl-boundary-kit::%network-sensitive-field-p :authorization) :to-be-truthy)
    (expect (cl-boundary-kit::%network-sensitive-field-p "Authorization") :to-be-truthy)
    (expect (cl-boundary-kit::%network-sensitive-field-p :accept) :to-be nil)
    (expect (cl-boundary-kit::%network-sensitive-field-p 42) :to-be nil))

  (it "copy-boundary-value-defensively-copies-bit-vectors"
    (let* ((original (make-array 3
                                 :element-type 'bit
                                 :initial-contents '(1 0 1)))
           (copy (cl-boundary-kit::%copy-boundary-value original)))
      (setf (sbit original 0) 0)
      (expect copy :to-equalp #*101))))

(describe "environment value/presence extraction and normalization"
  (it "environment-value-from-call-covers-every-arm"
    (flet ((v (values default) (cl-boundary-kit::%environment-value-from-call values default)))
      (expect (v '() :d) :to-be :d)
      (expect (v '(:x t) :d) :to-be :x)
      (expect (v '(:x nil) :d) :to-be :d)
      (expect (v '(nil) :d) :to-be :d)
      (expect (v '(:x) :d) :to-be :x)))

  (it "environment-presence-from-call-covers-every-arm"
    (flet ((p (values) (cl-boundary-kit::%environment-presence-from-call values)))
      (expect (p '()) :to-be nil)
      (expect (p '(:x t)) :to-be-truthy)
      (expect (p '(:x)) :to-be-truthy)
      (expect (p '(nil)) :to-be nil)))

  (it "normalize-environment-values-covers-empty-alist-and-plist-inputs"
    (flet ((n (input) (cl-boundary-kit::%normalize-environment-values input)))
      (expect (n '()) :to-be nil)
      (expect (n '((:a . 1))) :to-equal '((:a . 1)))
      (expect (n '(:a 1 :b 2)) :to-equal '((:a . 1) (:b . 2))))
    (expect (lambda () (cl-boundary-kit::%normalize-environment-values '(:a 1 :b))) :to-throw "INITIAL-VALUES must be an alist or plist")))

(describe "args-nth and random validation"
  (it "args-nth-rejects-a-non-integer-or-negative-index"
    (let ((args (make-test-args :arguments (list "a" "b"))))
      (expect (lambda () (args-nth args -1)) :to-throw "ARGS-NTH index must be a non-negative integer")
      (expect (lambda () (args-nth args :bad)) :to-throw "ARGS-NTH index must be a non-negative integer")
      (expect (args-nth args 9) :to-be nil)))

  (it "random-source-random-rejects-a-non-positive-limit"
    (let ((source (make-random-source)))
      (expect (lambda () (random-source-random source 0)) :to-throw "limit must be positive")
      (expect (lambda () (random-source-random source -5)) :to-throw "limit must be positive"))))

(describe "process-calls guard"
  (it "process-calls-rejects-a-non-recording-process-boundary"
    (expect (lambda () (cl-boundary-kit::%process-calls (make-process-boundary))) :to-throw "Unsupported process boundary type"))

  (it "record-process-call-rejects-a-non-recording-process-boundary"
    (expect (lambda () (cl-boundary-kit::%record-process-call (make-process-boundary) "noop")) :to-throw "Unsupported process boundary type"))

  (it "process-boundary-run-for-type-rejects-an-unrecognized-boundary-type"
    (expect (lambda ()
              (cl-boundary-kit::%process-boundary-run-for-type
               :bad (make-process-boundary) "noop" nil))
            :to-throw "Unsupported process boundary type"))

  (it "process-recorded-call-keys-names-the-keys-in-recorded-order"
    (expect cl-boundary-kit::+process-recorded-call-keys+
            :to-equal '(:arguments :input :directory :output :error-output :timeout))))

(describe "test-filesystem entry helpers"
  (it "copy-test-file-content-copies-strings-and-passes-other-values-through"
    (let ((original "abc"))
      (expect (cl-boundary-kit::%copy-test-file-content original) :to-equal "abc")
      (expect (eq (cl-boundary-kit::%copy-test-file-content original) original) :to-be nil))
    (expect (cl-boundary-kit::%copy-test-file-content 42) :to-be 42))

  (it "directory-path-prefix-normalizes-empty-slash-and-bare-directories"
    (flet ((p (d) (cl-boundary-kit::%directory-path-prefix d)))
      (expect (p "") :to-equal "")             ; empty stays empty
      (expect (p "/a/b/") :to-equal "/a/b/")   ; already slash-terminated
      (expect (p "/a/b") :to-equal "/a/b/"))))  ; slash appended

(describe "metric and rate-limiter validation"
  (it "metrics-count-and-timing-validate-their-arguments"
    (let ((metrics (make-test-metrics)))
      (expect (lambda () (metrics-count metrics 42 1)) :to-throw "Metric name must be a non-nil symbol or a string")
      (expect (lambda () (metrics-count metrics "hits" :bad)) :to-throw "must be a real number")
      (expect (lambda () (metrics-timing metrics "latency" -1)) :to-throw "Metric timing milliseconds must be a non-negative real number")))

  (it "make-test-rate-limiter-validates-capacity-and-refill-rate"
    (expect (lambda () (make-test-rate-limiter :capacity 0)) :to-throw "Rate limiter capacity must be a positive real number")
    (expect (lambda () (make-test-rate-limiter :refill-rate -1)) :to-throw "Rate limiter refill rate must be a non-negative real number")))

(describe "validation guards reject invalid operands"
  (it "random-source-random-rejects-a-non-real-limit"
    (expect (lambda () (random-source-random (make-random-source) "not-a-number")) :to-throw "limit must be positive"))

  (it "make-deterministic-random-source-rejects-non-integer-and-too-small-moduli"
    (expect (lambda () (make-deterministic-random-source :modulus 1)) :to-throw "modulus must be an integer greater than 1")
    (expect (lambda () (make-deterministic-random-source :modulus 3.5)) :to-throw "modulus must be an integer greater than 1"))

  (it "metrics-count-rejects-a-nil-symbol-name"
    (expect (lambda () (metrics-count (make-test-metrics) nil 1)) :to-throw "Metric name must be a non-nil symbol or a string"))

  (it "make-test-rate-limiter-rejects-non-real-capacity-and-refill-rate"
    (expect (lambda () (make-test-rate-limiter :capacity :not-real)) :to-throw "capacity must be a positive real number")
    (expect (lambda () (make-test-rate-limiter :refill-rate :not-real)) :to-throw "refill rate must be a non-negative real number")))

(describe "network and system dispatch completion"
  (it "network-call-storage-supports-known-boundaries-and-rejects-others"
    (let ((test-boundary (make-test-network-boundary :responses '()))
          (recording-boundary
            (make-recording-network-boundary
             :delegate (make-test-network-boundary :responses '()))))
      (setf (cl-boundary-kit::%network-calls test-boundary) '(:test-call)
            (cl-boundary-kit::%network-calls recording-boundary) '(:recording-call))
      (with-soft-assertions
        (expect (cl-boundary-kit::%network-calls test-boundary)
                :to-equal '(:test-call))
        (expect (cl-boundary-kit::%network-calls recording-boundary)
                :to-equal '(:recording-call))))
    (expect (lambda () (cl-boundary-kit::%network-calls :unsupported)) :to-throw "Unsupported network boundary type")
    (expect (lambda () (setf (cl-boundary-kit::%network-calls :unsupported) '())) :to-throw "Unsupported network boundary type"))

  (it "network-request-native-and-unsupported-dispatches-use-the-correct-method"
    (let* ((captured-request nil)
           (captured-timeout nil)
           (boundary
             (make-network-boundary
              :request-fn (lambda (request &key timeout)
                            (setf captured-request request
                                  captured-timeout timeout)
                            :response))))
      (expect (network-boundary-request boundary '(:method :get) :timeout 7)
              :to-be :response)
      (with-soft-assertions
        (expect captured-request :to-equal '(:method :get))
        (expect captured-timeout :to-be 7)))
    (expect (lambda ()
              (cl-boundary-kit::%network-boundary-request
               :unsupported '(:method :get) nil))
            :to-throw "Unsupported network boundary type"))

  (it "system-exit-uses-native-custom-exit-functions"
    (let* ((exit-codes '())
           (system
             (make-system-boundary
              :exit-fn (lambda (code)
                         (push code exit-codes)
                         code))))
      (with-soft-assertions
        (expect (system-exit system) :to-be 0)
        (expect (system-exit system 4) :to-be 4)
        (expect exit-codes :to-equal '(4 0)))))

  (it "recording-system-exit-validates-before-recording"
    (let ((system (make-recording-system-boundary)))
      (expect (lambda () (system-exit system -1)) :to-throw "SYSTEM-EXIT code must be a non-negative integer")
      (with-soft-assertions
        (expect (recording-system-calls system) :to-equal '())
        (expect (system-exit system 2) :to-be 2)
        (expect (recording-system-calls system)
                :to-have-recorded-calls (list (boundary-call-plist :exit (list 2) :result 2))))))

  (it "test-system-exit-codes-rejects-native-system-boundaries"
    (expect (lambda ()
              (test-system-exit-codes
               (make-system-boundary :exit-fn (lambda (code) code))))
            :to-throw "Unsupported system boundary type"))

  (it "network-call-log-accessor-updates-recording-boundaries"
    (let ((boundary
            (make-recording-network-boundary
             :delegate
             (make-network-boundary
              :request-fn (lambda (&rest arguments)
                            (declare (ignore arguments))
                            nil)))))
      (setf (cl-boundary-kit::%network-calls boundary) (list :recorded-call))
      (expect (cl-boundary-kit::%network-calls boundary) :to-equal (list :recorded-call)))))

(describe "requested public API completion"
  (it "recorded-call-query-functions-distinguish-supplied-nil-filters"
    (let* ((get-b-nil (boundary-call-plist :get '("b") :result nil))
           (get-a-one (boundary-call-plist :get '("a") :result 1))
           (get-a-nil (boundary-call-plist :get '("a") :result nil))
           (calls (list get-b-nil get-a-one get-a-nil
                        (boundary-call-plist :set '("a" 1) :result :stored))))
      (with-soft-assertions
        (expect (filter-recorded-calls calls :get)
                :to-equal (list get-b-nil get-a-one get-a-nil))
        (expect (filter-recorded-calls calls :get :arguments '("a"))
                :to-equal (list get-a-one get-a-nil))
        (expect (filter-recorded-calls calls :get :result nil)
                :to-equal (list get-b-nil get-a-nil))
        (expect (filter-recorded-calls calls :get :arguments '("a") :result nil)
                :to-equal (list get-a-nil))
        (expect (count-recorded-calls calls :get) :to-be 3)
        (expect (count-recorded-calls calls :get :arguments '("a")) :to-be 2)
        (expect (count-recorded-calls calls :get :result nil) :to-be 2)
        (expect (count-recorded-calls calls :get :arguments '("a") :result nil) :to-be 1)
        (expect (find-recorded-call calls :get) :to-equal get-b-nil)
        (expect (find-recorded-call calls :get :arguments '("a")) :to-equal get-a-one)
        (expect (find-recorded-call calls :get :result nil) :to-equal get-b-nil)
        (expect (find-recorded-call calls :get :arguments '("a") :result nil)
                :to-equal get-a-nil))))

  (it "sequential-temp-path-source-defaults-and-validates-constructor-arguments"
    (expect (temp-path-next (make-sequential-temp-path-source))
            :to-equal #P"/tmp/tmp-00000000")
    (signals error (make-sequential-temp-path-source :directory 42))
    (signals error (make-sequential-temp-path-source :prefix 42))
    (signals error (make-sequential-temp-path-source :suffix 42))
    (signals error (make-sequential-temp-path-source :start -1))
    (signals error (make-sequential-temp-path-source :start 1.5)))

  (it "test-filesystem-rejects-unsupported-existing-write-mode"
    (let ((filesystem
            (make-test-filesystem :initial-files (list #P"/tmp/existing.txt" "old"))))
      (expect (lambda () (filesystem-store-file filesystem #P"/tmp/existing.txt" "new" :if-exists :rename)) :to-throw "does not implement :IF-EXISTS :RENAME")))

  (it "native-process-boundary-distinguishes-omitted-and-explicit-nil-environment"
    (let* ((received-calls '())
           (process
             (make-process-boundary
              :run-fn (lambda (command &rest keywords)
                        (push (list command keywords) received-calls)
                        :completed))))
      (process-boundary-run process "inherit")
      (process-boundary-run process "empty" :environment nil)
      (let ((explicit-environment (first received-calls))
            (omitted-environment (second received-calls)))
        (with-soft-assertions
          (expect (member :environment (second omitted-environment)) :to-be nil)
          (expect (second explicit-environment) :to-contain :environment)
          (expect (getf (second explicit-environment) :environment) :to-be nil)))))

  (it "deterministic-random-source-normalizes-valid-seeds-by-modulus"
    (let ((wrapped-seed (make-deterministic-random-source :seed 8 :modulus 5))
          (canonical-seed (make-deterministic-random-source :seed 3 :modulus 5)))
      (with-soft-assertions
        (expect (random-source-random wrapped-seed 5)
                :to-be (random-source-random canonical-seed 5))
        (expect (random-source-random wrapped-seed 5)
                :to-be (random-source-random canonical-seed 5)))))
  (it "testing-query-helpers-handle-empty-histories-and-reject-symbol-indices"
    (with-soft-assertions
      (expect (recorded-call-operations (list)) :to-equal (list))
      (expect (recorded-call-results (list)) :to-equal (list))
      (expect (nth-recorded-call (list) 0) :to-be nil)
      (expect (last-recorded-call (list)) :to-be nil)
      (expect (filter-recorded-calls (list) :get) :to-equal (list))
      (expect (count-recorded-calls (list) :get) :to-be 0)
      (expect (find-recorded-call (list) :get) :to-be nil))
    (expect (lambda () (nth-recorded-call (list) :zero)) :to-throw "NTH-RECORDED-CALL index must be a non-negative integer"))

  (it "system-exit-validates-before-native-or-test-side-effects"
    (let ((native-exit-codes (list))
          (test-system (make-test-system-boundary)))
      (let ((native-system
              (make-system-boundary
               :exit-fn (lambda (code)
                          (push code native-exit-codes)
                          code))))
        (expect (lambda () (system-exit native-system :invalid)) :to-throw "SYSTEM-EXIT code must be a non-negative integer")
        (expect (lambda () (system-exit test-system :invalid)) :to-throw "SYSTEM-EXIT code must be a non-negative integer")
        (with-soft-assertions
          (expect native-exit-codes :to-equal (list))
          (expect (test-system-exit-codes test-system) :to-equal (list))
          (expect (system-exit native-system 3) :to-be 3)
          (expect (system-exit test-system 4) :to-be 4)
          (expect native-exit-codes :to-equal (list 3))
          (expect (test-system-exit-codes test-system) :to-equal (list 4)))))))
