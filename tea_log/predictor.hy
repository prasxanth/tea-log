(import pathlib [Path]
        json
        tea-log.utils [mapl read-json df-columns]
        toolz [get-in]
        pandas :as pd
        numpy :as np
        janitor [concatenate-columns]
        sklearn.model-selection [train-test-split]
        sklearn.ensemble [RandomForestRegressor]
        sklearn.linear-model [LinearRegression Ridge]
        sklearn.tree [DecisionTreeRegressor]
        sklearn.neighbors [KNeighborsRegressor]
        pickle)

(require hyrule [ -> ->> as-> let+ setv+ unless])
(require hyrule :readers [%])

(defn json->records [data] 
    (mapl #%(dict :supplement (get-in ["stack" "supplements"] %1)
                  :medium (get-in ["stack" "medium"] %1)
                  :score (:scores %1)) 
          data)) 

(defclass EnsembleStackPredictor []
  
  (defn __init__ [self records [features None] [targets None] [models None]]
    (setv self.records records 
      self.encoded-df (self.records->encoded-df)
      self.features (if (is features None)
                      (df-columns self.encoded-df :select "score")
                      features)
      self.targets (if (is targets None)
                     (+ (df-columns self.encoded-df :select "supplement")
                        (df-columns self.encoded-df :select "medium"))
                     targets)
      X (.filter self.encoded-df :items self.features)
      y (.filter self.encoded-df :items self.targets)
      [self.X-train self.X-valid self.y-train self.y-valid] (train-test-split X y :test-size 0.2 :random-state 42)
      self.models (if (is models None)
                    [(RandomForestRegressor :random-state 42)
                     (LinearRegression)
                     (Ridge)
                     (DecisionTreeRegressor :random-state 42)
                     (KNeighborsRegressor)]
                    models) 
      self.model-fits (self.fit-models)))
  
  (defn records->encoded-df [self]
    (as-> self.records it
      (.json-normalize pd it)
      (.fillna it (dfor k (df-columns it :select "supplement") k 0))
      (.fillna it (dfor k (df-columns it :select "score") k 2.5))
      (.concatenate-columns it :column-names ["medium.type" "medium.temperature"]
                            :new-column-name "medium"
                            :sep ":")
      (.drop it ["medium.type" "medium.temperature"] :axis 1)
      (.get-dummies pd it :columns ["medium"] :prefix-sep ".")))
      
  (defn fit-models [self]
    (mapl #%(.fit %1 self.X-train self.y-train) self.models)) 
  
  (defn predict [self df]
    (->> self.model-fits
         (mapl #%(.predict %1 df)) 
         (.mean np :axis 0) 
         (.matrix.round np :decimals 2) 
         (.DataFrame pd :columns self.targets))))
  

