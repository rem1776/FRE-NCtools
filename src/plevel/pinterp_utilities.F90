!***********************************************************************
!*                   GNU Lesser General Public License
!*
!* This file is part of the GFDL FRE NetCDF tools package (FRE-NCTools).
!*
!* FRE-NCTools is free software: you can redistribute it and/or modify it under
!* the terms of the GNU Lesser General Public License as published by
!* the Free Software Foundation, either version 3 of the License, or (at
!* your option) any later version.
!*
!* FRE-NCTools is distributed in the hope that it will be useful, but WITHOUT
!* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
!* FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
!* for more details.
!*
!* You should have received a copy of the GNU Lesser General Public
!* License along with FRE-NCTools..  If not, see
!* <http://www.gnu.org/licenses/>.
!***********************************************************************

module pinterp_utilities_mod

   use iso_fortran_env, only: error_unit
   use netcdf

   implicit none
   private

   public :: copy_axis, copy_variable,    &
      define_new_variable,         &
      set_verbose_level,           &
      error_handler,               &
      share_compression_parameters, &
      apply_compression_defaults

   integer, parameter :: max_char = 128
   integer :: verbose = 1
   integer :: user_deflation, user_shuffle, new_var_deflation, new_var_shuffle


contains

!#######################################################################

   subroutine copy_axis (ncid_in, name_in, ncid_out, dimid_out, &
      varid_in, varid_out, dimlen,           &
      dimlen_in, name_out, name_edges)

      integer,          intent(in)  :: ncid_in
      character(len=*), intent(in)  :: name_in
      integer,          intent(in)  :: ncid_out
      integer,          intent(out) :: dimid_out, varid_in, varid_out, dimlen
      integer,          intent(in),  optional :: dimlen_in
      character(len=*), intent(in),  optional :: name_out
      character(len=*), intent(out), optional :: name_edges

      character(len=NF90_MAX_NAME) :: oname, attname
      integer :: istat, recdim, dimid_in, xtype, ndims, natts, attnum, i
      integer :: deflate_in, deflation_in, shuffle_in, in_format
      integer :: deflation_out, shuffle_out
      logical :: found_edges, found_bounds
      character(len=NF90_MAX_NAME) :: name_bounds

      oname = trim(name_in)
      if (present(name_out)) oname = trim(name_out)

      ! search for axis edges (old convention) and bounds (CF convention)
      if (present(name_edges)) then
         do i=1,NF90_MAX_NAME; name_edges (i:i)=' '; enddo
         do i=1,NF90_MAX_NAME; name_bounds(i:i)=' '; enddo
      endif
      found_edges  = .false.
      found_bounds = .false.

      if (verbose > 1) print *, 'copy axis name=', trim(name_in)

      ! get record dimension id
      istat = NF90_INQUIRE (ncid_in, unlimiteddimid=recdim)

      ! get axis id
      istat = NF90_INQ_DIMID ( ncid_in, trim(name_in), dimid_in )
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)

      ! get axis length
      if (present(dimlen_in)) then
         dimlen = dimlen_in
      else
         istat = NF90_INQUIRE_DIMENSION ( ncid_in, dimid_in, len=dimlen)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif

      ! define output axis

      if (dimid_in /= recdim) then
         ! non-time axis
         istat = NF90_DEF_DIM ( ncid_out, trim(oname), dimlen, dimid_out )
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      else
         ! time axis
         istat = NF90_DEF_DIM ( ncid_out, trim(oname), NF90_UNLIMITED, dimid_out )
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif

      ! get variable id
      istat = NF90_INQ_VARID ( ncid_in, trim(name_in), varid_in )
      ! axis does not have a variable associated with it
      ! set output variables and return
      if (istat /= NF90_NOERR) then
         varid_in  = -1
         varid_out = -1
         return
      endif
      istat = NF90_INQUIRE_VARIABLE (ncid_in, varid_in, xtype=xtype, ndims=ndims, natts=natts)
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)

      ! must have one dimension
      if (ndims /= 1) then
         print *, 'ERROR: axis variable has more than one dimension'
         stop 111
      endif

      ! define output variable
      istat = NF90_DEF_VAR (ncid_out, trim(oname), xtype, (/dimid_out/), varid_out)
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)

      ! get compression parameters
      istat = NF90_INQUIRE ( ncid_in, formatnum=in_format )
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      if (in_format == NF90_FORMAT_64BIT .or. in_format == NF90_FORMAT_CLASSIC) then
         shuffle_in = 0
         deflate_in = 0
         deflation_in = 0
      else
         istat = NF90_INQ_VAR_DEFLATE (ncid_in, varid_in, shuffle_in, deflate_in, deflation_in)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif

      ! set compression parameters
      call apply_compression_defaults (deflation_in, shuffle_in, deflation_out, shuffle_out )
      if (deflation_out > 0) then
         istat = NF90_DEF_VAR_DEFLATE (ncid_out, varid_out, shuffle_out, 1, deflation_out)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif

      ! copy attributes
      do attnum = 1, natts
         istat = NF90_INQ_ATTNAME (ncid_in, varid_in, attnum, attname)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
         istat = NF90_COPY_ATT (ncid_in, varid_in, trim(attname), ncid_out, varid_out)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
         if (trim(attname) == 'edges') then
            if (present(name_edges)) then
               istat = NF90_GET_ATT (ncid_in, varid_in, 'edges', name_edges)  ! should check to see that length
               ! of name_edges is sufficient
               if (istat /= NF90_NOERR) call error_handler (ncode=istat)
               found_edges = .true.
            endif
         else if (trim(attname) == 'bounds') then
            if (present(name_edges)) then
               istat = NF90_GET_ATT (ncid_in, varid_in, 'bounds', name_bounds)
               if (istat /= NF90_NOERR) call error_handler (ncode=istat)
               found_bounds = .true.
            endif
         endif
      enddo

      ! if both axis edges and axis bounds check for agreement
      ! if they disagree then use the axis bounds
      if (found_edges .and. found_bounds) then
         if (name_edges /= name_bounds) then
            print *, 'WARNING: axis edges and bounds disagee for axis = ',trim(name_in)
            print *, 'WARNING: will continue using the axis bounds'
            name_edges = name_bounds
         endif
      endif

