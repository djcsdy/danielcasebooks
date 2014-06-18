#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

ebooks archive danielcassidy corpus/danielcassidy.json

ebooks consume corpus/danielcassidy.json
