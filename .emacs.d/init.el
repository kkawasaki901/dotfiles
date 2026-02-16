;; for debug stdout
(message "init start")
;;; init.el --- minimal usable Emacs config (Org + which-key + treemacs)
;;; -*- lexical-binding: t; -*-
(setq warning-minimum-level :error)

(setq which-key-popup-type 'side-window)
(setq which-key-side-window-location 'bottom)
(setq which-key-side-window-max-height 0.4)

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(which-key-command-description-face ((t (:height 1.2))))
 '(which-key-group-description-face ((t (:height 1.2))))
 '(which-key-key-face ((t (:height 1.3 :weight bold)))))



;; Minibuffer / Echo area を大きくする（GUI確実版）
(defun my/minibuffer-font-setup ()
  (face-remap-add-relative 'default :height 140))

(add-hook 'minibuffer-setup-hook #'my/minibuffer-font-setup)

(set-face-attribute 'minibuffer-prompt nil
                    :height 140
                    :weight 'bold)

(set-face-attribute 'default nil :height 130)

;; UTF-8 を全面使用
(set-language-environment "Japanese")
(prefer-coding-system 'utf-8-unix)
(set-default-coding-systems 'utf-8-unix)
(set-terminal-coding-system 'utf-8-unix)
(set-keyboard-coding-system 'utf-8-unix)
;; -----------------------------
;; Basic UI / behavior
;; -----------------------------
(setq inhibit-startup-message t
      ring-bell-function 'ignore
      make-backup-files nil
      auto-save-default nil
      create-lockfiles nil)

;; Smooth-ish / responsiveness (lightweight tuning)
(setq gc-cons-threshold (* 100 1024 1024) ;; 100MB
      read-process-output-max (* 1024 1024)) ;; 1MB

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)))) ;; back to 16MB

;; UI
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode 1)
(column-number-mode 1)

;; Prefer y/n
(fset 'yes-or-no-p 'y-or-n-p)

;; -----------------------------
;; Package setup (package.el)
;; -----------------------------
(require 'package)
(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("melpa" . "https://melpa.org/packages/")))

(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

(defun my/ensure-package (pkg)
  "Install PKG if not installed."
  (unless (package-installed-p pkg)
    (package-install pkg)))

;; Install plugins you requested
(my/ensure-package 'which-key)
(my/ensure-package 'treemacs)

;; -----------------------------
;; which-key
;; -----------------------------
(require 'which-key)
(which-key-mode 1)
(setq which-key-idle-delay 0.5
      which-key-idle-secondary-delay 0.05)

;; -----------------------------
;; treemacs
;; -----------------------------
(require 'treemacs)
;; Sensible defaults
(setq treemacs-is-never-other-window t
      treemacs-width 32)

;; Toggle treemacs
(global-set-key (kbd "<f8>") #'treemacs)

(with-eval-after-load 'treemacs
  (setq treemacs-sorting 'alphabetic-desc))
;; -----------------------------
;; Install evil
;; -----------------------------
(my/ensure-package 'evil)

;; Evil must be loaded before using evil hooks / commands
(require 'evil)
(evil-mode 1)
;; -----------------------------
;; Org (built-in) + conventional keybindings
;; -----------------------------
;; IMPORTANT: Use built-in org (do not install org from ELPA for this config)
(require 'org)

;; Make sure org-agenda and org-capture are available
(require 'org-agenda)
(require 'org-capture)

;; ---- Global Org keys (the conventional ones) ----
;; These are the "everyone expects them" bindings.
(global-set-key (kbd "C-c a") #'org-agenda)       ;; agenda dispatcher
(global-set-key (kbd "C-c c") #'org-capture)      ;; capture

(global-set-key (kbd "C-^")
                (lambda ()
                  (interactive)
                  (org-capture nil "j")))

(global-set-key (kbd "C-\\")
                (lambda ()
                  (interactive)
                  (org-capture nil "n")))

(global-set-key (kbd "C-c l") #'org-store-link)   ;; store link

;; Optional but common (uncomment if you want)
;; (global-set-key (kbd "C-c b") #'org-switchb)   ;; switch org buffer

;; ---- Basic org settings (minimal) ----
(setq org-directory (expand-file-name "~/org/")
      org-default-notes-file (expand-file-name "inbox.org" org-directory)
      org-agenda-files (list org-directory)
      org-log-done 'time
      org-hide-emphasis-markers t
      org-startup-indented t)

(setq org-directory (expand-file-name "~/org/"))

(defvar my/org-agenda-dir (expand-file-name "agenda/" org-directory))
(defvar my/org-daily-dir  (expand-file-name "daily/"  org-directory))
(defvar my/org-projects-dir (expand-file-name "projects/" org-directory))

(defun my/org-files-recursive-excluding-closed (dir)
  ;; "Return all .org files under DIR, excluding any 'closed' directory."
  (directory-files-recursively
   dir
   "\\.org\\'"
   nil
   (lambda (subdir)
     (not (string-match-p "/closed\\'" subdir)))))
(setq org-agenda-files
      (append
       (directory-files-recursively my/org-agenda-dir "\\.org\\'")
       (directory-files-recursively my/org-daily-dir  "\\.org\\'")
       (my/org-files-recursive-excluding-closed my/org-projects-dir)))


;; Capture templates (minimal)
(setq org-capture-templates
      '(("t" "Todo" entry
         (file+olp+datetree "~/org/todo.org")
          "* TODO %?\n  CREATED: %U\n")
        ("n" "Note" entry
         (file+headline org-default-notes-file "Inbox")
          "* %?\n  %U\n  ")
        ("j" "Journal" entry
         (file+olp+datetree "~/org/journal.org")
         "* %<%H:%M> %?\n")))

;; ---- Org-mode key behavior (the usual) ----
;; Org already defines most keys in org-mode-map.
;; We only add a couple of very common extras for convenience.

(with-eval-after-load 'org
  ;; Return makes a new heading item behavior feel nicer
  (setq org-M-RET-may-split-line nil))

;; -----------------------------
;; Helpful discovery (optional)
;; -----------------------------
;; Show key bindings for commands
(global-set-key (kbd "C-h B") #'describe-bindings)


(with-eval-after-load 'org
  ;; Date/time stamps
  (define-key org-mode-map (kbd "C-c .") #'org-time-stamp)
  (define-key org-mode-map (kbd "C-c !") #'org-time-stamp-inactive)
  (define-key org-mode-map (kbd "C-c ,") #'org-priority)

  ;; Scheduling / deadlines / todo
  (define-key org-mode-map (kbd "C-c C-s") #'org-schedule)
  (define-key org-mode-map (kbd "C-c C-d") #'org-deadline)
  (define-key org-mode-map (kbd "C-c C-t") #'org-todo)

  ;; Links / export
  (define-key org-mode-map (kbd "C-c C-l") #'org-insert-link)
  (define-key org-mode-map (kbd "C-c C-o") #'org-open-at-point)
  (define-key org-mode-map (kbd "C-c C-e") #'org-export-dispatch)

  ;; If you use habits
  (require 'org-habit))

;; Optional: Make sure .org files always open in org-mode
(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode))

;; ----------------------------------------
;; Open (almost) everything in org-mode
;; ----------------------------------------

(require 'org)

;; 1) Make Org the default major mode for new buffers (no file / unknown)
(setq-default major-mode 'org-mode)

;; 2) Prefer org-mode for files that don't match a more specific rule
;;    (Catch-all: any filename that has an extension or even none)
(add-to-list 'auto-mode-alist '(".*" . org-mode))

;; 3) But do NOT force org-mode for some special / binary-ish things
;;    (so you don't break Emacs internals)
(add-to-list 'auto-mode-alist '("\\.\\(png\\|jpe?g\\|gif\\|pdf\\|zip\\|gz\\|xz\\|tar\\|exe\\|dll\\|so\\|o\\)\\'" . fundamental-mode))

;; 4) Also keep these as-is (optional safety)
(add-to-list 'auto-mode-alist '("\\.el\\'"  . emacs-lisp-mode))
(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode)) ;; explicit


;; -----------------------------
;; Daily note (no plugin) - robust
;; -----------------------------
(require 'org)

(setq org-directory (expand-file-name "~/org/"))

(defvar my/org-daily-directory
  (expand-file-name "daily/" org-directory)
  "Directory for daily notes.")

(defun my/org-daily--file-for (date)
  (expand-file-name (concat date ".org") my/org-daily-directory))

(defun my/org-daily-today ()
  "Open today's daily note. Create it if missing."
  (interactive)
  (let* ((today (format-time-string "%Y-%m-%d"))
         (file (my/org-daily--file-for today)))
    (unless (file-directory-p my/org-daily-directory)
      (make-directory my/org-daily-directory t))
    (find-file file)
    (when (= (buffer-size) 0)
      (insert "#+TITLE: " today "\n\n"
              ))))


;; Make C-c d available everywhere (even in *scratch*)
(define-key mode-specific-map (kbd "d") #'my/org-daily-today)
;; ----------------------------------------
;; Calendar -> Daily note (no plugin)
;; ----------------------------------------

(defun my/org-daily-open-date (date)
  "Open daily note for DATE string YYYY-MM-DD."
  (interactive)
  (let ((file (my/org-daily--file-for date)))
    (unless (file-directory-p my/org-daily-directory)
      (make-directory my/org-daily-directory t))
    (find-file file)
    (when (= (buffer-size) 0)
      (insert "#+TITLE: " date "\n\n"
              ))))

(defun my/org-daily-open-from-calendar ()
  "Open the daily note for the date at point in calendar."
  (interactive)
  (let* ((d (calendar-cursor-to-date))      ;; (month day year)
         (m (nth 0 d))
         (day (nth 1 d))
         (y (nth 2 d))
         (date (format "%04d-%02d-%02d" y m day)))
    (my/org-daily-open-date date)))

(with-eval-after-load 'calendar
  (define-key calendar-mode-map (kbd "d") #'my/org-daily-open-from-calendar)
  (define-key calendar-mode-map (kbd "RET") #'my/org-daily-open-from-calendar))
(global-set-key (kbd "C-c C") #'calendar)

;; fzfっぽい対話補完（内蔵）
(fido-vertical-mode 1)   ;; もし無ければ (fido-mode 1) にしてOK
(setq completion-styles '(basic partial-completion substring))

(fido-mode 1)


(setq org-refile-use-outline-path 'file
      org-outline-path-complete-in-steps nil)

(setq org-refile-targets
      '((org-agenda-files :maxlevel . 3)))

(my/ensure-package 'doom-themes)
(require 'doom-themes)
(load-theme 'doom-one t)

(my/ensure-package 'doom-modeline)
(require 'doom-modeline)
(doom-modeline-mode 1)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-agenda-files
   '("c:/Users/kawasaki/org/daily/2026-02-11.org"
     "c:/Users/kawasaki/org/agenda/refile/notes.org"
     "c:/Users/kawasaki/org/agenda/refile/refile.org"
     "c:/Users/kawasaki/org/agenda/future.org"
     "c:/Users/kawasaki/org/agenda/now.org"
     "c:/Users/kawasaki/org/agenda/someday.org"
     "c:/Users/kawasaki/org/agenda/todo.org"
     "c:/Users/kawasaki/org/daily/2026-02-10.org"
     "c:/Users/kawasaki/org/daily/2026-02-12.org"))
 '(package-selected-packages nil))


;; ----------------------------------------
;; Simple Dashboard (no plugin) - fixed keys
;; ----------------------------------------
(require 'recentf)
(recentf-mode 1)
(setq recentf-max-saved-items 50)

(defvar my/dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "a") #'org-agenda)
    (define-key map (kbd "c") #'org-capture)
    (define-key map (kbd "d") #'my/org-daily-today)
    (define-key map (kbd "t") #'treemacs)
    (define-key map (kbd "r") #'recentf-open-files)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for my dashboard.")

(define-derived-mode my/dashboard-mode special-mode "Dashboard"
  "Dashboard mode."
  (setq-local cursor-type nil)
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t))

(defun my/dashboard--insert-button (label fn &optional help)
  (insert-text-button
   label
   'action (lambda (_btn) (when (fboundp fn) (call-interactively fn)))
   'follow-link t
   'help-echo (or help (format "%s" fn)))
  (insert "\n"))

(defun my/dashboard--insert-file-button (path)
  (let ((label (file-name-nondirectory path)))
    (insert-text-button
     (format "  %s" label)
     'action (lambda (_btn) (find-file path))
     'follow-link t
     'help-echo path)
    (insert "\n")))
(defun my/open-dashboard ()
  (interactive)
  (let ((buf (get-buffer-create "*dashboard*")))
    (with-current-buffer buf
      (my/dashboard-mode) ;; special-mode系でread-onlyになる
      (let ((inhibit-read-only t))  ;; ← これが重要
        (erase-buffer)

        (insert "\n")
        (insert (propertize "  Emacs Dashboard\n" 'face '(:height 1.6 :weight bold)))
        (insert (propertize "  ----------------\n\n" 'face '(:inherit shadow)))

        (my/dashboard--insert-button "  [a] Org Agenda" #'org-agenda)
        (my/dashboard--insert-button "  [c] Org Capture" #'org-capture)
        (when (fboundp 'my/org-daily-today)
          (my/dashboard--insert-button "  [d] Daily Note (today)" #'my/org-daily-today))
        (when (fboundp 'treemacs)
          (my/dashboard--insert-button "  [t] Treemacs" #'treemacs))
        (my/dashboard--insert-button "  [r] Recent Files" #'recentf-open-files)

        (insert "\n")
        (insert (propertize "  Recent files\n" 'face '(:weight bold)))
        (insert (propertize "  -----------\n" 'face '(:inherit shadow)))

        (dolist (f (seq-take recentf-list 10))
          (when (file-exists-p f)
            (my/dashboard--insert-file-button f)))

        (insert "\n")
        (insert (propertize "  Keys: a/c/d/t/r   (q to quit)\n" 'face '(:inherit shadow)))

        (goto-char (point-min))))
    (switch-to-buffer buf)))


(add-hook 'emacs-startup-hook #'my/open-dashboard)
(global-set-key (kbd "C-c SPC") #'my/open-dashboard)


;; ----------------------------------------
;; "Search everything" setup (consult stack)
;; ----------------------------------------

;; Packages
(my/ensure-package 'vertico)
(my/ensure-package 'orderless)
(my/ensure-package 'marginalia)
(my/ensure-package 'consult)

;; 1) Minibuffer UI
(require 'vertico)
(vertico-mode 1)

;; 2) Better matching (fzf-like)
(require 'orderless)
(setq completion-styles '(orderless basic)
      completion-category-defaults nil
      completion-category-overrides '((file (styles basic partial-completion))))

;; 3) Rich annotations
(require 'marginalia)
(marginalia-mode 1)

;; 4) History
(require 'savehist)
(savehist-mode 1)

;; 5) Consult
(require 'consult)

;; --- Keybindings: replace common "search/navigation" with consult ---
;; M-x を強化（コマンド検索）
(global-set-key (kbd "M-x") #'execute-extended-command) ; そのままでもvertico+orderlessで強化される

;; バッファ切り替え（めちゃ便利）
(global-set-key (kbd "C-x b") #'consult-buffer)

;; 行検索（現在バッファ内）: isearch(C-s)の代替
(global-set-key (kbd "C-s") #'consult-line)

;; 文字列検索（プロジェクト/ディレクトリ）: ripgrep
(global-set-key (kbd "C-c s") #'consult-ripgrep)

;; 見出しジャンプ（imenu）: org見出し/関数など
(global-set-key (kbd "C-c i") #'consult-imenu)

;; 最近開いたファイル
(global-set-key (kbd "C-c f") #'consult-recent-file)

;; 履歴参照（ミニバッファ履歴）
(global-set-key (kbd "M-y") #'consult-yank-pop)


(setq completion-styles '(orderless basic)
      completion-category-defaults nil
      completion-category-overrides
      '((command (styles orderless))
        (file (styles basic partial-completion))))


 ;;package 初期化（未設定なら）
;;(require 'package)
;;(add-to-list 'package-archives
             ;;'("melpa" . "https://melpa.org/packages/") t)
;;(package-initialize)
;;
;;;; evil インストール
;;(unless (package-installed-p 'evil)
  ;;(package-refresh-contents)
  ;;(package-install 'evil))

;;(require 'evil)
;;(evil-mode 1)


;;(add-hook 'after-init-hook #'viper-mode)


(global-set-key (kbd "<f7>") #'evil-mode)


(defun my/toggle-evil ()
  (interactive)
  (if (require 'evil nil t)
      (progn
        (evil-mode 'toggle)
        (message (if evil-mode "〇 Evil ON" "× Evil OFF")))
    (message "evil is not installed")))
(global-set-key (kbd "<f7>") #'my/toggle-evil)

;; IME ON
(defun my/ime-on ()
  (interactive)
  (when (fboundp 'w32-set-ime-open-status)
    (w32-set-ime-open-status t)))

;; IME OFF
(defun my/ime-off ()
  (interactive)
  (when (fboundp 'w32-set-ime-open-status)
    (w32-set-ime-open-status nil)))

;; Insert に入ったら ON
(add-hook 'evil-insert-state-entry-hook #'my/ime-on)

;; Insert から抜けたら OFF
(add-hook 'evil-insert-state-exit-hook #'my/ime-off)
