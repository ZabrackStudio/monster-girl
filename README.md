# Monster Girl – Simulador de Cuidado (prototipo)

Prototipo jugable en Godot 4.7 con un personaje: **Reme**, una slime.

## Ejecutar

Abre la carpeta en Godot y pulsa F5, o desde la terminal:

    flatpak run org.godotengine.Godot --path .

## Estructura

| Ruta | Qué contiene |
|---|---|
| `data/balance.json` | Acciones por día, actividades, deriva nocturna, niveles de lujuria, minijuegos |
| `data/personajes/slime.json` | Stats iniciales, afinidades, fórmula de lujuria de la especie, diálogos y finales |
| `data/items.json` | Tienda: consumibles, pasivos y minijuegos desbloqueables |
| `data/eventos.json` | Eventos con momento, condiciones, peso y opciones |
| `scripts/game.gd` | Toda la lógica (sin interfaz) |
| `scripts/main.gd` | Interfaz construida en código |
| `scripts/slime_view.gd` | Retrato provisional dibujado |
| `scripts/minigame_*.gd` | Minijuegos |
| `personajes/slime/expresiones/` | Suelta aquí los PNG y sustituyen al dibujo (ver README dentro) |
| `tests/` | Simulador de equilibrio, prueba de humo y capturas |

## Equilibrar

Cambia los JSON y ejecuta el simulador (200 partidas por estrategia):

    flatpak run org.godotengine.Godot --headless --path . -s res://tests/sim.gd

Resultado actual: al azar ~30 días, estrategia básica ~108, experta ~320.

## Fórmula de lujuria nocturna

base + tristeza×k + (hambre−50)×k + (40−energía)×k + (50−higiene)×k
− (felicidad−50)×k − (salud−60)×k + día×k + objetos + azar.
Cada "k" está en el JSON de la especie, así cada chica monstruo reacciona distinto.

## Eventos: condiciones

`<stat>_min`, `<stat>_max`, `dia_min`, `nivel_min`, `nivel_max`, `dinero_min`.
Momentos: `trabajar`, `comer`, `pasear`, `limpiar`, `jugar`, `noche`.
Una opción con `"final": "carnal"` termina la partida con ese final.

## Versión web (GitHub Pages)

Se juega en <https://zabrackstudio.github.io/monster-girl/>, también desde iPhone con Safari
(Compartir → «Añadir a pantalla de inicio» para abrirlo como una app).

Para publicar cambios, vuelve a exportar a `docs/` y sube:

    flatpak run org.godotengine.Godot --headless --path . --export-release "Web" docs/index.html
    git add -A && git commit -m "Actualiza build web" && git push

GitHub tarda un minuto en publicarlo. La exportación usa la variante sin hilos
(`thread_support=false`) porque GitHub Pages no permite las cabeceras que requieren los hilos.
