(import subprocess
        os
        pathlib [Path] 
        collections.abc [Iterable]
        tea-log.utils [mapl 
                       df-columns 
                       write-txtfile 
                       read-json 
                       write-json 
                       write-yaml
                       read-pickle 
                       write-pickle]
        tea-log.parser [parse-logs]
        tea-log.predictor [json->records EnsembleStackPredictor]
        pandas :as pd
        janitor [rename-columns]
        re
        rich [box]
        rich.console [Console TerminalTheme] 
        rich.syntax [Syntax]
        rich.table [Table]
        rich.columns [Columns]
        fire
        warnings)

(require hyrule [ -> ->> as-> defmain unless defmacro/g!])
(require hyrule :readers [%])

(.filterwarnings warnings "ignore")

(setv +console+ (Console :record True)
      +colors+ {"table_border" "#a6adc8" "table_column" "#b4befe"}
      +rich-theme+ (TerminalTheme #(30 30 46)
                                  #(205 214 244) 
                                  [#(69 71 90) 
                                   #(243 139 168) 
                                   #(166 227 161) 
                                   #(249 226 175) 
                                   #(137 180 250) 
                                   #(245 194 231) 
                                   #(148 226 213) 
                                   #(186 194 222) 
                                   #(88 91 112)]
                                   [#(243 139 168) 
                                    #(166 227 161) 
                                    #(249 226 175) 
                                    #(137 180 250) 
                                    #(245 194 231) 
                                    #(148 226 213) 
                                    #(166 173 200)]))


(setv (get os.environ "PYTHONWARNINGS") "ignore")

;;; ======================================================================== ;;;
;;;                   Utility functions and global configs                   ;;;
;;; ======================================================================== ;;;

(setv *data-folder* (Path "data") 
      *input-folder* (/ *data-folder* (Path "input"))
      *output-folder* (/ *data-folder* (Path "output")))

(defn run-shell-command [cmd]
  (let [result (subprocess.run cmd :shell True :stdout subprocess.PIPE)]
    (.decode result.stdout "utf-8")))

(defn print-strs-to-console [#* strings]
  (.print +console+ (+ "" #* strings)))

(defn make-section-title [title]
  (print-strs-to-console "")
  (.rule +console+ title :characters "═"))

(defn make-input-path [input-file]
  (unless (is input-file None)
          (/ *input-folder* (Path input-file))))

(defn make-output-path [output-file]
  (unless (is output-file None) 
          (/ *output-folder* (Path output-file))))

(defn save-file [data output-path msg write-fn] 
  (when (.exists output-path)
    (print-strs-to-console f"✔ [#7f849c]Removing existing {output-path}[/]")
    (.unlink Path output-path))
  (print-strs-to-console msg)
  (write-fn data output-path))

(defmacro with-path-exists [pathname-binding #* body]
  `(let ~pathname-binding
     (if (.exists ~(get pathname-binding 0))
       ~@body
       (.print +console+ f"[#f38ba8]File {~(get pathname-binding 0)} not found[/]"))))

(defmacro unless-path-is-none [pathname-binding #* body]
  `(let ~pathname-binding
     (unless (is None ~(get pathname-binding 0))
       ~@body)))

;;; ======================================================================== ;;;
;;;                               Parse Tea Log                              ;;;
;;; ======================================================================== ;;;

(defn parse-tea-log [tea-log output-json [output-yaml None]]
  (with-path-exists [log-path (make-input-path tea-log)] 
    (let [data (parse-logs log-path)
          json-path (make-output-path output-json)]
      (make-section-title "Parse Tea Log")
      (save-file :data data
                 :output-path json-path
                 :msg f"✔ Parsing [#89b4fa]{log-path}[/] and saving to [#a6e3a1]{json-path}[/]"
                 :write-fn write-json)
      (unless-path-is-none [yaml-path (make-output-path output-yaml)]
        (save-file :data data
                   :output-path yaml-path
                   :msg f"✔ Converting [#89b4fa]{json-path}[/] to [#a6e3a1]{yaml-path}[/]"
                   :write-fn write-yaml)))))
  
;;; ======================================================================== ;;;
;;;                              Pydantic model                              ;;;
;;; ======================================================================== ;;;

(defn generate-pydantic-model [log-path]
  (run-shell-command (+ "datamodel-codegen "
                        "--disable-warnings "
                        "--input-file-type 'json' "
                        f"--input {log-path}")))

(defn show-pydantic-model [model-code] 
  (.print +console+)
  (.rule +console+ "Code") 
  (.print +console+ (Syntax :code model-code :lexer "python" :theme "material")))

(defn pydantic-model [tea-log [show False] [output-model None]]
  (with-path-exists [log-path (make-output-path tea-log)] 
      (let [model-code (generate-pydantic-model log-path)]
        (make-section-title "Pydantic Model")
        (unless-path-is-none [model-path (make-output-path output-model)]
          (save-file :data model-code
                     :output-path model-path
                     :msg f"✔ Saving pydantic model to [#a6e3a1]{model-path}[/]"
                     :write-fn write-txtfile))
        (when show (show-pydantic-model model-code)))))

;;; ======================================================================== ;;;
;;;                                    Fit                                   ;;;
;;; ======================================================================== ;;;

(defn get-models-in-ensemble [predictor]
  (mapl #%(. %1 __class__ __name__) (. predictor models)))

(defn print-ensemble-models [log-path predictor]
  (print-strs-to-console f"✔ Fitting ensemble regression model to [bold #89b4fa]{log-path}[/]") 
  (print-strs-to-console f"  Regressors in ensemble:") 
  (->>  predictor 
        get-models-in-ensemble 
        (mapl #%(+ "    :eight-pointed_star: [#f9e2af]" %1 "[/]")) 
        (.join "\n")
        (.print +console+)))

(defn get-ensemble-stack-predictor [tea-log]
  (-> tea-log
      read-json
      json->records
      (EnsembleStackPredictor)))

(defn fit [tea-log output-pickle]
  (with-path-exists [log-path (make-output-path tea-log)] 
      (let [predictor (get-ensemble-stack-predictor log-path)]
        (make-section-title "Fit Ensemble Stack Predictor Regression Model")
        (print-ensemble-models log-path predictor)
        (let [pickle-path (make-output-path output-pickle)]
          (save-file :data predictor
                     :output-path pickle-path
                     :msg f"✔ Saving ensemble stack predictor to [#a6e3a1]{pickle-path}[/]"
                     :write-fn write-pickle)))))

;;; ======================================================================== ;;;
;;;                                  Predict                                 ;;;
;;; ======================================================================== ;;;

(defn get-predictions [predictor input-data conditions]
  (-> predictor
      (.predict input-data)
      (.transpose)
      (.set-axis conditions :axis 1)
      (.reset-index :names ["supplement_medium"])))

(defn prepare-rich-table-prediction-data [prediction-df [limit 10]]
   (let [well-being-column (df-columns prediction-df :select "mood")]
     (-> prediction-df 
       (.sort-values :by well-being-column :ascending False) 
       (.rename-columns :new-column-names {(get well-being-column 0) "quantity"}) 
       (.assign #** {"quantity" #%(-> (get %1 "quantity") 
                                      (- (.min (get %1 "quantity"))) 
                                      (round 2))}) 
       (.head :n limit))))

(defn make-single-prediction-rich-table [prediction-df]
  (let [well-being-column (df-columns prediction-df :select "mood")]
    (Table :box box.MINIMAL_DOUBLE_HEAD
           :title f"Predictions for {(get well-being-column 0)}"
           :border-style (:table-border +colors+))))

(defn add-single-prediction-rows-to-rich-table [df table]
  (for [[index row] (.iterrows df)] 
    (. table (add-row #* (mapl str row)))))

(defn add-single-prediction-cols-to-rich-table [df table]
  (mapl #%(.add-column table %1 :style (:table-column +colors+)) (. df columns)))

(defn single-prediction-df->rich-table [prediction-df [limit 10]]
  (let [rich-table (make-single-prediction-rich-table prediction-df)
        df (prepare-rich-table-prediction-data prediction-df limit)]
    (add-single-prediction-cols-to-rich-table df rich-table)
    (add-single-prediction-rows-to-rich-table df rich-table)
    rich-table))

(defn print-predictions-rich-tables [predictions-df conditions [limit 10]]
  (->> (mapl #%(-> predictions-df 
                   (get ["supplement_medium" %1])
                   (single-prediction-df->rich-table :limit limit))
            conditions)
      (Columns :equal True :expand True) 
      (.print +console+)))

(defn make-input-scores-dataframe [mood depression focus anxiety energy]
  (as-> [mood depression focus anxiety energy] it
    (if (isinstance mood Iterable) (zip #* it) [it])
    (.DataFrame pd :data it :columns ["score.mood" "score.depression" "score.focus"
                                      "score.anxiety" "score.energy"])))

(defn scores-df->strings [scores-df]
  (let [join-kvs #%(->> (lfor [k v] (.items %1) f"{k}={v}") (.join ", "))]
    (mapl join-kvs (.to-dict scores-df :orient "records"))))

(defn df->csv [df filename]
  (.to-csv df filename :index False))

(defn predict [fit-file mood depression focus anxiety energy [limit 10] [output-predictions None]]
  (with-path-exists [fit-path (make-output-path fit-file)] 
    (let [predictor (read-pickle fit-path)
          input-data (make-input-scores-dataframe mood depression focus anxiety energy)
          conditions (->> input-data scores-df->strings (mapl #%(re.sub "score." "" %1)))
          predictions-df (get-predictions predictor input-data conditions)]
      (make-section-title "Stack Predictions based on Ensemble Regression Model")
      (.print +console+)
      (print-predictions-rich-tables predictions-df conditions :limit limit) 
      (unless-path-is-none [pred-path (make-output-path output-predictions)] 
        (save-file :data predictions-df
                   :output-path pred-path
                   :msg f"✔ Saving predictions to [#a6e3a1]{pred-path}[/]"
                   :write-fn df->csv)))))

;;; ======================================================================== ;;;
;;;                                 Pipeline                                 ;;;
;;; ======================================================================== ;;;

(defn run-pipeline [pipeline-file [output-html None]] 
  (with-path-exists [pipeline-path (make-input-path pipeline-file)]
    (let [pipeline (read-json pipeline-path)] 
      (when (in "parse" pipeline) (parse-tea-log #** (:parse pipeline)))
      (when (in "pydantic_model" pipeline) (pydantic-model #** (:pydantic_model pipeline)))
      (when (in "fit" pipeline) (fit #** (:fit pipeline)))
      (when (in "predict" pipeline) (predict #** (:predict pipeline)))
      (unless-path-is-none [html-path (make-output-path output-html)] 
       ; (. +console+ (save-svg (make-output-path "results-report.svg") :theme +rich-theme+)) ; generate image for README
       (. +console+ (save-html html-path :theme +rich-theme+))))))
 
(defmain [] 
  (.Fire fire {"parse" parse-tea-log
               "pydantic-model" pydantic-model
               "fit" fit
               "predict" predict
               "run-pipeline" run-pipeline}))


