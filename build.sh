set -e

rm build -rf
mkdir build
cd build
cmake ..
make -j$(nproc)
./lumixor-qt