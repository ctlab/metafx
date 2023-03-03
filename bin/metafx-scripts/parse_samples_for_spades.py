#!/usr/bin/env python
# Utility for obtaining basename and corresponding samples for list of input files
import sys
import os
import re


def get_basename(s):
    s = os.path.basename(s)
    f = True
    if any(x in s for x in ["fq", "fastq", "FQ", "FASTQ"]):
        f = False
    s = re.sub('(_1|_2|_r1|_r2|_R1|_R2|)\.(fa|fasta|fq|fastq|FA|FASTA|FQ|FASTQ)(\.gz|)$', '', s)
    return f, s


if __name__ == "__main__":
    files = sys.argv[1:]
    names_files = dict()

    for file in files:
        f, base = get_basename(file)
        if base not in names_files:
            names_files[base] = (f, [])
        names_files[base][1].append(file)

    for key, (f, vals) in names_files.items():
        if len(vals) != 2:
            raise RuntimeError("Unexpected number of files for sample " + key + " obtained: " + str(len(vals)) + ". Provide two files with paired-end reads for each sample.")
        print(f, key, " ".join(vals))
