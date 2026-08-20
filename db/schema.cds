namespace logistica;

using { cuid, managed, Country } from '@sap/cds/common';

// ─── CATÁLOGO ──────────────────────────────────────────────────────────────

entity Categorias : cuid {
    nombre    : String(50) not null;
    productos : Association to many Productos on productos.categoria = $self;
}

entity Productos : cuid, managed {
    nombre      : String(100) not null;
    descripcion : String(500);
    precio      : Decimal(10,2) not null;
    categoria   : Association to Categorias;
    proveedor   : Association to Proveedores;
}

entity Proveedores : cuid, managed {
    nombre    : String(100) not null;
    pais      : Country;               // tipo estándar SAP (ISO 3166) → columna: pais_code
    email     : String(100);
    telefono  : String(20);
    productos : Association to many Productos on productos.proveedor = $self;
}

// ─── PEDIDOS ───────────────────────────────────────────────────────────────

entity Pedidos : cuid, managed {
    referencia : String(20);
    estado     : String(20) enum {
        PENDIENTE  = 'PENDIENTE';
        CONFIRMADO = 'CONFIRMADO';
        ENVIADO    = 'ENVIADO';
        ENTREGADO  = 'ENTREGADO';
        CANCELADO  = 'CANCELADO';
    } default 'PENDIENTE';
    cliente    : String(100) not null;
    total      : Decimal(10,2) default 0;
    items      : Composition of many ItemsPedido on items.pedido = $self;
}

entity ItemsPedido : cuid {
    pedido   : Association to Pedidos not null;
    producto : Association to Productos not null;
    cantidad : Integer not null;
    precio   : Decimal(10,2);    // se rellena automáticamente desde handler
    subtotal : Decimal(10,2);    // precio × cantidad, calculado en handler
}

// ─── TRAZABILIDAD DE LOTE ────────────────────────────────────────────────
entity LotesProveedor : cuid, managed {
    numeroLote         : String(30) not null;
    proveedor          : Association to Proveedores not null;
    producto           : Association to Productos not null;
    cantidadRecibida   : Decimal(10,3) not null;
    cantidadDisponible : Decimal(10,3) not null;   // para lógica FEFO en el handler
    fechaRecepcion     : Date not null;
    fechaCaducidad     : Date;                     // SLED
}

entity LotesInternos : cuid, managed {
    numeroLoteInterno : String(30) not null;
    productoTerminado : Association to Productos not null;
    fechaProduccion   : Date not null;
    cantidadProducida : Decimal(10,3) not null;
    origenes          : Composition of many ConsumosLote on origenes.loteInterno = $self;
}

entity ConsumosLote : cuid {
    loteInterno       : Association to LotesInternos not null;
    loteProveedor     : Association to LotesProveedor not null;
    cantidadConsumida : Decimal(10,3) not null;
}