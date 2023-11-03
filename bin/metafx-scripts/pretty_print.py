#!/usr/bin/env python
# Utility for printing comments
import sys


if __name__ == "__main__":
    comment = sys.argv[1]
    delimeter = sys.argv[2]

    total_len = 120
    max_len = total_len - 20
    print("\n" + delimeter * total_len)

    words = comment.split(" ")
    line = ""
    for word in words:
        if len(line) + 1 + len(word) > max_len:
            left_space = (total_len - len(line) - 10) // 2
            right_space = total_len - left_space - len(line) - 10
            print(delimeter * 5 + " " * left_space + line + " " * right_space + delimeter * 5)
            line = word
        else:
            line = line + " " + word
    left_space = (total_len - len(line) - 10) // 2
    right_space = total_len - left_space - len(line) - 10
    print(delimeter * 5 + " " * left_space + line + " " * right_space + delimeter * 5)

    print(delimeter * total_len + "\n")
