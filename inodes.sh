#!/usr/bin/env bash

echo "Detailed Inodes usage for: $(pwd)"

for d in $(find . -maxdepth 1 -type d | cut -d/ -f2 | grep -xv . | sort); do
  c=$(find "$d" | wc -l)
  printf "%s\t\t- %s\n" "$c" "$d"
done | sort -rn

printf "Total: \t\t$(find $(pwd) | wc -l)\n"