const API_URL = "/api";

let jugador = {};
let todasLasPredicciones = [];
let prediccionesVisibles = 10;
let filtroActual = "all";
let busquedaActual = "";

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
        const response = await fetch(`${API_URL}/misPredicciones?playerId=${playerId}`);

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudieron cargar tus predicciones.");
        }

        const data = await response.json();

        const jugadorGuardado = localStorage.getItem("jugadorData");
        if (jugadorGuardado) {
            jugador = JSON.parse(jugadorGuardado);
            console.log("Jugador recuperado:", jugador);
        }
        todasLasPredicciones = data.predicciones;
        console.log(todasLasPredicciones);

        renderHeader();
        renderStats();
        aplicarFiltros();

    } catch (error) {
        console.error("Error cargando mis predicciones:", error);
        Swal.fire({
            title: 'Error de Conexión',
            text: error.message || 'No se pudieron cargar tus predicciones.',
            icon: 'error',
            confirmButtonText: 'Entendido'
        });
    }
}

// =====================
// HEADER
// =====================
function renderHeader() {
    document.getElementById("nav-username").textContent = jugador.nombre;
    document.getElementById("header-points").textContent = jugador.puntos.balance;
    document.getElementById("header-money").textContent = jugador.dineroReal.balance.toFixed(2);
}

// =====================
// STATS
// =====================
function renderStats() {
    const total = todasLasPredicciones.length;
    const pendientes = todasLasPredicciones.filter(p => p.estado === "pending").length;
    const ganadas = todasLasPredicciones.filter(p => p.estado === "won").length;
    const resueltas = todasLasPredicciones.filter(p => p.estado === "won" || p.estado === "lost").length;
    const pct = resueltas > 0 ? Math.round((ganadas / resueltas) * 100) : 0;

    document.getElementById("stat-total").textContent = total;
    document.getElementById("stat-pending").textContent = pendientes;
    document.getElementById("stat-won").textContent = ganadas;
    document.getElementById("stat-pct").textContent = `${pct}%`;
}

// =====================
// FILTROS Y BÚSQUEDA
// =====================
function aplicarFiltros() {
    prediccionesVisibles = 10;
    let lista = todasLasPredicciones;

    if (filtroActual !== "all") {
        lista = lista.filter(p => p.estado === filtroActual);
    }

    if (busquedaActual.trim() !== "") {
        const q = busquedaActual.toLowerCase();
        lista = lista.filter(p =>
            p.sujeto.toLowerCase().includes(q) ||
            p.texto.toLowerCase().includes(q)
        );
    }

    renderPredicciones(lista);
}

