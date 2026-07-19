;;;; src/network-constructors.lisp

(in-package #:cl-boundary-kit)

(defun make-network-boundary (&key request-fn)
  "Create a network boundary backed by REQUEST-FN."
  (require-function request-fn "REQUEST-FN")
  (make-instance 'network-boundary :request-fn request-fn))
