#!/usr/bin/env python
# Utility for obtaining categories and corresponding samples' basenames
import sys
import os
import re
import pandas as pd


def get_basename(s):
    s = os.path.basename(s)
    s = re.sub('(_r1|_r2|_R1|_R2|)\.(fa|fasta|fq|fastq|FA|FASTA|FQ|FASTQ)(\.gz|\.bz2|)$', '', s)
    return s


if __name__ == "__main__":
    f = sys.argv[1]
    data = pd.read_csv(f, sep="\t", header=None, index_col=None)
    cat_dict = dict()
    all_items = set()
    for _, row in data.iterrows():
        name, cat = row
        if cat not in cat_dict:
            cat_dict[cat] = set()
        cat_dict[cat].add(get_basename(name))
        all_items.add(get_basename(name))

    for k, v in cat_dict.items():
        print(k, end="\t")
        print(" ".join(sorted(v)), end="\t")
        print(" ".join(sorted(all_items-v)))
