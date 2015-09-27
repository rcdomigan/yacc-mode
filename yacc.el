;;; clobbering it over c-mode ala flex.el to get syntax highlighting
;;
;;; added highlighting for $nth word (eg, for the action some rule $1 will highlight the first production)
;;; (\C-cd) primitive type inspection capacity on productions (including $$, $1 etc)

;; note: comments outside of semantic actions may lead to greif with production highlighting 
;; todo: use syntactic-info from CC mode to skip over comments and strings

(defconst yacc-colon-column 20
  "Column in which the colon separating a rule from its definitions will go.")

(defconst yacc-semi-column 18
  "Column in which the semicolon terminating a rule will go.")

(defconst yacc-code-indent 2
  "Indentation from yacc-colon-column of a code block.")

(defconst yacc-percent-column 47
  "Column in which a % (not part of two-letter token) will go.")

(defconst yacc-auto-newline nil
  "*Non-nil means automatically newline before and after braces and semicolons
inserted in yacc code.")

(defconst yacc-highlight-production-delay 0.125)
(defvar yacc-idle-timer '())

(defvar yacc-mode-abbrev-table nil
  "Abbrev table in use in yacc-mode buffers.")
(define-abbrev-table 'yacc-mode-abbrev-table ())

(defvar yacc-electric-chars "[:;|{}]")

(define-derived-mode yacc-mode c-mode "Yacc"
  "Major mode for editing yacc code.
Comments are delimited with /* ... */ and indented with tabs.
Paragraphs are separated by blank lines only.
Delete converts tabs to spaces as it moves back.
\\{yacc-mode-map}
Variables controlling indentation style:
 yacc-auto-newline {currently ignored}
    Non-nil means automatically newline before and after braces and semicolons
    inserted in yacc code.  (A brace also enters C mode.)
 yacc-colon-column
    The column in which a colon or bar will be placed.
 yacc-semi-column
    The column in which a semicolon will be placed.
 yacc-code-indent
    Indentation of a code block from yacc-colon-column.

Turning on yacc mode calls the value of the variable yacc-mode-hook with no
args, if that value is non-nil."

  ;; (kill-all-local-variables)
  (make-local-variable 'paragraph-start)
  (make-local-variable 'paragraph-separate)
  (make-local-variable 'indent-line-function)
  (make-local-variable 'require-final-newline)
  (make-local-variable 'comment-start)
  (make-local-variable 'comment-end)
  (make-local-variable 'comment-column)
  (make-local-variable 'parse-sexp-ignore-comments)
  (yacc-mode-setup)
  (run-hooks 'yacc-mode-hook)

;; keymap stuff
  (use-local-map yacc-mode-map)

  (define-key yacc-mode-map "{" 'yacc-insert-electric-brace)
  (define-key yacc-mode-map ";" 'yacc-insert-electric-character)
  (define-key yacc-mode-map ":" 'yacc-insert-electric-character)
  (define-key yacc-mode-map "|" 'yacc-insert-electric-character)
  (define-key yacc-mode-map "\C-cj" 'yacc-find-type)
  (define-key yacc-mode-map "\C-c\C-j" 'yacc-find-type)
  ;(define-key yacc-mode-map "%" 'yacc-insert-electric-percent)
  (define-key yacc-mode-map "\177" 'backward-delete-char-untabify)
  (define-key yacc-mode-map "\t" 'yacc-indent-line)
  (define-key yacc-mode-map "\C-cyg" 'yacc-goto-word-number)
  (define-key yacc-mode-map "\C-cyh" 'yacc-highlight-matching-word)
  ;; idle timer for production highlighting
  (setq yacc-idle-timer (run-with-idle-timer
  			 yacc-highlight-production-delay t
  			 'yacc-highlight-matching-word))
  )

(defvar yacc-mode-syntax-table nil
  "Syntax table in use in yacc-mode buffers.")

(if yacc-mode-syntax-table
    ()
  (setq yacc-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?\\ "\\" yacc-mode-syntax-table)
  (modify-syntax-entry ?/ ". 14" yacc-mode-syntax-table)
  (modify-syntax-entry ?* ". 23" yacc-mode-syntax-table)
  (modify-syntax-entry ?% "." yacc-mode-syntax-table)
  (modify-syntax-entry ?| "." yacc-mode-syntax-table)
  (modify-syntax-entry ?\' "\"" yacc-mode-syntax-table))

(defun yacc-mode-setup ()
  "Reinstate the context of a yacc-mode buffer.  Used by yacc-mode and
yacc-widen."
  ; should probably let the user hook this..
  (or (assoc 'hl-line-mode minor-mode-alist)
      (hl-line-mode))

  (use-local-map yacc-mode-map)
  (setq major-mode 'yacc-mode)
  (setq mode-name "Yacc parser")
  (setq local-abbrev-table yacc-mode-abbrev-table)
; doesn't seem to be executed?!  Twice gets it set right.
  (set-syntax-table yacc-mode-syntax-table)
  (set-syntax-table yacc-mode-syntax-table)
  (setq paragraph-start (concat "^$\\|" page-delimiter))
  (setq paragraph-separate paragraph-start)
  (setq indent-line-function 'yacc-indent-line)

  (setq require-final-newline t)
  (setq comment-start "/* ")
  (setq comment-end " */")
  (setq comment-column 9)
  (setq parse-sexp-ignore-comments t)
  )

(defun yacc-insert-electric-character (arg)
  "Insert character and correct line's indentation."
  (interactive "P")
  (if (= (char-before) ?')
      (self-insert-command (prefix-numeric-value arg))
    (progn
      (self-insert-command (prefix-numeric-value arg))
      (yacc-indent-line)
      )))

(defun yacc-insert-electric-brace (arg)
  "Insert character and correct line's indentation."
  (interactive "P")
  (let (insert-braces
	enter-braces
	extra-newline-then-enter )
    (fset 'insert-braces (lambda () 
			   (indent-to (+ yacc-colon-column yacc-code-indent))
			   (insert "{\n\n")
			   (indent-to (+ yacc-colon-column yacc-code-indent))
			   (insert "}")))
    (fset 'enter-braces (lambda ()
			  (forward-line -1)
			  (c-indent-line)))

    (fset 'extra-newline-then-enter (lambda ()
				      (insert "\n")
				      (forward-line -2)
				      (c-indent-line)))
    (cond
     ((= (char-before) ?')
      (insert "{"))
     ((yacc-code-block-p)
      (insert "{")
      (c-indent-line))
     ((blank-line-p)
      (progn
		(kill-whole-line)
		(insert-braces)
		(extra-newline-then-enter)))
     ((save-excursion
	(skip-chars-forward " \t")
	(eolp))
      (progn
	(insert "\n")
	(insert-braces)
	(enter-braces)))
     (t
      (progn
	(insert-braces)
	(extra-newline-then-enter))))))

(defun yacc-indent-line ()
  "Indent the current line to the specified column or otherwise to where it
belongs."
  (interactive)
  (if (or (blank-line-p)
	  (yacc-code-block-p)
	  (yacc-head-p))
      (c-indent-line)
    (save-excursion
      (beginning-of-line)
      (skip-chars-forward " \t")
      (if (re-search-forward "[^']:" (line-end-position) t)
	  (progn
	    (backward-char)
	    (let ((end (point))
		  (begin (progn
			   (if (re-search-backward "[^[:space:]]" (line-beginning-position) t)
			       (forward-char))
			   (point))))
	      (delete-region begin end)
	      (indent-to yacc-colon-column)
	      ))
	(progn
	  (indent-to
	   (cond
	    ((looking-at ";") yacc-semi-column)
	    ((looking-at "|") yacc-colon-column)
	    ((looking-at "[{}]") (+ yacc-colon-column yacc-code-indent))
	    (t (+ yacc-colon-column 2))))
	  (forward-char))))))

(defun yacc-head-p ()
  "Return non-nil if we are in the head of a yacc buffer (before the first %%)"
  (save-excursion
    (re-search-backward "^%%" (beginning-of-buffer) 1)
    (not (bobp))))

(defun yacc-code-block-p ()
  (cond
   ((looking-at "[ \t]*[{}]") 'nil)
   ((>= (current-column)
	(+ yacc-colon-column yacc-code-indent))
    't)
   (t
    (let ((syntax (if (boundp 'c-syntactic-context)
		      c-syntactic-context
		    (c-save-buffer-state nil
		      (c-guess-basic-syntax)))))
      (and syntax
	   (not (or (equal (symbol-name 'access-label) (symbol-name (caar syntax)))
		    (equal (symbol-name 'topmost-intro) (symbol-name (caar syntax)))
		    (equal (symbol-name 'topmost-intro) (symbol-name (caar syntax)))
		    (equal (symbol-name 'topmost-intro-cont) (symbol-name (caar syntax)))))))
    )))

(defun blank-line-p ()
  "Return non-nil if the line point is in contains only spaces and/or tabs."
  (save-excursion
    (beginning-of-line)
    (looking-at "[ \t]*$")))

;;; If point is over a reference to a production, put the production's
;;; lexical type in the message buffer.
(defun yacc-find-type ()
  (interactive)
  (let  ((match-found nil)
	 (type '()))
    (save-excursion
      (yacc-goto-word-number) ; shouldn't move point if I'm not at a valid number
      (let ((word (yacc-word-at-point)))
	(setq case-fold-search '())
	(goto-char (point-min))
	(while (not (or (eobp)
			match-found))
	  (re-search-forward "\\(%type\\|%token\\)")
	  (if (re-search-forward "<\\(.*\\)>" (line-end-position) t)
	      (setq type (match-string-no-properties 1)))

	  (if (looking-at  (concat ".*[ \t\n]" word "[ \t\n].*$"))
	      (setq match-found t))) ))
    (message "%s" type)
    ))

(defun yacc-number-at-point ()
  (interactive)
  (skip-chars-backward "[0-9\\$]")
  (if (looking-at "\\$\\$")
      0
    (progn
      (if (= (char-after) ?$)
	  (progn
	    (forward-char)
	    (re-search-forward "[0-9]+" (line-end-position) t)
	    (string-to-number (match-string 0) 10))
	'()))))

;;; If point is over a reference, move point to the token the
;;; reference is referring to.
(defun yacc-goto-word-number (&optional arg)
  (interactive "P")
  (set-mark (point))
  (let ((position (if arg arg (yacc-number-at-point))))
    (cond
     ((not position) '())
     ((= position 0)
      (re-search-backward "^[a-z][a-zA-Z0-9_]*[ \t]*:" (point-min))
      (beginning-of-line)
      (skip-chars-forward " \t"))
     (t ; default
      (set-mark (point))
      ; find beginning of productions
      (re-search-backward "\\([ \t]*[^|]|[^|]\\|^[a-z][a-zA-Z0-9_]*[ \t]*:\\)" (point-min))
      (goto-char (match-end 0))
      (dotimes (i (- position 1))
	(skip-chars-forward " \t\n")
	(skip-chars-forward "^ \t\n"))
      (skip-chars-forward " \t\n"))
    )))

(defvar yacc-active-overlay '())

(defun yacc-highlight-matching-word ()
  (interactive)
  (save-excursion
	(if yacc-active-overlay (delete-overlay yacc-active-overlay))
	(if (yacc-goto-word-number)
		(progn
		  (setq yacc-active-overlay
				(make-overlay
				 (point)
				 (if (re-search-forward "[[:space:]]" (line-end-position) t)
					 (- (point) 1)
				   (line-end-position))))
		  (overlay-put yacc-active-overlay 'face 'font-lock-warning-face))
	  (setq yacc-active-overlay '()))))

(defun yacc-word-at-point ()
  (save-excursion
    (let ((end (progn (re-search-forward "[;:[:space:]\n]")
		      (backward-char) (point)))
	  (begin (progn (re-search-backward "[[:space:]\n]")
			(forward-char) (point))))
      (buffer-substring-no-properties begin end))))
