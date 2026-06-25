const API_URL = "/api";
const LIMIT = 10; // [NUEVO] Constante única de paginación

let jugador = {};
let todasLasProposiciones = [];
let filtroActual = "pending_acceptance";
let propSeleccionada = null;

// [MODIFICADO] Paginación real del servidor — se eliminó proposicionesVisibles
// y el hack de window._listaFiltrada
let currentPageProposiciones = 1;
let hasMoreProposiciones = true;

// =====================
// INICIALIZACIÓN
// =====================
async function inicializar() {
    const playerId = localStorage.getItem("playerId");
    if (!playerId) {
        window.location.href = "iniciarSesion.html";
        return;
    }

    // [MODIFICADO] Reset completo del estado de paginación antes de cada carga
    currentPageProposiciones = 1;
    hasMoreProposiciones = true;
    todasLasProposiciones = [];

    try {
        // [MODIFICADO] Se pasan page y limit explícitamente al endpoint
        const response = await fetch(`${API_URL}/proposiciones/sobre-mi?playerId=${playerId}&page=1&limit=${LIMIT}`);

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo cargar la información.");
        }

        const data = await response.json();
        console.log(data);

        const jugadorGuardado = localStorage.getItem("jugadorData");
        if (jugadorGuardado) {
            jugador = JSON.parse(jugadorGuardado);
            console.log("Jugador recuperado:", jugador);
        }
        todasLasProposiciones = data.proposiciones;

        // [NUEVO] Si el backend devuelve exactamente LIMIT items, puede haber más páginas
        hasMoreProposiciones = data.proposiciones.length === LIMIT;

        renderHeader();
        renderConteoPendientes();
        aplicarFiltro();

    } catch (error) {
        console.error("Error cargando proposiciones sobre mí:", error);
        Swal.fire({
            title: 'Error de Conexión',
            text: error.message || 'No se pudieron cargar las proposiciones.',
            icon: 'error',
            confirmButtonText: 'Entendido'
        });
    }
}

// =====================
// [NUEVO] CARGA DE PÁGINAS ADICIONALES
// =====================

// [NUEVO] Solicita la siguiente página al servidor y re-aplica el filtro activo.
// Se usa re-render completo (append=false) porque:
//   1. El filtro client-side puede hacer que solo algunos nuevos items sean visibles.
//   2. renderConteoPendientes() debe recalcularse sobre el total acumulado.
async function cargarMasProposiciones() {
    if (!hasMoreProposiciones) return;

    const playerId = localStorage.getItem("playerId");
    const btnMas = document.getElementById("btn-cargar-mas");

    if (btnMas) {
        btnMas.disabled = true;
        btnMas.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i> Cargando...";
    }

    try {
        currentPageProposiciones++;
        const response = await fetch(`${API_URL}/proposiciones/sobre-mi?playerId=${playerId}&page=${currentPageProposiciones}&limit=${LIMIT}`);

        if (!response.ok) throw new Error("Error al cargar más proposiciones.");

        const data = await response.json();
        const nuevas = data.proposiciones;

        // [CLAVE] Acumular en el array global — todasLasProposiciones es la fuente de verdad
        // para el filtro, el conteo de pendientes y para abrirModalDecision()
        todasLasProposiciones = [...todasLasProposiciones, ...nuevas];

        // Si recibimos menos del LIMIT, ya no hay más páginas en el servidor
        hasMoreProposiciones = nuevas.length === LIMIT;

        // Re-calcular el badge de pendientes sobre el pool ampliado
        renderConteoPendientes();

        // Re-aplicar filtro → actualiza render completo
        aplicarFiltro();

    } catch (error) {
        currentPageProposiciones--; // Revertir si falló
        console.error("Error cargando más proposiciones:", error);
        Swal.fire({
            icon: 'error',
            title: 'Error',
            text: 'No se pudieron cargar más proposiciones.',
            confirmButtonColor: '#d33'
        });
    } finally {
        if (btnMas) {
            btnMas.disabled = false;
            btnMas.innerHTML = "<i class='bx bx-chevron-down'></i> Cargar más";
        }
    }
}

// =====================
// HEADER
// =====================
function renderHeader() {
    document.getElementById("nav-username").textContent = jugador.nombre;
    document.getElementById("header-points").textContent = jugador.puntos.balance;
}

// [NOTA] Cuenta sobre el total acumulado cargado — no el total real en la DB.
// Para el total exacto se necesitaría un campo `total` en la respuesta del backend.
function renderConteoPendientes() {
    const pendientes = todasLasProposiciones.filter(p => p.estado === "pending_acceptance");
    document.getElementById("count-pending").textContent = pendientes.length;
}

// =====================
// FILTRO
// =====================

