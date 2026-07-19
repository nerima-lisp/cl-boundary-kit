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
(defparameter *boundary-api-completeness*
  (cl-prolog:prolog
    ((provides-native filesystem)) ((provides-native environment))
    ((provides-native process)) ((provides-native network))
    ((provides-native clock)) ((provides-native random))
    ((provides-test filesystem)) ((provides-test environment))
    ((provides-test process)) ((provides-test network))
    ((provides-test random))
    ((provides-recording filesystem)) ((provides-recording environment))
    ((provides-recording process)) ((provides-recording network))
    ((provides-recording random))
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
    ((?boundary . random))))
  ("clock is the one documented, deliberate asymmetry"
   (complete-triad clock) :fails))

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
                   (cl-prolog:read-prolog-term "findall(B, boundary(B), Bs), length(Bs, 5)"))))
            :to-be-truthy)))

;;;; ---------------------------------------------------------------------------
;;;; Advanced cl-prolog 0.6.0 usage
;;;;
;;;; The policy above is authored as trusted Lisp data.  A real deployment may
;;;; instead receive the effect surface as *untrusted* Prolog source text (for
;;;; example a policy file shipped next to a plugin).  These cases exercise the
;;;; 0.6.0 capabilities that make that both safe and expressive: bounded
;;;; parsing of untrusted input, ISO-conformant rejection of malformed goals,
;;;; and terminating transitive reasoning over a boundary delegation graph.
;;;; ---------------------------------------------------------------------------

