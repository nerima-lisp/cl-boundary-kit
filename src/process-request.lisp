;;;; src/process-request.lisp

(in-package #:cl-boundary-kit)

(declaim (ftype function process-boundary-run))

(defgeneric %process-boundary-run-for-type (boundary-type process-boundary command call-keywords))

;; Each method below performs only the raw effect (native execution, or
;; consuming one queued test result) with no recording. Recording is
;; applied once, externally, by PROCESS-BOUNDARY-RUN for :TEST and
;; :RECORDING kinds, so a recording boundary's delegate -- even a
;; self-recording :TEST-kind delegate -- is dispatched through its own raw
;; effect here rather than re-entering its public PROCESS-BOUNDARY-RUN and
;; double-recording the call.

(defun %process-boundary-run-test (process-boundary command call-keywords)
  (declare (ignore call-keywords))
  (let ((results (%process-results process-boundary)))
    (unless results
      (error "Test process boundary has no remaining results for command ~S" command))
    (let ((result (first results)))
      (%set-process-results process-boundary (rest results))
      result)))

(defun %process-boundary-run-recording (process-boundary command call-keywords)
  (let ((delegate (%process-delegate process-boundary)))
    (%process-boundary-run-for-type (%process-boundary-type delegate)
                                    delegate
                                    command
                                    call-keywords)))

(defun %process-boundary-run-native (process-boundary command call-keywords)
  (apply (%process-runner process-boundary) command call-keywords))

(defmacro define-process-boundary-run-method (boundary-type
                                              (process-boundary command call-keywords)
                                              &body body)
  `(defmethod %process-boundary-run-for-type ((boundary-type ,boundary-type)
                                              ,process-boundary
                                              ,command
                                              ,call-keywords)
     (declare (ignore boundary-type))
     ,@body))

(define-process-boundary-run-method (eql :test-process-boundary)
    (process-boundary command call-keywords)
  (%process-boundary-run-test process-boundary command call-keywords))

(define-process-boundary-run-method (eql :recording-process-boundary)
    (process-boundary command call-keywords)
  (%process-boundary-run-recording process-boundary command call-keywords))

(define-process-boundary-run-method (eql :process-boundary)
    (process-boundary command call-keywords)
  (%process-boundary-run-native process-boundary command call-keywords))

(defmethod %process-boundary-run-for-type ((boundary-type t) process-boundary command call-keywords)
  (declare (ignore boundary-type command call-keywords))
  (error "Unsupported process boundary type: ~S" process-boundary))

(defun process-boundary-run
    (process-boundary command &key arguments input directory
                              (environment nil environment-supplied-p)
                              output error-output timeout)
  "Run COMMAND through PROCESS-BOUNDARY and return the process result."
  (%require-process-boundary process-boundary "PROCESS-BOUNDARY")
  (let* ((call-keywords (%process-call-keywords arguments
                                                input
                                                directory
                                                environment
                                                environment-supplied-p
                                                output
                                                error-output
                                                timeout))
         (run (lambda ()
                (%process-boundary-run-for-type (%process-boundary-type process-boundary)
                                                process-boundary
                                                command
                                                call-keywords))))
    (if (%recording-process-boundary-p process-boundary)
        (%record-process-call-result process-boundary command call-keywords (funcall run))
        (funcall run))))
