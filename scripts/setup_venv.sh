#!/usr/bin/env bash
set -e

# Name the venv `.venv` in repo root
VENV=".venv"

echo "▶ Creating virtual environment [$VENV] ..."
python3 -m venv "$VENV"

echo "▶ Activating venv and installing requirements ..."
source "$VENV/bin/activate"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo "✔ Done!  Activate later with:  source $VENV/bin/activate"
