;;;; src/filesystem-store.lisp

(in-package #:cl-boundary-kit)

;; DATA: the keyword options FILESYSTEM-STORE-FILE understands, kept apart from
;; the validation LOGIC below so the accepted set reads as a list rather than
;; being spelled out inside PLIST-REMOVE-KEYS.
(defparameter +filesystem-write-option-keys+
  '(:if-exists :if-does-not-exist :external-format)
  "The keyword options FILESYSTEM-STORE-FILE accepts; any other key is rejected.")

(defun filesystem-store-file (filesystem path content &rest options)
  "Write CONTENT to PATH through FILESYSTEM and return a truthy success value."
  (unless (evenp (length options))
    (error "Option list ended after ~S." (car (last options))))
  (let ((filesystem (%require-filesystem filesystem))
        (unknown-options
          (plist-remove-keys options +filesystem-write-option-keys+)))
    (when unknown-options
      (error "Unknown filesystem write options: ~S" unknown-options))
    (%filesystem-store-file/cps
     filesystem
     path
     content
     (getf options :if-exists)
     (getf options :if-does-not-exist)
     (getf options :external-format))))

(defun filesystem-append-file (filesystem path content &key external-format)
  "Append CONTENT to PATH, creating the file if it is absent, and return the
store result.

Derived from `filesystem-store-file` with `:if-exists :append` and
`:if-does-not-exist :create` -- the combination needed to append-or-create --
so it works across every variant and a recording filesystem records the write
with those options."
  (filesystem-store-file filesystem path content
                         :if-exists :append
                         :if-does-not-exist :create
                         :external-format external-format))

(defun filesystem-store-file-lines (filesystem path lines &rest options)
  "Store LINES (a list of strings) to PATH as newline-terminated text and return
the store result.

Each line is followed by a newline, so it round-trips with
`filesystem-read-file-lines`. OPTIONS (`:if-exists`, `:if-does-not-exist`,
`:external-format`) are forwarded to `filesystem-store-file`, from which this is
derived, so it works across every variant and a recording filesystem records the
underlying write."
  (unless (listp lines)
    (error "FILESYSTEM-STORE-FILE-LINES lines must be a list of strings: ~S" lines))
  (let ((content (with-output-to-string (out)
                   (dolist (line lines)
                     (unless (stringp line)
                       (error "FILESYSTEM-STORE-FILE-LINES line must be a string: ~S" line))
                     (write-line line out)))))
    (apply #'filesystem-store-file filesystem path content options)))
