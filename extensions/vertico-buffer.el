;;; vertico-buffer.el --- Display Vertico in a buffer instead of the minibuffer -*- lexical-binding: t -*-

;; Copyright (C) 2021  Free Software Foundation, Inc.

;; Author: Daniel Mendler <mail@daniel-mendler.de>
;; Maintainer: Daniel Mendler <mail@daniel-mendler.de>
;; Created: 2021
;; Version: 0.1
;; Package-Requires: ((emacs "27.1"))
;; Homepage: https://github.com/minad/vertico

;; This file is part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package is a Vertico extension, which allows to display Vertico
;; in a buffer instead of the minibuffer. The buffer display can be enabled
;; by the `vertico-buffer-mode'.

;;; Code:

(require 'vertico)

(defvar-local vertico-buffer--overlay nil)
(defvar-local vertico-buffer--buffer nil)

(defvar vertico-buffer-action
  `(display-buffer-in-side-window
    (window-height . ,(+ 3 vertico-count))
    (side . top)
    (slot . -1))
  "Display action for the Vertico buffer.")

(defun vertico-buffer--display (lines)
  "Display LINES in buffer."
  (move-overlay vertico-buffer--overlay (point-min) (point-max))
  (let ((count (vertico--format-count))
        (prompt (minibuffer-prompt))
        (content (minibuffer-contents)))
    (with-current-buffer vertico-buffer--buffer
      (erase-buffer)
      (insert (propertize (concat count prompt) 'face 'minibuffer-prompt)
              content "\n" (string-join lines)))
    (let ((win (or (get-buffer-window vertico-buffer--buffer)
                   (display-buffer vertico-buffer--buffer vertico-buffer-action)))
          (pt (point)))
      (overlay-put vertico--candidates-ov 'window win)
      (when vertico--count-ov
        (overlay-put vertico--count-ov 'window win))
      (with-selected-window win
        (goto-char (max (+ (point-min) (length prompt) (length count))
                        (+ pt (length count))))))))

(defun vertico-buffer--select (_)
  "Ensure that cursor is only shown if minibuffer is selected."
  (with-current-buffer (buffer-local-value 'vertico-buffer--buffer
                                           (window-buffer (active-minibuffer-window)))
    (if (eq (selected-window) (active-minibuffer-window))
        (setq-local cursor-in-non-selected-windows 'box)
      (setq-local cursor-in-non-selected-windows nil)
      (goto-char (point-min)))))

(defun vertico-buffer--destroy ()
  "Destroy Vertico buffer."
  (kill-buffer vertico-buffer--buffer))

(defun vertico-buffer--setup ()
  "Setup minibuffer overlay, which pushes the minibuffer content down."
  (add-hook 'window-selection-change-functions 'vertico-buffer--select nil 'local)
  (add-hook 'minibuffer-exit-hook 'vertico-buffer--destroy nil 'local)
  (setq-local cursor-type '(bar . 0))
  (setq vertico-buffer--overlay (make-overlay (point-max) (point-max)))
  (overlay-put vertico-buffer--overlay 'window (selected-window))
  (overlay-put vertico-buffer--overlay 'priority 1000)
  (overlay-put vertico-buffer--overlay 'invisible t)
  (setq vertico-buffer--buffer (get-buffer-create
                                (if (= 1 (recursion-depth))
                                    " *Vertico*"
                                  (format " *Vertico-%s*" (1- (recursion-depth))))))
  (with-current-buffer vertico-buffer--buffer
    (add-hook 'window-selection-change-functions 'vertico-buffer--select nil 'local)
    (setq-local display-line-numbers nil
                truncate-lines t
                show-trailing-whitespace nil
                inhibit-modification-hooks t
                cursor-in-non-selected-windows 'box)))

;;;###autoload
(define-minor-mode vertico-buffer-mode
  "Display Vertico in a buffer instead of the minibuffer."
  :global t
  (cond
   (vertico-buffer-mode
    (advice-add #'vertico--display-candidates :override #'vertico-buffer--display)
    (advice-add #'vertico--setup :after #'vertico-buffer--setup))
   (t
    (advice-remove #'vertico--display-candidates #'vertico-buffer--display)
    (advice-remove #'vertico--setup #'vertico-buffer--setup))))

(provide 'vertico-buffer)
;;; vertico-buffer.el ends here