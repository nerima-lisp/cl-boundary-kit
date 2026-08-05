;;;; t/working-directory-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "native working directory"
  (it "make-working-directory-wires-injected-collaborators"
    (let* ((store (list #P"/start/"))
           (wd (make-working-directory
                :get-fn (lambda () (first store))
                :set-fn (lambda (path) (setf (first store) path)))))
      (expect (working-directory-get wd) :to-equal #P"/start/")
      (expect (working-directory-set wd #P"/next/") :to-equal #P"/next/")
      (expect (working-directory-get wd) :to-equal #P"/next/")))

  (it "make-working-directory-rejects-non-function-collaborators"
    (signals error
      (make-working-directory :get-fn :bad :set-fn (lambda (p) p)))))

(describe "test working directory"
  (it "test-working-directory-tracks-an-in-memory-directory"
    (let ((wd (make-test-working-directory :initial #P"/home/")))
      (expect (working-directory-get wd) :to-equal #P"/home/")
      (working-directory-set wd #P"/tmp/")
      (expect (working-directory-get wd) :to-equal #P"/tmp/")))

  (it "working-directory-set-coerces-a-string-to-a-pathname"
    (let ((wd (make-test-working-directory)))
      (expect (working-directory-set wd "/var/") :to-equal #P"/var/")
      (expect (working-directory-get wd) :to-be-type-of 'pathname)))

  (it "working-directory-set-rejects-a-non-path-argument"
    (signals error
      (working-directory-set (make-test-working-directory) 42))))

(describe "recording working directory"
  (it "recording-working-directory-records-reads-and-changes"
    (let ((wd (make-recording-working-directory)))
      (working-directory-get wd)
      (working-directory-set wd #P"/tmp/")
      (expect (recording-working-directory-calls wd)
              :to-have-recorded-calls (list (boundary-call-plist :get '() :result #P"/")
                                            (boundary-call-plist :set (list #P"/tmp/") :result #P"/tmp/")))))

  (it "make-recording-working-directory-rejects-a-non-working-directory-delegate"
    (signals error
      (make-recording-working-directory :delegate :bad)))

  (it-each ((recording-working-directory-calls)
            (reset-recording-working-directory-calls))
      "~A signals for unsupported wd types"
      (operation)
    (expect (lambda () (funcall operation (make-test-working-directory))) :to-throw "Unsupported working directory type"))

  (it "reset-recording-working-directory-calls-clears-history-and-returns-it"
    (let ((wd (make-recording-working-directory)))
      (working-directory-get wd)
      (expect (recording-working-directory-calls wd) :to-have-length 1)
      (expect (reset-recording-working-directory-calls wd) :to-be wd)
      (expect (recording-working-directory-calls wd) :to-be-null))))

(describe "call-with-working-directory"
  (it "call-with-working-directory-changes-then-restores"
    (let ((wd (make-test-working-directory :initial #P"/home/")))
      (let ((seen (call-with-working-directory wd #P"/tmp/"
                                               (lambda () (working-directory-get wd)))))
        (expect seen :to-equal #P"/tmp/"))
      (expect (working-directory-get wd) :to-equal #P"/home/")))

  (it "call-with-working-directory-restores-even-when-the-thunk-signals"
    (let ((wd (make-test-working-directory :initial #P"/home/")))
      (signals error
        (call-with-working-directory wd #P"/tmp/" (lambda () (error "boom"))))
      (expect (working-directory-get wd) :to-equal #P"/home/")))

  (it "call-with-working-directory-rejects-a-non-function-thunk"
    (signals error
      (call-with-working-directory (make-test-working-directory) #P"/tmp/" :bad))))

(describe "native working directory set"
  (it "native-working-directory-set-updates-default-pathname-defaults"
    ;; Exercises the native SET-FN, which mutates *DEFAULT-PATHNAME-DEFAULTS*;
    ;; the previous value is restored so the rest of the suite is unaffected.
    (let ((working-directory (make-working-directory))
          (previous *default-pathname-defaults*))
      (unwind-protect
           (progn
             (working-directory-set working-directory #P"/tmp/")
             (expect *default-pathname-defaults* :to-equal #P"/tmp/")
             (expect (working-directory-get working-directory) :to-equal #P"/tmp/"))
        (setf *default-pathname-defaults* previous)))))
