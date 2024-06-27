/***********************************************************************
 *                   GNU Lesser General Public License
 *
 * This file is part of the GFDL FRE NetCDF tools package (FRE-NCTools).
 *
 * FRE-NCtools is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 *
 * FRE-NCtools is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FRE-NCTools.  If not, see
 * <http://www.gnu.org/licenses/>.
 **********************************************************************/
#include <stdlib.h>
#include <stdio.h>
#include <openacc.h>
#include "globals_acc.h"
#include "general_utils_acc.h"

/*******************************************************************************
void copy_grid_to_device( const int itile, Grid_config *grid )
Copies lat lon coordinates to device
*******************************************************************************/
void copy_grid_to_device_acc( const int npoints, const double *lat, const double *lon )
{

#pragma acc enter data copyin(lon[:npoints], lat[:npoints])

}

void delete_grid_from_device_acc( const int npoints, const double *lat, const double *lon )
{

#pragma acc exit data delete(lat[:npoints], lon[:npoints])

}

/*******************************************************************************
void copy_interp_to_device( Interp_config *interp )
Copies the interp struct to device
*******************************************************************************/
void copy_interp_to_device_acc( const int ntiles_in, const int ntiles_out, const Interp_config_acc *interp_acc,
                                const unsigned int opcode )
{

#pragma acc enter data copyin(interp_acc[:ntiles_out])
  for(int otile=0 ; otile<ntiles_out; otile++) {

#pragma acc enter data copyin( interp_acc[otile].input_tile[:ntiles_in] )

    for(int itile=0 ; itile<ntiles_in ; itile++) {

      int nxcells = interp_acc[otile].input_tile[itile].nxcells;
#pragma acc enter data copyin( interp_acc[otile].input_tile[itile].input_parent_cell_index[:nxcells], \
                               interp_acc[otile].input_tile[itile].output_parent_cell_index[:nxcells],\
                               interp_acc[otile].input_tile[itile].xcell_area[:nxcells] )
        if( opcode & CONSERVE_ORDER2) {
#pragma acc enter data copyin( interp_acc[otile].input_tile[itile].dcentroid_lon[:nxcells], \
                               interp_acc[otile].input_tile[itile].dcentroid_lat[:nxcells])
        }

    } // ntiles_in
  }//ntiles_out

} //end copy_interp_to_device

/*******************************************************************************
void get_bounding_indices
gets indices for kat that overlap with the ref_grid_lat
TODO: THIS FUNCTION NEEDS A UNIT TEST
*******************************************************************************/
void get_bounding_indices_acc(const int ref_nlon_cells, const int ref_nlat_cells,
                              const int nlon_cells, const int nlat_cells,
                              const double *ref_grid_lat, const double *grid_lat,
                              int *overlap_starts_here_index, int *overlap_ends_here_index)
{

  int ref_min_lat, ref_max_lat;
  int overlap_starts_here_index_tmp = nlat_cells; //declared to avoid dereferencing
  int overlap_ends_here_index_tmp = -1;

  int nlat_gridpts = nlat_cells+1;
  int nlon_gridpts = nlon_cells+1;

  ref_min_lat = minval_double_acc((ref_nlat_cells+1)*(ref_nlon_cells+1), ref_grid_lat);
  ref_max_lat = maxval_double_acc((ref_nlat_cells+1)*(ref_nlon_cells+1), ref_grid_lat);

#pragma acc parallel loop collapse(2) present(grid_lat[:nlat_gridpts]) \
                                      copyin(ref_min_lat, ref_max_lat) \
                                      copy(overlap_starts_here_index_tmp, overlap_ends_here_index_tmp)\
                                      reduction(min:overlap_starts_here_index_tmp) \
                                      reduction(max:overlap_ends_here_index_tmp)
  for(int jlat=0; jlat<nlat_gridpts; jlat++) {
    for(int ilon=0; ilon<nlon_gridpts; ilon++) {
      double lat = grid_lat[jlat*nlon_gridpts+ilon];
      if( lat > ref_min_lat ) overlap_starts_here_index_tmp = min(overlap_starts_here_index_tmp, jlat);
      if( lat < ref_max_lat ) overlap_ends_here_index_tmp   = max(overlap_ends_here_index_tmp, jlat);
    }
  }

  // top and bottom cells share grid points. -1 to get bottom cell; +1 to get top cells
  *overlap_starts_here_index = max(0, overlap_starts_here_index_tmp-1);
  *overlap_ends_here_index   = min(nlat_cells-1, overlap_ends_here_index_tmp+1);

}
/*******************************************************************************
void get_input_skip_cells
assign mask to skip input cells in xgrid creation
*******************************************************************************/
void get_input_grid_mask_acc(const int mask_size, double **input_grid_mask)
{

  double *p_input_grid_mask;

  *input_grid_mask = (double *)malloc(mask_size*sizeof(double));
  p_input_grid_mask = *input_grid_mask;


#pragma acc enter data create(p_input_grid_mask[:mask_size])
#pragma acc parallel loop independent present(p_input_grid_mask[:mask_size])
  for( int i=0 ; i<mask_size; i++) p_input_grid_mask[i]=1.0;

}

void free_input_grid_mask_acc(const int mask_size, double **input_grid_mask)
{
  double *p_input_grid_mask;

  p_input_grid_mask = *input_grid_mask;

#pragma acc exit data delete(p_input_grid_mask[:mask_size])
  free(p_input_grid_mask);
  p_input_grid_mask = NULL;
}

void create_interp_acc_itile_arrays_on_device_acc(const int nxcells, const unsigned int opcode,
                                                  Interp_per_input_tile *interp_per_itile)
{

  interp_per_itile->input_parent_cell_index = (int *)malloc(nxcells *sizeof(int));
  interp_per_itile->output_parent_cell_index = (int *)malloc(nxcells *sizeof(int));
  interp_per_itile->xcell_area = (double *)malloc(nxcells * sizeof(double));

  if(opcode & CONSERVE_ORDER2) {
    interp_per_itile->dcentroid_lon = (double *)malloc(nxcells*sizeof(double));
    interp_per_itile->dcentroid_lat = (double *)malloc(nxcells*sizeof(double));
  }

#pragma acc enter data create(interp_per_itile)
#pragma acc enter data create(interp_per_itile->input_parent_cell_index[:nxcells], \
                              interp_per_itile->output_parent_cell_index[:nxcells], \
                              interp_per_itile->xcell_area[:nxcells])
  if(opcode & CONSERVE_ORDER2) {
#pragma acc enter data create(interp_per_itile->dcentroid_lon[:nxcells], \
                              interp_per_itile->dcentroid_lat[:nxcells])
  }


}
