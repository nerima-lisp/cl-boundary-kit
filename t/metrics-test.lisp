;;;; t/metrics-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-metrics-forwards-events-to-its-emit-fn-and-returns-them"
  (let* ((emitted '())
         (metrics (make-metrics :emit-fn (lambda (event) (push event emitted)))))
    (let ((event (metrics-count metrics "hits" 3)))
      (expect (equal (list :type :count :name "hits" :value 3) event) :to-be-truthy)
      (expect (equal event (first emitted)) :to-be-truthy)
      (expect (not (eq event (first emitted))) :to-be-truthy))))

(it "make-metrics-rejects-a-non-function-emit-fn"
  (signals error
    (make-metrics :emit-fn :bad)))

(it "test-metrics-records-count-gauge-and-timing-events-in-order"
  (let ((metrics (make-test-metrics)))
    (metrics-count metrics "requests" 1)
    (metrics-gauge metrics "queue-depth" 7)
    (metrics-timing metrics "request-ms" 42)
    (expect (equal (recording-metric-events metrics)
                   (list (list :type :count :name "requests" :value 1)
                         (list :type :gauge :name "queue-depth" :value 7)
                         (list :type :timing :name "request-ms" :value 42))) :to-be-truthy)))

(it "metrics-operations-return-an-independent-recorded-event"
  (let* ((metrics (make-test-metrics))
         (event (metrics-gauge metrics "depth" 2)))
    (expect (equal event (first (recording-metric-events metrics))) :to-be-truthy)
    (expect (not (eq event (first (recording-metric-events metrics)))) :to-be-truthy)))

(it "metrics-reject-invalid-names-values-and-timings"
  (let ((metrics (make-test-metrics)))
    (signals error
      (metrics-count metrics nil 1))
    (signals error
      (metrics-gauge metrics "g" :not-a-number))
    (signals error
      (metrics-timing metrics "t" -1))))

(it "metrics-accept-symbol-names"
  (let ((metrics (make-test-metrics)))
    (expect (equal (list :type :count :name :hits :value 5)
                   (metrics-count metrics :hits 5)) :to-be-truthy)))

(it "recording-metrics-records-events-and-forwards-them-to-a-delegate"
  (let* ((forwarded '())
         (delegate (make-metrics :emit-fn (lambda (event) (push event forwarded))))
         (metrics (make-recording-metrics :delegate delegate))
         (event (metrics-count metrics "hits" 1)))
    (expect (equal event (first (recording-metric-events metrics))) :to-be-truthy)
    (expect (equal event (first forwarded)) :to-be-truthy)
    (expect (not (eq event (first (recording-metric-events metrics)))) :to-be-truthy)
    (expect (not (eq event (first forwarded))) :to-be-truthy)))

(it "recording-metric-events-returns-independent-snapshots"
  (let* ((metrics (make-test-metrics))
         (event (metrics-count metrics (copy-seq "hits") 3)))
    (setf (char (getf event :name) 0) #\m
          (getf event :value) 99)
    (expect (equal (list (list :type :count :name "hits" :value 3))
                   (recording-metric-events metrics)) :to-be-truthy)))

(it "make-recording-metrics-defaults-to-a-no-op-sink"
  (let ((metrics (make-recording-metrics)))
    (metrics-count metrics "hits" 1)
    (expect (= 1 (length (recording-metric-events metrics))) :to-be-truthy)))

(it "make-recording-metrics-rejects-a-non-metrics-delegate"
  (signals error
    (make-recording-metrics :delegate :bad)))

(it "recording-metric-events-signals-for-unsupported-metrics-types"
  (signals error
    (recording-metric-events (make-metrics))))

(it "reset-recording-metric-events-clears-history-and-returns-the-metrics"
  (let ((metrics (make-test-metrics)))
    (metrics-count metrics "hits" 1)
    (expect (= 1 (length (recording-metric-events metrics))) :to-be-truthy)
    (expect (eq metrics (reset-recording-metric-events metrics)) :to-be-truthy)
    (expect (null (recording-metric-events metrics)) :to-be-truthy)))

(it "reset-recording-metric-events-signals-for-unsupported-metrics-types"
  (signals error
    (reset-recording-metric-events (make-metrics))))

(it "metrics-increment-emits-a-counter-of-one"
  (let ((metrics (make-test-metrics)))
    (expect (equal (list :type :count :name "hits" :value 1)
                   (metrics-increment metrics "hits")) :to-be-truthy)
    (expect (= 1 (length (recording-metric-events metrics))) :to-be-truthy)))

(it "reset-recording-metric-events-clears-a-test-metrics-history"
  (let ((metrics (make-test-metrics)))
    (metrics-count metrics "hits" 1)
    (expect (= 1 (length (recording-metric-events metrics))) :to-be-truthy)
    (expect (eq metrics (reset-recording-metric-events metrics)) :to-be-truthy)
    (expect (null (recording-metric-events metrics)) :to-be-truthy)))

(it "reset-recording-metric-events-clears-a-recording-metrics-history"
  (let ((metrics (make-recording-metrics)))
    (metrics-count metrics "hits" 1)
    (expect (eq metrics (reset-recording-metric-events metrics)) :to-be-truthy)
    (expect (null (recording-metric-events metrics)) :to-be-truthy)))
