(import pathlib [Path]
        datetime [datetime]
        re
        copy [deepcopy] 
        toolz [get-in concatv]
        pandas :as pd
        janitor [transform-column]
        rich [box print :as rprint]
        rich.console [Console TerminalTheme]
        rich.table [Table]
        rich.text [Text]
        tea-log.utils [mapl]
        test-framework [test-framework]
        test-utils [test-utils]
        test-parser [test-parser])

(require hyrule [ -> ->> as-> unless defmain let+ fn+ doto])
(require hyrule :readers [%])

(setv +log-folder+ (Path "logs")
      +console+ (Console :record True)
      +colors+ {"pass" "#a6e3a1" "fail" "#f38ba8" "table_border" "#a6adc8" "table_column" "#b4befe"}
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

(defn update-dict [source-dict update-dict]
  (.update source-dict update-dict)
  source-dict)

(defn test-results->records [test-results]
  (let [records []
        test-count 0
        entry {"Package" (:package test-results)
               "StartDateTime" (:start_datetime test-results)
               "FinishDateTime" (:finish_datetime test-results)}]
    (for [run (:runs test-results)]
      (. entry (update {"Description" (:description run)}))
      (for [suite (:suites run)]
        (.update entry {"Function/Macro" (:test suite)
                        "Module" (get-in ["info" "module"] suite)
                        "Filename" (get-in ["info" "filename"] suite)
                        "LineNo" (str (get-in ["info" "lineno"] suite))})
        (for [result (:results suite)]
          (setv test-count (+ 1 test-count))
          (as-> entry it
            (update-dict it {"#" test-count
                             "Behavior" (cut result 8 None)
                             "Pass/Fail" (cut result 0 6)})
            (.copy it)
            (.append records it)))))
    records))

(defn test-results->df [test-results]
  (->> test-results
       test-results->records 
       (.DataFrame pd :columns ["#" "Package" "StartDateTime" "FinishDateTime"
                                "Module" "Filename" "Description" "Function/Macro"
                                "LineNo" "Behavior" "Pass/Fail"])))

(defn calculate-execution-time [start-datetime finish-datetime]
  (->> [finish-datetime start-datetime] 
       (mapl #%(.strptime datetime %1 "%Y-%m-%d %H:%M:%S.%f"))
       ((fn+ [[f s]] (- f s)))
       (.total-seconds))) 

(defn test-results-df->rich-format [test-results-df]
  (let [format-value #%(do f"[bold {%2}]{(str %1)}[/bold {%2}]")]
      (-> test-results-df
          (.transform-column :column-name "Pass/Fail"
                             :function #%(if (in "Pass" %1) 
                                           (format-value %1 (:pass +colors+))
                                           (format-value %1 (:fail +colors+))))
          (.transform-column :column-name "Behavior"
                             :function #%(->> %1
                                              (re.sub " => " "\n")
                                              (re.sub r"Actual(.*)(\s)(.*)(\s)Expected(.*)"
                                                      r"Actual\1\n\3\nExpected\5"))))))

(defn add-test-results-df-cols-to-rich-table [test-results-df rich-table]
  (mapl #%(.add-column rich-table %1 :style (:table-column +colors+)) (. test-results-df columns)))

(defn add-test-results-df-rows-to-rich-table [test-results-df rich-table]
  (for [[index row] (.iterrows test-results-df)] 
    (if (in "Pass" (get row "Pass/Fail"))
      (. rich-table (add-row #* (mapl str row)))
      (. rich-table (add-row #* (mapl str row) :style f"bold {(:fail +colors+)}"))))) 

(defn make-test-results-rich-table-title [test-results-df] 
  (let+ [first-row (-> test-results-df (.head 1) (.to-dict :orient "records") (get 0))
         {package "Package"
          start_datetime "StartDateTime"
          finish_datetime "FinishDateTime"} first-row
         execution-time (calculate-execution-time start_datetime finish_datetime)]
        (+ f":package: [bold underline]{package}[/bold underline] "
           f"tested on {start_datetime} [Execution time :clock2:: {execution-time}s]")))

(defn test-results-df->rich-table [test-results-df]
  (let [table (Table :title (make-test-results-rich-table-title test-results-df) 
                     :box box.HORIZONTALS 
                     :border-style (:table-border +colors+))
        df (-> test-results-df 
               test-results-df->rich-format
               (.drop ["Package" "StartDateTime" "FinishDateTime" "Filename"] :axis 1))] 
    (add-test-results-df-cols-to-rich-table df table)
    (add-test-results-df-rows-to-rich-table df table) 
    (.print +console+ table :justify "center")))

(defn print-post-test-info [csv-filename html-filename]
  (->> (+ f"\n:file_cabinet:  [grey70]Test results saved to "
          f"{csv-filename} and {html-filename}.[/grey70]")
       (.print +console+ :justify "center")))

(defn print-post-test-credits []
  (->> (+ "[grey50]\n Made with :red_heart: using "
          "[link=https://github.com/Textualize/rich]rich[/link] "
          "and [link=https://github.com/catppuccin/catppuccin]catpuccin[/link] "
          "color scheme.[/grey50]")
       (.print +console+ :justify "center")))

(defn summarize-test-results [test-results-df]
  (-> test-results-df
      (.groupby ["Module"]) 
      (.agg :Total #("Module" "count") 
            :Pass #("Pass/Fail" #%(.sum (= %1 "✔ Pass"))) 
            :Fail #("Pass/Fail" #%(.sum (= %1 "✘ Fail"))))
      (.reset-index)))

(defn test-summary-df->rich-format [summary-df]
  (let [format-value #%(do f"[bold {%2}]{(str %1)}[/bold {%2}]")]
   (-> summary-df
      (.transform-column :column-name "Pass"
                         :function #%(if (= 0 %1) 
                                       (format-value %1 (:fail +colors+))
                                       (format-value %1 (:pass +colors+))))
       (.transform-column :column-name "Fail"
                          :function #%(if (< 0 %1)
                                        (format-value %1 (:fail +colors+))
                                        (format-value %1 (:pass +colors+)))))))

(defn add-test-summary-df-cols-to-rich-table [footer table]
  (let [make-footer #%(-> (get footer %1) str (Text :style %2))]
   (doto table 
    (.add-column "Module" :style (:table-column +colors+))
    (.add-column "Total" 
                 :style "#f9e2af" 
                 :footer (make-footer "Total" "#f9e2af"))
    (.add-column "Pass" 
                 :style (:table-column +colors+) 
                 :footer (make-footer "Pass" (:pass +colors+)))
    (.add-column "Fail" 
                 :style (:table-column +colors+) 
                 :footer (make-footer "Fail" (if (= 0 (:Fail footer)) 
                                               (:pass +colors+)
                                               (:fail +colors+)))))))

(defn add-test-summary-df-rows-to-rich-table [summary-df rich-table]
  (for [[index row] (.iterrows summary-df)] 
      (. rich-table (add-row #* (mapl str row)))))

(defn print-post-test-summary-warning []
   (->> (+ f"\n:warning: [grey70]Results from tests for macros are "
            "[italic underline]not[/italic underline] included![/grey70]\n\n")
         (.print +console+ :justify "center")))

(defn test-summary-df->rich-table [summary-df]
  (let [results (-> summary-df (.sum :numeric-only True) (.to_dict))
        rich-df (test-summary-df->rich-format summary-df) 
        table (Table :box box.MINIMAL_DOUBLE_HEAD
                     :title f"{(:Fail results)} failed out of {(:Total results)} tests"
                     :border-style (:table-border +colors+)
                     :show-footer True)] 
    (add-test-summary-df-cols-to-rich-table results table) 
    (add-test-summary-df-rows-to-rich-table rich-df table)
    (.print +console+ table :justify "center") 
    (print-post-test-summary-warning)))

(defn run-tests []
  {"package" "tea-log"
   "start_datetime" (-> datetime (. (now)) (. (strftime "%Y-%m-%d %H:%M:%S.%f")))
   "runs" (list (concatv (test-framework)
                         (test-utils)
                         (test-parser)))
   "finish_datetime" (-> datetime (. (now)) (. (strftime "%Y-%m-%d %H:%M:%S.%f")))})

(defmain []
  (let [test-results (run-tests)
        test-results-label (->> test-results (:start_datetime) (re.sub r"\..*" "") (re.sub r"[^0-9]" ""))
        csv-filename (/ +log-folder+ (Path f"{test-results-label}.csv"))
        html-filename (/ +log-folder+ (Path f"{test-results-label}.html"))
        df (test-results->df test-results)] 
    (. df (to-csv csv-filename :index False))  
    (.rule +console+ "Summary Report") 
    (.print +console+ "\n")
    (-> df summarize-test-results test-summary-df->rich-table)
    (.rule +console+ "Detailed Report")
    (.print +console+ "\n")
    (test-results-df->rich-table df) 
    (print-post-test-info csv-filename html-filename)
    (print-post-test-credits)
   ; (. +console+ (save-svg (/ +log-folder+ (Path f"{test-results-label}.svg")) :theme +rich-theme+)) ; generate image for README
    (. +console+ (save-html html-filename :theme +rich-theme+))))
  




