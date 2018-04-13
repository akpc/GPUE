cmake_minimum_required(VERSION 2.8)
project(gpue_build LANGUAGES CXX CUDA)
find_package(CUDA QUIET REQUIRED)

set(
    CUDA_NVCC_FLAGS
    ${CUDA_NVCC_FLAGS};
    -O3 -gencode arch=compute_37,code=sm_37 -lcufft -fopenmp
)

add_executable(
    gpue
    src/dynamic.cu
    include/dynamic.h

    src/ds.cu
    include/ds.h

    src/edge.cu
    include/edge.h

    src/evolution.cu
    include/evolution.h

    src/fileIO.cu
    include/fileIO.h

    src/kernels.cu
    include/kernels.h

    src/manip.cu
    include/manip.h

    src/lattice.cu
    include/lattice.h

    src/minions.cu
    include/minions.h

    src/multigpu.cu

    src/node.cu
    include/node.h

    src/operators.cu
    include/operators.h

    src/parser.cu
    include/parser.h

    src/split_op.cu
    include/split_op.h

    src/tracker.cu
    include/tracker.h

    src/unit_test.cu
    include/unit_test.h

    src/vort.cu
    include/vort.h

    src/vortex_3d.cu
    include/vortex_3d.h

    src/init.cu
    include/init.h
)

target_compile_features(gpue PUBLIC cxx_std_11)
target_link_libraries(gpue ${CUDA_LIBRARIES} ${CUDA_CUFFT_LIBRARIES})
set_target_properties(gpue PROPERTIES CUDA_SEPARABLE_COMPILATION ON)