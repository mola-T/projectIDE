;;; projectIDE-header.el --- projectIDE header file
;;
;; Copyright (C) 2015-2016 Mola-T
;; Author: Mola-T <Mola@molamola.xyz>
;; URL: https://github.com/mola-T/projectIDE
;; Version: 1.0
;; Package-Requires: ((cl-lib.el "0.5") (fdex.el "1.0"))
;; Keywords: project, convenience
;;
;;; License:
;; This file is NOT part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.
;;
;;; Commentary:
;;
;; This files provides variables and funtions supporting all projectIDE-X.el
;;
;;; code:

(require 'cl-lib)
(require 'fdex)





















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;; General function
;;fff (defun projectIDE-concat-regexp (list))
;;fff (defun projectIDE-trim-string (string))
;;fff (defun projectIDE-add-to-list (list element))
;;fff (defun projectIDE-append (list1 list2))
;;fff (defun projectIDE-manipulate-filter (projectRoot list))
;;fff (defun projectIDE-prompt (prompt choices &optional initial-input))

(defun projectIDE-concat-regexp (list)
  
  "Return a single regexp string from a LIST of separated regexp.

Return
Type:\t\t string
Descrip.:\t A single string of combined regexp.
\t\t\t If LIST is empty, return nil.

LIST
Type:\t\t string list
Descrip.:\t A string list of regexp."
  
  (let (regexp)
    (dolist (val (reverse list) regexp)
      (setq regexp
            (concat val (and regexp (concat "\\|" regexp)))))))



(defun projectIDE-trim-string (string)
  
  "Return trimmed leading and tailing whitespace from STRING.
If the return string is a null string, return nil instead.

Return
Type:\t\t string or nil
Descrip.:\t Trimmed string or nil if blank string.

STRING
Type:\t\t string
Descrip.:\t String to be trimmed."
  
  (let ((return-string (string-trim string)))
    (if (string= return-string "")
        nil
      return-string)))



(cl-defun projectIDE-add-to-list (list element &key test)
  
  "Adds ELEMENT to LIST if it isn't there yet.
Place ELEMENT to the first of the list if it is already in the list.
It handles all situation when LIST or ELEMENT is nil.
This function does not modify the original list.
Instead, it returns a new list.
In addition, it accepts non-symbol LIST.

Key TEST can be provided to test for equal.
It is default `equal'.

This function is expensive in term of efficency.
Avoid to use in heavy loop.

Return
Type:\t\t list
Descrip.:\t New list with ELEMENT add to LIST

LIST
Type:\t\t list of any type
Descrip.:\t List to be checked and appended to.

ELEMENT
Type:\t\t same type of LIST element
Descrip.:\t Add to LIST if ELEMENT isn't there yet."
  
  (let ((newlist (copy-tree list)))
    (if newlist
        (when element
          (setq newlist (cl-remove element newlist :test (or test 'equal)))
          (setq newlist (nconc (list element) newlist)))
      (when element
        (setq newlist (list element))))
    newlist))



(cl-defun projectIDE-append (list1 list2 &key test)
  
  "Return a combined list of LIST1 and LIST2 and prevent duplication.
It accepts non-symbol LIST.

Key TEST can be provided to test for equal.
It is default `equal'.

This function is expensive in term of efficency.
Avoid to use in heavy loop.

Return
Type:\t\t list
Descrip.:\t Combined list of LIST1 and LIST2.

LIST1/LIST2
Type:\t list of any type
Descrip.:\t List to be combined."
  
  (let (newlist)
    (setq newlist (append list1 list2))
    (cl-remove-duplicates newlist :test (or test 'equal))))



(defun projectIDE-manipulate-filter (projectRoot list)
  
  "This function add the PROJECTROOT as a prefix to each entry in the LIST.
It also ajusts the regexp in the list so that
1) \"*\" is converted to \".*\" to provide wildcard function
2) \".\" is converted to \"\\.\" to prevent misuse of regexp in file extension
3) string end \"\\'\" is added to each list item
This function return a manipulated LIST.

Return
Type:\t\t string list
Descrip.:\t A string list with each item prefixed with PROJECTROOT.

PROJECTROOT
Type:\t\t string
Descrip.:\t A string of path.

LIST
Type:\t\t string list
Descip.:\t A string list which each entry is to be prefixed."

  (let (return)
    (dolist (entry list)
      (setq return (projectIDE-add-to-list return
                                           (concat projectRoot
                                                   (replace-regexp-in-string "\\*" ".*"
                                                                             (replace-regexp-in-string "\\." "\\\\." entry))
                                                   "\\'"))))
    (projectIDE-concat-regexp return)))



(defun projectIDE-prompt (prompt choices &optional initial-input)
  
  "Create a PROMPT to choose from CHOICES which is a list.
Return the selected result.

Return
Type:\t\t type of the CHOICES list
Descrip.:\t Return the user choice.

PROMPT
Type:\t\t string
Descrip.: Prompt message.

CHOICES
Type:\t\t list of any type
Descrip.: A list of choices to let user choose.

INITIAL-INPUT
Type:\t\t string
Descrip.:\t Initial input for the prompt."
  
  (cond
     ;; ido
     ((eq projectIDE-completion-system 'ido)
      (ido-completing-read prompt choices nil nil initial-input))
     ;; helm
     ((eq projectIDE-completion-system 'helm)
      (if (fboundp 'helm-comp-read)
          (helm-comp-read prompt choices
                          :initial-input initial-input
                          :candidates-in-buffer t
                          :must-match 'confirm)
        (projectIDE-message-handle 'Warning
                                   "Problem implementing helm completion. Please check `projectIDE-completion-system'.
                                    projectIDE will use default completion instead."
                                   t
                                   (projectIDE-caller 'projectIDE-prompt))
        (completing-read prompt choices nil nil initial-input)))
     ;; grizzl
     ((eq projectIDE-completion-system 'grizzl)
      (if (and (fboundp 'grizzl-completing-read)
               (fboundp 'grizzl-make-index))
          (grizzl-completing-read prompt (grizzl-make-index choices))
        (projectIDE-message-handle 'Warning
                                   "Problem implementing grizzl completion. Please check `projectIDE-completion-system'.
                                    projectIDE will use default completion instead."
                                   t
                                   (projectIDE-caller 'projectIDE-prompt))
        (completing-read prompt choices nil nil initial-input)))
     ;; ivy
     ((eq projectIDE-completion-system 'ivy)
      (if (fboundp 'ivy-completing-read)
          (ivy-completing-read prompt choices nil nil initial-input)
        (projectIDE-message-handle 'Warning
                                   "Problem implementing ivy completion. Please check `projectIDE-completion-system'.
                                    projectIDE will use default completion instead."
                                   t
                                   (projectIDE-caller 'projectIDE-prompt))
        (completing-read prompt choices nil nil initial-input)))
     ;; default
     (t (completing-read prompt choices nil nil initial-input))))

;; General function ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;; projectIDE modes

(defvar projectIDE-config-font-lock-keywords
  
  '(("^#+.*$" . font-lock-comment-face)
    ("\\(^signature\\)\\( *= *\\)\\(.*$\\)"
     (1 'font-lock-function-name-face)
     (3 'font-lock-warning-face))
    ("^name\\|^cachemode" . font-lock-function-name-face)
    ("^exclude\\|^whitelist\\|^module" . font-lock-builtin-face)
    ("^scope" . font-lock-type-face)
    ("=" . font-lock-keyword-face)
    ("\\(^[[:digit:][:alpha:]]+.*\\)="
     (1 'font-lock-variable-name-face)))
  
   "Keyword highlighting specification for `projectIDE-config-mode-hook'.")



(define-derived-mode projectIDE-config-mode nil "projectIDE-config"
  
  "Major mode for editing \".projectIDE\" project config.
Turning on Text mode runs the normal hook `projectIDE-config-mode-hook'."
  
  (setq-local font-lock-defaults
              '(projectIDE-config-font-lock-keywords))
  (add-hook 'after-save-hook 'projectIDE-verify-config nil t))



(defvar projectIDE-keymap (make-sparse-keymap)
  "The project specific keymap for projectIDE mode.")



(define-minor-mode projectIDE-mode
  "projectIDE mode for project specific keymap."
  :lighter " projectIDE"
  :global t
  :keymap projectIDE-keymap)



(defun projectIDE-set-key (key command)
  
  "Give KEY a project specific binding as COMMAND.
COMMAND is the command definition to use; usually it is
a symbol naming an interactively-callable function.
KEY is a key sequence; noninteractively, it is a string or vector
of characters or event types, and non-ASCII characters with codes
above 127 (such as ISO Latin-1) can be included if you use a vector.

Note that KEY won't take into effect until
its modules has been activated."
  
  (or (vectorp key) (stringp key)
      (signal 'wrong-type-argument (list 'arrayp key)))
  (setq projectIDE-key-table (plist-put projectIDE-key-table command key)))

;;; projectIDE modes ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;; projectIDE group

(defgroup projectIDE nil
  "Managing projects like an IDE."
  :tag "projectIDE"
  :group 'tools
  :group 'convenience)

(defgroup projectIDE-global nil
  "Global setting for all projects."
  :tag "Enviroment Values"
  :group 'projectIDE)

(defgroup projectIDE-window nil
  "Buffer window setting for all projectIDE."
  :tag "Buffer window setting"
  :group 'projectIDE)

(defgroup projectIDE-config-file nil
  "Setting for loading individual project config file."
  :tag "Config file settings"
  :group 'projectIDE)

(defgroup projectIDE-project-creation nil
  "Setting for creating project."
  :tag "Project creation"
  :group 'projectIDE)

(defgroup projectIDE-opening nil
  "Setting for opening project or files behaviour."
  :tag "Project opening"
  :group 'projectIDE)

(defgroup projectIDE-caching nil
  "Setting for project caching."
  :tag "Project caching"
  :group 'projectIDE)

(defgroup projectIDE-module nil
  "Setting for project module."
  :tag "Project module"
  :group 'projectIDE)

(defgroup projectIDE-hook nil
  "All available projectIDE hooks."
  :tag "Hook"
  :group 'projectIDE)

;;; projectIDE group ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Environmental Variable
;;vvv (defcustom projectIDE-database-path)
;;vvv (defconst PROJECTIDE-PROJECTROOT-IDENTIFIER)
;;vvv (defconst PROJECTIDE-RECORD-FILE)
;;vvv (defconst PROJECTIDE-LOG-PATH)
;;vvv (defconst PROJECTIDE-CACHE-PATH)
;;vvv (defcustom projectIDE-completion-system)

(defcustom projectIDE-database-path
  (file-name-as-directory
   (concat (file-name-as-directory user-emacs-directory) "projectIDE"))
  "Path for storing projectIDE RECORD database."
  :tag "Main database path"
  :type 'directory
  :group 'projectIDE-global)

(defconst PROJECTIDE-PROJECTROOT-IDENTIFIER ".projectIDE"
  "The root file indicator.")

(defconst PROJECTIDE-RECORD-FILE
  (concat projectIDE-database-path "RECORD")
  "Filename for project record.")

(defconst PROJECTIDE-LOG-PATH
  (file-name-as-directory (concat projectIDE-database-path "LOG"))
  "Filename for projectIDE log file.")

(defconst PROJECTIDE-CACHE-PATH
  (file-name-as-directory (concat projectIDE-database-path "CACHE"))
  "Folder path to individual project record.")

(defcustom projectIDE-auto-initialize-p t
  "Auto initialize projectIDE when its functions are called?"
  :tag "Auto initialize projectIDE?"
  :type 'bool
  :group 'projectIDE-global)

(defcustom projectIDE-initialize-hook nil
  "Hook runs when projectIDE starts."
  :tag "projectIDE-initialize-hook"
  :type 'hook
  :group 'projectIDE-global
  :group 'projectIDE-hook)

(defcustom projectIDE-terminate-hook nil
  "Hook runs when projectIDE terminates."
  :tag "projectIDE-terminate-hook"
  :type 'hook
  :group 'projectIDE-global
  :group 'projectIDE-hook)

(defcustom projectIDE-completion-system
  (or (and (fboundp 'helm) 'helm)
      (and (fboundp 'ivy-completing-read) 'ivy)
      (and (fboundp 'ido-completing-read) 'ido)
      (and (fboundp 'grizzl-completing-read) 'grizzl)
      'default)
  "The completion system to be used by projectIDE."
  :type '(radio
          (const :tag "Ido" ido)
          (const :tag "Ivy" ivy)
          (const :tag "Grizzl" grizzl)
          (const :tag "Helm" helm)
          (const :tag "Default" default))
  :group 'projectIDE-global)

(defcustom projectIDE-enable-background-service t
  "Enable projectIDE background services like updating cache."
  :type 'bool
  :group 'projectIDE-global)

;; Environmental Variable ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Project config file variable
;;vvv (defconst projectIDE-default-config-key)
;;vvv (defconst projectIDE-CACHEMODE-open-project-update-cache)
;;vvv (defconst projectIDE-CACHEMODE-background-update-cache)
;;vvv (defconst projectIDE-CACHEMODE-update-cache-pre-prompt)
;;vvv (defconst projectIDE-CACHEMODE-update-cache-important-command)
;;vvv (defconst projectIDE-CACHEMODE-generate-association)
;;vvv (defcustom projectIDE-default-cachemode)
;;vvv (defcustom projectIDE-default-exclude)
;;vvv (defcustom projectIDE-default-whitelist)
;;vvv (defcustom projectIDE-config-file-search-up-level)


(defconst projectIDE-config-key
  '("^signature *="
    "^name *="
    "^exclude *="
    "^whitelist *="
    "^cachemode *="
    "^module *="
    "^scope *="
    "^[[:digit:][:alpha:]]+.*=")
  "Default projectIDE config file keyword.
Must not change.")

(defvar projectIDE-config-key-string
  (projectIDE-concat-regexp projectIDE-config-key)
  "Combine the projectIDE-default-exclude.")

(defconst projectIDE-CACHEMODE-open-project-update-cache 1
  "[00000001] Do a full update cache after first opening a project.")
(defconst projectIDE-CACHEMODE-background-update-cache 2
  "[00000010] Do background update cache from time to time
if project is opened.")
(defconst projectIDE-CACHEMODE-update-cache-pre-prompt 4
  "[00000100] Fully update cache before any promt.")
(defconst projectIDE-CACHEMODE-update-cache-important-command 8
  "[00001000] Fully update cache before important command like compile.")
(defconst projectIDE-CACHEMODE-generate-association 16
  "[00010000] Generate file association in background.
Should be turned off for large project.")

(defcustom projectIDE-default-cachemode
  (logior projectIDE-CACHEMODE-open-project-update-cache
          projectIDE-CACHEMODE-background-update-cache
          projectIDE-CACHEMODE-update-cache-pre-prompt
          projectIDE-CACHEMODE-update-cache-important-command
          projectIDE-CACHEMODE-generate-association)

  "Default cache mode for projects.
`projectIDE-CACHEMODE-open-project-update-cache' = 1
`projectIDE-CACHEMODE-background-update-cache' = 2
`projectIDE-CACHEMODE-update-cache-pre-prompt' = 4
`projectIDE-CACHEMODE-update-cache-important-command' = 8
`projectIDE-CACHEMODE-generate-association' = 16
A sum of these cache modes you want to enable."
  
  :tag "Default cache mode"
  :type 'integer
  :group 'projectIDE-config-file)

(defcustom projectIDE-default-exclude
  `(,(concat (file-name-as-directory "*.idea") "*")
    ,(concat (file-name-as-directory "*.eunit") "*")
    ,(concat (file-name-as-directory "*.git") "*")
    ,(concat (file-name-as-directory "*.hg") "*")
    ,(concat (file-name-as-directory "*.fslckout") "*")
    ,(concat (file-name-as-directory "*.bzr") "*")
    ,(concat (file-name-as-directory "*_darcs") "*")
    ,(concat (file-name-as-directory "*.tox") "*")
    ,(concat (file-name-as-directory "*.svn") "*")
    ,(concat (file-name-as-directory "*.stack-work") "*"))
  "A list of exclude items by projectIDE."
  :group 'projectIDE-config-file
  :type '(repeat string))

(defcustom projectIDE-default-whitelist nil
    "A list of exclude items by projectIDE."
  :group 'projecIDE-config-file
  :type '(repeat string))

(defcustom projectIDE-config-file-search-up-level 4
  "Number of upper level directories to search for the .projectIDE file."
  :tag "Config file search up level"
  :type 'integer
  :group 'projectIDE-config-file)

;; Project config file variable ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Project creation variable
;;vvv (defcustom projectIDE-create-defaultDir)
;;vvv (defcustom projectIDE-project-create-hook)
;;vvv (defcustom projectIDE-create-require-confirm)

(defcustom projectIDE-create-defaultDir (getenv "HOME")
  "Global default project directory.
When creating project, if no specific directory or
invalid default directory is entered, projectIDE uses this
variable as the default directory."
  :tag "Default project directory"
  :type 'directory
  :group 'projectIDE-project-creation)

(defcustom projectIDE-project-create-hook nil
  "Hook runs when creating project."
  :tag "projectIDE-project-create-hook"
  :type 'hook
  :group 'projectIDE-project-creation
  :group 'projectIDE-hook)

(defcustom projectIDE-create-require-confirm t
  "Require confirmation when creating project?
If this value is nil, projectIDE will skip confirmation
before creating project.
Other values ask for the confirmation."
  :tag "Require confirmation when creating project?"
  :type 'bool
  :group 'projectIDE-project-creation)

;; Project creation variable ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Project or file opening variable
;;vvv (defcustom projectIDE-open-project-prompt-type)
;;vvv (defcustom projectIDE-open-last-opened-files)
;;vvv (defcustom projectIDE-use-project-prefix)

(defcustom projectIDE-open-project-prompt-type 'name
  "Define how projects are prompted when calling `projectIDE-open-project'.
It can be either name or path."
  :tag "Open project promt type"
  :type '(radio
          (const :tag "name" name)
          (const :tag "path" path))
  :group 'projectIDE-opening)

(defcustom projectIDE-open-last-opened-files t
  "When opening a project, open the last opened files instead of Dired."
  :tag "Open last opened files?"
  :type 'bool
  :group 'projectIDE-opening)

(defcustom projectIDE-use-project-prefix t
  "When showing files, show project name as prefix instead of full path."
  :tag "Use project prefix instead of full path?"
  :type 'bool
  :group 'projectIDE-opening)

;; Project or file opening variable ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Project window variable

(defcustom projectIDE-max-horizontal-window 2
  "The max number of visible horizontal window(s) projectIDE can open."
  :tag "Open project promt type"
  :type 'integer
  :group 'projectIDE-window)

(defcustom projectIDE-max-vertical-window 2
  "The max number of visible vertical window(s) projectIDE can open."
  :tag "Open project promt type"
  :type 'integer
  :group 'projectIDE-window)

(defcustom projectIDE-other-window-priority
  '(horizontal vertical)
  "Priority of creating/switching new window.
Can only be \"horizontal\" or \"vertical\""
  :tag "Other window priority"
  :type '(list
          (symbol :tag "1st" horizontal)
          (symbol :tag "2nd" vertical))
  :group 'projectIDE-window)

(defcustom projectIDE-other-window-horizontal-priority
  '(right left)
  "Priority of creating/switching new window.
Can only be \"right\" or \"left\""
  :tag "Other window horizontal priority"
  :type '(list
          (symbol :tag "1st" right)
          (symbol :tag "2nd" left))
  :group 'projectIDE-window)

(defcustom projectIDE-other-window-vertical-priority
  '(below above)
  "Priority of creating/switching new window.
Can only be \"above\" or \"below\""
  :tag "Other window horizontal priority"
  :type '(list
          (symbol :tag "1st" below)
          (symbol :tag "2nd" above))
  :group 'projectIDE-window)



(defun projectIDE-other-window ()
  
  "Split or switch to other window in a smarter way."
  
  (interactive)
  (let ((hor 1)
        (ver 1)
        test)
    
    (while (window-in-direction 'left test)
      (setq test (window-in-direction 'left test)))
    (while (window-in-direction 'right test)
      (setq test (window-in-direction 'right test))
      (setq hor (1+ hor)))
    (setq test nil)
    (while (window-in-direction 'above test)
      (setq test (window-in-direction 'above test)))
    (while (window-in-direction 'below test)
      (setq test (window-in-direction 'below test))
      (setq ver (1+ ver)))
    
    (unless (and (>= hor projectIDE-max-horizontal-window)
                 (>= ver projectIDE-max-vertical-window))
      (cond
       ((> hor ver)
        (split-window nil nil (car projectIDE-other-window-vertical-priority)))
       ((< hor ver)
        (split-window nil nil (car projectIDE-other-window-horizontal-priority)))
       ((= hor ver)
        (split-window nil nil
                      (if (eq (car projectIDE-other-window-priority) 'vertical)
                          (car projectIDE-other-window-vertical-priority)
                        (car projectIDE-other-window-horizontal-priority))))))
    
    (other-window 1)))

;; Project window variable ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Project caching variable

(defcustom projectIDE-update-cache-interval 5
  "The time interval in second updating project cache by one step."
  :tag "Background update cache interval"
  :type 'integer
  :group 'projectIDE-caching)

;; Project caching variable ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Debug and logging variable

(defcustom projectIDE-log-level 2
  "Logging level specifies what to be logged."
  :tag "Logging level"
  :type '(radio
          (const :tag "Error" 3)
          (const :tag "Warning" 2)
          (const :tag "Info" 1)
          (const :tag "Disable" nil))
  :group 'projectIDE-global)

;; Debug and logging variable ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; Runtime Variable

(defvar projectIDE-p nil
  "Indicate whether projectIDE is running.
Never attempt to modify it directly.")

(defvar projectIDE-debug-mode nil
  "Indicate whether projectIDE is in debug mode.
Debug mode only add extra output to log file.
Never attempt to modify it directly.")

(defvar projectIDE-last-message nil
  "Record the last message.
Never attempt to modify it directly.")

(defvar projectIDE-runtime-record nil
  ;; hash table
  ;; key: signature
  ;; value: projectIDE-record object
  "Database recording all project.
Never attempt to modify it directly.")

(defvar projectIDE-runtime-cache nil
  ;; hash table-backward-cell
  ;; key: signature
  ;; value: projectIDE-cache object
  "Individual project cache.
Never attempt to modify it directly.")

(defvar projectIDE-runtime-Btrace
  ;; hash table
  ;; key: buffer
  ;; value: projectIDE-Btrace object
  "Trace buffer which is a projectIDE project.
Never attempt to modify it directly.")

(defvar projectIDE-active-project nil
  "Store the current active project signature.
Never attempt to modify it directly.")

(defvar projectIDE-priority-update-file nil
  "To temporary store the file name to be saved at before-save hook.
And cache this file at at `after-save-hook'.
Never attempt to modify it directly.")

(defvar projectIDE-write-out-cache t
  "To determine whether projectIDE write cache to harddisk
after closing the last file.
Never attempt to modify it directly.")

(defvar projectIDE-timer-primary nil
  "Timer for `projectIDE-timer-function-primary' to repeat itself, or nil.
Never attempt to modify it directly.")

(defvar projectIDE-timer-idle nil
  "Timer for `projectIDE-timer-function-idle' to reschedule itself, or nil.
Never attempt to modify it directly.")

;; Runtime variable ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~























;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;; record object
(cl-defstruct projectIDE-record
  signature
  name
  path
  create-time
  last-open
  reserve-field-1
  reserve-field-2
  reserve-field-3
  )

;;; Getter and setter function
;;fff (defun projectIDE-get-all-singatures ())
;;fff (defun projectIDE-get-all-records ())
;;fff (defun projectIDE-get-record (signature))
;;fff (defun projectIDE-get-signature-by-path (path &optional caller))
;;fff (defun projectIDE-get-project-name (signature))
;;fff (defun projectIDE-get-project-path (signature))
;;fff (defun projectIDE-get-project-create-time (signature))
;;fff (defun projectIDE-get-project-last-open (signature))
;;fff (defun projectIDE-set-project-name (signature name))
;;fff (defun projectIDE-set-project-path (signature path))
;;fff (defun projectIDE-set-project-last-open (signature))

(defun projectIDE-get-all-singatures ()
  
  "Get a list of all signatures found in projectIDE-runtime-record.

Return
Type:\t\t list of stirng or nil
Descrip.:\t A list of signature in string in projectIDE-runtime-record.
\t\t\tIf there is nothing in runtime record, return nil."
  
  (hash-table-keys projectIDE-runtime-record))



(defun projectIDE-get-all-records ()
  
  "Get a list of all records found in projectIDE-runtime-record.

Return
Type:\t\t list of record objects or nil
Descrip.:\t A list of record objects from projectIDE-runtime-record.
\t\t\tIf there is nothing in runtime record, return nil."
  
  (hash-table-values projectIDE-runtime-record))




(defun projectIDE-get-record (signature)
  
  "Get a reference to record object by SIGNATURE.
Return nil with it is unable to find that signature.

Return
Type:\t\t projectIDE-record object or nil
Descrip.:\t Return a record object if found or nil if not found.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (gethash signature projectIDE-runtime-record))



(defun projectIDE-get-signature-by-path (path)
  
  "Return signature by the best match of PATH in record.
Record is search in projectIDE-runtime-record.

Return
Type:\t\t projectIDE-record signature or nil
Descrip.:\t projectIDE-record signature of given PATH.
\t\t\t nil if PATH not found.

PATH
Type:\t\t string
Descript.:\t File or folder path in string."
  
  (let ((records (projectIDE-get-all-records))
        candidates
        signature)

    ;; Search all recods matched path
    (dolist (record records)
      (when (string-prefix-p (projectIDE-record-path record) path)
        (cl-pushnew 'candidates (projectIDE-record-signature record) :test 'equal)))

    (setq signature (car candidates))

    ;; Use the best match result
    (unless (<= (length candidates) 1)
      (dolist (candidate candidates)
        (when (> (length (projectIDE-get-project-path candidate))
                 (length (projectIDE-get-project-path signature)))
          (setq signature candidate))))
    
    signature))



(defun projectIDE-get-project-name (signature)
  
"Get the project name of given SIGNATURE.

Return
Type:\t\t string
Descrip.:\t\t Name of project of the given signature.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (projectIDE-record-name (gethash signature projectIDE-runtime-record)))



(defun projectIDE-get-project-path (signature)
  
  "Get the project root path of given SIGNATURE.
Return nil if \".projectIDE\" no longer exists at path.

Return
Type:\t\t string or nil
Descrip.:\t\t Path to project root or nil if invalid project root.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (let ((path (projectIDE-record-path (gethash signature projectIDE-runtime-record))))
    (if (file-readable-p (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
        path
      nil)))



(defun projectIDE-get-config-file-path (signature)
  
  "Get the project config file path of given SIGNATURE.
Return nil if \".projectIDE\" no longer exists at path.

Return
Type:\t\t string or nil
Descrip.:\t\t Path to project config file
\t\t\t: Returns nil if config file no longer exists.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (let ((path
         (concat (projectIDE-record-path
                  (gethash signature projectIDE-runtime-record))
                 PROJECTIDE-PROJECTROOT-IDENTIFIER)))
    (if (file-readable-p path)
        path
      nil)))



(defun projectIDE-get-project-create-time (signature)
  
  "Get the creation time of project given by SIGNATURE.

Return
Type:\t\t Emacs time
Descrip.:\t Date and time that the project created.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (projectIDE-record-create-time (gethash signature projectIDE-runtime-record)))



(defun projectIDE-get-project-last-open (signature)
  
  "Get the last opened time of project given by SIGNATURE

Return
Type:\t\t Emacs time
Descrip.:\t Date and time that the project modified.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (projectIDE-record-last-open (gethash signature projectIDE-runtime-record)))



(defun projectIDE-set-project-name (signature name)
  
  "Set the project NAME of given SIGNATURE in projectIDE-runtime-record.

NAME
Type:\t\t string
Descrip.:\t project name

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (setf (projectIDE-record-name (gethash signature projectIDE-runtime-record)) name))



(defun projectIDE-set-project-path (signature path)
  
  "Set the project PATH of given SIGNATURE in projectIDE-runtime-record.

NAME
Type:\t\t string
Descrip.:\t project path

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (setf (projectIDE-record-path (gethash signature projectIDE-runtime-record)) path))




(defun projectIDE-set-project-last-open (signature)
  
  "Set the project last opened time given by SIGNATURE to current time.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (setf (projectIDE-record-last-open (gethash signature projectIDE-runtime-record)) (current-time)))

;; record object ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; cache and project object

(cl-defstruct projectIDE-project
  signature                                    ;; string         eg. "173874102"
  name                                         ;; string         eg. "project1"
  exclude                                      ;; string-list    eg. ("*.git" ".projectIDE")
  whitelist                                    ;; string-list    eg. ("*.git" ".projectIDE")
  cachemode
  module
  module-var
  reserve-field-1
  reserve-field-2
  )

(cl-defstruct projectIDE-cache
  project                                      ;; project-project object
  config-update-time                           ;;
  exclude
  whitelist
  file-cache-state
  file-cache
  opened-buffer                                ;; string in terms of file path
  reserve-field-1
  reserve-field-2
  reserve-field-3
  )

(cl-defstruct projectIDE-assocache
  state
  filelist)

;;; Getter and setter function
;; Project object doesn't provide setter function
;; because it can only create by projectIDE-parse-config
;; The setter function of cache can only set cache in projectIDE-runtime-cache
;;fff (defun projectIDE-get-all-caching-signature ())
;;fff (defun projectIDE-get-cache (signature))
;;fff (defun projectIDE-get-config-update-time (signature))
;;fff (defun projectIDE-get-project-exclude (signature))
;;fff (defun projectIDE-get-project-whitelist (signature))
;;fff (defun projectIDE-get-cache-exclude (signature))
;;fff (defun projectIDE-get-cache-whitelist (signature))
;;fff (defun projectIDE-get-cachemode (signature))
;;fff (defun projectIDE-background-update-cache? (signature))
;;fff (defun projectIDE-open-project-update-cache? (signature))
;;fff (defun projectIDE-important-cmd-update-cache? (signature))
;;fff (defun projectIDE-pre-prompt-update-cache? (signature))
;;fff (defun projectIDE-generate-association? (signature))
;;fff (defun projectIDE-get-file-cache-state (signature))
;;fff (defun projectIDE-get-file-cache (signature))
;;fff (defun projectIDE-get-opened-buffer (signature))
;;fff (defun projectIDE-get-file-association (&optional buffer))
;;fff (defun projectIDE-get-file-association-state (&optional buffer))
;;fff (defun projectIDE-get-modules (signature))
;;fff (defun projectIDE-push-cache (signature cache))
;;fff (defun projectIDE-pop-cache (signature))
;;fff (defun projectIDE-set-cache-project (signature project))
;;fff (defun projectIDE-set-cache-filter (signature))
;;fff (defun projectIDE-set-file-cache-state (signature))
;;fff (defun projectIDE-unset-file-cache-state (signature))
;;fff (defun projectIDE-set-file-cache (signature))
;;fff (defun projectIDE-add-opened-buffer (signature file))
;;fff (defun projectIDE-remove-opened-buffer (signature file))
;;fff (defun projectIDE-clear-opened-buffer (signature file))
;;fff (defun projectIDE-set-file-association (signature filelist &optional buffer))
;;fff (defun projectIDE-flag-association-expired (signature))

(defun projectIDE-get-all-caching-signature ()
  
  "Get a list of project signature which is currently in runtime-cache.

Return
Type:\t\t list of string
Descrip.:\t A list of project signature."

  (let ((signatures (hash-table-keys projectIDE-runtime-cache))
        signatures-1)
    (dolist (signature signatures)
      ;; prevent return association cache 
      (when (projectIDE-cache-p (gethash signature projectIDE-runtime-cache))
        (setq signatures-1 (nconc signatures-1 (list signature)))))
    signatures-1))




(defun projectIDE-get-cache (signature)
  
  "Get a projectIDE-cache object of give SIGNATURE in projectIDE-runtime-cache.
It can also use to test whether project is in projectIDE-runtime-cache.

Return
Type:\t\t projectIDE-cache object or nil
Descrip.:\t The cache object of given signature or nil if not found.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (gethash signature projectIDE-runtime-cache))



(defun projectIDE-get-config-update-time (signature)
  
  "Get the project config file update time in cache by given SIGNATURE.
Return nil if \".projectIDE\" no longer exists at path.

Return
Type:\t\t emacs time
Descrip.:\t\t Time of last update time of config file in projectIDE-runtime-cache.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (projectIDE-cache-config-update-time (gethash signature projectIDE-runtime-cache)))



(defun projectIDE-get-project-exclude (signature)
  
  "Get the list of exclude from project object with given SIGNATURE in cache.

Return
Type:\t\t list of string
Descrip.:\t A list of exculding regexp

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (projectIDE-project-exclude
   (projectIDE-cache-project
    (gethash signature projectIDE-runtime-cache))))




(defun projectIDE-get-project-whitelist (signature)
  
  "Get the list of allowed from project object with given SIGNATURE in cache.

Return
Type:\t\t list of string
Descrip.:\t A list of whitelist regexp

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (projectIDE-project-whitelist
   (projectIDE-cache-project
    (gethash signature projectIDE-runtime-cache))))



(defun projectIDE-get-cache-exclude (signature)
  
  "Get the list of exclude form cache with given SIGNATURE.

Return
Type:\t\t list of string
Descrip.:\t A list of exculding regexp

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (projectIDE-cache-exclude (gethash signature projectIDE-runtime-cache)))



(defun projectIDE-get-cache-whitelist (signature)
  
  "Get the list of allowed form cache with given SIGNATURE.

Return
Type:\t\t list of string
Descrip.:\t A list of whitelist regexp

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (projectIDE-cache-whitelist (gethash signature projectIDE-runtime-cache)))



(defun projectIDE-get-cachemode (signature)
  
  "Get the cache mode of project given by SIGNATURE.

Return
Type:\t\t integer (bitwise)
Descrip.:\t Bitwise operated cache mode.  See `projectIDE-default-cachemode'.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (projectIDE-project-cachemode (projectIDE-cache-project (gethash signature projectIDE-runtime-cache))))



(defun projectIDE-get-file-cache-state (signature)
  
  "Get the file cache state of project given by SIGNATURE.

Return
Type:\t\t integer
Descrip.:\t netgative if the file cache has not been updated yet.
\t\t\t 0 is an uncertain state that it may or may not be
\t\t\t   completed updating.
\t\t\t 1 is a state it repeating a completed state.
\t\t\t 2 is a state that it generates buffer association.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
   (projectIDE-cache-file-cache-state (gethash signature projectIDE-runtime-cache)))



(defun projectIDE-background-update-cache? (signature)
  
  "Return t if project of given SIGNATURE should update cache in background.

Return
Type:\t\t bool
Descrip.:\t t if project should update cache in background, otherwise nil.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (eq projectIDE-CACHEMODE-background-update-cache
      (logand
       projectIDE-CACHEMODE-background-update-cache
       (projectIDE-project-cachemode
        (projectIDE-cache-project (gethash signature projectIDE-runtime-cache))))))



(defun projectIDE-open-project-update-cache? (signature)
  
  "Return t if project of given SIGNATURE
should update cache when it first opens.

Return
Type:\t\t bool
Descrip.:\t t if project should update cache when first opens, otherwise nil.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (eq projectIDE-CACHEMODE-open-project-update-cache
      (logand
       projectIDE-CACHEMODE-open-project-update-cache
       (projectIDE-project-cachemode
        (projectIDE-cache-project (gethash signature projectIDE-runtime-cache))))))



(defun projectIDE-important-cmd-update-cache? (signature)
  
  "Return t if project of given SIGNATURE
should update cache before important command.

Return
Type:\t\t bool
Descrip.:\t t if project should update cache before important commands,
\t\t\t otherwise nil.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (eq projectIDE-CACHEMODE-update-cache-important-command
      (logand
       projectIDE-CACHEMODE-update-cache-important-command
       (projectIDE-project-cachemode
        (projectIDE-cache-project (gethash signature projectIDE-runtime-cache))))))



(defun projectIDE-pre-prompt-update-cache? (signature)
  
  "Return t if project of given SIGNATURE
should update cache before prompting for file list.

Return
Type:\t\t bool
Descrip.:\t t if project should update cache before prompting for file list,
\t\t\t otherwise nil.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (eq projectIDE-CACHEMODE-update-cache-pre-prompt
      (logand
       projectIDE-CACHEMODE-update-cache-pre-prompt
       (projectIDE-project-cachemode
        (projectIDE-cache-project (gethash signature projectIDE-runtime-cache))))))



(defun projectIDE-generate-association? (signature)
  
  "Return t if project of given SIGNATURE should generate file association list.

Return
Type:\t\t bool
Descrip.:\t t if project should generate file association list, otherwise nil.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (eq projectIDE-CACHEMODE-generate-association
      (logand
       projectIDE-CACHEMODE-generate-association
       (projectIDE-project-cachemode
       (projectIDE-cache-project (gethash signature projectIDE-runtime-cache))))))



(defun projectIDE-get-file-cache (signature)
  
  "Get the file cache hash table from cache with given SIGNATURE.

Return
Type:\t\t hashtbale
Descrip.:\t A hashtable of file cache maintained by fdex

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (projectIDE-cache-file-cache (gethash signature projectIDE-runtime-cache)))



(defun projectIDE-get-opened-buffer (signature)
  
  "Get the opened buffer from cache with given SIGNATURE.

Return
Type:\t\t list of string
Descrip.:\t A list of opened buffer in terms of file path.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (projectIDE-cache-opened-buffer (gethash signature projectIDE-runtime-cache)))



(defun projectIDE-get-file-association (&optional buffer)
  
  "Get the file association of BUFFER in project.
Associated files mean file with same file name but different extension.
If buffer is not provided, current buffer is used instead.

Return
Type:\t\t list of string or nil
Descrip.:\t A list of files that are associated.
\t\t\t nil if no associated record.
\t\t\t Either not yet generated or not enabled to geterate.
\t\t\t Note that nil does not means no association.
\t\t\t There should also be at least one association
\t\t\t that is the buffer itself.

BUFFER
Type:\t\t Emacs buffer
Descrip.:\t If buffer is not provided, current buffer is used."

  (let ((signature (gethash (or buffer (current-buffer)) projectIDE-runtime-Btrace))
        table
        association)
    (if (and signature
             (setq table (gethash (concat signature "association") projectIDE-runtime-cache))
             (setq association (gethash (file-name-sans-extension (file-name-nondirectory (buffer-file-name buffer))) table)))
        (projectIDE-assocache-filelist association)
      nil)))



(defun projectIDE-get-file-association-state (&optional buffer)
  
  "Return t if the file association state of given BUFFER is valid.
Otherwise, nil.
If BUFFER is not provided, current buffer is used.

Return
Type:\t\t bool
Descrip.:\t Return t if the file association state of given BUFFER is valid.

BUFFER
Type:\t\t Emacs buffer
Descrip.:\t If buffer is not provided, current buffer is used."

  (let ((signature (gethash buffer projectIDE-runtime-Btrace))
        table
        association)
    (if (and signature
             (setq table (gethash (concat signature "association") projectIDE-runtime-cache))
             (setq association
                   (gethash (file-name-sans-extension (file-name-nondirectory (buffer-file-name buffer))) table)))
        (projectIDE-assocache-state association)
      nil)))



(defun projectIDE-get-modules (signature)

  "Return a list of modules for project with given SIGNATURE.

Return
Type:\t\t list of symbol
Descrip:\t List of modules

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (let ((cache (gethash signature projectIDE-runtime-cache)))
    (if cache
        (projectIDE-project-module (projectIDE-cache-project cache))
      nil)))



(defun projectIDE-get-module-var (signature module var)
  
  "Get the value of VAR of MODULE from project specified by SIGNATURE.
The return result should be a list of string if VAR exists.
It will be nil if VAR does not exist.


Return
Type:\t\t list of string or nil
Descrip.:\t List of string if VAR exists, otherwise nil.

MODULDE
Type:\t\t symbol
Descrip.:\t The name of the module.

VAR
Type:\t\t symbol
Descrip.:\t The variable name.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (let* ((cache (gethash signature projectIDE-runtime-cache))
         (project (and cache (projectIDE-cache-project cache)))
         (values (and project (projectIDE-project-module-var project))))
    (lax-plist-get values (concat (symbol-name module) "-" (symbol-name var)))))



(defun projectIDE-push-cache (signature cache)
  
  "Push CACHE of project given by SIGNATURE in projectIDE-runtime-cache.
Make an file association cache as well if it is not disabled.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

CACHE
Type:\t\t projectIDE-cache object
Descrip.:\t The cache object to be put in projectIDE-runtime-cache."

  (puthash signature cache projectIDE-runtime-cache)
  (when (eq projectIDE-CACHEMODE-generate-association
            (logand
             projectIDE-CACHEMODE-generate-association
             (projectIDE-project-cachemode
              (projectIDE-cache-project cache))))
    (puthash (concat signature "association") (make-hash-table :size 30 :test 'equal) projectIDE-runtime-cache)))



(defun projectIDE-pop-cache (signature)
  
  "Remove cache of project given by SIGNATURE in projectIDE-runtime-cache.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (remhash signature projectIDE-runtime-cache))



(defun projectIDE-set-cache-project (signature project)
  
"Set the PROJECT object in projectIDE-runtime-cache with given SIGNATURE.
Update the config update time as well.

PROJECT
Type:\t\t projectIDE-project object
Descrip.:\t Project object to be set in cache.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

(let ((cache (gethash signature projectIDE-runtime-cache)))
        (setf (projectIDE-cache-project cache) project)
        (setf (projectIDE-cache-config-update-time cache) (current-time))))



(defun projectIDE-set-cache-filter (signature)
  
  "Set the exclude and whitelist of project cache given by SIGNATURE.
The exculde and whitelist obtain from the project object in cache.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (let* ((cache (gethash signature projectIDE-runtime-cache))
         (exclude (projectIDE-project-exclude (projectIDE-cache-project cache)))
         (whitelist (projectIDE-project-whitelist (projectIDE-cache-project cache))))
    (setf (projectIDE-cache-exclude cache) exclude)
    (setf (projectIDE-cache-whitelist cache) whitelist)))



(defun projectIDE-set-file-cache-state (signature state)
  
  "Set the the file cache state of project of given SIGNATURE to STATE.
STATE is the state of file caching, see `projectIDE-get-file-cache-state'.


SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

STATE
Type:\t\t integer
Descri.:\t The file caching state."
  
  (setf (projectIDE-cache-file-cache-state (gethash signature projectIDE-runtime-cache)) state))



(defun projectIDE-set-file-cache (signature)
  
  "Set a new file cache hash table for project given by SIGNATURE.
It can also use to reset the file cache.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (let ((path (projectIDE-record-path (gethash signature projectIDE-runtime-record)))
        (cache (gethash signature projectIDE-runtime-cache)))
    (setf (projectIDE-cache-file-cache cache)
          (fdex-new path
                    (projectIDE-manipulate-filter path (projectIDE-cache-exclude cache))
                    (projectIDE-manipulate-filter path (projectIDE-cache-whitelist cache))))))



(defun projectIDE-add-opened-buffer (signature file)
  
  "Add FILE to opened buffer of project cache given by SIGNATURE.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

FILE
Type:\t\t string
Descrip.:\t File path."
    
  (setf (projectIDE-cache-opened-buffer (gethash signature projectIDE-runtime-cache))
        (projectIDE-add-to-list (projectIDE-cache-opened-buffer (gethash signature projectIDE-runtime-cache)) file)))



(defun projectIDE-remove-opened-buffer (signature file)
  
  "Remove FILE from opened buffer of project cache given by SIGNATURE.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

FILE
Type:\t\t string
Descrip.:\t File path."
  
  (setf (projectIDE-cache-opened-buffer (gethash signature projectIDE-runtime-cache))
        (cl-remove file (projectIDE-cache-opened-buffer (gethash signature projectIDE-runtime-cache)) :test 'equal)))



(defun projectIDE-clear-opened-buffer (signature)
  
  "Remove all files from opened buffer of project cache given by SIGNATURE.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."
  
  (setf (projectIDE-cache-opened-buffer (gethash signature projectIDE-runtime-cache)) nil))



(defun projectIDE-set-file-association (filelist &optional buffer)
  
"Set the file association of BUFFER of project to FILELIST.
If BUFFER is not provided, current buffer is used instead.

FILELIST
Type:\t\t list of string
Descrip.:\t A list of file paths having same filename.
\t\t\t There is at least one element in the list: the buffer itself.

BUFFER
Type:\t\t Emacs buffer
Descrip.:\t If buffer is not provided, current buffer is used."

(let* ((signature (gethash (or buffer (current-buffer)) projectIDE-runtime-Btrace))
       (filename (file-name-sans-extension (file-name-nondirectory (buffer-file-name buffer))))
       (table (gethash (concat signature "association") projectIDE-runtime-cache)))

  ;; Prevent multi extension suffix, eg. "foo.h.in"
  (while (not (equal filename (file-name-sans-extension filename)))
    (setq filename (file-name-sans-extension filename) ))
  
    (when table
      (puthash filename (make-projectIDE-assocache :state t :filelist filelist) table))))



(defun projectIDE-flag-association-expired (signature)
  
  "Flag the file association list of project given by SIGNATURE expired.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID."

  (let ((table (gethash (concat signature "association") projectIDE-runtime-cache)))
    (when table
      (maphash
       (lambda (key value)
         (setf (projectIDE-assocache-state value) nil))
       table))))

;; cache and project object ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; projectIDE buffer tracer
;;; Getter and setter function
;;fff (defun projectIDE-get-Btrace-signature ())
;;fff (defun projectIDE-get-buffer-list (&optional signature))
;;fff (defun projectIDE-push-Btrace (signature &optional buffer))
;;fff (defun projectIDE-pop-Btrace ())

(defun projectIDE-get-Btrace-signature (&optional buffer)
  
  "Return the project signature of given BUFFER.
If BUFFER is not a member of a project, returns nil.
If BUFFER is not provided, current buffer is used.

Return
Type:\t\t string or nil
Descrip.:\t Project signature
\t\t\t Returns nil if BUFFER is not a project member.

BUFFER
Type:\t\t Emacs buffer
Descrip.:\t If buffer is not provided, current buffer is used."
  
  (gethash (or buffer (current-buffer)) projectIDE-runtime-Btrace))



(defun projectIDE-get-buffer-list (&optional signature)
  
  "Return all opened buffer objects from project given by SIGNATURE.
If signature is not provided, return opened buffers from all project.

Return
Type:\t\t list of buffer objects
Descrip.:\t\t Buffer objects of given project.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.
\t\t\t If signature is not provided, return opened buffers from all project."
  
  (if signature
      (let ((buffers (hash-table-keys projectIDE-runtime-Btrace))
            buffers-new)
        (dolist (buffer buffers)
          (when (equal (gethash buffer projectIDE-runtime-Btrace) signature)
            (push buffer buffers-new)))
        buffers-new)
    (hash-table-keys projectIDE-runtime-Btrace)))



(defun projectIDE-push-Btrace (signature &optional buffer)
  
  "Put BUFFER to Btrace.
It indicates buffer is a member of project given by SIGNATURE.
If BUFFER is not provided, current buffer is used.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

BUFFER
Type:\t\t Emacs buffer
Descrip.:\t If buffer is not provided, current buffer is used."

  (puthash (or buffer (current-buffer)) signature projectIDE-runtime-Btrace))



(defun projectIDE-pop-Btrace (&optional buffer)
  
  "Remove BUFFER from projectIDE-runtime-Btrace.
If BUFFER is not provided, current buffer is used.

BUFFER
Type:\t\t Emacs buffer
Descrip.:\t If buffer is not provided, current buffer is used."

  (remhash (or buffer (current-buffer)) projectIDE-runtime-Btrace))

;; projectIDE buffer trace ends
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; projectIDE module

(defvar projectIDE-runtime-packages nil
  "Store and manage modules.
Never attempt to modify it directly.")

(defvar projectIDE-runtime-functions nil
  "Store and manage project specific functions.
Never attempt to modify it directly.")

(defvar projectIDE-key-table nil
  "Store keymap for modules.
Never attempt to modify it directly.")

(defvar projectIDE-current-loading-module nil
  "Store the current loading module.
It will be non-nil only while loading a module.
Never attempt to modify it directly.")

(defvar projectIDE-active-modules nil
  "Store the current active modules.
Never attempt to modify it directly.")

(defvar projectIDE-renew-modules-timer nil
  "Store the timer for renewing modules.
It should be always nil when checking for it.
Because it store a idle timer with 0 second.
Never attempt to modify it directly.")



(cl-defstruct projectIDE-package
  name
  functions
  signatures
  closetime
  )

(cl-defstruct projectIDE-function
  name
  type
  args
  docstring
  body
  key
  )



(defun projectIDE-get-function-key (function)
  (plist-get projectIDE-key-table function))


(defun projectIDE-add-module-signature (module signature)

  (let ((module (plist-get projectIDE-runtime-packages module)))
    (if module
        (progn
          (cl-pushnew signature (projectIDE-package-signatures module) :test 'equal)
          t)
      nil)))

(defun projectIDE-register (package function)
  
  "Register FUNCTION from PACKAGE to `projectIDE-runtime-packages'."
  
  (let ((pack (plist-get projectIDE-runtime-packages package)))
    (if pack
        (cl-pushnew function (projectIDE-package-functions pack))
      (setq projectIDE-runtime-packages (plist-put
                                         projectIDE-runtime-packages
                                         package
                                         (make-projectIDE-package :name package :functions (list function)))))))



(defmacro projectIDE-defun (name args &rest body)
  
  "A wrapper to `defun' that put the function in `projectIDE-runtime-functions'
instead of defining it directly.

The function defined by `projectIDE-defun' will be managed by projectIDE."
  
  (projectIDE-register projectIDE-current-loading-module name)
  (puthash
   name
   (make-projectIDE-function :name name
                             :type 'defun
                             :args args
                             :docstring (and (stringp (car body)) (car body))
                             :body (or (and (stringp (car body)) (cdr body)) body)
                             :key (plist-get projectIDE-key-table 'name))
   projectIDE-runtime-functions))



(defmacro projectIDE-cl-defun (name args &rest body)
  
    "A wrapper to `cl-defun' that put the function in `projectIDE-runtime-functions'
instead of defining it directly.

The function defined by `projectIDE-cl-defun' will be managed by projectIDE."
    
  (projectIDE-register projectIDE-current-loading-module name)
  (puthash
   name
   (make-projectIDE-function :name name
                             :type 'cl-defun
                             :args args
                             :docstring (and (stringp (car body)) (car body))
                             :body (or (and (stringp (car body)) (cdr body)) body)
                             :key (plist-get projectIDE-key-table 'name))
   projectIDE-runtime-functions))



(defmacro projectIDE-defmacro (name args &rest body)

    "A wrapper to `demacro' that put the function in `projectIDE-runtime-functions'
instead of defining it directly.

The function defined by `projectIDE-defmacro' will be managed by projectIDE."
    
  (projectIDE-register projectIDE-current-loading-module name)
  (puthash
   name
   (make-projectIDE-function :name name
                             :type 'defmacro
                             :args args
                             :docstring (and (stringp (car body)) (car body))
                             :body (or (and (stringp (car body)) (cdr body)) body)
                             :key (plist-get projectIDE-key-table 'name))
   projectIDE-runtime-functions))

(defmacro projectIDE-cl-defmacro (name args &rest body)
    
    "A wrapper to `cl-defmarco' that put the function in `projectIDE-runtime-functions'
instead of defining it directly.

The function defined by `projectIDE-cl-defmarco' will be managed by projectIDE."
    
  (projectIDE-register projectIDE-current-loading-module name)
  (puthash
   name
   (make-projectIDE-function :name name
                             :type 'cl-defmacro
                             :args args
                             :docstring (and (stringp (car body)) (car body))
                             :body (or (and (stringp (car body)) (cdr body)) body)
                             :key (plist-get projectIDE-key-table 'name))
   projectIDE-runtime-functions))



;; Getter and setter functions

(defun projectIDE-get-all-functions-from-module (name)
  
  "Return a list of functions defined by module with NAME.

Return
Type\t\t: list of symbol or nil
Descrip.:\t A list of functions definded in specified module.
\t\t\t Return nil, if either module was not loaded
\t\t\t or no functions defined in module.

NAME
Type:\t\t symbol
Descrip.:\t\t Name of function."

  (let ((module (plist-get projectIDE-runtime-packages name)))
    (and module (projectIDE-package-functions module))))

(defun projectIDE-get-function-object (name)
  
  "Return a `projectIDE-function' object from `projectIDE-runtime-functions'
if function of name exists, otherwise return nil.

Return
Type:\t\t proejctIDE-function object or nil
Descrip.:\t\t Function object that has been defined by either
\t\t\t `projectIDE-defun', `porjectIDE-cl-defun',
\t\t\t `projectIDE-defmarco', `projectIDE-cl-defmarco'.
\t\t\t Or return nil if no such record.

NAME
Type:\t\t symbol
Descrip.:\t\t Name of function."
  
  (gethash name projectIDE-runtime-functions))

(defun projectIDE-get-function-object-type (name)

  "Return the type of defing of function given by NAME
from `projectIDE-runtime-functions'.
The type may either be 'defun, 'cl-defun, 'defmacro or
cl-defmacro.

Return
Type:\t\t symbol
Descrip.:\t Type of defining of function.
\t\t\t Return nil if function of NAME not found.

NAME
Type:\t\t symbol
Descrip.:\t\t Name of function."

  (let* ((function (gethash name projectIDE-runtime-functions))
         (type (and function (projectIDE-function-type function))))
    type))

;; projectIDE module endls
;;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

(provide 'projectIDE-header)
;;; projectIDE-header.el ends here
