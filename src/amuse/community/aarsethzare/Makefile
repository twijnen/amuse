# standard amuse configuration include
# config.mk will be made after ./configure has run
AMUSE_DIR?=../../../..
-include ${AMUSE_DIR}/config.mk

MPIFC ?= mpif90
FORTRAN ?= gfortran
FC ?= $(FORTRAN)

FFLAGS   += -g
LDFLAGS  += -lm $(MUSE_LD_FLAGS)

OBJS = interface.o

CODELIB = src/libaarsethzare.a

CODE_GENERATOR = $(AMUSE_DIR)/build.py

all: aarsethzare_worker 

clean:
	$(RM) -f *.so *.o *.pyc worker_code.cc worker_code.h 
	$(RM) *~ aarsethzare_worker worker_code.f90 aarsethzare_worker_sockets worker_code-sockets.f90
	$(RM) -f forsockets.mod
	make -C src clean

$(CODELIB):  src/*.f
	make -C src all

worker_code.f90: interface.py
	$(CODE_GENERATOR) --type=f90 interface.py AarsethZareInterface -o $@
	
aarsethzare_worker: worker_code.f90 $(CODELIB) $(OBJS)
	$(MPIFC) $(FCFLAGS) $(FS_FLAGS) $(LDFLAGS) -cpp worker_code.f90 $(OBJS) $(CODELIB) $(FS_LIBS) -o $@  $(LIBS)
	
%.o: %.f90
	$(FORTRAN) $(FFLAGS) -c -o $@ $<
