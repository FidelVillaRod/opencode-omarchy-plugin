# OpenCode — Omarchy Bar Plugin

Native Omarchy bar panel para gestionar sesiones de [OpenCode](https://opencode.ai) desde el escritorio: muestra sesiones activas/recientes, uso de tokens y costo del día, y permite elegir modelo y abrir nuevas sesiones.

## Características

- **Lista de sesiones**: haz clic en una sesión para reanudarla en un terminal `org.omarchy.agent` sobre el escritorio activo.
- **Selector de modelo**: desplegable con los modelos disponibles (`opencode models`).
- **Nueva sesión**: botón `+` que abre `opencode -m <modelo>` en el escritorio activo.
- **Indicador diario**: sesiones, tokens y costo de hoy en el tooltip del panel.
- **Activos vs. cerrados**: los directorios de sesión se comprueban para marcar qué sesiones siguen abiertas.

## Requisitos

- [Omarchy](https://omarchy.org) (Arch + Hyprland)
- [OpenCode](https://opencode.ai) instalado y accesible como `opencode`
- `python3` y `less`/`find` estándar

## Instalación

```bash
# 1. Copia el plugin a la carpeta de plugins de Omarchy
cp -r fidelv.opencode ~/.config/omarchy/plugins/

# 2. Instala los scripts auxiliares
install -m755 bin/omarchy-opencode-resume ~/.local/bin/
install -m755 bin/omarchy-opencode-new ~/.local/bin/

# 3. Añade el widget al bar layout en ~/.config/omarchy/shell.json (plugins[]) y
#    colócalo en bar.layout.* si quieres que aparezca en la barra.

# 4. Reinicia el shell para aplicarlo
omarchy restart shell
```

## Configuración

El widget expone dos opciones ajustables desde el editor de la barra:

| Opción | Tipo | Default | Descripción |
|--------|------|---------|-------------|
| `refreshIntervalSec` | entero | 300 | Intervalo de refresco del panel (30–3600 s) |
| `maxSessions` | entero | 20 | Número máximo de sesiones a mostrar (5–50) |

## Uso

- Clic en una sesión → la abre en el escritorio activo y cierra el panel.
- El icono `+` → nueva sesión con el modelo seleccionado.
- El selector de modelo persiste la última selección.

## Estructura

```
fidelv.opencode/
├── manifest.json        # Metadatos y schema del widget para Omarchy
├── Panel.qml            # Interfaz del panel y lógica QML
├── collector.py         # Recopila sesiones, modelos y estadísticas desde opencode.db/CLI
└── bin/
    ├── omarchy-opencode-resume   # Reanuda una sesión en el escritorio activo
    └── omarchy-opencode-new      # Abre una sesión nueva (con modelo opcional)
```

## Licencia

MIT
