;;;; t/metrics-test.lisp

(in-package #:cl-boundary-kit/test)

(defvar *test-metrics* nil)

(describe "metrics"
  (it "make-metrics-forwards-events-to-its-emit-fn-and-returns-them"
    (let* ((emitted '())
           (metrics (make-metrics :emit-fn (lambda (event) (push event emitted)))))
      (let ((event (metrics-count metrics "hits" 3)))
        (expect event :to-equal (list :type :count :name "hits" :value 3))
        (expect event :to-equal (first emitted))
        (expect event :not :to-be (first emitted)))))

  (it "make-metrics-rejects-a-non-function-emit-fn"
    (signals error
      (make-metrics :emit-fn :bad))))

(describe "test metrics"
  (before-each
    (setf *test-metrics* (make-test-metrics)))

  (it "test-metrics-records-count-gauge-and-timing-events-in-order"
    (metrics-count *test-metrics* "requests" 1)
    (metrics-gauge *test-metrics* "queue-depth" 7)
    (metrics-timing *test-metrics* "request-ms" 42)
    (expect (recording-metric-events *test-metrics*)
            :to-equal (list (list :type :count :name "requests" :value 1)
                            (list :type :gauge :name "queue-depth" :value 7)
                            (list :type :timing :name "request-ms" :value 42))))

  (it "metrics-operations-return-an-independent-recorded-event"
    (let ((event (metrics-gauge *test-metrics* "depth" 2)))
      (expect event :to-equal (first (recording-metric-events *test-metrics*)))
      (expect event :not :to-be (first (recording-metric-events *test-metrics*)))))

  (it "metrics-reject-invalid-names-values-and-timings"
    (signals error
      (metrics-count *test-metrics* nil 1))
    (signals error
      (metrics-gauge *test-metrics* "g" :not-a-number))
    (signals error
      (metrics-timing *test-metrics* "t" -1)))

  (it "metrics-accept-symbol-names"
    (expect (metrics-count *test-metrics* :hits 5) :to-equal (list :type :count :name :hits :value 5))))

(describe "recording metrics"
  (it "recording-metrics-records-events-and-forwards-them-to-a-delegate"
    (let* ((forwarded '())
           (delegate (make-metrics :emit-fn (lambda (event) (push event forwarded))))
           (metrics (make-recording-metrics :delegate delegate))
           (event (metrics-count metrics "hits" 1)))
      (expect event :to-equal (first (recording-metric-events metrics)))
      (expect event :to-equal (first forwarded))
      (expect event :not :to-be (first (recording-metric-events metrics)))
      (expect event :not :to-be (first forwarded))))

  (it "recording-metric-events-returns-independent-snapshots"
    (let* ((metrics (make-test-metrics))
           (event (metrics-count metrics (copy-seq "hits") 3)))
      (setf (char (getf event :name) 0) #\m
            (getf event :value) 99)
      (expect (recording-metric-events metrics) :to-equal (list (list :type :count :name "hits" :value 3)))))

  (it "make-recording-metrics-defaults-to-a-no-op-sink"
    (let ((metrics (make-recording-metrics)))
      (metrics-count metrics "hits" 1)
      (expect (recording-metric-events metrics) :to-have-length 1)))

  (it "make-recording-metrics-rejects-a-non-metrics-delegate"
    (signals error
      (make-recording-metrics :delegate :bad))))

(describe "recording-metric-events and reset"
  (before-each
    (setf *test-metrics* (make-test-metrics)))

  (it-each ((recording-metric-events)
            (reset-recording-metric-events))
      "~A signals for unsupported metrics types"
      (operation)
    (expect (lambda () (funcall operation (make-metrics))) :to-throw "Unsupported metrics type"))

  (it "reset-recording-metric-events-clears-history-and-returns-the-metrics"
    (metrics-count *test-metrics* "hits" 1)
    (expect (recording-metric-events *test-metrics*) :to-have-length 1)
    (expect (reset-recording-metric-events *test-metrics*) :to-be *test-metrics*)
    (expect (recording-metric-events *test-metrics*) :to-be-null))

  (it "metrics-increment-emits-a-counter-of-one"
    (expect (metrics-increment *test-metrics* "hits") :to-equal (list :type :count :name "hits" :value 1))
    (expect (recording-metric-events *test-metrics*) :to-have-length 1))

  (it "reset-recording-metric-events-clears-a-recording-metrics-history"
    (let ((metrics (make-recording-metrics)))
      (metrics-count metrics "hits" 1)
      (expect (reset-recording-metric-events metrics) :to-be metrics)
      (expect (recording-metric-events metrics) :to-be-null))))
