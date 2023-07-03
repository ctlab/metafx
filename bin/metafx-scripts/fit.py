#!/usr/bin/env python
# Utility for training RF model on feature table
import sys
import pandas as pd
from joblib import dump
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report


if __name__ == "__main__":
    features = pd.read_csv(sys.argv[1], header=0, index_col=0, sep="\t")
    outName = sys.argv[2]
    metadata = pd.read_csv(sys.argv[3], sep="\t", header=None, index_col=0, dtype=str)
    metadata.index = metadata.index.astype(str)

    if set(features.columns) != set(metadata.index):
        features = features.filter(items=metadata.index, axis=1)
        print("Samples from feature table and metadata does not match! Will use only " + str(features.shape[1]) + " common samples")

    M = features.shape[0]  # features count
    N = features.shape[1]  # samples  count

    model = RandomForestClassifier(n_estimators=100)
    X = features.T
    y = [metadata.loc[i, 1] for i in X.index]

    model.fit(X, y)
    dump(model, outName+".joblib")

    print("Model accuracy after training:")
    print(classification_report(y, model.predict(X)))
