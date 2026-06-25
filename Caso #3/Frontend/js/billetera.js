const API_URL = "/api";

let jugador = {};
let metodosPago = [];
let movimientos = [];
let movimientosVisibles = 10;
let filtroActual = "all";
let partnersAfiliados = [];

// =====================
// INICIALIZACIÓN
// =====================
async function inicializar() {
    const playerId = localStorage.getItem("playerId");
    if (!playerId) {
        window.location.href = "iniciarSesion.html";
        return;
    }

    try {
        const response = await fetch(`${API_URL}/billetera?playerId=${playerId}`);

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo cargar la billetera.");
        }

        const data = await response.json();

        jugadorGuardado = localStorage.getItem("jugadorData")
        if (jugadorGuardado) {
            jugador = JSON.parse(jugadorGuardado); 
            console.log("Jugador recuperado:", jugador);
        }
        metodosPago = data.metodosPago || [];
        movimientos = data.movimientos || [];
        partnersAfiliados = data.partners || [];

        renderHeader();
        renderBalances();
        renderMetodosPago();
        aplicarFiltroMovimientos();

    } catch (error) {
        console.error("Error cargando billetera:", error);
        Swal.fire({
            title: 'Error de Conexión',
            text: error.message || 'No se pudo sincronizar tu billetera.',
            icon: 'error',
            confirmButtonText: 'Entendido'
        });
    }
}

// =====================
// HEADER Y BALANCES
// =====================
function renderHeader() {
    document.getElementById("nav-username").textContent = jugador.nombre;
}

function renderBalances() {
    document.getElementById("balance-points").textContent = jugador.puntos.balance;
    document.getElementById("balance-money").textContent = `$${jugador.dineroReal.balance.toFixed(2)}`;
    document.getElementById("balance-reserved").textContent = `$${(jugador.dineroReservado ?? 0).toFixed(2)}`;
}

// =====================
// MÉTODOS DE PAGO
// =====================
const ICONOS_METODO = {
    credit_card: "bx-credit-card",
    debit_card: "bx-credit-card-front",
    bank_transfer: "bx-buildings",
    sinpe: "bx-mobile-alt",
    paypal: "bxl-paypal"
};

const LABELS_METODO = {
    credit_card: "Tarjeta de crédito",
    debit_card: "Tarjeta de débito",
    bank_transfer: "Transferencia bancaria",
    sinpe: "SINPE Móvil",
    paypal: "PayPal"
};

