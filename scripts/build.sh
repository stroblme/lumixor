#!/usr/bin/env bash
set -e

# Parse command line arguments
INSTALL=false
RUN=false
for arg in "$@"; do
    case $arg in
        --install)
            INSTALL=true
            shift
            ;;
        --run)
            RUN=true
            shift
            ;;
        *)
            ;;
    esac
done

# Determine number of cores (Linux vs macOS)
UNAME_OUT="$(uname -s || echo unknown)"
if [[ "$UNAME_OUT" == "Darwin" ]]; then
    NPROC="$(sysctl -n hw.ncpu)"
else
    if command -v nproc >/dev/null 2>&1; then
        NPROC="$(nproc)"
    else
        NPROC=4
    fi
fi

# Optional: auto-set CMAKE_PREFIX_PATH for Homebrew Qt on macOS
CMAKE_ARGS=()
if [[ "$UNAME_OUT" == "Darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
        QT_PREFIX="$(brew --prefix qt 2>/dev/null || echo "")"
        if [[ -n "$QT_PREFIX" ]]; then
            CMAKE_ARGS+=("-DCMAKE_PREFIX_PATH=$QT_PREFIX")
        fi
    fi
fi

rm -rf build
mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX="$HOME/.local" "${CMAKE_ARGS[@]}" ..
make -j"$NPROC"

# Install to user directory if --install flag is provided
if [ "$INSTALL" = true ]; then
    echo "Installing application to user directory (~/.local)..."
    make install
    echo "Installation completed successfully!"
    echo "Make sure ~/.local/bin is in your PATH to run 'lumixor-qt' from anywhere."
fi

# Run the application if --run flag is provided
if [ "$RUN" = true ]; then
    echo "Running application..."
    ./lumixor-qt
fi

# Provide usage information if neither flag was used
if [ "$INSTALL" = false ] && [ "$RUN" = false ]; then
    echo "Build completed successfully."
    echo "Use --install to install to ~/.local, or --run to execute the application."
fi