(defparameter *boundary-policy-source*
  "boundary(filesystem).
   boundary(environment).
   effect(filesystem, read).
   effect(filesystem, write).
   effect(environment, read).
   permitted(B, Op) :- boundary(B), effect(B, Op)."
  "The effect surface expressed as untrusted Prolog source text, as it might
arrive from an external configuration file.")

;;; Security: untrusted policy text is parsed within explicit resource bounds,
;;; so a hostile or malformed configuration cannot exhaust memory, the control
;;; stack, or the symbol table.  Each limit is a dynamically-bound special, so
;;; a host can tighten it around any consult of untrusted input.

;;; Goals against a text-consulted rulebase are themselves parsed from text, so
;;; the untrusted atom names never have to be pre-interned into a host package
;;; and atom identity stays consistent between clauses and queries.
(it "untrusted-policy-source-parses-and-answers-queries"
  (let ((policy (cl-prolog:consult-prolog *boundary-policy-source*)))
    (expect (cl-prolog:prolog-succeeds-p
             policy (cl-prolog:read-prolog-term "permitted(filesystem, read)"))
            :to-be-truthy)
    (expect (cl-prolog:prolog-succeeds-p
             policy (cl-prolog:read-prolog-term "permitted(filesystem, mutate)"))
            :to-be-null)))

(it "oversized-policy-token-stream-is-rejected-with-a-bounded-error"
  (let ((cl-prolog:*max-prolog-tokens* 8))
    (signals cl-prolog:prolog-parser-resource-error
      (cl-prolog:consult-prolog *boundary-policy-source*))))

(it "deeply-nested-policy-terms-are-rejected-before-stack-exhaustion"
  (let ((cl-prolog:*max-prolog-parser-depth* 4))
    (signals cl-prolog:prolog-parser-resource-error
      (cl-prolog:read-prolog-term "effect(a(b(c(d(e(f))))))"))))

(it "the-parser-resource-error-carries-actionable-diagnostics"
  (let ((cl-prolog:*max-prolog-source-characters* 5))
    (handler-case
        (progn (cl-prolog:read-prolog-term "boundary(filesystem)")
               (error "expected a parser resource error"))
      (cl-prolog:prolog-parser-resource-error (condition)
        (expect (string= "SOURCE_CHARACTERS"
                         (cl-prolog:prolog-parser-resource-error-resource condition))
                :to-be-truthy)
        (expect (= 5 (cl-prolog:prolog-parser-resource-error-limit condition))
                :to-be-truthy)))))

;;; ISO conformance: the query boundary rejects malformed goals with typed,
;;; catchable conditions instead of silently failing or looping.

(cl-prolog/weave:deftest-queries prolog-query-boundary-rejects-malformed-goals
    (*boundary-policy*)
  ("an unbound goal raises an ISO instantiation error"
   ?goal :signals cl-prolog:prolog-instantiation-error)
  ("a non-callable goal is rejected before dispatch"
   42 :signals cl-prolog:invalid-goal-error))

;;; Advanced reasoning + performance: a boundary *delegation* graph and its
;;; transitive closure.  The closure rule is deliberately left-recursive; the
;;; 0.6.0 engine detects the left recursion via strongly-connected components
;;; and terminates, where a naive resolution order would diverge.

(defparameter *boundary-delegation*
  (cl-prolog:prolog
    ((delegates recording-filesystem buffered-filesystem))
    ((delegates buffered-filesystem native-filesystem))
    ((delegates recording-process native-process))
    ((delegates recording-network native-network))
    ;; Left-recursive transitive closure of DELEGATES.
    ((reaches ?a ?b) (reaches ?a ?m) (delegates ?m ?b))
    ((reaches ?a ?b) (delegates ?a ?b)))
  "Which concrete boundaries a recording boundary ultimately delegates to.")

(cl-prolog/weave:deftest-queries boundary-delegation-reachability-terminates
    (*boundary-delegation*)
  ("left-recursive reachability yields the full delegation closure"
   (reaches recording-filesystem ?target) :set
   (((?target . buffered-filesystem))
    ((?target . native-filesystem))))
  ("direct delegation is included in the closure"
   (reaches recording-process ?target) :set
   (((?target . native-process)))))

;;; Performance: the same closure expressed as untrusted source with the
;;; predicate declared tabled.  Tabling memoizes variant subgoals, so the
;;; closure over a *cyclic* graph is computed once and terminates.

(it "tabled-reachability-over-a-cyclic-graph-terminates-and-deduplicates"
  (let ((graph (cl-prolog:consult-prolog
                "
:- table(reaches/2).
delegates(a, b).
delegates(b, c).
delegates(c, a).
reaches(X, Y) :- delegates(X, Y).
reaches(X, Y) :- delegates(X, Z), reaches(Z, Y).")))
    ;; Over the cycle a -> b -> c -> a every node reaches all three nodes,
    ;; each exactly once thanks to tabled answer deduplication.
    (expect (= 3 (length (cl-prolog:query-prolog
                          graph (cl-prolog:read-prolog-term "reaches(a, Y)"))))
            :to-be-truthy)))

;;; Definite-clause grammar (DCG): a capability grant is a well-formed,
;;; non-empty stream of recognized boundary effects.  The grammar validates
;;; the stream declaratively; unknown effects or an empty grant are rejected.
;;; (Grammar operators like TERMINAL are matched by symbol name, so they stay
;;; unqualified; DEF-DCG-RULE/MAKE-RULEBASE/PHRASE-ALL are cl-prolog entry
;;; points.)

(defparameter *capability-grammar*
  (cl-prolog:make-rulebase
   :clauses (list (cl-prolog:def-dcg-rule effect (terminal :read))
                  (cl-prolog:def-dcg-rule effect (terminal :write))
                  (cl-prolog:def-dcg-rule effect (terminal :request))
                  (cl-prolog:def-dcg-rule effect (terminal :observe))
                  (cl-prolog:def-dcg-rule capability effect)
                  (cl-prolog:def-dcg-rule capability effect capability)))
  "A DCG whose CAPABILITY rule accepts a non-empty stream of boundary effects.")

(defun %capability-grant-p (tokens)
  "True when TOKENS is fully consumed by the CAPABILITY grammar, i.e. the whole
stream is a well-formed boundary capability grant."
  (and (member nil (cl-prolog:phrase-all *capability-grammar* 'capability tokens)
               :test #'eq)
       t))

(it "dcg-accepts-well-formed-boundary-capability-streams"
  (expect (%capability-grant-p '(:read :write :request :observe)) :to-be-truthy)
  (expect (%capability-grant-p '(:read)) :to-be-truthy))

(it "dcg-rejects-empty-or-malformed-capability-streams"
  (expect (%capability-grant-p '()) :to-be-null)
  (expect (%capability-grant-p '(:read :delete)) :to-be-null)
  (expect (%capability-grant-p '(:read :write :bogus)) :to-be-null))

;;; Finite-domain constraints: assign distinct priority levels 1..3 to the
;;; filesystem, network, and process boundaries such that the filesystem is
;;; ordered ahead of the network.  The constraint solver enumerates exactly
;;; the admissible orderings (parsed from text so the FD builtins dispatch
;;; under their canonical spelling).

(it "finite-domain-constraints-enumerate-admissible-boundary-orderings"
  (let ((orderings
          (cl-prolog:query-prolog
           (cl-prolog:make-rulebase)
           (cl-prolog:read-prolog-term
            "Fs in 1..3, Net in 1..3, Proc in 1..3, all_different([Fs,Net,Proc]), Fs #< Net, labeling([], [Fs,Net,Proc])"))))
    ;; Over distinct priorities in 1..3 with Fs < Net there are exactly three
    ;; admissible orderings.
    (expect (= 3 (length orderings)) :to-be-truthy)))
