/*** tracker.h - GPUE: Split Operator based GPU solver for Nonlinear 
Schrodinger Equation, Copyright (C) 2011-2015, Lee J. O'Riordan 
<loriordan@gmail.com>, Tadhg Morgan, Neil Crowley. 
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are 
met:

1. Redistributions of source code must retain the above copyright 
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright 
notice, this list of conditions and the following disclaimer in the 
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its 
contributors may be used to endorse or promote products derived from 
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifndef TRACKER_H
#define TRACKER_H
#ifdef __linux
	#include<omp.h>
#elif __APPLE__
#endif
#include<math.h>
#include<stdio.h>
#include<cuda.h>
#include<cuda_runtime.h>
#include<complex.h>

/** See the source file for info on functions.**/
namespace Tracker{
	
	/** Vortex is used to track specific individual vortices.
	 * coords tracks x,y positions.
	 * sign indicates direction of vortex rotation.
	 * wind indicates the unit charge of the vortex.
	 */
	struct Vortex{
		int2 coords;
		int sign;
		int wind;
	};

	int findVortex(int*,double2*, double, int, double*, int);
	void vortPos(int *marker, struct Vortex *vLocation, int xDim, double2* wfc);
	void olPos(int *marker, int2 *vLocation, int xDim);
	struct Vortex* vortPosDelta(int *cMarker, int2 *pMarker, double* x, double tolerance, int numVortices, int xDim);
	struct Vortex vortCentre(struct Vortex *cArray, int length, int xDim);
	double vortAngle(struct Vortex *vortCoords, struct Vortex central, int numVort);
	double vortSepAvg(struct Vortex *vArray, struct Vortex centre, int length);
	double sigVOL(int2 *vArr, int2 *opLatt, double *x, int numVort);

	/**
	 * Finds the maxima of the optical lattice. Deprecated.
	 */
	int findOLMaxima(int *marker, double *V, double radius, int xDim, double* x);
	void vortArrange(struct Vortex *vCoordsC, struct Vortex *vCoordsP, int length);
	int phaseTest(int2 vLoc, double2* wfc, int xDim);
}

#endif
