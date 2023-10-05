(import tea-log.utils [mapl rxsub contains-substring? empty-line? merge-kv calculate-ratios write-json] 
        re
        unidecode [unidecode] 
        toolz [merge merge-with]
        datetime [datetime]
        subprocess)

(require hyrule [ -> ->> as-> setv+ fn+ let+ defmain])
(require hyrule :readers [%])

(require tea-log.utils [-<])

;;; ======================================================================== ;;;
;;;                              Supplement mix                              ;;;
;;; ======================================================================== ;;;

(defn parse-supplement-mix [supplement-mix]
  "Split a supplement mix into constituent supplements and ratio"
  {"supplements" (as-> supplement-mix it
                       (re.sub r"_\d+(?::\d+)+$" "" it)
                       (. it (split "_+_"))
                       (mapl (fn [x] (-< x (strip) (strip "_"))) it))
   "ratio" (re.findall r"\d+(?::\d+)+$" supplement-mix)}) 

(defn get-supplement-mix-ratio [parsed-supplements parsed-ratios]
  "Get ratio for each supplement in mix"
  (let [numsupps (len parsed-supplements)]
    (if parsed-ratios
      (as-> parsed-ratios it
            (get it 0)
            (. it (split ":"))
            (cut it numsupps)
            (mapl int it)
            (calculate-ratios it))
      (->> numsupps (* [1]) calculate-ratios))))

(defn split-supplement-mix [supplement quantity]
  "Split individual supplements and ratios in mix, scale overall quantity by ratio"
  (let+ [{parsed-supplements "supplements" parsed-ratio "ratio"
          :as parsed-values} (parse-supplement-mix supplement)
         ratios (get-supplement-mix-ratio parsed-supplements parsed-ratio)
         quantities (map #%(* quantity %1) ratios)]
    (dict (zip parsed-supplements quantities))))


;;; ======================================================================== ;;;
;;;                                  Medium                                  ;;;
;;; ======================================================================== ;;;

(defn parse-medium [medium]
  "Parse medium temperature and type"
  (let [temperature (if (in "hot" (.lower medium)) "hot" "cold")
        medium-type (as-> (.lower medium) it
                          (. it (replace temperature ""))
                          (re.sub r"\s+" " " it)
                          (-< it (strip "_") (strip) (replace "+" "plus"))
                          (re.sub r"(?<=\w)_+" "_" it))]
    {"type" medium-type "temperature" temperature}))


;;; ======================================================================== ;;;
;;;                                   Stack                                  ;;;
;;; ======================================================================== ;;;

;;; -------------------------- Single stack entry -------------------------- ;;;

(defn clean-supplement-name [supplement-name]
  "Remove encoding and replace spaces with underscores of supplement name"
  (-> supplement-name
      unidecode
      (-< (lower) (strip) (replace " " "_") (replace "-" "_"))
      (rxsub #(r"[().\ ']" "") #(r"_+" "_"))))

(defn standardize-supplement-name% [supplement-name keywords standardized-name]
  "Meta function to replace aliases with same supplement name"
  (if (contains-substring? supplement-name keywords)
      standardized-name
      supplement-name))

(defn standardize-supplement-name [supplement-name]
  "Replace aliases of supplement names with same name"
  (-> supplement-name 
      (standardize-supplement-name% ["vitamin" "complex"] "vitamin_b_complex")
      (standardize-supplement-name% ["nuun"] "nuun_energy")
      (standardize-supplement-name% ["hibiscus"] "hibiscus_flower")
      (standardize-supplement-name% ["valerian"] "valerian_root")))

(defn parse-stack-entry [entry]
  (setv+ [quantity supplement] (-< entry (strip) (split " " 1))) 
  #((-> supplement
        clean-supplement-name
        standardize-supplement-name)
    (float quantity)))

(defn medium? [supplement quantity]
  "Identify if supplement is a medium"
  (let [media ["hot" "cold" "tea" "coffee" "milk" "soda" "cream" "juice" "coconut_water"]]
    (and (contains-substring? supplement media) (>= quantity 4))))

(defn supplement-mix? [supplement]
  "Identify if supplement is a mix of two or more supplements"
  (in "+" supplement))

(defn categorize-stack-entry [supplement quantity]
  (cond
    (medium? supplement quantity)
    {"medium" (parse-medium supplement)}
    (supplement-mix? supplement)
    {"supplements" (split-supplement-mix supplement quantity)}
    True {"supplements" {supplement quantity}}))

;;; ------------------------------ Full stack ------------------------------ ;;;

(defn parse-stack [line]
  (let [default-entry {"supplements" {} "medium" {"type" "sparkling_water" "temperature" "cold"}}]
    (as-> line it
          (-< it (lstrip "- ") (split ", "))
          (mapl parse-stack-entry it)
          (mapl (fn+ [[sup qty]] (categorize-stack-entry sup qty)) it)
          (merge-with merge it)
          (merge default-entry it))))

;;; ======================================================================== ;;;
;;;                                  Scores                                  ;;;
;;; ======================================================================== ;;;

(defn parse-scores [line]
  (as-> line it
        (-< it (lower) (lstrip "- ") (split ", "))
        (mapl #%(. %1 (split ":")) it)
        (mapl (fn+ [[well-being score]] {(. well-being (strip))
                                         (-> score (. (strip)) float)}) it)
        (merge it)))
                               
;;; ======================================================================== ;;;
;;;                                   Date                                   ;;;
;;; ======================================================================== ;;;
                                
(defn parse-date [line]
  (as-> line it
        (-< it (lower) (replace "date: " "") (strip))
        (.strptime datetime it "%B %d, %Y")
        (. it (strftime "%Y-%m-%d"))))

;;; ======================================================================== ;;;
;;;                                   Time                                   ;;;
;;; ======================================================================== ;;;

(defn parse-time [line]
  (-< line (lower) (replace "- time: " "") (strip)))                             

;;; ======================================================================== ;;;
;;;                                   Logs                                   ;;;
;;; ======================================================================== ;;;

(defn read-logs [filename]
  "Read tea log"
  (with [file (open filename "r")]
    (return (.readlines file))))

(defn parse-line [line]
  (cond
     (. line (startswith "date:")) {"date" (parse-date line)}
     (in "supplements" line) {}
     (in "mood" line) {"scores" (parse-scores line)}
     (in "time" line) {"time" f"{(parse-time line)}:00"}
     (empty-line? line) {}
     True {"stack" (parse-stack line)}))

(defn complete-entry? [entry]
  (all (map #%(is-not %1 None) (. entry (values)))))

(defn parse-logs [filename]
  (let [lines (read-logs filename)
        logs []
        new-entry {"time" None "stack" None "scores" None}
        entry (. new-entry (copy))]
    (for [line lines]
      (setv line (-< line (replace "\n" "") (strip) (lower)))
      (. entry (update (parse-line line)))
      (when (complete-entry? entry) 
        (as-> entry e
              (. e (copy))
              (merge-kv e ["date" "time"] "date_time" :remove-original True)
              (. logs (append e)))
        (. entry (update new-entry))))
    logs))


