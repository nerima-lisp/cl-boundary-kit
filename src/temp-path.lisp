;;;; src/temp-path.lisp

(in-package #:cl-boundary-kit)

(defclass temp-path-source ()
  ((next-fn :initarg :next-fn :reader temp-path-source-next-fn)))

(defclass sequential-temp-path-source (temp-path-source)
  ((directory :initarg :directory :reader sequential-temp-path-source-directory)
   (prefix :initarg :prefix :reader sequential-temp-path-source-prefix)
   (suffix :initarg :suffix :reader sequential-temp-path-source-suffix)
   (counter :initarg :counter :accessor sequential-temp-path-source-counter)))

(defclass test-temp-path-source (temp-path-source)
  ((paths :initarg :paths :accessor test-temp-path-source-paths)))

(defclass recording-temp-path-source (temp-path-source)
  ((delegate :initarg :delegate :reader recording-temp-path-source-delegate)
   (calls :initform '() :accessor %recording-temp-path-source-calls)))

(defun %validate-temp-path-directory (directory)
  (unless (or (pathnamep directory) (stringp directory))
    (error "Temp path directory must be a pathname or string: ~S" directory))
  (pathname directory))

(defun %validate-temp-path-string (value name)
  (unless (stringp value)
    (error "~A must be a string: ~S" name value))
  value)

(defun %validate-temp-path-start (start)
  (unless (and (integerp start) (>= start 0))
    (error "Sequential temp path start must be a non-negative integer: ~S" start))
  start)

(defun %validate-temp-path-random-state (state)
  (unless (random-state-p state)
    (error "Temp path random state must be a random-state: ~S" state))
  state)

(defun %validate-test-temp-paths (paths)
  (unless (listp paths)
    (error "Test temp path source paths must be a list: ~S" paths))
  paths)

(defun %temp-path-under (directory name)
  (merge-pathnames (pathname name) directory))

(defun %random-temp-path (directory prefix suffix state)
  ;; This still returns a candidate path rather than atomically creating a file,
  ;; but it avoids returning an already-existing candidate from normal use.
  (loop repeat 256
        for path = (%temp-path-under directory
                                     (format nil "~A-~(~32,'0x~)~A"
                                             prefix
                                             (random (ash 1 128) state)
                                             suffix))
        unless (probe-file path)
          return path
        finally (error "Unable to find an unused temp path under ~S" directory)))

(defun make-temp-path-source (&key (directory #P"/tmp/") (prefix "tmp") (suffix "")
                                (state (make-random-state t)))
  "Create a temp-path source that allocates unique pathnames under DIRECTORY.

Each `temp-path-next` returns a fresh candidate
\"<prefix>-<128-bit random hex><suffix>\" pathname under DIRECTORY using STATE
and skips candidates that already exist. This does not atomically create the
file; callers that need exclusive creation must still open the returned path
with an exclusive creation mode."
  (let ((directory (%validate-temp-path-directory directory))
        (prefix (%validate-temp-path-string prefix "PREFIX"))
        (suffix (%validate-temp-path-string suffix "SUFFIX"))
        (state (%validate-temp-path-random-state state)))
    (make-instance 'temp-path-source
                   :next-fn (lambda () (%random-temp-path directory prefix suffix state)))))

(defun make-sequential-temp-path-source (&key (directory #P"/tmp/") (prefix "tmp") (suffix "") (start 0))
  "Create a deterministic temp-path source that returns counter-numbered paths.

Each `temp-path-next` returns \"<prefix>-<8 hex digits><suffix>\" under DIRECTORY
for a counter that advances by one on each call, so two sources created with the
same arguments produce the same path sequence. Intended for tests and
reproducible examples."
  (make-instance 'sequential-temp-path-source
                 :next-fn nil
                 :directory (%validate-temp-path-directory directory)
                 :prefix (%validate-temp-path-string prefix "PREFIX")
                 :suffix (%validate-temp-path-string suffix "SUFFIX")
                 :counter (%validate-temp-path-start start)))

(defun make-test-temp-path-source (&key paths)
  "Create a queue-backed temp-path source that returns PATHS in order.

  Each `temp-path-next` consumes one precomputed path (a pathname or string,
coerced to a pathname) and signals when the queue is exhausted."
  (make-instance 'test-temp-path-source
                 :next-fn nil
                 :paths (%copy-boundary-value (%validate-test-temp-paths paths))))

(defun make-recording-temp-path-source (&key (delegate (make-temp-path-source)))
  "Create a temp-path source that records calls while delegating to DELEGATE."
  (require-instance delegate 'temp-path-source "DELEGATE")
  (make-instance 'recording-temp-path-source :next-fn nil :delegate delegate))

(define-recording-call-log recording-temp-path-source-calls reset-recording-temp-path-source-calls
    (source recording-temp-path-source %recording-temp-path-source-calls) "temp path source")

(defmethod temp-path-next ((source temp-path-source))
  (funcall (temp-path-source-next-fn source)))

(defmethod temp-path-next ((source sequential-temp-path-source))
  (let ((counter (sequential-temp-path-source-counter source)))
    (setf (sequential-temp-path-source-counter source) (1+ counter))
    (%temp-path-under (sequential-temp-path-source-directory source)
                      (format nil "~A-~(~8,'0x~)~A"
                              (sequential-temp-path-source-prefix source)
                              counter
                              (sequential-temp-path-source-suffix source)))))

(defmethod temp-path-next ((source test-temp-path-source))
  (let ((paths (test-temp-path-source-paths source)))
    (unless paths
      (error "Test temp path source has no remaining paths"))
    (let ((path (first paths)))
      (unless (or (pathnamep path) (stringp path))
        (error "Test temp path source path must be a pathname or string: ~S" path))
      (setf (test-temp-path-source-paths source) (rest paths))
      (pathname path))))

(defmethod temp-path-next ((source recording-temp-path-source))
  (let ((result (temp-path-next (recording-temp-path-source-delegate source))))
    (%record-call (%recording-temp-path-source-calls source)
      :operation :next
      :arguments '()
      :result result)
    result))
