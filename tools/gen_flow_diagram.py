#!/usr/bin/env python3
"""
gen_flow_diagram.py -- genera recursos/flujo_detallado.html: un grafo
de llamadas Mermaid.js con TODAS las funciones reales (etiquetas
clasificadas "funcion" por gen_inventory.py, es decir destino de al
menos un CALL), coloreadas por subsistema, con aristas = llamadas
reales (CALL) entre ellas.

Adaptado del script homonimo del proyecto hermano de MSX -- misma
logica de parseo/clasificacion/render, mismo criterio de alcance
(solo nodos "funcion"), CATEGORY propia para las 82 funciones de este
proyecto.

Reutiliza el parseo/clasificacion de gen_inventory.py sobre el mismo
listado (src/build/main.lst) para no duplicar esa logica ni
desincronizarse de sus resultados.

Alcance deliberado (mismo criterio que MSX): SOLO nodos "funcion"
(destino real de CALL). Los manejadores de tipo de loseta
(HNDLR_SUELO_NORMAL, HNDLR_BOLITA_NORMAL, etc.) y otros puntos
alcanzados solo por tabla de salto/JP indirecto (clasificados
"interna") NO aparecen como nodos en este grafo -- ver
recursos/flujo_programa.html §3 para esos.

Uso:
  py tools/build_all.py        (generar src/build/main.lst primero)
  py tools/gen_flow_diagram.py

Autor de esta herramienta: Rafael Eduardo Martín Candial (raemca@hotmail.com)
"""
import os
import re
import sys
import json

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import gen_inventory as gi  # reusa parse_listing/classify

HTML_PATH = os.path.join(ROOT, "recursos", "flujo_detallado.html")

CALL_COND_RE = re.compile(r"\bCALL\b(?:\s+([A-Z]+),)?\s+([A-Za-z_][A-Za-z0-9_]*)\b")

