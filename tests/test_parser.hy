(import  framework [get-func-info]
         tea-log.parser [parse-supplement-mix 
                         get-supplement-mix-ratio 
                         split-supplement-mix 
                         parse-medium 
                         clean-supplement-name
                         standardize-supplement-name
                         categorize-stack-entry
                         parse-stack
                         parse-scores
                         parse-date
                         parse-time
                         parse-line]
         toolz [concatv])

(require hyrule [ -> ->> as-> defmain]
         framework [assert= assert!= assertT assertF deftest])

;;; ======================================================================== ;;;
;;;                              Supplement Mix                              ;;;
;;; ======================================================================== ;;;

(deftest parse-supplement-mix
  (assert= (parse-supplement-mix "matcha_+_cinnamon_3:1")
           {"supplements" ["matcha" "cinnamon"] "ratio" ["3:1"]}
           "Should correctly parse a mix of two supplements with a ratio")

  (assert= (parse-supplement-mix "saffron_+_omega_3_2:3")
           {"supplements" ["saffron" "omega_3"] "ratio" ["2:3"]}
           "Should correctly parse a mix of two supplements with a ratio when one constituent contains an underscore")

  (assert= (parse-supplement-mix "saffron_+_omega_3")
           {"supplements" ["saffron" "omega_3"] "ratio" []}
           "Should correctly parse a mix of two supplements with no ratio and the last constituent ends in a number")

  (assert= (parse-supplement-mix "matcha_+_cinnamon_+_saffron_5:2:4")
           {"supplements" ["matcha" "cinnamon" "saffron"] "ratio" ["5:2:4"]}
           "Should correctly parse a mix of *three* supplements with a ratio")

  (assert!= (parse-supplement-mix "rose_water + cardamom 1:4")
            {"supplements" ["rose_water" "cardamom"] "ratio" ["1:4"]}
            "Should fail parsing if supplements are not separated by '_+_'")

  (assert!= (parse-supplement-mix "matcha_+_cinnamon 3:1")
            {"supplements" ["matcha" "cinnamon"] "ratio" ["3:1"]}
            "Should fail parsing if an underscore is not before the start of the ratio")

  (assert!= (parse-supplement-mix "matcha_+_cinnamon_5/2")
            {"supplements" ["matcha" "cinnamon"] "ratio" ["5/2"]}
            "Should fail parsing if a colon is not between numbers in the ratio"))

(deftest get-supplement-mix-ratio
  (assert= (get-supplement-mix-ratio ["matcha" "cinnamon"] ["3:1"])
           [0.75 0.25]
           "Should correctly calculate the ratio for each supplement given an input ratio")

  (assert= (get-supplement-mix-ratio ["saffron" "omega_3"] [])
           [0.5 0.5]
           "Should evenly divide ratios when no input ratio is provided")

  (assert= (get-supplement-mix-ratio ["rose_water" "cardamom"] ["3:1:4"])
           [0.75 0.25]
           "Should ignore extra numbers in the input ratio")

  (assert= (get-supplement-mix-ratio ["matcha" "cinnamon"] ["3"])
           [1.0]
           "Should have the length of the returned list equal to the length of the input ratio")

  (assert= (get-supplement-mix-ratio ["saffron" "omega_3" "cinnamon"] ["3:5:2"])
           [0.3 0.5 0.2]
           "Should correctly calculate the ratio for each supplement in a three-element list given an input ratio"))

(deftest split-supplement-mix
  (assert= (split-supplement-mix "matcha_+_cinnamon_3:1" 0.75)
           {"matcha" 0.5625 "cinnamon" 0.1875}
           "Should correctly split a parsed mix of two supplements with a ratio")

  (assert= (split-supplement-mix "saffron_+_omega_3_+_cardamom_5:2:3" 1.25)
           {"saffron" 0.625 "omega_3" 0.25 "cardamom" 0.375}
           "Should correctly split a parsed mix of *three* supplements with a ratio")

  (assert= (split-supplement-mix "saffron_+_omega_3" 1.0)
           {"saffron" 0.5 "omega_3" 0.5}
           "Should evenly split quantity among all supplements when no ratio is provided")

  (assert= (split-supplement-mix "rose_water" 0.75)
           {"rose_water" 0.75}
           "Should return a single ingredient supplement (no mix) without a ratio as a {supplement quantity} dictionary"))

