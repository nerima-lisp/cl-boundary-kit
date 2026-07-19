;;;; src/process-recording.lisp

(in-package #:cl-boundary-kit)

(defun recording-process-calls (boundary)
  "Return the recorded process calls in call order."
  (%snapshot-recorded-calls (%process-calls boundary)))

(defun %process-call-keywords (arguments input directory environment output error-output timeout)
  (list :arguments arguments
        :input input
        :directory directory
        :environment environment
        :output output
        :error-output error-output
        :timeout timeout))

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