function renderMetodosPago() {
    const container = document.getElementById("payment-methods-list");
    document.getElementById("methods-count").textContent = metodosPago.length;

    if (metodosPago.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class='bx bx-credit-card'></i>
                Todavía no agregaste ningún método de pago.
            </div>`;
        return;
    }

    container.innerHTML = metodosPago.map(m => `
        <div class="payment-method-card">
            <div class="method-icon"><i class='bx ${ICONOS_METODO[m.tipo] || "bx-credit-card"}'></i></div>
            <div class="method-info">
                <div class="method-alias">${m.alias || LABELS_METODO[m.tipo] || m.tipo}</div>
                <div class="method-detail">${LABELS_METODO[m.tipo] || m.tipo} ${m.ultimosDigitos ? `•••• ${m.ultimosDigitos}` : ""}</div>
            </div>
            ${m.verificado
                ? `<span class="method-verified"><i class='bx bx-check-circle'></i> Verificado</span>`
                : `<span class="method-unverified"><i class='bx bx-x-circle'></i> No verificado</span>`
            }
            <button class="btn-remove-method" onclick="eliminarMetodo(${m.id})" title="Eliminar">
                <i class='bx bx-trash'></i>
            </button>
        </div>
    `).join("");

    // Actualizar selects de los modales
    const opciones = metodosPago.map(m =>
        `<option value="${m.id}">${m.alias || LABELS_METODO[m.tipo]} ${m.ultimosDigitos ? `(•••• ${m.ultimosDigitos})` : ""}</option>`
    ).join("");

    document.getElementById("dep-metodo").innerHTML = `<option value="">Seleccioná un método...</option>${opciones}`;
    document.getElementById("ret-metodo").innerHTML = `<option value="">Seleccioná un método...</option>${opciones}`;
}

async function eliminarMetodo(id) {
    const confirmacion = await Swal.fire({
        icon: 'warning',
        title: '¿Eliminar este método de pago?',
        showCancelButton: true,
        confirmButtonText: 'Sí, eliminar',
        cancelButtonText: 'Cancelar',
        confirmButtonColor: '#dc2626'
    });

    if (!confirmacion.isConfirmed) return;

    try {
        const response = await fetch(`${API_URL}/metodos-pago/${id}`, { method: "DELETE" });

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo eliminar el método de pago.");
        }

        metodosPago = metodosPago.filter(m => m.id !== id);
        renderMetodosPago();

        Swal.fire({ icon: 'success', title: 'Método eliminado', confirmButtonColor: '#7494ec', timer: 1500, showConfirmButton: false });

    } catch (error) {
        Swal.fire({ icon: 'error', title: 'Error', text: error.message, confirmButtonColor: '#d33' });
    }
}

// =====================
// MOVIMIENTOS / HISTORIAL
// =====================
const ICONOS_TX = {
    deposit: "bx-down-arrow-circle",
    withdrawal: "bx-up-arrow-circle",
    wager: "bx-target-lock",
    reward: "bx-trophy",
    commission: "bx-receipt",
    penalty: "bx-error-circle",
    points_purchase: "bx-cart",
    points_redemption: "bx-gift",
    refund: "bx-undo"
};

const LABELS_TX = {
    deposit: "Depósito",
    withdrawal: "Retiro",
    wager: "Predicción",
    reward: "Premio ganado",
    commission: "Comisión",
    penalty: "Penalización",
    points_purchase: "Compra de puntos",
    points_redemption: "Canje de puntos",
    refund: "Reembolso"
};

function aplicarFiltroMovimientos() {
    movimientosVisibles = 10;
    if (filtroActual === "all") {
        renderMovimientos(movimientos);
        return;
    }

    const listaFiltrada = movimientos.filter(m => {
        if (!m.moneda) return false;
        
        // .trim() quita los espacios, .toLowerCase() quita las mayúsculas
        const monedaLimpia = m.moneda.trim().toLowerCase();
        
        return monedaLimpia === filtroActual.toLowerCase();
    });

    renderMovimientos(listaFiltrada);
}

function renderMovimientos(lista) {
    const container = document.getElementById("transactions-list");
    const btnMas = document.getElementById("btn-cargar-mas");

    if (!lista || lista.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class='bx bx-history'></i>
                No hay movimientos para mostrar.
            </div>`;
        if (btnMas) btnMas.style.display = "none";
        return;
    }

    const bloque = lista.slice(0, movimientosVisibles);

    container.innerHTML = bloque.map(m => {
        const esCredito = m.monto > 0;
        const fecha = new Date(m.fecha).toLocaleString("es-CR", {
            day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
        });
        const simbolo = m.moneda.trim() === "PTS" ? "pts" : "$";
        const montoAbs = Math.abs(m.monto);
        const montoTexto = m.moneda.trim() === "PTS" ? `${montoAbs} ${simbolo}` : `${simbolo}${montoAbs.toFixed(2)}`;

        return `
        <div class="transaction-item">
            <div class="tx-icon ${esCredito ? "tx-credit" : "tx-debit"}">
                <i class='bx ${ICONOS_TX[m.tipo] || "bx-receipt"}'></i>
            </div>
            <div class="tx-info">
                <div class="tx-description">${m.descripcion || LABELS_TX[m.tipo] || m.tipo}</div>
                <div class="tx-meta">${LABELS_TX[m.tipo] || m.tipo} · ${fecha}</div>
            </div>
            <div class="tx-amount ${esCredito ? "positive" : "negative"}">
                ${esCredito ? "+" : "-"}${montoTexto}
            </div>
        </div>`;
    }).join("");

    window._movimientosFiltrados = lista;

    if (btnMas) {
        btnMas.style.display = movimientosVisibles < lista.length ? "inline-flex" : "none";
    }
}

// =====================
// MODALES — UTILIDADES
// =====================
function abrirModal(id) {
    document.getElementById(id).classList.add("show");
}

function cerrarModal(id) {
    document.getElementById(id).classList.remove("show");
}

document.querySelectorAll("[data-close]").forEach(btn => {
    btn.addEventListener("click", () => cerrarModal(btn.dataset.close));
});

document.querySelectorAll(".modal-overlay").forEach(overlay => {
    overlay.addEventListener("click", (e) => {
        if (e.target === overlay) overlay.classList.remove("show");
    });
});

