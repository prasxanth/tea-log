(import functools [reduce]
        re
        json
        yaml
        pickle
        unidecode [unidecode]
        operator [itemgetter]
        toolz [dissoc]
        time)

(require hyrule [ -> ->> as-> fn+ let+ defmacro/g! assoc unless])
(require hyrule :readers [%])

;;; ======================================================================== ;;;
;;;                   General utility and helper functions                   ;;;
;;; ======================================================================== ;;;

(defmacro/g! -< [head #* funcs]
  `(do (setv
         ~g!name ~head
         ~@(sum (gfor f funcs [g!name `(. ~g!name ~f)]) []))
     ~g!name))

(defn mapl [func coll]
  "Map function `func` to collection `coll` and return a list"
  (list (map func coll)))

;;; --------------------------- String functions --------------------------- ;;;

(defn rxsub [text #* patterns-replacements]
  "Recursively substitute `pattern` with `replacement` in `text`"
  (reduce (fn+ [t [p r]] (re.sub p r t)) patterns-replacements text))

(defn contains-substring? [text substrings]
  "Check if `text` contains any substring in list of `substrings`"
  (->> substrings (map #%(in %1 text)) any))

(defn empty-line? [line]
  (all (map #%(. %1 (isspace)) line)))

;;; ---------------------------- Dict functions ---------------------------- ;;;

(defn merge-kv [dictionary keys new-key * [remove-original False] [join-sep " "]]
  "Join values as strings in `keys` into `new-key`. If `remove-original` is true `keys` are removed." 
  (unless (all (lfor k keys (in k (dictionary.keys))))
    (return dictionary))
  (let [hash-map (. dictionary (copy))]
     (as-> hash-map it
           ((itemgetter #* keys) it)
           (mapl str it)
           (. join-sep (join it))
           (assoc hash-map new-key it))
     (if remove-original
         (dissoc hash-map #* keys)
         hash-map)))

;;; --------------------------------- Misc --------------------------------- ;;;

(defn calculate-ratios [lst]
  "Calculate ratios from numbers in a list"
  (let [total (sum lst)]
    (mapl #%(/ %1 total) lst)))

;;; ------------------------------- DataFrame ------------------------------ ;;;

(defn df-columns [df [select None]]
  (let [cols (.tolist (. df columns))]
    (if (is select None)
      cols
      (->> cols (filter #%(in select %1)) list)))) 

;;; ---------------------------- File functions ---------------------------- ;;;

; (defn create-timestamped-filename [basename ext]
;   f"{basename}-{(int (.time time))}.{ext}") 

(defn read-txtfile [filename]
  (with [file (open filename "rt")]
    (.read file)))

(defn write-txtfile [data filename]
  (with [file (open filename "wt")]
    (.write file data)))

(defn read-pickle [filename]
  (with [pickle-file (open filename "rb")]
    (.load pickle pickle-file)))

(defn write-pickle [data filename]
  (with [pickle-file (open filename "wb")]
    (.dump pickle data pickle-file)))

(defn read-json [filename]
  (with [json-file (open filename "r")]
    (.load json json-file)))

(defn write-json [data filename]
  (with [json-file (open filename "w")]
    (. json (dump data json-file :indent 4))))

(defn read-yaml [filename]
  (with [yaml-file (open filename "r")]
    (.load yaml yaml-file)))

(defn write-yaml [data filename]
  (with [yaml-file (open filename "w")]
    (. yaml (dump data yaml-file :default_flow_style False))))