;;; ======================================================================== ;;;
;;;                                  Medium                                  ;;;
;;; ======================================================================== ;;;

(deftest parse-medium
  (assert= (parse-medium "hot black tea")
           {"type" "black tea" "temperature" "hot"}
           "Should correctly parse a hot medium with a regular type")

  (assert= (parse-medium "cold green tea")
           {"type" "green tea" "temperature" "cold"}
           "Should correctly parse a cold medium with a regular type")

  (assert= (parse-medium "hot matcha tea +  oat milk")
           {"type" "matcha tea plus oat milk" "temperature" "hot"}
           "Should correctly parse a hot medium with multiple spaces and '+' characters in the type")

  (assert= (parse-medium "cold_oolong_tea")
           {"type" "oolong_tea" "temperature" "cold"}
           "Should correctly parse a cold medium with underscores in the type")

  (assert= (parse-medium "HOT_Green Tea")
           {"type" "green tea" "temperature" "hot"}
           "Should correctly parse a hot medium with mixed case and special characters in the type")

  (assert= (parse-medium "hot")
           {"type" "" "temperature" "hot"}
           "Should correctly handle parsing with no type provided")

  (assert= (parse-medium "black coffee")
           {"type" "black coffee" "temperature" "cold"}
           "Should correctly handle parsing with no temperature provided (default to 'cold')")

  (assert= (parse-medium "")
           {"type" "" "temperature" "cold"}
           "Should correctly handle parsing with empty input (default to 'cold')")

  (assert= (parse-medium "   ")
           {"type" "" "temperature" "cold"}
           "Should correctly handle parsing with input containing only spaces (default to 'cold')")

  (assert= (parse-medium "hot_coffee_+_milk_")
           {"type" "coffee_plus_milk" "temperature" "hot"}
           "Should correctly parse a hot medium with special characters in the type"))

;;; ======================================================================== ;;;
;;;                                   Stack                                  ;;;
;;; ======================================================================== ;;;

;;; -------------------------- Single stack entry -------------------------- ;;;

(deftest clean-supplement-name
  (assert= (clean-supplement-name "Matcha Tea")
           "matcha_tea"
           "Should correctly clean a supplement name with spaces")

  (assert= (clean-supplement-name "Omega-3")
           "omega_3"
           "Should correctly clean a supplement name with hyphen")

  (assert= (clean-supplement-name "Vitamin C (Ascorbic Acid)")
           "vitamin_c_ascorbic_acid"
           "Should correctly clean a supplement name with parentheses and spaces")

  (assert= (clean-supplement-name "CoQ10 (Coenzyme Q10)")
           "coq10_coenzyme_q10"
           "Should correctly clean a supplement name with parentheses and spaces and multiple spaces")

  (assert= (clean-supplement-name "St. John's Wart")
           "st_johns_wart"
           "Should correctly clean a supplement name with period and apostrophe special characters")

  (assert= (clean-supplement-name "L-Carnitine + Acetyl L-Carnitine")
           "l_carnitine_+_acetyl_l_carnitine"
           "Should correctly clean a supplement name with '+' and spaces")

  (assert= (clean-supplement-name "Curcumin (from Turmeric)")
           "curcumin_from_turmeric"
           "Should correctly clean a supplement name with parentheses and spaces and 'from' keyword")

  (assert= (clean-supplement-name "N-Acetyl-L-Cysteine (NAC)")
           "n_acetyl_l_cysteine_nac"
           "Should correctly clean a supplement name with parentheses and '-'"))

