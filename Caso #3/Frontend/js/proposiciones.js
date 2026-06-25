const API_URL = "/api";
const LIMIT = 10; // [NUEVO] Constante única de paginación

let jugador = {};
let todasLasProposiciones = [];
let filtroActual = "all";
let busquedaActual = "";
let propSeleccionada = null;
let votoSeleccionado = null;
let tipoApuesta = "puntos";

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
        const response = await fetch(`${API_URL}/getProposiciones?page=1&limit=${LIMIT}`);

        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || "No se pudo cargar la información.");
        }

        const data = await response.json();

        const jugadorGuardado = localStorage.getItem("jugadorData");
        if (jugadorGuardado) {
            jugador = JSON.parse(jugadorGuardado);
            console.log("Jugador recuperado:", jugador);
        }
        todasLasProposiciones = data.proposiciones;

        console.log(todasLasProposiciones);

        // [NUEVO] Si el backend devuelve exactamente LIMIT items, puede haber más páginas
        hasMoreProposiciones = data.proposiciones.length === LIMIT;

        renderHeader();
        aplicarFiltros();

    } catch (error) {
        console.error("Error cargando proposiciones:", error);
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

// [NUEVO] Solicita la siguiente página al servidor y re-aplica los filtros activos.
// Se usa re-render completo (append=false en renderProposiciones) porque:
//   1. Los filtros client-side pueden hacer que solo algunos de los nuevos items sean visibles.
//   2. Los stats (count-all, count-active, count-pending) deben recalcularse sobre
//      el total acumulado filtrado.
// Si en el futuro se mueven los filtros al servidor (query params en getProposiciones),
// se podría cambiar a append=true para mejor performance.
async function cargarMasProposiciones() {
    if (!hasMoreProposiciones) return;

    const btnMas = document.getElementById("btn-cargar-mas");

    // Feedback visual mientras carga
    if (btnMas) {
        btnMas.disabled = true;
        btnMas.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i> Cargando...";
    }

    try {
        currentPageProposiciones++;
        const response = await fetch(`${API_URL}/getProposiciones?page=${currentPageProposiciones}&limit=${LIMIT}`);

        if (!response.ok) throw new Error("Error al cargar más proposiciones.");

        const data = await response.json();
        const nuevas = data.proposiciones;

        // [CLAVE] Acumular en el array global — todasLasProposiciones es la fuente de verdad
        // para filtros, búsqueda y para que abrirModalPrediccion() siga encontrando todas las props
        todasLasProposiciones = [...todasLasProposiciones, ...nuevas];

        // Si recibimos menos del LIMIT, ya no hay más páginas en el servidor
        hasMoreProposiciones = nuevas.length === LIMIT;

        // Re-aplicar filtros sobre el pool ampliado → actualiza stats y re-renderiza
        aplicarFiltros();

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
        // Restaurar botón siempre, aplicarFiltros() se encarga de ocultarlo si ya no hay más
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
    document.getElementById("header-money").textContent = jugador.dineroReal.balance.toFixed(2);
}

// =====================
// FILTROS Y BÚSQUEDA
// =====================

// [MODIFICADO] Se eliminó el reset de proposicionesVisibles (ya no existe)
function aplicarFiltros() {
    let resultado = todasLasProposiciones;

    // --- LÓGICA DE FILTRADO DE ESTADO ---
    if (filtroActual === "pending") {
        // Filtramos para obtener todo lo que NO coincida con estos 3 estados
        const excluidos = ["active", "cancelled", "rejected"];
        resultado = resultado.filter(p => !excluidos.includes(p.estado));
        
    } else if (filtroActual !== "all") {
        // Mantienes el comportamiento normal para filtros específicos (ej: "active")
        resultado = resultado.filter(p => p.estado === filtroActual);
    }

    // --- LÓGICA DE BÚSQUEDA ---
    if (busquedaActual.trim() !== "") {
        const q = busquedaActual.toLowerCase();
        resultado = resultado.filter(p =>
            p.sujeto.toLowerCase().includes(q) ||
            p.texto.toLowerCase().includes(q)
        );
    }

    renderStats(resultado);
    renderProposiciones(resultado);
}

// =====================
// STATS
// =====================

// Nota: los contadores reflejan el total cargado hasta ahora, no el total en la DB.
// Para conteos exactos se necesitaría que el backend devuelva un campo `total`.
function renderStats(lista) {
    document.getElementById("count-all").textContent = lista.length;
    document.getElementById("count-active").textContent = lista.filter(p => p.estado === "active").length;
    document.getElementById("count-pending").textContent = lista.filter(p => p.estado === "pending").length;
}

// =====================
// RENDER PROPOSICIONES
// =====================

// [MODIFICADO] Recibe la lista completa a renderizar + flag append (consistencia con inicioGathel).
// - append=false → innerHTML (reemplazo, usado siempre que hay filtros activos)
// - append=true  → insertAdjacentHTML (para uso futuro si se mueven filtros al servidor)
// Se eliminó: .slice(0, proposicionesVisibles) y window._listaFiltrada
function renderProposiciones(lista, append = false) {
    const container = document.getElementById("propositions-list");
    const btnMas = document.getElementById("btn-cargar-mas");

    if (!lista || lista.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class='bx bx-bulb'></i>
                <strong>Sin proposiciones</strong>
                <p>No hay proposiciones que coincidan con tu búsqueda.</p>
            </div>`;
        // Ocultar botón solo si tampoco hay más en el servidor
        if (btnMas) btnMas.style.display = hasMoreProposiciones ? "inline-flex" : "none";
        return;
    }

    // [MODIFICADO] Sin slicing — se renderizan todos los items de la lista filtrada
    const cards = lista.map(prop => {
        const fechaCierre = new Date(prop.cierre).toLocaleString("es-CR", {
            day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
        });

        const badgeClass = prop.estado === "active" ? "badge-active" : "badge-pending";
        const badgeLabel = prop.estado === "active" ? "Activa" : "Pendiente";

        const countdown = calcularCountdown(prop.cierre);
        const countdownClass = countdown.urgente ? "prop-countdown" : "prop-countdown safe";

        const yaPredijo = prop.miPrediccion !== null && prop.miPrediccion !== undefined;

        return `
        <div class="proposition-card" id="prop-card-${prop.id}">
            <div class="prop-left">
                <div class="prop-subject">
                    <i class='bx bxs-user'></i> ${prop.sujeto}
                </div>
                <div class="prop-text">"${prop.texto}"</div>
                <div class="prop-meta">
                    <span><i class='bx bx-user'></i> Creada por ${prop.autor}</span>
                    <span><i class='bx bx-calendar'></i> Cierre: ${fechaCierre}</span>
                    <span class="${countdownClass}"><i class='bx bx-time-five'></i> ${countdown.texto}</span>
                </div>
            </div>
            <div class="prop-right">
                <span class="prop-badge ${badgeClass}">${badgeLabel}</span>
                ${yaPredijo
                    ? `<button class="btn-predict" disabled>
                        <i class='bx bx-check'></i> Ya predijiste
                       </button>`
                    : `<button class="btn-predict" onclick="abrirModalPrediccion(${prop.id})">
                        <i class='bx bx-target-lock'></i> Predecir
                       </button>`
                }
            </div>
        </div>`;
    }).join("");

    // [CLAVE] insertAdjacentHTML para append, innerHTML para reemplazo
    if (append) {
        container.insertAdjacentHTML("beforeend", cards);
    } else {
        container.innerHTML = cards;
    }

    // [MODIFICADO] La visibilidad del botón la controla hasMoreProposiciones (estado del servidor),
    // no el largo del array local. Si hay un filtro activo y los resultados son 0,
    // el botón igual se muestra si el servidor tiene más páginas.
    if (btnMas) {
        btnMas.style.display = hasMoreProposiciones ? "inline-flex" : "none";
    }
}

// =====================
// COUNTDOWN
// =====================
function calcularCountdown(fechaIso) {
    if (!fechaIso) return { texto: "Sin fecha", urgente: false };

    const cierre = new Date(fechaIso);
    const ahora = new Date();
    const diffMs = cierre - ahora;

    if (diffMs <= 0) return { texto: "Cerrada", urgente: true };

    const horas = Math.floor(diffMs / (1000 * 60 * 60));
    const mins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

    if (horas < 1) return { texto: `${mins}m restantes`, urgente: true };
    if (horas < 24) return { texto: `${horas}h ${mins}m restantes`, urgente: horas < 3 };

    const dias = Math.floor(horas / 24);
    return { texto: `${dias}d restantes`, urgente: false };
}

// =====================
// MODAL PREDICCIÓN
// =====================
function abrirModalPrediccion(propId) {
    // Sigue leyendo todasLasProposiciones global — funciona con el array acumulado
    propSeleccionada = todasLasProposiciones.find(p => p.id === propId);
    if (!propSeleccionada) return;

    votoSeleccionado = null;
    tipoApuesta = "puntos";

    document.getElementById("modal-sujeto").textContent = propSeleccionada.sujeto;
    document.getElementById("modal-prop-text").textContent = `"${propSeleccionada.texto}"`;

    // Reset UI
    document.getElementById("btn-yes").classList.remove("selected");
    document.getElementById("btn-no").classList.remove("selected");
    document.getElementById("tab-pts").classList.add("active");
    document.getElementById("tab-money").classList.remove("active");
    document.getElementById("panel-puntos").style.display = "flex";
    document.getElementById("panel-dinero").style.display = "none";
    document.getElementById("input-puntos").value = "1";
    document.getElementById("input-dinero").value = "";
    document.getElementById("avail-pts").textContent = jugador.puntos.balance;
    document.getElementById("avail-money").textContent = `$${jugador.dineroReal.balance.toFixed(2)}`;

    document.getElementById("modal-prediccion").classList.add("show");
}

function cerrarModal() {
    document.getElementById("modal-prediccion").classList.remove("show");
    propSeleccionada = null;
    votoSeleccionado = null;
}

function seleccionarVoto(tipo) {
    votoSeleccionado = tipo;
    document.getElementById("btn-yes").classList.toggle("selected", tipo === "yes");
    document.getElementById("btn-no").classList.toggle("selected", tipo === "no");
}

function cambiarTipoApuesta(tipo) {
    tipoApuesta = tipo;
    document.getElementById("tab-pts").classList.toggle("active", tipo === "puntos");
    document.getElementById("tab-money").classList.toggle("active", tipo === "dinero");
    document.getElementById("panel-puntos").style.display = tipo === "puntos" ? "flex" : "none";
    document.getElementById("panel-dinero").style.display = tipo === "dinero" ? "flex" : "none";
}

document.getElementById("btn-submit-pred").addEventListener("click", async () => {
    if (!votoSeleccionado) {
        Swal.fire({
            icon: 'warning',
            title: 'Falta tu voto',
            text: 'Seleccioná Sí o No antes de confirmar.',
            confirmButtonColor: '#3085d6'
        });
        return;
    }

    const monto = tipoApuesta === "puntos"
        ? parseInt(document.getElementById("input-puntos").value)
        : parseFloat(document.getElementById("input-dinero").value);

    const wallet = tipoApuesta === "puntos" 
        ? parseInt(jugador.puntos.walletId)
        : parseInt(jugador.dineroReal.walletId);

    if (!monto || monto <= 0) {
        Swal.fire({
            icon: 'warning',
            title: 'Monto inválido',
            text: 'Ingresá un monto mayor a 0 para continuar.',
            confirmButtonColor: '#3085d6'
        });
        return;
    }

    const limiteDisponible = tipoApuesta === "puntos" ? jugador.puntos.balance : jugador.dineroReal.balance;
    if (monto > limiteDisponible) {
        Swal.fire({
            icon: 'error',
            title: 'Saldo insuficiente',
            text: `No tenés suficientes ${tipoApuesta === "puntos" ? "puntos" : "dinero"} para esta apuesta.`,
            confirmButtonColor: '#d33'
        });
        return;
    }

    const payload = {
        propositionId: propSeleccionada.id,
        predictorId: jugador.id,
        predictionOption: votoSeleccionado,
        walletId: wallet,
        amountWagered: monto
    };

    console.log("Datos enviados al api:", payload);

    try {
        const response = await fetch(`${API_URL}/predecir`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || "Error al procesar la predicción.");
        }

        Swal.fire({
            icon: 'success',
            title: '¡Predicción registrada!',
            text: 'Tu apuesta fue confirmada correctamente.',
            confirmButtonColor: '#3085d6'
        });

        cerrarModal();
        await inicializarDashboard();

    } catch (error) {
        let mensajeMostrado = error.message;
        if (mensajeMostrado.includes("] ")) {
            mensajeMostrado = mensajeMostrado.split("] ")[1]; // Intenta limpiar el prefijo de SQL
        }
        Swal.fire({
            icon: 'error',
            title: 'No se pudo procesar',
            text: mensajeMostrado,
            confirmButtonColor: '#d33'
        });
    }
});

// =====================
// EVENTOS UI
// =====================
document.getElementById("modal-close").addEventListener("click", cerrarModal);
document.getElementById("btn-cancel").addEventListener("click", cerrarModal);

document.getElementById("modal-prediccion").addEventListener("click", (e) => {
    if (e.target === document.getElementById("modal-prediccion")) cerrarModal();
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

// [MODIFICADO] El botón ahora llama a la función de paginación real en el servidor
document.getElementById("btn-cargar-mas").addEventListener("click", cargarMasProposiciones);

// =====================
// INIT
// =====================
document.addEventListener("DOMContentLoaded", inicializar);