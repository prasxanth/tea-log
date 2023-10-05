(import framework [get-func-info])

(require hyrule [ -> ->> as-> defmain]
         framework [assert= assert!= assertT assertF deftest])

(deftest assert-macros
  (assert= (+ 1 2) 3 "assert=")
  (assert!= (+ 2 2) 3 "assert!=")
  (assertT (= 1 1) "assertT")
  (assertF False "assertF"))

(defn test-framework [] 
  [{"description" f"Functions and Macros in Test Framework"
   "suites" [(test-assert-macros)]}])

