;; xref.scm -- cross-referencing utilities

;; Copyright (C) 2009 Jose Antonio Ortega Ruiz

;; Author: Jose Antonio Ortega Ruiz <jao@gnu.org>
;; Start date: Mon Mar 02, 2009 02:37

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

;; Procedures to locate symbols and their xrefs.

;;; Code:

(define-module (geiser xref)
  #:export (symbol-location
            generic-methods)
  #:use-module (geiser utils)
  #:use-module (geiser modules)
  #:use-module (geiser doc)
  #:use-module (oop goops)
  #:use-module (system vm program))

(define (symbol-location sym)
  (cond ((symbol-module sym) => module-location)
        (else '())))

(define (generic-methods sym)
  (let* ((gen (symbol->object sym))
         (methods (if (is-a? gen <generic>) (generic-function-methods gen) '())))
    (filter (lambda (x) (not (null? x)))
            (map (lambda (m) (describe-method sym m)) methods))))

(define (describe-method name m)
  (let ((proc (method-procedure m)))
    (if proc
        `((location . ,(program-location proc))
          (signature . ,(object-signature name proc)))
        '())))

(define (program-location p)
  (cond ((program-source p 0) =>
         (lambda (s) (make-location (program-path p) (source:line s))))
        ((program-path p) =>
         (lambda (s) (make-location (program-path p) #f)))
        (else '())))

(define (program-path p)
  (let* ((mod (program-module p))
         (name (and mod (module-name mod))))
    (and name (module-filename name))))

;;; xref.scm ends here