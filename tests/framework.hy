(import inspect)

(require hyrule [ -> ->> as-> defmain]) 

(defmacro assert! [op actual expected description]
  `(try
     (assert (~op ~actual ~expected))
     f"✔ Pass: {~description}"
     (except [e AssertionError]
             f"✘ Fail: {~description} => Actual: {~actual} !{'~op} Expected: {~expected}")))

(defmacro assert= [actual expected description]
  `(assert! = ~actual ~expected ~description))

(defmacro assert!= [actual expected description]
  `(assert! != ~actual ~expected ~description))

(defmacro assertT [actual description]
  `(assert! = ~actual True ~description))

(defmacro assertF [actual description]
  `(assert! = ~actual False ~description))
 
(defn get-func-info [func]
  (when (callable func)
    {"module" (. (. inspect (getmodule func) __name__))
     "filename" (. inspect (getfile func))
     "lineno" func.__code__.co_firstlineno}))

(defmacro deftest [func-name #* body]
  `(defn ~(hy.models.Symbol f"test-{func-name}") []
     {"test" f"{'~func-name}"
      "info" (try 
               (get-func-info ~func-name)
               (except [[NameError TypeError]]
                       {"module" None "filename" None "lineno" None}))
      "results" (do [~@body])}))

; (deftest sum-num (return (+ 1 2)))
; (test-sum-num)

