;;;; src/random.lisp

(in-package #:cl-boundary-kit)

(defconstant +lcg-multiplier+ 6364136223846793005)

(defconstant +lcg-increment+ 1)

(defclass random-source ()
  ((state :initarg :state :reader random-source-state)))

(defclass deterministic-random-source (random-source)
  ((modulus :initarg :modulus :reader deterministic-random-source-modulus)))

(defclass test-random-source (random-source)
  ((values :initarg :values :accessor test-random-source-values)))

(defclass recording-random-source (random-source)
  ((delegate :initarg :delegate :reader recording-random-source-delegate)
   (calls :initform '() :accessor %recording-random-source-calls)))

(define-scalar-validator %validate-deterministic-random-modulus modulus
    (and (integerp modulus) (> modulus 1))
  "an integer greater than 1" "Deterministic random source modulus")

(define-scalar-validator %validate-random-limit limit
    (and (realp limit) (> limit 0))
  "positive" "RANDOM-SOURCE-RANDOM limit")

(define-scalar-validator %validate-random-state state
    (typep state 'random-state)
  "a RANDOM-STATE" "Random source state")

(define-list-validator %validate-test-random-values values "Test random source values")

(defun %validate-test-random-value (value limit)
  (unless (and (realp value) (>= value 0) (< value limit))
    (error "Test random source value ~S is outside limit ~S" value limit))
  (when (integerp limit)
    (unless (integerp value)
      (error "Test random source value must be an integer for integer limit ~S: ~S"
             limit
             value)))
  value)

(defun make-random-source (&key (state (make-random-state t)))
  "Create a random source backed by STATE.

This uses Common Lisp RANDOM and is not a cryptographic randomness source."
  (make-instance 'random-source :state (%validate-random-state state)))

(defun make-deterministic-random-source (&key (seed 1) (modulus (expt 2 64)))
  "Create a deterministic random source seeded with SEED and bounded by MODULUS."
  (%validate-deterministic-random-modulus modulus)
  (make-instance 'deterministic-random-source :state (mod seed modulus) :modulus modulus))

(defun make-test-random-source (&key values)
  "Create a test random source that returns VALUES in order."
  (make-instance 'test-random-source
                 :state nil
                 :values (copy-list (%validate-test-random-values values))))

(define-recording-boundary-constructor make-recording-random-source
    recording-random-source random-source (make-random-source)
  "Create a random source that records calls while delegating to DELEGATE."
  :state nil)

(define-recording-call-log recording-random-source-calls reset-recording-random-source-calls
    (source recording-random-source %recording-random-source-calls) "random source")

(defun %lcg-step (state modulus)
  (mod (+ (* state +lcg-multiplier+) +lcg-increment+) modulus))

(defmethod random-source-random ((source random-source) limit)
  (%validate-random-limit limit)
  (random limit (random-source-state source)))

(defmethod random-source-random ((source deterministic-random-source) limit)
  (%validate-random-limit limit)
  (let* ((modulus (deterministic-random-source-modulus source))
         (state (%lcg-step (random-source-state source) modulus)))
    (setf (slot-value source 'state) state)
    (etypecase limit
      (integer (mod state limit))
      ;; STATE ranges over [0, MODULUS-1]; dividing by MODULUS keeps the ratio
      ;; in [0, 1) so the scaled value stays strictly below LIMIT as documented.
      (real (* limit (/ state (float modulus 1.0d0)))))))

(defmethod random-source-random ((source test-random-source) limit)
  (%validate-random-limit limit)
  (let ((values (test-random-source-values source)))
    (unless values
      (error "Test random source has no remaining values for limit ~S" limit))
    (let ((value (%validate-test-random-value (first values) limit)))
      (setf (test-random-source-values source) (rest values))
      value)))

(define-recording-delegate-method random-source-random
    (source recording-random-source recording-random-source-delegate %recording-random-source-calls)
    ((limit) (limit)) :random (list limit)
  (%validate-random-limit limit))

(defun random-source-element (source sequence)
  "Return a random element of the non-empty SEQUENCE using SOURCE.

Derived from `random-source-random`, so it works with any random source; a
recording source records the underlying integer draw."
  (let ((length (length sequence)))
    (when (zerop length)
      (error "RANDOM-SOURCE-ELEMENT sequence must be non-empty"))
    (elt sequence (random-source-random source length))))

(defun random-source-boolean (source)
  "Return a random boolean from SOURCE, derived from `random-source-random`."
  (= 0 (random-source-random source 2)))

(defun random-source-bytes (source count)
  "Return a fresh `(unsigned-byte 8)` vector of COUNT random bytes drawn from SOURCE.

Each byte is a fresh `random-source-random` draw below 256, so it works with any
random source and a recording source records each draw. Useful for generating
nonces, salts, and tokens while keeping them deterministic in tests."
  (unless (and (integerp count) (>= count 0))
    (error "RANDOM-SOURCE-BYTES count must be a non-negative integer: ~S" count))
  (let ((bytes (make-array count :element-type '(unsigned-byte 8))))
    (dotimes (index count bytes)
      (setf (aref bytes index) (random-source-random source 256)))))



(defun %random-source-sample-vector (source sequence length count)
  (let ((swaps (make-hash-table)))
    (labels ((value-at (index)
               (multiple-value-bind (value present-p) (gethash index swaps)
                 (if present-p
                     value
                     (aref sequence index)))))
      (loop for index from 0 below count
            for pick = (+ index (random-source-random source (- length index)))
            for at-index = (value-at index)
            for at-pick = (value-at pick)
            do (setf (gethash index swaps) at-pick
                     (gethash pick swaps) at-index)
            collect at-pick))))

(defun %random-source-sample-list (source sequence length count)
  (let ((vector (make-array length)))
    (replace vector sequence)
    (loop for index from 0 below count
          for pick = (+ index (random-source-random source (- length index)))
          do (rotatef (aref vector index) (aref vector pick)))
    (loop for index from 0 below count collect (aref vector index))))

(defun random-source-sample (source sequence count)
  "Return a list of COUNT distinct elements drawn from SEQUENCE without
replacement, using SOURCE.

COUNT must be an integer between 0 and the length of SEQUENCE. Uses a partial
Fisher-Yates shuffle (only the first COUNT positions), so it is more efficient
than a full shuffle when COUNT is small. Vector inputs use a sparse virtual
swap table to avoid copying the entire input. Derived from
`random-source-random`; a recording source records the underlying draws, and
the input is not modified."
  (let ((length (length sequence)))
    (unless (and (integerp count) (<= 0 count length))
      (error "RANDOM-SOURCE-SAMPLE count must be an integer in [0, ~D]: ~S" length count))
    (if (vectorp sequence)
        (%random-source-sample-vector source sequence length count)
        (%random-source-sample-list source sequence length count))))

(defun random-source-shuffle (source sequence)
  "Return a freshly shuffled copy of SEQUENCE using SOURCE.

Uses a Fisher-Yates shuffle driven by `random-source-random`, so it works with
any random source and a recording source records the underlying index draws. The
input is not modified, and the result has the same sequence type (list or
vector) as SEQUENCE."
  (let* ((length (length sequence))
         (vector (make-array length)))
    (replace vector sequence)
    (loop for index from (1- length) downto 1
          for pick = (random-source-random source (1+ index))
          do (rotatef (aref vector index) (aref vector pick)))
    (if (listp sequence)
        (coerce vector 'list)
        vector)))
