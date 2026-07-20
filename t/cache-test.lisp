;;;; t/cache-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-cache-stores-and-reads-values-with-present-p"
  (let ((cache (make-test-cache)))
    (expect (= 1 (cache-put cache "k" 1)) :to-be-truthy)
    (multiple-value-bind (value present) (cache-get cache "k")
      (expect (= 1 value) :to-be-truthy)
      (expect (eq t present) :to-be-truthy))
    (multiple-value-bind (value present) (cache-get cache "missing" :default)
      (expect (eq :default value) :to-be-truthy)
      (expect (null present) :to-be-truthy))))

(it "test-cache-distinguishes-a-stored-nil-from-a-missing-key"
  (let ((cache (make-test-cache)))
    (cache-put cache "k" nil)
    (multiple-value-bind (value present) (cache-get cache "k" :default)
      (expect (null value) :to-be-truthy)
      (expect (eq t present) :to-be-truthy))))

(it "test-cache-expires-entries-once-the-ttl-passes"
  (let* ((now 0)
         (cache (make-test-cache :now-fn (lambda () now))))
    (cache-put cache "k" "v" :ttl 10)
    (expect (string= "v" (cache-get cache "k")) :to-be-truthy)
    (setf now 9)
    (expect (string= "v" (cache-get cache "k")) :to-be-truthy)
    (setf now 10)
    (multiple-value-bind (value present) (cache-get cache "k" :gone)
      (expect (eq :gone value) :to-be-truthy)
      (expect (null present) :to-be-truthy))))

(it "test-cache-entries-without-a-ttl-never-expire"
  (let* ((now 0)
         (cache (make-test-cache :now-fn (lambda () now))))
    (cache-put cache "k" "v")
    (setf now 1000000)
    (expect (string= "v" (cache-get cache "k")) :to-be-truthy)))

(it "test-cache-evict-removes-an-entry-and-reports-presence"
  (let ((cache (make-test-cache)))
    (cache-put cache "k" 1)
    (expect (eq t (cache-evict cache "k")) :to-be-truthy)
    (expect (null (cache-evict cache "k")) :to-be-truthy)
    (multiple-value-bind (value present) (cache-get cache "k" :gone)
      (declare (ignore value))
      (expect (null present) :to-be-truthy))))

(it "cache-put-rejects-a-non-positive-ttl"
  (let ((cache (make-test-cache)))
    (signals error
      (cache-put cache "k" 1 :ttl 0))
    (signals error
      (cache-put cache "k" 1 :ttl -5))))

(it "test-cache-accepts-non-expiring-initial-entries"
  (let ((cache (make-test-cache :initial '(("k" . 1)))))
    (expect (= 1 (cache-get cache "k")) :to-be-truthy)))

(it "make-cache-wires-injected-collaborators"
  (let* ((events '())
         (cache (make-cache
                 :get-fn (lambda (key default) (push (list :get key) events) (values default nil))
                 :put-fn (lambda (key value ttl) (push (list :put key value ttl) events) value)
                 :evict-fn (lambda (key) (push (list :evict key) events) t))))
    (cache-put cache "k" 7 :ttl 3)
    (cache-get cache "k")
    (cache-evict cache "k")
    (expect (equal (list (list :evict "k") (list :get "k") (list :put "k" 7 3)) events) :to-be-truthy)))

(it "make-cache-rejects-non-function-collaborators"
  (signals error
    (make-cache :get-fn :bad
                :put-fn (lambda (k v ttl) v)
                :evict-fn (lambda (k) k))))

(it "recording-cache-records-every-operation"
  (let ((cache (make-recording-cache)))
    (cache-put cache "k" 1 :ttl 5)
    (cache-get cache "k" :default)
    (cache-evict cache "k")
    (expect (equal (recording-cache-calls cache)
                   (list (boundary-call-plist :put (list "k" 1 5) :result 1)
                         (boundary-call-plist :get (list "k" :default) :result 1)
                         (boundary-call-plist :evict (list "k") :result t))) :to-be-truthy)))

(it "make-recording-cache-rejects-a-non-cache-delegate"
  (signals error
    (make-recording-cache :delegate :bad)))

(it "recording-cache-calls-signals-for-unsupported-cache-types"
  (signals error
    (recording-cache-calls (make-test-cache))))

(it "reset-recording-cache-calls-clears-history-and-returns-the-cache"
  (let ((cache (make-recording-cache)))
    (cache-put cache "k" 1)
    (expect (= 1 (length (recording-cache-calls cache))) :to-be-truthy)
    (expect (eq cache (reset-recording-cache-calls cache)) :to-be-truthy)
    (expect (null (recording-cache-calls cache)) :to-be-truthy)))

(it "reset-recording-cache-calls-signals-for-unsupported-cache-types"
  (signals error
    (reset-recording-cache-calls (make-test-cache))))

(it "cache-fetch-computes-and-stores-a-value-only-on-a-miss"
  (let* ((cache (make-test-cache))
         (calls 0))
    (flet ((compute () (incf calls) "value"))
      (expect (string= "value" (cache-fetch cache "k" #'compute)) :to-be-truthy)
      ;; Second fetch is a hit, so the thunk is not called again.
      (expect (string= "value" (cache-fetch cache "k" #'compute)) :to-be-truthy)
      (expect (= 1 calls) :to-be-truthy))))

(it "cache-fetch-honors-the-ttl-when-storing-a-computed-value"
  (let* ((now 0)
         (cache (make-test-cache :now-fn (lambda () now)))
         (calls 0))
    (flet ((compute () (incf calls) "value"))
      (cache-fetch cache "k" #'compute :ttl 10)
      (setf now 10)
      ;; The stored entry has expired, so the thunk runs again.
      (cache-fetch cache "k" #'compute :ttl 10)
      (expect (= 2 calls) :to-be-truthy))))

(it "cache-fetch-rejects-a-non-function-thunk"
  (signals error
    (cache-fetch (make-test-cache) "k" :bad)))

(it "test-cache-clear-empties-the-cache"
  (let ((cache (make-test-cache :initial '(("a" . 1) ("b" . 2)))))
    (expect (eq cache (cache-clear cache)) :to-be-truthy)
    (multiple-value-bind (value present) (cache-get cache "a" :gone)
      (declare (ignore value))
      (expect (null present) :to-be-truthy))))

(it "native-cache-clear-is-unsupported-without-a-clear-fn"
  (let ((cache (make-cache :get-fn (lambda (k d) (declare (ignore k)) (values d nil))
                           :put-fn (lambda (k v ttl) (declare (ignore k ttl)) v)
                           :evict-fn (lambda (k) (declare (ignore k)) nil))))
    (signals cl-boundary-kit:unsupported-boundary-operation
      (cache-clear cache))))

(it "native-cache-clear-uses-an-injected-clear-fn"
  (let* ((cleared 0)
         (cache (make-cache :get-fn (lambda (k d) (declare (ignore k)) (values d nil))
                            :put-fn (lambda (k v ttl) (declare (ignore k ttl)) v)
                            :evict-fn (lambda (k) (declare (ignore k)) nil)
                            :clear-fn (lambda () (incf cleared)))))
    (expect (eq cache (cache-clear cache)) :to-be-truthy)
    (expect (= 1 cleared) :to-be-truthy)))

(it "recording-cache-records-clear"
  (let ((cache (make-recording-cache :delegate (make-test-cache :initial '(("a" . 1))))))
    (cache-clear cache)
    (expect (equal (recording-cache-calls cache)
                   (list (boundary-call-plist :clear '() :result t))) :to-be-truthy)))
