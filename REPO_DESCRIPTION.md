# HackMTY2026-Bolis-5-peso

## 📋 Descripción General

**HackMTY2026-Bolis-5-peso** es un proyecto desarrollado para el hackathon HackMTY 2026, que presenta una aplicación móvil denominada **Banorte App**. Se trata de una solución innovadora construida con tecnologías modernas para dispositivos móviles, con un enfoque en proporcionar una experiencia de usuario optimizada.

**Propietario:** [Alexa404NL](https://github.com/Alexa404NL)  
**Licencia:** MIT License  
**Visibilidad:** Público  
**Rama Principal:** main  
**Lenguaje Primario:** Dart  

---

## 🎯 Funcionalidades Principales

### 1. **Aplicación Móvil Flutter**
- Interfaz de usuario moderna y responsive
- Compatible con múltiples plataformas (iOS, Android, Windows)
- Utiliza Material Design para consistencia visual
- Soporte para fuentes personalizadas (Gotham y Roboto)

### 2. **Visualización de Datos**
- Gráficos y tablas interactivas
- Integración de la librería `fl_chart` para representación visual de datos
- Capacidad de mostrar información financiera de manera clara

### 3. **Comunicación con Servidores**
- Integración de APIs HTTP
- Cliente HTTP robusto para solicitudes de red
- Potencial para conectar con servicios backend

### 4. **Interfaz de Usuario Profesional**
- Diseño inspirado en identidad corporativa (Banorte)
- Iconografía consistente mediante Cupertino Icons
- Tipografía profesional personalizada

---

## 🛠️ Stack Tecnológico

### **Lenguajes de Programación**

| Lenguaje | Porcentaje | Descripción |
|----------|-----------|------------|
| **Dart** | 53.3% | Lenguaje principal de Flutter |
| **Python** | 33.4% | Scripting, backend, o herramientas de build |
| **C++** | 7.5% | Código nativo para optimización |
| **CMake** | 4.1% | Sistema de construcción para código nativo |
| **Swift** | 0.8% | Integración específica para iOS |
| **HTML** | 0.6% | Recursos web o documentación |
| **Otros** | 0.3% | Diversos |

### **Frameworks y Librerías Principales**

#### **Frontend (Dart/Flutter)**
- **Flutter SDK**: Framework principal para desarrollo multiplataforma
- **fl_chart** (v1.2.0): Librería para crear gráficos interactivos y visualizaciones
- **http** (v1.6.0): Cliente HTTP para comunicación con APIs
- **cupertino_icons** (v1.0.8): Iconografía nativa iOS
- **flutter_lints** (v6.0.0): Herramientas de análisis estático de código

#### **Backend/Scripting (Python)**
- Scripts de automatización
- Herramientas de desarrollo
- Posible servidor backend o API

#### **Código Nativo**
- **C++**: Optimizaciones de rendimiento críticas
- **CMake**: Compilación del código nativo
- **Swift**: Integración específica con iOS

### **Configuración de Entorno**

```yaml
SDK Dart/Flutter: >=3.11.5 <4.0.0
Versión del Proyecto: 1.0.0+1
```

### **Tipografías Personalizadas**

- **Gotham** (pesos: 400, 500, 700)
- **Roboto** (peso: 400)

---

## 📁 Estructura del Proyecto

```
HackMTY2026-Bolis-5-peso/
├── banorte_app/                    # Aplicación Flutter principal
│   ├── pubspec.yaml               # Configuración de dependencias
│   ├── lib/                       # Código fuente Dart
│   ├── assets/                    # Recursos (fuentes, imágenes)
│   │   └── fonts/                 # Fuentes personalizadas
│   │       ├── gotham/
│   │       └── roboto/
│   ├── ios/                       # Código específico para iOS
│   │   ├── Runner/
│   │   └── Assets.xcassets/
│   ├── android/                   # Código específico para Android
│   ├── windows/                   # Código específico para Windows
│   ├── web/                       # Código específico para Web
│   └── test/                      # Pruebas unitarias e integración
├── [Scripts Python]               # Herramientas y automatización
└── [Código C++/CMake]            # Optimizaciones nativas
```

---

## 🔧 Dependencias Principales

### Producción

| Paquete | Versión | Propósito |
|---------|---------|----------|
| `flutter` | sdk | Framework base |
| `cupertino_icons` | ^1.0.8 | Iconografía iOS |
| `http` | ^1.6.0 | Comunicación HTTP/REST |
| `fl_chart` | ^1.2.0 | Visualización de gráficos |

### Desarrollo

| Paquete | Versión | Propósito |
|---------|---------|----------|
| `flutter_test` | sdk | Framework de pruebas |
| `flutter_lints` | ^6.0.0 | Análisis de código |

---

## 🚀 Capacidades Técnicas

### 1. **Desarrollo Multiplataforma**
- ✅ iOS
- ✅ Android
- ✅ Windows
- ✅ Web (opcional)

### 2. **Rendimiento**
- Código nativo en C++ para operaciones críticas
- Compilación optimizada con CMake
- Gestión eficiente de memoria con Dart

### 3. **Integración Backend**
- Cliente HTTP para consumir APIs REST
- Soporte para autenticación y gestión de sesiones
- Comunicación asincrónica

### 4. **Experiencia de Usuario**
- Gráficos interactivos para análisis de datos
- Diseño responsivo y adaptable
- Tema visual consistente

---

## 📊 Visualización de Composición del Código

```
Dart        ████████████████████████████████░░░░░  53.3%
Python      ███████████████████████░░░░░░░░░░░░░░  33.4%
C++         ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   7.5%
CMake       ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   4.1%
Swift       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   0.8%
HTML        ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   0.6%
Otros       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   0.3%
```

---

## 🎓 Contexto de Desarrollo

### HackMTY 2026
- **Evento:** Hackathon Tecnológico (Monterrey, México)
- **Temática:** Soluciones innovadoras con tecnología moderna
- **Producto:** Aplicación Banorte - Solución fintech/bancaria

### Colaboración
- Proyecto reciente (creado hace 1 día)
- Activamente en desarrollo
- Última actualización: 13 de septiembre de 2026

---

## 📝 Características de Desarrollo

### Control de Versiones
- **Sistema:** Git
- **Rama principal:** main
- **Política de merge:** Soporta merge commit, rebase y squash
- **Confirmación de commit:** Requerida según configuración

### Gestión del Proyecto
- ✅ Sistema de Issues habilitado
- ✅ Proyectos/Boards habilitados
- ✅ Pull Requests habilitados
- ✅ Wiki habilitado

### Licencia
- **Tipo:** MIT License
- **Distribuible:** Sí
- **Modificable:** Sí
- **Uso comercial:** Permitido

---

## 🔐 Permisos y Colaboración

- **Bifurcación:** Permitida
- **Descargas:** Habilitadas
- **Tipo de repositorio:** Original (no es fork)
- **Red:** Sin actividad de red registrada

---

## 💡 Caso de Uso

Esta aplicación parece estar diseñada para proporcionar:

1. **Experiencia Bancaria Moderna:** Interfaz intuitiva para operaciones financieras
2. **Análisis de Datos:** Visualización de gráficos para seguimiento de transacciones
3. **Accesibilidad Multiplataforma:** Disponibilidad en iOS, Android y potencialmente web
4. **Rendimiento Optimizado:** Uso de código nativo donde sea necesario
5. **Integración con APIs:** Conectividad con servicios backend

---

## 🔍 Análisis de Tecnologías

### ¿Por qué Dart/Flutter?
- Desarrollo rápido y multiplataforma
- Hot reload para iteración veloz en desarrollo
- Excelente rendimiento en dispositivos móviles
- Comunidad activa y documentación extensa

### ¿Por qué Python (33.4%)?
- Automatización de tareas de build
- Scripts de desarrollo
- Posible backend en micro-servicios
- Análisis de datos o reporting

### ¿Por qué C++ (7.5%)?
- Operaciones computacionalmente intensivas
- Criptografía o transacciones seguras
- Librerías nativas críticas para performance
- Integración con código legacy

### ¿Por qué Swift (0.8%)?
- Integración específica iOS
- APIs nativas no disponibles en Flutter
- Optimizaciones de plataforma

---

## 📈 Métricas del Repositorio

| Métrica | Valor |
|---------|-------|
| Tamaño | 773 KB |
| Estrellas | 0 |
| Forks | 0 |
| Issues Abiertos | 0 |
| Watchers | 0 |
| Licencia | MIT |
| Público | Sí |

---

## 🎯 Conclusión

**HackMTY2026-Bolis-5-peso** es un proyecto ambicioso que combina tecnologías modernas para crear una solución bancaria móvil. La composición del stack (Dart + Python + C++) sugiere un enfoque empresarial robusto, balanceando desarrollo rápido con optimizaciones de rendimiento donde es crítico. El proyecto está bien estructurado para escalabilidad y mantenimiento a largo plazo.

---

**Última actualización:** 13 de septiembre de 2026
