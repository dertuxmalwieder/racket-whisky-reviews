#lang web-server/insta

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; reddit whisky exposé
;; made by /u/rhabarba
;;-----------------------------------------
;; Requirements:
;;  - the YAML module (raco pkg install yaml)
;;  - a file named whiskies.yaml built like this:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; meta:
;;     - username: rhabarba
;;
;; whiskies:
;;     - name: Foo Bar
;;       age: 12
;;       price: $42
;;       alcvol: 42.6
;;       region: Speyside
;;       subreddit: scotch
;;       commentsid: 7gg3o9
;;       rating: 100
;;
;;     - name: Quux
;;       age: NAS
;;       subreddit: worldwhisky
;;       commentsid: abcdef
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; The "meta" field is mandatory.
;;
;; All whisky fields except "name", "subreddit" and "com-
;; mentsid" (which is the ID part of the reddit thread URL)
;; are optional, the table will remain empty in the parti-
;; cular fields.
;;
;; For efficiency reasons, the list is read once on startup.
;; Restart the server if you changed your YAML file. (This
;; could be automatic if you use a VCS, e.g. a post-commit
;; hook.)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require yaml)

(define whiskyfile "whiskies.yaml") ;; you can change this

;; Check for file existence:
(unless (file-exists? whiskyfile)
  (displayln "YAML file not accessible")
  (exit 1))

;; Read the whiskyfile:
(define whisky-list
  (with-handlers ((void (lambda _
                          (displayln "invalid YAML syntax")
                          #f)))
    (file->yaml* whiskyfile)))

;; Check the validity:
(unless (and
         (hash-has-key? (first whisky-list) (string->yaml "meta"))
         (hash-has-key? (first whisky-list) (string->yaml "whiskies")))
  (displayln "missing YAML key - required meta and whiskies.")
  (exit 1))

;; As the lists can come in unstructured, we'll make a struct.
(define-struct whisky (name age alcvol price region subreddit commentsid rating))
(define all-whiskies (list))

(define this-name "")
(define this-age "")
(define this-alcvol "")
(define this-price "")
(define this-region "")
(define this-subreddit "")
(define this-commentsid "")
(define this-rating "")

;; Generate a new table row for a whisky:
(define (render-whisky whisky)
  `(tr
    (td (a ((href
             ,(string-append
               "https://reddit.com/r/"
               (whisky-subreddit whisky)
               "/comments/"
               (whisky-commentsid whisky))))
           ,(whisky-name whisky)))
    (td ,(if (number? (whisky-age whisky))
             (number->string (whisky-age whisky))
             (whisky-age whisky)))
    (td ,(if (number? (whisky-alcvol whisky))
             (number->string (whisky-alcvol whisky))
             (whisky-alcvol whisky)))
    (td ,(whisky-region whisky))
    (td ,(if (number? (whisky-price whisky))
             (number->string (whisky-price whisky))
             (whisky-price whisky)))
    (td ,(if (number? (whisky-rating whisky))
             (number->string (whisky-rating whisky))
             (whisky-rating whisky)))))

;; Generate both lists:
(define meta-data null)
(define whisky-data null)

(for-each
 (lambda (arg)
   (if (string=? (first arg) "meta")
       ;; We either have "meta" or "whiskies".
       ;; if "meta":
       (set! meta-data (hash->list (second arg)))
       ;; else:
       (for ((h (in-list      ;; traverse over "whiskies"
                 (cdr arg)))) ;; filter out the key, keep the values

         ;; Each "h" is a whisky here. We shall put it in a struct.
         (for ((a-whisky (in-list (hash->list h))))
           (when (regexp-match? #rx"name" (yaml->string (car a-whisky)))
             (set! this-name (cdr a-whisky)))
           (when (regexp-match? #rx"age" (yaml->string (car a-whisky)))
             (set! this-age (cdr a-whisky)))
           (when (regexp-match? #rx"alcvol" (yaml->string (car a-whisky)))
             (set! this-alcvol (cdr a-whisky)))
           (when (regexp-match? #rx"price" (yaml->string (car a-whisky)))
             (set! this-price (cdr a-whisky)))
           (when (regexp-match? #rx"region" (yaml->string (car a-whisky)))
             (set! this-region (cdr a-whisky)))
           (when (regexp-match? #rx"subreddit" (yaml->string (car a-whisky)))
             (set! this-subreddit (cdr a-whisky)))
           (when (regexp-match? #rx"commentsid" (yaml->string (car a-whisky)))
             (set! this-commentsid (cdr a-whisky)))
           (when (regexp-match? #rx"rating" (yaml->string (car a-whisky)))
             (set! this-rating (cdr a-whisky))))
   
         ;; Make a complete list of structs.
         (set! all-whiskies
               (append all-whiskies
                       (list
                        (make-whisky
                         this-name
                         this-age
                         this-alcvol
                         this-price
                         this-region
                         this-subreddit
                         this-commentsid
                         this-rating))))

         ;; Reset:
         (set! this-name "")
         (set! this-age "")
         (set! this-alcvol "")
         (set! this-price "")
         (set! this-region "")
         (set! this-subreddit "")
         (set! this-commentsid "")
         (set! this-rating ""))))

 (hash->list (first whisky-list)))

;; We have filled meta-data and all-whiskies now.
;; The user name is a fixed string in our very small meta-data
;; list right now. It only contains a username... if the user
;; wasn't too dumb. :p
(define list-user-name (cdar meta-data))
(define the-table "")

;; Sort the whisky list alphabetically.
(set! all-whiskies (sort all-whiskies string<? #:key whisky-name))

;; Create the-table.
(set! the-table
      `(table
        (tr
         (th "Name")
         (th "Age")
         (th "Vol.%")
         (th "Region")
         (th "Price")
         (th "Rating"))
        ,@(map render-whisky all-whiskies)))

;; Time to process the whiskies while answering HTTP requests!
(define (start request)
  (response/xexpr
   #:preamble #"<!DOCTYPE html>"
   `(html
     (head
      (title ,(string-append list-user-name "'s whisky reviews"))
      (style ((type "text/css"))
             ,(string-append
               "body { font-family: sans-serif }"
               "table { border-collapse:collapse }"
               "tr, th, td { border: 1px solid grey }"
               "th, td { padding: 3px 6px }")))
     (body
      (h1
       (a ((href ,(string-append "https://reddit.com/u/" list-user-name))
           (target "_blank"))
          ,list-user-name) "'s whisky reviews")
      ,the-table))))