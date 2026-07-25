;;;; t/working-directory-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-working-directory-wires-injected-collaborators"
  (let* ((store (list #P"/start/"))
         (wd (make-working-directory
              :get-fn (lambda () (first store))
              :set-fn (lambda (path) (setf (first store) path)))))
    (expect (equal #P"/start/" (working-directory-get wd)) :to-be-truthy)
    (expect (equal #P"/next/" (working-directory-set wd #P"/next/")) :to-be-truthy)
    (expect (equal #P"/next/" (working-directory-get wd)) :to-be-truthy)))

(it "make-working-directory-rejects-non-function-collaborators"
  (signals error
    (make-working-directory :get-fn :bad :set-fn (lambda (p) p))))

(it "test-working-directory-tracks-an-in-memory-directory"
  (let ((wd (make-test-working-directory :initial #P"/home/")))
    (expect (equal #P"/home/" (working-directory-get wd)) :to-be-truthy)
    (working-directory-set wd #P"/tmp/")
    (expect (equal #P"/tmp/" (working-directory-get wd)) :to-be-truthy)))

(it "working-directory-set-coerces-a-string-to-a-pathname"
  (let ((wd (make-test-working-directory)))
    (expect (equal #P"/var/" (working-directory-set wd "/var/")) :to-be-truthy)
    (expect (pathnamep (working-directory-get wd)) :to-be-truthy)))

(it "working-directory-set-rejects-a-non-path-argument"
  (signals error
    (working-directory-set (make-test-working-directory) 42)))

(it "recording-working-directory-records-reads-and-changes"
  (let ((wd (make-recording-working-directory)))
    (working-directory-get wd)
    (working-directory-set wd #P"/tmp/")
    (expect (equal (recording-working-directory-calls wd)
                   (list (boundary-call-plist :get '() :result #P"/")
                         (boundary-call-plist :set (list #P"/tmp/") :result #P"/tmp/"))) :to-be-truthy)))

(it "make-recording-working-directory-rejects-a-non-working-directory-delegate"
  (signals error
    (make-recording-working-directory :delegate :bad)))

(it-each ((recording-working-directory-calls)
          (reset-recording-working-directory-calls))
    "~A signals for unsupported wd types"
    (operation)
  (expect (lambda () (funcall operation (make-test-working-directory)))
          :to-signal-message-containing "Unsupported working directory type"))

(it "reset-recording-working-directory-calls-clears-history-and-returns-it"
  (let ((wd (make-recording-working-directory)))
    (working-directory-get wd)
    (expect (= 1 (length (recording-working-directory-calls wd))) :to-be-truthy)
    (expect (eq wd (reset-recording-working-directory-calls wd)) :to-be-truthy)
    (expect (null (recording-working-directory-calls wd)) :to-be-truthy)))

(it "call-with-working-directory-changes-then-restores"
  (let ((wd (make-test-working-directory :initial #P"/home/")))
    (let ((seen (call-with-working-directory wd #P"/tmp/"
                                             (lambda () (working-directory-get wd)))))
      (expect (equal #P"/tmp/" seen) :to-be-truthy))
    (expect (equal #P"/home/" (working-directory-get wd)) :to-be-truthy)))

(it "call-with-working-directory-restores-even-when-the-thunk-signals"
  (let ((wd (make-test-working-directory :initial #P"/home/")))
    (signals error
      (call-with-working-directory wd #P"/tmp/" (lambda () (error "boom"))))
    (expect (equal #P"/home/" (working-directory-get wd)) :to-be-truthy)))

(it "call-with-working-directory-rejects-a-non-function-thunk"
  (signals error
    (call-with-working-directory (make-test-working-directory) #P"/tmp/" :bad)))

(it "native-working-directory-set-updates-default-pathname-defaults"
  ;; Exercises the native SET-FN, which mutates *DEFAULT-PATHNAME-DEFAULTS*;
  ;; the previous value is restored so the rest of the suite is unaffected.
  (let ((working-directory (make-working-directory))
        (previous *default-pathname-defaults*))
    (unwind-protect
         (progn
           (working-directory-set working-directory #P"/tmp/")
           (expect (equal *default-pathname-defaults* #P"/tmp/") :to-be-truthy)
           (expect (equal (working-directory-get working-directory) #P"/tmp/") :to-be-truthy))
      (setf *default-pathname-defaults* previous))))
