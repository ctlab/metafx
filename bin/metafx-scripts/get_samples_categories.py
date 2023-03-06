#!/usr/bin/env python
# Utility for obtaining samples' basenames and their categories
import sys
import pandas as pd


if __name__ == "__main__":
    wd = sys.argv[1]
    cat_samples = pd.read_csv(wd + "/categories_samples.tsv", sep="\t", header=None, index_col=None)
    cat_samples = cat_samples.fillna('')

    out = open(wd + "/samples_categories.tsv", 'w')
    for _, (cat, samples, _) in cat_samples.iterrows():
        for sample in samples.split():
            print(sample, cat, sep="\t", file=out)
    out.close()