# --- categorizacion manual (mas fiable que un heuristico de nombre a
# esta escala -- 82 nodos es poco para mantener a mano, y evita
# clasificaciones raras). Cualquier "funcion" nueva que no aparezca
# aqui cae en "otros" y se avisa por stdout al generar. ---
CATEGORY = {
    # --- arranque / carga (boot) -- incluye el logo animado de
    # portada_body.asm (fichero cerrado, analisis semantico completo,
    # es la fase de "portada" del arranque, sesiones 4-20) ---
    "ACTIVAR_INTERRUPCION_MODO_2": "boot", "LEER_BLOQUE_CINTA": "boot",
    "ANIMAR_PUNTO_LUZ_SOFT": "boot", "DIBUJAR_FORMA_ANIMADA": "boot",
    "RESTAURAR_FRANJA_FONDO": "boot", "DIBUJAR_SOFT_ROTANDO": "boot",
    "DIBUJAR_T_TOPO": "boot", "DIBUJAR_P_TOPO_ANIMADA": "boot",
    "DIBUJAR_O1_TOPO": "boot", "DIBUJAR_O2_TOPO_ANIMADA": "boot",
    "DIBUJAR_ESTRELLA_ANIMADA": "boot", "LIMPIAR_TABLA_COLOR_VRAM": "boot",
    "RELLENAR_COLOR_TOPO": "boot", "ANIMAR_COLOR_TOPO": "boot",
    "PAUSA_ENTRE_LETRAS": "boot", "DIBUJAR_FORMA_TEMPORIZADA": "boot",
    "GUARDAR_PANTALLA_LOGO": "boot", "RESTAURAR_FRANJA_FILA": "boot",

    # --- motor de juego (actores, colision, camara, nivel) ---
    "ENLACE_MOTOR_MOVIMIENTO_COLISION": "motor",
    "CONSULTAR_PROXIMA_LOSETA_EN_ESTA_DIRECCION": "motor",
    "CONSULTAR_LOSETA_LIBRE_DIRECCION": "motor",
    "MAPEAR_COORDENADA_A_DIRECCION": "motor", "GENERAR_ALEATORIO": "motor",
    "CARGAR_NIVEL": "motor", "MOTOR_ACTORES": "motor",
    "VOLTEAR_PATRON_HORIZONTAL": "motor", "CALCULAR_LIMITE_INTERCAMBIO": "motor",
    "DIBUJAR_ACTORES_PENDIENTES": "motor", "TICK_REDIBUJADO_VBLANK": "motor",
    "MAPEAR_LOSETA_RELATIVA_A_ABSOLUTA": "motor", "CONSULTAR_TIPO_LOSETA": "motor",
    "ACTUALIZAR_PARPADEO_BOLA": "motor",

    # --- items especiales (pelmazoide/maricoco/regpunantoso, destellos, pistas) ---
    "REGISTRAR_PISTA_TANQUE_AVION": "items", "MOTOR_MOVIMIENTO_ITEM": "items",
    "CALCULAR_POSICION_VRAM_ITEM": "items",
    "MAPEAR_COORDENADA_A_DIRECCION_LOCAL": "items",
    "AVISAR_PROXIMIDAD_PISTA": "items", "ARMAR_AVISO_DESTELLO": "items",
    "ACTUALIZAR_DESTELLO_ITEMS": "items", "ACTIVAR_EFECTO_ITEM": "items",
    "INICIALIZAR_ITEMS_NIVEL": "items", "INICIALIZAR_PARCIAL_ITEMS_NIVEL": "items",

    # --- HUD / entrada (teclado, joystick, marcador de puntos) ---
    "ESPERAR_TECLA_SOLTADA": "hud", "PREPARAR_TABLA_ESQUEMA_COLOR": "hud",
    "ESCRIBIR_COLOR_ACTUAL_X2": "hud", "REFRESCAR_ESQUEMA_COLOR_NIVEL": "hud",
    "DIBUJAR_MARCADOR_PUNTOS": "hud", "CONVERTIR_PUNTUACION_A_TEXTO": "hud",
    "ESCRIBIR_DIGITO_PUNTUACION": "hud", "LEER_ENTRADA": "hud",
    "ESCANEAR_TABLA_TECLAS": "hud", "ESCANEAR_FILAS_TECLADO": "hud",
    "COMPROBAR_TECLA": "hud", "DESTELLO_ICONO_COLOR_HUD": "hud",

    # --- menu / creditos / redefinicion de teclas / demo ---
    "LEER_TECLA_MENU": "menu", "LIMPIAR_PANTALLA_MENU": "menu",
    "DIBUJAR_TEXTOS_MENU": "menu", "LEER_TECLADO_MENU": "menu",
    "FINALIZAR_MENU_CONTROLES": "menu", "REDEFINIR_TECLAS": "menu",
    "INICIAR_REDEFINICION_TECLAS": "menu", "ESPERAR_TECLA_NUEVA": "menu",
    "DIBUJAR_CREDITOS": "menu", "INICIAR_DEMO": "menu",

    # --- sonido (motor de musica/percusion por interrupcion + efectos) ---
    "DESPACHAR_EFECTO_SONIDO": "sonido", "INICIAR_TONO_EFECTO_SONIDO": "sonido",
    "REPRODUCIR_SONIDO": "sonido", "COPIAR_PATRON_TONO": "sonido",

    # --- graficos / gestion VRAM ---
    "DIBUJAR_CAMBIO_LOSETA": "graficos", "ESCRIBIR_PATRON_VRAM": "graficos",
    "DIBUJAR_TEXTO_VRAM": "graficos", "CARGAR_MARCO_DECORATIVO": "graficos",
    "APLICAR_ATRIBUTOS_MARCO_COMPLETO": "graficos",
    "APLICAR_ATRIBUTOS_MARCO_PARCIAL": "graficos",
    "CALCULAR_DIRECCION_PANTALLA": "graficos", "WAIT_VBLANK": "graficos",
    "GESTIONAR_SCROLL": "graficos", "BUCLE_REDIBUJAR_FILA_VERTICAL": "graficos",
    "MAPEAR_LOSETA_A_GRAFICO": "graficos",
    "REDIBUJAR_PANTALLA_COMPLETA_BUFFER_VRAM": "graficos",
    "REDIBUJAR_LOSETA_BUFFER_VRAM": "graficos", "DIBUJAR_CADENA_VRAM": "graficos",
}