// =====================
// DEPOSITAR
// =====================
document.getElementById("btn-depositar").addEventListener("click", () => {
    document.getElementById("dep-monto").value = "";
    document.getElementById("dep-metodo").value = "";
    document.querySelectorAll(".chip-amount").forEach(c => c.classList.remove("selected"));
    abrirModal("modal-deposito");
});

document.querySelectorAll("#modal-deposito .chip-amount").forEach(chip => {
    chip.addEventListener("click", () => {
        document.querySelectorAll("#modal-deposito .chip-amount").forEach(c => c.classList.remove("selected"));
        chip.classList.add("selected");
        document.getElementById("dep-monto").value = chip.dataset.amount;
    });
});

document.getElementById("btn-confirmar-deposito").addEventListener("click", async () => {
    const monto = parseFloat(document.getElementById("dep-monto").value);
    const metodoId = document.getElementById("dep-metodo").value;

    if (isNaN(monto) || monto <= 0) {
        Swal.fire({ icon: 'warning', title: 'Monto inválido', text: 'Ingresá un monto mayor a $0.', confirmButtonColor: '#7494ec' });
        return;
    }
    if (!metodoId) {
        Swal.fire({ icon: 'warning', title: 'Falta método de pago', text: 'Seleccioná con qué método querés depositar.', confirmButtonColor: '#7494ec' });
        return;
    }

    try {
        const response = await fetch(`${API_URL}/billetera/depositar`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                playerId: jugador.id,
                amount: monto,
                paymentMethodId: parseInt(metodoId)
            })
        });

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo procesar el depósito.");
        }

        Swal.fire({
            icon: 'success',
            title: '¡Depósito simulado exitoso!',
            text: `Se acreditaron $${monto.toFixed(2)} a tu billetera.`,
            confirmButtonColor: '#7494ec'
        });

        cerrarModal("modal-deposito");
        await inicializar();

    } catch (error) {
        Swal.fire({ icon: 'error', title: 'Error en el depósito', text: error.message, confirmButtonColor: '#d33' });
    }
});

// =====================
// RETIRAR
// =====================
document.getElementById("btn-retirar").addEventListener("click", () => {
    document.getElementById("ret-monto").value = "";
    document.getElementById("ret-metodo").value = "";
    document.getElementById("ret-disponible").textContent = `$${jugador.dineroReal.balance.toFixed(2)}`;
    abrirModal("modal-retiro");
});

document.getElementById("btn-confirmar-retiro").addEventListener("click", async () => {
    const monto = parseFloat(document.getElementById("ret-monto").value);
    const metodoId = document.getElementById("ret-metodo").value;

    if (isNaN(monto) || monto <= 0) {
        Swal.fire({ icon: 'warning', title: 'Monto inválido', text: 'Ingresá un monto mayor a $0.', confirmButtonColor: '#7494ec' });
        return;
    }
    if (monto > jugador.dineroReal.balance) {
        Swal.fire({ icon: 'error', title: 'Saldo insuficiente', text: `Tu saldo disponible es de $${jugador.dineroReal.balance.toFixed(2)}.`, confirmButtonColor: '#7494ec' });
        return;
    }
    if (!metodoId) {
        Swal.fire({ icon: 'warning', title: 'Falta método de retiro', text: 'Seleccioná a dónde querés retirar el dinero.', confirmButtonColor: '#7494ec' });
        return;
    }

    try {
        const response = await fetch(`${API_URL}/billetera/retirar`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                playerId: jugador.id,
                amount: monto,
                paymentMethodId: parseInt(metodoId)
            })
        });

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo procesar el retiro.");
        }

        Swal.fire({
            icon: 'success',
            title: '¡Retiro simulado exitoso!',
            text: `Se procesó tu retiro de $${monto.toFixed(2)}.`,
            confirmButtonColor: '#7494ec'
        });

        cerrarModal("modal-retiro");
        await inicializar();

    } catch (error) {
        Swal.fire({ icon: 'error', title: 'Error en el retiro', text: error.message, confirmButtonColor: '#d33' });
    }
});

// =====================
// AGREGAR MÉTODO DE PAGO
// =====================
document.getElementById("btn-add-method").addEventListener("click", () => {
    document.getElementById("metodo-alias").value = "";
    document.getElementById("metodo-numero").value = "";
    document.getElementById("metodo-tipo").value = "credit_card";
    abrirModal("modal-metodo");
});

