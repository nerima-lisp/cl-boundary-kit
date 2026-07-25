;;;; src/process-recording.lisp

(in-package #:cl-boundary-kit)

(define-recording-call-log recording-process-calls reset-recording-process-calls
    (boundary (satisfies %recording-process-boundary-p) %process-calls)
    "process boundary")

(defun %process-call-keywords (arguments input directory environment environment-supplied-p
                              output error-output timeout)
  ;; Only include :ENVIRONMENT when the caller actually supplied it, so an
  ;; omitted :ENVIRONMENT (inherit) stays distinguishable downstream from an
  ;; explicit empty '() (give the child nothing) all the way to the native
  ;; sb-ext:run-program call -- both would otherwise look identical as NIL.
  (list* :arguments arguments
         :input input
         :directory directory
         :output output
         :error-output error-output
         :timeout timeout
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
