#!/bin/sh

# Godot Response System files
cat examples/basic/grs/sources/base.grs.yaml | yq -o=json > examples/basic/grs/base.grs-json
