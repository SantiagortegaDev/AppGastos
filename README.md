# AppGastos

App Flutter (Material 3) para registro rápido de gastos, con acceso directo
desde el panel de Ajustes Rápidos de Android (Quick Settings Tile).

---

## Estructura del proyecto

```
appgastos/
├── lib/
│   ├── main.dart                       # Entry point + inicialización de servicios
│   ├── models/
│   │   └── expense.dart                # Modelo Expense + enum ExpenseCategory
│   ├── services/
│   │   ├── expense_repository.dart     # Persistencia con shared_preferences
│   │   └── tile_channel.dart           # MethodChannel hacia el Tile nativo
│   ├── screens/
│   │   └── home_screen.dart            # Pantalla principal (lista + total + FAB)
│   ├── widgets/
│   │   ├── add_expense_sheet.dart      # Bottom sheet de 2 pasos (monto → categoría)
│   │   ├── add_quick_tile_button.dart  # Botón "Agregar acceso rápido"
│   │   └── expense_list_item.dart      # Ítem de la lista de gastos
│   └── utils/
│       └── formatters.dart             # formatCurrency / formatDateTime
├── android/app/src/main/
│   ├── AndroidManifest.xml             # Registro del TileService
│   └── kotlin/com/example/appgastos/
│       ├── MainActivity.kt             # Bridge Kotlin ↔ Flutter
│       └── ExpenseTileService.kt       # TileService nativo
├── .github/workflows/
│   └── build-apk.yml                   # CI: build APK + release automático
└── pubspec.yaml
```

---

## Cómo usar este código en un proyecto nuevo

### 1) Crea el proyecto base

```bash
flutter create appgastos --org com.example
cd appgastos
```

> Si usas otro `--org`, recuerda actualizar el `namespace` en
> `android/app/build.gradle.kts` y los `package` en los archivos `.kt`.

### 2) Reemplaza / añade los archivos

Copia cada archivo de este proyecto en la ruta equivalente del proyecto
recién creado, sobreescribiendo los defaults de `flutter create` cuando
corresponda:

- `lib/main.dart`
- `lib/models/expense.dart`
- `lib/services/expense_repository.dart`
- `lib/services/tile_channel.dart`
- `lib/screens/home_screen.dart`
- `lib/widgets/add_expense_sheet.dart`
- `lib/widgets/add_quick_tile_button.dart`
- `lib/widgets/expense_list_item.dart`
- `lib/utils/formatters.dart`
- `pubspec.yaml` (o edita el default y añade `shared_preferences` + `intl`)
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/appgastos/MainActivity.kt`
- `android/app/src/main/kotlin/com/example/appgastos/ExpenseTileService.kt`
- `android/app/build.gradle.kts`
- `.github/workflows/build-apk.yml`

### 3) Dependencias

Las dos dependencias externas son:

```yaml
dependencies:
  shared_preferences: ^2.2.3
  intl: ^0.19.0
```

(Ejecuta `flutter pub get`.)

---

## Cómo compilar y probar

### En emulador o dispositivo físico

```bash
flutter run --release
```

> Para el Quick Settings Tile necesitas un dispositivo o emulador con API 33+
> (Android 13+) para que funcione `ACTION_QUICK_SETTINGS_ADD_TILE`. El Tile
> en sí funciona desde API 24, pero el asistente de "agregar" automático
> requiere Android 13.

### Probar el flujo del Tile

1. Instala la app: `flutter install`.
2. Desliza el panel de ajustes rápidos (dos veces, para ver todo).
3. Toca el lápiz ("Editar tiles").
4. Busca "Registrar gasto" en la lista de tiles disponibles.
5. Arrástralo al panel principal y guarda.
6. Despliega el panel, toca el tile nuevo → la app se abre con el bottom
   sheet de captura automáticamente.

### Probar el flujo del botón "Agregar acceso rápido"

Dentro de la app, en la cabecera hay un botón "Agregar acceso rápido".
Al tocarlo:

- En Android 13+: abre el diálogo nativo del sistema pidiendo permiso
  para agregar el tile.
- En Android < 13: muestra un diálogo con instrucciones manuales.

---

## Cómo crear el repo en GitHub

> **NO uses el token que expusiste en el chat.** Ya está comprometido:
> revócalo en https://github.com/settings/tokens y crea uno nuevo con
> scopes `repo` y `workflow`. Guárdalo como secret si lo vas a usar desde
> un CI/CD propio, o pásalo por variable de entorno temporal.

### Opción A — `gh` CLI (recomendado)

```bash
# 1) Entra a la carpeta del proyecto
cd appgastos

# 2) Init git local
git init
git branch -M main
git add .
git commit -m "feat: AppGastos — Flutter app + Quick Settings Tile"

# 3) Autentícate (si no lo estás ya) — NO pegues el token en el chat la próxima vez
gh auth login
# (Sigue las instrucciones en pantalla; usa el token rotado.)

# 4) Crea el repo remoto y empuja
gh repo create AppGastos --public --source=. --remote=origin --push
```

### Opción B — Web UI

1. Entra a https://github.com/new.
2. Nombre: `AppGastos`. Público o privado a tu gusto. **No** marques
   "Initialize with README" (ya tienes archivos locales).
3. Vuelve a tu terminal local:

```bash
cd appgastos
git init
git branch -M main
git add .
git commit -m "feat: AppGastos — Flutter app + Quick Settings Tile"
git remote add origin https://github.com/SantiagortegaDev/AppGastos.git
git push -u origin main
```

### Verificar el workflow

Una vez pusheado:

1. Entra a `https://github.com/SantiagortegaDev/AppGastos/actions`.
2. Deberías ver el workflow "Build APK & Release" corriendo.
3. Cuando termine, en `Releases` aparecerá el APK publicado.
4. Los siguientes push a `main` crearán releases `v1.0.<run_number>`
   marcados como prerelease.
5. Si quieres un release "estable", crea un tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   El workflow generará un release final (no prerelease) con ese tag.

---

## Notas técnicas

### Por qué `shared_preferences` y no `sqflite`

Más simple, sin esquema, sin migraciones. Suficiente para uso individual.
El modelo `Expense` y el repositorio están aislados, así que migrar a
`sqflite` o `drift` más adelante no afecta a la UI.

### Por qué el TileService no puede auto-agregarse

Android prohíbe explícitamente que apps agreguen tiles al panel de ajustes
rápidos sin interacción del usuario (medida anti-abuso). La excepción es
`ACTION_QUICK_SETTINGS_ADD_TILE` (API 33+), que muestra un diálogo del
sistema donde el usuario confirma.

### Comunicación Kotlin ↔ Flutter

- `MainActivity.kt` recibe el intent con `open_expense_sheet = true`.
- Caso cold-start: guarda el flag y lo responde a Flutter cuando este llama
  `getInitialAction()` vía MethodChannel.
- Caso foreground: invoca `openExpenseSheet` en vivo sobre el canal.
- Flutter (`TileChannel`) expone `pendingOpenRequest` como `ChangeNotifier`
  para que la UI reaccione.

### Ajuste del teclado en el bottom sheet

`showModalBottomSheet(isScrollControlled: true)` + `Padding(viewInsets.bottom)`
asegura que el contenido se desplace sobre el teclado en vez de quedarse
oculto detrás de él.
