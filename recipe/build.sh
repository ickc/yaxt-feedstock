#!/bin/bash

set -x

autoreconf -vfi

if [[ "${mpi}" == "openmpi" ]]; then
  export MPI_LAUNCH="${PREFIX}/bin/mpirun --oversubscribe"
  export OMPI_MCA_plm_rsh_agent=""
  if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    # openmpi's mpicc/mpifort under $PREFIX are compiled binaries for the
    # host (target) arch; when cross-compiling (e.g. osx-64 -> osx-arm64)
    # they can't run on the build machine at all. $BUILD_PREFIX carries a
    # build-arch copy of openmpi (added to requirements/build for exactly
    # this case) whose wrapper is configured -- via OMPI_CC/OMPI_FC/
    # OPAL_PREFIX, set automatically by openmpi's own activation script --
    # to target the host env instead. Same fix as
    # conda-forge/libpnetcdf-feedstock.
    COMPILER_PREFIX="${BUILD_PREFIX}"
  else
    COMPILER_PREFIX="${PREFIX}"
  fi
  export CC="${COMPILER_PREFIX}/bin/mpicc"
  export FC="${COMPILER_PREFIX}/bin/mpifort"
else
  export MPI_LAUNCH="${PREFIX}/bin/mpirun"
  export CC=mpicc
  export FC=mpifort
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # ACX_FC_C_2FLD_STRUCT_RETURN is new in 0.12.x and does a link test followed
  # by a run test.  Its cross-compilation branch reports "2-field-struct-return
  # link-test succeeded" but then stores the answer in the wrong cache variable
  # (acx_cv_cfortran_works instead of acx_cv_fc_c_2fld_struct_return), so the
  # check falls through to "failed" and configure disables the Fortran
  # interface of the bucket generator.  That drops
  # tests/test_xmap_bucket_tiler_f.f90 from libtestutil_f_la_SOURCES while
  # tests/test_xmap_common_f.f90 still USEs the module -- it guards that USE on
  # HAVE_FC_ABSTRACT_INTERFACE, a different condition -- and the build dies on
  # a missing test_xmap_bucket_tiler.mod.  Seed the cache with the answer the
  # native builds give: both osx-64 and linux-aarch64 report a plain "yes".
  export acx_cv_fc_c_2fld_struct_return=yes
fi

IDXTYPE_ARGS=""
if [[ "${idxtype}" == "long" ]]; then
  IDXTYPE_ARGS="--with-idxtype=long"
fi

./configure --prefix=${PREFIX} \
            --with-mpi-root=${PREFIX} \
            --with-pic \
            ${IDXTYPE_ARGS}

make -j ${CPU_COUNT} all
make install
