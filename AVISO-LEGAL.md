# Aviso legal y de atribución

*Ingeniería inversa, análisis y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)*

## De quién es cada cosa

**El juego no es nuestro.** *Mad Mix Game* lo publicó **Topo Soft** para
ZX Spectrum en 1988 (el propio bloque de información de archivo del `.tzx`
original registra "D.L. M-19452-1988"). La versión de MSX del mismo juego
(ver el proyecto hermano en `MSX/proyectos/madmixgame`) acredita en su
pantalla de créditos a **"RAPHAEL GOMEZZZ"** (programación), **"ROBERTO
P.ACEBES"** (gráficos) y **"COMILONAS"** (música) — pseudónimos o grafías
de la época; no se ha confirmado la identidad civil real de ninguno de los
tres. Es razonable esperar los mismos nombres en la pantalla de créditos de
esta versión de Spectrum, pero **no se da por hecho hasta verificarlo en
este binario concreto** (pendiente: la pantalla de créditos vive dentro de
`CODE.bin`, aún sin desensamblar). La propiedad intelectual del juego
original — código, gráficos, sonido y diseño — sigue siendo de Topo Soft,
de las personas detrás de esos créditos, o de quien haya heredado esos
derechos a día de hoy.

**Lo que sí es nuestro** son las herramientas de este repositorio, los
comentarios del código fuente reconstruido, el análisis y la documentación
(`FINDINGS.md`, `README.md` y los recursos HTML que los acompañen). Eso se
publica bajo la licencia que conste en `LICENSE`.

## Qué contiene este repositorio

Este proyecto **no tenía acceso al código fuente original** de *Mad Mix
Game* — no se conserva, o al menos no ha llegado a este trabajo. Lo que hay
en `src/` es una **reconstrucción por ingeniería inversa**: desensamblado
byte a byte del binario original de cinta (`.tzx`), reescrito como fuente
ensamblador (`SjASMPlus`) legible, con etiquetas descriptivas y comentarios
que explican qué hace cada rutina y por qué — y, cuando es posible,
**verificado recompilando y comparando el resultado byte a byte contra el
binario original** (misma disciplina que el proyecto hermano de MSX). Se
acompaña de las herramientas (`tools/`) que permiten recompilar esa fuente
y regenerar el `.tzx`.

Este repositorio **no incluye** el volcado original de la cinta (`.tzx`)
tal como se extrajo del soporte físico, ni herramientas de terceros usadas
durante el análisis (desensambladores, ensambladores). Lo que se distribuye
es la fuente reconstruida, los datos del juego ya identificados y
documentados, y las herramientas propias para generarlos — no una copia del
producto original.

## Si eres uno de los autores, Topo Soft, o su sucesor en derechos

Si trabajaste en *Mad Mix Game*, eres alguna de las personas acreditadas en
su pantalla de créditos, o representas a Topo Soft o a quien haya heredado
sus derechos, y prefieres que este material no esté publicado, **dilo y se
retira sin discusión**. Cualquier requerimiento legal, de quien
corresponda, será atendido. La intención de este trabajo es la contraria a
perjudicar: es dejar constancia de cómo estaba hecho un juego que forma
parte de la historia del software español, con fines educativos y de
preservación de ese legado, antes de que se pierda del todo.

## Sobre los créditos

Cuando se localice la pantalla de créditos dentro de `CODE.bin`, los
nombres se transcribirán tal cual aparezcan en el binario del juego,
incluyendo posibles erratas originales — no de fuentes externas. No se
afirmará ninguna identidad civil real detrás de esos pseudónimos.
