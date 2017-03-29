/*-------------vortex_3d.cu---------------------------------------------------//
*
* Purpose: This file intends to perform a convolution of 3d data for vortex
*          recognition in the GPUE code
*
*   Notes: We will be using the window method for convolutions because it has
*          a slightly better complxity case for a separable filter
*          (which the Sobel filter definitely is!)
*
*-----------------------------------------------------------------------------*/

#include <algorithm>
#include "../include/ds.h"
#include "../include/vortex_3d.h"
#include "../include/kernels.h"

//We will need a few functions to deal with vortex skeletons
pos **find_skeletons(double* edges);

// Function to find the sobel operators and transfer to GPU
void find_sobel(Grid &par){

    std::string conv_type = par.sval("conv_type");
    int xDim, yDim, zDim;

    // There will be two cases to take into account here, one for fft 
    // convolution and another for window

    int index = 0;

    if (conv_type == "FFT"){
        double2 *sobel_x, *sobel_y, *sobel_z;
        xDim = par.ival("xDim");
        yDim = par.ival("yDim");
        zDim = par.ival("zDim");

        sobel_x = (double2 *) malloc(sizeof(double2) *xDim*yDim*zDim);
        sobel_y = (double2 *) malloc(sizeof(double2) *xDim*yDim*zDim);
        sobel_z = (double2 *) malloc(sizeof(double2) *xDim*yDim*zDim);

        // Now let's go ahead and pad these guys with 0's
        for (int i = 0; i < xDim; ++i){
            for (int j = 0; j < yDim; ++j){
                for (int k = 0; k < zDim; ++k){
                    index = k + j * xDim + i * yDim * zDim;
                    sobel_x[index].x = 0;
                    sobel_y[index].x = 0;
                    sobel_z[index].x = 0;
                }
            }
        }

        // There is clearly a better way to do this with matrix multiplication
        // the sobel operator is separable, so we just need to mix
        // Gradient and triangle filters, check:
        //     https://en.wikipedia.org/wiki/Sobel_operator
    
        // Starting with S_z
        int factor;
        for (int i = 0; i < 3; ++i){
            for (int j = 0; j < 3; ++j){
                for (int k = 0; k < 3; ++k){
                    index = k + zDim*j + zDim*yDim*i;
                    if (k == 0){
                        factor = -1;
                    }
                    if (k == 1){
                        factor = 0;
                    }
                    if (k == 2){
                        factor = 1;
                    }
                    if (i == 0 && j == 0){
                        sobel_z[index].x = factor * 1;
                    }
                    if (i == 0 && j == 1){
                        sobel_z[index].x = factor * 2;
                    }
                    if (i == 0 && j == 2){
                        sobel_z[index].x = factor * 1;
                    }
                    if (i == 1 && j == 0){
                        sobel_z[index].x = factor * 2;
                    }
                    if (i == 1 && j == 1){
                        sobel_z[index].x = factor * 4;
                    }
                    if (i == 1 && j == 2){
                        sobel_z[index].x = factor * 2;
                    }
                    if (i == 2 && j == 0){
                        sobel_z[index].x = factor * 1;
                    }
                    if (i == 2 && j == 1){
                        sobel_z[index].x = factor * 2;
                    }
                    if (i == 2 && j == 2){
                        sobel_z[index].x = factor * 1;
                    }
                }
            }
        }
    
        // S_y
        for (int i = 0; i < 3; ++i){
            for (int j = 0; j < 3; ++j){
                for (int k = 0; k < 3; ++k){
                    index = k + zDim*j + zDim*yDim*i;
                    if (j == 0){
                        factor = -1;
                    }
                    if (j == 1){
                        factor = 0;
                    }
                    if (j == 2){
                        factor = 1;
                    }
                    if (i == 0 && k == 0){
                        sobel_y[index].x = factor * 1;
                    }
                    if (i == 0 && k == 1){
                        sobel_y[index].x = factor * 2;
                    }
                    if (i == 0 && k == 2){
                        sobel_y[index].x = factor * 1;
                    }
                    if (i == 1 && k == 0){
                        sobel_y[index].x = factor * 2;
                    }
                    if (i == 1 && k == 1){
                        sobel_y[index].x = factor * 4;
                    }
                    if (i == 1 && k == 2){
                        sobel_y[index].x = factor * 2;
                    }
                    if (i == 2 && k == 0){
                        sobel_y[index].x = factor * 1;
                    }
                    if (i == 2 && k == 1){
                        sobel_y[index].x = factor * 2;
                    }
                    if (i == 2 && k == 2){
                        sobel_y[index].x = factor * 1;
                    }
                }
            }
        }
    
        // Now for S_x
        for (int i = 0; i < 3; ++i){
            for (int j = 0; j < 3; ++j){
                for (int k = 0; k < 3; ++k){
                    index = k + zDim*j + zDim*yDim*i;
                    if (i == 0){
                        factor = -1;
                    }
                    if (i == 1){
                        factor = 0;
                    }
                    if (i == 2){
                        factor = 1;
                    }
                    if (k == 0 && j == 0){
                        sobel_x[index].x = factor * 1;
                    }
                    if (k == 0 && j == 1){
                        sobel_x[index].x = factor * 2;
                    }
                    if (k == 0 && j == 2){
                        sobel_x[index].x = factor * 1;
                    }
                    if (k == 1 && j == 0){
                        sobel_x[index].x = factor * 2;
                    }
                    if (k == 1 && j == 1){
                        sobel_x[index].x = factor * 4;
                    }
                    if (k == 1 && j == 2){
                        sobel_x[index].x = factor * 2;
                    }
                    if (k == 2 && j == 0){
                        sobel_x[index].x = factor * 1;
                    }
                    if (k == 2 && j == 1){
                        sobel_x[index].x = factor * 2;
                    }
                    if (k == 2 && j == 2){
                        sobel_x[index].x = factor * 1;
                    }
                }
            }
        }


        par.store("sobel_x", sobel_x);
        par.store("sobel_y", sobel_y);
        par.store("sobel_z", sobel_z);

    }
    else{
        double *sobel_x, *sobel_y, *sobel_z;
        xDim = 9;
        yDim = 9;
        zDim = 9;

        sobel_x = (double *) malloc(sizeof(double) *9);
        sobel_y = (double *) malloc(sizeof(double) *9);
        sobel_z = (double *) malloc(sizeof(double) *9);

        // There is clearly a better way to do this with matrix multiplication
        // the sobel operator is separable, so we just need to mix 
        // Gradient and triangle filters, check:
        //     https://en.wikipedia.org/wiki/Sobel_operator
    
        // Starting with S_z
        int factor;
        for (int i = 0; i < 3; ++i){
            for (int j = 0; j < 3; ++j){
                for (int k = 0; k < 3; ++k){
                    index = k + 3*j + 9*i;
                    if (k == 0){
                        factor = -1;
                    }
                    if (k == 1){
                        factor = 0;
                    }
                    if (k == 2){
                        factor = 1;
                    }
                    if (i == 0 && j == 0){
                        sobel_z[index] = factor * 1;
                    }
                    if (i == 0 && j == 1){
                        sobel_z[index] = factor * 2;
                    }
                    if (i == 0 && j == 2){
                        sobel_z[index] = factor * 1;
                    }
                    if (i == 1 && j == 0){
                        sobel_z[index] = factor * 2;
                    }
                    if (i == 1 && j == 1){
                        sobel_z[index] = factor * 4;
                    }
                    if (i == 1 && j == 2){
                        sobel_z[index] = factor * 2;
                    }
                    if (i == 2 && j == 0){
                        sobel_z[index] = factor * 1;
                    }
                    if (i == 2 && j == 1){
                        sobel_z[index] = factor * 2;
                    }
                    if (i == 2 && j == 2){
                        sobel_z[index] = factor * 1;
                    }
                }
            }
        }
    
        // S_y
        for (int i = 0; i < 3; ++i){
            for (int j = 0; j < 3; ++j){
                for (int k = 0; k < 3; ++k){
                    index = k + 3*j + 9*i;
                    if (j == 0){
                        factor = -1;
                    }
                    if (j == 1){
                        factor = 0;
                    }
                    if (j == 2){
                        factor = 1;
                    }
                    if (i == 0 && k == 0){
                        sobel_y[index] = factor * 1;
                    }
                    if (i == 0 && k == 1){
                        sobel_y[index] = factor * 2;
                    }
                    if (i == 0 && k == 2){
                        sobel_y[index] = factor * 1;
                    }
                    if (i == 1 && k == 0){
                        sobel_y[index] = factor * 2;
                    }
                    if (i == 1 && k == 1){
                        sobel_y[index] = factor * 4;
                    }
                    if (i == 1 && k == 2){
                        sobel_y[index] = factor * 2;
                    }
                    if (i == 2 && k == 0){
                        sobel_y[index] = factor * 1;
                    }
                    if (i == 2 && k == 1){
                        sobel_y[index] = factor * 2;
                    }
                    if (i == 2 && k == 2){
                        sobel_y[index] = factor * 1;
                    }
                }
            }
        }
    
        // Now for S_x
        for (int i = 0; i < 3; ++i){
            for (int j = 0; j < 3; ++j){
                for (int k = 0; k < 3; ++k){
                    index = k + 3*j + 9*i;
                    if (i == 0){
                        factor = -1;
                    }
                    if (i == 1){
                        factor = 0;
                    }
                    if (i == 2){
                        factor = 1;
                    }
                    if (k == 0 && j == 0){
                        sobel_x[index] = factor * 1;
                    }
                    if (k == 0 && j == 1){
                        sobel_x[index] = factor * 2;
                    }
                    if (k == 0 && j == 2){
                        sobel_x[index] = factor * 1;
                    }
                    if (k == 1 && j == 0){
                        sobel_x[index] = factor * 2;
                    }
                    if (k == 1 && j == 1){
                        sobel_x[index] = factor * 4;
                    }
                    if (k == 1 && j == 2){
                        sobel_x[index] = factor * 2;
                    }
                    if (k == 2 && j == 0){
                        sobel_x[index] = factor * 1;
                    }
                    if (k == 2 && j == 1){
                        sobel_x[index] = factor * 2;
                    }
                    if (k == 2 && j == 2){
                        sobel_x[index] = factor * 1;
                    }
                }
            }
        }



        par.store("sobel_x", sobel_x);
        par.store("sobel_y", sobel_y);
        par.store("sobel_z", sobel_z);
    }

    transfer_sobel(par);

    par.store("found_sobel", true);
}

