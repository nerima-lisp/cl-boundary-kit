(in-package #:cl-boundary-kit)

(defun %make-process-boundary-data (type &rest entries)
  (list* :boundary-type type entries))

(define-plist-accessor %process-boundary-type boundary :boundary-type)

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

(define-list-validator %validate-test-process-results results "Test process boundary results")

(defun %process-calls (boundary)
  (if (%recording-process-boundary-p boundary)
      (getf boundary :calls)
      (error "Unsupported process boundary type: ~S" boundary)))

(defun (setf %process-calls) (new-value boundary)
  (setf (getf boundary :calls) new-value))

(define-plist-accessor %process-runner boundary :run-fn)

(define-plist-accessor %process-results boundary :results)

(defun %set-process-results (boundary results)
  (setf (getf boundary :results) results))

(define-plist-accessor %process-delegate boundary :delegate)

(defun %normalize-program (command arguments)
  (normalize-command command arguments))

(defun %capture-destination-p (destination)
  (or (null destination) (eq destination :string)))

(defun %process-output-option (destination)
  (if (%capture-destination-p destination)
      :stream
      destination))
