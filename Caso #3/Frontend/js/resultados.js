const API_URL = "/api";

let jugador = {};
let todosLosResultados = [];
let resultadosVisibles = 10;
let filtroActual = "all";
let busquedaActual = "";

async function inicializar() {
    const playerId = localStorage.getItem("playerId");
    if (!playerId) {
        window.location.href = "iniciarSesion.html";
        return;
    }

    try {
        const response = await fetch(`${API_URL}/getResultados?playerId=${playerId}`);

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudieron cargar los resultados.");
        }

        const data = await response.json();

        jugadorGuardado = localStorage.getItem("jugadorData")
        if (jugadorGuardado) {
            jugador = JSON.parse(jugadorGuardado); 
            console.log("Jugador recuperado:", jugador);
        }
        todosLosResultados = data.resultados;

        renderHeader();
        renderStats();
        aplicarFiltros();

    } catch (error) {
        console.error("Error cargando resultados:", error);
        Swal.fire({
            title: 'Error de Conexión',
            text: error.message || 'No se pudieron cargar los resultados.',
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
// STATS DE DESEMPEÑO
// =====================
function renderStats() {
    // Solo cuenta las proposiciones donde el jugador participó
    const conPrediccion = todosLosResultados;
    const ganadas = conPrediccion.filter(r => r.isWinner === true);
    const perdidas = conPrediccion.filter(r => r.isWinner === false);
    const pct = conPrediccion.length > 0
        ? Math.round((ganadas.length / conPrediccion.length) * 100)
        : 0;

    document.getElementById("stat-total").textContent = conPrediccion.length;
    document.getElementById("stat-won").textContent = ganadas.length;
    document.getElementById("stat-lost").textContent = perdidas.length;
    document.getElementById("stat-pct").textContent = `${pct}%`;
}

// =====================
// FILTROS Y BÚSQUEDA
// =====================
function aplicarFiltros() {
    resultadosVisibles = 10;

    let lista = todosLosResultados;

    // Filtro de pestaña
    if (filtroActual === "won") {
        lista = lista.filter(r => r.isWinner === true);
    } else if (filtroActual === "lost") {
        lista = lista.filter(r => r.isWinner === false);
    } else if (filtroActual === "void") {
        lista = lista.filter(r => r.resultadoProposicion === "Cancelada");
    } else if (filtroActual === "no-pred") {
        lista = lista.filter(r => r.miEleccion === null || r.miEleccion === undefined);
    }

    // Búsqueda por texto
    if (busquedaActual.trim() !== "") {
        const q = busquedaActual.toLowerCase();
        lista = lista.filter(r =>
            r.sujeto.toLowerCase().includes(q) ||
            r.texto.toLowerCase().includes(q)
        );
    }

    renderResultados(lista);
}

// =====================
// RENDER RESULTADOS
// =====================
function renderResultados(lista) {
    const container = document.getElementById("results-list");
    const btnMas = document.getElementById("btn-cargar-mas");

    if (!lista || lista.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class='bx bx-trophy'></i>
                <strong>Sin resultados</strong>
                <p>No hay resultados que coincidan con tu filtro o búsqueda.</p>
            </div>`;
        if (btnMas) btnMas.style.display = "none";
        return;
    }

    const bloque = lista.slice(0, resultadosVisibles);

    container.innerHTML = bloque.map(r => {
        const fechaCierre = new Date(r.cierrePredicciones).toLocaleString("es-CR", {
            day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
        });

        // Clase de la card según resultado propio
        const cardClass = r.isWinner || "no-pred";

        // Badge resultado oficial
        const { badgeClass, badgeIcon, badgeLabel } = getBadgeResultado(r.resultadoProposicion);

        // Badge mi predicción
        const { myClass, myLabel } = getBadgeMiPrediccion(r);

        // Ganancia/pérdida resumida
        const { gainText, gainClass } = calcularGananciaResumida(r);

        const fechaFormateada = formatearFecha(r.fechaResolucion);

        return `
        <div class="result-card ${cardClass}" onclick="abrirDetalle(${r.predictionId})">
            <div class="res-left">
                <div class="res-subject">
                    <i class='bx bxs-user'></i> ${r.NombreDelSujeto}
                </div>
                <div class="res-text">"${r.DescripcionProposicion}"</div>
                <div class="res-meta">
                    <span><i class='bx bx-user'></i> Por ${r.CreadorProposicion}</span>
                    <span><i class='bx bx-calendar-check'></i> Cierre: ${fechaCierre}</span>
                </div>
            </div>
            <div class="res-right">
                <div class="outcome-badge ${badgeClass}">
                    <i class='bx ${badgeIcon}'></i> ${badgeLabel}
                </div>
                <span class="my-badge ${myClass}">${myLabel}</span>
                <span class="res-gain ${gainClass}">${gainText}</span>
                <button class="btn-detail" onclick="event.stopPropagation(); abrirDetalle(${r.predictionId})">
                    <i class='bx bx-info-circle'></i> Ver detalle
                </button>
            </div>
        </div>`;
    }).join("");

    window._listaFiltrada = lista;

    if (btnMas) {
        btnMas.style.display = resultadosVisibles < lista.length ? "inline-flex" : "none";
    }
}

// =====================
// HELPERS DE BADGE
// =====================
function getBadgeResultado(resultado) {
    if (resultado === "Se cumplió") {
        return { badgeClass: "cumplida", badgeIcon: "bx-check-circle", badgeLabel: "Se cumplió" };
    } else if (resultado === "No se cumplió") {
        return { badgeClass: "no-cumplida", badgeIcon: "bx-x-circle", badgeLabel: "No se cumplió" };
    } else if (resultado === "Cancelada") {
        return { badgeClass: "cancelada", badgeIcon: "bx-x-circle", badgeLabel: "Cancelada" };
    } 
    return { badgeClass: "pendiente", badgeIcon: "bx-minus-circle", badgeLabel: "Pendiente de resolución" };
}

function getBadgeMiPrediccion(r) {
    if (r.miEleccion === null || r.miEleccion === undefined) {
        return { myClass: "my-none", myLabel: "Sin predicción" };
    }
    if (r.isWinner === true)  return { myClass: "my-won",  myLabel: "✓ Ganaste" };
    if (r.isWinner === false) return { myClass: "my-lost", myLabel: "✗ Perdiste" };
    if(r.resultadoProposicion === "Cancelada") return { myClass: "my-cancelled", myLabel: "↩ Reembolsado"};
    return { myClass: "my-void", myLabel: "⧖ Pendiente" };
}

function calcularGananciaResumida(r) {
    if (r.miEleccion === null || r.miEleccion === undefined) {
        return { gainText: "—", gainClass: "neutral" };
    }
    if (r.miEleccion === "Cancelada") {
        return { gainText: "Reembolso", gainClass: "neutral" };
    }

    const ganancia = r.GananciaNeta ?? 0;
    const esGanador = r.isWinner === true;

    const divisaLimpia = r.Divisa ? r.Divisa.trim() : "";
    let textoFormateado;

    if (divisaLimpia === 'PTS') {
        textoFormateado = `${ganancia} pts`;
    } else {
        textoFormateado = `$${ganancia.toFixed(2)}`;
    }

    return {
        gainText: `${esGanador ? '+' : ''}${textoFormateado}`,
        gainClass: esGanador ? "positive" : "negative"
    };
}

// =====================
// MODAL DETALLE
// =====================
function abrirDetalle(id) {
    const r = todosLosResultados.find(x => x.predictionId === id);
    if (!r) return;

    const fechaCierre = new Date(r.cierrePredicciones).toLocaleString("es-CR", {
        day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
    });

    const fechaCreacion = new Date(r.fechaCreacion).toLocaleString("es-CR", {
        day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
    });

    const fechaAceptacion = new Date(r.fechaAceptacion).toLocaleString("es-CR", {
        day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
    });

    // Header
    document.getElementById("det-sujeto").textContent = r.NombreDelSujeto;
    document.getElementById("det-texto").textContent = `"${r.DescripcionProposicion}"`;

    // Resultado oficial
    console.log(r.resultadoProposicion);
    const { badgeClass, badgeIcon, badgeLabel } = getBadgeResultado(r.resultadoProposicion);
    document.getElementById("det-resultado-pill").className = `result-pill ${badgeClass}`;
    document.getElementById("det-resultado-pill").innerHTML = `<i class='bx ${badgeIcon}'></i> ${badgeLabel}`;

    // Mi predicción
    const miPredEl = document.getElementById("det-mi-prediccion");
    if (r.miEleccion === null || r.miEleccion === undefined) {
        miPredEl.innerHTML = `<p class="pred-no-pred">No realizaste ninguna predicción en esta proposición.</p>`;
    } else {
        const votoTexto = r.miEleccion === "Apuesta a favor (SÍ)" ? "Sí se cumple" : "No se cumple";
        const apuesta = r.montoInvertido;
        const divisaLimpia = r.Divisa ? r.Divisa.trim() : "";


        miPredEl.innerHTML = `
            <div class="pred-summary-row">
                <span class="label">Tu voto</span>
                <span class="value">${votoTexto}</span>
            </div>
            ${divisaLimpia === 'PTS' ? `
            <div class="pred-summary-row">
                <span class="label">Puntos apostados</span>
                <span class="value">${apuesta} pts</span>
            </div>` : ""}
            ${divisaLimpia === 'USD' ? `
            <div class="pred-summary-row">
                <span class="label">Dinero apostado</span>
                <span class="value">$${apuesta.toFixed(2)}</span>
            </div>` : ""}
        `;
    }

    // Balance breakdown
    const balanceSection = document.getElementById("det-balance-section");
    const balanceEl = document.getElementById("det-balance");

    if (r.miEleccion === null || r.miEleccion === undefined) {
        balanceSection.style.display = "none";
    } else {
        balanceSection.style.display = "flex";

        if (r.resultado === "anulada") {
            const refPts = r.puntosApostados ?? 0;
            const refDin = r.dineroApostado ?? 0;
            balanceEl.innerHTML = `
                <div class="breakdown-row">
                    <span class="bd-label">Estado</span>
                    <span class="bd-value bd-neutral">Reembolso — proposición anulada</span>
                </div>
                ${refPts > 0 ? `<div class="breakdown-row">
                    <span class="bd-label">Puntos devueltos</span>
                    <span class="bd-value bd-neutral">+${refPts} pts</span>
                </div>` : ""}
                ${refDin > 0 ? `<div class="breakdown-row">
                    <span class="bd-label">Dinero devuelto</span>
                    <span class="bd-value bd-neutral">+$${refDin.toFixed(2)}</span>
                </div>` : ""}`;
        } else if (r.isWinner === true) {
            const ganancia = r.GananciaNeta ?? 0;
            const comision = r.comisionDinero ?? 0;
            const divisaLimpia = r.Divisa ? r.Divisa.trim() : "";

            balanceEl.innerHTML = `
                <div class="breakdown-row">
                    <span class="bd-label">Resultado</span>
                    <span class="bd-value bd-positive">Predicción correcta 🎉</span>
                </div>
                ${divisaLimpia === 'PTS' ? `<div class="breakdown-row">
                    <span class="bd-label">Puntos ganados (neto)</span>
                    <span class="bd-value bd-positive">+${ganancia} pts</span>
                </div>` : ""}
                ${divisaLimpia === 'USD' ? `<div class="breakdown-row">
                    <span class="bd-label">Dinero ganado (neto)</span>
                    <span class="bd-value bd-positive">+$${ganancia.toFixed(2)}</span>
                </div>` : ""}`;
        } else {
            const ganancia = r.GananciaNeta ?? 0;
            const divisaLimpia = r.Divisa ? r.Divisa.trim() : "";

            balanceEl.innerHTML = `
                <div class="breakdown-row">
                    <span class="bd-label">Resultado</span>
                    <span class="bd-value bd-negative">Predicción incorrecta</span>
                </div>
                ${divisaLimpia === 'PTS' ? `<div class="breakdown-row">
                    <span class="bd-label">Puntos perdidos</span>
                    <span class="bd-value bd-negative">${ganancia} pts</span>
                </div>` : ""}
                ${divisaLimpia === 'USD' ? `<div class="breakdown-row">
                    <span class="bd-label">Dinero perdido</span>
                    <span class="bd-value bd-negative">$${ganancia.toFixed(2)}</span>
                </div>` : ""}`;
        }
    }

    // Validación IA
    const validacionEl = document.getElementById("det-validacion");
    const metodoLabel = r.metodoValidacion === "ia"
        ? "Validado automáticamente por IA de Gathel"
        : r.metodoValidacion === "manual"
            ? "Validado manualmente con evidencia adicional"
            : "Método de validación no disponible";

    validacionEl.innerHTML = `
        <i class='bx bx-shield-quarter'></i>
        <span>${metodoLabel}</span>`;

    // Fechas
    document.getElementById("det-fechas").innerHTML = `
        <div class="date-item">
            <span class="date-label">Creada</span>
            <span class="date-value">${fechaCreacion}</span>
        </div>
        <div class="date-item">
            <span class="date-label">Cierre predicciones</span>
            <span class="date-value">${fechaCierre}</span>
        </div>
        <div class="date-item">
            <span class="date-label">Aceptada</span>
            <span class="date-value">${fechaAceptacion}</span>
        </div>`;

    document.getElementById("modal-detalle").classList.add("show");
}

function cerrarDetalle() {
    document.getElementById("modal-detalle").classList.remove("show");
}

// =====================
// HELPERS DE FECHA
// =====================
function formatearFecha(fechaIso) {
    if (!fechaIso) return "—";
    return new Date(fechaIso).toLocaleString("es-CR", {
        day: "2-digit", month: "short", year: "numeric",
        hour: "2-digit", minute: "2-digit"
    });
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

// Filtro tabs
document.getElementById("filter-tabs").addEventListener("click", (e) => {
    const tab = e.target.closest(".filter-tab");
    if (!tab) return;
    document.querySelectorAll(".filter-tab").forEach(t => t.classList.remove("active"));
    tab.classList.add("active");
    filtroActual = tab.dataset.filter;
    aplicarFiltros();
});

// Búsqueda
document.getElementById("search-input").addEventListener("input", (e) => {
    busquedaActual = e.target.value;
    aplicarFiltros();
});

// Cargar más
document.getElementById("btn-cargar-mas").addEventListener("click", () => {
    resultadosVisibles += 10;
    renderResultados(window._listaFiltrada || []);
});

// =====================
// INIT
// =====================
document.addEventListener("DOMContentLoaded", inicializar);
