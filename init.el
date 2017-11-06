(package-initialize)

(progn "Stuff that needs to be performed immediately, for a visually pleasant startup"

  (setq inhibit-startup-message t)
  (setq-default line-spacing 1) ;; NOTE: might mess up the echo area
  
  (when t
    (setq inhibit-message t) ;; Silence minibuffer
    (setq debug-on-error nil)
    (setq debugger (lambda (&rest _))) ;; Disable annoying *Backtrace* buffer
    (setq command-error-function (lambda (&rest _))) ;; Silence "End of buffer" messages
    (defun minibuffer-message (&rest _))) ;; Silence "No matching parenthesis found"
  
  (if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
  (if (fboundp 'tool-bar-mode) (tool-bar-mode -1))
  (if (fboundp 'menu-bar-mode) (menu-bar-mode -1)))

(let ((default-directory "~/.emacs.d/lib"))
      (normal-top-level-add-subdirs-to-load-path))

(when (eq system-type 'darwin)
  (setq mac-control-modifier 'super)
  (setq mac-option-modifier 'meta)
  (setq mac-command-modifier 'control))

(setq vemv-font (if (eq system-type 'darwin) "Monaco-12" "DejaVu Sans Mono-13"))

(if (window-system) (set-face-attribute 'default nil :font vemv-font))

(require 'vemv.project)
(require 'vemv.init)

(when (file-exists-p "~/.emacs.d.overrides/")
  (let ((default-directory "~/.emacs.d.overrides/"))
        (normal-top-level-add-subdirs-to-load-path))
  (require 'emacs.d.overrides))
