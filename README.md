# 🏪 Tenda — Sistema para tiendas de barrio

App móvil hecha en **Flutter** para administrar una tienda de barrio en Colombia: inventario, precios de venta, lectura de facturas con **inteligencia artificial (Grok)**, deudas con proveedores, ventas y fiados. **Todo gratis**: los datos se guardan en el teléfono (no necesita servidor) y la app se compila gratis con GitHub Actions.

## ✨ Funcionalidades

| Función | Descripción |
|---|---|
| 📦 **Inventario** | Productos con costo, % de ganancia, precio de venta, stock y categoría. Búsqueda rápida. |
| 💰 **Cálculo de precios** | Precio = costo + % de ganancia (20% por defecto, **editable por producto**), redondeado al múltiplo de $50 como se acostumbra en Colombia. |
| 🤖 **Escáner de facturas con IA** | Tomas la foto de la factura del proveedor y Grok extrae los productos, cantidades y costos unitarios. Tú revisas, corriges y asignas el % de ganancia antes de pasarlos al inventario. |
| 📅 **Deudas con proveedores** | Agenda las facturas pendientes con su fecha límite y la app te dice **cuánto ahorrar cada día o cada semana** para pagarlas a tiempo. Registra abonos parciales. |
| 🔔 **Alertas** | Aviso cuando un producto se está agotando (stock mínimo configurable por producto) y cuando una deuda está por vencer o vencida. |
| 🛒 **Punto de venta** | Arma el carrito, cobra de contado o fiado, y el stock se descuenta automáticamente. |
| 🤝 **Fiados** | Cuentas por cliente: anota lo que se llevan fiado, recibe abonos y mira cuánto te deben en total. |
| 📊 **Dashboard** | Resumen del día: ventas, valor del inventario, deudas pendientes y fiados por cobrar. |
| 📈 **Historial de ventas** | Consulta las ventas por rango de fechas con el detalle de cada una. |
| 🧮 **Calculadora rápida** | Ingresa un costo y un % y obtén el precio de venta sin crear el producto. |

Todo está en **pesos colombianos (COP)** con el formato local ($ 12.500).

## 📲 Cómo instalar la app (gratis)

### Opción A: Descargar el APK desde GitHub (recomendada)

1. Ve a la pestaña **Releases** del repositorio (o **Actions → última ejecución → Artifacts → tenda-apk**).
2. Descarga `app-release.apk` en tu teléfono Android.
3. Ábrelo y acepta "instalar de orígenes desconocidos" si te lo pide.
4. ¡Listo! No necesita cuenta ni internet (solo para el escáner con IA).

> Cada vez que se sube código a `main`, GitHub Actions compila el APK gratis. Para publicar una versión en Releases basta con crear un tag `v1.0.0`, `v1.1.0`, etc.

### Opción B: Compilar tú mismo

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) (canal stable) y Android Studio o el SDK de Android.

