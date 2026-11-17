#include "../eta_cpu.hpp"

#include <cassert>
#include <cmath>
#include <iostream>
#include <stdexcept>

int main() {
  const double distanciaRestaurante[] = {0.0, 100.0, 500.0, 900.0};
  double eta[4] = {};
  calcularETA_CPU(distanciaRestaurante, 100.0, 10.0, eta, 4);
  assert(std::abs(eta[0] - 10.0) < 1e-12);
  assert(std::abs(eta[1] - 20.0) < 1e-12);
  assert(std::abs(eta[2] - 60.0) < 1e-12);
  assert(std::abs(eta[3] - 100.0) < 1e-12);
  bool rechazoVelocidadCero = false;
  try {
    calcularETA_CPU(distanciaRestaurante, 100.0, 0.0, eta, 4);
  } catch (const std::invalid_argument&) {
    rechazoVelocidadCero = true;
  }
  assert(rechazoVelocidadCero);
  std::cout << "Prueba de referencia CPU: OK (4 casos y velocidad invalida)\n";
  return 0;
}
