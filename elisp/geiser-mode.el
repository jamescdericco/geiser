;; geiser-mode.el -- minor mode for scheme buffers

;; Copyright (C) 2009 Jose Antonio Ortega Ruiz

;; Author: Jose Antonio Ortega Ruiz <jao@gnu.org>
;; Start date: Sun Feb 08, 2009 15:13

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3 of the License, or
;; (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Comentary:

;; Minor mode adding Geiser REPL/Emacs interaction commands to Scheme
;; buffers.

;;; Code:

(require 'geiser-doc)
(require 'geiser-compile)
(require 'geiser-completion)
(require 'geiser-edit)
(require 'geiser-autodoc)
(require 'geiser-eval)
(require 'geiser-popup)
(require 'geiser-custom)
(require 'geiser-base)


;;; Customization:

(defgroup geiser-mode nil
  "Mode enabling Geiser abilities in Scheme buffers &co.."
  :group 'geiser)

(defcustom geiser-mode-autodoc-p t
  "Whether `geiser-autodoc-mode' gets enabled by default in Scheme buffers."
  :group 'geiser-mode
  :group 'geiser-autodoc
  :type 'boolean)

(defcustom geiser-mode-smart-tab-p t
  "Whether `geiser-smart-tab-mode' gets enabled by default in Scheme buffers."
  :group 'geiser-mode
  :type 'boolean)



;;; Auxiliary functions:

(geiser-popup--define mode "*Geiser evaluation results*" scheme-mode)

(defun geiser-eval--display-error (err output)
  (if (not output)
      (message (geiser-eval--error-str err))
    (geiser-mode--with-buffer
      (erase-buffer)
      (insert ";; " (geiser-eval--error-str err))
      (newline 2)
      (insert output)
      (newline))
    (geiser-mode--pop-to-buffer)))

(defun geiser-eval--send-region (compile start end and-go)
  (let* ((str (buffer-substring-no-properties start end))
         (code `(,(if compile :comp :eval) (:scm ,str)))
         (ret (geiser-eval--send/wait code))
         (err (geiser-eval--retort-error ret)))
    (when and-go
      (switch-to-guile)
      (push-mark)
      (goto-char (point-max)))
    (if (not err)
        (message (format "=> %s" (geiser-eval--retort-result ret)))
      (geiser-eval--display-error err (geiser-eval--retort-output ret)))))


;;; Evaluation commands:

(defun geiser-eval-region (start end &optional and-go)
  "Eval the current region in the Geiser REPL.
With prefix, goes to the REPL buffer afterwards (as
`geiser-eval-region-and-go')"
  (interactive "rP")
  (geiser-eval--send-region nil start end and-go))

(defun geiser-eval-region-and-go (start end)
  "Eval the current region in the Geiser REPL and visit it afterwads."
  (interactive "r")
  (geiser-eval-region start end t))

(defun geiser-eval-definition (&optional and-go)
  "Eval the current definition in the Geiser REPL.
With prefix, goes to the REPL buffer afterwards (as
`geiser-eval-definition-and-go')"
  (interactive "P")
  (save-excursion
    (end-of-defun)
    (let ((end (point)))
      (beginning-of-defun)
      (geiser-eval-region (point) end and-go))))

(defun geiser-eval-definition-and-go ()
  "Eval the current definition in the Geiser REPL and visit it afterwads."
  (interactive)
  (geiser-eval-definition t))

(defun geiser-eval-last-sexp ()
  "Eval the previous sexp in the Geiser REPL."
  (interactive)
  (geiser-eval-region (save-excursion (backward-sexp) (point)) (point)))

(defun geiser-compile-definition (&optional and-go)
  "Compile the current definition in the Geiser REPL.
With prefix, goes to the REPL buffer afterwards (as
`geiser-eval-definition-and-go')"
  (interactive "P")
  (save-excursion
    (end-of-defun)
    (let ((end (point)))
      (beginning-of-defun)
      (geiser-eval--send-region t (point) end and-go))))

(defun geiser-compile-definition-and-go ()
  "Compile the current definition in the Geiser REPL and visit it afterwads."
  (interactive)
  (geiser-compile-definition t))


;;; Geiser mode:

(make-variable-buffer-local
 (defvar geiser-mode-string " Geiser"
   "Modeline indicator for geiser-mode"))

(defvar geiser-mode-map (make-sparse-keymap)
  "Key map for geiser-mode")

(define-minor-mode geiser-mode
  "Toggle Geiser's mode.
With no argument, this command toggles the mode.
Non-null prefix argument turns on the mode.
Null prefix argument turns off the mode.

When Geiser mode is enabled, a host of nice utilities for
interacting with the Geiser REPL is at your disposal.
\\{geiser-mode-map}"
  :init-value nil
  :lighter geiser-mode-string
  :group 'geiser-mode
  :keymap geiser-mode-map
  (setq geiser-autodoc-mode-string "/A")
  (setq geiser-smart-tab-mode-string "/T")
  (when geiser-mode-autodoc-p (geiser-autodoc-mode geiser-mode))
  (when geiser-mode-smart-tab-p (geiser-smart-tab-mode geiser-mode)))


;;; Keys:

(defun geiser-mode--triple-chord (p k c)
  (define-key geiser-mode-map (vector '(control ?c) `(control ,p) k) c)
  (define-key geiser-mode-map (vector '(control ?c) `(control ,p) `(control ,k)) c))

(define-key geiser-mode-map "\C-c\C-z" 'switch-to-guile)
(define-key geiser-mode-map "\C-c\C-l" 'geiser-load-current-buffer)
(define-key geiser-mode-map "\C-c\C-k" 'geiser-compile-current-buffer)

(define-key geiser-mode-map (kbd "M-TAB") 'geiser-completion--complete-symbol)
(define-key geiser-mode-map "\M-." 'geiser-edit-symbol-at-point)
(define-key geiser-mode-map "\M-," 'geiser-edit-pop-edit-symbol-stack)

(define-key geiser-mode-map "\M-\C-x" 'geiser-eval-definition)
(define-key geiser-mode-map "\C-x\C-e" 'geiser-eval-last-sexp)
(define-key geiser-mode-map "\C-c\M-e" 'geiser-eval-definition-and-go)
(define-key geiser-mode-map "\C-c\C-r" 'geiser-eval-region)
(define-key geiser-mode-map "\C-c\M-r" 'geiser-eval-region-and-go)
(define-key geiser-mode-map "\C-c\M-c" 'geiser-compile-definition)
(define-key geiser-mode-map "\C-c\C-c" 'geiser-compile-definition-and-go)

(geiser-mode--triple-chord ?d ?a 'geiser-autodoc-mode)
(geiser-mode--triple-chord ?d ?d 'geiser-doc-symbol-at-point)
(geiser-mode--triple-chord ?d ?m 'geiser-doc-module)

(geiser-mode--triple-chord ?e ?m 'geiser-edit-module)

(define-key geiser-mode-map "\C-c\C-t" 'geiser-trace-procedure)
(define-key geiser-mode-map "\C-c\C-x" 'geiser-expand-current-form)


(provide 'geiser-mode)
;;; geiser-mode.el ends here