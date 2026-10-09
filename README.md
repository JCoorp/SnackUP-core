# SnackUP · Pipeline CI con SonarQube y Discord

Versión integrada de SnackUP en Flutter y Firebase, con un agente que muestra las etapas de CI y explica los fallos.

- [Instrucciones, configuración y estado de la evidencia](docs/ci-parte-2/README.md).
- [Pipeline Flutter, SonarQube, Quality Gate y alerta](.github/workflows/flutter-ci.yml).
- [Agente gráfico](tools/ci_agent/README.md).
- [Generador del video a partir de ejecuciones reales](tools/ci_evidence/README_VIDEO.md).

El análisis y la alerta requieren los secretos `SONAR_TOKEN` y `CI_FAILURE_WEBHOOK_URL` de este repositorio. La entrega se valida con un análisis real y un mensaje confirmado por Discord. Consulta el estado de verificación antes de entregar el video.

---

# SnackUP-Core `v1.0`

![SnackUP Banner](https://img.shields.io/badge/SnackUP-Official_Production_Repo-orange?style=for-the-badge&logo=fastapi)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.29.0%2B-02569B?style=flat&logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)](https://firebase.google.com)

Bienvenido al repositorio central de **SnackUP**. Esta es la versión profesional destinada a producción, optimizada para escalabilidad y rendimiento.

---

## ⚠️ Regla de Oro (Políticas de Git)

> **Prohibido hacer push directo a `main` o `develop`.**
> Todo cambio debe integrarse mediante **Pull Request (PR)** y requiere al menos **1 aprobación** de un socio para ser fusionado.

---

## 🛠️ Stack Tecnológico

| Componente | Tecnología | Detalle |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.29.0+ | UI Multiplataforma |
| **Lenguaje** | Dart (SDK >=3.8.0) | Tipado fuerte |
| **Backend** | Firebase | Firestore, Auth, Storage |
| **Estado** | Provider | ChangeNotifiers |

---

## 📋 Requisitos Previos

Para que el proyecto compile a la primera, es **obligatorio**:

1. **Actualizar Flutter:**

```bash
flutter upgrade
```

Verifica con `flutter --version` que estés en la 3.29.0 o superior.

2. **Firebase CLI:**

```bash
npm install -g firebase-tools
firebase login
```

---

## ⚙️ Configuración Inicial

Si es la primera vez que clonas el repo, sigue este orden exacto:

1. **Obtener dependencias:**

```bash
flutter pub get
```

2. **Vincular Firebase:**

```bash
flutterfire configure
```

Selecciona el proyecto **snackup-official** cuando el terminal te lo solicite.

3. **Limpieza (Solo si algo falla):**

```bash
flutter clean && flutter pub get
```

---

## 🌿 Flujo de Trabajo (GitFlow Pro)

Para mantener el código limpio y profesional, seguimos este estándar:

| Acción | Rama / Prefijo | Ejemplo de Commit |
| :--- | :--- | :--- |
| **Nueva Mejora** | `feat/` | `feat: add qr scanner integration` |
| **Arreglo de Bug** | `fix/` | `fix: resolve login timeout` |
| **Refactor** | `refactor/` | `refactor: optimize provider logic` |

> [!TIP]
> **Antes de empezar cualquier tarea:** Asegúrate de estar al día ejecutando `git pull origin develop` para evitar conflictos de merge.

---

## 📁 Estructura del Proyecto

```text
lib/
├── models/      # Definición de datos (Data classes)
├── services/    # Lógica de Firebase y APIs externas
├── providers/   # Manejo de estado global (ChangeNotifiers)
├── screens/     # Pantallas principales de la UI
└── widgets/     # Componentes reutilizables
```

---

<p align="center">
Desarrollado con ❤️ por el equipo de <strong>SnackUP</strong>
</p>

