#!/usr/bin/env python
# Utility for creating and visualisation of machine learning classifier in Bandage
# -*- coding: UTF-8 -*-

import sys
import getopt
import numpy as np
import pandas as pd

# for classification with cross-validation
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, AdaBoostClassifier
from sklearn.tree import DecisionTreeClassifier

# to save and load classification model
from joblib import dump, load


def buildModelRandomForest(dataFile, rawLabels, nEstimators, maxDepth):
    """Fit Random Forest classification model

    Arguments:
    - dataFile (str): path to tab-separated file with features table
    - rawLabels (pd.DataFrame): DataFrame with class labels
    - nEstimators (int): number of Decision Trees in model
    - maxDepth (int): maximal depth of Decision Tree

    Returns:
    sklearn.ensemble.RandomForestClassifier: fitted model
    """
    data = pd.read_csv(dataFile, header=0, index_col=0, sep='\t')
    if set(data.columns) != set(rawLabels.index):
        data = data.filter(items=rawLabels.index, axis=1)
        print("Samples from feature table and metadata does not match! " +
              "Will use only " + str(data.shape[1]) + " common samples")
    data = data.T
    labels = np.array([rawLabels.loc[i, 1] for i in data.index])

    if (nEstimators != 0 and maxDepth != 0):
        model = RandomForestClassifier(n_estimators=nEstimators, max_depth=maxDepth)
    elif (nEstimators != 0):
        model = RandomForestClassifier(n_estimators=nEstimators)
    elif (maxDepth != 0):
        model = RandomForestClassifier(max_depth=maxDepth)
    else:
        model = RandomForestClassifier()

    model.fit(data, labels)

    return model


def buildModelGradientBoosting(dataFile, rawLabels, nEstimators, maxDepth):
    """Fit Gradient Boosting classification model

    Arguments:
    - dataFile (str): path to tab-separated file with features table
    - rawLabels (pd.DataFrame): DataFrame with class labels
    - nEstimators (int): number of Decision Trees in model
    - maxDepth (int): maximal depth of Decision Tree

    Returns:
    sklearn.ensemble.GradientBoostingClassifier: fitted model
    """
    data = pd.read_csv(dataFile, header=0, index_col=0, sep='\t')
    if set(data.columns) != set(rawLabels.index):
        data = data.filter(items=rawLabels.index, axis=1)
        print("Samples from feature table and metadata does not match! " +
              "Will use only " + str(data.shape[1]) + " common samples")
    data = data.T
    labels = np.array([rawLabels.loc[i, 1] for i in data.index])

    if (nEstimators != 0 and maxDepth != 0):
        model = GradientBoostingClassifier(n_estimators=nEstimators, max_depth=maxDepth)
    elif (nEstimators != 0):
        model = GradientBoostingClassifier(n_estimators=nEstimators)
    elif (maxDepth != 0):
        model = GradientBoostingClassifier(max_depth=maxDepth)
    else:
        model = GradientBoostingClassifier()

    model.fit(data, labels)

    return model


def buildModelAdaBoost(dataFile, rawLabels, nEstimators, maxDepth):
    """Fit AdaBoost classification model

    Arguments:
    - dataFile (str): path to tab-separated file with features table
    - rawLabels (pd.DataFrame): DataFrame with class labels
    - nEstimators (int): number of Decision Trees in model
    - maxDepth (int): maximal depth of Decision Tree

    Returns:
    sklearn.ensemble.AdaBoostClassifier: fitted model
    """
    data = pd.read_csv(dataFile, header=0, index_col=0, sep='\t')
    if set(data.columns) != set(rawLabels.index):
        data = data.filter(items=rawLabels.index, axis=1)
        print("Samples from feature table and metadata does not match! " +
              "Will use only " + str(data.shape[1]) + " common samples")
    data = data.T
    labels = np.array([rawLabels.loc[i, 1] for i in data.index])

    if (nEstimators != 0 and maxDepth != 0):
        dTree = DecisionTreeClassifier(max_depth=maxDepth)
        model = AdaBoostClassifier(n_estimators=nEstimators, estimator=dTree)
    elif (nEstimators != 0):
        model = AdaBoostClassifier(n_estimators=nEstimators)
    elif (maxDepth != 0):
        dTree = DecisionTreeClassifier(max_depth=maxDepth)
        model = AdaBoostClassifier(estimator=dTree)
    else:
        model = AdaBoostClassifier()

    model.fit(data, labels)

    return model


