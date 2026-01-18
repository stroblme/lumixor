#!/bin/bash
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

rm build -rf
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX="$HOME/.local" ..
make -j$(nproc)

# Install system-wide if --install flag is provided
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
    echo "Use --install to install system-wide, or --run to execute the application."
fi