// Fucntion to transfer 3d sobel operators for non-fft convolution
void transfer_sobel(Grid &par){

    // Grabbing necessary parameters
    int xDim = par.ival("xDim");
    int yDim = par.ival("yDim");
    int zDim = par.ival("zDim");
    int gSize = xDim * yDim * zDim;
    std::string conv_type = par.sval("conv_type");

    double2 *sobel_x_gpu, *sobel_y_gpu, *sobel_z_gpu;

    // creating space on device for 2 separate cases
    // Note that in the case of the FFT, the Sobel operators will be double2's
    //     while in the case of the window transform, they will be double
    if (conv_type == "FFT"){
        double2 *sobel_x = par.cufftDoubleComplexval("sobel_x");
        double2 *sobel_y = par.cufftDoubleComplexval("sobel_y");
        double2 *sobel_z = par.cufftDoubleComplexval("sobel_z");
        cudaMalloc((void**) &sobel_x_gpu, sizeof(double2) *gSize);
        cudaMalloc((void**) &sobel_y_gpu, sizeof(double2) *gSize);
        cudaMalloc((void**) &sobel_z_gpu, sizeof(double2) *gSize);

        // Transferring to device
        cudaError_t err;
    
        // Sobel_x
        err = cudaMemcpy(sobel_x_gpu, sobel_x, sizeof(double2)*gSize,
                         cudaMemcpyHostToDevice);
        if (err != cudaSuccess){
            std::cout << "ERROR: Could not copy sobel_x to device!" << '\n';
            exit(1);
        }
    
        // Sobel_y
        err = cudaMemcpy(sobel_y_gpu, sobel_y, sizeof(double2)*gSize,
                         cudaMemcpyHostToDevice);
        if (err != cudaSuccess){
            std::cout << "ERROR: Could not copy sobel_y to device!" << '\n';
            exit(1);
        }
    
        // Sobel_z
        err = cudaMemcpy(sobel_z_gpu, sobel_z, sizeof(double2)*gSize,
                         cudaMemcpyHostToDevice);
        if (err != cudaSuccess){
            std::cout << "ERROR: Could not copy sobel_z to device!" << '\n';
            exit(1);
        }
    
        // Generating the 3d plan
        cufftHandle plan_3d;
        cufftPlan3d(&plan_3d, xDim, yDim, zDim, CUFFT_Z2Z);
    
        // We only need the FFT's of the sobel operators. Let's generate those
        cufftExecZ2Z(plan_3d, sobel_x_gpu, sobel_x_gpu, CUFFT_FORWARD);
        cufftExecZ2Z(plan_3d, sobel_y_gpu, sobel_y_gpu, CUFFT_FORWARD);
        cufftExecZ2Z(plan_3d, sobel_z_gpu, sobel_z_gpu, CUFFT_FORWARD);
    
        // Storing in set of parameters
        par.store("sobel_x_gpu", sobel_x_gpu);
        par.store("sobel_y_gpu", sobel_y_gpu);
        par.store("sobel_z_gpu", sobel_z_gpu);
    }
    else{
        double2 *sobel_x = par.cufftDoubleComplexval("sobel_x");
        double2 *sobel_y = par.cufftDoubleComplexval("sobel_y");
        double2 *sobel_z = par.cufftDoubleComplexval("sobel_z");
        cudaMalloc((void**) &sobel_x_gpu, sizeof(double) *9);
        cudaMalloc((void**) &sobel_y_gpu, sizeof(double) *9);
        cudaMalloc((void**) &sobel_z_gpu, sizeof(double) *9);
        // Transferring to device
        cudaError_t err;
   
        // Sobel_x
        err = cudaMemcpy(sobel_x_gpu, sobel_x, sizeof(double)*gSize,
                         cudaMemcpyHostToDevice);
        if (err != cudaSuccess){
            std::cout << "ERROR: Could not copy sobel_x to device!" << '\n';
            exit(1);
        }
   
        // Sobel_y
        err = cudaMemcpy(sobel_y_gpu, sobel_y, sizeof(double)*gSize,
                         cudaMemcpyHostToDevice);
        if (err != cudaSuccess){
            std::cout << "ERROR: Could not copy sobel_y to device!" << '\n';
            exit(1);
        }
   
        // Sobel_z
        err = cudaMemcpy(sobel_z_gpu, sobel_z, sizeof(double)*gSize,
                         cudaMemcpyHostToDevice);
        if (err != cudaSuccess){
            std::cout << "ERROR: Could not copy sobel_z to device!" << '\n';
            exit(1);
        }
   
        // Storing in set of parameters
        par.store("sobel_x_gpu", sobel_x_gpu);
        par.store("sobel_y_gpu", sobel_y_gpu);
        par.store("sobel_z_gpu", sobel_z_gpu);

    }

}

