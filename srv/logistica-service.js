// srv/logistica-service.js
const cds = require('@sap/cds');

module.exports = cds.service.impl(async function () {

    const { Pedidos, Productos, ItemsPedido } = this.entities;

    // ── BEFORE CREATE ItemsPedido ──────────────────────────────────────────
    // Se ejecuta ANTES de insertar.
    // Valida stock y calcula precio/subtotal automáticamente.
    this.before('CREATE', ItemsPedido, async (req) => {
        const { producto_ID, cantidad } = req.data;

        // Consultamos el producto en la BD
        const prod = await SELECT.one.from(Productos)
                           .where({ ID: producto_ID });

        if (!prod)
            return req.error(404, `Producto no encontrado: ${producto_ID}`);

        if (prod.stock < cantidad)
            return req.error(400,
                `Stock insuficiente. Disponible: ${prod.stock}, solicitado: ${cantidad}`);

        // Enriquecemos el payload antes de que CAP lo persista
        req.data.precio   = prod.precio;
        req.data.subtotal = prod.precio * cantidad;
    });

    // ── AFTER CREATE ItemsPedido ───────────────────────────────────────────
    // Se ejecuta DESPUÉS de insertar.
    // Recalcula el total del pedido sumando todos los subtotales.
    this.after('CREATE', ItemsPedido, async (data) => {
        const items = await SELECT.from(ItemsPedido)
                           .where({ pedido_ID: data.pedido_ID });

        const total = items.reduce((sum, item) => sum + (item.subtotal || 0), 0);

        await UPDATE(Pedidos)
              .set({ total })
              .where({ ID: data.pedido_ID });
    });

    // ── ACTION: confirmarPedido ────────────────────────────────────────────
    // Cambia el estado a CONFIRMADO y descuenta el stock de cada producto.
    this.on('confirmarPedido', async (req) => {
        const { pedidoId } = req.data;

        const pedido = await SELECT.one.from(Pedidos).where({ ID: pedidoId });

        if (!pedido)
            return req.error(404, 'Pedido no encontrado');

        if (pedido.estado !== 'PENDIENTE')
            return req.error(400,
                `No se puede confirmar: estado actual es '${pedido.estado}'`);

        // Descontar stock por cada item del pedido
        const items = await SELECT.from(ItemsPedido)
                          .where({ pedido_ID: pedidoId });

        for (const item of items) {
            await UPDATE(Productos)
                  .set(`stock = stock - ${item.cantidad}`)
                  .where({ ID: item.producto_ID });
        }

        await UPDATE(Pedidos)
              .set({ estado: 'CONFIRMADO' })
              .where({ ID: pedidoId });

        return SELECT.one.from(Pedidos).where({ ID: pedidoId });
    });

    // ── FUNCTION: stockProducto ────────────────────────────────────────────
    // Devuelve el stock actual de un producto (solo lectura).
    this.on('stockProducto', async (req) => {
        const prod = await SELECT.one.from(Productos)
                         .where({ ID: req.data.productoId });
        return prod ? prod.stock : 0;
    });
});
