;;;; src/random.lisp

(in-package #:cl-boundary-kit)

(defclass random-source ()
  ((state :initarg :state :reader random-source-state)))

(defclass deterministic-random-source (random-source)
  ((modulus :initarg :modulus :reader deterministic-random-source-modulus)))

(defclass test-random-source (random-source)
  ((values :initarg :values :accessor test-random-source-values)))

(defun %validate-deterministic-random-modulus (modulus)
  (unless (and (integerp modulus) (> modulus 1))
    (error "Deterministic random source modulus must be an integer greater than 1: ~S" modulus))
  modulus)

(defun %validate-random-limit (limit)
  (unless (and (realp limit) (> limit 0))
    (error "RANDOM-SOURCE-RANDOM limit must be positive: ~S" limit))
  limit)

(defun %validate-random-state (state)
  (unless (typep state 'random-state)
    (error "Random source state must be a RANDOM-STATE: ~S" state))
  state)

(defun %validate-test-random-values (values)
  (unless (listp values)
    (error "Test random source values must be a list: ~S" values))
  values)

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
  "Create a random source backed by STATE."
  (make-instance 'random-source :state (%validate-random-state state)))

(defun make-deterministic-random-source (&key (seed 1) (modulus (expt 2 64)))
  "Create a deterministic random source seeded with SEED and bounded by MODULUS."
  (%validate-deterministic-random-modulus modulus)
  (make-instance 'deterministic-random-source :state (mod seed modulus) :modulus modulus))

(defun make-test-random-source (&key values)
  "Create a test random source that returns VALUES in order."
  (make-instance 'test-random-source
                 :state nil
                 :values (%validate-test-random-values values)))

(defun %lcg-step (state modulus)
  (mod (+ (* state 6364136223846793005) 1) modulus))

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
