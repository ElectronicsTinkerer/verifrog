;;; vfl-mode.el --- sample major mode for editing VeriFrog. -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright © 2022, by Zach Baldwin

;; Author: Zach Baldwin
;; Version: 0.0.1
;; Created: 23 Oct 2022
;; Keywords: languages
;; Homepage: https://github.com/ElectronicsTinkerer/Verifrog

;; This file is not part of GNU Emacs.

;;; License:

;; You can redistribute this program and/or modify it under the terms of the GNU General Public License version 2.

;;; Commentary:

;; This file based on a tutorial by Xah Lee
;; URL: http://xahlee.info/emacs/emacs/elisp_syntax_coloring.html
;;
;; Installation:
;; 1) Place this file (vfl-mode.el) into a directory on your load-path in you EMACS config
;; 2) Add the following line to your EMACS startup file:
;;    (require 'vfl-mode)
;; 3) Reload your EMACS config

;;; Code:

;; create the list for font-lock.
;; each category of keyword is given a particular face
(setq vfl-font-lock-keywords
      (let* (
            ;; define several category of keywords
            (x-keywords '("tick" "drain" "alias"))
            (x-types '("input" "output"))
            ;; (x-constants '("ACTIVE" "AGENT" "ALL_SIDES" "ATTACH_BACK"))
            (x-events '("@"))
            (x-functions '("always" "expect" "set"))

            ;; generate regex string for each category of keywords
            (x-keywords-regexp (regexp-opt x-keywords 'words))
            (x-types-regexp (regexp-opt x-types 'words))
            ;; (x-constants-regexp (regexp-opt x-constants 'words))
            (x-events-regexp (regexp-opt x-events 'words))
            (x-functions-regexp (regexp-opt x-functions 'words)))

        `(
          (,x-types-regexp . 'font-lock-type-face)
          ;; (,x-constants-regexp . 'font-lock-constant-face)
          (,x-events-regexp . 'font-lock-builtin-face)
          (,x-functions-regexp . 'font-lock-function-name-face)
          (,x-keywords-regexp . 'font-lock-keyword-face)
          ;; note: order above matters, because once colored, that part won't change.
          ;; in general, put longer words first
          )))

;;;###autoload
(define-derived-mode vfl-mode c-mode "vfl mode"
  "Major mode for editing VFL (VeriFrog test bench description Language)…"

  ;; code for syntax highlighting
  (setq font-lock-defaults '((vfl-font-lock-keywords))))

;; add the mode to the `features' list
(provide 'vfl-mode)

;; add .vfl to vfl style
(add-to-list 'auto-mode-alist '("\\.vfl\\'" . vfl-mode))

;;; vfl-mode.el ends here