// [MODIFICADO] Se eliminó el reset de proposicionesVisibles (ya no existe)
function aplicarFiltro() {
    const lista = todasLasProposiciones.filter(p => p.estado === filtroActual);
    renderProposiciones(lista);
}

// =====================
// RENDER PROPOSICIONES
// =====================

// [MODIFICADO] Recibe la lista completa a renderizar + flag append (consistencia con otros módulos).
// - append=false → innerHTML (reemplazo, usado siempre que hay filtro activo)
// - append=true  → insertAdjacentHTML (para uso futuro si se mueven filtros al servidor)
// Se eliminó: .slice(0, proposicionesVisibles) y window._listaFiltrada
function renderProposiciones(lista, append = false) {
    const container = document.getElementById("propositions-list");
    const btnMas = document.getElementById("btn-cargar-mas");

    if (!lista || lista.length === 0) {
        const mensajes = {
            pending_acceptance: { icon: "bx-check-shield", title: "Sin proposiciones pendientes", text: "No tenés proposiciones esperando tu decisión." },
            active: { icon: "bx-trending-up", title: "Sin proposiciones aceptadas", text: "Todavía no aceptaste ninguna proposición." },
            rejected_subject: { icon: "bx-shield-x", title: "Sin proposiciones rechazadas", text: "No has rechazado ninguna proposición." }
        };
        const msg = mensajes[filtroActual] || mensajes.pending_acceptance;

        container.innerHTML = `
            <div class="empty-state">
                <i class='bx ${msg.icon}'></i>
                <strong>${msg.title}</strong>
                <p>${msg.text}</p>
            </div>`;
        // Ocultar botón solo si tampoco hay más en el servidor
        if (btnMas) btnMas.style.display = hasMoreProposiciones ? "inline-flex" : "none";
        return;
    }

    // [MODIFICADO] Sin slicing — se renderizan todos los items del filtro activo
    const cards = lista.map(prop => {
        const fechaCreacion = formatearFecha(prop.creada);

        if (prop.estado === "pending_acceptance") {
            return `
            <div class="proposition-card state-pending_acceptance" id="prop-card-${prop.propositionId}">
                <div class="prop-top">
                    <div class="prop-text">"${prop.propositionText}"</div>
                    <span class="prop-status-badge status-pending_acceptance">
                        <i class='bx bx-time-five'></i> Pendiente
                    </span>
                </div>
                <div class="prop-meta">
                    <span><i class='bx bx-user'></i> Creada por ${prop.Creador}</span>
                    <span><i class='bx bx-calendar'></i> ${fechaCreacion}</span>
                </div>
                <div class="prop-actions-row">
                    <button class="btn-decision reject" onclick="abrirModalDecision(${prop.propositionId})">
                        <i class='bx bx-x'></i> Rechazar
                    </button>
                    <button class="btn-decision accept" onclick="abrirModalDecision(${prop.propositionId})">
                        <i class='bx bx-check'></i> Aceptar
                    </button>
                </div>
            </div>`;
        }

        if (prop.estado === "active") {
            const fechaCierre = formatearFecha(prop.cierre);
            return `
            <div class="proposition-card state-active" id="prop-card-${prop.propositionId}">
                <div class="prop-top">
                    <div class="prop-text">"${prop.propositionText}"</div>
                    <span class="prop-status-badge status-active">
                        <i class='bx bx-check-circle'></i> Activa
                    </span>
                </div>
                <div class="prop-meta">
                    <span><i class='bx bx-user'></i> Creada por ${prop.Creador}</span>
                    <span><i class='bx bx-calendar'></i> ${fechaCreacion}</span>
                </div>
                <div class="prop-result-info">
                    <i class='bx bx-info-circle'></i>
                    Aceptaste esta proposición. Cierre de predicciones: ${fechaCierre}.
                </div>
            </div>`;
        }

        // rejected_subject
        return `
        <div class="proposition-card state-rejected_subject" id="prop-card-${prop.propositionId}">
            <div class="prop-top">
                <div class="prop-text">"${prop.propositionText}"</div>
                <span class="prop-status-badge status-rejected_subject">
                    <i class='bx bx-x-circle'></i> Rechazada
                </span>
            </div>
            <div class="prop-meta">
                <span><i class='bx bx-user'></i> Creada por ${prop.Creador}</span>
                <span><i class='bx bx-calendar'></i> ${fechaCreacion}</span>
            </div>
            <div class="prop-result-info">
                <i class='bx bx-error'></i>
                Rechazaste esta proposición. Se aplicó una penalización de 1 punto.
            </div>
        </div>`;
    }).join("");

    // [CLAVE] insertAdjacentHTML para append, innerHTML para reemplazo completo
    if (append) {
        container.insertAdjacentHTML("beforeend", cards);
    } else {
        container.innerHTML = cards;
    }

    // [MODIFICADO] La visibilidad del botón la controla hasMoreProposiciones (estado del servidor),
    // no el largo del array local
    if (btnMas) {
        btnMas.style.display = hasMoreProposiciones ? "inline-flex" : "none";
    }
}

