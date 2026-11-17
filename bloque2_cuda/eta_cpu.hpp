#pragma once

#include <cstddef>
#include <stdexcept>

// Variante CPU (secuencial). Recibe distancias de rutas ya calculadas
// por el algoritmo de caminos minimos del proyecto original.
inline void calcularETA_CPU(const double* distanciaAlRestauranteMetros,
                            double distanciaAlClienteMetros,
                            double velocidadMetrosPorSegundo,
                            double* etaSegundos,
                            std::size_t cantidad) {
  if (velocidadMetrosPorSegundo <= 0.0) {
    throw std::invalid_argument("La velocidad debe ser positiva");
  }
  for (std::size_t i = 0; i < cantidad; ++i) {
    etaSegundos[i] = (distanciaAlRestauranteMetros[i] +
                      distanciaAlClienteMetros) / velocidadMetrosPorSegundo;
  }
}
