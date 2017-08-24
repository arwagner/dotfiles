(setq make-backup-files nil)

(setq-default indent-tabs-mode nil)
(setq tab-width 2)
(electric-indent-mode -1)

(menu-bar-mode -1)
(global-linum-mode 1)
(setq linum-format "%4d \u2502 ")

(setq ring-bell-function 'ignore)

(setq inhibit-startup-message t)
(setq initial-scratch-message "")

(ido-mode t)
(setq ido-enable-flex_matching t)
(global-set-key (kbd "M-/") 'hippie-expand)
(global-set-key (kbd "C-s") 'isearch-forward-regexp)
(global-set-key (kbd "C-r") 'isearch-backward-regexp)

(add-to-list 'load-path "~/dotfiles/emacs/")
(add-to-list 'load-path "~/dotfiles/emacs/async")

(add-to-list 'auto-mode-alist '("\\.js\\.erb\\'" . javascript-model))
(add-to-list 'auto-mode-alist '("\\.ts" . javascript-mode))
(add-to-list 'auto-mode-alist '("\\.scss" . css-mode))
