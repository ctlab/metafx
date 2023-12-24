#!/usr/bin/env python
# Utility for extracting contigs from GFA to FASTA
import sys


if __name__ == "__main__":
    wd = sys.argv[1]
    file = open(wd + "/components.seq.fasta", "w")
    comp = -1
    comp_i = 0
    for line in open(wd + "/components-graph.gfa"):
        if line.split()[0] == 'S':
            _, name, seq, *_ = line.strip().split(sep="\t")
            raw_name = name
            name = int(name.split("_")[1][1:])
            if name != comp:
                comp += 1
                comp_i = 0
            comp_i += 1
            print(">" + str(comp) + "_" + str(comp_i) + "\t" + raw_name, file=file)
            print(seq, file=file)
    file.close()
