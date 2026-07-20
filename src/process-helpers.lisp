(in-package #:cl-boundary-kit)

(defun %make-process-boundary-data (type &rest entries)
  (list* :boundary-type type entries))

(defun %process-boundary-type (boundary)
  (getf boundary :boundary-type))

(defun %process-boundary-p (boundary)
  (let ((type (%process-boundary-type boundary)))
    (or (eq type +process-boundary-type+)
        (eq type +test-process-boundary-type+)
        (eq type +recording-process-boundary-type+))))

(defun %recording-process-boundary-p (boundary)
  (let ((type (%process-boundary-type boundary)))
    (or (eq type +test-process-boundary-type+)
        (eq type +recording-process-boundary-type+))))

(defun %require-process-boundary (boundary name)
  (unless (%process-boundary-p boundary)
    (error "~A must be a process boundary: ~S" name boundary))
  boundary)

(defun %validate-test-process-results (results)
  (unless (listp results)
    (error "Test process boundary results must be a list: ~S" results))
  results)

(defun %process-calls (boundary)
  (if (%recording-process-boundary-p boundary)
      (getf boundary :calls)
      (error "Unsupported process boundary type: ~S" boundary)))

(defun %process-runner (boundary)
  (getf boundary :run-fn))

(defun %process-results (boundary)
  (getf boundary :results))

(defun %set-process-results (boundary results)
  (setf (getf boundary :results) results))

(defun %process-delegate (boundary)
  (getf boundary :delegate))

(defun %normalize-program (command arguments)
  (normalize-command command arguments))

(defun %capture-destination-p (destination)
  (or (null destination) (eq destination :string)))

(defun %process-output-option (destination)
  (if (%capture-destination-p destination)
      :stream
      destination))
