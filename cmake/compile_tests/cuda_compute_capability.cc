//@HEADER
// ************************************************************************
//
//                        Kokkos v. 4.0
//       Copyright (2022) National Technology & Engineering
//               Solutions of Sandia, LLC (NTESS).
//
// Under the terms of Contract DE-NA0003525 with NTESS,
// the U.S. Government retains certain rights in this software.
//
// Part of Kokkos, under the Apache License v2.0 with LLVM Exceptions.
// See https://kokkos.org/LICENSE for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//@HEADER

#include <iostream>
#include <cuda_runtime_api.h>

int main() {
  cudaDeviceProp device_properties;
  const cudaError_t error = cudaGetDeviceProperties(&device_properties,
                                                    /*device*/ 0);
  if (error != cudaSuccess) {
    std::cout << "CUDA error: " << cudaGetErrorString(error) << '\n';
    return error;
  }
  unsigned int const compute_capability =
      device_properties.major * 10 + device_properties.minor;
#ifdef SM_ONLY
  std::cout << compute_capability;
#else
  switch (compute_capability) {
      // clang-format off
    case 30:  std::cout << "Set -DKokkos_ARCH_KEPLER30=ON ." << std::endl; break;
    case 32:  std::cout << "Set -DKokkos_ARCH_KEPLER32=ON ." << std::endl; break;
    case 35:  std::cout << "Set -DKokkos_ARCH_KEPLER35=ON ." << std::endl; break;
    case 37:  std::cout << "Set -DKokkos_ARCH_KEPLER37=ON ." << std::endl; break;
    case 50:  std::cout << "Set -DKokkos_ARCH_MAXWELL50=ON ." << std::endl; break;
    case 52:  std::cout << "Set -DKokkos_ARCH_MAXWELL52=ON ." << std::endl; break;
    case 53:  std::cout << "Set -DKokkos_ARCH_MAXWELL53=ON ." << std::endl; break;
    case 60:  std::cout << "Set -DKokkos_ARCH_PASCAL60=ON ." << std::endl; break;
    case 61:  std::cout << "Set -DKokkos_ARCH_PASCAL61=ON ." << std::endl; break;
    case 70:  std::cout << "Set -DKokkos_ARCH_VOLTA70=ON ." << std::endl; break;
    case 72:  std::cout << "Set -DKokkos_ARCH_VOLTA72=ON ." << std::endl; break;
    case 75:  std::cout << "Set -DKokkos_ARCH_TURING75=ON ." << std::endl; break;
    case 80:  std::cout << "Set -DKokkos_ARCH_AMPERE80=ON ." << std::endl; break;
    case 86:  std::cout << "Set -DKokkos_ARCH_AMPERE86=ON ." << std::endl; break;
    case 89:  std::cout << "Set -DKokkos_ARCH_ADA89=ON ." << std::endl; break;
    case 90:  std::cout << "Set -DKokkos_ARCH_HOPPER90=ON ." << std::endl; break;
    case 100: std::cout << "Set -DKokkos_ARCH_BLACKWELL100=ON ." << std::endl; break;
    case 120: std::cout << "Set -DKokkos_ARCH_BLACKWELL120=ON ." << std::endl; break;
    default:
      std::cout << "Compute capability " << compute_capability
                << " is not supported" << std::endl;
      // clang-format on
  }
#endif
  return 0;
}
