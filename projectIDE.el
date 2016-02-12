;;; projectIDE.el --- project configuration file

;; Copyright (C) 2015 Mola-T
;; Author: Mola-T <Mola@molamola.xyz>
;; URL: https://github.com/mola-T/projectIDE
;; Version: 0.1
;; Package-Requires: ((cl-lib.el "0.5"))
;; Keywords: project, convenience

;;; License:
;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;;; code:
(require 'cl-lib)

;;; Customization
(defgroup projectIDE nil
  "Managing projects like an IDE."
  :tag "projectIDE"
  :group 'tools
  :group 'convenience)
(defgroup projectIDE-global nil
  "Global setting for all projects."
  :tag "Enviroment Values"
  :group 'projectIDE)
(defgroup projectIDE-project-creation nil
  "Setting for creating project."
  :tag "Projection creation"
  :group 'projectIDE)
(defgroup projectIDE-config-file nil
  "Setting for loading individual project config file."
  :tag "Config file settings"
  :group 'projectIDE)
(defgroup projectIDE-hook nil
  "All available projectIDE hooks."
  :tag "Hook"
  :group 'projectIDE)

;;; Variables
;; Global Effective Variable
(defconst PROJECTIDE-PROJECTROOT-IDENTIFIER ".projectIDE"
  "The root file indicator.")

(defcustom projectIDE-database-path
  (file-name-as-directory
   (concat (file-name-as-directory user-emacs-directory) "projectIDE"))
  "Type: string\nPath for storing projectIDE RECORD database."
  :tag "Main database path"
  :type 'directory
  :group 'projectIDE-global)

(defconst PROJECTIDE-RECORD-FILE
  (concat projectIDE-database-path "RECORD")
  "Type: string\nFilename for project record.")

(defconst PROJECTIDE-LOG-FILE
  (concat projectIDE-database-path "log")
  "Type: string\nFilename for projectIDE log file.")

(defcustom projectIDE-log-level 2
  "Logging level specifies what to be logged."
  :tag "Logging level"
  :type '(radio
          (const :tag "Error" 3)
          (const :tag "Warning" 2)
          (const :tag "Info" 1)
          (const :tag "Disable" nil))
  :group 'projectIDE-global)

(defconst PROJECTIDE-CACHE-PATH
  (file-name-as-directory (concat projectIDE-database-path "CACHE"))
  "Type: string\nFolder path to individual project record.")

;; Runtime Variable
(defvar projectIDE-p nil
  "Indicate whether projectIDE is running.
Never attempt to modify it directly.")

(defvar projectIDE-runtime-record nil
  ;; hash table
  ;; key: signature
  ;; value: project-record object
  "Database recording all project.
Never attempt to modify it directly.")

(defvar projectIDE-opened-project nil
  ;; hash table
  ;; key: signature
  ;; value: project object
  "Current opened project.
Never attempt to modify it directly.")

(defvar projectIDE-runtime-cache nil
  ;; hash table-backward-cell
  ;; key: signature
  ;; value: project cache object
  "Individual project cache.
Never attempt to modify it directly."
  )

(defvar projectIDE-buffer-trace
  ;; hash table
  ;; key: buffer
  ;; value: signature
  "Trace buffer which is a projectIDE project.
Never attempt to modify it directly.")

;; Project Creation Variable
(defcustom projectIDE-create-defaultDir (getenv "HOME")
  "Global default project directory.
When creating project, if no specific directory or
invalid default directory is entered, projectIDE uses this
variable as the default directory."
  :tag "Default project directory"
  :type 'directory
  :group 'projectIDE-project-creation)

(defcustom projectIDE-global-project-create-hook nil
  "Hook runs when creating project."
  :tag "projectIDE-global-project-create-hook"
  :type 'hook
  :group 'projectIDE-project-creation
  :group 'projectIDE-hook)

(defcustom projectIDE-create-require-confirm t
  "Require confirmation when creating project?
If this value is nil, projectIDE will skip confirmation
before creating project.
Other values ask for the confirmation."
  :tag "Require confirmation when creating project?"
  :type 'boolean
  :group 'projectIDE-project-creation)

;; Project config file variable
(defconst projectIDE-default-config-key
  '("^signature="
    "^name="
    "^exclude="
    "^whitelist="
    "^inject=")
  "Default projectIDE config file keyword.
Must not change.")

(defun projectIDE-concat-regexp-list (list)
  "Return a single regexp string from a LIST of separated regexp.

Return
Type:\t\t string
Descrip.:\t A single string of combined regexp.
\t\t\t If LIST is empty, return nil.

LIST
Type:\t\t string list
Descrip.:\t A string list of regexp."
  
  (let (regexp)
    (dolist (val list regexp)
      (if regexp
          (setq regexp (concat val "\\|" regexp))
        (setq regexp val)))))

(defvar projectIDE-default-config-key-regexp
  (projectIDE-concat-regexp-list projectIDE-default-config-key)
  "Combine the projectIDE-default-exclude.")

(defcustom projectIDE-default-exclude
  '("*.idea*"
    "*.eunit*"
    "*.git*"
    "*.hg*"
    "*.fslckout*"
    "*.bzr*"
    "*_darcs*"
    "*.tox*"
    "*.svn*"
    "*.stack-work*")
  "A list of exclude items by projectIDE."
  :group 'projecIDE-config-file
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

;; Object
(cl-defstruct projectIDE-injector
  file
  replace ;;(####ABCED#### . ####ABCDEEND####)
  source ;; ####FILE#####*.cpp####FILEEND####
  )

(cl-defstruct projectIDE-project
  ;; config file
  signature                                    ;; string         eg. "173874102"
  name                                         ;; string         eg. "project1"
  (exclude projectIDE-default-exclude)         ;; string-list    eg. ("*.git" ".projectIDE")
  (whitelist projectIDE-default-whitelist)     ;; string-list    eg. ("*.git" ".projectIDE")
  project-create-hook                          ;; symbol-list    eg. ('fun1 'fun2 'fun3)
  project-open-hook                            ;; symbol
  project-file-open-hook                       ;; symbol
  compile-hook                                 ;; symbol
  injector                                     ;; injector-list
  reserve-field-1
  reserve-field-2
  reserve-field-3
  )

(cl-defstruct projectIDE-cache
  project                                      ;; project-project object
  folder-hash                                  ;; hash table. key: path  value: last-modify
  file-hash                                    ;; hash table. key: path  value: file list
  opened-buffer                                ;; string in terms of file path
  association                                  ;; hash table. key: filename value: file path list
  )

(cl-defstruct projectIDE-record
  signature
  path
  create-date
  last-modify)


(defun projectIDE-message-handle (type message &optional print function)
  "This funtion handle messages from projectIDE for debug purpose.
TYPE specifies message type.  It can be 'Info, 'Warning or 'Error.
Warning and Error message will be logged by default for debug purpose.
Logging level can be set at `projectIDE-log-level'
MESSAGE elaborates the Info, Warning or Error.
PRINT controls whether message should be output to screen.
FUNCTION denotes the function calling this message handle.
It should be used by 'Warning or 'Error level for debug purpose.

TYPE
Type:\t\t symbol
Descrip.:\t Can be 'Error, 'Warning or 'Info to indicate message type.

MESSAGE
Type:\t\t string
Descrip.:\t Debug or informational message.

PRINT
Type:\t\t bool
Descrip.:\t Display message to minibuffer if it is t.
\t\t\t It is nil by default

FUNCTION
TYpe:\t\t symbol
Descrip.: Function producing the message.  Just for debug purpose."

  (let ((message-prefix nil)
        (time (format-time-string "%Y%m%d-%R"))
        (logtype nil))
    
    (cond ((eq type 'Error)
           (setq message-prefix "[projectIDE::Error]")
           (setq logtype 3))
          ((eq type 'Warning)
           (setq message-prefix "[projectIDE::Warning]")
           (setq logtype 2))
          ((eq type 'Info)
           (setq message-prefix "[projectIDE::Info]")
           (setq logtype 1)))

    (when print
      (message (concat message-prefix " " message)))

    (when (and logtype (>= logtype projectIDE-log-level))
      (write-region
       (concat time "\t"
               message-prefix "\t"
               (when (symbolp function)
                 (concat (symbol-name function) ": "))
               message "\n")
       nil PROJECTIDE-LOG-FILE t 'inhibit))

    ;; Return value
    (concat message-prefix " " message)))

(defun trim-string (string)
  "Return trimmed leading and tailing whitespace from STRING.
If the return string is a null string, return nil instead.

Return
Type:\t\t string or nil
Descrip.:\t Trimmed string or nil if blank string.

STRING
Type:\t\t string
Descrip.:\t String to be trimmed."
  (let ((return-string
         (replace-regexp-in-string (rx (or (: bos (* (any " \t\n")))
                                           (: (* (any " \t\n")) eos)))
                                   ""
                                   string)))
    ;; Return type
    (if (string= return-string "")
        nil
      return-string)))

(defun fout<<projectIDE (file data)
       "Write FILE with DATA.
DATA is any symbol variable in Emacs.

This function is safe.
It checks the accessibilty of file.
Return NIL if file is not accessable.
It checks the data for a valid symbol.
Return NIL if data value is void.
Return t if wirting file successfully

It is designed to simulate C++ std::cout.

Example:
\(if \(file<<data \"~\\Documents\\foo.txt\" 'foo\)
    \(message \"All success.\"\)
  \(message \"Some problem.\"\)\)

Return
Type:\t\t bool
Descrip.:\t t for no error, nil for error.

FILE
Type:\t\t string
Descrip.:\t Path to output file.
Example:\t ~/.emacs.d/file.txt , ~/usr/mola/documents/cache.txt

DATA
Type:\t\t symbol
Descrip.:\t Serialize data holds by symbol."
       
       (catch 'Error
         (let ((noError t))
           ;; Check file accessibility
           (unless (and (file-exists-p file) (file-writable-p file))
             (let ((parentPath (file-name-directory file)))
               (when (or (file-directory-p parentPath)
                         (make-directory parentPath t)
                         (file-directory-p parentPath))
                 (write-region "" nil file nil 'inhibit nil 'exc1))
               (unless (and (file-exists-p file) (file-writable-p file))
                 (throw 'Error nil))))

           ;; Check symbol exists
           (unless (boundp data)
             (throw 'Error nil))

           ;; Serialize and wirte data to file
           (with-temp-file file
             (insert (prin1-to-string (symbol-value data))))
           
           ;; return value
           noError)))

(defun fin>>projectIDE (file symbol)
  "This function is safe.
It read data from FILE and restore data to SYMBOL.

It returns t it there isn't any error
It returns nil if data cannot be restored.

Return
Type:\t\t bool
Descrip.:\t t for no error, nil for error.

FILE
Type:\t\t string
Descrip.:\t Path to input file.
Example:\t ~/.emacs.d/file.txt , ~/usr/mola/documents/cache.txt"
  
  (catch 'Error
    ;; Check file accessibility
    (unless (file-readable-p file)
      (throw 'Error nil))

    ;; Read from file
    (with-temp-buffer
      (insert-file-contents file)
      (unless (equal (point-min) (point-max))
        (if (boundp symbol)
            (set symbol (read (buffer-string)))
          (throw 'Error nil))))
    
    ;; Return value
    t))

(defun projectIDE-find-record-by-path (path)
  "Return record signature by the given PATH.
Record is search in projectIDE-runtime-record.

Return
Type:\t\t projectIDE-record signature or nil
Descrip.:\t projectIDE-record signature of given PATH.
\t\t\t nil if PATH not found.

PATH
Type:\t\t string
Descript.:\t File or folder path in string."
  (let ((record (hash-table-values projectIDE-runtime-record))
        (found nil))
    (while (and (not found) (car-safe record))
      (when (string-prefix-p (projectIDE-record-path (car record)) path)
        (setq found (projectIDE-record-signature (car record))))
      (setq record (cdr record)))
    
    ;; Return value
    found))

(defun projectIDE-configParser (file)
  "Parse .projectIDE config FILE.
Return a projectIDE-project object created by the FILE.
If .projectIDE is a blank file, return a default projectIDE-project object.
If there is any problem parsing the .projectIDE file, return nil.

Return
Type:\t\t projectIDE-project object or nil
Descrip.:\t Project object created by parsing FILE.
\t\t\t: nil for any error.

FILE
Type:\t\t string
Descrip.:\t Flie path to .projectIDE."
  (catch 'parse-error
    (let ((project (make-projectIDE-project)))
      
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char 1)

        ;; Search keys
        (while (search-forward-regexp projectIDE-default-config-key-regexp nil t)
          (save-excursion

            ;; Identify key
            (beginning-of-line)
            (let ((found nil)
                  (line-end (line-end-position))
                  (keylist projectIDE-default-config-key)
                  (counter 0))
              (while (and (not found) (car-safe keylist))
                (if (search-forward-regexp (car keylist) line-end t)
                    (progn
                      (cond
                       ((= counter 0) ;; "^signature="
                        (when (projectIDE-project-signature project)
                          (message "[ProjectIDE::Error] Config file corrupt. 'signature' defined more than once.")
                          (throw 'parse-error nil))
                        (setf (projectIDE-project-signature project) (trim-string (buffer-substring-no-properties (point) line-end))))
                       ((= counter 1) ;; "^name="
                        (when (projectIDE-project-name project)
                          (message "[ProjectIDE::Error] Config file corrupt. 'name' defined more than once.")
                          (throw 'parse-error nil))
                        (setf (projectIDE-project-name project) (trim-string (buffer-substring-no-properties (point) line-end))))
                       ((= counter 2) ;; "^exclude="
                        (let ((exclude-list
                               (or (split-string (buffer-substring-no-properties (point) line-end))
                                   (projectIDE-project-exclude project)
                                   "")))
                            (setf (projectIDE-project-exclude project) exclude-list)))
                       ((= counter 3) ;; "^whitelist="
                        (let ((whitelist
                               (or (split-string (buffer-substring-no-properties (point) line-end))
                                   (projectIDE-project-whitelist project)
                                   "")))
                            (setf (projectIDE-project-whitelist project) whitelist)))
                       ((= counter 4) ;; "^inject"
                        ;; Implement later
                        (message "[ProjectIDE::Warning] Inject eature not availiable for this version.")))
                      (setq found t)))
                (setq counter (1+ counter))
                (setq keylist (cdr keylist)))))))
      
      ;; Return value
      project)))

(cl-defmacro projectIDE-create (projectType &key templateDir defaultDir document)
  "Create projection creation function."
  (let* ((projectType (symbol-name projectType))
         (templateDir (file-name-as-directory templateDir))
         (defaultDir (file-name-as-directory defaultDir))
         (document (or document (format
                                 "Create new '%s' project.\nProjectIDE will create a new folder named PROJECTNAME under DIR"
                                 projectType))))
    
    ;; Check if the template directory and default directory exist
    (if (and (file-directory-p templateDir)
             (or (file-directory-p defaultDir)
                 (setq defaultDir (or projectIDE-create-defaultDir user-emacs-directory))))
        
        ;; Function template
        `(defun ,(intern (concat "projectIDE-create-" (downcase projectType))) (projectName dir)

           ;; Documentation
           ,document

           ;; Interactive call to ask for project name and project directory
           (interactive (list (read-string "Project Name: ")
                              (read-directory-name "Create project at: " ,defaultDir)))
           (setq dir (file-name-as-directory (expand-file-name dir)))

           (catch 'Error
             ;; Validate input
             ;; Check for initialization
             (unless (or projectIDE-p (projectIDE-initialize))
               (throw 'Error nil))
             ;; Prevent null string project name
             (when (string= projectName "")
               (message "[ProjectIDE::Error] Project name cannot be empty string.")
               (throw 'Error nil))
             ;; Make sure project root directory can be generated
             (unless (and (file-accessible-directory-p dir) (file-writable-p dir))
               (message (format "[ProjectIDE::Error] Project directory \"%s\" is not accessible." dir))
               (throw 'Error nil))
             (when (file-exists-p (concat dir projectName))
               (message (format "[ProjectIDE::Error] Folder \"%s\" already exists in \"%s\". Operation cancelled." projectName dir))
               (throw 'Error nil))

             ;; Ask for user prompt
             (unless (or (not projectIDE-create-require-confirm) ;; Confirm project creation guard
                         (y-or-n-p (format "Project\t\t\t\t: %s\nTemplate\t\t\t: %s\nProject Directory\t: %s\nCreate Project ? "
                                           projectName ,templateDir (concat dir projectName))))
               (message "[ProjectIDE::Info] Projection creation canceled.")
               (throw 'Error nil))


             ;; Project create here
             (let* ((projectRoot (file-name-as-directory (concat dir projectName)))
                    (projectConfig (concat projectRoot PROJECTIDE-PROJECTROOT-IDENTIFIER)))
               ;; Create project structure by template
               (make-directory projectRoot)
               (copy-directory ,templateDir projectRoot nil nil t)
               (projectIDE-new-project projectRoot)

               (run-hooks 'projectIDE-global-project-create-hook)
               (message "Project Created\nProject\t\t\t\t: %s\nTemplate\t\t\t: %s\nProject Directory\t: %s"
                        projectName ,templateDir projectRoot))))
                 
      ;; Macro error message
      (message "Template directory \"%s\" error\nEither not exists, not directory or non-accessible." templateDir))))

(defun projectIDE-new-project (path)
  ;; Ensure PATH is a directory before passing to this function.
  ;; ie. use file-name-as-directory
  "Create project with PATH as project root.
It is a encapsulation of project creation chain.

PATH
Type:\t\t string
Descrip.:\t Path to project root."

  (let ((project-config (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER)))
    ;; Generate .projectIDE file
    (projectIDE-project-root-creator path)
    ;; Create global record
    (projectIDE-create-record project-config)
    ;; Create individual record
    (projectIDE-create-cache project-config)))

(defun projectIDE-project-root-creator (path)
  "Create '.projectIDE' at PATH to indicate a project root.
Create basic key like signature, name, exclude and whitelist as well.
If '.projectIDE' has already existed,

PATH
Type:\t\t string
Descrip.:\t Path to project root."
  ;; Generate .projectIDE if not exist
  (unless (memq PROJECTIDE-PROJECTROOT-IDENTIFIER (directory-files path))
    (write-region "" nil (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER) t 'inhibit))

  (let* ((file (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
         (project (projectIDE-configParser file)) ;; don't use projectIDE-make-projectIDE-project
         (signature (concat (number-to-string (random most-positive-fixnum))
                            (number-to-string (random most-positive-fixnum))
                            (number-to-string (random most-positive-fixnum))))
         (name (projectIDE-project-name project))
         (exclude (projectIDE-project-exclude project))
         (whitelist (projectIDE-project-whitelist project)))
    
    (with-temp-file file
      ;; If signature exists in .projectIDE, remove it
      (when (projectIDE-project-signature project)
        (while (search-forward-regexp "^signature=" nil t)
          (delete-region (line-beginning-position) (line-end-position))))

      (goto-char 1)
      ;; Write to .projectIDE
      ;; Handle signature
      (insert "## This file is generated by projectIDE\n"
              "## There are several keys availiable.\n"
              "## You can see documentation for all keys.\n"
              "## Keys must start on a newline and end with a '='.\n"
              "## Below is an example for key 'signature.\n"
              "signature=" signature "\n"
              "## Signature is unique for each project.\n"
              "## ProjectIDE used the signature to trace every data on that project.\n"
              "## So never create or change the signature manually!!!\n\n")
      ;; Handle name
      ;; If name not exists in projectIDE, create for it
      (unless name
        (setq name (file-name-nondirectory (directory-file-name (file-name-directory file))))
        (insert "name=" name "\n"))
      ;; Handle exclude
      (unless exclude
        (insert "exclude=" (mapconcat 'identity (projectIDE-project-exclude project) " ") "\n"))
      ;; Handle whitelist
      (unless whitelist
        (insert "whitelist=" (mapconcat 'identity (projectIDE-project-whitelist project) " ") "\n")))))

(defun projectIDE-create-record (configfile)
  "Create projectIDE-record by reading CONFIGFILE.
Write to RECORD file afterward."
  (let ((project (projectIDE-configParser configfile))
        (record (make-projectIDE-record)))
    (setf (projectIDE-record-signature record)(projectIDE-project-signature project)
          (projectIDE-record-path record) (file-name-directory configfile)
          (projectIDE-record-create-date record) (time-to-days (current-time))
          (projectIDE-record-last-modify record) (time-to-days (current-time)))
    (puthash (projectIDE-project-signature project) record projectIDE-runtime-record)
    (fout<<projectIDE PROJECTIDE-RECORD-FILE 'projectIDE-runtime-record)))

(defun projectIDE-create-cache (configfile)
  "Create individual record by CONFIGFILE."
  (let* ((cache (make-projectIDE-cache))
         (project (projectIDE-configParser configfile))
         (file (concat PROJECTIDE-CACHE-PATH (projectIDE-project-signature project))))
    (setf (projectIDE-cache-project cache) project)
        (unless (file-exists-p file)
          (write-region "" nil file t 'inhibit)
          (fout<<projectIDE file 'cache))))

(defun projectIDE-last-modify (path)
  "Return last modify time from PATH.
PATH can be a file path or a folder path.
If PATH does not exist, return nil.

PATH
Type:\t\t string
Descrip.:\t String of path to file or folder."
  (nth 5 (file-attributes path)))

(defun projectIDE-get-folder-list (projectRoot currentPath &optional exclude whitelist)
  "Combining PROJECTROOT and CURRENTPATH generate a complete current path.
Return a list of folder (path relative to project root) under current path.
The returned folder paths includes all its sub-directories.
If there is no folder under current path, return nil.

Return
Type:\t\t string list of folder paths
Descrip.:\t Return a list of folder (relative to PROJECTROOT) under CURRENTPATH.
\t\t\t If there is no files under CURRENTPATH, return nil.

PROJECTROOT
Type:\t\t string
Descrip.:\t String of path to project root.

CURRENTPATH
Type:\t\t string
Descrip.:\t String of current searching path.
\t\t\t It is relative to PROJECTROOT."
  
  (let ((content-list (directory-files (concat projectRoot currentPath) nil nil 'nosort)) ;; A list of content entry relative to current path
        (folder-list nil))
    
    (while (car-safe content-list)
      (let* ((content (car content-list)) ;; Content relative to current path
             (entry (concat projectRoot currentPath content))) ;; Complete path of content
        (when (and (file-directory-p entry)
                   (not (or (string= content ".") (string= content ".."))))
          (when (and exclude (string-match exclude entry))
            (unless (and whitelist (string-match whitelist entry))
              (setq content nil)))

          (when content
            (setq folder-list (append
                               folder-list
                               (projectIDE-get-folder-list projectRoot (file-name-as-directory (concat currentPath content)))))
            (add-to-list 'folder-list (file-name-as-directory (concat currentPath content))))))
        (setq content-list (cdr content-list)))

    ;; Return value
    folder-list))

(defun projectIDE-get-path-files (path &optional exclude whitelist)
  "Return a list of files (only file name) under PATH.
If there is no files under PATH, return nil.

Return
Type:\t\t string list of file names
Descrip.:\t Return a list of files (only file name) under PATH.
\t\t\t If there is no files under PATH, return nil.

PATH
Type:\t\t string
Descrip.:\t String of path."
  
  (let ((contents (directory-files path t nil 'nosort))
        (filelist nil))
    
    (while (car-safe contents)
      (unless (file-directory-p (car contents))
        (let ((file (car contents)))
          (when (and exclude (string-match exclude file))
            (unless (and whitelist (string-match whitelist file))
              (setq file nil)))
          (when file
            (add-to-list 'filelist (file-name-nondirectory file)))))
      (setq contents (cdr contents)))

    ;; Return value
    (sort filelist 'projectIDE-filename-sort-predicate)))

(defun projectIDE-filename-sort-predicate (filename1 filename2)
  "Wrapper of `string-lessp' to sort filename regardless of case.

FILENAME1 FILENAME2
Type:\t string
Descrip.:\t Filename."
  
  (setq filename1 (downcase filename1)
        filename2 (downcase filename2))
  (string-lessp filename1 filename2))

(defun projectIDE-update-project-config (signature &optional ErrorMessage)
  "Update specific project config in projectIDE-opened-project.
The project updated is specified by SIGNATURE.
ERRORMESSAGE indicates whether message is displayed to minibuffer
if there is any error.  Error message is not displayed by default.
This function return t if the project config is updated successfully.

Return
Type:\t\t bool
Descrip.: Return t if config is updated successfully.  Otherwise, return nil.

SIGNATURE
Type:\t\t string
Descrip.:\t String of number of signature.

ERRORMESSAGE
Type:\t\t bool
Descrip.: Display error message to minibuffer if it is t."

  (catch 'Error
    (let ((project-config-file (concat (projectIDE-record-path (gethash signature projectIDE-runtime-record))
                                       PROJECTIDE-PROJECTROOT-IDENTIFIER)))
      (unless (file-exists-p project-config-file)
        (projectIDE-message-handle 'Error
                                   (format "Update project config failed. %s not found." project-config-file)
                                   ErrorMessage
                                   'projectIDE-update-project-config)
        (throw 'Error nil))
      
      (let ((project (projectIDE-configParser project-config-file)))
        (unless project
          (projectIDE-message-handle 'Error
                                     (format "Update project config failed. Error reading %s." project-config-file)
                                     ErrorMessage
                                     'projectIDE-update-project-config)
          (throw 'Error nil))

        (puthash signature project projectIDE-opened-project))))

  ;; Return value
  t)

(defun projectIDE-add-projectRoot-prefix (projectRoot list)
  "Add the PROJECTROOT as a prefix to each entry in the LIST.
Also, it adjusts the regexp in the list.
Return a modified LIST.

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
    (while (car-safe list)
      (add-to-list 'return
                   (concat projectRoot
                           (replace-regexp-in-string "\\*" ".*"
                                                     (replace-regexp-in-string "\\." "\\\\." (car list)))))
      (setq list (cdr list)))

    ;; Return value
    return))

(defun projectIDE-update-cache-by-signature (signature &optional ErrorMessage)
  "Update cache for the project provided by SIGNATURE.
ERRORMESSAGE indicates whether message is displayed to minibuffer
if there is any error.  Error message is not displayed by default.

SIGNATURE
Type:\t\t string
Descrip.:\t String of number of signature.

ERRORMESSAGE
Type:\t\t bool
Descrip.: Display error message to minibuffer if it is t."

  (catch 'Error
    (unless (projectIDE-update-project-config signature)
      (projectIDE-message-handle 'Error
                                 "Update cache terminated due to failure in updating config"
                                 ErrorMessage
                                 'projectIDE-update-cache-by-signature)
      (throw 'Error nil))

    ;; Check whether project config has changed.
    ;; If exclude or whitelist has changed, whole project need to be reindexed.
    (let* ((project (gethash signature projectIDE-opened-project))
           (cache (gethash signature projectIDE-runtime-cache))
           (cached-project (projectIDE-cache-project cache)))
      
      (when (not (and (equal (projectIDE-project-exclude project) (projectIDE-project-exclude cached-project))
                      (equal (projectIDE-project-whitelist project) (projectIDE-project-whitelist cached-project))))
        (clrhash (projectIDE-cache-folder-hash cache))
        (clrhash (projectIDE-cache-file-hash cache)))

      (setf (projectIDE-cache-project cache) project))

    ;; Update folder list
    (let* ((projectRoot (projectIDE-record-path (gethash signature projectIDE-runtime-record)))
           (cache (gethash signature projectIDE-runtime-cache))
           (project (projectIDE-cache-project cache)) ;; cached project
           (exclude (projectIDE-concat-regexp-list
                     (projectIDE-add-projectRoot-prefix projectRoot (projectIDE-project-exclude project)))) ;; cached exclude list
           (whitelist (projectIDE-concat-regexp-list
                       (projectIDE-add-projectRoot-prefix projectRoot (projectIDE-project-whitelist project)))) ;; cached whitelist
           (folder-hash (projectIDE-cache-folder-hash cache)) ;; cached folder hash table
           (folder-list (hash-table-keys folder-hash)) ;; cached folder list
           (file-hash (projectIDE-cache-file-hash cache))) ;; cached file hash table

      ;; Check current entries in the hash table first
      (while (car-safe folder-list)
        (let* ((folder-name (car folder-list)) ;; folder path relative to projectRoot
               (folder-path (concat projectRoot (car folder-list)))) ;; complete folder path
          (if (not (and (file-exists-p folder-path) (file-directory-p folder-path)))
              ;; Remove redundant entry
              (progn
                (remhash folder-name folder-hash)
                (remhash folder-name file-hash))
            ;; Check last modification to update file list
            (when (time-less-p
                   (gethash folder-name folder-hash)
                   (projectIDE-last-modify folder-path))
              (puthash folder-name (projectIDE-get-path-files folder-path exclude whitelist) file-hash)
              (puthash folder-name (projectIDE-last-modify folder-path) folder-hash)))))

      ;; Check any newly added folder
      (let ((current-folder-list (projectIDE-get-folder-list projectRoot "" exclude whitelist)))
        (while (car-safe current-folder-list)
          (unless (gethash (car current-folder-list) folder-hash)
            (puthash (car current-folder-list)
                     (projectIDE-get-path-files (concat projectRoot (car current-folder-list)) exclude whitelist)
                     file-hash)
            (puthash (car current-folder-list) (projectIDE-last-modify (concat projectRoot (car current-folder-list))) folder-hash))
          (setq current-folder-list (cdr current-folder-list))))))

  (fout<<projectIDE (concat PROJECTIDE-CACHE-PATH signature) (gethash signature projectIDE-runtime-cache)))

  
(defun projectIDE-index-project (path)
  "This is an interactive function to let user index a project.
PATH is the project root."
  (interactive (list (read-directory-name "Please choose the project root: "
                                          (file-name-directory (or buffer-file-name user-emacs-directory)))))

  
  ;; Index project
  (if (and (file-exists-p (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
           (projectIDE-project-signature (projectIDE-configParser (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))))
      (if (yes-or-no-p
           (concat (projectIDE-message-handle 'Warning
                                              (format ".projectIDE with signature found at %s" path)
                                              nil 'projectIDE-index-project)
                   "\nChoose yes if you want to create a new signature for this project.
Choose no if you want to retain current signature.
Press C-g to cancel the operation."))
          (projectIDE-new-project (file-name-as-directory path))
        (projectIDE-create-record (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
        (projectIDE-create-cache (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER)))
    (projectIDE-new-project (file-name-as-directory path)))
  
  ;; Scan through buffers to check whether they are memeber of newly indexed project
  (let ((buffers (buffer-list)))
    (while (car-safe buffers)
      (projectIDE-identify-project (car buffers))
      (setq buffers (cdr buffers))))

    (message "FUCKFUCKFUCKFUCK")
  (message path)

  (projectIDE-message-handle 'Info
                             (format "Project Indexed\nProject\t\t\t\t: %s\nProject Directory\t: %s"
                                     (projectIDE-project-name
                                      (projectIDE-configParser (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER)))
                                     path)
                             t
                             'projectIDE-index-project))


(defun projectIDE-identify-project (&optional buffer)
  "This function check whether BUFFER is a indexed project.
If it is a indexed project, it ensures
1) it is under opened project
2) it is under opened buffer in project cache
If BUFFER is not provided, current buffer is used instead.

BUFFER
Type\t\t: buffer
Descrip.:\t The buffer being identified."
  
  (let ((found nil)
        (signature nil))

    (let ((opened-project-signatures (hash-table-keys projectIDE-opened-project)))
      ;; Find project in current opened project
      ;; If found set found to t
      (while (and (not found) (buffer-file-name buffer) (car-safe opened-project-signatures))
        (when (string-prefix-p
               (projectIDE-record-path
                (gethash (car opened-project-signatures) projectIDE-runtime-record)) ;; get RECORD from current opened project
               (buffer-file-name buffer))
          (setq signature (car opened-project-signatures))
          (setq found t))
        (setq opened-project-signatures (cdr opened-project-signatures))))

    ;; Search in project RECORD
    ;; If found set found to t
    ;; And add project to projectIDE-opened-project
    (unless found
      (when (buffer-file-name buffer)
        (setq signature (projectIDE-find-record-by-path (buffer-file-name buffer))))
      (when signature
        (setq found t)))
    
    ;; Search .projectIDE up directory
    ;; If found set found to t,
    ;; add project to projectIDE-opened-project
    ;; and add current buffer to current opened buffer
    (unless (or buffer found)
      (let ((search-countdown projectIDE-config-file-search-up-level)
            (path (file-name-directory (buffer-file-name))))
        (while (and (not found) (> search-countdown 0))
          (when (file-exists-p (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
            (let* ((projectRoot (concat path PROJECTIDE-PROJECTROOT-IDENTIFIER))
                   (project (projectIDE-configParser projectRoot)))
              (if (projectIDE-project-signature project)
                  ;; found .projectIDE with signature
                  (progn
                    (setq signature (projectIDE-project-signature project))
                    (projectIDE-create-record projectRoot)
                    (unless (file-exists-p (concat PROJECTIDE-CACHE-PATH signature))
                      (projectIDE-create-cache projectRoot))
                    (setq found t))
                ;; found .projectIDE without signature
                (if (y-or-n-p
                     (projectIDE-message-handle
                      'Info
                      (format ".projectIDE root file found at %s.\nMake this path as project root and index the project? " path)
                      nil
                      'projectIDE-identify-project))
                    (progn
                      (projectIDE-new-project path)
                      (setq signature (projectIDE-find-record-by-path (buffer-file-name buffer)))
                      (setq found t)
                      (projectIDE-message-handle
                       'Info
                       (format "Project Indexed\nProject\t\t\t\t: %s\nProject Directory\t: %s"
                               (file-name-nondirectory (directory-file-name (file-name-directory projectRoot))) path)
                       t
                       'projectIDE-identify-project))
                  (projectIDE-message-handle
                   'Info
                   "File opened without indexing."
                   t
                   'projectIDE-identify-project)
                  (setq search-countdown -1)))))
          
          (setq search-countdown (1- search-countdown))
          (setq path (file-name-directory (directory-file-name path))))))

        
        (when found
          (let ((project (projectIDE-configParser
                          (concat (projectIDE-record-path (gethash signature projectIDE-runtime-record)) PROJECTIDE-PROJECTROOT-IDENTIFIER)))
                (cache))

            ;; Add to opened project if it is not there yet
            (unless (gethash signature projectIDE-opened-project)
              (puthash signature project projectIDE-opened-project))

            ;; Create project cache if it is not ther yet
            (unless (gethash signature projectIDE-runtime-cache)
              (fin>>projectIDE (concat PROJECTIDE-CACHE-PATH signature) 'cache)
              (puthash signature cache projectIDE-runtime-cache)))
          
          (let ((project (gethash signature projectIDE-opened-project))
                (cache (gethash signature projectIDE-runtime-cache)))
            ;; Add to opened buffer in project cache
            (setf (projectIDE-cache-opened-buffer cache) (projectIDE-add-to-list (projectIDE-cache-opened-buffer cache) (buffer-file-name buffer)))
            ;; Add to buffer-trace
            (puthash (or buffer (current-buffer)) signature projectIDE-buffer-trace))

          (unless buffer
            (projectIDE-message-handle
             'Info
             (format "Opened [%s] file" (projectIDE-project-name (gethash signature projectIDE-opened-project)))
             t
             'projectIDE-identify-project)))))

  
(defun projectIDE-add-to-list (list element)
  "Wrapper to `add-to-list'(LIST ELEMENT).
Add ELEMENT to  LIST if it isn't there yet.
This function does not modify the original list.
Instead, it returns a new list.
In addition, it accepts non-symbol LIST.

Return
Type:\t\t list
Descrip.:\t New list with ELEMENT add to LIST

LIST
Type:\t\t list of any type
Descrip.:\t List to be checked and appended to.

ELEMENT
Type:\t\t same type of LIST element
Descrip.:\t Add to LIST if ELEMENT isn't there yet."
  (add-to-list 'list element))
  
(defun projectIDE-initialize ()
  "ProjectIDE-initialize."
  (interactive)
  ;; Check whether projectIDE database folder exist
  (unless (file-exists-p projectIDE-database-path)
    (make-directory projectIDE-database-path))
  ;; Check global RECORD file exist
  (unless (file-exists-p PROJECTIDE-RECORD-FILE)
    (write-region "" nil PROJECTIDE-RECORD-FILE t 'inhibit))
  ;; Check INDIVIDUAL record folder exist
  (unless (file-exists-p PROJECTIDE-CACHE-PATH)
    (make-directory PROJECTIDE-CACHE-PATH))

  (if (fin>>projectIDE PROJECTIDE-RECORD-FILE 'projectIDE-runtime-record)
      (progn
        (unless projectIDE-runtime-record
          (setq projectIDE-runtime-record (make-hash-table :test 'equal :size 40)))
        (setq projectIDE-opened-project (make-hash-table :test 'equal :size 20))
        (setq projectIDE-runtime-cache (make-hash-table :test 'equal :size 20))
        (setq projectIDE-buffer-trace (make-hash-table))
        (projectIDE-message-handle 'Info
                                   "projectIDE starts successfully."
                                   t
                                   'projectIDE-initialize)
        (add-hook 'find-file-hook 'projectIDE-identify-project)
        (setq projectIDE-p t))
    (projectIDE-message-handle 'Error
                               (format "projectIDE starts fail. Unable to read record file at %s" PROJECTIDE-RECORD-FILE)
                               t
                               'projectIDE-initialize))
;; Return value
  projectIDE-p)

;;;; Testing function
(defvar projectIDE-test-path
  (file-name-as-directory
   (concat
    (file-name-as-directory
     (concat default-directory "projectIDE")) "test")))
(defvar projectIDE-testfile1 (concat projectIDE-test-path "testfile1.txt"))
(defvar projectIDE-testfile2 (concat projectIDE-test-path "testfile2.txt"))
(defvar projectIDE-testfile3 (concat projectIDE-test-path "testfile3.txt"))
(defvar projectIDE-testfile4 (concat projectIDE-test-path "testfile4.txt"))
(defvar projectIDE-testfile5 (concat projectIDE-test-path "testfile5.txt"))
 (defvar projectIDE-testvar1 nil)
(defvar projectIDE-testvar2 nil)
(defvar projectIDE-testvar3 nil)
(defvar projectIDE-testvar4 nil)
(defvar projectIDE-testvar5 nil)
(projectIDE-initialize)

;;;; End Testing
(provide 'projectIDE)
;;; projectIDE.el ends here