// =====================
// HELPERS
// =====================
function formatearFecha(fechaIso) {
    if (!fechaIso) return "—";
    return new Date(fechaIso).toLocaleString("es-CR", {
        day: "2-digit", month: "short", year: "numeric",
        hour: "2-digit", minute: "2-digit"
    });
}

// =====================
// MODAL DE DECISIÓN
// =====================
function abrirModalDecision(propId) {
    // Sigue leyendo todasLasProposiciones global — funciona con el array acumulado
    propSeleccionada = todasLasProposiciones.find(p => p.propositionId === propId);
    if (!propSeleccionada) return;

    document.getElementById("modal-prop-text").textContent = `"${propSeleccionada.propositionText}"`;
    document.getElementById("modal-autor").textContent = propSeleccionada.Creador;
    document.getElementById("modal-fecha").textContent = formatearFecha(propSeleccionada.creada);
    document.getElementById("prop-deadline").value = "";
    document.getElementById("penalty-balance").textContent = jugador.puntos.balance;

    document.getElementById("modal-decision").classList.add("show");
}

function cerrarModal() {
    document.getElementById("modal-decision").classList.remove("show");
    propSeleccionada = null;
}

// =====================
// ACEPTAR
// =====================
document.getElementById("btn-accept").addEventListener("click", async () => {
    if (!propSeleccionada) return;
    const deadline = document.getElementById("prop-deadline").value;

    if (!deadline) {
        Swal.fire({
            icon: 'warning',
            title: 'Falta la fecha límite',
            text: 'Definí cuándo se cierran las predicciones para activar la proposición.',
            confirmButtonColor: '#7494ec'
        });
        return;
    }

    if (new Date(deadline) <= new Date()) {
        Swal.fire({
            icon: 'warning',
            title: 'Fecha inválida',
            text: 'La fecha límite debe ser en el futuro.',
            confirmButtonColor: '#7494ec'
        });
        return;
    }

    try {
        const response = await fetch(`${API_URL}/aceptProposition`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                propositionId: parseInt(propSeleccionada.propositionId),
                subjectPlayerId: parseInt(jugador.id),
                predictionsCloseAt: deadline
            })
        });

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo aceptar la proposición.");
        }

        Swal.fire({
            icon: 'success',
            title: '¡Proposición activada!',
            text: 'Ya se habilitaron las predicciones para esta proposición.',
            confirmButtonColor: '#7494ec'
        });

        cerrarModal();
        await inicializar();

    } catch (error) {
        Swal.fire({ icon: 'error', title: 'Error', text: error.message, confirmButtonColor: '#d33' });
    }
});

// =====================
// RECHAZAR
// =====================
document.getElementById("btn-reject").addEventListener("click", async () => {
    if (!propSeleccionada) return;

    const confirmacion = await Swal.fire({
        icon: 'warning',
        title: '¿Rechazar esta proposición?',
        text: `Perderás 1 punto de tu balance (${jugador.puntos.balance} pts disponibles). Esta acción no se puede revertir.`,
        showCancelButton: true,
        confirmButtonText: 'Sí, rechazar',
        cancelButtonText: 'Cancelar',
        confirmButtonColor: '#dc2626',
        cancelButtonColor: '#888'
    });

    if (!confirmacion.isConfirmed) return;

    try {
        const response = await fetch(`${API_URL}/rejectProposition`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                propositionId: parseInt(propSeleccionada.propositionId),
                subjectPlayerId: parseInt(jugador.id)
            })
        });

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo rechazar la proposición.");
        }

        Swal.fire({
            icon: 'info',
            title: 'Proposición rechazada',
            text: 'Se descontó 1 punto de tu balance.',
            confirmButtonColor: '#7494ec'
        });

        cerrarModal();
        await inicializar();

    } catch (error) {
        Swal.fire({ icon: 'error', title: 'Error', text: error.message, confirmButtonColor: '#d33' });
    }
});

// =====================
// EVENTOS UI
// =====================
document.getElementById("modal-close").addEventListener("click", cerrarModal);

document.getElementById("modal-decision").addEventListener("click", (e) => {
    if (e.target === document.getElementById("modal-decision")) cerrarModal();
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
    aplicarFiltro();
});

// [MODIFICADO] El botón ahora llama a la función de paginación real en el servidor
document.getElementById("btn-cargar-mas").addEventListener("click", cargarMasProposiciones);

// =====================
// INIT
// =====================
document.addEventListener("DOMContentLoaded", inicializar);