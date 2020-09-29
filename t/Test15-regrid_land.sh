#!/usr/bin/env bats
# Test regrid land data with cell_measures and cell_methods attribute

@test "Test regrid land data" {

  if [ ! -d "Test15" ] 
  then
  		mkdir Test15
  fi

  cd Test15
  ncgen -o 00050101.land_static.tile1.nc $top_srcdir/t/Test15-input/00050101.land_static.tile1.ncl
  ncgen -o 00050101.land_static.tile2.nc $top_srcdir/t/Test15-input/00050101.land_static.tile2.ncl
  ncgen -o 00050101.land_static.tile3.nc $top_srcdir/t/Test15-input/00050101.land_static.tile3.ncl
  ncgen -o 00050101.land_static.tile4.nc $top_srcdir/t/Test15-input/00050101.land_static.tile4.ncl
  ncgen -o 00050101.land_static.tile5.nc $top_srcdir/t/Test15-input/00050101.land_static.tile5.ncl
  ncgen -o 00050101.land_static.tile6.nc $top_srcdir/t/Test15-input/00050101.land_static.tile6.ncl
  ncgen -o C180_grid.tile1.nc $top_srcdir/t/Test15-input/C180_grid.tile1.ncl
  ncgen -o C180_grid.tile2.nc $top_srcdir/t/Test15-input/C180_grid.tile2.ncl
  ncgen -o C180_grid.tile3.nc $top_srcdir/t/Test15-input/C180_grid.tile3.ncl
  ncgen -o C180_grid.tile4.nc $top_srcdir/t/Test15-input/C180_grid.tile4.ncl
  ncgen -o C180_grid.tile5.nc $top_srcdir/t/Test15-input/C180_grid.tile5.ncl
  ncgen -o C180_grid.tile6.nc $top_srcdir/t/Test15-input/C180_grid.tile6.ncl
  ncgen -o C180_mosaic.nc $top_srcdir/t/Test15-input/C180_mosaic.ncl

  run command fregrid \
		--input_mosaic C180_mosaic.nc \
		--interp_method conserve_order1 \
		--nlon 144 \
		--nlat 90 \
		--remap_file remap_file.nc
  [ "$status" -eq 0 ] 

#remap static field
  run command fregrid  \
		--input_mosaic C180_mosaic.nc  \
		--interp_method conserve_order1  \
		--nlon 144  \
		--nlat 90  \
		--input_file 00050101.land_static  \
		--scalar_field soil_frac,lake_frac,glac_frac,area,soil_area,lake_area,glac_area  \
		--output_file out.nc  \
		--remap_file remap_file.nc 
  [ "$status" -eq 0 ] 

#TO DO: Add a parallel call and use nccmp to compare

# remap other fields
# Commented this part out because the input file is too large
#  run command fregrid  \
#		--input_mosaic C180_mosaic.nc  \
#		--interp_method conserve_order1  \
#		--nlon 144  \
#		--nlat 90  \
#		--input_file 00050101.land_month  \
#		--scalar_field evap_land,evap_soil,evap_glac,evap_lake  \
#		--output_file 00050101.land_month.nc  \
#		--remap_file remap_file.nc
#  [ "$status" -eq 0 ] 

  cd ..
  rm -rf Test15
}