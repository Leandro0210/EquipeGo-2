# EquipeGo 2 · Bloque 2 CUDA

Laboratorio **independiente** del simulador del Bloque 1. Primera función: ETA en lote CPU vs GPU.

## 1. ¿Qué hace y de dónde sale?

En `src/dispatch/Dispatcher.cpp` del proyecto original se calcula:

`ETA = (distancia courier->restaurante + distancia restaurante->cliente) / (velocidadKmH / 3.6)`

La implementación del Bloque 1 obtiene las distancias con `RoadNetwork::shortestRoute` (Dijkstra), usando un caché para un tramo. **Este piloto NO reemplaza Dijkstra**: recibe distancias de ruta precomputadas, un tramo común al cliente y la velocidad; reproduce únicamente la operación aritmética por candidato. Los valores iniciales son **sintéticos y deterministas** para comprobar el entorno; posteriormente podremos exportar instantáneas reales de EquipeGo.

## 2. ¿Por qué se prueba en GPU?

Cada ETA se calcula de forma independiente, lo que permite asignar un hilo CUDA a cada candidato. Es una primera demostración de indexación global, grillas, bloques, límite `i < N` y transferencia de memoria. La GPU **no tiene garantizado ser más rápida**: poca aritmética por dato, lanzamientos y transferencias pueden hacer que la CPU gane, especialmente con N pequeños. El piloto usa `double`, como el cálculo del proyecto original; en GPUs como la T4, el rendimiento de FP64 puede ser inferior al de FP32.

## 3. ¿Cómo ejecutarlo en Google Colab?

En Colab: **Entorno de ejecución -> Cambiar tipo de entorno -> GPU**. Después, abrir `EquipeGo_Bloque2.ipynb` y ejecutar las celdas de arriba hacia abajo. El notebook clona el **nuevo repositorio independiente** `Leandro0210/EquipeGo-2`, compila con `nvcc` y hace las comparaciones.

Manual, una vez clonado el repo:

```bash
cd EquipeGo-2/bloque2_cuda
nvcc -O3 -std=c++17 01_eta_cpu_gpu.cu -o eta_benchmark
./eta_benchmark 1000 256 15
./eta_benchmark 100000 256 15
./eta_benchmark 1000000 256 15
```

Salida: nombre de GPU, precisión, validación, N, hilos, repeticiones, mediana de CPU, mediana del kernel GPU, mediana del total GPU, speedup total y error máximo. **No hay tiempos predeterminados ni medidos de antemano.**

Prueba básica de la implementación CPU (también funciona sin GPU):

```bash
g++ -O3 -std=c++17 tests/test_eta_cpu.cpp -o /tmp/test_eta_cpu
/tmp/test_eta_cpu
```

## 4. Metodología para justificar el rendimiento

- Entrada y resultado: mismos datos, misma expresión y precisión `double` para CPU y GPU; validar todas las salidas.
- Configuración: registrar CPU y GPU asignadas por Colab, versión de nvcc, N, hilos, compilación y repeticiones.
- Separar GPU-kernel de GPU-total. `GPU_total` incluye las transferencias H2D y D2H y la ejecución, pero **no incluye asignación/liberación de memoria GPU**.
- Medición: calentamiento previo, 15 repeticiones y mediana; CPU y GPU dentro de la **misma sesión Colab**. Para un estudio riguroso, repetir en distintos órdenes y vigilar la variabilidad del servicio compartido.
- Speedup total = CPU_ms / GPU_total_ms; >1 GPU mejor, <1 CPU mejor.
- Alcance: este es un **piloto de infraestructura** y la primera operación candidata; la cuenta de funciones nuevas debe acordarse con JJ. No presentar el piloto como aceleración del simulador completo.

## 5. Ficheros

- `eta_cpu.hpp`: versión CPU reutilizable y comprobable sin GPU.
- `01_eta_cpu_gpu.cu`: kernel CUDA, generación reproducible, mediciones, comparación y errores.
- `tests/test_eta_cpu.cpp`: prueba de referencia CPU.
- `EquipeGo_Bloque2.ipynb`: notebook en Google Colab.

## 6. Qué debemos justificar por función

1. Problema de EquipeGo que resuelve y referencia al código o dato de origen.
2. Por qué ese cómputo es paralelo; patrón del tema del curso.
3. Misma semántica y validación de resultados.
4. Tamaño mínimo y escala de los experimentos.
5. CPU vs GPU-kernel vs GPU-total, incluyendo casos donde no conviene GPU.
6. Limitaciones y plan de posible integración sin modificar el Bloque 1.
