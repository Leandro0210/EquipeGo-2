// EquipeGo 2 - Piloto 01: ETA de muchos candidatos en CPU y GPU.
// Base: formula de Dispatcher.cpp, sin reemplazar shortestRoute (Dijkstra).
// Uso: ./eta_benchmark [N] [hilos_por_bloque] [repeticiones]

#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <exception>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

#include "eta_cpu.hpp"

#define CUDA_CHECK(call)                                                     \
  do {                                                                       \
    const cudaError_t err = (call);                                          \
    if (err != cudaSuccess) {                                                \
      throw std::runtime_error(std::string("CUDA: ") +                       \
                               cudaGetErrorString(err) + " (" + #call + ")"); \
    }                                                                        \
  } while (0)

__global__ void calcularETA_GPU(const double* distanciaAlRestauranteMetros,
                                double distanciaAlClienteMetros,
                                double velocidadMetrosPorSegundo,
                                double* etaSegundos,
                                std::size_t cantidad) {
  const std::size_t i = static_cast<std::size_t>(blockIdx.x) * blockDim.x +
                        threadIdx.x;
  if (i < cantidad) {
    etaSegundos[i] = (distanciaAlRestauranteMetros[i] +
                      distanciaAlClienteMetros) / velocidadMetrosPorSegundo;
  }
}

static double mediana(std::vector<double> valores) {
  std::sort(valores.begin(), valores.end());
  const std::size_t medio = valores.size() / 2;
  return valores.size() % 2 ? valores[medio]
                            : (valores[medio - 1] + valores[medio]) / 2.0;
}

static int enteroPositivo(const char* str, const char* etiqueta) {
  const long long n = std::stoll(str);
  if (n < 1 || n > std::numeric_limits<int>::max()) {
    throw std::invalid_argument(std::string(etiqueta) + " fuera de rango");
  }
  return static_cast<int>(n);
}

int main(int argc, char** argv) {
  double* dDistancia = nullptr;
  double* dETA = nullptr;
  cudaEvent_t inicio = nullptr;
  cudaEvent_t fin = nullptr;
  try {
    if (argc > 4) throw std::invalid_argument("Demasiados argumentos");
    const int n = argc > 1 ? enteroPositivo(argv[1], "N") : 100000;
    const int hilos = argc > 2 ? enteroPositivo(argv[2], "hilos") : 256;
    const int repeticiones = argc > 3 ? enteroPositivo(argv[3], "repeticiones") : 15;

    cudaDeviceProp prop{};
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    if (hilos > prop.maxThreadsPerBlock) {
      throw std::invalid_argument("Hilos por bloque excede el limite de la GPU");
    }
    CUDA_CHECK(cudaSetDevice(0));

    // Misma semilla -> mismos datos para CPU y GPU en cada prueba.
    std::mt19937_64 generador(2026);
    std::uniform_real_distribution<double> distribucion(100.0, 18000.0);
    std::vector<double> distancias(n);
    for (double& distancia : distancias) distancia = distribucion(generador);

    // En EquipeGo, estos datos vienen de shortestRoute y de config.fleet.speedKmh.
    constexpr double DISTANCIA_CLIENTE_METROS = 1600.0;
    constexpr double VELOCIDAD_KMH = 25.0;
    const double velocidadMS = VELOCIDAD_KMH / 3.6;

    std::vector<double> etaCPU(n, 0.0);
    std::vector<double> etaGPU(n, 0.0);
    const std::size_t bytes = static_cast<std::size_t>(n) * sizeof(double);
    const int bloques = (n + hilos - 1) / hilos;

    CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&dDistancia), bytes));
    CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&dETA), bytes));
    CUDA_CHECK(cudaEventCreate(&inicio));
    CUDA_CHECK(cudaEventCreate(&fin));
    CUDA_CHECK(cudaMemcpy(dDistancia, distancias.data(), bytes,
                          cudaMemcpyHostToDevice));

    // Calentamiento previo de ambos caminos; no cuenta para las mediciones.
    for (int i = 0; i < 3; ++i) {
      calcularETA_CPU(distancias.data(), DISTANCIA_CLIENTE_METROS,
                      velocidadMS, etaCPU.data(), static_cast<std::size_t>(n));
      calcularETA_GPU<<<bloques, hilos>>>(dDistancia, DISTANCIA_CLIENTE_METROS,
                                          velocidadMS, dETA, n);
      CUDA_CHECK(cudaGetLastError());
    }
    CUDA_CHECK(cudaDeviceSynchronize());

    std::vector<double> tiemposCPU, tiemposKernel, tiemposTotal;
    tiemposCPU.reserve(repeticiones);
    tiemposKernel.reserve(repeticiones);
    tiemposTotal.reserve(repeticiones);

    using Reloj = std::chrono::steady_clock;
    auto milisegundos = [](Reloj::duration t) {
      return std::chrono::duration<double, std::milli>(t).count();
    };

    // CPU: procesamiento de datos ya disponibles en RAM.
    for (int r = 0; r < repeticiones; ++r) {
      const auto t0 = Reloj::now();
      calcularETA_CPU(distancias.data(), DISTANCIA_CLIENTE_METROS,
                      velocidadMS, etaCPU.data(), static_cast<std::size_t>(n));
      const auto t1 = Reloj::now();
      tiemposCPU.push_back(milisegundos(t1 - t0));
    }

    // GPU kernel: solo computo en la GPU (no cuenta las copias).
    for (int r = 0; r < repeticiones; ++r) {
      CUDA_CHECK(cudaEventRecord(inicio));
      calcularETA_GPU<<<bloques, hilos>>>(dDistancia, DISTANCIA_CLIENTE_METROS,
                                          velocidadMS, dETA, n);
      CUDA_CHECK(cudaGetLastError());
      CUDA_CHECK(cudaEventRecord(fin));
      CUDA_CHECK(cudaEventSynchronize(fin));
      float ms = 0.0f;
      CUDA_CHECK(cudaEventElapsedTime(&ms, inicio, fin));
      tiemposKernel.push_back(static_cast<double>(ms));
    }

    // GPU completa: copia de entrada, lanzamiento y copia de salida.
    // No incluye cudaMalloc/cudaFree. Usamos memoria host pageable.
    for (int r = 0; r < repeticiones; ++r) {
      const auto t0 = Reloj::now();
      CUDA_CHECK(cudaMemcpy(dDistancia, distancias.data(), bytes,
                            cudaMemcpyHostToDevice));
      calcularETA_GPU<<<bloques, hilos>>>(dDistancia, DISTANCIA_CLIENTE_METROS,
                                          velocidadMS, dETA, n);
      CUDA_CHECK(cudaGetLastError());
      CUDA_CHECK(cudaMemcpy(etaGPU.data(), dETA, bytes,
                            cudaMemcpyDeviceToHost));
      CUDA_CHECK(cudaDeviceSynchronize());
      const auto t1 = Reloj::now();
      tiemposTotal.push_back(milisegundos(t1 - t0));
    }

    // Validacion elemento a elemento con tolerancia relativa por redondeo.
    double errorMaximo = 0.0;
    bool coinciden = true;
    for (int i = 0; i < n; ++i) {
      const double error = std::abs(etaCPU[i] - etaGPU[i]);
      errorMaximo = std::max(errorMaximo, error);
      if (!std::isfinite(etaCPU[i]) || !std::isfinite(etaGPU[i]) ||
          error > 1e-11 * std::max(1.0, std::abs(etaCPU[i]))) {
        coinciden = false;
      }
    }
    const double cpuMs = mediana(tiemposCPU);
    const double kernelMs = mediana(tiemposKernel);
    const double totalMs = mediana(tiemposTotal);
    const double speedup = totalMs > 0.0 ? cpuMs / totalMs : 0.0;

    std::cout << "GPU," << prop.name << '\n';
    std::cout << "PRECISION,double (float64)" << '\n';
    std::cout << "VALIDACION," << (coinciden ? "OK" : "ERROR") << '\n';
    std::cout << "N,HILOS,REPETICIONES,CPU_ms,GPU_kernel_ms,GPU_total_ms,SPEEDUP_total,ERROR_MAX" << '\n';
    std::cout << std::fixed << std::setprecision(9)
              << n << ',' << hilos << ',' << repeticiones << ','
              << cpuMs << ',' << kernelMs << ',' << totalMs << ','
              << speedup << ',' << errorMaximo << '\n';

    CUDA_CHECK(cudaEventDestroy(inicio)); inicio = nullptr;
    CUDA_CHECK(cudaEventDestroy(fin)); fin = nullptr;
    CUDA_CHECK(cudaFree(dDistancia)); dDistancia = nullptr;
    CUDA_CHECK(cudaFree(dETA)); dETA = nullptr;
    return coinciden ? 0 : 2;
  } catch (const std::exception& ex) {
    std::cerr << "ERROR: " << ex.what() << '\n';
    if (inicio) cudaEventDestroy(inicio);
    if (fin) cudaEventDestroy(fin);
    if (dDistancia) cudaFree(dDistancia);
    if (dETA) cudaFree(dETA);
    return 1;
  }
}
