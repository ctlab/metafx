#!/usr/bin/env python
# Utility transform Kraken class report to csv file for Bandage visualization
# -*- coding: UTF-8 -*-

import sys
import getopt
from ete3 import NCBITaxa

if __name__ == "__main__":
    inputFile = ''
    resFile = ''

    helpString = 'Please add all mandatory parameters: --class-file and --res-file'

    argv = sys.argv[1:]
    try:
        opts, args = getopt.getopt(argv, "h", ["class-file=", "res-file="])
    except getopt.GetoptError:
        print(helpString)
        sys.exit(2)
    for opt, arg in opts:
        if opt == "-h":
            print(helpString)
            sys.exit()
        elif opt == "--class-file":
            inputFile = arg
            if inputFile[0] == "'" or inputFile[0] == '"':
                inputFile = inputFile[1:]
            if inputFile[-1] == "'" or inputFile[-1] == '"':
                inputFile = inputFile[:-1]
        elif opt == "--res-file":
            resFile = arg
            if resFile[0] == "'" or resFile[0] == '"':
                resFile = resFile[1:]
            if resFile[-1] == "'" or resFile[-1] == '"':
                resFile = resFile[:-1]

    tax_ids = []
    fileR = open(inputFile, 'r')
    fileW = open(resFile, 'w')
    count = 0
    while True:
        line = fileR.readline()
        if not line:
            break
        count += 1
        listLine = line.split('\t')
        if (listLine[0] == 'C'):
            tax_id = listLine[2].split('taxid')[1][1:-1]
            #tax_ids.append((listLine[1], tax_id))
            tax_ids.append((listLine[1].split("\t")[1], tax_id))
    fileR.close()

    ncbi = NCBITaxa()
    fileW.write("Node name,Superkingdom,Phylum,Class,Order,Family,Genus,Species,Serotype,Strains\n")
    ranks = {'superkingdom': 1, 'phylum': 2, 'class': 3, 'order': 4, 'family': 5, 'genus': 6, 'species': 7, 'serotype': 8, 'strain': 9}
    for (node, tax) in tax_ids:
        lineage = ncbi.get_lineage(tax)
        names = ncbi.get_taxid_translator(lineage)
        fileW.write(node + ",")
        prevCount = 0
        for taxid in lineage:
            rank = ncbi.get_rank([taxid])[taxid]
            if (rank in ranks):
                curCount = ranks[ncbi.get_rank([taxid])[taxid]]
                for i in range(curCount - prevCount - 1):
                    fileW.write(",")
                fileW.write(names[taxid]+",")
                prevCount = curCount
        fileW.write("\n")
    fileW.close()
