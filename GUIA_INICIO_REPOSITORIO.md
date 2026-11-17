# Crear EquipeGo-2 sin alterar el EquipeGo original

## Paso 1: crear el repo vacío en GitHub

Iniciar sesión en GitHub; elegir **New repository**. Nombre: `EquipeGo-2`. Propietario: `Leandro0210`. Recomendación para este trabajo: público (Colab podrá clonarlo sin token), o privado si el docente lo exige. **No marcar** las opciones de agregar README, `.gitignore` o licencia; debe empezar vacío.

## Paso 2: clonar la rama que contiene Variante C (WSL Ubuntu)

```bash
cd ~
git clone --single-branch --branch feat/variante-c-descansos https://github.com/Leandro0210/EquipeGo.git EquipeGo-2
cd EquipeGo-2
# Guardar el remoto del Bloque 1 con un nombre distinto, evitando pushes accidentales.
git remote rename origin upstream
git switch -c main
git remote add origin https://github.com/Leandro0210/EquipeGo-2.git
git remote -v
git status --short
# Revisar: origin debe apuntar a EquipeGo-2, upstream a EquipeGo.
git push -u origin main
```

Conservamos el historial de la rama e incorporamos la Variante C como punto de partida de `main` en el repo nuevo. No se realiza ninguna escritura en EquipeGo original. Al publicar, verificar que `https://github.com/Leandro0210/EquipeGo-2` muestre la rama `main`.

## Paso 3: agregar el piloto

Descomprimir `EquipeGo-2_starter.zip` **dentro** de la carpeta local `EquipeGo-2` (sin crear una segunda carpeta `EquipeGo-2` intermedia). Debe aparecer `EquipeGo-2/bloque2_cuda/01_eta_cpu_gpu.cu`.

```bash
cd ~/EquipeGo-2
git add bloque2_cuda GUIA_INICIO_REPOSITORIO.md
git commit -m "feat(cuda): iniciar bloque 2 con benchmark ETA CPU vs GPU"
git push origin main
```

Si la guía no está en el directorio, agregar solo `bloque2_cuda` al commit. Revisar el resultado de `git status` antes de publicar; nunca subir `build/`, ejecutables, resultados temporales, logs o credenciales.

## Paso 4: ejecutar el notebook en Colab

Abrir en GitHub `bloque2_cuda/EquipeGo_Bloque2.ipynb` y usar **Open in Colab** o acceder desde `colab.research.google.com` > GitHub. Activar runtime GPU y ejecutar las celdas. Después revisar `VALIDACION,OK` y los tiempos generados. Si el repo es privado, habrá que configurar acceso seguro en Colab; nunca pegar tokens en notebooks ni commits.

## Notas

- No usar 'Fork': un fork queda vinculado a la red de repositorios del original; para trabajos de bloques separados, una copia independiente permite experimentar con más libertad.
- La copia incluye fuentes e historial del Bloque 1. Si hubiera archivos grandes de evidencias previamente versionados, también se copiarán; más adelante podremos limpiar **solo el nuevo** repositorio con cuidado, sin reescribir historia sin necesidad.
- No se ha comprobado el kernel GPU en una NVIDIA real en el entorno donde se preparó este kit; sus mediciones deben hacerse en Google Colab.
