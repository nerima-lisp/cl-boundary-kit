;;;; t/logging-kit-adapter-test.lisp

(in-package #:cl-boundary-kit/test)

(defun captured-log-kit-logger (records)
  "Return a log-kit:logger whose emitted records are pushed onto RECORDS,
a fresh list cell usable as (first (captured-log-kit-logger-records ...))."
  (log-kit:make-logger
   :level log-kit:+level-debug+
   :handler (log-kit:make-function-handler
             (lambda (record) (push record (car records))))))

(it "make-log-kit-sink-fn-forwards-events-to-a-log-kit-logger"
  (let* ((records (list '()))
         (sink-logger (captured-log-kit-logger records))
         (logger (make-logger
                  :timestamp-fn (lambda () 42)
                  :sink-fn (make-log-kit-sink-fn sink-logger))))
    (logger-info logger "handled request" :request-id "req-9")
    (let ((emitted (first (car records))))
      (expect (not (null emitted)) :to-be-truthy)
      (expect (= log-kit:+level-info+ (log-kit:log-record-level emitted)) :to-be-truthy)
      (expect (string= "handled request" (log-kit:log-record-message emitted)) :to-be-truthy)
      (expect (equal '((:request-id . "req-9")) (log-kit:log-record-fields emitted)) :to-be-truthy))))

(it "make-log-kit-sink-fn-maps-every-standard-level"
  (let* ((records (list '()))
         (sink-logger (captured-log-kit-logger records))
         (logger (make-logger
                  :timestamp-fn (lambda () 0)
                  :sink-fn (make-log-kit-sink-fn sink-logger))))
    (logger-debug logger "d")
    (logger-info logger "i")
    (logger-warn logger "w")
    (logger-error logger "e")
    (let ((levels (mapcar #'log-kit:log-record-level (reverse (car records)))))
      (expect (equal (list log-kit:+level-debug+ log-kit:+level-info+
                       log-kit:+level-warn+ log-kit:+level-error+)
                 levels)
              :to-be-truthy))))

(it "make-log-kit-sink-fn-respects-the-log-kit-logger-level-threshold"
  (let* ((records (list '()))
         (sink-logger (log-kit:make-logger
                       :level log-kit:+level-warn+
                       :handler (log-kit:make-function-handler
                                 (lambda (record) (push record (car records))))))
         (logger (make-logger
                  :timestamp-fn (lambda () 0)
                  :sink-fn (make-log-kit-sink-fn sink-logger))))
    (logger-info logger "filtered")
    (logger-error logger "kept")
    (expect (= 1 (length (car records))) :to-be-truthy)
    (expect (string= "kept" (log-kit:log-record-message (first (car records)))) :to-be-truthy)))

(it "make-log-kit-sink-fn-rejects-a-non-log-kit-logger"
  (signals error
    (make-log-kit-sink-fn :bad)))
