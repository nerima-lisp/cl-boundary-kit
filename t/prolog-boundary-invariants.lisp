;;;; t/prolog-boundary-invariants.lisp

(in-package #:cl-boundary-kit/test)

(defun %prolog-binding (variable solution)
  (cdr (assoc variable solution)))

(defparameter *boundary-policy*
  (cl-prolog:prolog
    ((boundary filesystem))
    ((boundary environment))
    ((boundary process))
    ((boundary network))
    ((boundary clock))
    ((effect filesystem read))
    ((effect filesystem write))
    ((effect environment read))
    ((effect environment write))
    ((effect process execute))
    ((effect network request))
    ((effect clock observe))
    ((recordable filesystem))
    ((recordable environment))
    ((recordable process))
    ((recordable network))
    ((permitted ?boundary ?operation)
     (boundary ?boundary)
     (effect ?boundary ?operation))
    ((observable-effect ?boundary ?operation)
     (permitted ?boundary ?operation)
     (recordable ?boundary)))
  "Facts and rules describing the effect surface of boundary objects.")

(cl-prolog/weave:deftest-queries prolog-boundary-policy-has-declarative-invariants
    (*boundary-policy*)
  ("filesystem boundaries permit the expected operations"
   (permitted filesystem ?operation) :set
   (((?operation . read))
    ((?operation . write))))
  ("observable request effects stay on the network boundary"
   (observable-effect ?boundary request) :ordered
   (((?boundary . network))))
  ("undefined clock mutations are rejected"
   (permitted clock mutate) :fails))

;;;; ---------------------------------------------------------------------------
;;;; API-surface completeness as a declarative invariant
;;;;
;;;; A functional-requirements review of this library found that every
;;;; boundary kind exports a native/test/recording constructor triad except
;;;; CLOCK (ADVANCE-FAKE-CLOCK already gives full control, so
;;;; MAKE-RECORDING-CLOCK was flagged rather than added speculatively) --
;;;; RANDOM's missing recording variant was the one asymmetry closed by
;;;; adding MAKE-RECORDING-RANDOM-SOURCE. Encoding that as facts and a rule
;;;; makes the intended shape checkable instead of only documented in prose:
;;;; if a future change added a boundary kind without completing its triad,
;;;; or "completed" CLOCK's, this invariant would need an explicit update
;;;; rather than silently drifting from what actually shipped.
;;;;
;;;; The UUID, SLEEPER, CONSOLE, SYSTEM, KV, and METRICS boundaries were each
;;;; added with a full native/test/recording triad, so they extend the fact
;;;; base and the expected solution set below rather than introducing new
;;;; asymmetries.
(defparameter *boundary-api-completeness*
  (cl-prolog:prolog
    ((provides-native filesystem)) ((provides-native environment))
    ((provides-native process)) ((provides-native network))
    ((provides-native clock)) ((provides-native random))
    ((provides-native uuid)) ((provides-native temp-path))
    ((provides-native args)) ((provides-native host-info))
    ((provides-native sleeper))
    ((provides-native console)) ((provides-native system))
    ((provides-native kv)) ((provides-native metrics))
    ((provides-native lock)) ((provides-native semaphore))
    ((provides-native working-directory))
    ((provides-native dns)) ((provides-native secret))
    ((provides-native feature-flags)) ((provides-native cache))
    ((provides-native rate-limiter)) ((provides-native scheduler))
    ((provides-native publisher)) ((provides-native subscriber))
    ((provides-native notifier))
    ((provides-test filesystem)) ((provides-test environment))
    ((provides-test process)) ((provides-test network))
    ((provides-test random))
    ((provides-test uuid)) ((provides-test temp-path))
    ((provides-test args)) ((provides-test host-info))
    ((provides-test sleeper))
    ((provides-test console)) ((provides-test system))
    ((provides-test kv)) ((provides-test metrics))
    ((provides-test lock)) ((provides-test semaphore))
    ((provides-test working-directory))
    ((provides-test dns)) ((provides-test secret))
    ((provides-test feature-flags)) ((provides-test cache))
    ((provides-test rate-limiter)) ((provides-test scheduler))
    ((provides-test publisher)) ((provides-test subscriber))
    ((provides-test notifier))
    ((provides-recording filesystem)) ((provides-recording environment))
    ((provides-recording process)) ((provides-recording network))
    ((provides-recording random))
    ((provides-recording uuid)) ((provides-recording temp-path))
    ((provides-recording args)) ((provides-recording host-info))
    ((provides-recording sleeper))
    ((provides-recording console)) ((provides-recording system))
    ((provides-recording kv)) ((provides-recording metrics))
    ((provides-recording lock)) ((provides-recording semaphore))
    ((provides-recording working-directory))
    ((provides-recording dns)) ((provides-recording secret))
    ((provides-recording feature-flags)) ((provides-recording cache))
    ((provides-recording rate-limiter)) ((provides-recording scheduler))
    ((provides-recording publisher)) ((provides-recording subscriber))
    ((provides-recording notifier))
    ((complete-triad ?boundary)
     (provides-native ?boundary)
     (provides-test ?boundary)
     (provides-recording ?boundary)))
  "Which native/test/recording constructors each boundary kind actually
exports.")

(cl-prolog/weave:deftest-queries boundary-api-triads-match-the-documented-asymmetry
    (*boundary-api-completeness*)
  ("every boundary except clock completes the native/test/recording triad"
   (complete-triad ?boundary) :set
   (((?boundary . filesystem))
    ((?boundary . environment))
    ((?boundary . process))
    ((?boundary . network))
    ((?boundary . random))
    ((?boundary . uuid))
    ((?boundary . temp-path))
    ((?boundary . args))
    ((?boundary . host-info))
    ((?boundary . sleeper))
    ((?boundary . console))
    ((?boundary . system))
    ((?boundary . kv))
    ((?boundary . metrics))
    ((?boundary . lock))
    ((?boundary . semaphore))
    ((?boundary . working-directory))
    ((?boundary . dns))
    ((?boundary . secret))
    ((?boundary . feature-flags))
    ((?boundary . cache))
    ((?boundary . rate-limiter))
    ((?boundary . scheduler))
    ((?boundary . publisher))
    ((?boundary . subscriber))
    ((?boundary . notifier))))
  ("clock is the one documented, deliberate asymmetry"
   (complete-triad clock) :fails))

;;; Dynamic database: a plugin can register a wholly new boundary kind at
;;; runtime by ASSERTZ-ing facts into a policy copy, immediately making it
;;; PERMITTED; RETRACT reverses that grant. This extends the
;;; untrusted-policy-source scenario above (a config file parsed once via
;;; CONSULT-PROLOG) to a policy that a running process can still mutate after
;;; it was built, the way a plugin loaded mid-session would.
;;;
;;; The grant lives under its own REGISTERED-BOUNDARY/REGISTERED-EFFECT
;;; predicates rather than BOUNDARY/EFFECT: those already carry the static
;;; facts *BOUNDARY-POLICY* was built with, and ISO permission rules forbid
;;; ASSERTZ/RETRACT against a predicate that already has clauses unless it was
;;; declared DYNAMIC in advance. A fresh predicate has no such history, so it
;;; is free to become dynamic on first use.

(defun %call-with-empty-dynamic-registration (policy body)
  "Seed PLUGIN-REGISTRATION's predicates as dynamic-but-empty, then run BODY.

A predicate with zero clauses and no dynamic declaration raises an
existence error on lookup rather than simply failing. ASSERTZ-ing and
immediately RETRACT-ing a throwaway fact registers the predicate as dynamic
with an empty extension, so BODY can query it before anything real is
registered without tripping that error."
  (cl-prolog:query-prolog policy '(cl-prolog:assertz (registered-boundary %seed%)))
  (cl-prolog:query-prolog policy '(cl-prolog:assertz (registered-effect %seed% %seed%)))
  (cl-prolog:query-prolog policy '(cl-prolog:retract (registered-boundary %seed%)))
  (cl-prolog:query-prolog policy '(cl-prolog:retract (registered-effect %seed% %seed%)))
  (funcall body))

(it "runtime-plugin-registration-via-assertz-and-retract-updates-permitted-facts"
  (let ((policy (cl-prolog:extend-rulebase *boundary-policy*
                  ((permitted ?boundary ?operation)
                   (registered-boundary ?boundary)
                   (registered-effect ?boundary ?operation)))))
    (%call-with-empty-dynamic-registration policy
     (lambda ()
       (expect (cl-prolog:prolog-succeeds-p policy '(permitted plugin invoke))
               :to-be-null)
       (cl-prolog:query-prolog policy '(cl-prolog:assertz (registered-boundary plugin)))
       (cl-prolog:query-prolog policy '(cl-prolog:assertz (registered-effect plugin invoke)))
       (expect (cl-prolog:prolog-succeeds-p policy '(permitted plugin invoke))
               :to-be-truthy)
       (cl-prolog:query-prolog policy '(cl-prolog:retract (registered-effect plugin invoke)))
       (expect (cl-prolog:prolog-succeeds-p policy '(permitted plugin invoke))
               :to-be-null)
       ;; The original shared policy is untouched by mutating its extended copy.
       (expect (cl-prolog:prolog-succeeds-p *boundary-policy* '(boundary plugin))
               :to-be-null)))))

;;; Negation as failure: "clock mutation is not permitted" stated as a rule
;;; (using NOT rather than the :FAILS query kind above) so the restriction is
;;; itself a declarative fact a query can depend on, not only an assertion a
;;; test makes about the absence of solutions.

(defparameter *boundary-policy-with-negation*
  (cl-prolog:extend-rulebase *boundary-policy*
    ((clock-mutation-forbidden) (not (permitted clock mutate)))))

(it "negation-as-failure-declares-clock-mutation-forbidden"
  (expect (cl-prolog:prolog-succeeds-p
           *boundary-policy-with-negation* '(clock-mutation-forbidden))
          :to-be-truthy)
  ;; A permitted operation is NOT forbidden -- the negated rule tracks the
  ;; underlying PERMITTED facts rather than always succeeding.
  (expect (cl-prolog:prolog-succeeds-p
           (cl-prolog:extend-rulebase *boundary-policy-with-negation*
             ((clock-observation-forbidden) (not (permitted clock observe))))
           '(clock-observation-forbidden))
          :to-be-null))

(it "prolog-rulebase-extension-is-transactional"
  (let ((extended
          (cl-prolog:extend-rulebase *boundary-policy*
            ((effect clock advance))
            ((recordable clock)))))
    (cl-prolog/weave:assert-query *boundary-policy*
        (permitted clock advance) :fails)
    (cl-prolog/weave:assert-query *boundary-policy*
        (permitted clock ?operation) :set
      (((?operation . observe))))
    (cl-prolog/weave:assert-query extended
        (permitted clock ?operation) :set
      (((?operation . advance))
       ((?operation . observe))))
    (cl-prolog/weave:assert-query extended
        (observable-effect clock ?operation) :set
      (((?operation . advance))
       ((?operation . observe))))))

(it "prolog-solutions-stream-through-cps-query-boundary"
  (let ((seen '()))
    (cl-prolog:map-prolog-solutions
     (lambda (solution)
       (push (%prolog-binding '?boundary solution) seen))
     *boundary-policy*
     '(observable-effect ?boundary ?operation)
     :limit 3)
    (expect (= 3 (length seen)) :to-be-truthy)
    (expect (every (lambda (boundary)
                 (member boundary '(filesystem environment process network)))
               seen) :to-be-truthy)))

(it "prolog-occurs-check-rejects-cyclic-boundary-facts"
  (expect (null (cl-prolog:unify '?boundary '(wrapped ?boundary))) :to-be-truthy))

;;; FINDALL: aggregate every declared BOUNDARY/1 fact into one list and
;;; assert its length, rather than enumerating solutions one at a time the
;;; way the :SET query kind above does. Facts and query are both consulted
;;; from text (like *BOUNDARY-POLICY-SOURCE* / the tabled-reachability graph
;;; below), not queried against the sexp-authored *BOUNDARY-POLICY* --
;;; mixing the two representations left BOUNDARY/1 unresolvable from a
;;; text-parsed goal (an atom-identity mismatch between the two clause
;;; authoring styles).
(it "findall-aggregates-every-declared-boundary-fact-into-one-count"
  (let ((policy (cl-prolog:consult-prolog
                 "boundary(filesystem).
                  boundary(environment).
                  boundary(process).
                  boundary(network).
                  boundary(clock).")))
    (expect (= 1 (length
                  (cl-prolog:query-prolog
                   policy
                   (cl-prolog:read-prolog-term
                    "findall(B, boundary(B), [filesystem,environment,process,network,clock])"))))
            :to-be-truthy)))

