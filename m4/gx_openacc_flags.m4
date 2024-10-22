# ===========================================================================
#
# SYNOPSIS
#
#   GX_OPENACC_FLAGS()
#
# DESCRIPTION
#
#  Checks C compiler flags for openacc support.
#
# LICENSE
#
#   Copyright (c) 2024 Ryan Mulhall
#
#   This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published by the
#   Free Software Foundation; either version 3 of the License, or (at your
#   option) any later version.
#
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
#   Public License for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with this program. If not, see <https://www.gnu.org/licenses/>.
#
#   As a special exception, the respective Autoconf Macro's copyright owner
#   gives unlimited permission to copy, distribute and modify the configure
#   scripts that are the output of Autoconf when processing the Macro. You
#   need not follow the terms of the GNU General Public License when using
#   or distributing such scripts, even though portions of the text of the
#   Macro appear in them. The GNU General Public License (GPL) does govern
#   all other use of the material that constitutes the Autoconf Macro.

# ----------------------------------------------------------------------
#
#  Will set OPENACC_CFLAGS to openacc flags for a given compiler if accepted.
#
#  Mainly for nvhpc, offloading with gcc is not currently supported,
#  although the build will still work.
#
AC_DEFUN([GX_OPENACC_FLAGS],[
AC_CACHE_CHECK([whether C compiler accepts OpenACC flags], [gx_cv_openacc_flags],[

AC_LANG_ASSERT(C)
gx_cv_openacc_flags=unknown
gx_openacc_flags_CFLAGS_save=$CFLAGS

dnl check for base openacc flag
for ac_flag in -acc -fopenacc; do
  CFLAGS="$gx_openacc_flags_CFLAGS_save $ac_flag"
  AC_LINK_IFELSE([AC_LANG_SOURCE(
          extern int acc_get_device_type();
          int main(int argc, char** argv){
              acc_get_device_type();
              return 0;
          })],
     [gx_cv_openacc_flags="$gx_openacc_flags_CFLAGS_save ${ac_flag}"]; break)
done
rm -f conftest.err conftest.$ac_objext conftest.$ac_ext

CFLAGS="$gx_openacc_flags_CFLAGS_save"

if test "x$gx_cv_openacc_flags" = xunknown; then
  m4_default([$2],
              [AC_MSG_ERROR([no])])
else
  OPENACC_CFLAGS="${gx_cv_openacc_flags}"
  AC_MSG_RESULT([yes])
fi
],
AC_SUBST([OPENACC_CFLAGS])
)])