(deftest standardize-supplement-name
  (assert= (standardize-supplement-name "vitamin_b_complex")
           "vitamin_b_complex"
           "Should not modify an already standardized supplement name")

  (assert= (standardize-supplement-name "vitamin b5")
           "vitamin_b_complex"
           "Should standardize 'vitamin b5' to 'vitamin_b_complex'")

  (assert= (standardize-supplement-name "nuun")
           "nuun_energy"
           "Should standardize 'nuun' to 'nuun_energy'")

  (assert= (standardize-supplement-name "hibiscus")
           "hibiscus_flower"
           "Should standardize 'hibiscus' to 'hibiscus_flower'")

  (assert= (standardize-supplement-name "vitamin B Complex")
           "vitamin_b_complex"
           "Should standardize 'vitamin B Complex' (with spaces) to 'vitamin_b_complex'")

  (assert= (standardize-supplement-name "nuun  Energy")
           "nuun_energy"
           "Should standardize 'nuun Energy' (with spaces) to 'nuun_energy'")
  
  (assert= (standardize-supplement-name "valerian")
           "valerian_root"
           "Should standardize 'valerian' (with spaces) to 'valerian root'"))

(deftest categorize-stack-entry
  (assert= (categorize-stack-entry "hot_water" 4)
           {"medium" {"type" "water" "temperature" "hot"}}
           "Should correctly categorize a (cleaned) medium entry")

  (assert= (categorize-stack-entry "matcha_tea_+_ginger_2:1" 0.75)
           {"supplements" {"matcha_tea" 0.5 "ginger" 0.25}}
           "Should correctly categorize a (cleaned) supplement mix entry")

  (assert= (categorize-stack-entry "turmeric" 0.5)
           {"supplements" {"turmeric" 0.5}}
           "Should correctly categorize a regular supplement entry")

  (assert= (categorize-stack-entry "" 0.0)
           {"supplements" {"" 0.0}}
           "Should correctly handle an empty entry and set quantity to 0.0"))

;;; ------------------------------ Full stack ------------------------------ ;;;

(deftest parse-stack
  (let [line "- 0.75 St. John's Wart, 0.75 turmeric, 0.75 rose water + cardamom (3:1), 0.75 ginger, 8 hot black tea"
        result {"supplements" {"st_johns_wart" 0.75
                               "turmeric" 0.75
                               "rose_water" 0.5625
                               "cardamom" 0.1875
                               "ginger" 0.75}
                "medium" {"type" "black_tea" "temperature" "hot"}}]
        (assert= (parse-stack line) result
                 "Should correctly parse stack line with supplements, supplement mixes and medium types"))
  
    
  (let [line " - 0.75   shatavari,  0.75 matcha +   cinnamon (3:1) , 1.5 valerian   root, 8   hot black tea"
        result {"supplements" {"shatavari" 0.75 "matcha" 0.5625 "cinnamon" 0.1875 "valerian_root" 1.5}
                "medium" {"type" "black_tea" "temperature" "hot"}}]
    (assert= (parse-stack line) result
             "Should correctly parse stack with arbitrary number of spaces between words"))
  
  (let [line "- 8 hot black tea"
        result {"supplements" {}
                "medium" {"type" "black_tea" "temperature" "hot"}}]
    (assert= (parse-stack line) result
            "Should correctly parse a stack line with no supplements and medium only"))

  (let [line "- 0.75 Turmeric, 0.5 ginger, 1.5 shatavari"
      result {"supplements" {"turmeric" 0.75 "ginger" 0.5 "shatavari" 1.5}
              "medium" {"type" "sparkling_water" "temperature" "cold"}}]
  (assert= (parse-stack line) result
           "Should correctly parse a stack line with supplements only and no medium"))

  (let [line "- 1 St. John’s Wart, 1 St. John’s Wart, 1 St. John’s Wart, 8 hot green tea"
        result {"supplements" {"st_johns_wart" 1.0}
                "medium" {"type" "green_tea" "temperature" "hot"}}]
    (assert= (parse-stack line) result
            "Should correctly aggregate multiple entries of the same supplement")))

;;; ======================================================================== ;;;
;;;                                  Scores                                  ;;;
;;; ======================================================================== ;;;