!-----------------------------------------------------------------------

   end subroutine copy_axis

!#######################################################################
! apply_compression_defaults -- applies the user-specified settings
!       deflation and shuffle to the input variable parameters.
!       If the user-specified settings are -1, use the input file settings.

   subroutine apply_compression_defaults ( deflation_in, shuffle_in, deflation_out, shuffle_out )

      integer, intent(in) :: deflation_in, shuffle_in
      integer, intent(out) :: deflation_out, shuffle_out

      if (user_deflation == -1) then
         deflation_out = deflation_in
      else if (user_deflation == 0) then
         deflation_out = 0
      else
         deflation_out = user_deflation
      endif

      if (user_shuffle == -1) then
         shuffle_out = shuffle_in
      else
         shuffle_out = user_shuffle
      endif

      if (verbose > 1) then
         if (deflation_out > 0) then
            print *, 'Using deflation=', deflation_out, 'and shuffle=', shuffle_out
         else
            print *, 'Not using deflation'
         endif
      endif

   end subroutine apply_compression_defaults

!#######################################################################

   subroutine copy_variable ( ncid_in, name_in, ncid_out, dimids, varid_out, &
      name_out, pack, range, missvalue    )

      integer,          intent(in)  :: ncid_in, ncid_out, dimids(:)
      character(len=*), intent(in)  :: name_in
      integer,          intent(out) :: varid_out

      character(len=*), intent(in), optional :: name_out
      logical, intent(in), optional :: pack
      real, intent(in), optional :: range(2), missvalue

      character(len=NF90_MAX_NAME) :: oname, attname
      integer :: istat, varid_in,  xtype, ndims, natts, attnum
      integer :: shuffle_in, deflate_in, deflation_in, in_format
      integer :: shuffle_out, deflation_out
      logical :: no_missing_value, no_valid_range, no_add_offset, no_scale_factor
