;;;; t/helpers-api-markdown.lisp

(in-package #:cl-boundary-kit/test)

(defun split-lines (string)
  (let ((lines '())
        (start 0))
    (labels ((emit (end)
               (push (subseq string start end) lines)))
      (loop for end = (position #\Newline string :start start)
            do (if end
                   (progn
                     (emit end)
                     (setf start (1+ end)))
                   (progn
                     (emit (length string))
                     (return (nreverse lines))))))))

(defun trimmed-markdown-line (line)
  (string-trim '(#\Space #\Tab #\Return) line))

(defun markdown-heading-position (document heading &key (start 0))
  (loop for position = (search heading document :start2 start)
        while position
        do (let ((before-ok (or (zerop position)
                                (char= #\Newline (char document (1- position)))))
                 (after-position (+ position (length heading))))
             (when (and before-ok
                        (or (= after-position (length document))
                            (char= #\Newline (char document after-position))))
               (return position))
             (setf start (1+ position)))))

(defun markdown-section (document start-heading end-heading)
  (let* ((start (markdown-heading-position document start-heading))
         (content-start (and start (+ start (length start-heading))))
         (end (and content-start end-heading
                   (markdown-heading-position document end-heading :start content-start))))
    (unless content-start
      (error "Missing markdown heading ~S" start-heading))
    (subseq document content-start (or end (length document)))))

(defun line-code-item (line)
  (let* ((trimmed (trimmed-markdown-line line))
         (first-tick (and (string= "- " trimmed :end2 (min 2 (length trimmed)))
                          (position #\` trimmed)))
         (second-tick (and first-tick
                           (position #\` trimmed :start (1+ first-tick)))))
    (and first-tick second-tick
         (subseq trimmed (1+ first-tick) second-tick))))

(defun markdown-code-items (section)
  (let ((items '()))
    (dolist (line (split-lines section) (nreverse items))
      (let ((item (line-code-item line)))
        (when item
          (push item items))))))

(defparameter *docs-guide-pages*
  '("docs/src/composition.md"
    "docs/src/filesystem-and-environment.md"
    "docs/src/time-and-randomness.md"
    "docs/src/process-network-and-dns.md"
    "docs/src/observability.md"
    "docs/src/state-and-storage.md"
    "docs/src/concurrency-control.md"
    "docs/src/messaging.md"
    "docs/src/system-and-host.md"
    "docs/src/testing-helpers.md"))

(defun readme-api-overview-symbol-names ()
  (mapcan (lambda (page)
            (markdown-code-items (repository-file-string page)))
          *docs-guide-pages*))

(defun markdown-fenced-code-blocks (section language)
  (let ((fence (concatenate 'string "```" language))
        (lines (split-lines section))
        (blocks '())
        (current-lines '())
        (collecting nil))
    (dolist (line lines)
      (cond
        ((and (not collecting)
              (string= fence (trimmed-markdown-line line)))
         (setf collecting t
               current-lines '()))
        ((and collecting
              (string= "```" (trimmed-markdown-line line)))
         (push (format nil "~{~A~^~%~}" (nreverse current-lines)) blocks)
         (setf collecting nil
               current-lines '()))
        (collecting
         (push line current-lines))))
    (when collecting
      (error "Unclosed markdown code fence for language ~S" language))
    (nreverse blocks)))

(defun markdown-example-paths (section)
  ;; Extracts from the link TEXT ([`examples/x.lisp`](...)), not the href, so
  ;; this works whether the href is a checkout-relative path (README.md) or an
  ;; absolute GitHub blob URL (the published docs site's examples.md).
  (let ((items '()))
    (dolist (line (split-lines section) (nreverse items))
      (let* ((trimmed (trimmed-markdown-line line))
             (open (search "[`" trimmed))
             (close (and open (search "`]" trimmed :start2 (+ open 2)))))
        (when (and open close)
          (let ((path (subseq trimmed (+ open 2) close)))
            (when (and (>= (length path) (length "examples/a.lisp"))
                       (string= "examples/" path :end2 (length "examples/"))
                       (string= ".lisp" path :start2 (- (length path) (length ".lisp"))))
              (push path items))))))))

(defun document-fenced-code-blocks (pathname start-heading end-heading language)
  (fenced-code-blocks-from-file pathname start-heading end-heading language))