// function to transform a wavefunction to a field of edges
void find_edges(Grid &par, Cuda &cupar, Wave &wave, 
                double2* wfc, double* edges){

    // for this, we simply need to take our sobel 3d sobel filter,
    // FFT forward, multiply, FFT back.

    dim3 grid = cupar.dim3val("grid");
    dim3 threads = cupar.dim3val("threads");
    //cufftHandle plan_3d = cupar.cufftHandleval("plan_3d");

    double2 *wfc_gpu = wave.cufftDoubleComplexval("wfc_gpu");
    int xDim = par.ival("xDim");
    int yDim = par.ival("yDim");
    int zDim = par.ival("zDim");
    int gSize = xDim * yDim * zDim;

    // First, we need to generate the wfc_density
    //double *density = (double *)malloc(sizeof(double)*gSize);
    
    // copying density to device for cuda-fication
    double *density_d;
    cudaMalloc((void**) &density_d, sizeof(double) * gSize);

    // now to perform the complexMagnitudeSquared operation
    complexMagnitudeSquared<<<grid,threads>>>(wfc_gpu, density_d);

    // Now we need to grab the Sobel operators
    if (par.bval("found_sobel") == false){
        find_sobel(par);
    }

    // Pulling operators from find_sobel(par)
    double2 *sobel_x_gpu = par.cufftDoubleComplexval("sobel_x_gpu");
    double2 *sobel_y_gpu = par.cufftDoubleComplexval("sobel_y_gpu");
    double2 *sobel_z_gpu = par.cufftDoubleComplexval("sobel_z_gpu");

    // Creating variables for the edge gradient along xyz
    double2 *gradient_x_fft;
    double2 *gradient_y_fft;
    double2 *gradient_z_fft;

    cudaMalloc((void**) &gradient_x_fft, sizeof(double2) * gSize);
    cudaMalloc((void**) &gradient_y_fft, sizeof(double2) * gSize);
    cudaMalloc((void**) &gradient_z_fft, sizeof(double2) * gSize);

    // This should work in principle, but the D2Z transform plays tricks
    // Generating plan for d2z in 3d
    //cufftHandle plan_3d2z;
    //cufftPlan3d(&plan_3d2z, xDim, yDim, zDim, CUFFT_D2Z);

    // Creating complex density
    double2 *density_d2;
    cudaMalloc((void**) &density_d2, sizeof(double2) * gSize);

    make_cufftDoubleComplex<<<grid, threads>>>(density_d, density_d2);

    cufftHandle plan_3d;
    cufftPlan3d(&plan_3d, xDim, yDim, zDim, CUFFT_Z2Z);

    // Now fft forward, multiply, fft back
    cufftExecZ2Z(plan_3d, density_d2, gradient_x_fft, CUFFT_FORWARD);
    cufftExecZ2Z(plan_3d, density_d2, gradient_y_fft, CUFFT_FORWARD);
    cufftExecZ2Z(plan_3d, density_d2, gradient_z_fft, CUFFT_FORWARD);

    // Now to perform the multiplication
    cMult<<<grid, threads>>>(gradient_x_fft, sobel_x_gpu, gradient_x_fft);
    cMult<<<grid, threads>>>(gradient_y_fft, sobel_y_gpu, gradient_y_fft);
    cMult<<<grid, threads>>>(gradient_z_fft, sobel_z_gpu, gradient_z_fft);
    
    // FFT back
    cufftExecZ2Z(plan_3d, gradient_x_fft, gradient_x_fft, CUFFT_INVERSE);
    cufftExecZ2Z(plan_3d, gradient_y_fft, gradient_y_fft, CUFFT_INVERSE);
    cufftExecZ2Z(plan_3d, gradient_z_fft, gradient_z_fft, CUFFT_INVERSE);

    // Creating the edges variable on the gpu
    double *edges_gpu;
    cudaMalloc((void**) &edges_gpu, sizeof(double) * gSize);

    l2_norm<<<grid, threads>>>(gradient_x_fft, gradient_y_fft, 
                               gradient_z_fft, edges_gpu);

    // Copying edges back
    cudaMemcpy(edges, edges_gpu, sizeof(double) * gSize, 
               cudaMemcpyDeviceToHost);

    // Method to find edges based on window approach -- more efficient, 
    // but difficult to implement
/*
    // first, we need to set the threading
    unsigned int gid = getGid3d3d();

    // Now we need to create the wfc density
    density[gid] = complexMagnitudeSquared(wfc[gid]);

    // Now we should do the convolutions, note that we simply need to
    // pass the convolved "sum" around. It should work out just fine (I think)

    // Defining the sobel kernel;
    double kernel_tri[3];
    double kernel_div[3];

    kernel_tri[0] = 1;
    kernel_tri[1] = 2;
    kernel_tri[2] = 1;

    kernel_div[0] = -1;
    kernel_div[1] = 0;
    kernel_div[2] = 1;

    // Note: The 256, 256 is arbitrarily set right now
    convolve_row(density, edges, kernel_tri, 256, 256, 256);
    //convolve_col(density, edges, kernel_div, 256, 256, 256);
    //convolve_depth(density, edges, kernel_div, 256, 256, 256);
*/
}