!-----------------------------------------------------------------------
      if (verbose > 1) print *, 'copy_variable name=', trim(name_in)

      no_missing_value = .true.
      no_valid_range   = .true.
      no_add_offset    = .true.
      no_scale_factor  = .true.

      oname = name_in
      if (present(name_out)) oname = name_out

      ! get variable information
      istat = NF90_INQ_VARID ( ncid_in, trim(name_in), varid_in )
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      istat = NF90_INQUIRE_VARIABLE ( ncid_in, varid_in, &
         xtype=xtype, ndims=ndims, natts=natts)
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)

      if (size(dimids,1) /= ndims) then
         call error_handler ('Inconsistent number of dimensions when copying variable')
      endif

      ! define output variable
      istat = NF90_DEF_VAR ( ncid_out, trim(oname), xtype, dimids, varid_out)
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)

      ! get compression parameters
      istat = NF90_INQUIRE ( ncid_in, formatnum=in_format )
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      if (in_format == NF90_FORMAT_64BIT .or. in_format == NF90_FORMAT_CLASSIC) then
         shuffle_in = 0
         deflate_in = 0
         deflation_in = 0
      else
         istat = NF90_INQ_VAR_DEFLATE (ncid_in, varid_in, shuffle_in, deflate_in, deflation_in)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif

      ! set compression parameters
      call apply_compression_defaults (deflation_in, shuffle_in, deflation_out, shuffle_out )
      if (deflation_out > 0) then
         istat = NF90_DEF_VAR_DEFLATE (ncid_out, varid_out, shuffle_out, 1, deflation_out)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif

      ! new missing value?

      ! copy variable attributes
      do attnum = 1, natts
         istat = NF90_INQ_ATTNAME (ncid_in, varid_in, attnum, attname)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
         ! special treatment of several attributes
         if (trim(attname) == 'missing_value') then
            if (present(missvalue)) then
               call put_missing_value (ncid_out, varid_out, xtype, missvalue)
               no_missing_value = .false.
               cycle
            endif
         else if (trim(attname) == 'valid_range') then
            if (present(range)) then
               call put_valid_range (ncid_out, varid_out, xtype, range)
               no_valid_range = .false.
               cycle
            endif
            !else if (trim(attname) == 'add_offset') then
            !    no_add_offset = .false.
            !else if (trim(attname) == 'scale_factor') then
            !    no_scale_factor = .false.
         endif
         istat = NF90_COPY_ATT (ncid_in, varid_in, trim(attname), ncid_out, varid_out)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      enddo

      ! add missing value attribute if necessary
      if (present(missvalue) .and. no_missing_value) then
         call put_missing_value (ncid_out, varid_out, xtype, missvalue)
      endif
      ! add valid range attribute if necessary
      if (present(range) .and. no_valid_range) then
         call put_valid_range (ncid_out, varid_out, xtype, range)
      endif

!-----------------------------------------------------------------------

   end subroutine copy_variable

!#######################################################################

   subroutine put_missing_value ( ncid, varid, xtype, missval )
      integer, intent(in) :: ncid, varid, xtype
      real,    intent(in) :: missval

      integer :: istatmiss
      integer :: istatfill
! machine dependent data kind
      integer(2) :: imiss2
      integer(4) :: imiss4
      real(4)    :: miss4
      real(8)    :: miss8

      ! save missing value with same data type as variable

      select case (xtype)
       case (NF90_REAL4)
         miss4 = missval
         istatmiss = NF90_PUT_ATT (ncid, varid, 'missing_value', miss4)
         istatfill = NF90_PUT_ATT (ncid, varid, '_FillValue', miss4)
       case (NF90_INT2)
         imiss2 = nint(missval)
         istatmiss = NF90_PUT_ATT (ncid, varid, 'missing_value', imiss2)
         istatfill = NF90_PUT_ATT (ncid, varid, '_FillValue', imiss2)
       case (NF90_INT)
         imiss4 = nint(missval)
         istatmiss = NF90_PUT_ATT (ncid, varid, 'missing_value', imiss4)
         istatfill = NF90_PUT_ATT (ncid, varid, '_FillValue', imiss4)
       case (NF90_REAL8)
         miss8 = missval
         istatmiss = NF90_PUT_ATT (ncid, varid, 'missing_value', miss8)
         istatfill = NF90_PUT_ATT (ncid, varid, '_FillValue', miss8)
       case default
         call error_handler ('invalid xtype for missing value')
      end select

      if (istatmiss /= NF90_NOERR) call error_handler ('putting missing value', ncode=istatmiss)
      if (istatfill /= NF90_NOERR) call error_handler ('putting fill value', ncode=istatfill)

   end subroutine put_missing_value

!#######################################################################

   subroutine put_valid_range ( ncid, varid, xtype, range )
      integer, intent(in) :: ncid, varid, xtype
      real,    intent(in) :: range(2)

      integer :: istat
! machine dependent data kind
      integer(2) :: irange2(2)
      integer(4) :: irange4(2)
      real(4)    ::  range4(2)
      real(8)    ::  range8(2)

      ! save valid range with same data type as variable

      select case (xtype)
       case (NF90_REAL4)
         range4 = range
         istat = NF90_PUT_ATT (ncid, varid, 'valid_range', range4)
       case (NF90_INT2)
         irange2 = nint(range)
         istat = NF90_PUT_ATT (ncid, varid, 'valid_range', irange2)
       case (NF90_INT)
         irange4 = nint(range)
         istat = NF90_PUT_ATT (ncid, varid, 'valid_range', irange4)
       case (NF90_REAL8)
         range8 = range
         istat = NF90_PUT_ATT (ncid, varid, 'valid_range', range8)
       case default
         call error_handler ('invalid xtype for valid range')
      end select

      if (istat /= NF90_NOERR) call error_handler ('putting valid range', ncode=istat)

   end subroutine put_valid_range

