#!/usr/bin/env python
# Utility for training RF model on feature table and predicting new labels
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
        features_train = features.filter(items=metadata.index, axis=1)
        features_test = features[features.columns.difference(metadata.index)]
        predict = True
        print("Will use " + str(features_train.shape[1]) + " common samples for model training and " + str(features_test.shape[1]) + " samples to predict new labels")
    else:
        features_train = features
        predict = False
        print("Samples from feature table and metadata are the same! Will only train model, nothing to predict")

    model = RandomForestClassifier(n_estimators=100)
    X_train = features_train.T
    y_train = [metadata.loc[i, 1] for i in X_train.index]

    model.fit(X_train, y_train)
    dump(model, outName+".joblib")

    print("Model accuracy after training:")
    print(classification_report(y_train, model.predict(X_train)))

    if predict:
        X_test = features_test.T
        y_pred = model.predict(X_test)

        outFile = open(outName+".tsv", "w")
        for sam, pred in zip(X_test.index, y_pred):
            print(sam, pred, sep="\t", file=outFile)
        outFile.close()
        print("Predicted labels saved to "+outName+".tsv")