__device__ void convolve_row(double* density, double* edges, double* kernel,
                             int width, int height, int depth){

    // These definitions are somewhat arbitrary for now. 
    // Kernel is the Sobel filter, so radius 1, right?
    int kernel_radius = 1;
    int kernel_radius_aligned = 1;
    int tile_width = 128;

    // this will need to be updated to compile. 
    // The array size needs to be constant
    __shared__ float data[130];

    // Defining apron limits with respect to starting row
    const int tile_start  = blockIdx.x * tile_width;
    const int tile_end    = tile_start + tile_width + 1;
    const int apron_start = tile_start - kernel_radius;
    const int apron_end   = tile_end + kernel_radius;

    // Clamps for limits according to resolution limits
    // I don't know if I'm allowed to se std functions here...
    const int tile_end_clamp    = min(tile_end, width - 1);
    const int apron_start_clamp = min(apron_start, 0);
    const int apron_end_clamp   = min(apron_end, width - 1);

    const int row_start = blockIdx.y * width;

    const int apron_start_aligned = tile_start - kernel_radius_aligned;

    const int load_pos = apron_start_aligned + threadIdx.x;

    if (load_pos >= apron_start){
        const int smem_pos = load_pos - apron_start;

        if (load_pos >= apron_start_clamp && load_pos <= apron_end_clamp){
            data[smem_pos] = density[row_start + load_pos];
        }
        else{
            data[smem_pos] = 0;
        }
    }

    __syncthreads();

    const int write_pos = tile_start + threadIdx.x;

    if (write_pos <= tile_end_clamp){
        const int smem_pos = write_pos - apron_start;
        float sum = 0;

        sum += data[smem_pos -1] * kernel[0];
        sum += data[smem_pos] * kernel[1];
        sum += data[smem_pos +1] * kernel[2];

        edges[row_start + write_pos] = sum;
    }
}

