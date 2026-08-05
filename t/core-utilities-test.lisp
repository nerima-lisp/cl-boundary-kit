;;;; t/core-utilities-test.lisp
(in-package #:cl-boundary-kit/test)

(describe "core utilities"
  (it "do-plist-visits-each-key-value-pair-and-returns-its-result"
    (let ((pairs '()))
      (expect (cl-boundary-kit::do-plist
                  (key value '(:first 1 :second 2) :result (nreverse pairs))
                (push (cons key value) pairs))
              :to-equal '((:first . 1) (:second . 2)))))

  (it "copy-boundary-value-defensively-copies-bit-vectors"
    (let* ((original #*101)
           (copy (cl-boundary-kit::%copy-boundary-value original)))
      (setf (sbit copy 0) 0)
      (expect original :to-equalp #*101)
      (expect copy :to-equalp #*001))))
