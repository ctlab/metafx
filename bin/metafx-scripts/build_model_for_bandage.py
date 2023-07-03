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

# dump and load classification model
from joblib import dump, load


def buildModelRandomForest(dataFile, rawLabels, nEstimators, maxDepth):
    data = pd.read_csv(dataFile, header=0, index_col=0, sep='\t')
    if set(data.columns) != set(rawLabels.index):
        data = data.filter(items=rawLabels.index, axis=1)
        print("Samples from feature table and metadata does not match! Will use only " + str(data.shape[1]) + " common samples")
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
    data = pd.read_csv(dataFile, header=0, index_col=0, sep='\t')
    if set(data.columns) != set(rawLabels.index):
        data = data.filter(items=rawLabels.index, axis=1)
        print("Samples from feature table and metadata does not match! Will use only " + str(data.shape[1]) + " common samples")
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
    data = pd.read_csv(dataFile, header=0, index_col=0, sep='\t')
    if set(data.columns) != set(rawLabels.index):
        data = data.filter(items=rawLabels.index, axis=1)
        print("Samples from feature table and metadata does not match! Will use only " + str(data.shape[1]) + " common samples")
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


def printModelBase(model, resFileName, sourceDir):
    f = open(resFileName, 'w')
    prefix = 0
    features = dict()
    treeClassifierList = model.estimators_
    feature_names = model.feature_names_in_
    classes = model.classes_
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
                continue
            childLeftId = tree.children_left[nodeId]
            nodeIds.append(childLeftId)
            print(childLeftId + prefix, sep="\t", end="\t", file=f)

            childRightId = tree.children_right[nodeId]
            nodeIds.append(childRightId)
            print(childRightId + prefix,  sep="\t", end="\t", file=f)
            print(file=f)
            feature = feature_names[tree.feature[nodeId]]
            threshold = tree.threshold[nodeId]
            classF = feature.split("_")[0]
            print("C", nodeId + prefix, classF, sep="\t", file=f)
            print("F", nodeId + prefix, feature, "{:.2f}".format(threshold), sep="\t", end="\n", file=f)
            if feature in features:
                features[feature].append(nodeId + prefix)
            else:
                features[feature] = [nodeId + prefix]
        prefix += tree.node_count

    for fClass in classes:
        file = open(sourceDir + "/contigs_" + fClass + "/kmers_fasta/component.fasta", 'r')
        line = file.readline()
        while line:
            feature = fClass + "_" + line[1:].split("_")[0]
            k_mer = file.readline()[:-1]
            if feature in features:
                print("S", feature, k_mer, sep="\t", file=f)
            line = file.readline()
    f.close()


def printModelGradientBoosting(model, resFileName, sourceDir):
    f = open(resFileName, 'w')
    prefix = 0
    features = dict()
    treeClassifierList = model.estimators_
    feature_names = model.feature_names_in_
    classes = model.classes_
    for i in treeClassifierList:
        for tc in i:
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
                    continue
                childLeftId = tree.children_left[nodeId]
                nodeIds.append(childLeftId)
                print(childLeftId + prefix, sep="\t", end="\t", file=f)

                childRightId = tree.children_right[nodeId]
                nodeIds.append(childRightId)
                print(childRightId + prefix,  sep="\t", end="\t", file=f)
                print(file=f)
                feature = feature_names[tree.feature[nodeId]]
                threshold = tree.threshold[nodeId]
                classF = feature.split("_")[0]
                print("C", nodeId + prefix, classF, sep="\t", file=f)
                print("F", nodeId + prefix, feature, "{:.2f}".format(threshold), sep="\t", end="\n", file=f)
                if feature in features:
                    features[feature].append(nodeId + prefix)
                else:
                    features[feature] = [nodeId + prefix]
            prefix += tree.node_count

    for fClass in classes:
        file = open(sourceDir + "/contigs_" + fClass + "/kmers_fasta/component.fasta", 'r')
        line = file.readline()
        while line:
            feature = fClass + "_" + line[1:].split("_")[0]
            k_mer = file.readline()[:-1]
            if feature in features:
                print("S", feature, k_mer, sep="\t", file=f)
            line = file.readline()
    f.close()


def buildAndPrintModel(sourceDir, treeNum, maxDepth, typeOfForest, resFile, model=None):
    rawLabels = pd.read_csv(sourceDir + '/samples_categories.tsv', sep="\t", index_col=0, header=None)
    rawLabels.index = rawLabels.index.astype(str)

    if typeOfForest == 0:
        if model is None:
            model = buildModelRandomForest(sourceDir + '/feature_table.tsv', rawLabels, treeNum, maxDepth)
            dump(model, resFile[:-4]+".joblib")
        printModelBase(model, resFile, sourceDir)
    elif typeOfForest == 1:
        if model is None:
            model = buildModelGradientBoosting(sourceDir + '/feature_table.tsv', rawLabels, treeNum, maxDepth)
            dump(model, resFile[:-4]+".joblib")
        printModelGradientBoosting(model, resFile, sourceDir)
    else:
        if model is None:
            model = buildModelAdaBoost(sourceDir + '/feature_table.tsv', rawLabels, treeNum, maxDepth)
            dump(model, resFile[:-4]+".joblib")
        printModelBase(model, resFile, sourceDir)


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