!#######################################################################

   subroutine define_new_variable ( ncid, name, xtype, dimids, varid, &
      units, long_name, missing_value,  &
      time_avg_info, cell_methods )
      integer,          intent(in)  :: ncid, xtype, dimids(:)
      character(len=*), intent(in)  :: name
      integer,          intent(out) :: varid
      character(len=*), intent(in), optional :: units, long_name, &
         time_avg_info, cell_methods
      real,             intent(in), optional :: missing_value

      integer :: istat

      ! define output variable
      istat = NF90_DEF_VAR ( ncid, trim(name), xtype, dimids, varid )
      if (istat /= NF90_NOERR) call error_handler &
         ('defining output variable '//trim(name), ncode=istat)

      ! apply compression parameters
      if (new_var_deflation > 0) then
         istat = NF90_DEF_VAR_DEFLATE (ncid, varid, new_var_shuffle, 1, new_var_deflation)
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif

      ! new attributes
      if (present(units)) then
         istat = NF90_PUT_ATT (ncid, varid, 'units', trim(units))
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif
      if (present(long_name)) then
         istat = NF90_PUT_ATT (ncid, varid, 'long_name', trim(long_name))
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      endif
      ! NOTE: if data is packed then missing value needs to be packed
      if (present(missing_value)) then
         call put_missing_value (ncid, varid, xtype, missing_value)
      endif

      ! time average attributes
      if (present(cell_methods)) then
         if (cell_methods(1:1) .ne. ' ') then
            istat = NF90_PUT_ATT ( ncid, varid, 'cell_methods', trim(cell_methods) )
            if (istat /= NF90_NOERR) call error_handler (ncode=istat)
         endif
      endif
      if (present(time_avg_info)) then
         if (time_avg_info(1:1) .ne. ' ') then
            istat = NF90_PUT_ATT ( ncid, varid, 'time_avg_info',trim(time_avg_info) )
            if (istat /= NF90_NOERR) call error_handler (ncode=istat)
         endif
      endif

   end subroutine define_new_variable

!#######################################################################

   function get_variable_axes (ncid, name, axes) result (ndim)
      integer         , intent(in)  :: ncid
      character(len=*), intent(in)  :: name
      character(len=*), intent(out) :: axes(:)
      integer :: ndim

      integer :: dimids(NF90_MAX_VAR_DIMS), istat, varid, ndims, xtype, dimid

      ! get variable information
      istat = NF90_INQ_VARID (ncid, trim(name), varid)
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      istat = NF90_INQUIRE_VARIABLE (ncid, varid, xtype=xtype, ndims=ndims, dimids=dimids)
      if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      ndim = ndims

      if (size(axes) < ndim) &
         call error_handler ('ERROR in get_variable_axes: size(axes) < ndim')

      do dimid = 1, ndim
         istat = NF90_INQUIRE_DIMENSION (ncid, dimid, name=axes(dimid))
         if (istat /= NF90_NOERR) call error_handler (ncode=istat)
      enddo

   end function get_variable_axes

!#######################################################################

   subroutine set_verbose_level (verbose_level)
      integer, intent(in) :: verbose_level
      verbose = verbose_level
   end subroutine set_verbose_level

!#######################################################################

! make the namelist compression settings visible to code in this file
   subroutine share_compression_parameters (user_deflation2, user_shuffle2, &
      new_var_deflation2, new_var_shuffle2)
      integer, intent(in) :: user_deflation2, user_shuffle2
      integer, intent(in), optional :: new_var_deflation2, new_var_shuffle2

      user_deflation = user_deflation2
      user_shuffle = user_shuffle2
      if (present(new_var_deflation2)) new_var_deflation = new_var_deflation2
      if (present(new_var_shuffle2)) new_var_shuffle = new_var_shuffle2
   end subroutine share_compression_parameters

!#######################################################################

   subroutine error_handler (string, ncode)
      character(len=*), intent(in), optional :: string
      integer         , intent(in), optional :: ncode
      character(len=:), allocatable :: errstrg
      if (present(ncode))  then
         write (error_unit, '(A)') 'NETCDF ERROR'
      else
         write (error_unit, '(A)') 'ERROR'
      endif
      if (present(string)) write (error_unit, '(A)') trim(string)
      if (present(ncode))  then
         errstrg = NF90_STRERROR (ncode)
         write (error_unit, '(A)') trim(errstrg)
      endif
      stop 111
   end subroutine error_handler

!#######################################################################

end module pinterp_utilities_mod

