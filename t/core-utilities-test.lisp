;;;; t/core-utilities-test.lisp
(in-package #:cl-boundary-kit/test)

(it
  "do-plist-visits-each-key-value-pair-and-returns-its-result"
  (let ((pairs '()))
    (expect
      (equal
        (cl-boundary-kit::do-plist
          (key value '(:first 1 :second 2) :result (nreverse pairs))
          (push (cons key value) pairs))
        '((:first . 1) (:second . 2)))
      :to-be-truthy)))

(it
  "copy-boundary-value-defensively-copies-bit-vectors"
  (let* ((original #*101)
         (copy (cl-boundary-kit::%copy-boundary-value original)))
    (setf (sbit copy 0) 0)
    (expect (equalp original #*101) :to-be-truthy)
    (expect (equalp copy #*001) :to-be-truthy)))