CATEGORY_LABEL = {
    "boot": "Arranque / portada",
    "motor": "Motor de juego",
    "items": "Items especiales",
    "hud": "HUD / entrada",
    "menu": "Menu / creditos / demo",
    "sonido": "Sonido",
    "graficos": "Graficos / VRAM",
    "otros": "Sin clasificar",
}

# mismos colores que recursos/flujo_programa.html (--c-boot etc), mas
# --c-graficos nuevo (no usado alli, solo en este grafo mas fino)
COLOR_LIGHT = {
    "boot": "#d69a3a", "motor": "#6a86ae", "items": "#8a6ab0",
    "hud": "#7fae6a", "menu": "#4aa89a", "sonido": "#c46a6a",
    "graficos": "#3aa8c4", "otros": "#cbc3b6",
}
COLOR_DARK = {
    "boot": "#e6b25a", "motor": "#7f9bc4", "items": "#a17fd0",
    "hud": "#8fc27a", "menu": "#5ec2b2", "sonido": "#d68a8a",
    "graficos": "#4ac2d6", "otros": "#4a453c",
}


def lexical_owners(labels, source_lines):
    """Para cada (file, linea) determina cual es la etiqueta GLOBAL
    mas reciente en ese fichero (de cualquier tipo: funcion/interna/
    dato/sinref) -- el limite lexico real de "a que rutina pertenece
    este codigo", no solo las etiquetas 'funcion'. Asi un CALL dentro
    de una rutina que solo se alcanza por JR/JP (nunca CALL) no se le
    atribuye por error a la 'funcion' anterior mas cercana en el
    fichero -- se le atribuye a su propia etiqueta real (que luego
    build_edges descarta si esa etiqueta no es 'funcion', en vez de
    inventar una arista falsa)."""
    starts_by_file = {}
    for name, (addr, file_, line) in labels.items():
        starts_by_file.setdefault(file_, []).append((line, name))
    for file_ in starts_by_file:
        starts_by_file[file_].sort()

    owner = {}
    cur_owner_by_file = {}
    for file_, line, addr, text in source_lines:
        starts = starts_by_file.get(file_, [])
        idx = cur_owner_by_file.get(file_, 0)
        while idx < len(starts) and starts[idx][0] <= line:
            cur_owner_by_file[file_] = idx + 1
            idx += 1
        if idx > 0:
            owner[(file_, line)] = starts[idx - 1][1]
    return owner


def build_edges(labels, source_lines, types, funcion_set):
    owner = lexical_owners(labels, source_lines)

    edges = {}  # (caller, callee) -> set(conditions) ("" = incondicional)
    dropped = 0
    for file_, line, addr, text in source_lines:
        caller = owner.get((file_, line))
        if not caller or types.get(caller) != "funcion":
            # el CALL esta dentro de una rutina que en si misma no es
            # 'funcion' (solo alcanzada por JR/JP) -- no hay nodo
            # fiable al que atribuirselo, se descarta en vez de
            # inventar una arista falsa con el 'funcion' anterior.
            for m in CALL_COND_RE.finditer(text):
                if m.group(2) in funcion_set:
                    dropped += 1
            continue
        for m in CALL_COND_RE.finditer(text):
            cond, target = m.group(1) or "", m.group(2)
            if target in funcion_set and target != caller:
                edges.setdefault((caller, target), set()).add(cond)
    if dropped:
        print(f"AVISO: {dropped} CALL(s) a nodos 'funcion' descartados por "
              f"estar dentro de una rutina no-funcion (solo JR/JP) -- no "
              f"se les puede atribuir un nodo origen fiable.")
    return edges, dropped


def mermaid_id(name):
    return "N_" + name