__device__ void convolve_col(double* density, double* edges, double* kernel,
                             int width, int height, int depth){

    // These definitions are somewhat arbitrary for now.
    // Kernel is the Sobel filter, so radius 1, right?
    int kernel_radius = 1;
    int kernel_radius_aligned = 1;
    int tile_width = 128;

    // this will need to be updated to compile.
    // The array size needs to be constant
    __shared__ float data[130];

    // Defining apron limits with respect to starting row
    const int tile_start  = blockIdx.x * tile_width;
    const int tile_end    = tile_start + tile_width + 1;
    const int apron_start = tile_start - kernel_radius;
    const int apron_end   = tile_end + kernel_radius;

    // Clamps for limits according to resolution limits
    // I don't know if I'm allowed to se std functions here...
    const int tile_end_clamp    = min(tile_end, width - 1);
    const int apron_start_clamp = min(apron_start, 0);
    const int apron_end_clamp   = min(apron_end, width - 1);

    const int col_start = blockIdx.y * width;

    const int apron_start_aligned = tile_start - kernel_radius_aligned;

    const int load_pos = apron_start_aligned + threadIdx.x;

    if (load_pos >= apron_start){
        const int smem_pos = load_pos - apron_start;

        if (load_pos >= apron_start_clamp && load_pos <= apron_end_clamp){
            data[smem_pos] = density[col_start + load_pos];
        }
        else{
            data[smem_pos] = 0;
        }
    }

    __syncthreads();

    const int write_pos = tile_start + threadIdx.x;

    if (write_pos <= tile_end_clamp){
        const int smem_pos = write_pos - apron_start;
        float sum = 0;

        sum += data[smem_pos -1] * kernel[0];
        sum += data[smem_pos] * kernel[1];
        sum += data[smem_pos +1] * kernel[2];

        edges[col_start + write_pos] = sum;
    }
}

