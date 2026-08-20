using logistica from '../db/schema';

service LogisticaService @(path: '/api/logistica') {

    // ── Entidades expuestas (proyecciones) ────────────────────────────────
    entity Productos   as projection on logistica.Productos;
    entity Categorias  as projection on logistica.Categorias;
    entity Proveedores as projection on logistica.Proveedores;
    entity Pedidos     as projection on logistica.Pedidos;
    entity ItemsPedido as projection on logistica.ItemsPedido;

    // ── Operación personalizada (acción): modifica estado ─────────────────
    action confirmarPedido(pedidoId : UUID) returns Pedidos;

    // ── Operación de consulta (función): solo lectura ─────────────────────
    function stockProducto(productoId : UUID) returns Integer;
}