// =====================
// RENDER PREDICCIONES
// =====================
function renderPredicciones(lista) {
    const container = document.getElementById("predictions-list");
    const btnMas = document.getElementById("btn-cargar-mas");

    if (!lista || lista.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class='bx bx-target-lock'></i>
                <strong>Sin predicciones</strong>
                <p>No hay predicciones que coincidan con tu filtro o búsqueda.</p>
            </div>`;
        if (btnMas) btnMas.style.display = "none";
        return;
    }

    const bloque = lista.slice(0, prediccionesVisibles);

    container.innerHTML = bloque.map(p => {
        const fechaCreada = formatearFecha(p.creada);
        const { stateClass, stateLabel } = getEstadoInfo(p.estado);
        const votoClass = p.voto ? "vote-yes" : "vote-no";
        const votoIcon = p.voto ? "bx-check" : "bx-x";
        const votoLabel = p.voto ? "Sí" : "No";

        const monto = Number(p.montoApostado) || 0;

        const moneda = p.moneda === "PTS" ? "pts" : "$";

        const montoTexto = p.moneda === "PTS"
            ? `${monto} ${moneda}`
            : `${moneda}${monto.toFixed(2)}`;

        let amountClass = "";
        let amountTexto = `Apostaste ${montoTexto}`;

        if (p.estado === "won") {
            amountClass = "gain";
            const ganado = p.moneda === "PTS"
                ? `+${p.montoGanado} pts`
                : `+$${p.montoGanado.toFixed(2)}`;
            amountTexto = ganado;
        } else if (p.estado === "lost") {
            amountClass = "loss";
            amountTexto = `-${montoTexto}`;
        } else if (p.estado === "void") {
            amountTexto = `Reembolso: ${montoTexto}`;
        }

        return `
        <div class="prediction-card ${p.estado}" onclick="abrirDetalle(${p.predictionId})">
            <div class="pred-left">
                <div class="pred-subject">
                    <i class='bx bxs-user'></i> ${p.sujeto}
                </div>
                <div class="pred-text">"${p.propositionText}"</div>
                <div class="pred-meta">
                    <span><i class='bx bx-user'></i> Por ${p.autor}</span>
                    <span><i class='bx bx-calendar'></i> ${fechaCreada}</span>
                </div>
            </div>
            <div class="pred-right">
                <span class="vote-badge ${votoClass}"><i class='bx ${votoIcon}'></i> ${votoLabel}</span>
                <span class="state-badge state-${p.estado}">${stateLabel}</span>
                <span class="pred-amount ${amountClass}">${amountTexto}</span>
            </div>
        </div>`;
    }).join("");

    window._listaFiltrada = lista;

    if (btnMas) {
        btnMas.style.display = prediccionesVisibles < lista.length ? "inline-flex" : "none";
    }
}

// =====================
// HELPERS
// =====================
function getEstadoInfo(estado) {
    const mapa = {
        pending: { stateClass: "pending", stateLabel: "En curso" },
        won: { stateClass: "won", stateLabel: "Ganaste" },
        lost: { stateClass: "lost", stateLabel: "Perdiste" },
        void: { stateClass: "void", stateLabel: "Anulada" }
    };
    return mapa[estado] || mapa.pending;
}

function formatearFecha(fechaIso) {
    if (!fechaIso) return "—";
    return new Date(fechaIso).toLocaleString("es-CR", {
        day: "2-digit", month: "short", year: "numeric",
        hour: "2-digit", minute: "2-digit"
    });
}

// =====================
// MODAL DETALLE
// =====================
function abrirDetalle(id) {
    const p = todasLasPredicciones.find(x => x.predictionId === id);
    if (!p) return;

    document.getElementById("det-sujeto").textContent = p.sujeto;
    document.getElementById("det-texto").textContent = `"${p.propositionText}"`;

    // Estado pill
    const { stateClass, stateLabel } = getEstadoInfo(p.estado);
    const iconos = { pending: "bx-time-five", won: "bx-trophy", lost: "bx-x-circle", void: "bx-minus-circle" };
    document.getElementById("det-estado-pill").className = `status-pill ${stateClass}`;
    document.getElementById("det-estado-pill").innerHTML = `<i class='bx ${iconos[p.estado] || "bx-time-five"}'></i> ${stateLabel}`;

    // Mi predicción
    const moneda = p.moneda === "PTS" ? "pts" : "USD";
    const montoTexto = p.moneda === "PTS" ? `${p.montoApostado} pts` : `$${p.montoApostado.toFixed(2)}`;

    document.getElementById("det-mi-prediccion").innerHTML = `
        <div class="pred-summary-row">
            <span class="label">Tu voto</span>
            <span class="value">${p.voto ? "Sí se cumple" : "No se cumple"}</span>
        </div>
        <div class="pred-summary-row">
            <span class="label">Monto apostado</span>
            <span class="value">${montoTexto}</span>
        </div>
        <div class="pred-summary-row">
            <span class="label">Moneda</span>
            <span class="value">${moneda === "pts" ? "Puntos" : "Dinero real"}</span>
        </div>
    `;

    // Resultado
    const resultadoSection = document.getElementById("det-resultado-section");
    const resultadoEl = document.getElementById("det-resultado");

    if (p.estado === "pending") {
        resultadoSection.style.display = "none";
    } else {
        resultadoSection.style.display = "flex";

        if (p.estado === "void") {
            resultadoEl.innerHTML = `
                <div class="breakdown-row">
                    <span class="bd-label">Estado</span>
                    <span class="bd-value bd-neutral">Reembolso — proposición anulada</span>
                </div>
                <div class="breakdown-row">
                    <span class="bd-label">Monto devuelto</span>
                    <span class="bd-value bd-neutral">+${montoTexto}</span>
                </div>`;
        } else if (p.estado === "won") {
            const ganadoTexto = p.moneda === "PTS" ? `+${p.montoGanado} pts` : `+$${p.montoGanado.toFixed(2)}`;
            resultadoEl.innerHTML = `
                <div class="breakdown-row">
                    <span class="bd-label">Resultado</span>
                    <span class="bd-value bd-positive">Predicción correcta 🎉</span>
                </div>
                <div class="breakdown-row">
                    <span class="bd-label">Ganancia neta</span>
                    <span class="bd-value bd-positive">${ganadoTexto}</span>
                </div>`;
        } else {
            resultadoEl.innerHTML = `
                <div class="breakdown-row">
                    <span class="bd-label">Resultado</span>
                    <span class="bd-value bd-negative">Predicción incorrecta</span>
                </div>
                <div class="breakdown-row">
                    <span class="bd-label">Monto perdido</span>
                    <span class="bd-value bd-negative">-${montoTexto}</span>
                </div>`;
        }
    }

    // Fechas
    document.getElementById("det-fechas").innerHTML = `
        <div class="date-item">
            <span class="date-label">Predicción realizada</span>
            <span class="date-value">${formatearFecha(p.creada)}</span>
        </div>
        <div class="date-item">
            <span class="date-label">Cierre de predicciones</span>
            <span class="date-value">${formatearFecha(p.cierre)}</span>
        </div>
        ${p.resuelta ? `
        <div class="date-item">
            <span class="date-label">Resuelta</span>
            <span class="date-value">${formatearFecha(p.resuelta)}</span>
        </div>` : ""}
    `;

    document.getElementById("modal-detalle").classList.add("show");
}

function cerrarDetalle() {
    document.getElementById("modal-detalle").classList.remove("show");
}

// =====================
// EVENTOS UI
// =====================
document.getElementById("modal-close").addEventListener("click", cerrarDetalle);
document.getElementById("btn-cerrar-detalle").addEventListener("click", cerrarDetalle);

document.getElementById("modal-detalle").addEventListener("click", (e) => {
    if (e.target === document.getElementById("modal-detalle")) cerrarDetalle();
});

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
    aplicarFiltros();
});

document.getElementById("search-input").addEventListener("input", (e) => {
    busquedaActual = e.target.value;
    aplicarFiltros();
});

document.getElementById("btn-cargar-mas").addEventListener("click", () => {
    prediccionesVisibles += 10;
    renderPredicciones(window._listaFiltrada || []);
});

// =====================
// INIT
// =====================
document.addEventListener("DOMContentLoaded", inicializar);
