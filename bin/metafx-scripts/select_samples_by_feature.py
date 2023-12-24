#!/usr/bin/env python
# Utility select samples from feature_table.tsv with feature score greater than board value (default 0.1)
# -*- coding: UTF-8 -*-

import sys
import getopt
import pandas as pd

if __name__ == "__main__":
    inputFile = ''
    outputFile = ''
    feature = ''
    category = ''
    featureId = ''
    board = 0.1

    helpString = 'Please add all mandatory parameters --work-dir, --feature, --res-dir and use optional float parameter --board'

    argv = sys.argv[1:]
    try:
        opts, args = getopt.getopt(argv, "h", ["work-dir=", "feature=", "res-dir=", "board="])
    except getopt.GetoptError:
        print(helpString)
        sys.exit(2)
    for opt, arg in opts:
        if opt == "-h":
            print(helpString)
            sys.exit()
        elif opt == "--work-dir":
            workDir = arg
            if workDir[0] == "'" or workDir[0] == '"':
                workDir = workDir[1:]
            if workDir[-1] == "'" or workDir[-1] == '"':
                workDir = workDir[:-1]
        elif opt == "--feature":
            feature = arg
            if feature[0] == "'" or feature[0] == '"':
                feature = feature[1:]
            if feature[-1] == "'" or feature[-1] == '"':
                feature = feature[:-1]
            category = feature.split("_")[0]
            featureId = feature.split("_")[1]
        elif opt == "--res-dir":
            resDir = arg
            if resDir[0] == "'" or resDir[0] == '"':
                resDir = resDir[1:]
            if resDir[-1] == "'" or resDir[-1] == '"':
                resDir = resDir[:-1]
        elif opt == "--board":
            board = float(arg)

    data = pd.read_csv(workDir + '/feature_table.tsv', header=0, index_col=0, sep = '\t')
    data = data.T
    filteredData = data[feature][data[feature] > board].keys().tolist()
    samplesList = open(resDir + '/samples_list_feature_' + feature + '.txt', 'w')
    print(*filteredData, sep = "\n", file=samplesList)
    samplesList.close()

    resSeqFile = open(resDir + '/seq_feature_' + feature + '.fasta', 'w')
    featuresFasta = open(workDir + '/contigs_' + category + '/components.seq.fasta', 'r')

    while True:
        line = featuresFasta.readline()
        if not line:
            break
        if len(line)==0:
            continue
        if line[0] == '>':
            line = line.strip()[1:]
            seqName = line.split('_')[0]
            if seqName == featureId:
                seq = featuresFasta.readline().strip()
                print(">"+line, file=resSeqFile)
                print(seq, file=resSeqFile)
    resSeqFile.close()
    featuresFasta.close()
