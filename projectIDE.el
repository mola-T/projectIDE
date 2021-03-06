;;; projectIDE.el --- project management package
;;
;; Copyright (C) 2015 Mola-T
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
;; A project management package.
;; See https://github.com/mola-T/projectIDE for all information
;;
;;; code:

(require 'cl-lib)
(require 'fdex)
(require 'projectIDE-header)
(require 'projectIDE-debug)
(require 'projectIDE-fstream)
(require 'projectIDE-module)
(require 'projectIDE-modeline)
(require 'projectIDE-session)
(require 'projectIDE-addfile)
(require 'projectIDE-compile)
(require 'projectIDE-scriptloader)
(require 'projectIDE-cleanup)

;;; Config file function ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;fff (defun projectIDE-parse-config (file &optional errormessage caller))
;;fff (defun projectIDE-verify-config (&optional prefix)) -I


(defun projectIDE-parse-config (config &optional errormessage caller)
  
  "Parse .projectIDE config FILE.

Return a projectIDE-project object created by the CONFIG.
CONFIG is either a \".projectIDE\" config file
or a \".projectIDE\" buffer.
If .projectIDE is a blank file, return a default projectIDE-project object.
If there is any problem parsing the .projectIDE file, return nil.

Return
Type:\t\t projectIDE-project object or nil
Descrip.:\t Project object created by parsing FILE.
\t\t\t: nil for any error.

CONFIG
Type:\t\t string or buffer
Descrip.:\t Flie path to .projectIDE.
\t\t\t Or emacs buffer to .projectIDE. 

ERRORMESSAGE
Type:\t\t bool
Descrip.:\t Display error message to minibuffer if it is t.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."

  (catch 'parse-error
    (let ((project (make-projectIDE-project))
          (filename (or (and (bufferp config) (buffer-file-name config)) config))
          scope)
      
      (with-temp-buffer
        (if (bufferp config)
            (insert-buffer-substring config)
          (insert-file-contents config))
        (goto-char 1)
        
        ;; Search keys
        (while (search-forward-regexp projectIDE-config-key-string nil t)
          (save-excursion
            
            ;; Identify key
            (beginning-of-line)
            (let ((line-end (line-end-position))
                  (keylist projectIDE-config-key)
                  (counter 0)
                  found)
              
              (while (and (not found) (car keylist))
                (if (search-forward-regexp (car keylist) line-end t)
                    (progn
                      (cond
                       ((= counter 0) ;; "^signature *="
                        (when (projectIDE-project-signature project)
                          (projectIDE-message 'Error
                                              (format "Config file corrupt. 'signature' in \"%s\" definded more than once." filename)
                                              errormessage
                                              (projectIDE-caller 'projectIDE-parse-config caller))
                          (throw 'parse-error nil))
                        (setf (projectIDE-project-signature project) (projectIDE-trim-string (buffer-substring-no-properties (point) line-end))))
                       
                       ((= counter 1) ;; "^name *="
                        (when (projectIDE-project-name project)
                          (projectIDE-message 'Error
                                              (format "Config file corrupt. 'name' in \"%s\" definded more than once." filename)
                                              errormessage
                                              (projectIDE-caller 'projectIDE-parse-config caller))
                          (throw 'parse-error nil))
                        (setf (projectIDE-project-name project) (projectIDE-trim-string (buffer-substring-no-properties (point) line-end))))
                       
                       ((= counter 2) ;; "^exclude *="
                        (let ((exclude-list
                               (condition-case err
                                   (split-string-and-unquote (buffer-substring-no-properties (point) line-end))
                                 (end-of-file
                                  (projectIDE-message 'Error
                                                      (format "Config file corrupt. Unbalance quote on line --%s-- of \"%s\"."
                                                              (line-number-at-pos) filename)
                                                      errormessage
                                                      (projectIDE-caller 'projectIDE-parse-config caller))
                                  (throw 'parse-error nil)))))
                          (setf (projectIDE-project-exclude project)
                                (projectIDE-append (projectIDE-project-exclude project) exclude-list))))
                       
                       ((= counter 3) ;; "^whitelist *="
                        (let ((whitelist
                               (condition-case err
                                   (split-string-and-unquote (buffer-substring-no-properties (point) line-end))
                                 (end-of-file
                                  (projectIDE-message 'Error
                                                      (format "Config file corrupt. Unbalance quote on line --%s-- of \"%s\"."
                                                              (line-number-at-pos) filename)
                                                      errormessage
                                                      (projectIDE-caller 'projectIDE-parse-config caller))
                                  (throw 'parse-error nil)))))
                          (setf (projectIDE-project-whitelist project)
                                (projectIDE-append (projectIDE-project-whitelist project) whitelist))))
                       
                       ((= counter 4) ;; "^cachemode *="
                        (when (projectIDE-project-cachemode project)
                          (projectIDE-message 'Error
                                              (format "Config file corrupt. 'cachemode' in \"%s\" definded more than once." filename)
                                              errormessage
                                              (projectIDE-caller 'projectIDE-parse-config caller))
                          (throw 'parse-error nil))
                        (setf (projectIDE-project-cachemode project)
                              (string-to-number (projectIDE-trim-string (buffer-substring-no-properties (point) line-end)))))
                       
                       ((= counter 5) ;; "^module *="
                        (let ((modules (projectIDE-project-module project))
                              (modules-s (split-string (buffer-substring-no-properties (point) line-end))))
                          (dolist (module modules-s)
                            (setq modules (projectIDE-add-to-list modules (intern module))))
                          (setf (projectIDE-project-module project) modules)))

                       ((= counter 6) ;; "^scope *="
                        (setq scope (projectIDE-trim-string (buffer-substring-no-properties (point) line-end))))

                       ((= counter 7) ;; "^[[:digit:][:alpha:]]+ *="
                        (let ((module-var (projectIDE-project-module-var project))
                              (var (condition-case err
                                       (split-string-and-unquote (buffer-substring-no-properties (point) line-end))
                                     (end-of-file
                                      (projectIDE-message 'Error
                                                          (format "Config file corrupt. Unbalance quote on line --%s-- of \"%s\"."
                                                                  (line-number-at-pos) filename)
                                                          errormessage
                                                          (projectIDE-caller 'projectIDE-parse-config caller))
                                      (throw 'parse-error nil))))
                              (name (concat scope (and scope "-")
                                            (projectIDE-trim-string
                                             (string-remove-suffix "="
                                                                   (buffer-substring-no-properties (line-beginning-position) (point)))))))
                          (setq module-var (plist-put module-var (intern name) var))
                          (setf (projectIDE-project-module-var project) module-var))))
                      (setq found t))
                  
                  (setq counter (1+ counter))
                  (setq keylist (cdr keylist))))))))
      
      (unless (projectIDE-project-exclude project)
        (setf (projectIDE-project-exclude project) projectIDE-default-exclude))
      (unless (projectIDE-project-whitelist project)
        (setf (projectIDE-project-whitelist project) projectIDE-default-whitelist))
      (unless (projectIDE-project-cachemode project)
        (setf (projectIDE-project-cachemode project) projectIDE-default-cachemode))
      
      (when projectIDE-debug-mode
        (projectIDE-message 'Info
                            (format "Parsed config file \"%s\" successfully" filename)
                            nil
                            (projectIDE-caller 'projectIDE-parse-config caller)))
      project)))



(defun projectIDE-verify-config (&optional prefix)
  
  "An interactive function to verify a \".projectIDE\" config.

If PREFIX is not provided, it will try to verify the current buffer.
If PREFIX is provided or current buffer is not a config file,
it will prompt user for a config file.

This function can only check syntax error!

Return
Type:\t\t bool
Descrip.:\t Returns t if the config file can be parsed successfully.
\t\t\t Otherwise, returns nil.

PREFIX
Type:\t\t any
Descrip:\t Prompt for a config file if it is provided."
  
  (interactive "p")
  (let (config)

    ;; Try to read current buffer first
    (when (and (or (not prefix) (= prefix 1))
               (buffer-file-name)
               (equal (file-name-nondirectory (buffer-file-name)) PROJECTIDE-PROJECTROOT-IDENTIFIER))
      (setq config (current-buffer)))
    
    ;; Try to prompt for a config file
    (when (and prefix (not (= prefix 1)))
      (setq config (expand-file-name
                    (projectIDE-read-file-name "Choose config: " nil nil t nil
                                               (lambda (file)
                                                 (or
                                                  (file-directory-p file)
                                                  (equal (file-name-nondirectory file) PROJECTIDE-PROJECTROOT-IDENTIFIER))))))
      (when (file-directory-p config)
        (setq config nil)))

    (when config
      (if (projectIDE-parse-config config)
          (progn
            (projectIDE-message 'Info
                                "Project config parse successfully. File saved."
                                t
                                (projectIDE-caller 'projectIDE-verify-config))
            t)
        ;; Parsing error
        (message "%s\nFile saved." projectIDE-last-message)
        nil))))

;;; Config file function ends ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















;; Indexing function ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;fff (defun projectIDE-generate-signature (&optional caller))
;;fff (defun projectIDE-new-project (path &optional caller))
;;fff (defun projectIDE-root-create (path &optional caller))
;;fff (defun projectIDE-record-create (configfile &optional caller))
;;fff (defun projectIDE-cache-create (configfile &optional caller))
;;fff (defun projectIDE-identify-project (&optional buffer caller))
;;fff (defun projectIDE-index-project (path &optional caller))

(defun projectIDE-generate-signature (&optional caller)
  "Generate and return a projectIDE signature.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

Return
Type:\t\t string
Descrip.:\t A signature string.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (secure-hash 'sha1
               (concat (current-time-string) (number-to-string (random)))))



(defun projectIDE-new-project (path &optional caller)
  ;; Ensure PATH is a directory before passing to this function.
  ;; ie. use file-name-as-directory
  "Create project with PATH as project root.
It is a encapsulation of project creation chain.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

PATH
Type:\t\t string
Descrip.:\t Path to project root.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (let ((project-config (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER)))
    ;; Generate .projectIDE file
    (projectIDE-root-create path (projectIDE-caller 'projectIDE-new-project caller))
    ;; Create global record
    (projectIDE-record-create project-config (projectIDE-caller 'projectIDE-new-project caller))
    ;; Create individual record
    (projectIDE-cache-create project-config (projectIDE-caller 'projectIDE-new-project caller))))



(defun projectIDE-root-create (path &optional caller)
  
  "Create '.projectIDE' at PATH to indicate a project root.
Create basic key like signature, name, exclude and whitelist as well.

If '.projectIDE' has already existed, try to read the '.projectIDE config
and give it a new signature.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

PATH
Type:\t\t string
Descrip.:\t Path to project root.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  ;; Generate .projectIDE if not exist
  (unless (memq PROJECTIDE-PROJECTROOT-IDENTIFIER (directory-files path))
    (write-region "" nil (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER) t 'inhibit))

  (let* ((file (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
         (project (projectIDE-parse-config file nil (projectIDE-caller 'projectIDE-root-creator caller)))
         (signature (projectIDE-generate-signature (projectIDE-caller 'projectIDE-root-creator caller)))
         (name (projectIDE-project-name project))
         (exclude (projectIDE-project-exclude project))
         (whitelist (projectIDE-project-whitelist project)))
    
    (with-temp-file file
      ;; If signature exists in .projectIDE, remove it
      (when (projectIDE-project-signature project)
        (while (search-forward-regexp "^signature *=" nil t)
          (delete-region (line-beginning-position) (line-end-position))))
      
      (goto-char 1)
      ;; Write to .projectIDE
      ;; Handle signature
      
      (insert "## This file is generated by projectIDE\n"
              "## There are several keys availiable.\n"
              "## You can see documentation for all keys.\n"
              "## Keys must start on a newline and end with a '='.\n"
              "## Below is an example for key 'signature.\n"
              "signature = " signature "\n"
              "## Signature is unique for each project.\n"
              "## ProjectIDE used the signature to trace every data on that project.\n"
              "## So never create or change the signature manually!!!\n\n")
      
      ;; Handle name
      ;; If name not exists in projectIDE, create for it
      (unless name
        (setq name (file-name-nondirectory (directory-file-name (file-name-directory file))))
        (insert "name = " name "\n"))
      
      ;; Handle exclude
      (insert "exclude = " (mapconcat 'identity (projectIDE-project-exclude project) " ") "\n")
      (save-excursion
        (while (search-forward-regexp "^exclude *=" nil t)
          (delete-region (line-beginning-position) (line-end-position))))
      
      ;; Handle whitelist
      (insert "whitelist =" (mapconcat 'identity (projectIDE-project-whitelist project) " ") "\n")
      (save-excursion
        (while (search-forward-regexp "^whitelist *=" nil t)
          (delete-region (line-beginning-position) (line-end-position)))))
    
    (when projectIDE-debug-mode
      (projectIDE-message 'Info
                          (format "Project root created at \"%s\"" path)
                          nil
                          (projectIDE-caller 'projectIDE-root-creator caller)))))



(defun projectIDE-record-create (configfile &optional caller)
  
  "Create projectIDE-record by reading CONFIGFILE.
Write to RECORD file afterward.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

CONFIGFILE
Type:\t\t string
Descrip.:\t A string of path to .projectIDE config file.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (let ((project (projectIDE-parse-config configfile nil (projectIDE-caller 'projectIDE-record-create caller)))
        (record (make-projectIDE-record)))
    
    (setf (projectIDE-record-signature record)(projectIDE-project-signature project)
          (projectIDE-record-name record)(projectIDE-project-name project)
          (projectIDE-record-path record) (file-name-directory configfile)
          (projectIDE-record-create-time record) (current-time)
          (projectIDE-record-last-open record) (current-time))
    
    (puthash (projectIDE-project-signature project) record projectIDE-runtime-record)
    (fout<<projectIDE PROJECTIDE-RECORD-FILE 'projectIDE-runtime-record (projectIDE-caller 'projectIDE-record-create caller)))
  
  (when projectIDE-debug-mode
    (projectIDE-message 'Info
                        (format "Project record created for \"%s\"" configfile)
                        nil
                        (projectIDE-caller 'projectIDE-record-create caller))))



(defun projectIDE-cache-create (configfile &optional caller)
  
  "Create cache by CONFIGFILE.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

CONFIGFILE
Type:\t\t string
Descrip.:\t A string of path to .projectIDE config file.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (let* ((cache (make-projectIDE-cache))
         (project (projectIDE-parse-config configfile nil (projectIDE-caller 'projectIDE-cache-create caller)))
         (signature (projectIDE-project-signature project))
         (projectRoot (projectIDE-record-path (gethash signature projectIDE-runtime-record)))
         (file (concat PROJECTIDE-CACHE-PATH signature))
         (exclude (projectIDE-project-exclude project))
         (exclude-modified (projectIDE-manipulate-filter projectRoot exclude))
         (whitelist (projectIDE-project-whitelist project))
         (whitelist-modified (projectIDE-manipulate-filter projectRoot whitelist)))
    
    (setf (projectIDE-cache-project cache) project
          (projectIDE-cache-exclude cache) exclude
          (projectIDE-cache-whitelist cache) whitelist
          (projectIDE-cache-file-cache cache) (fdex-new projectRoot exclude-modified whitelist-modified)
          (projectIDE-cache-config-update-time cache) (current-time))
    
    (fout<<projectIDE file 'cache (projectIDE-caller 'projectIDE-cache-create caller)))
  
  (when projectIDE-debug-mode
    (projectIDE-message 'Info
                        (format "Project cache created for \"%s\"" configfile)
                        nil
                        (projectIDE-caller 'projectIDE-cache-create caller))))



(defun projectIDE-consolidate-record ()

  "Remove invalid or expired projectIDE-record."

  (let ((signatures (projectIDE-get-all-signatures)))

    (dolist (signature signatures)
      (unless (projectIDE-get-project-path signature)
        (projectIDE-remove-record signature)))

    (setq signatures (projectIDE-get-all-signatures))

    (when (>= (length signatures) projectIDE-max-record-number)
      ;; sorted to older first
      (setq signatures (sort signatures (lambda (signature1 signature2) (time-less-p signature1 signature2))))
      (dotimes (var (- (length signatures) (- projectIDE-max-record-number projectIDE-record-reduce-number)))
        (projectIDE-remove-record (nth var signatures))))

    (fout<<projectIDE PROJECTIDE-RECORD-FILE 'projectIDE-runtime-record (projectIDE-caller 'projectIDE-consolidate-record))))



(defun projectIDE-identify-project (&optional buffer caller)
  ;; If buffer is not provided, it implies this function is possibily call by find-file-hook
  ;; With buffer provided it means this function is possibilty call by projectIDE-initialize or projectIDE-index-project
  ;; to check all existing buffers
  "This function check whether BUFFER is a indexed project.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

If it is a indexed project, it ensures
1) the project is under projectIDE-runtime-cache
2) it is under opened buffer in the project cache
3) it is under projectIDE-runtime-Btrace

If BUFFER is not provided, current buffer is used.

BUFFER
Type\t\t: buffer
Descrip.:\t The buffer being identified.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (let (signature)

    ;; Comment out this so that project in project identified as the inner project
    ;; Find project in projectIDE-runtime-cache
    ;; (let ((opened-project (projectIDE-get-all-caching-signature)))
    ;;   (while (and (not signature) (buffer-file-name buffer) (car opened-project))
    ;;     (when (string-prefix-p (projectIDE-get-project-path (car opened-project)) (buffer-file-name buffer))
    ;;       (setq signature (car opened-project)))
    ;;     (setq opened-project (cdr opened-project))))

    ;; Search in project RECORD
    (unless signature
      (when (buffer-file-name buffer)
        (setq signature (projectIDE-get-signature-by-path (buffer-file-name buffer)))))

    ;; Search .projectIDE up directory
    ;; Only apply to call where buffer is not provided
    (unless (or buffer signature)
      (let ((search-countdown projectIDE-config-file-search-up-level)
            (path (file-name-directory (buffer-file-name))))
        
        (while (and (not signature) (> search-countdown 0))
          (when (file-exists-p (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
            (let* ((projectRoot (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
                   (project (projectIDE-parse-config projectRoot nil (projectIDE-caller 'projectIDE-identify-project caller))))

              (if (projectIDE-project-signature project)
                  ;; found .projectIDE with signature
                  (progn
                    (setq signature (projectIDE-project-signature project))
                    (projectIDE-record-create projectRoot (projectIDE-caller 'projectIDE-identify-project caller))
                    (unless (file-exists-p (concat PROJECTIDE-CACHE-PATH signature))
                      (projectIDE-cache-create projectRoot (projectIDE-caller 'projectIDE-identify-project caller))))

                ;; found .projectIDE without signature
                (if (y-or-n-p
                     (projectIDE-message
                      'Info
                      (format ".projectIDE root file found at \"%s\".\nMake this path as project root and index the project? " path)
                      nil
                      (projectIDE-caller 'projectIDE-identify-project '(find-file-hook))))
                    (progn
                      (projectIDE-new-project path (and projectIDE-debug-mode (list 'projectIDE-identify-project 'find-file-hook)))
                      (setq signature (projectIDE-get-signature-by-path (buffer-file-name buffer)))
                      (projectIDE-message
                       'Info
                       (format "Project Indexed\nProject\t\t\t\t: %s\nProject Directory\t: %s"
                               (file-name-nondirectory (directory-file-name (file-name-directory projectRoot))) path)
                       t
                       (projectIDE-caller 'projectIDE-identify-project '(find-file-hook))))

                  (projectIDE-message 'Info
                                      "File opened without indexing."
                                      t
                                      (projectIDE-caller 'projectIDE-identify-project '(find-file-hook)))
                  (setq search-countdown -1)))))
          
          (setq search-countdown (1- search-countdown)
                path (file-name-directory (directory-file-name path))))))
    
    ;; When buffer is identified,
    ;; adds project to projectIDE-runtime-Btrace
    ;; ensures the project is in projectIDE-runtime-cache
    ;; adds to opened buffer in projectIDE-runtime-cache
    ;; update the last-open time of project record
    (when signature
      (projectIDE-track-buffer signature buffer (projectIDE-caller 'projectIDE-identify-project (or caller '(find-file-hook))))
      (unless buffer
        (projectIDE-message
         'Info
         (format "Opened file from project [%s]" (projectIDE-get-project-name signature))
         t
         (projectIDE-caller 'projectIDE-identify-project (or caller '(find-file-hook))))))
    
    (when (and projectIDE-debug-mode (not signature))
      (projectIDE-message
       'Info
       (format "Opened buffer \"%s\" is not a indexed project." (or (buffer-file-name) "invalid buffer"))
       nil
       (projectIDE-caller 'projectIDE-identify-project (or caller '(find-file-hook)))))))



(defun projectIDE-index-project (path &optional caller)
  
  "This is an interactive function to let user indexing a project.
It will ask for a project root (PATH) and indexing starts there.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

PATH
Type:\t\t string of directory
Descrip.:\t Path to be indexed as project root.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (interactive (list (read-directory-name "Choose the project root: "
                                          (file-name-directory (or (buffer-file-name) user-emacs-directory)))))

  (catch 'Error
    (unless (projectIDE-initialize-maybe)
      (projectIDE-message 'Error
                          "projectIDE not initialized."
                          t
                          (projectIDE-caller 'projectIDE-index-project caller))
      (throw 'Error nil))
    
    ;; Index project
    (if (and (file-exists-p (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
             (projectIDE-project-signature
              (projectIDE-parse-config (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER)
                                       nil
                                       (projectIDE-caller 'projectIDE-index-project caller))))
        (if (yes-or-no-p
             (concat (projectIDE-message 'Warning
                                         (format ".projectIDE with signature found at \"%s\"" path)
                                         nil
                                         (projectIDE-caller 'projectIDE-index-project caller))
                     "\nChoose yes if you want to create a new signature for this project.
                      Choose no if you want to retain current signature.
                      Press C-g to cancel the operation."))
            
            (projectIDE-new-project (file-name-as-directory path) (projectIDE-caller 'projectIDE-index-project caller))
          
          (projectIDE-record-create (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER) (projectIDE-caller 'projectIDE-index-project caller))
          (projectIDE-cache-create (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER) (projectIDE-caller 'projectIDE-index-project caller)))
      
      (projectIDE-new-project (file-name-as-directory path) (projectIDE-caller 'projectIDE-index-project caller)))
    
    ;; Scan through buffers to check whether they are memeber of newly indexed project
    (let ((buffers (buffer-list)))
      (dolist (buffer buffers)
        (projectIDE-identify-project buffer (projectIDE-caller 'projectIDE-index-project caller))))
    
    (projectIDE-message 'Info
                        (format "Project Indexed\nProject\t\t\t\t: %s\nProject Directory\t: %s"
                                (projectIDE-project-name (projectIDE-parse-config (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER)))
                                path)
                        t
                        (projectIDE-caller 'projectIDE-index-project caller))))

;; Indexing function ends ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















;; Caching function ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;fff (defun projectIDE-config-need-update? (signature &optional caller))
;;fff (defun projectIDE-filter-changed? (signature &optional caller))
;;fff (defun projectIDE-update-project-config (signature &optional ErrorMessage caller))
;;fff (defun projectIDE-update-cache-backend (signature &optional caller))
;;fff (defun projectIDE-background-update-cache ())
;;fff (defun projectIDE-update-cache ()) - I
;;fff (defun projectIDE-track-buffer (signature &optional buffer caller))
;;fff (defun projectIDE-untrack-buffer (&optional buffer caller))
;;fff (defun projectIDE-before-save-new-file ())
;;fff (defun projectIDE-after-save-new-file ())
;;fff (defun projectIDE-before-emacs-kill ())

(defun projectIDE-config-need-update? (signature &optional caller)
  
  "Return t if config file of given SIGNATURE need to be updated.
The config file needs to be updated iif its modification time is
later than the last config update time in cache.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

Return
Type:\t\t bool
Descrip.:\t t if config file needs update, otherwise nil.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (catch 'Error
    (unless (projectIDE-get-cache signature)
      (projectIDE-message 'Warning
                          (format "Project cache for \"%s\" not in projectIDE-runtime-cache." signature)
                          nil
                          (projectIDE-caller 'projectIDE-config-need-update? caller))
      (throw 'Error nil))
    
    (let ((config (projectIDE-get-config-file-path signature)))
      (if config
          (if (time-less-p (projectIDE-get-config-update-time signature)(fdex-modify-time config))
              t
            nil)
        (when projectIDE-debug-mode
          (projectIDE-message 'Warning
                              (format "Unable to find project config file for \"%s\"" signature)
                              nil
                              (projectIDE-caller 'projectIDE-config-need-update? caller)))
        nil))))



(defun projectIDE-filter-changed? (signature &optional caller)
  
  "Return t if exclude or whitelist changed in project given by SIGNATURE.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

Return
Type:\t\t bool
Descri.:\t t if either exclude or whitelist had changed.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (catch 'Error
    (unless (projectIDE-get-cache signature)
      (projectIDE-message 'Warning
                          (format "Project cache for %s not in projectIDE-runtime-cache." signature)
                          nil
                          (projectIDE-caller 'projectIDE-filter-changed? caller))
      (throw 'Error nil))
    
    (if (and (equal (projectIDE-get-project-exclude signature) (projectIDE-get-cache-exclude signature))
             (equal (projectIDE-get-project-whitelist signature) (projectIDE-get-cache-whitelist signature)))
        nil
      t)))



(defun projectIDE-update-project-config (signature &optional ErrorMessage caller)
  
  "Update specific project config in projectIDE-runtime-cache.
The project updated is specified by SIGNATURE.

ERRORMESSAGE indicates whether message is displayed to minibuffer
if there is any error.  Error message is not displayed by default.

This function return t if the project config is updated successfully.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

Return
Type:\t\t bool
Descrip.: Return t if config is updated successfully.  Otherwise, return nil.

SIGNATURE
Type:\t\t string
Descrip.:\t String of number of signature.

ERRORMESSAGE
Type:\t\t bool
Descrip.: Display error message to minibuffer if it is t.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (catch 'Error
    (let* ((project-config-file (projectIDE-get-config-file-path signature))
           (project (projectIDE-parse-config project-config-file nil (projectIDE-caller 'projectIDE-update-project-config caller))))

      (unless project
        (projectIDE-message 'Error
                            (format "Update project config failed. Error reading \"%s\"." project-config-file)
                            ErrorMessage
                            (projectIDE-caller 'projectIDE-update-project-config caller))
        (throw 'Error nil))
      
      (unless (equal (projectIDE-project-name project) (projectIDE-get-project-name signature))
        (projectIDE-set-project-name signature (projectIDE-project-name project))
        (fout<<projectIDE PROJECTIDE-RECORD-FILE 'projectIDE-runtime-record (projectIDE-caller 'projectIDE-update-project-config caller)))
      
      (projectIDE-set-cache-project signature project))
    
    (when projectIDE-debug-mode
      (projectIDE-message 'Info
                          (format "Project config for project \"%s\" update successfully."
                                  (projectIDE-get-project-name signature))
                          nil
                          (projectIDE-caller 'projectIDE-update-project-config caller)))
    t))



(defun projectIDE-update-cache-backend (signature &optional caller)
  
  "Perform a complete update on cache given by SIGNATURE.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (catch 'Error
    ;; Test whether signature is in projectIDE-runtime-cache
    (unless (projectIDE-get-cache signature)
      (projectIDE-message 'Error
                          (format "Attempt to update cache \"%s\" not in projectIDE-runtime-cache." signature)
                          nil
                          (projectIDE-caller 'projectIDE-update-cache-backend caller))
      (throw 'Error nil))
    
    ;; Test whether config file need to be update and is able to update
    (when (projectIDE-config-need-update? signature (projectIDE-caller 'projectIDE-update-cache-backend caller))
      (unless (projectIDE-update-project-config signature nil (projectIDE-caller 'projectIDE-update-cache-backend caller))
        (projectIDE-message 'Error
                            (format "Project config file for project %s not found." signature)
                            nil
                            (projectIDE-caller 'projectIDE-update-cache-backend caller))
        (throw 'Error nil))
      (run-hooks 'projectIDE-config-updated-hook))
    
    (when (projectIDE-filter-changed? signature (projectIDE-caller 'projectIDE-update-cache-backend caller))
      (projectIDE-set-cache-filter signature)
      (projectIDE-set-file-cache signature)
      (projectIDE-set-file-cache-state signature 0))
    
    (with-temp-message
        (projectIDE-message 'Info
                            "Updating cache in progress. May take some time for large project."
                            nil
                            (projectIDE-caller 'projectIDE-update-cache-backend caller))
      (fdex-update (projectIDE-get-file-cache signature)))
    
    (projectIDE-set-file-cache-state signature 2)
    
    t))



(defun projectIDE-background-update-cache ()

  "Update cache of current buffer in background by one step."
  
  (catch 'quit
    (let ((signature projectIDE-active-project)
          state
          cache
          filehash)
      
      (when signature
        (unless (projectIDE-background-update-cache? signature)
          (throw 'quit nil))

        (when (projectIDE-config-need-update? signature (projectIDE-caller 'projectIDE-background-update-cache))
          (projectIDE-update-project-config signature nil (projectIDE-caller 'projectIDE-background-update-cache))
          (run-hooks 'projectIDE-config-updated-hook))

        (setq state (projectIDE-get-file-cache-state signature))
        
        (cond
         ((= state 0)
          (setq filehash (projectIDE-get-file-cache signature))
          (unless (fdex-updateNext filehash)
            (fdex-updateRoot filehash)
            (projectIDE-set-file-cache-state signature 1)))
         ((= state 1)
          (setq filehash (projectIDE-get-file-cache signature))
          (unless (fdex-updateNext filehash)
            (fdex-updateRoot filehash)
            (projectIDE-set-file-cache-state signature 2)
            (when (projectIDE-background-generate-association? signature)
              (projectIDE-flag-association-expired signature))))
         ((= state 2)
          (unless (projectIDE-background-generate-association? signature)
            (projectIDE-set-file-cache-state signature 1)
            (throw 'quit nil))
          
          (let ((buffers (projectIDE-get-buffer-list signature))
                (time (current-time))
                done)
            (while (and (car buffers) (not done))
              (unless (projectIDE-get-file-association-state (car buffers))
                (projectIDE-set-file-association (projectIDE-generate-association-list (car buffers)) (car buffers))
                (setq done t))
              (setq buffers (cdr buffers)))
            (unless done
              (projectIDE-set-file-cache-state signature 1))
            (when (> (time-to-seconds (time-subtract (current-time) time)) 1)
              (projectIDE-message 'Warning
                                  (format "projectIDE detects background service has been causing performance issue.
You may try setting \"cachemode = 15\" or even  \"cachemode = 7\" in [%s] config file." (projectIDE-get-project-name signature))
                                  t
                                  (projectIDE-caller 'projectIDE-background-update-cache))))))))))



(defun projectIDE-update-cache ()
  
  "An interactive function to update project cache of current buffer.
In simple term, it updates folders and files of the project."
  
  (interactive)
  (catch 'Error
    (unless (projectIDE-initialize-maybe)
      (projectIDE-message 'Error
                          "projectIDE not initialized."
                          t
                          (projectIDE-caller 'projectIDE-update-cache))
      (throw 'Error nil))
    
    (let ((signature projectIDE-active-project))
      (unless signature
        (projectIDE-message 'Warning
                            "Current buffer not in project record."
                            t
                            (projectIDE-caller 'projectIDE-update-cache))
        (throw 'Error nil))
      
      (projectIDE-update-cache-backend signature (projectIDE-caller 'projectIDE-update-cache))
      
      (when projectIDE-debug-mode
        (projectIDE-message 'Info
                            (format "Updated project cache for project \"%s\"" signature)
                            nil
                            (projectIDE-caller 'projectIDE-update-cache))))
    t))



(defun projectIDE-track-buffer (signature &optional buffer caller)
  
  "Track BUFFER as a member of project given by SIGNATURE.

Tracking means
1) put buffer in projectIDE-runtime-BTrace
2) add buffer filename to opened buffer in projectIDE-runtime-record.
If buffer is not provide, current buffer is used.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

BUFFER
Type\t\t: buffer
Descrip.:\t The buffer being identified.
\t\t\t If buffer is not provide, current buffer is used.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (projectIDE-push-Btrace signature buffer)
  
  (unless (projectIDE-get-cache signature)
    (let (cache)
      (fin>>projectIDE (concat PROJECTIDE-CACHE-PATH signature) 'cache (projectIDE-caller 'projectIDE-track-buffer caller))     
      (projectIDE-push-cache signature cache)

      (unless (equal (fdex-get-rootPath (projectIDE-get-file-cache signature)) (projectIDE-get-project-path signature))
        (projectIDE-set-file-cache signature))

      (when (projectIDE-get-opened-buffer signature)
        (projectIDE-clear-opened-buffer signature)))
    
    (if (projectIDE-open-project-update-cache? signature)
        (projectIDE-update-cache-backend signature (projectIDE-caller 'projectIDE-track-buffer caller))
      (projectIDE-set-file-cache-state signature 0))

    (setq projectIDE-active-project signature)
    (run-hooks 'projectIDE-open-project-hook))
  
  (projectIDE-add-opened-buffer signature (buffer-file-name buffer))
  (projectIDE-set-project-last-open signature)
  (run-hooks 'projectIDE-open-project-buffer-hook))



(defun projectIDE-untrack-buffer (&optional buffer caller)
  
  "Untrack BUFFER as from project given by SIGNATURE.
It is designed to add to `kill-buffer-hook' as well.

Untrack means
1) remove buffer from projectIDE-runtime-BTrace
2) remove buffer filename from opened buffer in projectIDE-runtime-record.
If buffer is not provide, current buffer is used.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

SIGNATURE
Type:\t\t string
Descrip.:\t A project based unique ID.

BUFFER
Type\t\t: buffer
Descrip.:\t The buffer being identified.
\t\t\t If buffer is not provide, current buffer is used.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."

  (let ((signature (projectIDE-get-Btrace-signature buffer)))
    (when signature
      (run-hooks 'projectIDE-kill-project-buffer-hook)
      
      (when (projectIDE-get-cache signature)
        (if (> (length (projectIDE-get-opened-buffer signature)) 1)
            (projectIDE-remove-opened-buffer signature (buffer-file-name buffer))
          (run-hooks 'projectIDE-close-project-hook)
          (projectIDE-pop-cache signature)))

      (projectIDE-pop-Btrace buffer))))



(defun projectIDE-before-save-new-file ()
  
  "This function is designed to add to `before-save-hook'.
It detects whether the newly created file is a member of a project.
It also test whether the project enabled background caching.
If yes, it will flag the file to be priority caching
at `projectIDE-after-save-new-file'."
  
  (let ((signature (projectIDE-get-signature-by-path (buffer-file-name))))
    (when (and signature
               (not (file-exists-p (buffer-file-name)))
               (projectIDE-background-update-cache? signature))
      (setq projectIDE-priority-update-file (list signature (buffer-file-name))))))



(defun projectIDE-after-save-new-file ()

  "This function is designed to add to `after-save-hook'.
It flags the newly created file to cache at priority."
  
  (when (and projectIDE-priority-update-file (equal (cdr projectIDE-priority-update-file) (buffer-file-name)))
    (projectIDE-track-buffer (car projectIDE-priority-update-file) (cdr projectIDE-priority-update-file))
    (fdex-add-priority-update-path (projectIDE-get-file-cache (car projectIDE-priority-update-file))
                                   (file-name-directory (buffer-file-name)))
    (when (projectIDE-get-file-association)
      (projectIDE-set-file-association (projectIDE-add-to-list (projectIDE-get-file-association) (buffer-file-name)))))
  (setq projectIDE-priority-update-file nil))



(defun projectIDE-before-emacs-kill (&optional ARG)
  
  "Write all cache in projectIDE-runtime-cache to harddisk.
This function is designed to advice before `save-buffers-kill-emacs'."
  
  (let ((signatures (projectIDE-get-all-caching-signature)))
    (dolist (signature signatures)
      (let ((cache (projectIDE-get-cache signature)))
        (with-temp-message
            (projectIDE-message 'Info
                                (format "Saving caching for [%s] ... " (projectIDE-get-project-name signature))
                                nil
                                (projectIDE-caller 'projectIDE-before-emacs-kill '(save-buffers-kill-emacs-hook)))
         (fout<<projectIDE (concat PROJECTIDE-CACHE-PATH signature) 'cache (projectIDE-caller 'projectIDE-track-buffer '(save-buffers-kill-emacs)))))))
  (setq projectIDE-write-out-cache nil)
  (save-some-buffers nil t)
  (dolist (buffer (projectIDE-get-buffer-list))
    (kill-buffer buffer))
  (projectIDE-terminate))

;; Caching function ends ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~





















;;; Fetching data function ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;fff (defun projectIDE-open-project (&optional caller)) - I
;;fff (defun projectIDE-get-folder-list (signature &optional full filter caller))
;;fff (defun projectIDE-open-folder (prefix &optional otherwindow)) -I
;;fff (defun projectIDE-open-folder-other-window (prefix)) - I
;;fff (defun projectIDE-get-file-list (signature &optional full filter caller))
;;fff (defun projectIDE-open-file (prefix)) - I
;;fff (defun projectIDE-open-file-other-window (prefix)) - I
;;fff (defun projectIDE-generate-association-list (&optional buffer))
;;fff (defun projectIDE-switch-association (prefix)) -I
;;fff (defun projectIDE-switch-association-other-window (prefix)) - I
;;fff (defun projectIDE-close-project ()) -I
;;fff (defun projectIDE-switch-project-buffer (prefix)) -I
;;fff (defun projectIDE-open-config-file ()) -I

(defun projectIDE-open-project (&optional caller)
  
  "Open certain project with user prompt.

CALLER is the function list calling this function.
It is uesed for debugging purpose.

CALLER
Type:\t\t symbol list
Descrip.:\t Function list calling this function for debug purpose."
  
  (interactive)
  (catch 'Error
    (unless (projectIDE-initialize-maybe)
      (projectIDE-message 'Error
                          "projectIDE not initialized."
                          t
                          (projectIDE-caller 'projectIDE-open-project caller))
      (throw 'Error nil))
    
    (let (promptlist
          choices)

      ;; Get all project singnatures sorted by last open time
      (setq promptlist
            (sort (projectIDE-get-all-signatures)
                  (lambda (record1 record2)
                    (time-less-p (projectIDE-get-project-last-open record1)
                                 (projectIDE-get-project-last-open record2)))))

      ;; Get the prompting alist
      (cond
       ((eq projectIDE-open-project-prompt-type 'path)
        (setq promptlist (projectIDE-generate-prompt-alist promptlist
                                                           :display-function 'projectIDE-get-project-path
                                                           :duplicate-function projectIDE-open-project-prompt-resolve-duplicate)))
       (t
        (setq promptlist (projectIDE-generate-prompt-alist promptlist
                                                           :display-function 'projectIDE-get-project-name
                                                           :duplicate-function projectIDE-open-project-prompt-resolve-duplicate))))

      ;; Get the project singature with user prompt
      (setq choices (projectIDE-prompt "Choose project: " (projectIDE-detach-prompt-alist promptlist) nil t))

      (unless (listp choices)
        (setq choices (list choices)))

      (dolist (choice choices)
        (let (signature
              projectRoot
              cache
              opened-buffer)

          (catch 'project-error
            (setq signature (projectIDE-resolve-prompt-result choice promptlist))
            (setq projectRoot (projectIDE-get-project-path signature))
            
            ;; Check whether project has been opened
            ;; If yes, just open the last opened buffer
            (when (projectIDE-get-cache signature)
              (find-file (car (projectIDE-get-opened-buffer signature)))
              (projectIDE-message 'Info
                                  (format "Project [%s] had been opened already." (projectIDE-get-project-name signature))
                                  t
                                  (projectIDE-caller 'projectIDE-open-project caller))
              (throw 'project-error nil))
            
            ;; Check whether .projectIDE exists under path
            (unless (file-exists-p (concat projectRoot PROJECTIDE-PROJECTROOT-IDENTIFIER))
              (projectIDE-message 'Warning
                                  (format ".projectIDE file not exists under \"%s\".
If you moved the project, you can use `projectIDE-index-project' to reindex it." projectRoot)
                                  t
                                  (projectIDE-caller 'projectIDE-open-project caller))
              (throw 'project-error nil))
            
            ;; Check whether .projectIDE is able to be parsed
            (unless (projectIDE-parse-config (concat projectRoot PROJECTIDE-PROJECTROOT-IDENTIFIER))
              (projectIDE-message 'Error
                                  (format "Open project terminated due to .projectIDE file under \"%s\" corrupted." projectRoot)
                                  t
                                  (projectIDE-caller 'projectIDE-open-project caller))
              (throw 'project-error nil))
            
            ;; check if there is cache file
            (unless (file-exists-p (concat PROJECTIDE-CACHE-PATH signature))
              (projectIDE-cache-create projectRoot))
            
            ;; check if cache load successfully
            (unless (fin>>projectIDE (concat PROJECTIDE-CACHE-PATH signature) 'cache (projectIDE-caller 'projectIDE-open-project caller))
              (projectIDE-message 'Error
                                  (format "Unable to load project cache: [%s] \"%s\"" (projectIDE-get-project-name signature) signature)
                                  t
                                  (projectIDE-caller 'projectIDE-open-project caller))
              (throw 'project-error nil))
            
            (setq opened-buffer (nreverse (copy-tree (projectIDE-cache-opened-buffer cache))))
            (if (and opened-buffer projectIDE-open-last-opened-files)
                (dolist (file opened-buffer)
                  (when (file-readable-p file)
                    (find-file file)))
              (projectIDE-dired projectRoot))
            (unless (equal (projectIDE-get-Btrace-signature) signature)
              (projectIDE-dired projectRoot))))))))



(defun projectIDE-open-folder (prefix &optional otherwindow)
  
  "An interative function to prompt a folder for opening.
The folder list prompted contains folders from project of current buffer.

When PREFIX is provided, it will ask for regexp first to get interseted list
of prompt.
When OTHERWINDOW is provided, the folder will be open on other window."
  
  (interactive "p")
  (catch 'Error
    (unless (projectIDE-initialize-maybe)
      (projectIDE-message 'Error
                          "projectIDE not initialized."
                          t
                          (projectIDE-caller 'projectIDE-open-folder))
      (throw 'Error nil))

    (unless projectIDE-active-project
      (projectIDE-message 'Info
                          "Current buffer is not a projectIDE project."
                          t
                          (projectIDE-caller 'projectIDE-open-folder))
      (throw 'Error nil))
    
    (lexical-let ((signature projectIDE-active-project)
                  regexp ;; need lexical-let
                  project-prefix
                  promptlist
                  choices)
      
      ;; When prefixed, asked for regexp to fetch interested prompt list
      (unless (= prefix 1)
        (setq regexp (read-string "Regexp to search folder: ")))
      (when (equal "" regexp)
        (setq regexp nil))
      
      ;; Determined if project prefix should be used
      (when projectIDE-use-project-prefix
        (setq project-prefix
              (concat (file-name-as-directory (concat "[" (projectIDE-get-project-name signature) "] ")) " ")))

      ;; Update cache pre prompt
      (when (projectIDE-pre-prompt-update-cache? signature)
        (projectIDE-update-cache-backend signature (projectIDE-caller 'projectIDE-open-folder)))

      (if project-prefix
          (if regexp
              (setq promptlist
                    (projectIDE-get-folder-list signature
                                                nil
                                                (lambda (elt)
                                                  (if (string-match regexp elt) t nil))
                                                (projectIDE-caller 'projectIDE-open-folder)))
            (setq promptlist
                    (projectIDE-get-folder-list signature
                                                nil
                                                nil
                                                (projectIDE-caller 'projectIDE-open-folder))))
        (if regexp
              (setq promptlist
                    (projectIDE-get-folder-list signature
                                                t
                                                (lambda (elt)
                                                  (if (string-match regexp elt) t nil))
                                                (projectIDE-caller 'projectIDE-open-folder)))
            (setq promptlist
                    (projectIDE-get-folder-list signature
                                                t
                                                nil
                                                (projectIDE-caller 'projectIDE-open-folder)))))

      (if project-prefix
          (setq promptlist (projectIDE-generate-prompt-alist promptlist
                                                             :display-function (lambda (elt) (concat project-prefix elt))
                                                             :duplicate-function 'inhabit))
        (setq promptlist (projectIDE-generate-prompt-alist promptlist)))

      (setq choices (projectIDE-prompt "Open folder: " (projectIDE-detach-prompt-alist promptlist) nil t))
      
      (unless (listp choices)
        (setq choices (list choices)))

      (dolist (choice choices)
        (catch 'folder-error
          (let ((folder (projectIDE-resolve-prompt-result choice promptlist)))

            (unless (file-exists-p folder)
              (projectIDE-message 'Warning
                                  (format "%s no longer exist.\nYou may need to call `projectIDE-update-cache' first." choice)
                                  t
                                  'projectIDE-open-folder)
              (throw 'folder-error nil))

            (when otherwindow
              (projectIDE-other-window))
            
            (projectIDE-dired folder)))))))





(defun projectIDE-open-folder-other-window (prefix)
  
  "Wrapper of `projectIDE-open-folder' to open file
in other window."

  (interactive "p")
  (funcall 'projectIDE-open-folder prefix t))



(defun projectIDE-open-file (prefix &optional otherwindow)
  
  "An interative function to prompt a file for opening.
The file list prompted contains files from project of current buffer.
Unless current buffer is not a recorded project,
it will project for all files form opened projects instesd.
When PREFIX is provided, the file list contains files from all opened projects.
When OTHERWINDOW is provided, the file will be open on other window."
  
  (interactive "p")
  (catch 'Error
    (unless (projectIDE-initialize-maybe)
      (projectIDE-message 'Error
                          "projectIDE not initialized."
                          t
                          (projectIDE-caller 'projectIDE-open-file))
      (throw 'Error nil))

    
    
    (let (sources
          prompt
          project-prefix
          choice)
      
      ;; When prefixed, open file from all current opened project.
      (if (not (= prefix 1))
          (setq sources (projectIDE-get-all-caching-signature))
        (setq sources (list projectIDE-active-project))
        (unless (car sources)
          (setq sources (projectIDE-get-all-caching-signature))))
      
      (unless (car sources)
        (projectIDE-message 'Warning
                            "Current buffer is not an indexed project."
                            t
                            (projectIDE-caller 'projectIDE-open-file))
        (throw 'Error nil))

            
      ;; Determined if project prefix should be used
      (when (and projectIDE-use-project-prefix (= (length sources) 1))
        (setq project-prefix
              (concat (file-name-as-directory (concat "[" (projectIDE-get-project-name (car sources)) "] ")) " ")))
      
      ;; Create promt-file-list from different source
      (dolist (source sources)
        (if project-prefix
            (progn
              ;; Update cache pre prompt
              (when  (projectIDE-pre-prompt-update-cache? source)
                (projectIDE-update-cache-backend source (projectIDE-caller 'projectIDE-open-file)))
              
              (setq prompt (projectIDE-get-file-list source nil nil (projectIDE-caller 'projectIDE-open-file)))
              (setq prompt (mapcar (apply-partially 'concat project-prefix) prompt)))
          ;; Update cache pre prompt
          (when  (projectIDE-pre-prompt-update-cache? source)
            (projectIDE-update-cache-backend source (projectIDE-caller 'projectIDE-open-file)))
          (setq prompt (nconc prompt (projectIDE-get-file-list source t nil (projectIDE-caller 'projectIDE-open-file))))))
      
      (setq choice (projectIDE-prompt "Open file: " prompt))
      
      (when project-prefix
        (setq choice 
              (concat
               (projectIDE-get-project-path (car sources))
               (string-remove-prefix project-prefix choice))))
      
      (unless (file-exists-p choice)
        (projectIDE-message 'Warning
                            (format "%s no longer exist.\nYou may need to call `projectIDE-update-cache' first." choice)
                            t
                            'projectIDE-open-file)
        (throw 'Error nil))

      (when otherwindow
        (projectIDE-other-window))
      
      (find-file choice))))



(defun projectIDE-open-file-other-window (prefix)
  
  "Wrapper of `projectIDE-open-file' to open file
in other window."

  (interactive "p")
  (funcall 'projectIDE-open-file prefix t))



(defun projectIDE-generate-association-list (&optional buffer)
  
  "Return a list of files which have same filename as BUFFER.

Return
Type:\t\t list of string
Descrip.:\t A list of file paths having same filename as BUFFER.

BUFFER
Type:\t\t buffer
Descrip.:\t The buffer being identified.
\t\t\t If BUFFER is not provided, current buffer is used."
  
  (let* ((signature (projectIDE-get-Btrace-signature (or buffer (current-buffer))))
         (filename (file-name-nondirectory (buffer-file-name (or buffer (current-buffer)))))
         regexp)
    
    (while (not (equal filename (file-name-sans-extension filename)))
      (setq filename (file-name-sans-extension filename)))
    
    (setq regexp (concat (file-name-as-directory ".*\\")
                         filename
                         (file-name-as-directory "\\.+[^\\")
                         "]*$"
                         "\\|"
                         (file-name-as-directory ".*\\")
                         filename
                         "$"))
    
    (projectIDE-get-file-list signature t
                              (lambda (test) (string-match regexp test))
                              (projectIDE-caller 'projectIDE-generate-association-list))))



(defun projectIDE-switch-association (prefix &optional otherwindow)
  
  "An interactive function to switch across associated files in project.
When PREFIX is not supplied, it switches to next associated file.
When FREFIX is supplied, it prompts a list of associated files.
When OTHERWINDOW is provided , associated file is opened in other window."

  (interactive "p")

  (catch 'Error
    (unless (projectIDE-initialize-maybe)
      (projectIDE-message 'Error
                          "projectIDE not initialized."
                          t
                          (projectIDE-caller 'projectIDE-switch-association))
      (throw 'Error nil))
    
    (let ((signature (projectIDE-get-Btrace-signature))
          (filelist (projectIDE-get-file-association)))
      
      (unless signature
        (projectIDE-message 'Warning
                            (format "[%s] is not in an indexed project." (buffer-file-name))
                            t
                            (projectIDE-caller 'projectIDE-switch-association))
        (throw 'Error nil))
      
      (unless (and filelist (projectIDE-get-file-association-state))
        (when (projectIDE-pre-prompt-update-cache? signature)
             (projectIDE-update-cache-backend signature (projectIDE-caller 'projectIDE-switch-association)))
        (with-temp-message
            (projectIDE-message 'Info
                                "Searching file association. May take some time for large project."
                                nil
                                (projectIDE-caller 'projectIDE-switch-association))
            (setq filelist (projectIDE-generate-association-list)))
        (projectIDE-set-file-association filelist))
      
      (if (= (length filelist) 1)
          (projectIDE-message 'Info
                              "No association files found."
                              t
                              (projectIDE-caller 'projectIDE-switch-association))
        (if (= prefix 1)
            (let ((pos (cl-position (buffer-file-name) filelist :test 'equal)))
              (if (= (1+ pos) (length filelist))
                  (find-file (nth 0 filelist))
                (find-file (nth (1+ pos) filelist))))
          (let (choice
                project-prefix
                projectRoot)
            (when projectIDE-use-project-prefix
              (setq projectRoot (projectIDE-get-project-path signature))
              (setq project-prefix
                    (concat (file-name-as-directory (concat "[" (projectIDE-get-project-name signature) "] ")) " "))
              (setq filelist (mapcar (apply-partially 'string-remove-prefix projectRoot) filelist)
                    filelist (mapcar (apply-partially 'concat project-prefix) filelist)))
            
            (setq choice (projectIDE-prompt "Open file: " filelist))
            (when project-prefix
              (setq choice (string-remove-prefix project-prefix choice)
                    choice (concat projectRoot choice)))

            (when otherwindow
              (projectIDE-other-window))
            
            (find-file choice)))))))


(defun projectIDE-switch-association-other-window (prefix)

  "Wrapper of `projectIDE-switch-association' to switch
association at other window."

  (interactive "p")
  (funcall 'projectIDE-switch-association prefix t))



(defun projectIDE-close-project (prefix)

  "An interactive function to close all buffers in current project.
If PREFIX is provided, close all projects."
  
  (interactive "p")
  (catch 'Error
    (unless (projectIDE-initialize-maybe)
      (projectIDE-message 'Error
                          "projectIDE not initialized."
                          t
                          (projectIDE-caller 'projectIDE-close-project))
      (throw 'Error nil))

    (unless (projectIDE-get-Btrace-signature)
      (projectIDE-message 'Info
                          "Current buffer is not a member of a project."
                          t
                          (projectIDE-caller 'projectIDE-close-project))
      (throw 'Error nil))
    
    (setq projectIDE-write-out-cache nil)

    (if (= prefix 1)
        (let* ((signature (projectIDE-get-Btrace-signature))
               (buffers (buffer-list))
               (cache (projectIDE-get-cache signature)))
          (when cache
            (with-temp-message
                (projectIDE-message 'Info
                                    (format "Saving caching for [%s] ... " (projectIDE-get-project-name signature))
                                    nil
                                    (projectIDE-caller 'projectIDE-close-project))
              (fout<<projectIDE (concat PROJECTIDE-CACHE-PATH signature) 'cache (projectIDE-caller 'projectIDE-close-project))))
          (dolist (buffer buffers)
            (when (equal signature (projectIDE-get-Btrace-signature buffer))
              (kill-buffer buffer))))
      
      (let* ((signatures (projectIDE-get-all-caching-signature))
             (buffers (buffer-list))
             cache)
        (dolist (signature signatures)
          (setq cache (projectIDE-get-cache signature))
          (when cache
            (with-temp-message
                (projectIDE-message 'Info
                                    (format "Saving caching for [%s] ... " (projectIDE-get-project-name signature))
                                    nil
                                    (projectIDE-caller 'projectIDE-close-project))
              (fout<<projectIDE (concat PROJECTIDE-CACHE-PATH signature) 'cache (projectIDE-caller 'projectIDE-close-project)))))
        (dolist (buffer buffers)
          (kill-buffer buffer))))
    
    (setq projectIDE-write-out-cache t)))



(defun projectIDE-switch-project-buffer (prefix)

  "An interactive function to switch to buffer of the same project.
If PREFIX is provided, switch to buffer of all opened project."
  
  (interactive "p")

  (catch 'Error
    (unless (projectIDE-initialize-maybe)
      (projectIDE-message 'Error
                          "projectIDE not initialized."
                          t
                          (projectIDE-caller 'projectIDE-switch-project-buffer))
      (throw 'Error nil))
    
    (let (signature buffers choice)
      (when (= prefix 1)
        (setq signature (projectIDE-get-Btrace-signature)))
      (setq buffers (mapcar 'buffer-name (projectIDE-get-buffer-list signature)))

      (unless buffers
        (projectIDE-message 'Info
                            "No avaliable project buffer."
                            t
                            (projectIDE-caller 'projectIDE-switch-project-buffer))
        (throw 'Error nil))

      (setq choice (projectIDE-prompt "Choose buffer: " buffers))
      (switch-to-buffer (get-buffer (buffer-name choice))))))



(defun projectIDE-open-config-file ()

  "An interactive funciton to open config file of current project."

  (interactive)

  (catch 'Error
    (unless (projectIDE-get-Btrace-signature)
      (projectIDE-message 'Info
                          "Current buffer is not a projectIDE project."
                          t
                          (projectIDE-caller 'projectIDE-open-config-file))
      (throw 'Error nil))

    (let ((configfile (projectIDE-get-config-file-path (projectIDE-get-Btrace-signature))))
      (unless (file-exists-p configfile)
        (projectIDE-message 'Warning
                            (format "Config file %s not found." configfile)
                            t
                            (projectIDE-caller 'projectIDE-open-config-file))
        (throw 'Error nil))
      
      (find-file configfile))))



(defun projectIDE-M-x (choice)

  "ProjectIDE command prompt."

  (interactive
   (list (projectIDE-prompt "Command: " projectIDE-M-x-functions)))
  (call-interactively (intern choice)))


(defun projectIDE-go ()
  
  "An interactive function to go file at point."

  (interactive)
  
  (let (candidates
        choices)

    (setq candidates
          (projectIDE-add-to-list
           candidates
           (ffap-file-at-point)))

    (pp candidates)
    
    (dolist (function projectIDE-go-test-function)
      (when (fboundp function)
        (let ((result (funcall function)))
          (if (listp result)
              (setq candidates (projectIDE-append candidates result))
            (setq candidates (projectIDE-add-to-list candidates result))))))

        
    (dolist (elt candidates)
      (if (file-exists-p elt)
          (push elt choices)
        (if (file-exists-p (concat (projectIDE-get-project-path (projectIDE-get-Btrace-signature)) elt))
            (push (concat (projectIDE-get-project-path (projectIDE-get-Btrace-signature)) elt) choices)
          (if (file-exists-p (concat (directory-file-name (projectIDE-get-project-path (projectIDE-get-Btrace-signature))) elt))
              (push (concat (directory-file-name (projectIDE-get-project-path (projectIDE-get-Btrace-signature))) elt) choices)))))
    
    (when (>= (length choices) 1)
      (if (= (length choices) 1)
          (projectIDE-open (car choices))
        (projectIDE-open (projectIDE-prompt "Open file: " choices nil t))))))

;;; Fetching data function ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~




















(cl-defmacro projectIDE-create (projectType &key templateDir defaultDir documentation)
  
  "Create projectIDE-create-X function."
  
  (let* ((projectType (symbol-name projectType))
         (templateDir (file-name-as-directory templateDir))
         (defaultDir (file-name-as-directory defaultDir))
         (documentation (or documentation (format
                                           "Create new \"%s\" project.\nProjectIDE will create a new folder named PROJECTNAME under DIR"
                                           projectType))))
    
    ;; Check if the template directory and default directory exist
    (if (and (file-directory-p templateDir)
             (or (file-directory-p defaultDir)
                 (setq defaultDir (or projectIDE-create-defaultDir user-emacs-directory))))
        
        ;; Function template
        `(defun ,(intern (concat "projectIDE-create-" (downcase projectType))) (projectName dir)
           ;; Documentation
           ,documentation
           ;; Interactive call to ask for project name and project directory
           (interactive (list (read-string "Project Name: ")
                              (read-directory-name "Create project at: " ,defaultDir)))
           (setq dir (file-name-as-directory (expand-file-name dir)))

           (catch 'Error
             ;; Validate input
             ;; Check for initialization
             (unless (projectIDE-initialize-maybe)
               (projectIDE-message 'Error
                                   "projectIDE is not initialized."
                                   nil
                                   (projectIDE-caller 'projectIDE-create))
               (throw 'Error nil))
             
             ;; Prevent null string project name
             (when (string= projectName "")
               (projectIDE-message 'Error
                                   "Project name cannot be empty string."
                                   t
                                   (projectIDE-caller 'projectIDE-create))
               (throw 'Error nil))
             
             ;; Make sure project root directory can be generated
             (when (file-exists-p (concat dir projectName))
               (projectIDE-message 'Error
                                   (format "Folder \"%s\" already exists in \"%s\". Operation cancelled." projectName dir)
                                   t
                                   (projectIDE-caller 'projectIDE-create))
               (throw 'Error nil))
             
             ;; Ask for user prompt
             (unless (or (not projectIDE-create-require-confirm) ;; Confirm project creation guard
                         (y-or-n-p (projectIDE-message
                                    'Info
                                    (format "\nProject\t\t\t\t: %s\nTemplate\t\t\t: %s\nProject Directory\t: %s\nCreate Project ? "
                                            projectName ,templateDir (concat dir projectName))
                                    nil
                                    (projectIDE-caller 'projectIDE-create))))
               (projectIDE-message 'Info
                                   "Projection creation cancelled."
                                   t
                                   (projectIDE-caller 'projectIDE-create))
               (throw 'Error nil))
             
             ;; Project create here
             (let* ((projectRoot (file-name-as-directory (concat dir projectName)))
                    (projectConfig (concat projectRoot PROJECTIDE-PROJECTROOT-IDENTIFIER)))

               ;; Create project structure by template
               (make-directory projectRoot t)
               
               (unless (file-writable-p projectRoot)
                 (projectIDE-message 'Error
                                     (format "Project directory \"%s\" is not writable." dir)
                                     t
                                     (projectIDE-caller 'projectIDE-create))
                 (throw 'Error nil))
               
               (copy-directory ,templateDir projectRoot nil nil t)
               (projectIDE-new-project projectRoot (projectIDE-caller 'projectIDE-create))
               (run-hooks 'projectIDE-project-create-hook)

               (projectIDE-message 'Info
                                   (format "Project Created\nProject\t\t\t\t: %s\nTemplate\t\t\t: %s\nProject Directory\t: %s"
                                           projectName ,templateDir projectRoot)
                                   t
                                   (projectIDE-caller 'projectIDE-create)))))
      
      ;; Macro error message
      (projectIDE-message 'Error
                          (format "Template directory \"%s\" error\nEither not exists, not directory or non-accessible." templateDir)
                          t
                          (projectIDE-caller 'projectIDE-create)))))



(defun projectIDE-backgrounde-update-timer ()

  "A timer function to control background update cache."
  
  (when projectIDE-timer-idle
    (cancel-timer projectIDE-timer-idle)
    (projectIDE-background-update-cache))
  (setq projectIDE-timer-idle
        (run-with-idle-timer (time-add (or (current-idle-time) '(0 0 0 0))
                                       (seconds-to-time projectIDE-update-cache-interval))
                             nil
                             'projectIDE-backgrounde-update-timer)))



(defun projectIDE-initialize ()
  
  "Initialize projectIDE."
  
  (interactive)
  (catch 'Error
    (when projectIDE-p
      (projectIDE-message 'Warning
                          "projectIDE has already initialized."
                          nil
                          (projectIDE-caller 'projectIDE-initialize))
      (throw 'Error nil))
    
    ;; Check whether projectIDE database folder exist
    (unless (file-exists-p projectIDE-database-path)
      (make-directory projectIDE-database-path))
    ;; Check global RECORD file exist
    (unless (file-exists-p PROJECTIDE-RECORD-FILE)
      (write-region "" nil PROJECTIDE-RECORD-FILE t 'inhibit))
    ;; Check global PERSIST MEMORY file exist
    (unless (file-exists-p PROJECTIDE-PERSIST-MEMORY-FILE)
      (write-region "" nil PROJECTIDE-PERSIST-MEMORY-FILE t 'inhibit))
    ;; Check cache folder exist
    (unless (file-exists-p PROJECTIDE-CACHE-PATH)
      (make-directory PROJECTIDE-CACHE-PATH))
    ;; Check log folder exist
    (unless (file-exists-p PROJECTIDE-LOG-PATH)
      (make-directory PROJECTIDE-LOG-PATH))
    
    (if (and (fin>>projectIDE PROJECTIDE-RECORD-FILE 'projectIDE-runtime-record)
             (fin>>projectIDE PROJECTIDE-PERSIST-MEMORY-FILE 'projectIDE-persist-memory))
        (progn
          (unless projectIDE-runtime-record
            (setq projectIDE-runtime-record (make-hash-table :test 'equal :size 40)))
          (unless projectIDE-persist-memory
            (setq projectIDE-persist-memory (make-hash-table :test 'eq :size 100)))
          (setq projectIDE-runtime-cache (make-hash-table :test 'equal :size 20)
                projectIDE-runtime-Btrace (make-hash-table :test 'eq :size 40)
                projectIDE-non-persist-memory (make-hash-table :test 'eq :size 100))

          (projectIDE-consolidate-record)
          
          (add-hook 'find-file-hook 'projectIDE-identify-project)
          (add-hook 'kill-buffer-hook 'projectIDE-untrack-buffer)
          (advice-add 'save-buffers-kill-emacs :before 'projectIDE-before-emacs-kill)
          (add-hook 'before-save-hook 'projectIDE-before-save-new-file)
          (add-hook 'after-save-hook 'projectIDE-after-save-new-file)
          
          (add-to-list 'auto-mode-alist '("\\.projectIDE\\'" . projectIDE-config-mode))

          ;; Two timers are set
          (when projectIDE-enable-background-service
            (setq projectIDE-timer-primary (run-with-idle-timer projectIDE-update-cache-interval t 'projectIDE-backgrounde-update-timer))
            (projectIDE-backgrounde-update-timer))
          
          (setq projectIDE-p t)
          (projectIDE-mode 1)
          
          (let ((buffers (buffer-list)))
            (dolist (buffer buffers)
              (projectIDE-identify-project buffer (projectIDE-caller 'projectIDE-initialize))))

          (when projectIDE-enable-project-mode-line
            (setq-default mode-line-buffer-identification projectIDE-mode-line-buffer-identification))

          (projectIDE-module-initialize)
          (projectIDE-session-initialize)
          (run-hooks 'projectIDE-initialize-hook)

          (projectIDE-message 'Info
                              "projectIDE starts successfully."
                              t
                              (projectIDE-caller 'projectIDE-initialize)))
      
      (projectIDE-message 'Error
                          (format "projectIDE starts fail. Unable to read record file at %s" PROJECTIDE-RECORD-FILE)
                          t
                          (projectIDE-caller 'projectIDE-initialize)))
    projectIDE-p))



(defun projectIDE-terminate ()
  
  "Terminate projectIDE."

  (interactive)
  (projectIDE-module-terminate)
  (projectIDE-session-terminate)
  (when projectIDE-p
    (when projectIDE-timer-primary
      (cancel-timer projectIDE-timer-primary))
    (when projectIDE-timer-idle
      (cancel-timer projectIDE-timer-idle))
    (setq-default mode-line-buffer-identification projectIDE-mode-line-buffer-identification-failback)
    (projectIDE-mode 0)
    (remove-hook 'find-file-hook 'projectIDE-identify-project)
    (remove-hook 'kill-buffer-hook 'projectIDE-untrack-buffer)
    (advice-remove 'save-buffers-kill-emacs  'projectIDE-before-emacs-kill)
    (remove-hook 'before-save-hook 'projectIDE-before-save-new-file)
    (remove-hook 'after-save-hook 'projectIDE-after-save-new-file)
    (setq projectIDE-runtime-record nil
          projectIDE-runtime-cache nil
          projectIDE-runtime-Btrace nil
          projectIDE-runtime-functions nil
          projectIDE-p nil)
    (run-hooks 'projectIDE-terminate-hook)))



(defun projectIDE-initialize-maybe ()
  
  "Try to initialize projectIDE if it has not been initialized.
Return t if projectIDE has been initialized.
Return
Type:\t\t bool
Descrip.:\t Return t if projectIDE has been initialized.
\t\t\t Return nil if projectIDE cannot be initialized."
  
  (if projectIDE-p
      t
    (and projectIDE-auto-initialize-p (projectIDE-initialize))))

(projectIDE-register-Mx
 '(projectIDE-verify-config
   projectIDE-index-project
   projectIDE-update-cache
   projectIDE-open-project
   projectIDE-open-folder
   projectIDE-open-folder-other-window
   projectIDE-open-file
   projectIDE-open-file-other-window
   projectIDE-switch-association
   projectIDE-switch-association-other-window
   projectIDE-close-project
   projectIDE-switch-project-buffer
   projectIDE-open-config-file
   projectIDE-go))

(provide 'projectIDE)
;;; projectIDE.el ends here