def build_mermaid(labels, funcion_set, edges):
    by_cat = {}
    for name in funcion_set:
        cat = CATEGORY.get(name, "otros")
        by_cat.setdefault(cat, []).append(name)
    for cat in by_cat:
        by_cat[cat].sort(key=lambda n: labels[n][0])

    lines = ["flowchart TD"]
    cat_order = ["boot", "menu", "motor", "items", "hud", "graficos", "sonido", "otros"]
    for cat in cat_order:
        names = by_cat.get(cat, [])
        if not names:
            continue
        lines.append(f'  subgraph SG_{cat}["{CATEGORY_LABEL[cat]}"]')
        for name in names:
            addr = labels[name][0]
            safe = name.replace('"', "'")
            lines.append(f'    {mermaid_id(name)}["{safe}<br/>${addr}"]')
        lines.append("  end")

    for (caller, callee), conds in sorted(edges.items()):
        a, b = mermaid_id(caller), mermaid_id(callee)
        conds_clean = sorted(c for c in conds if c)
        unconditional = "" in conds
        if unconditional or not conds_clean:
            lines.append(f"  {a} --> {b}")
        else:
            label = "/".join(conds_clean)
            lines.append(f"  {a} -.->|{label}| {b}")

    for cat in cat_order:
        names = by_cat.get(cat, [])
        if not names:
            continue
        ids = ",".join(mermaid_id(n) for n in names)
        lines.append(f"  class {ids} cat_{cat};")

    return "\n".join(lines), by_cat


