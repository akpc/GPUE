/*
* operators.h - GPUE2: GPU Split Operator solver for Nonlinear
* Schrodinger Equation, Copyright (C) 2015, Lee J. O'Riordan.

* This library is free software; you can redistribute it and/or modify
* it under the terms of the GNU Lesser General Public License as
* published by the Free Software Foundation; either version 2.1 of the
* License, or (at your option) any later version. This library is
* distributed in the hope that it will be useful, but WITHOUT ANY
* WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
* License for more details. You should have received a copy of the GNU
* Lesser General Public License along with this library; if not, write
* to the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
* Boston, MA 02111-1307 USA
*/

//###########################################################################################################//

#ifndef OPERATORS_H
#define OPERATORS_H

double* generate_V(struct addr_grid *grid, double mass, double[] omega);
double* generate_K(struct addr_grid *grid, double mass);
double2* generate_gndOperator(double *operator, struct addr_grid *grid, double dt_hbar);
double2* generate_evOperator(double *operator, struct addr_grid *grid, double dt_hbar);

#endif

//###########################################################################################################//
