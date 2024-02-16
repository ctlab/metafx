#!/usr/bin/env python
# Utility for training RF model on feature table
import sys
import numpy as np
import pandas as pd
from joblib import dump
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from xgboost import XGBClassifier
from sklearn import preprocessing
from metafx_torch import TorchLinearModel
import torch

if __name__ == "__main__":
    features = pd.read_csv(sys.argv[1], header=0, index_col=0, sep="\t")
    outName = sys.argv[2]
    metadata = pd.read_csv(sys.argv[3], sep="\t", header=None, index_col=0, dtype=str)
    metadata.index = metadata.index.astype(str)

    if set(features.columns) != set(metadata.index):
        features = features.filter(items=metadata.index, axis=1)
        print("Samples from feature table and metadata does not match! " +
              "Will use only " + str(features.shape[1]) + " common samples")

    M = features.shape[0]  # features count
    N = features.shape[1]  # samples  count

    X = features.T
    y = np.array([metadata.loc[i, 1] for i in X.index])

    model = None
    if sys.argv[4] == "RF":
        model = RandomForestClassifier(n_estimators=100)
    elif sys.argv[4] == "XGB":
        model = XGBClassifier(n_estimators=100)
    else:
        model = TorchLinearModel(n_features=M, n_classes=len(set(y)))

    if sys.argv[4] == "XGB":
        le = preprocessing.LabelEncoder()
        le.fit(y)
        y = le.transform(y)
    elif sys.argv[4] == "Torch":
        le = preprocessing.LabelEncoder()
        le.fit(y)
        y = le.transform(y)

    model.fit(X, y)

    if sys.argv[4] == "RF":
        dump(model, outName + ".joblib")
    elif sys.argv[4] == "XGB":
        dump(model, outName + ".joblib")
        dump(le, outName + "_le.joblib")
    elif sys.argv[4] == "Torch":
        torch.save(model, outName + ".joblib")
        dump(le, outName + "_le.joblib")

    print("Model accuracy after training:")
    print(classification_report(y, model.predict(X)))
