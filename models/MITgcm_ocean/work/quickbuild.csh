#!/bin/csh
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

#----------------------------------------------------------------------
# compile all programs in the current directory that have a mkmf_xxx file.
#
# usage: [ -mpi | -nompi ]
#
# environment variable options:
#  before running this script, do:
#   "setenv CODE_DEBUG 1" (csh) or "export CODE_DEBUG=1" (bash)
#  to keep the .o and .mod files in the current directory instead of
#  removing them at the end.  this usually improves runtime error reports
#  and these files are required by most debuggers.
#
#----------------------------------------------------------------------

# this model name:
set BUILDING = "MITgcm_ocean"

# programs which have the option of building with MPI:
set MPI_TARGETS = "filter perfect_model_obs model_mod_check"

# set default (override with -mpi or -nompi):
#  0 = build without MPI, 1 = build with MPI
set with_mpi = 1

#----------------------------------------------------------------------
# shouldn't have to modify this script below here.

if ( $#argv >= 1 ) then
   if ( "$1" == "-mpi" ) then
      set with_mpi = 1
   else if ( "$1" == "-nompi" ) then
      set with_mpi = 0
   else
      echo usage: $0 '[ -mpi | -nompi ]'
      exit 0
   endif
endif

set preprocess_done = 0
set tdebug = 0
set cdebug = 0

if ( $?CODE_DEBUG ) then
   set cdebug = $CODE_DEBUG
endif
if ( $?DART_TEST ) then
   set tdebug = $DART_TEST
endif

\rm -f preprocess *.o *.mod Makefile .cppdefs

#----------------------------------------------------------------------
# Build all the single-threaded targets
#----------------------------------------------------------------------

@ n = 0

foreach TARGET ( mkmf_preprocess mkmf_* )

   set PROG = `echo $TARGET | sed -e 's/mkmf_//'`

   if ( $PROG == "preprocess" && $preprocess_done ) goto skip

   if ( $with_mpi ) then
      foreach i ( $MPI_TARGETS )
         if ( $PROG == $i ) goto skip
      end
   endif

   @ n = $n + 1
   echo
   echo "---------------------------------------------------"
   echo "$BUILDING build number $n is $PROG"
   \rm -f $PROG
   csh $TARGET || exit $n
   make        || exit $n

   if ( $tdebug ) then
      echo 'removing all files between builds'
      \rm -f *.o *.mod Makefile .cppdefs
   endif

   # preprocess creates module files that are required by
   # the rest of the executables, so it must be run in addition
   # to being built.
   if ( $PROG == "preprocess" ) then
      ./preprocess || exit $n
      set preprocess_done = 1
   endif

skip:
end

if ( $cdebug ) then
   echo 'preserving .o and .mod files for debugging'
else
   \rm -f *.o *.mod Makefile .cppdefs
endif

\rm -f input.nml*_default

echo "Success: All single task DART programs compiled."

if ( $with_mpi ) then
  echo "Script now compiling MPI parallel versions of the DART programs."
else
  echo "Script is exiting after building the serial versions of the DART programs."
  exit 0
endif

\rm -f *.o *.mod Makefile .cppdefs

#----------------------------------------------------------------------
# Build the MPI-enabled target(s)
#----------------------------------------------------------------------

# module swap PrgEnv-intel PrgEnv-cray 
# module load cray-netcdf

foreach PROG ( $MPI_TARGETS )

   set TARGET = `echo $PROG | sed -e 's/^/mkmf_/'`

   @ n = $n + 1
   echo
   echo "---------------------------------------------------"
   echo "$BUILDING with MPI build number $n is $PROG"
   \rm -f $PROG
   csh $TARGET -mpi || exit $n
   make             || exit $n

   if ( $tdebug ) then
      echo 'removing all files between builds'
      \rm -f *.o *.mod Makefile .cppdefs
   endif

end

if ( $cdebug ) then
   echo 'preserving .o and .mod files for debugging'
else
   \rm -f *.o *.mod Makefile .cppdefs
endif
\rm -f input.nml*_default

echo "Success: All MPI parallel DART programs compiled."

exit 0