__device__ void convolve_depth(double* density, double* edges, double* kernel,
                               int width, int height, int depth){

    // These definitions are somewhat arbitrary for now.
    // Kernel is the Sobel filter, so radius 1, right?
    int kernel_radius = 1;
    int kernel_radius_aligned = 1;
    int tile_width = 128;

    // this will need to be updated to compile.
    // The array size needs to be constant
    __shared__ float data[130];

    // Defining apron limits with respect to starting depth
    const int tile_start  = blockIdx.x * tile_width;
    const int tile_end    = tile_start + tile_width + 1;
    const int apron_start = tile_start - kernel_radius;
    const int apron_end   = tile_end + kernel_radius;

    // Clamps for limits according to resolution limits
    // I don't know if I'm allowed to se std functions here...
    const int tile_end_clamp    = min(tile_end, width - 1);
    const int apron_start_clamp = min(apron_start, 0);
    const int apron_end_clamp   = min(apron_end, width - 1);

    const int depth_start = blockIdx.y * width;

    const int apron_start_aligned = tile_start - kernel_radius_aligned;

    const int load_pos = apron_start_aligned + threadIdx.x;

    if (load_pos >= apron_start){
        const int smem_pos = load_pos - apron_start;

        if (load_pos >= apron_start_clamp && load_pos <= apron_end_clamp){
            data[smem_pos] = density[depth_start + load_pos];
        }
        else{
            data[smem_pos] = 0;
        }
    }

    __syncthreads();

    const int write_pos = tile_start + threadIdx.x;

    if (write_pos <= tile_end_clamp){
        const int smem_pos = write_pos - apron_start;
        float sum = 0;

        sum += data[smem_pos -1] * kernel[0];
        sum += data[smem_pos] * kernel[1];
        sum += data[smem_pos +1] * kernel[2];

        edges[depth_start + write_pos] = sum;
    }
}