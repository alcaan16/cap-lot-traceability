using logistica from '../db/schema';

service LogisticaService @(path: '/api/logistica') {

    // ── Entidades expuestas (proyecciones) ────────────────────────────────
    entity Productos      as projection on logistica.Productos;
    entity Categorias     as projection on logistica.Categorias;
    entity Proveedores    as projection on logistica.Proveedores;
    entity Pedidos        as projection on logistica.Pedidos;
    entity ItemsPedido    as projection on logistica.ItemsPedido;
    entity LotesProveedor as projection on logistica.LotesProveedor;
    entity LotesInternos  as projection on logistica.LotesInternos;
    entity ConsumosLote   as projection on logistica.ConsumosLote;

    // ── Operación personalizada (acción): modifica estado ─────────────────
    action confirmarPedido(pedidoId : UUID) returns Pedidos;

    // Registra una producción: consume lotes de proveedor por FEFO
    // (caduca antes → se usa antes) y deja el rastro en ConsumosLote.
    action registrarProduccion(
        productoId        : UUID,
        cantidadProducida : Decimal,
        fechaProduccion   : Date
    ) returns LotesInternos;

    // ── Operación de consulta (función): solo lectura ─────────────────────
    // Antes leía Productos.stock (ya no existe). Ahora es un dato real:
    // suma de cantidadDisponible en los lotes de proveedor de ese producto.
    function stockProducto(productoId : UUID) returns Decimal;
}