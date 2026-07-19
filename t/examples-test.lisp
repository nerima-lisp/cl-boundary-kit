;;;; t/examples-test.lisp

(in-package #:cl-boundary-kit/test)

(defun read-all-forms (string)
  (with-input-from-string (input string)
    (loop for form = (read input nil input)
          until (eq form input)
          collect form)))

(defun eval-forms (forms)
  (let ((result nil))
    (dolist (form forms result)
      (setf result (eval form)))))

(defun eval-readme-snippet (snippet)
  (eval-forms (read-all-forms snippet)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *readme-snippet-contracts*
    '((:prefix "README-QUICK-START"
     :start-heading "## Quick Start"
     :end-heading "## Core Concepts"
     :expected-results
     ((1000 1005)
      (:RESULT
       (:PATH #P"example.txt"
        :CONTENT "hello"
        :IF-EXISTS :APPEND
        :IF-DOES-NOT-EXIST :CREATE
        :EXTERNAL-FORMAT :UTF-8)
       :CALLS
       ((:OPERATION :WRITE-FILE
         :ARGUMENTS
         (#P"example.txt"
          :CONTENT "hello"
          :IF-EXISTS :APPEND
          :IF-DOES-NOT-EXIST :CREATE
          :EXTERNAL-FORMAT :UTF-8)
         :RESULT
         (:PATH #P"example.txt"
          :CONTENT "hello"
          :IF-EXISTS :APPEND
          :IF-DOES-NOT-EXIST :CREATE
          :EXTERNAL-FORMAT :UTF-8))))))
    (:prefix "README-TESTING-HELPER"
     :start-heading "### Testing Helper"
     :end-heading "### Boundary Context"
     :expected-results
     ((:OPERATION :WRITE-FILE
       :ARGUMENTS (#P"example.txt"
                   :CONTENT "hello"
                   :IF-EXISTS NIL
                   :IF-DOES-NOT-EXIST NIL
                   :EXTERNAL-FORMAT NIL)
       :RESULT (:PATH #P"example.txt"
                :CONTENT "hello"
                :IF-EXISTS NIL
                :IF-DOES-NOT-EXIST NIL
                :EXTERNAL-FORMAT NIL))
      (:OPERATION :WRITE-FILE
       :ARGUMENTS (#P"example.txt" :CONTENT "hello")
       :RESULT T))))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  ;; Called at macroexpansion time by DEFINE-README-SNIPPET-CONTRACT-TESTS,
  ;; so it must be available in the compile-time environment.
  (defun readme-snippet-test-symbol (prefix suffix)
    ;; cl-weave's IT evaluates its name argument, so test names must be
    ;; literal strings, not interned symbols.
    (string-downcase (format nil "~A-~A" prefix suffix))))

(defmacro define-readme-snippet-contract-tests (contracts)
  (let ((resolved-contracts (if (and (symbolp contracts) (boundp contracts))
                                (symbol-value contracts)
                                contracts)))
    `(progn
       ,@(loop for contract in resolved-contracts
             append
             (let* ((prefix (getf contract :prefix))
                    (start-heading (getf contract :start-heading))
                    (end-heading (getf contract :end-heading))
                    (expected-results (getf contract :expected-results)))
               (cons
                `(it ,(readme-snippet-test-symbol prefix "COUNT-MATCHES")
                   (expect (= ,(length expected-results)
                          (length (readme-snippet-blocks ,start-heading ,end-heading))) :to-be-truthy))
                (loop for expected in expected-results
                      for index from 0
                      collect
                      `(it ,(readme-snippet-test-symbol
                                  prefix
                                  (format nil "~D-IS-EXECUTABLE" (1+ index)))
                         (expect (equal ',expected
                                    (eval-readme-snippet
                                     (nth ,index
                                          (readme-snippet-blocks
                                           ,start-heading
                                           ,end-heading)))) :to-be-truthy)))))))))

(define-readme-snippet-contract-tests *readme-snippet-contracts*)

(defun readme-snippet-blocks (start-heading end-heading)
  (readme-fenced-code-blocks start-heading end-heading "lisp"))
