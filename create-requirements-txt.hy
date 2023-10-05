(import subprocess
        re
        tea-log.utils [mapl write-txtfile]
        hyrule [flatten distinct]
        toolz [merge]
        stdlib-list [stdlib-list]
        rich.console [Console])

(require hyrule [ -> ->> as-> fn+ defmain])
(require hyrule :readers [%])

(setv  +console+ (Console :record True)
       +stdlib-modules+ (stdlib-list "3.9"))

(defn run-shell-command [cmd]
  (let [result (subprocess.run cmd :shell True :stdout subprocess.PIPE)]
    (.decode result.stdout "utf-8")))

(defn grep-import-sexps []
  (let [cmd "find '.' -type f -name '*.hy' -exec awk '/^\\(import/{p=1} p; /\\)$/ && p{p=0}' RS= {} \\;"]
    (run-shell-command cmd)))

(defn import-sexps->uniq-modules [import-sexps]
  (->> import-sexps
       (.findall re r"\(([^)]+)\)")
       (mapl #%(.sub re r"\[.*?(\n|.)*?\]" "" %1)) ; remove individual function imports between square brackets   
       (mapl #%(.sub re r"import|require| :as.*|tea-log.*|test-.*|framework" "" %1)) ; remove keywords and custom modules
       (mapl #%(.sub re r"sklearn" "scikit-learn" %1))
       (mapl #%(.split %1 "\n"))
       flatten
       (mapl #%(->> %1 (.strip) (.sub re r"\..*" ""))) ; remove submodules 
       (filter #%(!= "" %1)) ; remove empty string
       distinct
       list))

(defn pip-freeze-info []
  (as-> (run-shell-command "pip freeze") it
    (.split it "\n")
    (filter #%(and (in "==" %1) (not (.startswith %1 "# "))) it)
    (map #%(.lower %1) it)
    (map #%(.split %1 "==") it)
    (dict it)))

(defn get-closest-pip-freeze-module [pip-freeze-info module]
  (next (gfor key (.keys pip-freeze-info)
              :if (in module key)
              {key (get pip-freeze-info key)}) None))

(defn remove-modules-in-stdlib [modules]
  (filter #%(not (in %1 +stdlib-modules+)) modules))

(defn get-tea-log-modules [pip-freeze-info modules]
  (->> modules
       (mapl #%(if (in %1 pip-freeze-info)
                 {%1 (get pip-freeze-info %1)}
                 (get-closest-pip-freeze-module pip-freeze-info %1)))))

(defn write-requirements-txt [modules-vers]
  (as-> modules-vers it 
    (filter #%(is-not %1 None) it) 
    (merge #* it)
    (mapl (fn+ [[k v]] f"{k}=={v}") (.items it))
    (.join "\n" it)
    (write-txtfile it "requirements.txt")))

(defmain []
  (let [installed-modules (pip-freeze-info)]
    (->> (grep-import-sexps)
         import-sexps->uniq-modules
         remove-modules-in-stdlib
         (get-tea-log-modules installed-modules)
         (+ [{"hy" "0.26"}])
         write-requirements-txt))
  (.print +console+ "Modules and versions saved to [#a6e3a1]requirements.txt[/]"))

