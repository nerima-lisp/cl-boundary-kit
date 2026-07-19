;;;; t/recording-test.lisp

(in-package #:cl-boundary-kit/test)

(it "recording-boundary-invokes-handler"
  (let ((boundary (make-recording-boundary
                   :handler (lambda (operation &rest args)
                              (list :operation operation :args args)))))
    (expect (equal (recording-boundary-invoke boundary :ping 1 2)
               '(:operation :ping :args (1 2))) :to-be-truthy)
    (expect (= (length (recording-boundary-calls boundary)) 1) :to-be-truthy)
    (expect (equal (first (recording-boundary-calls boundary))
               '(:operation :ping :arguments (1 2) :result (:operation :ping :args (1 2)))) :to-be-truthy)))

(it "recording-boundary-preserves-nil-result"
  (let ((boundary (make-recording-boundary
                   :handler (lambda (&rest args)
                              (declare (ignore args))
                              nil))))
    (expect (null (recording-boundary-invoke boundary :noop)) :to-be-truthy)
    (expect (equal (first (recording-boundary-calls boundary))
               '(:operation :noop :arguments nil :result nil)) :to-be-truthy)))

(it "recording-boundary-propagates-handler-errors-without-recording"
  (let ((boundary (make-recording-boundary
                   :handler (lambda (&rest args)
                              (declare (ignore args))
                              (error "boom")))))
    (signals error
      (recording-boundary-invoke boundary :explode))
    (expect (null (recording-boundary-calls boundary)) :to-be-truthy)))

(it "make-recording-boundary-rejects-non-function-handler"
  (signals error
    (make-recording-boundary :handler :not-a-function)))

;;; Regression: the accessor used to return call plists that shared structure
;;; with the boundary's own history, so a caller editing a returned snapshot
;;; silently corrupted future reads.
(it "recording-boundary-calls-returns-an-independent-snapshot"
  (let ((boundary (make-recording-boundary
                   :handler (lambda (operation &rest args)
                              (list :operation operation :args args)))))
    (recording-boundary-invoke boundary :ping 1 2)
    (let ((snapshot (recording-boundary-calls boundary)))
      (setf (getf (first snapshot) :result) :tampered)
      (setf (first snapshot) :clobbered))
    (expect (equal (first (recording-boundary-calls boundary))
               '(:operation :ping :arguments (1 2) :result (:operation :ping :args (1 2))))
            :to-be-truthy)))

;;; Regression: RECORDING-BOUNDARY-INVOKE built its call record by hand
;;; instead of going through the shared %RECORD-CALL macro, so it never got
;;; the COPY-TREE write-time protection: mutating a list the caller still
;;; holds a reference to corrupted the boundary's own history before any
;;; snapshot was ever taken.
(it "recording-boundary-history-is-independent-of-a-mutated-argument"
  (let* ((arg (list 1 2 3))
         (boundary (make-recording-boundary
                    :handler (lambda (&rest args)
                               (declare (ignore args))
                               :ok))))
    (recording-boundary-invoke boundary :ping arg)
    (nreverse arg)
    (expect (equal (first (getf (first (recording-boundary-calls boundary)) :arguments))
               '(1 2 3))
            :to-be-truthy)))

(it "recording-boundary-history-is-independent-of-a-mutated-result"
  (let ((boundary (make-recording-boundary
                   :handler (lambda (&rest args)
                              (declare (ignore args))
                              (list 1 2 3)))))
    (let ((result (recording-boundary-invoke boundary :ping)))
      (nreverse result))
    (expect (equal (getf (first (recording-boundary-calls boundary)) :result)
               '(1 2 3))
            :to-be-truthy)))

(it "recording-boundary-calls-rejects-non-boundary-values"
  (signals error
    (recording-boundary-calls :not-a-boundary)))

(it "recording-boundary-invoke-rejects-non-boundary-values"
  (signals error
    (recording-boundary-invoke :not-a-boundary :ping)))
