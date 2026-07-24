(in-package #:cl-boundary-kit)

(defun %plist-has-key-p (plist key)
  (loop for tail on plist by #'cddr
        thereis (eql (first tail) key)))

(defun %recorded-call-matches-p (call operation arguments arguments-supplied-p result result-supplied-p)
  (and (eql (getf call :operation) operation)
       (or (not arguments-supplied-p) (equal (getf call :arguments) arguments))
       (or (not result-supplied-p) (equal (getf call :result) result))))

(defun %recorded-call-expectation (operation arguments arguments-supplied-p result result-supplied-p)
  (list* :operation operation
         (when arguments-supplied-p
           (list :arguments arguments))
         (when result-supplied-p
           (list :result result))))

(defun %matching-recorded-calls (calls operation arguments arguments-supplied-p result result-supplied-p)
  (loop for call in calls
        when (%recorded-call-matches-p call
                                       operation
                                       arguments
                                       arguments-supplied-p
                                       result
                                       result-supplied-p)
        collect call))

(defun %recorded-call-sequence-entry-matches-p (call expectation)
  (%recorded-call-matches-p call
                            (getf expectation :operation)
                            (getf expectation :arguments)
                            (%plist-has-key-p expectation :arguments)
                            (getf expectation :result)
                            (%plist-has-key-p expectation :result)))

(defun %validate-recorded-call-expectation (expectation)
  (unless (listp expectation)
    (error "Recorded call expectation must be a plist, got ~S" expectation))
  (unless (%plist-has-key-p expectation :operation)
    (error "Recorded call expectation is missing :OPERATION: ~S" expectation))
  expectation)
