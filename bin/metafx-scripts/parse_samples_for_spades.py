#!/usr/bin/env python
# Utility for obtaining basename and corresponding samples for list of input files
import sys
import os
import re


def is_fastq(s):
    """ Check whether the file is FASTQ format

    Arguments:
    s (str): full file path

    Returns:
    bool: True for file in FASTQ format
    """
    s = os.path.basename(s)
    f = True
    if any(x in s for x in ["fq", "fastq", "FQ", "FASTQ"]):
        f = False
    return f


def get_basename(s):
    """ Get file name without path and extension

    Arguments:
    s (str): full file path

    Returns:
    str: file basename without extension
    """
    s = os.path.basename(s)
    s = re.sub(r'(_r1|_r2|_R1|_R2|)\.(fa|fasta|fq|fastq|FA|FASTA|FQ|FASTQ)(\.gz|)$', '', s)
    return s


if __name__ == "__main__":
    files = sys.argv[1:]
    names_files = dict()

    for file in files:
        f = is_fastq(file)
        base = get_basename(file)
        if base not in names_files:
            names_files[base] = (f, [])
        names_files[base][1].append(file)

    for key, (f, vals) in names_files.items():
        if len(vals) != 2:
            raise RuntimeError("Unexpected number of files for sample " + key + " obtained: " + str(len(vals)) + ". Provide two files with paired-end reads for each sample.")
        print(f, key, " ".join(vals))
