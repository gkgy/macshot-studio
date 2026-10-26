#!/bin/bash
# Installs the Python runtime only. The model download is an explicit separate step.
set -euo pipefail
studio_python="${STUDIO_PYTHON:-python3}"
studio_venv="${STUDIO_WHISPER_VENV:-$HOME/.local/share/macshot-studio/whisper-venv}"
"$studio_python" -m venv "$studio_venv"
"$studio_venv/bin/python" -m pip install 'faster-whisper==1.2.1'
printf '\nWhisper Python: %s/bin/python\n' "$studio_venv"
printf 'Set this path in Macshot Studio → Studio settings. Configure a local model folder too.\n'
