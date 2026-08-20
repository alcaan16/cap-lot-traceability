// srv/logistica-service.js
const cds = require('@sap/cds');

module.exports = cds.service.impl(async function () {

const { Pedidos, Productos, ItemsPedido, LotesProveedor, LotesInternos, ConsumosLote } = this.entities;

    // ── BEFORE CREATE ItemsPedido ──────────────────────────────────────────
    this.before('CREATE', ItemsPedido, async (req) => {
        const { producto_ID, cantidad } = req.data;

        const prod = await SELECT.one.from(Productos)
                        .where({ ID: producto_ID });

        if (!prod)
            return req.error(404, `Producto no encontrado: ${producto_ID}`);

        req.data.precio   = prod.precio;
        req.data.subtotal = prod.precio * cantidad;
    });

    // ── AFTER CREATE ItemsPedido ───────────────────────────────────────────
    this.after('CREATE', ItemsPedido, async (data) => {
        const items = await SELECT.from(ItemsPedido)
                           .where({ pedido_ID: data.pedido_ID });

        const total = items.reduce((sum, item) => sum + (item.subtotal || 0), 0);

        await UPDATE(Pedidos)
              .set({ total })
              .where({ ID: data.pedido_ID });
    });

    // ── ACTION: confirmarPedido ────────────────────────────────────────────
    // Cambia el estado a CONFIRMADO. El descuento de stock se elimina: no
    // hay conexión diseñada entre Pedidos y el sistema de lotes (Pedidos
    // queda como material de apoyo, fuera del alcance de trazabilidad).
    this.on('confirmarPedido', async (req) => {
        const { pedidoId } = req.data;

        const pedido = await SELECT.one.from(Pedidos).where({ ID: pedidoId });

        if (!pedido)
            return req.error(404, 'Pedido no encontrado');

        if (pedido.estado !== 'PENDIENTE')
            return req.error(400,
                `No se puede confirmar: estado actual es '${pedido.estado}'`);

        await UPDATE(Pedidos)
              .set({ estado: 'CONFIRMADO' })
              .where({ ID: pedidoId });

        return SELECT.one.from(Pedidos).where({ ID: pedidoId });
    });

    // ── ACTION: registrarProduccion ────────────────────────────────────────
    const { uuid } = cds.utils;

    this.on('registrarProduccion', async (req) => {
        const { productoId, cantidadProducida, fechaProduccion } = req.data;

        if (!cantidadProducida || cantidadProducida <= 0)
            return req.error(400, 'La cantidad producida debe ser mayor que cero');

        const fechaCompacta = fechaProduccion.replace(/-/g, '');
        const lotesDelDia = await SELECT.from(LotesInternos).where({ fechaProduccion });
        const secuencial = String(lotesDelDia.length + 1).padStart(3, '0');
        const numeroLoteInterno = `LI-${fechaCompacta}-${secuencial}`;

        const lotesDisponibles = await SELECT.from(LotesProveedor)
            .where({ producto_ID: productoId, cantidadDisponible: { '>': 0 } })
            .orderBy('fechaCaducidad asc, fechaRecepcion asc');

        const totalDisponible = lotesDisponibles.reduce((sum, l) => sum + l.cantidadDisponible, 0);

        if (totalDisponible < cantidadProducida)
            return req.error(400,
                `Stock insuficiente en lotes de proveedor. Disponible: ${totalDisponible}, necesario: ${cantidadProducida}`);

        const loteInternoId = uuid();

        await INSERT.into(LotesInternos).entries({
            ID                   : loteInternoId,
            numeroLoteInterno,
            productoTerminado_ID : productoId,
            fechaProduccion,
            cantidadProducida
        });

        let pendiente = cantidadProducida;

        for (const lote of lotesDisponibles) {
            if (pendiente <= 0) break;

            const consumir = Math.min(lote.cantidadDisponible, pendiente);

            await INSERT.into(ConsumosLote).entries({
                loteInterno_ID   : loteInternoId,
                loteProveedor_ID : lote.ID,
                cantidadConsumida: consumir
            });

            await UPDATE(LotesProveedor, lote.ID)
                .set({ cantidadDisponible: lote.cantidadDisponible - consumir });

            pendiente -= consumir;
        }

        return SELECT.one.from(LotesInternos).where({ ID: loteInternoId });
    });

    // ── FUNCTION: stockProducto ──────────────────────────────────────────
    this.on('stockProducto', async (req) => {
        const { productoId } = req.data;

        const lotes = await SELECT.from(LotesProveedor)
            .where({ producto_ID: productoId });

        return lotes.reduce((sum, l) => sum + (l.cantidadDisponible || 0), 0);
    });
});