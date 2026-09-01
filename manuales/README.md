# Manuales

*[Read this in English](README.en.md)*

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

Esta carpeta es distinta de `FINDINGS.md` (diario cronológico de
hallazgos) y de `recursos/flujo_programa.html` (inventario por flujo de
ejecución). Ahí se documenta **cómo se descubrió** cada cosa, en el
orden en que se investigó, con toda la incertidumbre y los callejones
sin salida por el camino.

Aquí, en cambio, se documenta **cómo funciona** cada subsistema ya
entendido, de forma ordenada y pedagógica — como si fuera el manual
técnico que un programador de la época le habría dejado a un
compañero nuevo. Dos objetivos concretos:

1. **Formación**: que un programador que se incorpore al proyecto (o a
   cualquier ingeniería inversa parecida) pueda aprender el
   funcionamiento real de cada pieza sin tener que reconstruir el
   proceso de investigación completo.
2. **Preservación**: dejar constancia clara y legible de cómo está
   construida esta pieza de arqueología del software de 8 bits, más
   allá del propio código fuente reconstruido.

Cada manual asume que quien lo lee sabe ensamblador Z80 y programación
en general, pero **no** da por hecho nada específico de este proyecto
ni del hardware del ZX Spectrum — eso se explica desde cero la primera
vez que hace falta.

Estos 4 manuales son el equivalente directo de los ya existentes en el
proyecto hermano de MSX (`../../MSX/proyectos/madmixgame/manuales/`),
adaptados a las diferencias reales de plataforma — la más señalada es
que el Spectrum no tiene ningún chip de sonido dedicado ni ningún
sprite hardware, así que ambos subsistemas se resuelven aquí por
software puro sobre el altavoz y la ULA.

## Índice

- [`manual_driver_sonido.md`](manual_driver_sonido.md) — el driver de
  sonido por altavoz (`src/madmix_body.asm`, región
  `$DBE0`-`$EFB5`): los tres subsistemas de audio (motor de música
  bloqueante de 2 canales, efectos de sonido cortos no bloqueantes, y
  los guiones de demo que NO son sonido pese a parecerlo), el lenguaje
  de bytecode de 6 comandos, el mecanismo de disparo de efectos
  (`EVENTO_SONIDO_PENDIENTE`), y las herramientas para editar y
  escuchar los sonidos.
- [`manual_motor_colision_ia.md`](manual_motor_colision_ia.md) — el
  motor de movimiento/colisión (`src/madmix_body.asm`), la tabla de
  despacho de 20 tipos de loseta, y la IA de los enemigos/ítems móviles:
  cómo deciden dirección, qué hace cada uno al llegar a su sitio, y los
  modos especiales que dispara pisarlos.
- [`manual_subsistema_grafico.md`](manual_subsistema_grafico.md) — la
  ULA en su modo de pantalla estándar, por qué el motor de actores no
  tiene NINGÚN sprite hardware que usar (a diferencia del VDP del MSX,
  que sí lo tiene pero se ignora): compone cada personaje a mano con
  máscaras AND/OR y desplazamiento sub-pixel. También el lienzo de
  trabajo en RAM del laberinto, el scroll por software (4px,
  `RLD`/`RRD`), y el mecanismo — el más particular de todo el
  proyecto — que vuelca ese lienzo a la pantalla real cada fotograma
  con una danza de `PUSH`/`POP` y `SP` redirigido.
- [`manual_niveles.md`](manual_niveles.md) — el formato de los 15
  niveles: el registro de 20 bytes, la tabla de 16 entradas (el
  registro 0 es un duplicado muerto), los 15 cuerpos + 3 cabeceras
  compartidas, el comodín `$3C`, cómo se detecta el fin de nivel, el
  modo demo del menú, la herramienta `mmlvl_tool.py` para editarlos, y
  un caso concreto de herencia de dirección compartida con el port de
  MSX.

*(Se irán añadiendo más manuales aquí a medida que se decida qué otras
partes del sistema documentar de esta forma.)*
