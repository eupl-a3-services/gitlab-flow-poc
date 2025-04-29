#!/bin/bash
ncc build jira-report.js -o dist
terser dist/index.js --compress --mangle --output dist/index.min.js

echo node index.js > dist/index.sh