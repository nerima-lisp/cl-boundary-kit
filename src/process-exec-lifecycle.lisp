;;;; src/process-exec-lifecycle.lisp
;;;;
;;;; Process lifecycle and timeout management: deadlines, liveness checks, and
;;;; the SIGTERM/SIGKILL escalation that guarantees a timed-out child is always
;;;; terminated and reaped rather than left as an orphan.
(in-package #:cl-boundary-kit)

(defparameter *%process-kill-grace-seconds* 2
  "Seconds to wait after SIGTERM before escalating to SIGKILL on timeout.")

(defun %deadline-seconds (timeout)
  (when timeout
    (+ (get-internal-real-time) (round (* timeout internal-time-units-per-second)))))

(defun %deadline-remaining-seconds (deadline)
  "Return the non-negative remaining time before DEADLINE, or NIL."
  (when deadline
    (/
      (max 0 (- deadline (get-internal-real-time)))
      (float internal-time-units-per-second))))

(defun %process-alive-p (process)
  (sb-ext:process-alive-p process))

(defun %force-kill-and-reap (process)
  ;; SIGKILL cannot be caught or ignored, so this always terminates the child;
  ;; PROCESS-WAIT then reaps it. Every early-exit cleanup path funnels through
  ;; here so a child is never left running as an untracked orphan.
  (when (%process-alive-p process)
    (sb-ext:process-kill process 9)
    (sb-ext:process-wait process)))

(defun %kill-process-with-escalation (process)
  ;; A child that traps or ignores SIGTERM would otherwise hang this call (and
  ;; the timeout contract) forever; SIGKILL cannot be caught or ignored.
  (sb-ext:process-kill process 15)
  (let ((grace-deadline (+ (get-internal-real-time)
                           (round (* *%process-kill-grace-seconds*
                                     internal-time-units-per-second)))))
    (loop
      (when (not (%process-alive-p process))
        (return))
      (when (>= (get-internal-real-time) grace-deadline)
        (sb-ext:process-kill process 9)
        (sb-ext:process-wait process)
        (return))
      (sleep 0.01))))

(defun %wait-for-process-with-deadline (process deadline)
  ;; DEADLINE never changes across iterations, so whether one exists at all is
  ;; an up-front branch, not another polling-loop clause alongside liveness
  ;; and expiry checks.
  (if (null deadline)
      (progn (sb-ext:process-wait process) nil)
      (loop
        when (not (%process-alive-p process)) do
          (return nil)
        when (>= (get-internal-real-time) deadline) do
          (%kill-process-with-escalation process)
          (return t)
        do (sleep 0.01))))
