
#include "../include/split_op.h"
#include "../include/kernels.h"
#include "../include/constants.h"
#include "../include/fileIO.h"
#include "../include/tracker.h"
#include "../include/minions.h"
#include "../include/parser.h"

#include "../include/lattice.h"
#include "../include/node.h"
#include "../include/edge.h"
#include "../include/manip.h"
#include "../include/vort.h"
#include <string>
#include <iostream>


//Declare the static uid values to avoid conflicts. Upper limit of 2^32-1 different instances. Should be reasonable in
// any simulation of realistic timescales.
unsigned int LatticeGraph::Edge::suid = 0;
unsigned int LatticeGraph::Node::suid = 0;
//std::size_t Vtx::Vortex::suid = 0;

char buffer[100]; //Buffer for printing out. Need to replace by a better write-out procedure. Consider binary or HDF.
int verbose; //Print more info. Not curently implemented.
int device; //GPU ID choice.
int kick_it; //Kicking mode: 0 = off, 1 = multiple, 2 = single
int graph=0; //Generate graph from vortex lattice.
double gammaY; //Aspect ratio of trapping geometry.
double omega; //Rotation rate of condensate
double timeTotal;
double angle_sweep; //Rotation angle of condensate relative to x-axis
double x0_shift, y0_shift; //Optical lattice shift parameters.
double Rxy; //Condensate scaling factor.
double a0x, a0y; //Harmonic oscillator length in x and y directions
double sepMinEpsilon=0.0; //Minimum separation for epsilon.

/*
 * Checks CUDA routines have exitted correctly.
 */
int isError(int result, char* c){
    if(result!=0){
        printf("Error has occurred for method %s with return type %d\n",
               c,result);
        exit(result);
    }
    return result;
}
/*
 * Used to perform parallel summation on WFC for normalisation.
 */
void parSum(double* gpuWfc, double* gpuParSum, Grid &par){
    // May need to add double l
    int dimnum = par.ival("dimnum");
    double dx = par.dval("dx");
    double dy = par.dval("dy");
    double dz = par.dval("dz");
    dim3 threads = par.threads;
    int xDim = par.ival("xDim");
    int yDim = par.ival("yDim");
    int zDim = par.ival("zDim");
    dim3 grid_tmp(xDim, 1, 1);
    int gsize = xDim;
    double dg = dx;

    // Setting option for 3d
    if (dimnum > 1){
        grid_tmp.x *= yDim;
        gsize *= yDim;
        dg *= dy;
    }
    if (dimnum > 2){
        grid_tmp.x *= zDim;
        gsize *= zDim;
        dg *= dz;
    }
    dim3 block(grid_tmp.x/threads.x, 1, 1);
    dim3 thread_tmp = threads;
    int pass = 0;

    set_eq<<<par.grid, par.threads>>>(gpuWfc, gpuParSum);

    dim3 grid = par.grid;
    while((double)grid_tmp.x/threads.x > 1.0){
        multipass<<<block,thread_tmp,thread_tmp.x*sizeof(double)>>>(
            &gpuParSum[0],&gpuParSum[0]);
        grid_tmp.x /= threads.x;
        block = (int) ceil((double)grid_tmp.x/threads.x);
        pass++;
        //std::cout << grid_tmp.x << '\n';
    }
    thread_tmp = grid_tmp.x;
    multipass<<<1,thread_tmp,thread_tmp.x*sizeof(double2)>>>(&gpuParSum[0],
                                                           &gpuParSum[0]);
}

/*
 * Used to perform parallel summation on WFC for normalisation.
 */
void parSum(double2* gpuWfc, Grid &par){
    // May need to add double l
    int dimnum = par.ival("dimnum");
    double dx = par.dval("dx");
    double dy = par.dval("dy");
    double dz = par.dval("dz");
    dim3 threads = par.threads;
    int xDim = par.ival("xDim");
    int yDim = par.ival("yDim");
    int zDim = par.ival("zDim");
    dim3 grid_tmp(xDim, 1, 1);
    int gsize = xDim;
    double dg = dx;

    // Setting option for 3d
    if (dimnum > 1){
        grid_tmp.x *= yDim;
        gsize *= yDim;
        dg *= dy;
    }
    if (dimnum > 2){
        grid_tmp.x *= zDim;
        gsize *= zDim;
        dg *= dz;
    }
    dim3 block(grid_tmp.x/threads.x, 1, 1);
    dim3 thread_tmp = threads;
    int pass = 0;

    double *density;
    cudaMalloc((void**) &density, sizeof(double)*gsize);

    complexMagnitudeSquared<<<par.grid, par.threads>>>(gpuWfc, density);

/*
    std::cout << "grid / threads = " << '\t'
              << (double)grid_tmp.x/threads.x << '\n'
              << "grid.x is: " << grid_tmp.x << '\t'
              << "threads.x are: " << threads.x << '\n';
*/
    dim3 grid = par.grid;
    while((double)grid_tmp.x/threads.x > 1.0){
        multipass<<<block,threads,threads.x*sizeof(double)>>>(&density[0],
                                                              &density[0]);
        grid_tmp.x /= threads.x;
        block = (int) ceil((double)grid_tmp.x/threads.x);
        pass++;
        //std::cout << pass << '\t' << grid_tmp.x << '\n';
    }
    thread_tmp = grid_tmp.x;
    multipass<<<1,thread_tmp,thread_tmp.x*sizeof(double)>>>(&density[0],
                                                            &density[0]);

/*
    // Writing out in the parSum Function (not recommended, for debugging)
    double *sum;
    sum = (double *) malloc(sizeof(double)*gsize);
    cudaMemcpy(sum,density,sizeof(double)*gsize,
               cudaMemcpyDeviceToHost);
    std::cout << (sum[0]) << '\n';
*/
    scalarDiv_wfcNorm<<<par.grid,par.threads>>>(gpuWfc, dg, density, gpuWfc);

    cudaFree(density);
}

