;;;; src/process-recording.lisp

(in-package #:cl-boundary-kit)

(defun recording-process-calls (boundary)
  "Return the recorded process calls in call order."
  (%snapshot-recorded-calls (%process-calls boundary)))

(defun reset-recording-process-calls (boundary)
  "Clear BOUNDARY's recorded call history and return BOUNDARY.

Recording/test process boundaries otherwise retain every call for the
object's whole lifetime; call this periodically to bound memory growth
instead of only being able to reclaim it by discarding the object."
  (if (%recording-process-boundary-p boundary)
      (progn
        (setf (getf boundary :calls) nil)
        boundary)
      (error "Unsupported process boundary type: ~S" boundary)))

(defun %process-call-keywords (arguments input directory environment environment-supplied-p
                              output error-output timeout)
  ;; Only include :ENVIRONMENT when the caller actually supplied it, so an
  ;; omitted :ENVIRONMENT (inherit) stays distinguishable downstream from an
  ;; explicit empty '() (give the child nothing) all the way to the native
  ;; sb-ext:run-program call -- both would otherwise look identical as NIL.
  (append (list :arguments arguments
               :input input
               :directory directory)
          (when environment-supplied-p (list :environment environment))
          (list :output output
               :error-output error-output
               :timeout timeout)))

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
  (apply #'%record-process-call boundary command (append call-keywords (list :result result)))
  result)
