# Trazabilidad de Lote — Logística de Producción

Aplicación CAP que modela la trazabilidad de lote en un proceso de producción: desde el lote recibido
de proveedor hasta el lote interno de producto terminado, aplicando consumo FEFO (First-Expired,
First-Out) cuando la producción tira de varias partidas a la vez.

## 1. Qué problema resuelve

En una planta de producción, cada lote de materia prima que llega de proveedor tiene su propia fecha
de caducidad, y la producción diaria no suele consumir un único lote: cuando el de hoy no basta, se
completa con el del día anterior, o con el que quede disponible que caduque antes. Ese reparto entre
varios lotes es exactamente lo que hay que poder reconstruir después — ante una alerta sanitaria o una
reclamación de cliente, se necesita poder ir del producto terminado hacia atrás hasta el origen exacto
de cada kilo, sin depender de un registro en papel.

Este proyecto modela esa cadena: **lote de proveedor → lote interno → producto terminado**, con
consumo automático por fecha de caducidad (FEFO) y un registro explícito de qué lotes de proveedor
componen cada lote interno.

## 2. Stack y arquitectura

- **SAP Cloud Application Programming Model (CAP)**, Node.js, JavaScript (ES6+)
- **SQLite** como base de datos, en memoria — sin persistencia entre reinicios (ver alcance técnico)
- **OData V4** como protocolo de servicio
- **SAP Fiori preview** (generada automáticamente por CAP) para navegar las entidades sin UI propia

```
db/schema.cds                → modelo de datos (8 entidades)
srv/logistica-service.cds    → definición del servicio: proyecciones + 2 operaciones custom
srv/logistica-service.js     → lógica de negocio: handlers de validación y consumo FEFO
srv/logistica-service-ui.cds → anotaciones Fiori (Productos, Pedidos)
```

El modelo tiene dos bloques con propósitos distintos:

- **Catálogo y pedidos** (`Categorias`, `Productos`, `Proveedores`, `Pedidos`, `ItemsPedido`) —
  ejercicio de CAP con asociaciones, composición y lógica de servicio (cálculo automático de
  precio/subtotal, recálculo de total del pedido). Se mantiene como apoyo técnico; no forma parte de
  la trazabilidad.
- **Trazabilidad de lote** (`LotesProveedor`, `LotesInternos`, `ConsumosLote`) — el caso real del
  proyecto, descrito abajo.

## 3. Alcance técnico

**Implementado:**

- Modelo de datos con relación completa lote de proveedor → lote interno vía `ConsumosLote`
  (composición many-to-many con cantidad consumida por línea).
- Acción `registrarProduccion`: dada una cantidad a producir, selecciona automáticamente los lotes de
  proveedor disponibles por **FEFO** (fecha de caducidad más próxima primero; en empate, el que llegó
  antes), reparte el consumo entre tantos lotes como haga falta, y deja el rastro completo en
  `ConsumosLote`.
- Validación atómica: si no hay stock suficiente en los lotes de proveedor, la operación se rechaza
  **antes** de escribir nada — no deja lotes internos ni consumos a medias.
- Función `stockProducto`: cantidad disponible real de un producto, calculada en el momento sumando
  `cantidadDisponible` de sus lotes de proveedor — no un contador que alguien tiene que mantener a
  mano.
- Servicio OData V4 con las 8 entidades expuestas y las 2 operaciones custom.
- Datos de ejemplo para `LotesProveedor` (3 lotes de Aceite de Oliva 5L, fechas de caducidad
  distintas) — se cargan solos al arrancar, listos para reproducir el caso FEFO sin preparar nada.
  Es el único producto del catálogo de ejemplo con lotes: los demás (palet, cinta de embalaje,
  escáner) son bienes duraderos a los que no les corresponde caducidad, y el modelo no se la fuerza.

**No implementado, a propósito:**

- **Sin desplegar.** Corre 100% local (`cds watch` + SQLite). Nunca se ha desplegado en Cloud Foundry,
  no usa XSUAA ni HANA Cloud. Decisión tomada desde el inicio del proyecto, no una limitación por
  falta de tiempo.
- **Sin persistencia real entre reinicios.** SQLite en memoria se regenera desde los `.csv` de
  `db/data/` cada vez que `cds watch` recarga — lo que incluye los 3 lotes de ejemplo (se recargan
  solos, no hay que recrearlos). Cualquier lote adicional creado a mano durante una prueba sí se
  pierde al reiniciar.
- **Sin autenticación.** No hay XSUAA ni control de usuario; cualquiera con acceso a la URL puede
  llamar cualquier operación. No apto para producción tal cual.
- **Sin UI Fiori propia para las entidades de lote.** Se navegan con la preview genérica de OData, sin
  las anotaciones de etiquetas/layout que sí tienen `Productos` y `Pedidos`.
- **Generación de `numeroLoteInterno` no segura ante concurrencia.** Cuenta los lotes internos del día
  y suma uno; con llamadas simultáneas reales podría repetirse un número. Suficiente para una demo, no
  para producción.
- **Orden FEFO indefinido si `fechaCaducidad` es nula** en algún lote — depende de cómo trate SQLite
  los valores nulos en `ORDER BY`. No resuelto.
- **`Pedidos`/`ItemsPedido` no está conectado a los lotes.** Es un ejercicio de CAP independiente
  (catálogo + pedido de cliente), no un segundo caso de trazabilidad.

## 4. Cómo ejecutarlo

```bash
git clone https://github.com/alcaan16/cap-lot-traceability.git
cd cap-lot-traceability
npm install
cds watch
```

El servicio queda disponible en `http://localhost:4004/api/logistica/`. Todo el catálogo viene con
datos de ejemplo desde `db/data/`, incluidos **3 lotes de proveedor ya cargados** del mismo producto
con fechas de caducidad distintas — no hace falta crear nada a mano para ver la trazabilidad:

```bash
# Ver los 3 lotes de partida
curl -s http://localhost:4004/api/logistica/LotesProveedor
```

```bash
# Registrar una producción que necesite más de un lote (100 no cabe en los 80 del primero)
curl -si -X POST http://localhost:4004/api/logistica/registrarProduccion \
  -H "Content-Type: application/json" \
  -d '{"productoId":"30000000-0000-0000-0000-000000000004","cantidadProducida":100,"fechaProduccion":"2026-08-20"}'
```

```bash
# Comprobar el reparto: el lote que caduca antes queda en 0, el siguiente con lo que sobre
curl -s http://localhost:4004/api/logistica/LotesProveedor
curl -s http://localhost:4004/api/logistica/ConsumosLote
```

Estos son los mismos pasos usados para verificar el proyecto durante el desarrollo, no un ejemplo
aproximado.

## 5. Capturas

*(pendiente de añadir)*

- Modelo de datos (entidades y relaciones)
- Respuesta de `registrarProduccion` repartiendo el consumo entre dos lotes
- `LotesProveedor` y `ConsumosLote` tras el reparto, mostrando el resultado