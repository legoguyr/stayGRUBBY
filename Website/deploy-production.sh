#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: sh Website/deploy-production.sh (no deployment overrides)" >&2
    exit 2
fi

cd "$(dirname "$0")/.."
python3 Website/build.py
python3 -m unittest discover -s Website -p 'test_*.py'
node --test Website/test_links.mjs
wrangler deploy --config Website/wrangler.jsonc --dry-run
wrangler deploy --config Website/wrangler.jsonc
if ! python3 -E Website/verify_live_links.py; then
    echo "Production deployment failed the live-link gate. Diagnose before republishing." >&2
    exit 1
fi