(deftest parse-scores 
  (let [line "    -  Mood: 4.5, Depression: 4, Focus:  4.5, Anxiety: 4, Energy: 4"
        result {"mood" 4.5
                "depression" 4.0
                "focus" 4.5
                "anxiety" 4.0
                "energy" 4.0}]
    (assert= (parse-scores line) result
            "Should correctly parse scores with various well-being factors"))
  
  (let [line "    -  Mood : 5.0   ,  Depression : 2.5  ,   Focus :  4.0,  Anxiety: 3.5 ,  Energy: 3.00"
        result {"mood" 5.0
                "depression" 2.5
                "focus" 4.0
                "anxiety" 3.5
                "energy" 3.0}]
    (assert= (parse-scores line) result
            "Should correctly parse scores with well-being factors containing spaces"))
  
  (let [line "    -  Mood: 4.5, Focus:  4.5, Energy: 4"
        result {"mood" 4.5
                "focus" 4.5
                "energy" 4.0}]
    (assert= (parse-scores line) result
            "Should correctly handle parsing scores with missing well-being factors")))


;;; ======================================================================== ;;;
;;;                                   Date                                   ;;;
;;; ======================================================================== ;;;
                                
(deftest parse-date 
  (assert= (parse-date "Date: July 4, 2023")
            "2023-07-04"
            "Should correctly parse a date with full month name")
  
  (assert= (parse-date "Date: May 9, 2023")
            "2023-05-09"
            "Should correctly parse another date with full month name"))

;;; ======================================================================== ;;;
;;;                                   Time                                   ;;;
;;; ======================================================================== ;;;

(deftest parse-time 
  (assert= (parse-time "- Time: 18:00")
            "18:00"
            "Should correctly parse a time entry with a valid format")
  
  (assert= (parse-time "- tImE: 09:30")
            "09:30"
            "Should correctly parse a time entry with different casing")
  
  (assert= (parse-time "- Time:  14:15  ")
            "14:15"
            "Should correctly parse a time entry with leading and trailing spaces")
  
  (assert= (parse-time "- Time: ")
            ""
            "Should correctly handle parsing an empty time entry") 

  (assert= (parse-time "12:45")
            "12:45"
            "Should correctly parse a time entry with only the time component"))

;;; ======================================================================== ;;;
;;;                                Parse line                                ;;;
;;; ======================================================================== ;;;

(deftest parse-line 
  (assert= (parse-line (.lower "Date:  September 4, 2023"))
            {"date" "2023-09-04"}
            "Should correctly parse a line with a date") 
  
  (assert= (parse-line (.lower "  -  Mood: 3.0, Depression: 3.0, Focus:  3.0, Anxiety: 3, Energy: 4.0"))
            {"scores" {"mood" 3.0 "depression" 3.0 "focus" 3.0 "anxiety" 3.0 "energy" 4.0}}
            "Should correctly parse a line with mood scores")
  
   (assert= (parse-line (.lower "   - Time: 9:45"))
            {"time" "9:45:00"}
            "Should correctly parse a line with time and format it as 'HH:MM:SS'")
  
  (assert= (parse-line "")
            {}
            "Should handle an empty line and return an empty map")
  
  (assert= (parse-line "   ")
            {}
            "Should handle a line with only whitespace and return an empty map"))

;;; ======================================================================== ;;;
;;;                                Test parser                               ;;;
;;; ======================================================================== ;;;

(defn test-parser []
  [{"description" f"Functions to parse and split supplement mixes"
     "suites" [(test-parse-supplement-mix)
               (test-get-supplement-mix-ratio)
               (test-split-supplement-mix)]}
   {"description" f"Function to parse medium"
   "suites" [(test-parse-medium)]}
   {"description" f"Functions to parse entire stack (supplements + medium)"
    "suites" [(test-clean-supplement-name)
              (test-standardize-supplement-name)
              (test-categorize-stack-entry)
              (test-parse-stack)
              (test-parse-scores)
              (test-parse-date)
              (test-parse-time)
              (test-parse-line)]}])