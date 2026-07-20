;;;; src/network-classes.lisp

(in-package #:cl-boundary-kit)

(defclass network-boundary ()
  ((request-fn :initarg :request-fn :reader network-boundary-request-fn)))

(defclass test-network-boundary (network-boundary)
  ((responses :initarg :responses :accessor test-network-boundary-responses)
   (calls :initform '() :accessor %test-network-calls)))

(defclass recording-network-boundary (network-boundary)
  ((delegate :initarg :delegate :reader recording-network-boundary-delegate)
   (request-redactor-fn :initarg :request-redactor-fn
                        :reader recording-network-request-redactor-fn)
   (response-redactor-fn :initarg :response-redactor-fn
                         :reader recording-network-response-redactor-fn)
   (calls :initform '() :accessor %recording-network-calls)))

(defgeneric %network-calls (boundary))

(defmethod %network-calls ((boundary test-network-boundary))
  (%test-network-calls boundary))

(defmethod %network-calls ((boundary recording-network-boundary))
  (%recording-network-calls boundary))

(defmethod %network-calls ((boundary t))
  (error "Unsupported network boundary type: ~S" boundary))
