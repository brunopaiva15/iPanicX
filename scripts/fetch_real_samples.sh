#!/bin/bash
# Downloads the public panic reports listed in scripts/real_samples_urls.txt
# into test/fixtures/real_full/ (git-ignored), for:
#   flutter test test/diagnostics/real_corpus_test.dart
#   dart run tool/analyze_corpus.dart test/fixtures/real_full
# You can also drop your own .ips / .txt / .log reports into that folder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/test/fixtures/real_full"
mkdir -p "${OUT}"

while read -r url; do
  [ -z "${url}" ] && continue
  name="$(basename "${url}" | sed 's/%2B/+/g')"
  # -f: on an HTTP error curl exits non-zero and writes no file.
  if curl -fsSL -o "${OUT}/${name}" "${url}"; then
    echo "ok   ${name}"
  else
    echo "FAIL ${url}"
  fi
done < "${ROOT}/scripts/real_samples_urls.txt"

echo "Saved to ${OUT}"
