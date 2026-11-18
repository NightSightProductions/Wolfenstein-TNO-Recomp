// Imports specific to Wolfenstein: The New Order.
#include "rt.h"

// cudart64_40_17.dll: the CUDA runtime's static registration of the virtual-texture transcode kernels (.nvFatBi),
// called from the CRT's initializers. No CUDA device exists on a Mac, so the engine uses its CPU transcoder; the
// registration only has to succeed and hand back a handle.
static uint64_t fatbin_handle[4];
void I_cudart64_40_17_dll___cudaRegisterFatBinary(CPU *c) { RET(G(fatbin_handle)); }
void I_cudart64_40_17_dll___cudaUnregisterFatBinary(CPU *c) { }
