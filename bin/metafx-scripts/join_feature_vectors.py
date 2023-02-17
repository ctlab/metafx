#!/usr/bin/env python
# Utility for combining feature vectors into one table
import sys
import os
import re
import pandas as pd

def load_cat(cat):
    df_list = [pd.read_csv(wd + "/features_" + cat + "/vectors/" + file + ".breadth", header=None, index_col=None) for file in all_files]
    data = pd.concat(df_list, axis=1)
    data.columns = all_files
    data.index = [cat + "_" + str(i) for i in data.index]
    print("Found " + str(data.shape[0]) + " features for category " + cat)
    return data


wd = sys.argv[1]
cat_samples = pd.read_csv(wd+"/categories_samples.tsv", sep="\t", header=None, index_col=None)
categories = cat_samples.iloc[:, 0]
all_files = cat_samples.iloc[0, 1].split() + cat_samples.iloc[0, 2].split()


subtables = []
for cat in categories:
    subtables.append(load_cat(cat))

feature_table = pd.concat(subtables, axis=0)
feature_table.to_csv(wd+"/feature_table.tsv", sep="\t")
print("Total " + str(feature_table.shape[0]) + " features found!")
