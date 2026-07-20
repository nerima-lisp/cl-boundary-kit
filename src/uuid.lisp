;;;; src/uuid.lisp

(in-package #:cl-boundary-kit)

(defclass uuid-source ()
  ((generate-fn :initarg :generate-fn :reader uuid-source-generate-fn)))

(defclass sequential-uuid-source (uuid-source)
  ((prefix :initarg :prefix :reader sequential-uuid-source-prefix)
   (counter :initarg :counter :accessor sequential-uuid-source-counter)))

(defclass test-uuid-source (uuid-source)
  ((values :initarg :values :accessor test-uuid-source-values)))

(defclass recording-uuid-source (uuid-source)
  ((delegate :initarg :delegate :reader recording-uuid-source-delegate)
   (calls :initform '() :accessor %recording-uuid-source-calls)))

(defun %uuid-v4-string ()
  ;; The one genuinely non-deterministic default: 122 random bits laid out as an
  ;; RFC 4122 version-4 UUID. Tests never reach this path -- they use the
  ;; sequential or queue-backed doubles below -- so relying on the global
  ;; *RANDOM-STATE* here is the intended real-world effect, not hidden fallback.
  (let ((bytes (make-array 16 :element-type '(unsigned-byte 8))))
    (dotimes (index 16)
      (setf (aref bytes index) (random 256)))
    (setf (aref bytes 6) (logior #x40 (logand (aref bytes 6) #x0f)))
    (setf (aref bytes 8) (logior #x80 (logand (aref bytes 8) #x3f)))
    (with-output-to-string (out)
      (loop for index below 16
            do (when (member index '(4 6 8 10))
                 (write-char #\- out))
               (format out "~(~2,'0x~)" (aref bytes index))))))

(defun %validate-uuid-prefix (prefix)
  (unless (stringp prefix)
    (error "Sequential UUID source prefix must be a string: ~S" prefix))
  prefix)

(defun %validate-uuid-start (start)
  (unless (and (integerp start) (>= start 0))
    (error "Sequential UUID source start must be a non-negative integer: ~S" start))
  start)

(defun %validate-test-uuid-values (values)
  (unless (listp values)
    (error "Test UUID source values must be a list: ~S" values))
  values)

(defun %validate-test-uuid-value (value)
  (unless (stringp value)
    (error "Test UUID source value must be a string: ~S" value))
  value)

(defun make-uuid-source (&key (generate-fn #'%uuid-v4-string))
  "Create a UUID source backed by GENERATE-FN.

GENERATE-FN is called with no arguments and must return an identifier string.
The default generator produces a fresh RFC 4122 version-4 UUID string using the
host random state."
  (require-function generate-fn "GENERATE-FN")
  (make-instance 'uuid-source :generate-fn generate-fn))

(defun make-sequential-uuid-source (&key (prefix "uuid") (start 0))
  "Create a deterministic UUID source that returns PREFIX-joined counter values.

Each `uuid-generate` call returns \"PREFIX-<16 hex digits>\" for the current
counter and then advances the counter by one, so two sources created with the
same PREFIX and START produce the same identifier sequence. Intended for tests
and reproducible examples."
  (%validate-uuid-prefix prefix)
  (%validate-uuid-start start)
  (make-instance 'sequential-uuid-source
                 :generate-fn nil
                 :prefix prefix
                 :counter start))

(defun make-test-uuid-source (&key values)
  "Create a queue-backed UUID source that returns VALUES in order.

Each `uuid-generate` call consumes one precomputed string and signals when the
queue is exhausted."
  (make-instance 'test-uuid-source
                 :generate-fn nil
                 :values (%validate-test-uuid-values values)))

(defun make-recording-uuid-source (&key (delegate (make-uuid-source)))
  "Create a UUID source that records calls while delegating to DELEGATE."
  (require-instance delegate 'uuid-source "DELEGATE")
  (make-instance 'recording-uuid-source :generate-fn nil :delegate delegate))

(defun recording-uuid-source-calls (source)
  "Return the recorded UUID-source calls in call order."
  (unless (typep source 'recording-uuid-source)
    (error "Unsupported UUID source type: ~S" source))
  (%snapshot-recorded-calls (%recording-uuid-source-calls source)))

(defun reset-recording-uuid-source-calls (source)
  "Clear SOURCE's recorded call history and return SOURCE.

A recording UUID source otherwise retains every call for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (unless (typep source 'recording-uuid-source)
    (error "Unsupported UUID source type: ~S" source))
  (setf (%recording-uuid-source-calls source) nil)
  source)

(defmethod uuid-generate ((source uuid-source))
  (funcall (uuid-source-generate-fn source)))

(defmethod uuid-generate ((source sequential-uuid-source))
  (let ((counter (sequential-uuid-source-counter source)))
    (setf (sequential-uuid-source-counter source) (1+ counter))
    (format nil "~A-~(~16,'0x~)" (sequential-uuid-source-prefix source) counter)))

(defmethod uuid-generate ((source test-uuid-source))
  (let ((values (test-uuid-source-values source)))
    (unless values
      (error "Test UUID source has no remaining values"))
    (let ((value (%validate-test-uuid-value (first values))))
      (setf (test-uuid-source-values source) (rest values))
      value)))

(defmethod uuid-generate ((source recording-uuid-source))
  (let ((result (uuid-generate (recording-uuid-source-delegate source))))
    (%record-call (%recording-uuid-source-calls source)
      :operation :generate
      :arguments '()
      :result result)
    result))
