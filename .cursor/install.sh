#!/usr/bin/env bash
#
# Idempotent development environment bootstrap for plotly.py.
#
# This legacy release of plotly.py targets Python 2.7-3.7 and pins old
# scientific-python dependencies, so the development environment is built on a
# dedicated Python 3.7 Miniconda environment (matching the newest interpreter
# this codebase officially supports). The script installs Miniconda if needed,
# creates the "plotly-dev" conda environment, and performs editable installs of
# the three Python packages in this repository.
#
# It is safe to run repeatedly: existing Miniconda installs and conda
# environments are detected and reused.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

MINICONDA_DIR="$HOME/miniconda"
ENV_NAME="plotly-dev"
CONDA_BIN="$MINICONDA_DIR/bin/conda"
ENV_PYTHON="$MINICONDA_DIR/envs/$ENV_NAME/bin/python"
ENV_PIP="$MINICONDA_DIR/envs/$ENV_NAME/bin/pip"

# 1. Install Miniconda if it is not already present.
if [ ! -x "$CONDA_BIN" ]; then
  echo "==> Installing Miniconda into $MINICONDA_DIR"
  tmp_dir="$(mktemp -d)"
  curl -fsSL \
    "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" \
    -o "$tmp_dir/miniconda.sh"
  bash "$tmp_dir/miniconda.sh" -b -p "$MINICONDA_DIR"
  rm -rf "$tmp_dir"
else
  echo "==> Reusing existing Miniconda at $MINICONDA_DIR"
fi

# Use conda-forge exclusively. This both provides the older package builds this
# release needs and avoids the interactive Terms-of-Service prompt on the
# Anaconda default channels.
"$CONDA_BIN" config --set channel_priority strict

# 2. Create the plotly-dev environment if it does not exist.
#
# numpy/pandas are pinned to era-appropriate versions so the test-suite behaves
# as it did when this release was current (newer numpy raises when assigning NaN
# into integer arrays, which breaks px.imshow tests). webcolors is pinned to the
# last release that still supports Python 3.7 (newer releases use 3.8+ syntax and
# break the optional nbformat import path).
if ! "$CONDA_BIN" env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  echo "==> Creating conda environment '$ENV_NAME' (Python 3.7)"
  "$CONDA_BIN" create -n "$ENV_NAME" --yes --override-channels -c conda-forge \
    python=3.7 \
    numpy=1.16 \
    pandas=0.25 \
    webcolors=1.11.1 \
    scipy \
    xarray \
    requests \
    nbformat \
    six \
    retrying \
    psutil \
    decorator \
    pytest \
    mock \
    nose \
    ipython \
    jupyter \
    ipykernel \
    ipywidgets \
    pillow \
    pytz
else
  echo "==> Reusing existing conda environment '$ENV_NAME'"
fi

# 3. Editable installs of the repository's Python packages (idempotent).
#    Invoke the environment's pip by absolute path so this is independent of the
#    caller's PATH / active conda environment.
echo "==> Installing plotly, chart-studio and plotly-geo (editable)"
"$ENV_PIP" install --no-build-isolation \
  -e packages/python/plotly/ \
  -e packages/python/chart-studio/ \
  -e packages/python/plotly-geo/

# 4. Make conda + the plotly-dev environment available in interactive shells so
#    future sessions land directly in the development environment.
if ! grep -q "plotly-dev conda setup" "$HOME/.bashrc" 2>/dev/null; then
  {
    echo ""
    echo "# >>> plotly-dev conda setup >>>"
    echo "source \"$MINICONDA_DIR/etc/profile.d/conda.sh\""
    echo "conda activate $ENV_NAME"
    echo "# <<< plotly-dev conda setup <<<"
  } >> "$HOME/.bashrc"
fi

echo "==> plotly-dev environment ready ($("$ENV_PYTHON" --version 2>&1))."
echo "    Activate with: source \"$MINICONDA_DIR/etc/profile.d/conda.sh\" && conda activate $ENV_NAME"
