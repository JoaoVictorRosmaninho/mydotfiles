#!/bin/bash

set -e

grim -g \"$(slurp)\" - | swappy -f -
