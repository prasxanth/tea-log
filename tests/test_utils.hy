(import  framework [get-func-info]
         tea-log.utils [rxsub merge-kv contains-substring? calculate-ratios]) 

(require hyrule [ -> ->> as-> defmain]
         framework [assert= assert!= assertT assertF deftest])

(deftest rxsub
  (assert= (rxsub "St. John's Wart" #(r"[().\']" ""))
           "St Johns Wart"
           "Should remove special characters")
   
   (assert= (rxsub "St. John's Wart" #(r"[().\']" "") #(r" " "_"))
           "St_Johns_Wart"
           "Should remove special characters and replace spaces with '_'")
   
   (assert= (rxsub "St. John's Wart" #(r"[().\']" "") #(r" " "_") #(r"St" "uv"))
           "uv_Johns_Wart"
           "Should remove special characters, replace spaces with '_', and replace 'St' with 'uv'"))

(deftest merge-kv
  (assert= (merge-kv {"a" "A" "b" "B" "c" "C" "d" "D"} ["a" "b"] "ab")
           {"a" "A" "b" "B" "ab" "A B" "c" "C" "d" "D"}
           "Should merge two keys with string values")

  (assert= (merge-kv {"a" "A" "b" "B" "c" "C" "d" "D"} ["a" "b"] "cd" :remove-original True)
           {"c" "C" "d" "D" "cd" "A B"}
           "Should merge two keys with string values and remove the original")

  (assert= (merge-kv {"a" 1 "b" "B" "c" "C" "d" "D"} ["a" "b"] "ab")
           {"a" 1 "b" "B" "c" "C" "d" "D" "ab" "1 B"}
           "Should merge one key with a string value and another with an integer value")

  (assert= (merge-kv {"a" "A" "b" "B" "c" "C" "d" "D"} ["a" "b"] "ab" :join-sep "-")
           {"a" "A" "b" "B" "ab" "A-B" "c" "C" "d" "D"}
           "Should merge two keys with string values with '-' separator")

  (assert= (merge-kv {"a" "A" "b" "B" "c" "C" "d" "D"} ["e" "a"] "ab" :join-sep "-")
           {"a" "A" "b" "B" "c" "C" "d" "D"}
           "Should return the original dictionary when any of the keys to be merged are not in the dictionary"))

(deftest contains-substring?
  (assertT (contains-substring? "Hello, World!" ["Hello" "foo" "bar"])
           "Text contains one string from list")

  (assertF (contains-substring? "Hello, World!" ["Hy" "Python" "great"])
           "Text contains no string from list")

  (assertF (contains-substring? "Hello, World!" [])
           "No match for empty substrings list")

  (assertF (contains-substring? "" [])
           "No match for empty text and empty substrings list")

  (assertT (contains-substring? "Hy. is. #$%& great 987!" ["Hy." "#$%&" "987!"])
           "Match special characters in substrings list"))

(deftest calculate-ratios
  (assert= (calculate-ratios [1 2 3 4])
           [0.1 0.2 0.3 0.4]
           "Should correctly calculate ratios for a list of positive integers")

  (assert= (calculate-ratios [5])
           [1.0]
           "Should correctly calculate the ratio for a list with only one integer")

  (assert= (calculate-ratios [])
           []
           "Should return empty list when ratio is an empty list")

  (assert= (calculate-ratios [-1 -2 -3 -4])
           [0.1 0.2 0.3 0.4]
           "Should correctly calculate ratios for a list of negative integers")

  (assert= (calculate-ratios [0.5 1.75 2.75])
           [0.1 0.35 0.55]
           "Should correctly calculate ratios for a list of positive floating-point numbers"))
  
(defn test-utils []
  [{"description" f"General utility and helper functions"
    "suites" [(test-rxsub) 
             (test-contains-substring?)
             (test-merge-kv)
             (test-calculate-ratios)]}])

   

