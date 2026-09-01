# Guía de Contribución (CONTRIBUTING)

*[Read this in English](CONTRIBUTING.en.md)*

¡Gracias por tu interés en contribuir a este proyecto de **ingeniería inversa,
desensamblado y reconstrucción en ensamblador Z80** de *Mad Mix Game* (Topo
Soft, 1988, ZX Spectrum 48K, versión de cinta)!

El objetivo del repositorio es traducir el binario original del juego
(cinta, `.tzx`) a código fuente Z80 real, identificando y documentando
funciones, variables y bloques de datos, manteniendo siempre una
**reconstrucción 1:1 (byte-matching)** frente al ejecutable original.
Antes de nada, échale un vistazo a `README.md` y `src/README.md` (la
arquitectura y las convenciones del proyecto) y a `FINDINGS.md` (el diario
de hallazgos) para entender cómo se ha trabajado hasta ahora.

---

## 📌 Principios Fundamentales del Proyecto

1. **Fidelidad 1:1 (byte-matching):** cualquier cambio en las instrucciones
   ensamblador o en las tablas de datos debe seguir generando un binario
   idéntico, byte a byte, al original (48485 bytes, 0 diferencias). A día de
   hoy no hay ninguna excepción documentada — esta versión de Spectrum es el
   **original** de 1988, a diferencia del proyecto hermano de MSX (un *port*
   de éste), que sí tuvo que corregir un bug real propio de su plataforma en
   su v2.0 (ver `manuales/manual_niveles.md` §8).
2. **Claridad sobre interpretación:** no se añade código nuevo ni se
   "optimizan" rutinas originales. El objetivo es traducir e interpretar
   exactamente lo que el binario hace, bugs originales incluidos si los hay.
3. **Paso a paso:** mejor etiquetar/documentar un bloque pequeño y verificado
   que enviar un cambio grande sin comprobar contra el binario real.
4. **Nombres descriptivos en español:** la convención ya establecida en todo
   el proyecto (cientos de rondas de renombrado documentadas en
   `FINDINGS.md`) es usar nombres descriptivos **en español**, no inglés ni
   abreviaturas crípticas — por ejemplo `MOTOR_ACTORES`,
   `CONSULTAR_TIPO_LOSETA`, `REGISTRO_NIVEL_POSICION_COMECOCOS`, no
   `ACTOR_ENGINE` ni `lbl_8200`. Las etiquetas puramente internas de una
   rutina (marcas de salto sin entidad propia) usan el mecanismo de
   etiquetas locales de SjASMPlus con punto inicial (`.BUCLE_SEGMENTO`).
5. **Nombres compartidos con el proyecto MSX cuando hay una rutina
   equivalente ya resuelta allí:** buena parte del contenido (al menos el
   logo animado de Topo Soft, verificado sesión 11) es la misma secuencia de
   alto nivel en ambas versiones, aunque el código Z80 concreto sea distinto
   (ULA mapeada en memoria en Spectrum, VRAM de VDP en MSX). Cuando se
   identifica una rutina Spectrum como equivalente de una ya resuelta en el
   proyecto MSX, se le pone **el mismo nombre exacto** — ver "Convenciones"
   en `src/README.md` para el detalle completo y los casos en que
   deliberadamente NO se comparte nombre porque el mecanismo real difiere.

---

## 🛠️ Entorno de Trabajo y Herramientas

- **Ensamblador:** [SjASMPlus](https://github.com/z00m128/sjasmplus) en el
  PATH — es el único ensamblador que usa este proyecto (no `pasmo`, no
  `z80asm`).
- **Python 3** (`py` en Windows) — para las herramientas de `tools/`
  (compilación completa, generación del `.tzx`, sonido, niveles, BASIC
  tokenizado). Sin dependencias externas, solo librería estándar.
- **Un emulador de ZX Spectrum con ROM de 48K** (p. ej.
  [ZEsarUX](https://github.com/chernandezba/zesarux)), opcional pero
  recomendado, para probar el resultado y contrastar hallazgos contra la
  ROM real.
- **Una copia legalmente obtenida del juego original** (`.tzx` de cinta) si
  quieres verificar tú mismo la comparación byte a byte — este repositorio
  **no incluye** el volcado original, ver `AVISO-LEGAL.md`. Sin ella puedes
  seguir contribuyendo (renombrados, comentarios, documentación), pero no
  podrás comprobar el byte-match tú mismo.

---

## 🚀 Flujo de Trabajo para Contribuir

### 1. Preparar el Repositorio

1. Haz un **fork** de este repositorio en GitHub.
2. Clónalo localmente:

   ```bash
   git clone https://github.com/TU_USUARIO/SPECTRUM_MadMixGame.git
   cd SPECTRUM_MadMixGame
   ```

3. Crea una rama descriptiva:

   ```bash
   git checkout -b etiquetar-motor-colision
   # o bien: git checkout -b fix-comentario-scroll
   ```

### 2. Compilar y Verificar

```bash
# Compila TODO el proyecto de un tirón (motor, portada, loader de cinta)
py tools/build_all.py

# Genera el entregable final (.tzx) desde cero y lo verifica automáticamente
# byte a byte contra FISICO/Mad Mix Game.tzx
py tools/gen_tzx_file.py
```

Esto deja los binarios en `src/build/` y el `.tzx` reconstruido en
`build/madmix_reconstruido.tzx`. El propio script `gen_tzx_file.py` imprime
el resultado de la comparación byte a byte — debe decir **"0 diferencias,
48485 bytes idénticos"**.

Si tu cambio es solo renombrado/comentarios, el resultado debe ser
**exactamente el mismo** que antes de tu cambio (0 diferencias). Si tu
cambio introduce una divergencia real, no es un cambio válido para este
proyecto — la reconstrucción debe seguir siendo byte a byte fiel al
original.

### 3. Documentar el hallazgo

Si identificas o corriges algo (una etiqueta, un bloque de datos, un
comportamiento), añade una entrada en `FINDINGS.md` siguiendo el estilo ya
usado — un encabezado `##`/`###` describiendo qué se creía antes, qué se
descubrió y cómo se verificó. Es el diario cronológico del proyecto; no se
reescribe el historial, se añade encima.

---

## 📬 Envío de Pull Requests

1. Haz commit de tus cambios con mensajes descriptivos:

   ```bash
   git commit -m "Renombra MOTOR_MOVIMIENTO_ITEM y documenta su hallazgo en FINDINGS.md"
   ```

2. Sube tu rama:

   ```bash
   git push origin etiquetar-motor-colision
   ```
3. Abre una **Pull Request** contra la rama `main` de este repositorio.
4. En la descripción de la PR, indica los rangos de memoria/etiquetas
   modificados, el resultado de la verificación byte a byte (§2), y los
   ficheros afectados.

---

## 🐛 Reporte de Errores e Inconsistencias

Si encuentras una sección mal interpretada, datos leídos como código, o una
etiqueta que ya no describe lo que hace su rutina, pero no vas a corregirlo
tú mismo:

1. Comprueba que no exista ya un Issue abierto sobre lo mismo.
2. Abre un nuevo Issue describiendo el problema.
3. Incluye la dirección de memoria real y la justificación técnica —si puedes
   verificarlo en vivo con un emulador o comparando contra el binario
   original, mejor.

---

¡Gracias por colaborar en la preservación e ingeniería inversa de este trozo
de la historia del software español!
