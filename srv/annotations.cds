using LogisticaService as service from './logistica-service';

// ═══════════════════════════════════════════════════════════════
// ETIQUETAS DE CAMPOS
// ═══════════════════════════════════════════════════════════════

annotate service.Productos with {
    nombre      @title: 'Nombre';
    descripcion @title: 'Descripción';
    precio      @title: 'Precio (€)';
    categoria   @title: 'Categoría';
    proveedor   @title: 'Proveedor';
}

annotate service.Pedidos with {
    referencia  @title: 'Referencia';
    estado      @title: 'Estado';
    cliente     @title: 'Cliente';
    total       @title: 'Total (€)';
}

annotate service.Proveedores with {
    nombre      @title: 'Nombre';
    email       @title: 'Email';
    telefono    @title: 'Teléfono';
    pais        @title: 'País';
}

// ═══════════════════════════════════════════════════════════════
// PRODUCTOS — Lista + Página de detalle
// ═══════════════════════════════════════════════════════════════

annotate service.Productos with @(
    UI: {

        HeaderInfo: {
            TypeName:       'Producto',
            TypeNamePlural: 'Productos',
            Title:          { Value: nombre },
            Description:    { Value: descripcion }
        },

        SelectionFields: [ nombre, precio, categoria_ID ],

        LineItem: [
            { Value: nombre,           Label: 'Nombre' },
            { Value: precio,           Label: 'Precio (€)' },
            { Value: categoria.nombre, Label: 'Categoría' },
            { Value: proveedor.nombre, Label: 'Proveedor' }
        ],

        FieldGroup #Ficha: {
            Label: 'Ficha del Producto',
            Data: [
                { Value: nombre },
                { Value: descripcion },
                { Value: precio }
            ]
        },

        FieldGroup #Clasificacion: {
            Label: 'Clasificación',
            Data: [
                { Value: categoria_ID },
                { Value: proveedor_ID }
            ]
        },

        Facets: [
            {
                $Type:  'UI.ReferenceFacet',
                Label:  'Ficha',
                Target: '@UI.FieldGroup#Ficha'
            },
            {
                $Type:  'UI.ReferenceFacet',
                Label:  'Clasificación',
                Target: '@UI.FieldGroup#Clasificacion'
            }
        ]
    }
);

// ═══════════════════════════════════════════════════════════════
// PEDIDOS — Lista + Página de detalle con líneas
// ═══════════════════════════════════════════════════════════════

annotate service.Pedidos with @(
    UI: {

        HeaderInfo: {
            TypeName:       'Pedido',
            TypeNamePlural: 'Pedidos',
            Title:          { Value: referencia },
            Description:    { Value: cliente }
        },

        SelectionFields: [ estado, cliente, referencia ],

        LineItem: [
            { Value: referencia,  Label: 'Referencia' },
            { Value: cliente,     Label: 'Cliente' },
            { Value: estado,      Label: 'Estado' },
            { Value: total,       Label: 'Total (€)' },
            { Value: createdAt,   Label: 'Fecha Creación' }
        ],

        FieldGroup #InfoPedido: {
            Label: 'Datos del Pedido',
            Data: [
                { Value: referencia },
                { Value: cliente },
                { Value: estado },
                { Value: total }
            ]
        },

        Facets: [
            {
                $Type:  'UI.ReferenceFacet',
                Label:  'Pedido',
                Target: '@UI.FieldGroup#InfoPedido'
            },
            {
                $Type:  'UI.ReferenceFacet',
                Label:  'Líneas',
                Target: 'items/@UI.LineItem'
            }
        ]
    }
);

// ═══════════════════════════════════════════════════════════════
// ITEMS DEL PEDIDO — columnas cuando se ven dentro del Pedido
// ═══════════════════════════════════════════════════════════════

annotate service.ItemsPedido with @(
    UI: {
        LineItem: [
            { Value: producto.nombre, Label: 'Producto' },
            { Value: cantidad,        Label: 'Cantidad' },
            { Value: precio,          Label: 'Precio Unit. (€)' },
            { Value: subtotal,        Label: 'Subtotal (€)' }
        ]
    }
);
