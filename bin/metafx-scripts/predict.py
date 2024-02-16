#!/usr/bin/env python
# Utility for predicting labels based on pre-trained RF model
import sys
import pandas as pd
from joblib import load
from sklearn.metrics import classification_report
import torch


if __name__ == "__main__":
    features = pd.read_csv(sys.argv[1], header=0, index_col=0, sep="\t")
    outName = sys.argv[2]
    model_type = sys.argv[4]

    if model_type == "RF":
        model = load(sys.argv[3])
    elif model_type == "XGB":
        model = load(sys.argv[3])
        le = load(sys.argv[3][:-7] + "_le.joblib")
    elif model_type == "Torch":
        model = torch.load(sys.argv[3])
        le = load(sys.argv[3][:-7] + "_le.joblib")

    metadata = None
    if len(sys.argv) == 6:
        metadata = pd.read_csv(sys.argv[5], sep="\t", header=None, index_col=0, dtype=str)
        metadata.index = metadata.index.astype(str)

    M = features.shape[0]  # features count
    N = features.shape[1]  # samples  count

    X = features.T
    y_pred = model.predict(X)

    if model_type == "XGB" or model_type == "Torch":
        y_pred = le.inverse_transform(y_pred)

    outFile = open(outName + ".tsv", "w")
    for sam, pred in zip(X.index, y_pred):
        print(sam, pred, sep="\t", file=outFile)
    outFile.close()

    if metadata is not None:
        y = [metadata.loc[i, 1] for i in X.index]
        print("Predictions accuracy compared with given labels:")
        print(classification_report(y, y_pred, zero_division=0))