def printModel(model, resFileName, sourceDir, typeOfForest=0):
    """Print fitted model to file in format supported by BandageNG

    Arguments:
    - model: fitted model
    - resFileName (str): filename to output result
    - sourceDir (str): path to directory with features' sequences
    - typeOfForest (int): 0 (RandomForest), 1 (GradientBoosting) or 2 (AdaBoost)

    Returns:
    None
    """
    f = open(resFileName, 'w')
    prefix = 0
    features = dict()
    treeClassifierList = model.estimators_
    feature_names = model.feature_names_in_
    classes = model.classes_
    if typeOfForest == 1:
        treeClassifierList = np.ravel(treeClassifierList)
    for tc in treeClassifierList:
        tree = tc.tree_
        nodeIds = [0]
        while (len(nodeIds) > 0):
            nodeId = nodeIds.pop(0)
            print("N", nodeId + prefix, sep="\t", end="\t", file=f)
            if tree.children_left[nodeId] == tree.children_right[nodeId]:
                print(file=f)
                if tree.n_outputs == 1:
                    value = tree.value[nodeId][0]
                else:
                    value = tree.value[nodeId].T[0]
                class_name = np.argmax(value)
                print("C", nodeId + prefix, classes[class_name], sep="\t", file=f)
            else:
                childLeftId = tree.children_left[nodeId]
                nodeIds.append(childLeftId)
                print(childLeftId + prefix, end="\t", file=f)

                childRightId = tree.children_right[nodeId]
                nodeIds.append(childRightId)
                print(childRightId + prefix, file=f)

                feature = feature_names[tree.feature[nodeId]]
                threshold = tree.threshold[nodeId]
                classF = feature.split("_")[0]
                print("C", nodeId + prefix, classF, sep="\t", file=f)
                print("F", nodeId + prefix, feature, "{:.2f}".format(threshold), sep="\t", file=f)
                if feature in features:
                    features[feature].append(nodeId + prefix)
                else:
                    features[feature] = [nodeId + prefix]
        prefix += tree.node_count

    for fClass in classes:
        file = open(sourceDir + "/contigs_" + fClass + "/components.seq.fasta", 'r')
        line = file.readline()
        while line:
            feature = fClass + "_" + line[1:].split("_")[0]
            seq = file.readline().strip()
            if feature in features:
                print("S", feature, seq, sep="\t", file=f)
            line = file.readline()
    f.close()


def buildAndPrintModel(sourceDir, treeNum, maxDepth, typeOfForest, resFile, model=None):
    """Wrapper to fit and print classification model

    Arguments:
    - sourceDir (str): path to directory with features' sequences
    - treeNum (int): number of Decision Trees in model
    - maxDepth (int): maximal depth of Decision Tree
    - typeOfForest (int): 0 (RandomForest), 1 (GradientBoosting) or 2 (AdaBoost)
    - resFile (str): filename to output result
    - model: pre-fitted model

    Returns:
    None
    """
    rawLabels = pd.read_csv(sourceDir + '/samples_categories.tsv', sep="\t", index_col=0, header=None)
    rawLabels.index = rawLabels.index.astype(str)

    if model is None:
        dataFile = sourceDir + '/feature_table.tsv'
        if typeOfForest == 0:
            model = buildModelRandomForest(dataFile, rawLabels, treeNum, maxDepth)
        elif typeOfForest == 1:
            model = buildModelGradientBoosting(dataFile, rawLabels, treeNum, maxDepth)
        elif typeOfForest == 2:
            model = buildModelAdaBoost(dataFile, rawLabels, treeNum, maxDepth)
        dump(model, resFile[:-4] + ".joblib")

    printModel(model, resFile, sourceDir, typeOfForest)


if __name__ == "__main__":
    sourceDir = ''
    modelFile = ''
    treeNum = 100
    maxDepth = 20
    typeOfForest = 0
    resFile = ''

    model = None
    helpString = 'Please add all mandatory parameters --source-dir --res-file and use optional parameters --model-file --tree-num --max-depth --type-of-forest'

    argv = sys.argv[1:]
    try:
        opts, args = getopt.getopt(argv, "h", ["source-dir=", "res-file=", "model-file=", "tree-num=", "max-depth=", "type-of-forest="])
    except getopt.GetoptError:
        print(helpString)
        sys.exit(2)
    for opt, arg in opts:
        if opt == "-h":
            print(helpString)
            sys.exit()
        elif opt == "--source-dir":
            sourceDir = arg
            if sourceDir[0] == "'" or sourceDir[0] == '"':
                sourceDir = sourceDir[1:]
            if sourceDir[-1] == "'" or sourceDir[-1] == '"':
                sourceDir = sourceDir[:-1]
        elif opt == "--res-file":
            resFile = arg
            if resFile[0] == "'" or resFile[0] == '"':
                resFile = resFile[1:]
            if resFile[-1] == "'" or resFile[-1] == '"':
                resFile = resFile[:-1]
        elif opt == "--model-file":
            modelFile = arg
            if modelFile[0] == "'" or modelFile[0] == '"':
                modelFile = modelFile[1:]
            if modelFile[-1] == "'" or modelFile[-1] == '"':
                modelFile = modelFile[:-1]
        elif opt == "--tree-num":
            treeNum = int(arg)
        elif opt == "--max-depth":
            maxDepth = int(arg)
        elif opt == "--type-of-forest":
            typeOfForest = int(arg)
            if typeOfForest < 0 or typeOfForest > 2:
                print("Please use typeOfForest 0 (RandomForest), 1 (GradientBoosting) or 2 (AdaBoost)")
                sys.exit(2)

    print('Source dir:', sourceDir)
    print('Result file:', resFile)
    if (modelFile == ''):
        print('Type of forest:', typeOfForest)
        print('Number of trees:', treeNum)
        print('Maximum depth of the tree:', maxDepth)
    else:
        print('Model file:', modelFile)

    if (modelFile != ''):
        model = load(modelFile)
        if model.__class__.__name__ == 'RandomForestClassifier':
            typeOfForest = 0
        elif model.__class__.__name__ == 'GradientBoostingClassifier':
            typeOfForest = 1
        elif model.__class__.__name__ == 'AdaBoostClassifier':
            typeOfForest = 2
        else:
            print("Class of model", model.__class__.__name__, "is incorrect. Supported classes: RandomForestClassifier, GradientBoostingClassifier, AdaBoostClassifier")
            sys.exit(2)
    buildAndPrintModel(sourceDir, treeNum, maxDepth, typeOfForest, resFile, model)
