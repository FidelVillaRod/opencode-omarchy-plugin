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

Con `omarchy plugin add` (recomendado):

```bash
# 1. Instala el plugin desde git
omarchy plugin add https://github.com/FidelVillaRod/opencode-omarchy-plugin --enable

# 2. Instala los scripts auxiliares (el panel los invoca por nombre)
install -m755 ~/.config/omarchy/plugins/opencode.core/bin/omarchy-opencode-* ~/.local/bin/

# 3. Reinicia el shell para aplicarlo
omarchy restart shell
```

Instalación manual (clonando el repo):

```bash
git clone https://github.com/FidelVillaRod/opencode-omarchy-plugin
cp -r opencode-omarchy-plugin ~/.config/omarchy/plugins/opencode.core
install -m755 opencode-omarchy-plugin/bin/omarchy-opencode-* ~/.local/bin/
omarchy restart shell
```

> Nota: los programas `omarchy-opencode-*` deben quedarse en `~/.local/bin/` (o en el PATH), porque el panel los invoca por nombre.

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
- Los iconos de acción **aparecen al pasar el cursor** por una sesión (o al
  seleccionarla con el teclado):
  - Icono de **descarga** → exporta la conversación a `~/Descargas/opencode/`
    (Markdown + JSON) y abre la carpeta.
  - Icono de **papelera** → elimina la sesión. Si está abierta, avisa
    que está en uso y permite cerrarla y eliminarla; si está cerrada, solo confirma.
- **Navegación por teclado** (con el panel enfocado):
  - `↑`/`↓` o `k`/`j` → mover el cursor entre sesiones.
  - `→`/`←` o `l`/`h` → mover el foco a los iconos de acción (exportar/eliminar).
  - `Enter` → activar (reanudar la sesión o ejecutar la acción enfocada).
  - `d` o `Supr` → abrir el diálogo de eliminación de la sesión seleccionada.
  - `r` → refrescar los datos; `Esc` → cerrar el panel.

## Estructura

```
opencode.core/
├── manifest.json        # Metadatos y schema del widget para Omarchy
├── Panel.qml            # Interfaz del panel y lógica QML (incluye ConfirmDialog)
├── collector.py         # Recopila sesiones, modelos y estadísticas desde opencode.db/CLI
└── bin/
    ├── omarchy-opencode-resume   # Reanuda una sesión en el escritorio activo
    ├── omarchy-opencode-new      # Abre una sesión nueva (con modelo opcional)
    ├── omarchy-opencode-check    # Indica si una sesión está abierta o cerrada
    ├── omarchy-opencode-delete   # Cierra (si aplica) y elimina una sesión
    └── omarchy-opencode-export   # Exporta la conversación en Markdown/JSON y abre la carpeta
```

## Licencia

MIT
