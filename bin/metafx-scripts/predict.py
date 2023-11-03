#!/usr/bin/env python
# Utility for predicting labels based on pre-trained RF model
import sys
import pandas as pd
from joblib import load
from sklearn.metrics import classification_report


if __name__ == "__main__":
    features = pd.read_csv(sys.argv[1], header=0, index_col=0, sep="\t")
    outName = sys.argv[2]
    model = load(sys.argv[3])
    metadata = None
    if len(sys.argv) == 5:
        metadata = pd.read_csv(sys.argv[4], sep="\t", header=None, index_col=0, dtype=str)
        metadata.index = metadata.index.astype(str)

    M = features.shape[0]  # features count
    N = features.shape[1]  # samples  count

    X = features.T
    y_pred = model.predict(X)

    outFile = open(outName + ".tsv", "w")
    for sam, pred in zip(X.index, y_pred):
        print(sam, pred, sep="\t", file=outFile)
    outFile.close()

    if metadata is not None:
        y = [metadata.loc[i, 1] for i in X.index]
        print("Predictions accuracy compared with given labels:")
        print(classification_report(y, y_pred, zero_division=0))