HTML_TEMPLATE = """<!doctype html>
<!-- Ingeniería inversa, herramientas y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com) -->
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mad Mix Game (Spectrum) — flujo detallado de llamadas</title>
<style>
  :root {{
    --bg: #faf7f0; --fg: #2a2620; --muted: #6b6458; --border: #ddd4c4;
    --panel: #ffffff;
{light_vars}
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #1b1812; --fg: #ece6d8; --muted: #a89e8c; --border: #3a352b;
      --panel: #242019;
{dark_vars}
    }}
  }}
  :root[data-theme="dark"] {{
    --bg: #1b1812; --fg: #ece6d8; --muted: #a89e8c; --border: #3a352b;
    --panel: #242019;
{dark_vars}
  }}
  :root[data-theme="light"] {{
    --bg: #faf7f0; --fg: #2a2620; --muted: #6b6458; --border: #ddd4c4;
    --panel: #ffffff;
{light_vars}
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; padding: 1.5rem; background: var(--bg); color: var(--fg);
    font-family: -apple-system, "Segoe UI", Roboto, sans-serif; line-height: 1.5;
  }}
  h1 {{ font-size: 1.4rem; margin: 0 0 0.3rem 0; }}
  .subtitle {{ color: var(--muted); font-size: 0.92rem; margin: 0 0 1rem 0; }}
  .note {{
    background: var(--panel); border: 1px solid var(--border); border-radius: 8px;
    padding: 0.8rem 1rem; font-size: 0.88rem; color: var(--muted); margin-bottom: 1rem;
  }}
  .note b {{ color: var(--fg); }}
  .legend {{
    display: flex; flex-wrap: wrap; gap: 0.9rem; margin-bottom: 1rem;
    font-size: 0.85rem;
  }}
  .legend label {{ display: flex; align-items: center; gap: 0.35rem; cursor: pointer; user-select: none; }}
  .swatch {{ width: 0.85rem; height: 0.85rem; border-radius: 3px; display: inline-block; flex: none; }}
  .controls {{ display: flex; gap: 0.6rem; margin-bottom: 1rem; flex-wrap: wrap; }}
  button {{
    background: var(--panel); color: var(--fg); border: 1px solid var(--border);
    border-radius: 6px; padding: 0.4rem 0.8rem; font-size: 0.85rem; cursor: pointer;
  }}
  button:hover {{ border-color: var(--muted); }}
  #diagramWrap {{
    background: var(--panel); border: 1px solid var(--border); border-radius: 10px;
    padding: 1rem; overflow: auto; max-height: 82vh;
  }}
  #diagram {{ transform-origin: 0 0; }}
  #diagram .node, #diagram .cluster {{ cursor: pointer; }}
  .edgeLabel {{ background: var(--panel) !important; }}
  #boxTooltip {{
    position: fixed; z-index: 1000; display: none; pointer-events: none;
    max-width: 22rem; background: var(--fg); color: var(--bg);
    border-radius: 8px; padding: 0.6rem 0.85rem; font-size: 0.95rem;
    line-height: 1.35; white-space: pre-line; box-shadow: 0 6px 20px rgba(0,0,0,0.35);
  }}
</style>
</head>
<body>
<h1>Mad Mix Game (ZX Spectrum) — flujo detallado de llamadas (grafo real)</h1>
<p class="attribution-line" style="color:var(--muted);font-size:0.85rem;margin:-0.3rem 0 1.2rem 0;">Ingeniería inversa, herramientas y documentación: Rafael Eduardo Martín Candial (raemca@hotmail.com)</p>
<p class="subtitle">Compañero de <code>flujo_programa.html</code> (inventario + diagrama a mano). Generado automáticamente por <code>tools/gen_flow_diagram.py</code> a partir del grafo de llamadas real (<code>src/build/main.lst</code>).</p>

<div class="note">
  <b>Alcance:</b> solo se representan las {n_func} etiquetas clasificadas
  <b>"función"</b> (destino de al menos un <code>CALL</code> en algún sitio del código
  fuente transcrito) — el mismo conjunto que la categoría "función" del inventario de
  <code>flujo_programa.html</code>. Las aristas son llamadas <code>CALL</code> reales entre
  esas funciones ({n_edges} aristas); una arista punteada con etiqueta (p.ej. <code>C</code>,
  <code>NZ</code>) es una llamada condicional (<code>CALL cc,destino</code>) — el texto es
  el código de condición del Z80, no una descripción semántica de la condición real.
  <br><br>
  <b>Lo que NO aparece aquí:</b> los manejadores de tipo de loseta
  (<code>HNDLR_SUELO_NORMAL</code>, <code>HNDLR_BOLITA_NORMAL</code>, etc., alcanzados vía
  <code>JP (IX)</code> desde <code>TABLA_MANEJADORES_LOSETA</code>, no vía <code>CALL</code> —
  ver <code>flujo_programa.html</code> §3) ni el resto de puntos "interna" (destino solo de
  <code>JP</code>/<code>JR</code>, sin <code>CALL</code>) — son un conjunto bastante más
  grande y una pieza central real del flujo del juego que este grafo, centrado en llamadas,
  no captura.
  <br><br>
  <b>Aristas descartadas:</b> {n_dropped} llamadas <code>CALL</code> a nodos "función" NO
  se representan porque ocurren dentro de una rutina que en sí misma NO es "función" (solo
  se alcanza por <code>JR</code>/<code>JP</code>) — no hay un nodo de origen fiable al que
  atribuírselas sin inventar una relación falsa, así que se omiten en vez de colgarlas de la
  "función" más cercana en el fichero fuente.
  <br><br>
  <b>El diagrama es grande:</b> carga con zoom ajustado automáticamente a la ventana. Usa
  "Ajustar al ancho" para que solo haga falta scroll vertical. Pasa el ratón por encima de
  cualquier caja para ver su contenido completo en un panel junto al cursor; haz clic para
  fijarlo (útil en pantallas táctiles), y clic fuera para cerrarlo.
</div>

<div class="legend" id="legend">
{legend_items}
</div>

<div class="controls">
  <button id="zoomIn">Zoom +</button>
  <button id="zoomOut">Zoom −</button>
  <button id="zoomReset">Reset zoom</button>
  <button id="zoomFit">Ajustar a ventana</button>
  <button id="zoomFitWidth">Ajustar al ancho (solo scroll vertical)</button>
</div>

<div id="boxTooltip"></div>

<div id="diagramWrap">
<div id="diagram" class="mermaid">
{mermaid_src}
</div>
</div>

<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>
  function currentTheme() {{
    var attr = document.documentElement.getAttribute('data-theme');
    if (attr === 'dark' || attr === 'light') return attr;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }}
  mermaid.initialize({{
    startOnLoad: true,
    theme: 'base',
    themeVariables: {{
      background: 'transparent',
      primaryColor: '{panel_hint}',
      primaryTextColor: '{fg_hint}',
      primaryBorderColor: '{muted_hint}',
      lineColor: '{muted_hint}',
      fontFamily: '-apple-system, Segoe UI, Roboto, sans-serif',
      fontSize: '13px'
    }},
    flowchart: {{ curve: 'basis', htmlLabels: true, useMaxWidth: false }}
  }});

  var scale = 1;
  var wrap = document.getElementById('diagramWrap');
  var diagram = document.getElementById('diagram');
  function applyZoom() {{ diagram.style.transform = 'scale(' + scale + ')'; }}
  document.getElementById('zoomIn').onclick = function() {{ scale = Math.min(scale * 1.2, 3); applyZoom(); }};
  document.getElementById('zoomOut').onclick = function() {{ scale = Math.max(scale / 1.2, 0.2); applyZoom(); }};
  document.getElementById('zoomReset').onclick = function() {{ scale = 1; applyZoom(); }};

  function fitToWindow() {{
    var svg = diagram.querySelector('svg');
    if (!svg) return;
    var bbox;
    try {{ bbox = svg.getBBox(); }} catch (e) {{ return; }}
    if (!bbox || !bbox.width || !bbox.height) return;
    var availW = wrap.clientWidth - 32;
    var availH = wrap.clientHeight - 32;
    scale = Math.max(Math.min(availW / bbox.width, availH / bbox.height, 1), 0.05);
    applyZoom();
  }}
  document.getElementById('zoomFit').onclick = fitToWindow;

  function fitToWidth() {{
    var svg = diagram.querySelector('svg');
    if (!svg) return;
    var bbox;
    try {{ bbox = svg.getBBox(); }} catch (e) {{ return; }}
    if (!bbox || !bbox.width) return;
    var availW = wrap.clientWidth - 32;
    scale = Math.max(availW / bbox.width, 0.05);
    applyZoom();
  }}
  document.getElementById('zoomFitWidth').onclick = fitToWidth;

  function nodeText(el) {{
    var parts = [];
    el.childNodes.forEach(function(n) {{
      if (n.nodeType === Node.TEXT_NODE) parts.push(n.textContent);
      else if (n.tagName === 'BR') parts.push('\\n');
      else if (n.tagName && n.tagName.toLowerCase() === 'title') {{ /* ignora titulos ya existentes */ }}
      else parts.push(nodeText(n));
    }});
    return parts.join('');
  }}

  var boxTooltip = document.getElementById('boxTooltip');
  var tooltipPinned = false;

  function positionTooltip(x, y) {{
    var pad = 18;
    var vw = window.innerWidth, vh = window.innerHeight;
    var rect = boxTooltip.getBoundingClientRect();
    var left = x + pad;
    var top = y + pad;
    if (left + rect.width > vw) left = x - rect.width - pad;
    if (top + rect.height > vh) top = y - rect.height - pad;
    boxTooltip.style.left = Math.max(4, left) + 'px';
    boxTooltip.style.top = Math.max(4, top) + 'px';
  }}
  function showTooltip(text, x, y) {{
    boxTooltip.textContent = text;
    boxTooltip.style.display = 'block';
    positionTooltip(x, y);
  }}
  function hideTooltip() {{
    boxTooltip.style.display = 'none';
    tooltipPinned = false;
  }}

  function wireTooltips() {{
    var svg = diagram.querySelector('svg');
    if (!svg) return;
    svg.querySelectorAll('.node, .cluster').forEach(function(nodeEl) {{
      var text = nodeText(nodeEl).replace(/[ \\t]*\\n[ \\t]*/g, '\\n').trim();
      if (!text) return;
      nodeEl.addEventListener('mouseenter', function(ev) {{
        if (!tooltipPinned) showTooltip(text, ev.clientX, ev.clientY);
      }});
      nodeEl.addEventListener('mousemove', function(ev) {{
        if (!tooltipPinned) positionTooltip(ev.clientX, ev.clientY);
      }});
      nodeEl.addEventListener('mouseleave', function() {{
        if (!tooltipPinned) hideTooltip();
      }});
      nodeEl.addEventListener('click', function(ev) {{
        ev.stopPropagation();
        showTooltip(text, ev.clientX, ev.clientY);
        tooltipPinned = true;
      }});
    }});
    document.addEventListener('click', hideTooltip);
  }}

  var wireAttempts = 0;
  var wireTimer = setInterval(function() {{
    wireAttempts++;
    var svg = diagram.querySelector('svg');
    var ready = svg && svg.querySelectorAll('.node, .cluster').length > 0;
    if (ready) {{
      clearInterval(wireTimer);
      fitToWindow();
      wireTooltips();
    }} else if (wireAttempts > 100) {{
      clearInterval(wireTimer); // se rindio tras 10s -- algo fue mal en el render de mermaid
    }}
  }}, 100);

  document.querySelectorAll('#legend input[type=checkbox]').forEach(function(cb) {{
    cb.addEventListener('change', function() {{
      var cat = cb.value;
      var display = cb.checked ? '' : 'none';
      document.querySelectorAll('.cat_' + cat).forEach(function(el) {{
        el.style.display = display;
      }});
    }});
  }});
</script>
</body>
</html>
"""


