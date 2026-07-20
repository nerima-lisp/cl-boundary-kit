;;;; src/network-test-boundary.lisp

(in-package #:cl-boundary-kit)

(defun make-test-network-boundary (&key responses)
  "Create a test network boundary that returns RESPONSES in order."
  (make-instance 'test-network-boundary
                 :request-fn nil
                 :responses (%copy-boundary-value (%validate-test-network-responses responses))))
