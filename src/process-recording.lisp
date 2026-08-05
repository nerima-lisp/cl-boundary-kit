;;;; src/process-recording.lisp

(in-package #:cl-boundary-kit)

;;; DATA: the recording schema -- the keys every recorded process call carries,
;;; in recorded order -- kept apart from the assembly LOGIC in
;;; %PROCESS-CALL-KEYWORDS, which pairs them positionally with its arguments and
;;; appends :ENVIRONMENT only when the caller supplied one.
(defparameter +process-recorded-call-keys+
  '(:arguments :input :directory :output :error-output :timeout)
  "Keys every recorded process call carries, in recorded order.")

(define-recording-call-log recording-process-calls reset-recording-process-calls
    (boundary (satisfies %recording-process-boundary-p) %process-calls)
    "process boundary")

(defun %process-call-keywords (arguments input directory environment environment-supplied-p
                              output error-output timeout)
  ;; Only include :ENVIRONMENT when the caller actually supplied it, so an
  ;; omitted :ENVIRONMENT (inherit) stays distinguishable downstream from an
  ;; explicit empty '() (give the child nothing) all the way to the native
  ;; sb-ext:run-program call -- both would otherwise look identical as NIL.
  (nconc (mapcan #'list
                 +process-recorded-call-keys+
                 (list arguments input directory output error-output timeout))
         (when environment-supplied-p (list :environment environment))))

(defun %record-process-call
    (boundary command &key arguments input directory environment output error-output timeout result)
  (if (%recording-process-boundary-p boundary)
      (%record-call (getf boundary :calls)
        :command command
        :arguments arguments
        :input input
        :directory directory
        :environment environment
        :output output
        :error-output error-output
        :timeout timeout
        :result result)
      (error "Unsupported process boundary type: ~S" boundary)))

(defun %record-process-call-result (boundary command call-keywords result)
  (apply #'%record-process-call boundary command (list* :result result call-keywords))
  result)