def main():
    if not os.path.exists(gi.LST_PATH):
        print(f"ERROR: falta {gi.LST_PATH} -- ejecuta antes:")
        print("  py tools/build_all.py")
        raise SystemExit(1)

    labels, source_lines = gi.parse_listing(gi.LST_PATH)
    types = gi.classify(labels, source_lines)
    funcion_set = {n for n, t in types.items() if t == "funcion"}

    unmapped = sorted(n for n in funcion_set if n not in CATEGORY)
    if unmapped:
        print("AVISO: funciones sin categoria explicita (van a 'otros'):")
        for n in unmapped:
            print(f"  {n}")

    edges, n_dropped = build_edges(labels, source_lines, types, funcion_set)
    mermaid_src, by_cat = build_mermaid(labels, funcion_set, edges)

    light_vars = "\n".join(f"    --c-{cat}: {hexv};" for cat, hexv in COLOR_LIGHT.items())
    dark_vars = "\n".join(f"      --c-{cat}: {hexv};" for cat, hexv in COLOR_DARK.items())

    legend_items = []
    cat_order = ["boot", "menu", "motor", "items", "hud", "graficos", "sonido", "otros"]
    for cat in cat_order:
        n = len(by_cat.get(cat, []))
        if n == 0:
            continue
        legend_items.append(
            f'  <label><input type="checkbox" value="{cat}" checked> '
            f'<span class="swatch" style="background:var(--c-{cat})"></span>'
            f'{CATEGORY_LABEL[cat]} ({n})</label>'
        )

    class_defs = "\n".join(
        f"  classDef cat_{cat} fill:{COLOR_LIGHT[cat]},stroke:{COLOR_LIGHT[cat]},color:#fff,stroke-width:1px;"
        for cat in COLOR_LIGHT
    )
    mermaid_full = mermaid_src + "\n" + class_defs

    html = HTML_TEMPLATE.format(
        n_func=len(funcion_set),
        n_edges=len(edges),
        n_dropped=n_dropped,
        legend_items="\n".join(legend_items),
        mermaid_src=mermaid_full,
        light_vars=light_vars,
        dark_vars=dark_vars,
        panel_hint="#ffffff",
        fg_hint="#2a2620",
        muted_hint="#6b6458",
    )

    with open(HTML_PATH, "w", encoding="utf-8") as f:
        f.write(html)

    n_edges = len(edges)
    print(f"escrito {HTML_PATH}")
    print(f"nodos (funcion): {len(funcion_set)}  aristas (CALL): {n_edges}")
    for cat in cat_order:
        print(f"  {cat:10s} {len(by_cat.get(cat, []))}")


if __name__ == "__main__":
    main()