document.getElementById("metodo-tipo").addEventListener("change", (e) => {
    const numeroBox = document.getElementById("metodo-numero-box");
    numeroBox.style.display = e.target.value === "sinpe" || e.target.value === "paypal" ? "none" : "flex";
});

document.getElementById("btn-guardar-metodo").addEventListener("click", async () => {
    const tipo = document.getElementById("metodo-tipo").value;
    const alias = document.getElementById("metodo-alias").value.trim();
    const numero = document.getElementById("metodo-numero").value.trim();

    if (!alias) {
        Swal.fire({ icon: 'warning', title: 'Falta el alias', text: 'Ponele un nombre a este método de pago.', confirmButtonColor: '#7494ec' });
        return;
    }

    try {
        const response = await fetch(`${API_URL}/metodos-pago`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                playerId: jugador.id,
                methodType: tipo,
                alias: alias,
                accountDetails: numero || null
            })
        });

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo guardar el método de pago.");
        }

        Swal.fire({
            icon: 'success',
            title: '¡Método agregado!',
            confirmButtonColor: '#7494ec',
            timer: 1500,
            showConfirmButton: false
        });

        cerrarModal("modal-metodo");
        await inicializar();

    } catch (error) {
        Swal.fire({ icon: 'error', title: 'Error', text: error.message, confirmButtonColor: '#d33' });
    }
});

// =====================
// CANJEAR PUNTOS
// =====================
document.getElementById("btn-canjear-pts").addEventListener("click", () => {
    document.getElementById("canje-disponible").textContent = jugador.puntos,balance;
    renderPartners();
    abrirModal("modal-canje");
});

function renderPartners() {
    const container = document.getElementById("partners-list");

    if (!partnersAfiliados || partnersAfiliados.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class='bx bx-store'></i>
                No hay socios afiliados disponibles por ahora.
            </div>`;
        return;
    }

    container.innerHTML = partnersAfiliados.map(p => {
        const sinPuntos = jugador.puntos.balance < p.costoPuntos;
        return `
        <div class="partner-card">
            <div class="partner-logo"><i class='bx bx-store-alt'></i></div>
            <div class="partner-info">
                <div class="partner-name">${p.nombre}</div>
                <div class="partner-reward">${p.detalleRecompensa} · ${p.costoPuntos} pts</div>
            </div>
            <button class="btn-redeem" ${sinPuntos ? "disabled" : ""} onclick="canjearPuntos(${p.id}, ${p.costoPuntos})">
                Canjear
            </button>
        </div>`;
    }).join("");
}

async function canjearPuntos(partnerId, costoPuntos) {
    const confirmacion = await Swal.fire({
        icon: 'question',
        title: '¿Confirmar canje?',
        text: `Se descontarán ${costoPuntos} pts de tu balance.`,
        showCancelButton: true,
        confirmButtonText: 'Sí, canjear',
        cancelButtonText: 'Cancelar',
        confirmButtonColor: '#7494ec'
    });

    if (!confirmacion.isConfirmed) return;

    try {
        const response = await fetch(`${API_URL}/billetera/canjear-puntos`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                playerId: jugador.id,
                partnerId: partnerId
            })
        });

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo procesar el canje.");
        }

        Swal.fire({
            icon: 'success',
            title: '¡Canje realizado!',
            text: 'Revisá tu correo para los detalles de la recompensa.',
            confirmButtonColor: '#7494ec'
        });

        cerrarModal("modal-canje");
        await inicializar();

    } catch (error) {
        Swal.fire({ icon: 'error', title: 'Error en el canje', text: error.message, confirmButtonColor: '#d33' });
    }
}

// =====================
// EVENTOS GENERALES
// =====================
document.getElementById("btn-logout").addEventListener("click", () => {
    if (confirm("¿Seguro que querés cerrar sesión?")) {
        localStorage.removeItem("playerId");
        window.location.href = "iniciarSesion.html";
    }
});

document.getElementById("filter-tabs").addEventListener("click", (e) => {
    const tab = e.target.closest(".filter-tab");
    if (!tab) return;
    document.querySelectorAll(".filter-tab").forEach(t => t.classList.remove("active"));
    tab.classList.add("active");
    filtroActual = tab.dataset.filter;
    aplicarFiltroMovimientos();
});

document.getElementById("btn-cargar-mas").addEventListener("click", () => {
    movimientosVisibles += 10;
    renderMovimientos(window._movimientosFiltrados || []);
});

// =====================
// INIT
// =====================
document.addEventListener("DOMContentLoaded", inicializar);