```bash
git clone https://github.com/Jhoan-Pd/Tenda.git
cd Tenda
flutter pub get
flutter run            # ejecutar en un teléfono/emulador conectado
flutter build apk      # generar el APK instalable
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

## 🤖 Configurar la IA de Grok (para escanear facturas)

El escáner de facturas usa la API de **xAI (Grok)** con visión. Necesitas una API key:

1. Entra a [console.x.ai](https://console.x.ai) y crea una cuenta.
2. Ve a **API Keys** y crea una nueva key (empieza por `xai-...`).
3. En la app: **Ajustes (⚙️) → API key de Grok** → pégala y guarda.

La key **solo se guarda en tu teléfono** y se usa únicamente cuando escaneas una factura. xAI cobra por uso de la API; cada factura cuesta unos pocos pesos en créditos (revisa los precios en su consola — suelen dar créditos de prueba al registrarse). Todo lo demás de la app funciona sin internet y sin costo.

## 📖 Guía de uso rápida

### 1. Primer uso
Abre **Ajustes (⚙️)** y configura el nombre de tu tienda y el **% de ganancia por defecto** (viene en 20%).

### 2. Llegó la factura del proveedor
1. En **Inicio**, toca **"Escanear factura con IA"** (o el botón 📄 en Inventario).
2. Toma la foto (buena luz, factura completa, sin arrugas).
3. Toca **"Extraer productos con IA"** y espera unos segundos.
4. Revisa la lista: toca cualquier producto para **corregir nombre, cantidad, costo o cambiar su % de ganancia**. La app te muestra al instante el precio de venta calculado.
5. Toca **"Agregar al inventario"**. Si un producto ya existía, se le suma el stock y se actualiza su costo y precio.

### 3. Agendar la factura como deuda
Si la factura es a crédito: pestaña **Deudas → +**, escribe el proveedor, el valor y la **fecha límite**. La app te muestra el **plan de ahorro diario y semanal**. Cuando vayas pagando, registra los **abonos** y el plan se recalcula solo.

### 4. Vender
Pestaña **Vender**: busca el producto, tócalo para agregarlo al carrito y toca **Cobrar**:
- **De contado**: la venta queda registrada y el stock se descuenta.
- **Fiado**: eliges (o creas) el cliente y queda anotado en su cuenta.

### 5. Fiados
Pestaña **Fiados**: mira cuánto debe cada cliente, anota fiados manuales y registra abonos.

### 6. Alertas
La campana 🔔 (arriba a la derecha) muestra los **productos que se están agotando** y las **deudas por vencer**. El número rojo indica cuántas alertas tienes. El stock mínimo de cada producto se configura al crearlo o editarlo.

### 7. Agregar/editar productos a mano
Pestaña **Inventario → +**. Escribe el costo y el % de ganancia y el **precio de venta se calcula solo** (puedes ajustarlo manualmente; con el botón ↻ vuelves al sugerido). Mantén presionado un producto para agregar stock, editar o eliminar.

## 🏗️ Arquitectura

```
lib/
├── main.dart                 # Arranque, tema y providers
├── models/                   # Product, Debt, Sale, Customer, InvoiceItem
├── data/
│   └── database_helper.dart  # SQLite local (sqflite)
├── services/
│   └── grok_service.dart     # Cliente de la API de Grok (visión)
├── providers/                # Estado con Provider (inventario, ventas, deudas, fiados, ajustes)
├── screens/                  # Pantallas por módulo
│   ├── dashboard/  products/  invoice/  sales/  debts/  credit/  alerts/  settings/
├── utils/
│   ├── price_calculator.dart # Costo + % ganancia, redondeo a $50
│   └── formatters.dart       # Formato COP y fechas
└── widgets/                  # Componentes reutilizables
```

- **Estado**: [provider](https://pub.dev/packages/provider) con `ChangeNotifier`.
- **Persistencia**: [sqflite](https://pub.dev/packages/sqflite) — base de datos SQLite en el teléfono, sin servidores ni mensualidades.
- **IA**: API de xAI (`grok-2-vision`) para leer facturas; la respuesta se valida y el usuario siempre revisa antes de guardar.
- **Tests**: `flutter test` cubre el cálculo de precios y el plan de ahorro de deudas.
- **CI/CD**: GitHub Actions analiza, prueba y compila el APK en cada push (gratis en repos públicos).

## 🧪 Desarrollo

```bash
flutter pub get      # dependencias
flutter analyze      # análisis estático
flutter test         # tests unitarios
flutter run          # correr en modo debug
```

## 📌 Notas

- Los datos viven **solo en tu teléfono**. Si desinstalas la app se pierden: haz copias de seguridad del teléfono si tu inventario es valioso.
- El escáner con IA puede equivocarse: **siempre revisa** los productos antes de agregarlos (la app te obliga a pasar por la pantalla de revisión).
- iOS: el proyecto incluye la carpeta `ios/`, pero compilar para iPhone requiere un Mac y cuenta de desarrollador de Apple (no es gratis). Android es 100% gratis.

---

Hecho con ❤️ para las tiendas de barrio de Colombia.
