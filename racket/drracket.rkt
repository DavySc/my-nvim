#lang racket/base
;; Back end for lua/config/drracket: DrRacket's Run, Interactions, macro
;; stepper and Check Syntax, for Neovim. One JSON object per line both ways:
;;   request   {"id": 1, "method": "run", "params": {...}}
;;   response  {"id": 1, "result": ...} or {"id": 1, "error": {...}}
;;   event     {"method": "output" | "value", "params": {...}}
;; Methods: run, eval, stop, expand, syncheck. stdout carries only protocol;
;; the user program's output comes back as "output" events, in order.

(require racket/list racket/string racket/file racket/port racket/lazy-require
         json file/convertible setup/dirs
         errortrace/errortrace-lib errortrace/errortrace-key)
(lazy-require [drracket/check-syntax (show-content)]
              [macro-debugger/stepper-text (expand/step-text)]
              [syntax/modread (with-module-reading-parameterization)])

(define-namespace-anchor anchor)
;; The fresh namespaces share this process's file/convertible, or picts made
;; by the user's code never satisfy our convertible?.
(define home-ns (namespace-anchor->empty-namespace anchor))

(define proto-out (current-output-port))
(current-output-port (current-error-port)) ; stray prints never reach the protocol
(define send-lock (make-semaphore 1))
(define (send! v)
  (call-with-semaphore send-lock
    (λ () (write-json v proto-out) (newline proto-out) (flush-output proto-out))))
(define (event method params) (send! (hasheq 'method method 'params params)))