/**
** Matches the optical lattice to the vortex lattice.
** Moire super-lattice project.
**/
void optLatSetup(std::shared_ptr<Vtx::Vortex> centre, const double* V,
                 std::vector<std::shared_ptr<Vtx::Vortex>> &vArray, double theta_opt,
                 double intensity, double* v_opt, const double *x, const double *y,
                 Grid &par){
    std::string data_dir = par.sval("data_dir");
    int xDim = par.ival("xDim");
    int yDim = par.ival("yDim");
    double dx = par.dval("dx");
    double dy = par.dval("dy");
    double dt = par.dval("dt");
    cufftDoubleComplex *EV_opt = par.cufftDoubleComplexval("EV_opt");
    int i,j;
    double sepMin = Tracker::vortSepAvg(vArray,centre);
    sepMin = sepMin*(1 + sepMinEpsilon);
    par.store("Vort_sep",(double)sepMin);

    // Defining the necessary k vectors for the optical lattice


    // Additional /2 as a result of lambda/2 period
    double k_mag = ((2*PI/(sepMin*dx))/2)*(2/sqrt(3));
    double2* k = (double2*) malloc(sizeof(double2)*3);
    par.store("kmag",(double)k_mag);
    k[0].x = k_mag * cos(0*PI/3 + theta_opt);
    k[0].y = k_mag * sin(0*PI/3 + theta_opt);
    k[1].x = k_mag * cos(2*PI/3 + theta_opt);
    k[1].y = k_mag * sin(2*PI/3 + theta_opt);
    k[2].x = k_mag * cos(4*PI/3 + theta_opt);
    k[2].y = k_mag * sin(4*PI/3 + theta_opt);

    double2 *r_opt = (double2*) malloc(sizeof(double2)*xDim);

    //FileIO::writeOut(buffer,data_dir + "r_opt",r_opt,xDim,0);
    par.store("k[0].x",(double)k[0].x);
    par.store("k[0].y",(double)k[0].y);
    par.store("k[1].x",(double)k[1].x);
    par.store("k[1].y",(double)k[1].y);
    par.store("k[2].x",(double)k[2].x);
    par.store("k[2].y",(double)k[2].y);

    // sin(theta_opt)*(sepMin);

    double x_shift = dx*(9+(0.5*xDim-1) - centre->getCoordsD().x);

    // cos(theta_opt)*(sepMin);
    double y_shift = dy*(0+(0.5*yDim-1) - centre->getCoordsD().y);

    printf("Xs=%e\nYs=%e\n",x_shift,y_shift);

    //#pragma omp parallel for private(j)
    for ( j=0; j<yDim; ++j ){
        for ( i=0; i<xDim; ++i ){
            v_opt[j*xDim + i] = intensity*(
                                pow( ( cos( k[0].x*( x[i] + x_shift ) +
                                       k[0].y*( y[j] + y_shift ) ) ), 2) +
                                pow( ( cos( k[1].x*( x[i] + x_shift ) +
                                       k[1].y*( y[j] + y_shift ) ) ), 2) +
                                pow( ( cos( k[2].x*( x[i] + x_shift ) +
                                       k[2].y*( y[j] + y_shift ) ) ), 2)
                                );
            EV_opt[(j*xDim + i)].x=cos( -(V[(j*xDim + i)] +
                                   v_opt[j*xDim + i])*(dt/(2*HBAR)));
            EV_opt[(j*xDim + i)].y=sin( -(V[(j*xDim + i)] +
                                   v_opt[j*xDim + i])*(dt/(2*HBAR)));
        }
    }

    // Storing changed variables
    par.store("EV_opt", EV_opt);
    par.store("V", V);
    par.store("V_opt",v_opt);
}

