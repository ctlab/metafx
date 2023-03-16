#!/usr/bin/env python
# Utility for training RF model and cross-validation on feature table
import sys
import numpy as np
import pandas as pd
from joblib import dump, load
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import StratifiedKFold, GridSearchCV
from sklearn.metrics import classification_report


if __name__ == "__main__":
    features = pd.read_csv(sys.argv[1], header=0, index_col=0, sep="\t")
    outName = sys.argv[2]
    metadata = pd.read_csv(sys.argv[3], sep="\t", header=None, index_col=0, dtype=str)
    metadata.index = metadata.index.astype(str)
    nFolds = int(sys.argv[4])
    gridSearch = True if sys.argv[5] == "true" else False
    nThreads = int(sys.argv[6])

    if set(features.columns) != set(metadata.index):
        features = features.filter(items=metadata.index, axis=1)
        print("Samples from feature table and metadata does not match! Will use only " + str(features.shape[1]) + " common samples")

    M = features.shape[0]  # features count
    N = features.shape[1]  # samples  count

    X = features.T
    y = np.array([metadata.loc[i, 1] for i in X.index])

    if gridSearch:
        model = RandomForestClassifier()
        parameters = {"n_estimators": [10, 20, 30, 40] + list(range(50, 1001, 50)),
                      "max_depth": [None, 2, 3, 4] + list(range(5, 51, 5)),
                     }
        clf = GridSearchCV(model, parameters, scoring='balanced_accuracy', cv=nFolds, verbose=1, n_jobs=nThreads)
        clf.fit(X, y)
        print("\nGrid search cross-validation accuracy:")
        print(pd.DataFrame.from_dict(clf.cv_results_).filter(regex='param_.*|mean_test_score|std_test_score|rank_test_score').to_string())
        print("\nSelected parameters for best Random Forest classifier:")
        for k, v in clf.best_params_.items():
            print("\t", k, "=", v)
        print()
        dump(clf.best_estimator_, outName+".joblib")
        print("Model accuracy after training:")
        print(classification_report(y, clf.best_estimator_.predict(X)))
    else: # performing cross-validation
        cv = StratifiedKFold(n_splits=nFolds)
        y_tests = []
        y_preds = []
        for train, test in cv.split(X, y):
            model = RandomForestClassifier(n_estimators=100)
            X_train, X_test = X.iloc[train, :], X.iloc[test, :]
            y_train, y_test = y[train], y[test]
            model.fit(X_train, y_train)
            y_pred = model.predict(X_test)
            y_tests.extend(y_test)
            y_preds.extend(y_pred)
        print("Model accuracy on cross-validation:")
        print(classification_report(y_tests, y_preds))

        model = RandomForestClassifier(n_estimators=100)
        model.fit(X, y)
        dump(model, outName+".joblib")
        print("Model accuracy after training:")
        print(classification_report(y, model.predict(X)))

