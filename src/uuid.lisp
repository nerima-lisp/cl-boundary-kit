;;;; src/uuid.lisp

(in-package #:cl-boundary-kit)

;;; DATA: the RFC 4122 version-4 layout -- byte count, the two fixed nibble
;;; edits, and the hyphen positions -- kept apart from the byte-shuffling LOGIC
;;; in %UUID-V4-STRING so the wire format reads as a specification.
(defconstant +uuid-byte-length+ 16
  "Octets in a UUID: 128 bits laid out as 16 bytes.")

(defconstant +uuid-version-byte-index+ 6
  "Byte carrying the version nibble.")

(defconstant +uuid-version-4-nibble+ #x40
  "Version nibble ORed into the version byte, marking the UUID as version 4.")

(defconstant +uuid-version-nibble-mask+ #x0f
  "Bits of the version byte left random once the version nibble is set.")

(defconstant +uuid-variant-byte-index+ 8
  "Byte carrying the variant bits.")

(defconstant +uuid-variant-rfc-4122-bits+ #x80
  "Variant bits ORed into the variant byte, marking the UUID as RFC 4122.")

(defconstant +uuid-variant-bits-mask+ #x3f
  "Bits of the variant byte left random once the variant bits are set.")

(defparameter +uuid-hyphen-positions+ '(4 6 8 10)
  "Byte indexes a hyphen precedes in the 8-4-4-4-12 textual form.")

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
  (let ((bytes (make-array +uuid-byte-length+ :element-type '(unsigned-byte 8))))
    (dotimes (index +uuid-byte-length+)
      (setf (aref bytes index) (random 256)))
    (setf (aref bytes +uuid-version-byte-index+)
          (logior +uuid-version-4-nibble+
                  (logand (aref bytes +uuid-version-byte-index+)
                          +uuid-version-nibble-mask+)))
    (setf (aref bytes +uuid-variant-byte-index+)
          (logior +uuid-variant-rfc-4122-bits+
                  (logand (aref bytes +uuid-variant-byte-index+)
                          +uuid-variant-bits-mask+)))
    (with-output-to-string (out)
      (loop for index below +uuid-byte-length+
            do (when (member index +uuid-hyphen-positions+)
                 (write-char #\- out))
               (format out "~(~2,'0x~)" (aref bytes index))))))

(define-scalar-validator %validate-uuid-prefix prefix
    (stringp prefix)
  "a string" "Sequential UUID source prefix")

(define-scalar-validator %validate-uuid-start start
    (and (integerp start) (>= start 0))
  "a non-negative integer" "Sequential UUID source start")

(define-list-validator %validate-test-uuid-values values "Test UUID source values")

(define-scalar-validator %validate-test-uuid-value value
    (stringp value)
  "a string" "Test UUID source value")

(defun make-uuid-source (&key (generate-fn #'%uuid-v4-string))
  "Create a UUID source backed by GENERATE-FN.

GENERATE-FN is called with no arguments and must return an identifier string.
The default generator produces a fresh RFC 4122 version-4 UUID string using the
host random state; inject GENERATE-FN for cryptographic or policy-specific
identifier requirements."
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
                 :values (copy-list (%validate-test-uuid-values values))))

(define-recording-boundary-constructor make-recording-uuid-source
    recording-uuid-source uuid-source (make-uuid-source)
  "Create a UUID source that records calls while delegating to DELEGATE."
  :generate-fn nil)

(define-recording-call-log recording-uuid-source-calls reset-recording-uuid-source-calls
    (source recording-uuid-source %recording-uuid-source-calls) "UUID source")

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

(define-recording-delegate-method uuid-generate
    (source recording-uuid-source recording-uuid-source-delegate %recording-uuid-source-calls)
    (() ()) :generate '())
