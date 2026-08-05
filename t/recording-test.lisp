;;;; t/recording-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "recording-boundary handler contract"
  ;; Every other MAKE-RECORDING-BOUNDARY test below supplies an explicit
  ;; :HANDLER; exercise the &KEY default (an ignore-everything, return-NIL
  ;; handler) too.
  (it "recording-boundary-defaults-to-a-handler-that-returns-nil"
    (let ((boundary (make-recording-boundary)))
      (expect (recording-boundary-invoke boundary :ping 1 2) :to-be-null)
      (expect (recording-boundary-calls boundary) :to-have-length 1)))

  (it "recording-boundary-invokes-handler"
    (let ((boundary (make-recording-boundary
                     :handler (lambda (operation &rest args)
                                (list :operation operation :args args)))))
      (expect (recording-boundary-invoke boundary :ping 1 2) :to-equal '(:operation :ping :args (1 2)))
      (expect (recording-boundary-calls boundary) :to-have-length 1)
      (expect (first (recording-boundary-calls boundary)) :to-equal '(:operation :ping :arguments (1 2) :result (:operation :ping :args (1 2))))))

  (it "recording-boundary-preserves-nil-result"
    (let ((boundary (make-recording-boundary
                     :handler (lambda (&rest args)
                                (declare (ignore args))
                                nil))))
      (expect (recording-boundary-invoke boundary :noop) :to-be-null)
      (expect (first (recording-boundary-calls boundary)) :to-equal '(:operation :noop :arguments nil :result nil))))

  (it "recording-boundary-propagates-handler-errors-without-recording"
    (let ((boundary (make-recording-boundary
                     :handler (lambda (&rest args)
                                (declare (ignore args))
                                (error "boom")))))
      (signals error
        (recording-boundary-invoke boundary :explode))
      (expect (recording-boundary-calls boundary) :to-be-null)))

  (it "make-recording-boundary-rejects-non-function-handler"
    (signals error
      (make-recording-boundary :handler :not-a-function))))

(describe "recording-boundary history isolation"
  ;; Regression: the accessor used to return call plists that shared structure
  ;; with the boundary's own history, so a caller editing a returned snapshot
  ;; silently corrupted future reads.
  (it "recording-boundary-calls-returns-an-independent-snapshot"
    (let ((boundary (make-recording-boundary
                     :handler (lambda (operation &rest args)
                                (list :operation operation :args args)))))
      (recording-boundary-invoke boundary :ping 1 2)
      (let ((snapshot (recording-boundary-calls boundary)))
        (setf (getf (first snapshot) :result) :tampered)
        (setf (first snapshot) :clobbered))
      (expect (first (recording-boundary-calls boundary)) :to-equal '(:operation :ping :arguments (1 2) :result (:operation :ping :args (1 2))))))

  ;; Regression: RECORDING-BOUNDARY-INVOKE built its call record by hand
  ;; instead of going through the shared %RECORD-CALL macro, so it never got
  ;; the COPY-TREE write-time protection: mutating a list the caller still
  ;; holds a reference to corrupted the boundary's own history before any
  ;; snapshot was ever taken.
  (it "recording-boundary-history-is-independent-of-a-mutated-argument"
    (let* ((arg (list 1 2 3))
           (boundary (make-recording-boundary
                      :handler (lambda (&rest args)
                                 (declare (ignore args))
                                 :ok))))
      (recording-boundary-invoke boundary :ping arg)
      (setf arg (nreverse arg))
      (expect (first (getf (first (recording-boundary-calls boundary)) :arguments)) :to-equal '(1 2 3))))

  (it "recording-boundary-history-is-independent-of-a-mutated-result"
    (let ((boundary (make-recording-boundary
                     :handler (lambda (&rest args)
                                (declare (ignore args))
                                (list 1 2 3)))))
      (let ((result (recording-boundary-invoke boundary :ping)))
        (setf result (nreverse result)))
      (expect (getf (first (recording-boundary-calls boundary)) :result) :to-equal '(1 2 3))))

  (it "recording-boundary-defensively-copies-vector-arguments-in-its-history"
    ;; Exercises the vector arm of %COPY-BOUNDARY-VALUE: a recorded vector
    ;; argument is deep-copied, so mutating the original afterward cannot alter
    ;; the stored history.
    (let* ((argument (vector 1 2 3))
           (boundary (make-recording-boundary
                      :handler (lambda (operation &rest args)
                                 (declare (ignore operation args))
                                 :ok))))
      (recording-boundary-invoke boundary :store argument)
      (setf (aref argument 0) 99)
      (let ((recorded-argument (first (getf (first (recording-boundary-calls boundary)) :arguments))))
        (expect recorded-argument :to-equalp (vector 1 2 3))))))

(describe "recording-boundary type validation and reset"
  (it "recording-boundary-calls-rejects-non-boundary-values"
    (signals error
      (recording-boundary-calls :not-a-boundary)))

  (it "recording-boundary-invoke-rejects-non-boundary-values"
    (signals error
      (recording-boundary-invoke :not-a-boundary :ping)))

  (deftest-reset-recording-clears-history
      "reset-recording-boundary-calls-clears-history-and-returns-the-boundary"
      (boundary (make-recording-boundary
                 :handler (lambda (&rest args) (declare (ignore args)) :ok)))
      (recording-boundary-calls reset-recording-boundary-calls)
    (recording-boundary-invoke boundary :ping))

  (it "reset-recording-boundary-calls-rejects-non-boundary-values"
    (signals error
      (reset-recording-boundary-calls :not-a-boundary))))
