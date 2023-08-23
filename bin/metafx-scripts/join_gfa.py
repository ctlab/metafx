#!/usr/bin/env python
# Joining several GFA files into one
import sys


if __name__ == "__main__":
    wd = sys.argv[1]
    file = open(wd+"/all-components-graph.gfa", "w")
    cat = 0
    m = dict()
    for fin in sys.argv[2:]:
        cat += 1
        for line in open(fin):
            if line.split()[0] == 'S':
                a, b, c, d, e = line.strip().split(sep="\t")
                m[b] = str(cat) + "_" + b
                b = str(cat) + "_" + b
                print(a, b, c, d, e, sep="\t", file=file)
            if line.split()[0] == 'L':
                a, b, c, d, e, f = line.strip().split(sep="\t")
                print(a, m[b], c, m[d], e, f, sep="\t", file=file)
    file.close()