(define image-dir (make-temporary-directory "drracket-nvim-~a"))
(exit-handler (let ([orig (exit-handler)])
                (λ (code) (delete-directory/files image-dir #:must-exist? #f) (orig code))))

;; ── Output ports ─────────────────────────────────────────────────────────
;; Bytes that end in the middle of a UTF-8 character wait for the rest.
(define (split-utf8 b)
  (let loop ([n (bytes-length b)])
    (cond [(< n (- (bytes-length b) 3)) (values (bytes->string/utf-8 b #\?) #"")]
          [(bytes-utf-8-length b #f 0 n) (values (bytes->string/utf-8 (subbytes b 0 n)) (subbytes b n))]
          [else (loop (sub1 n))])))

(define (stream-port stream)
  (define pending #"")
  (make-output-port
   stream always-evt
   (λ (bs start end _non-block? _breakable?)
     (define-values (text rest) (split-utf8 (bytes-append pending (subbytes bs start end))))
     (set! pending rest)
     (unless (string=? text "") (event "output" (hasheq 'stream (symbol->string stream) 'text text)))
     (- end start))
   void))

(define user-out (stream-port 'stdout))
(define user-err (stream-port 'stderr))
(define value-out (stream-port 'value))

;; ── Values ───────────────────────────────────────────────────────────────
(define (png-of v)
  (and (convertible? v)
       (with-handlers ([exn:fail? (λ (_) #f)]) (convert v 'png-bytes #f))))

;; Images become PNG files; everything else goes to the language's own printer
;; (BSL prints differently from racket), in the "value" stream.
(define (make-print lang-print)
  (λ (v)
    (cond [(void? v) (void)]
          [(png-of v)
           => (λ (png)
                (define path (make-temporary-file "img-~a.png" #f image-dir))
                (call-with-output-file path (λ (o) (write-bytes png o)) #:exists 'truncate)
                (flush-output user-out)
                (event "value" (hasheq 'image (path->string path))))]
          [else (parameterize ([current-output-port value-out])
                  (lang-print v)
                  (flush-output value-out))])))

(define racket-dirs
  (filter values (list (find-collects-dir) (find-pkgs-dir) (find-share-dir))))
(define (in-racket-install? p)
  (define s (path->string (simplify-path p)))
  (for/or ([d racket-dirs]) (string-prefix? s (path->string (simplify-path d)))))

;; ── Errors ───────────────────────────────────────────────────────────────
(define this-file (variable-reference->module-source (#%variable-reference)))
;; Only places in the user's files: not this back end, not Racket itself.
(define (srcloc->json src line col pos span)
  (and (path? src)
       (not (equal? src this-file))
       (not (in-racket-install? src))
       (hasheq 'file (path->string src) 'line (or line 1) 'col (or col 0)
               'pos (or pos 'null) 'span (or span 0))))

(define (exn->json e)
  (cond
    [(exn? e)
     (define marks (exn-continuation-marks e))
     (define from-exn
       (if (exn:srclocs? e)
           (for/list ([s ((exn:srclocs-accessor e) e)] #:when (srcloc? s))
             (srcloc->json (srcloc-source s) (srcloc-line s) (srcloc-column s)
                           (srcloc-position s) (srcloc-span s)))
           '()))
     ;; errortrace marks: (datum source line col pos span), innermost first.
     (define trace
       (for/list ([m (continuation-mark-set->list marks errortrace-key)]
                  #:when (and (pair? m) (list? m) (= (length m) 6)))
         (apply srcloc->json (cdr m))))
     (define context
       (for/list ([c (continuation-mark-set->context marks)] #:when (srcloc? (cdr c)))
         (define s (cdr c))
         (srcloc->json (srcloc-source s) (srcloc-line s) (srcloc-column s)
                       (srcloc-position s) (srcloc-span s))))
     (hasheq 'message (exn-message e)
             'kind (cond [(exn:break? e) "break"] [(exn:fail:syntax? e) "syntax"]
                         [(exn:fail:read? e) "read"] [else "runtime"])
             'srclocs (filter values from-exn)
             'stack (filter values (if (null? trace) context trace)))]
    [else (hasheq 'message (format "raised a non-exception: ~e" e) 'kind "raise"
                  'srclocs '() 'stack '())]))

;; ── Running user code ────────────────────────────────────────────────────
;; A run is one program: its custodian and one long-lived user thread that
;; does the run and then every eval, so whatever configure-runtime or the
;; program sets (current-print, the namespace, ...) stays set, as in DrRacket.
(struct run (custodian thread jobs [job #:mutable]))
(define current-run #f)
;; The namespace the last program left its REPL in (for expanding a selection).
(define last-namespace #f)
;; racket/gui/base may be instantiated once per process; later runs borrow it
;; from the run that first loaded it.
(define gui-ns #f)

(define (busy?) (and current-run (run-job current-run) #t))

(define (shutdown!)
  (when current-run
    (custodian-shutdown-all (run-custodian current-run))
    (set! current-run #f)))

;; Start a run's user thread with `setup` already applied to its parameters.
(define (start-run! cust setup)
  (define jobs (make-channel))
  (define r #f)
  (define t
    (parameterize ([current-custodian cust])
      (setup
       (λ ()
         (thread
          (λ ()
            (let loop ()
              (define job (parameterize-break #f (channel-get jobs)))
              (define reply
                (with-handlers ([(λ (_) #t) (λ (e) (hasheq 'id (car job) 'error (exn->json e)))])
                  (hasheq 'id (car job) 'result (parameterize-break #t ((cdr job))))))
              (flush-output user-out) (flush-output user-err) (flush-output value-out)
              (set-run-job! r #f)
              (send! reply)
              (loop))))))))
  (set! r (run cust t jobs #f))
  ;; A memory limit or a new Run can kill the thread mid-job; still answer.
  (thread (λ ()
            (sync (thread-dead-evt t))
            (define id (run-job r))
            (when id
              (set-run-job! r #f)
              (send! (hasheq 'id id 'error (hasheq 'kind "killed" 'srclocs '() 'stack '()
                                                   'message "The program was stopped: it hit its memory limit or a new Run replaced it."))))))
  r)

(define (submit! r id thunk)
  (set-run-job! r id)
  (channel-put (run-jobs r) (cons id thunk)))

(define (configure-runtime! file)
  (define submod `(submod ,file configure-runtime))
  (cond
    [(module-declared? submod #t) (dynamic-require submod #f)]
    [(module->language-info file #t)
     => (λ (info)
          (define get-info ((dynamic-require (vector-ref info 0) (vector-ref info 1)) (vector-ref info 2)))
          (for ([c (get-info 'configure-runtime '())])
            ((dynamic-require (vector-ref c 0) (vector-ref c 1)) (vector-ref c 2))))]
    [else (void)]))

(define (do-run id params)
  (shutdown!)
  (define file (and (hash-ref params 'file #f) (simplify-path (path->complete-path (hash-ref params 'file)))))
  (define dir (if file (let-values ([(d _n _m) (split-path file)]) d) (current-directory)))
  (define cust (make-custodian))
  (define limit (hash-ref params 'memory_mb #f))
  (when (and limit (custodian-memory-accounting-available?))
    (custodian-limit-memory cust (* limit 1024 1024) cust))
  (define ns (make-base-empty-namespace))
  (namespace-attach-module home-ns 'file/convertible ns)
  (when gui-ns
    (for ([m '(racket/draw racket/gui/base)])
      (with-handlers ([exn:fail? void]) (namespace-attach-module gui-ns m ns))))
  (define r
    (start-run! cust
      (λ (go)
        (parameterize ([current-namespace ns]
                       [current-output-port user-out]
                       [current-error-port user-err]
                       [current-input-port (open-input-string "")]
                       [current-directory dir]
                       [current-load-relative-directory dir]
                       [compile-enforce-module-constants #f]
                       [current-command-line-arguments (vector)])
          ;; Made inside the namespace: the handler only instruments its registry.
          (parameterize ([current-compile (if (hash-ref params 'errortrace #t)
                                              (make-errortrace-compile-handler)
                                              (current-compile))])
            (go))))))
  (set! current-run r)
  (submit! r id
    (λ ()
      (cond
        [file
         (configure-runtime! file)
         (current-print (make-print (current-print)))
         (dynamic-require file #f)
         ;; DrRacket runs these too: BSL's check-expect report lives in `test`.
         (for ([sub (hash-ref params 'submodules '("main" "test"))])
           (define m `(submod ,file ,(string->symbol sub)))
           (when (module-declared? m #t) (dynamic-require m #f)))
         (current-namespace (module->namespace file))]
        [else
         (namespace-require 'racket/base)
         (current-print (make-print (current-print)))])
      (set! last-namespace (current-namespace))
      (remember-gui! ns)
      (hasheq 'language (if file (language-name file) "racket/base")))))

;; Did this run instantiate racket/gui/base? Then it's the one to borrow from.
(define (remember-gui! ns)
  (unless gui-ns
    (when (with-handlers ([exn:fail? (λ (_) #f)])
            (parameterize ([current-namespace ns])
              (module->namespace 'racket/gui/base)
              #t))
      (set! gui-ns ns))))

(define (language-name file)
  (with-handlers ([exn:fail? (λ (_) "")])
    (call-with-input-file file
      (λ (in) (cond [(regexp-match #px"#lang\\s+(\\S+)" (read-line in)) => cadr]
                    [else ""])))))

(define (do-eval id params)
  (unless current-run (do-run-repl-only))
  (define code (hash-ref params 'code))
  (submit! current-run id
    (λ ()
      (define in (open-input-string code))
      (port-count-lines! in)
      (let loop ()
        (define form ((current-read-interaction) 'interactions in))
        (unless (eof-object? form)
          (call-with-values
           (λ () (eval (if (syntax? form)
                           (namespace-syntax-introduce (datum->syntax #f (cons '#%top-interaction form)))
                           (cons '#%top-interaction form))))
           (λ vs (for-each (current-print) vs)))
          (loop)))
      #t)))

;; An eval with no program run yet gets a racket/base REPL, like DrRacket's
;; empty Definitions window.
(define (do-run-repl-only)
  (define ns (make-base-empty-namespace))
  (namespace-attach-module home-ns 'file/convertible ns)
  (set! current-run
    (start-run! (make-custodian)
      (λ (go)
        (parameterize ([current-namespace ns] [current-output-port user-out]
                       [current-error-port user-err] [current-input-port (open-input-string "")])
          (namespace-require 'racket/base)
          (current-print (make-print (current-print)))
          (set! last-namespace ns)
          (go))))))

(define (do-stop id)
  (define stopped (busy?))
  (when stopped (break-thread (run-thread current-run)))
  (send! (hasheq 'id id 'result (hasheq 'stopped stopped))))

;; ── Tools ────────────────────────────────────────────────────────────────
;; The buffer's text, read as a module whose source is the file, so results
;; line up with what's on screen even before a save.
(define (read-module file text)
  (define in (open-input-string text file))
  (port-count-lines! in)
  (with-module-reading-parameterization (λ () (read-syntax file in))))

(define (file-dir file) (let-values ([(d _n _m) (split-path file)]) d))

;; The stepper's default: hide macros from Racket's own installation, show
;; everything else (your languages, packages linked from elsewhere, the file).
(define (user-macro? id)
  (define b (identifier-binding id))
  (cond [(not (pair? b)) #t]
        [else
         (define name (resolved-module-path-name (module-path-index-resolve (car b))))
         (define p (if (pair? name) (cadr name) name))
         (not (and (path? p) (in-racket-install? p)))]))

(define (do-expand id params)
  (define file (simplify-path (path->complete-path (hash-ref params 'file))))
  (define show (if (hash-ref params 'all #f) (λ (_) #t) user-macro?))
  (define out (open-output-string))
  (define (steps stx)
    (parameterize ([current-output-port out]) (expand/step-text stx show)))
  (define form (hash-ref params 'form #f))
  (cond
    [form
     ;; A form: in the namespace of the program that last ran, else racket/base.
     (define in (open-input-string form file))
     (port-count-lines! in)
     (define stx (read-syntax file in))
     (parameterize ([current-namespace (or last-namespace (make-base-namespace))])
       (steps (namespace-syntax-introduce stx)))]
    [else
     (parameterize ([current-namespace (make-base-namespace)]
                    [current-load-relative-directory (file-dir file)]
                    [current-directory (file-dir file)])
       (steps (read-module file (hash-ref params 'text))))])
  (send! (hasheq 'id id 'result (hasheq 'text (get-output-string out)))))

(define (do-syncheck id params)
  (define file (simplify-path (path->complete-path (hash-ref params 'file))))
  (define results
    (parameterize ([current-load-relative-directory (file-dir file)]
                   [current-directory (file-dir file)])
      (show-content (read-module file (hash-ref params 'text)))))
  (define arrows '()) (define tails '()) (define unused '()) (define status '())
  (for ([v (in-list results)])
    (case (vector-ref v 0)
      [(syncheck:add-arrow/name-dup/pxpy)
       ;; binder range, use range, whether the binder is a require
       (set! arrows (cons (list (vector-ref v 1) (vector-ref v 2) (vector-ref v 5) (vector-ref v 6)
                                (and (vector-ref v 11) #t))
                          arrows))]
      [(syncheck:add-tail-arrow) (set! tails (cons (list (vector-ref v 1) (vector-ref v 2)) tails))]
      [(syncheck:add-unused-require) (set! unused (cons (list (vector-ref v 1) (vector-ref v 2)) unused))]
      [(syncheck:add-mouse-over-status)
       (set! status (cons (list (vector-ref v 1) (vector-ref v 2) (vector-ref v 3)) status))]
      [else (void)]))
  (send! (hasheq 'id id 'result (hasheq 'arrows (remove-duplicates arrows) 'tails tails
                                        'unused unused 'status (remove-duplicates status)))))

;; ── Main loop ────────────────────────────────────────────────────────────
;; Tools run on their own thread, so a slow expansion doesn't hold up a stop.
(define (tool id thunk)
  (thread (λ () (with-handlers ([(λ (_) #t) (λ (e) (send! (hasheq 'id id 'error (exn->json e))))])
                  (thunk)))))

(define (dispatch msg)
  (define id (hash-ref msg 'id 'null))
  (define params (let ([p (hash-ref msg 'params #f)]) (if (hash? p) p (hasheq))))
  (define method (hash-ref msg 'method ""))
  (cond
    [(member method '("run" "eval"))
     (if (and (equal? method "eval") (busy?))
         (send! (hasheq 'id id 'error (hasheq 'message "still running: stop it first" 'kind "busy"
                                              'srclocs '() 'stack '())))
         (with-handlers ([exn:fail? (λ (e) (send! (hasheq 'id id 'error (exn->json e))))])
           ((if (equal? method "run") do-run do-eval) id params)))]
    [(equal? method "stop") (do-stop id)]
    [(equal? method "expand") (tool id (λ () (do-expand id params)))]
    [(equal? method "syncheck") (tool id (λ () (do-syncheck id params)))]
    [else (send! (hasheq 'id id 'error (hasheq 'message (format "unknown method: ~a" method)
                                                 'kind "protocol" 'srclocs '() 'stack '())))]))

(module+ main
  (let loop ()
    (define line (read-line (current-input-port) 'any))
    (unless (eof-object? line)
      (unless (string=? (string-trim line) "")
        (define msg (with-handlers ([exn:fail? (λ (_) #f)]) (string->jsexpr line)))
        (if (hash? msg)
            (dispatch msg)
            (event "log" (hasheq 'text (format "not a JSON object: ~a" line)))))
      (loop)))
  (shutdown!)
  (exit 0))