/**
** Calculates energy and angular momentum of current state.
** Implementation not fully finished.
**/
double energy_angmom(double2 *gpuWfc, int gState, Grid &par){
    bool corotating = par.bval("corotating");
    int xDim = par.ival("xDim");
    int yDim = par.ival("yDim");
    int zDim = par.ival("zDim");
    double dx = par.dval("dx");
    double dy = par.dval("dy");
    double dz = par.dval("dz");

    std::cout << dx << '\t' << dy << '\t' << dz << '\t' << xDim << '\t' 
              << yDim << '\t' << zDim << '\n';

    int gSize = xDim * yDim * zDim;
    double dt = par.dval("dt");
    double gDenConst = par.dval("gDenConst");

    double mass = par.dval("mass");
    double omegaX = par.dval("omegaX");
    double omegaY = par.dval("omegaY");
    double omegaZ = par.dval("omegaZ");

    dim3 threads = par.threads;
    dim3 grid = par.grid;

    // Creating the 2d plan and defining other cuda variables
    cufftHandle plan;
    cufftResult result;
    cudaError_t err;

    if (par.ival("dimnum") == 1){
        plan = par.ival("plan_1d");
    }
    if (par.ival("dimnum") == 2){
        plan = par.ival("plan_2d");
    }
    if (par.ival("dimnum") == 3){
        plan = par.ival("plan_3d");
    }

    double renorm_factor=1.0/pow(gSize,0.5);
    double out;

    // now allocating space on CPU and GPU for energy
    double2 *energy, *energy_gpu, *tmp_wfc, *op;

    energy = (double2*)malloc(sizeof(double2)*gSize);

    cudaMalloc((void**) &energy_gpu, sizeof(double2)*gSize);
    cudaMalloc((void**) &tmp_wfc, sizeof(double2)*gSize);


    for (int i=0; i < gSize; ++i){
        energy[i].x = 0.0; 
        energy[i].y = 0.0; 
    }

    // Now to memcpy the values over
    cudaMemcpy(energy_gpu, energy, sizeof(double2)*gSize,
               cudaMemcpyHostToDevice);

    int op_space = 2;

    result = cufftExecZ2Z( plan, gpuWfc, tmp_wfc, CUFFT_FORWARD );

    scalarMult<<<grid,threads>>>(tmp_wfc, renorm_factor, tmp_wfc);//Normalise

    op = par.cufftDoubleComplexval("K_gpu");

    energyCalc<<<grid,threads>>>(tmp_wfc, op, dt, energy_gpu, gState,op_space,
                                 0.5*sqrt(omegaZ/mass), gDenConst);
    result = cufftExecZ2Z( plan, energy_gpu, energy_gpu, CUFFT_INVERSE );
    result = cufftExecZ2Z( plan, tmp_wfc, tmp_wfc, CUFFT_INVERSE );

    scalarMult<<<grid,threads>>>(energy_gpu, renorm_factor, energy_gpu);
    scalarMult<<<grid,threads>>>(tmp_wfc, renorm_factor, tmp_wfc);

    if (corotating){
        op_space = 0;
    }
    else{
        op_space = 1;
    }

    op = par.cufftDoubleComplexval("V_gpu");

    energyCalc<<<grid,threads>>>(tmp_wfc, op, dt, energy_gpu, gState,op_space,
                                 0.5*sqrt(omegaZ/mass), gDenConst);

    err=cudaMemcpy(energy, energy_gpu, 
                   sizeof(cufftDoubleComplex)*gSize, 
                   cudaMemcpyDeviceToHost);
    if(err!=cudaSuccess){
        std::cout << "ERROR: Could not copy energy to host!" << '\n';
        exit(1);
    }
    
    for(int i=0; i < gSize; i++){
        out += energy[i].x + energy[i].y;
    }

    cudaFree(energy_gpu);
    cudaFree(tmp_wfc);
    free(energy);
    return out*dx*dy*dz;

}
/*

// Creates narrow Gaussian "delta" peaks for vortex kicking
void delta_define(double *x, double *y, double x0, double y0, double *delta,
                  Grid &par){
    int xDim = par.ival("xDim");
    int yDim = par.ival("yDim");
    cufftDoubleComplex *EV_opt = par.cufftDoubleComplexval("EV_opt");
    double *V = par.dsval("V");
    double dx = par.dval("dx");
    double dt = par.dval("dt");

    for (int i=0; i<xDim; ++i){
        for (int j=0; j<yDim; ++j){
            delta[j*xDim + i] = 1e6*HBAR*exp( -( pow( x[i] - x0, 2) +
                                pow( y[j] - y0, 2) )/(5*dx*dx) );
            EV_opt[(j*xDim + i)].x = cos( -(V[(j*xDim + i)] +
                                     delta[j*xDim + i])*(dt/(2*HBAR)));
            EV_opt[(j*xDim + i)].y = sin( -(V[(j*xDim + i)] +
                                     delta[j*xDim + i])*(dt/(2*HBAR)));
        }
    }
}
*/
