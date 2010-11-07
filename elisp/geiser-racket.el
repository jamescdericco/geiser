;; geiser-racket.el -- geiser support for Racket scheme

;; Copyright (C) 2009, 2010 Jose Antonio Ortega Ruiz

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the Modified BSD License. You should
;; have received a copy of the license along with this program. If
;; not, see <http://www.xfree86.org/3.3.6/COPYRIGHT2.html#5>.

;; Start date: Sat Apr 25, 2009 21:13



(require 'geiser-edit)
(require 'geiser-doc)
(require 'geiser-eval)
(require 'geiser-syntax)
(require 'geiser-custom)
(require 'geiser-base)


;;; Customization:

(defgroup geiser-racket nil
  "Customization for Geiser's Racket flavour."
  :group 'geiser)

(geiser-custom--defcustom geiser-racket-binary
  (cond ((eq system-type 'windows-nt) "Racket.exe")
        (t "racket"))
  "Name to use to call the racket executable when starting a REPL."
  :type '(choice string (repeat string))
  :group 'geiser-racket)

(geiser-custom--defcustom geiser-racket-gracket-binary
  (cond ((eq system-type 'windows-nt) "GRacket-text.exe")
        (t "gracket-text"))
  "Name to use to call the gracket executable when starting a REPL.
This executable is used by `run-gracket', and, if
`geiser-racket-use-gracket-p' is set to t, by `run-racket'."
  :type '(choice string (repeat string))
  :group 'geiser-racket)

(geiser-custom--defcustom geiser-racket-collects nil
  "A list of paths to be added to racket's collection directories."
  :type '(repeat file)
  :group 'geiser-racket)

(geiser-custom--defcustom geiser-racket-init-file "~/.racket-geiser"
  "Initialization file with user code for the racket REPL."
  :type 'string
  :group 'geiser-racket)

(geiser-custom--defcustom geiser-racket-use-gracket-p nil
  "Whether to use the gracket binary to start Racket REPLs."
  :type 'boolean
  :group 'geiser-racket)



;;; REPL support:

(defsubst geiser-racket--real-binary ()
  (if geiser-racket-use-gracket-p
      geiser-racket-gracket-binary
    geiser-racket-binary))

(defun geiser-racket--binary ()
  (let ((binary (geiser-racket--real-binary)))
    (if (listp binary) (car binary) binary)))

(defun geiser-racket--parameters ()
  "Return a list with all parameters needed to start racket.
This function uses `geiser-racket-init-file' if it exists."
  (let ((init-file (and (stringp geiser-racket-init-file)
                        (expand-file-name geiser-racket-init-file)))
        (binary (geiser-racket--real-binary)))
    `("-i" "-q"
      "-S" ,(expand-file-name "racket/" geiser-scheme-dir)
      ,@(apply 'append (mapcar (lambda (p) (list "-S" p)) geiser-racket-collects))
      ,@(and (listp binary) (cdr binary))
      ,@(and init-file (file-readable-p init-file) (list "-f" init-file))
      "-f" ,(expand-file-name "racket/geiser.rkt" geiser-scheme-dir))))

(defconst geiser-racket--prompt-regexp "^=?\\(mzscheme\\|racket\\)@[^ ]*?> ")


;;; Evaluation support:

(defun geiser-racket--language ()
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward
         "^\\(?:#lang\\|(module +[^ ]+?\\) +\\([^ ]+?\\|([^)]+)\\) *$" nil t)
        (car (geiser-syntax--read-from-string (match-string-no-properties 1)))
      "#f")))

(defun geiser-racket--geiser-procedure (proc &rest args)
  (case proc
    ((eval compile)
     (format ",geiser-eval %s %s %s"
             (or (car args) "#f")
             (geiser-racket--language)
             (mapconcat 'identity (cdr args) " ")))
    ((load-file compile-file)
     (format ",geiser-eval geiser/main racket (geiser:%s %s)"
             proc (car args)))
    ((no-values) ",geiser-no-values")
    (t (format ",apply geiser:%s (%s)" proc (mapconcat 'identity args " ")))))

(defconst geiser-racket--module-re
  "^(module +\\([^ ]+\\)")

(defun geiser-racket--explicit-module ()
  (save-excursion
    (goto-char (point-min))
    (and (re-search-forward geiser-racket--module-re nil t)
         (ignore-errors
           (car (geiser-syntax--read-from-string
                 (match-string-no-properties 1)))))))

(defsubst geiser-racket--implicit-module ()
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^#lang " nil t)
        (buffer-file-name)
      :f)))

(defun geiser-racket--get-module (&optional module)
  (cond ((and (null module) (buffer-file-name)))
        ;; (geiser-racket--explicit-module)
        ((null module) (geiser-racket--implicit-module))
        ((symbolp module) module)
        ((and (stringp module) (file-name-absolute-p module)) module)
        ((stringp module) (intern module))
        (t nil)))

(defun geiser-racket--symbol-begin (module)
  (save-excursion (skip-syntax-backward "^-()>") (point)))

(defun geiser-racket--enter-command (module)
  (when (stringp module)
    (cond ((zerop (length module)) ",enter #f")
          ((file-name-absolute-p module) (format ",enter (file %S)" module))
          (t (format ",enter %s" module)))))

(defun geiser-racket--import-command (module)
  (and (stringp module)
       (not (zerop (length module)))
       (format "(require %s)" module)))

(defun geiser-racket--exit-command ()
  (comint-send-eof)
  (get-buffer-process (current-buffer)))

(defconst geiser-racket--binding-forms
  '(for for/list for/hash for/hasheq for/and for/or
    for/lists for/first for/last for/fold
    for: for/list: for/hash: for/hasheq: for/and: for/or:
    for/lists: for/first: for/last: for/fold:))

(defconst geiser-racket--binding-forms*
  '(for* for*/list for*/lists for*/hash for*/hasheq for*/and
    for*/or for*/first for*/last for*/fold
    for*: for*/list: for*/lists: for*/hash: for*/hasheq: for*/and:
    for*/or: for*/first: for*/last: for*/fold:))

;;; External help

(defsubst geiser-racket--get-help (symbol module)
  (geiser-eval--send/wait
   `(:eval (get-help ',symbol '(:module ,module)) geiser/autodoc)))

(defun geiser-racket--external-help (id module)
  (message "Requesting help for '%s'..." id)
  (let ((out (geiser-eval--retort-output
              (geiser-racket--get-help id module))))
    (when (and out (string-match " but provided by:\n +\\(.+\\)\n" out))
      (geiser-racket--get-help id (match-string 1 out))))
  (minibuffer-message "%s done" (current-message))
  t)


;;; Error display

(defconst geiser-racket--file-rxs
  '(nil
    "path:\"?\\([^>\"\n]+\\)\"?>"
    "module: \"\\([^>\"\n]+\\)\""))

(defconst geiser-racket--geiser-file-rx
  (format "^%s/?racket/geiser" (regexp-quote geiser-scheme-dir)))

(defun geiser-racket--purge-trace ()
  (save-excursion
    (while (re-search-forward geiser-racket--geiser-file-rx nil t)
      (kill-whole-line))))

(defun geiser-racket--display-error (module key msg)
  (when key
    (insert "Error: ")
    (geiser-doc--insert-button key nil 'racket)
    (newline 2))
  (when msg
    (let ((p (point)))
      (insert msg)
      (when key
        (let ((end (point)))
        (goto-char p)
        (geiser-racket--purge-trace)
        (mapc 'geiser-edit--buttonize-files geiser-racket--file-rxs)
        (goto-char end)
        (newline)))))
  (or key (not (zerop (length msg)))))


;;; Trying to ascertain whether a buffer is mzscheme scheme:

(defun geiser-racket--guess ()
  (or (save-excursion
        (goto-char (point-min))
        (re-search-forward "#lang " nil t))
      (geiser-racket--explicit-module)))


;;; Implementation definition:

(define-geiser-implementation racket
  (unsupported-procedures '(callers callees generic-methods))
  (binary geiser-racket--binary)
  (arglist geiser-racket--parameters)
  (startup)
  (prompt-regexp geiser-racket--prompt-regexp)
  (marshall-procedure geiser-racket--geiser-procedure)
  (find-module geiser-racket--get-module)
  (enter-command geiser-racket--enter-command)
  (import-command geiser-racket--import-command)
  (exit-command geiser-racket--exit-command)
  (find-symbol-begin geiser-racket--symbol-begin)
  (display-error geiser-racket--display-error)
  (display-help geiser-racket--external-help)
  (check-buffer geiser-racket--guess)
  (binding-forms geiser-racket--binding-forms)
  (binding-forms* geiser-racket--binding-forms*))

(geiser-impl--add-to-alist 'regexp "\\.ss$" 'racket t)
(geiser-impl--add-to-alist 'regexp "\\.rkt$" 'racket t)

(defun run-gracket ()
  "Start the Racket REPL using gracket instead of plain racket."
  (interactive)
  (let ((geiser-racket-use-gracket-p t))
    (run-racket)))


(provide 'geiser-racket)
;;; geiser-racket.el ends here
