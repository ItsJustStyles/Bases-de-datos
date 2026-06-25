const API_URL = "/api";
const LIMIT = 10; // [NUEVO] Constante única de paginación

let jugador = {};
let proposicionesEjemplo = [];
let actividadEjemplo = [];
let propSeleccionada = null;
let votoSeleccionado = null;
let tipoApuesta = "puntos";

// [MODIFICADO] Variables de paginación — ahora controlan páginas reales en el servidor
// Se eliminaron proposicionesVisibles y actividadVisibles (eran paginación client-side)
let currentPageProposiciones = 1;
let currentPageActividad = 1;
let hasMoreProposiciones = true;
let hasMoreActividad = true;

// ========== INIT / CARGA DE DATOS ==========

async function inicializarDashboard() {
    const playerId = localStorage.getItem("playerId");
    console.log("ID del jugador recuperado de localStorage:", playerId);

    if (!playerId) {
        window.location.href = "iniciarSesion.html";
        return;
    }

    // [MODIFICADO] Reset completo del estado de paginación en cada reinicio del dashboard
    currentPageProposiciones = 1;
    currentPageActividad = 1;
    hasMoreProposiciones = true;
    hasMoreActividad = true;
    proposicionesEjemplo = [];
    actividadEjemplo = [];

    try {
        // [MODIFICADO] Se pasa page y limit explícitamente al endpoint
        const response = await fetch(`${API_URL}/inicio/${playerId}?page=1&limit=${LIMIT}`);

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            console.error("Error del backend:", response.status, errorData);
            throw new Error(errorData.detail || "No se pudo obtener la información del perfil.");
        }

        const data = await response.json();
        console.log("Datos recibidos correctamente:", data);

        jugador = data.jugador;
        localStorage.setItem("jugadorData", JSON.stringify(jugador));
        proposicionesEjemplo = data.proposiciones;
        actividadEjemplo = data.actividad;

        // [NUEVO] Si el backend devuelve exactamente LIMIT items, asumimos que puede haber más
        hasMoreProposiciones = data.proposiciones.length === LIMIT;
        hasMoreActividad = data.actividad.length === LIMIT;

        cargarDatosJugador();
        renderProposiciones(proposicionesEjemplo, false); // [MODIFICADO] Recibe array + append=false (reemplazo)
        renderActividad(actividadEjemplo, false);         // [MODIFICADO] Recibe array + append=false (reemplazo)

    } catch (error) {
        console.error("Error detallado cargando dashboard:", error);
        Swal.fire({
            title: 'Error de Conexión',
            text: error.message || 'Ocurrió un problema al sincronizar tus balances desde la base de datos.',
            icon: 'error',
            confirmButtonText: 'Entendido'
        });
    }
}

// ========== [NUEVO] CARGA DE PÁGINAS ADICIONALES ==========

// [NUEVO] Solicita la siguiente página de proposiciones y las agrega al DOM
async function cargarMasProposiciones() {
    if (!hasMoreProposiciones) return;

    const playerId = localStorage.getItem("playerId");
    const btnCargarMas = document.getElementById("btn-cargar-mas");

    // Feedback visual mientras carga
    if (btnCargarMas) {
        btnCargarMas.disabled = true;
        btnCargarMas.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i> Cargando...";
    }

    try {
        currentPageProposiciones++;

        // Nota: el endpoint actual pagina proposiciones y actividad con el mismo parámetro `page`.
        // Por eso usamos el contador propio de proposiciones. Si en el futuro se crean endpoints
        // separados (/api/proposiciones y /api/actividad), cada función usará el suyo directamente.
        const response = await fetch(`${API_URL}/inicio/${playerId}?page=${currentPageProposiciones}&limit=${LIMIT}`);

        if (!response.ok) throw new Error("Error al cargar más proposiciones.");

        const data = await response.json();
        const nuevasProps = data.proposiciones;

        // [CLAVE] Acumular en el array global para que predecir() siga encontrando todas las props
        proposicionesEjemplo = [...proposicionesEjemplo, ...nuevasProps];

        // Si recibimos menos del LIMIT, ya no hay más páginas
        hasMoreProposiciones = nuevasProps.length === LIMIT;

        renderProposiciones(nuevasProps, true); // append=true → insertAdjacentHTML

    } catch (error) {
        currentPageProposiciones--; // Revertir el incremento si falló
        console.error("Error cargando más proposiciones:", error);
        Swal.fire({
            icon: 'error',
            title: 'Error',
            text: 'No se pudieron cargar más proposiciones.',
            confirmButtonColor: '#d33'
        });
    } finally {
        if (btnCargarMas) {
            btnCargarMas.disabled = false;
            btnCargarMas.innerHTML = "<i class='bx bx-chevron-down'></i> Cargar más";
        }
    }
}

// [NUEVO] Solicita la siguiente página de actividad y la agrega al DOM
async function cargarMasActividad() {
    if (!hasMoreActividad) return;

    const playerId = localStorage.getItem("playerId");
    const btnCargarActividad = document.getElementById("btn-cargar-actividad");

    if (btnCargarActividad) {
        btnCargarActividad.disabled = true;
        btnCargarActividad.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i> Cargando...";
    }

    try {
        currentPageActividad++;

        const response = await fetch(`${API_URL}/inicio/${playerId}?page=${currentPageActividad}&limit=${LIMIT}`);

        if (!response.ok) throw new Error("Error al cargar más actividad.");

        const data = await response.json();
        const nuevaActividad = data.actividad;

        actividadEjemplo = [...actividadEjemplo, ...nuevaActividad];
        hasMoreActividad = nuevaActividad.length === LIMIT;

        renderActividad(nuevaActividad, true); // append=true → insertAdjacentHTML

    } catch (error) {
        currentPageActividad--;
        console.error("Error cargando más actividad:", error);
        Swal.fire({
            icon: 'error',
            title: 'Error',
            text: 'No se pudo cargar más actividad.',
            confirmButtonColor: '#d33'
        });
    } finally {
        if (btnCargarActividad) {
            btnCargarActividad.disabled = false;
            btnCargarActividad.innerHTML = "<i class='bx bx-chevron-down'></i> Cargar más";
        }
    }
}

// ========== RENDER ==========

function cargarDatosJugador() {
    document.getElementById("nav-username").textContent = jugador.nombre;
    document.getElementById("balance-points").textContent = jugador.puntos.balance;
    document.getElementById("balance-money").textContent = `$${jugador.dineroReal.balance.toFixed(2)}`;
    document.getElementById("active-predictions").textContent = jugador.prediccionesActivas;
}

// [MODIFICADO] Recibe el array a renderizar + flag append
// - append=false (default) → reemplaza el contenido con innerHTML (carga inicial)
// - append=true            → agrega al final con insertAdjacentHTML (cargar más)
function renderProposiciones(proposiciones, append = false) {
    const lista = document.getElementById("propositions-list");
    const badge = document.getElementById("prop-count");
    const btnCargarMas = document.getElementById("btn-cargar-mas");

    if (!append && proposiciones.length === 0) {
        lista.innerHTML = `
            <div class="empty-state">
                <i class='bx bx-bulb'></i>
                No hay proposiciones activas por ahora.
            </div>`;
        badge.textContent = "0";
        if (btnCargarMas) btnCargarMas.style.display = "none";
        return;
    }

    // El badge refleja el total acumulado en memoria
    badge.textContent = proposicionesEjemplo.length;

    const nuevasCards = proposiciones.map(prop => {
        const fechaCierre = new Date(prop.cierre).toLocaleString("es-CR", {
            day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"
        });

        const badgeClass = prop.estado === "active" ? "badge-active" : "badge-pending";
        const badgeLabel = prop.estado === "active" ? "Activa" : "Pendiente";

        return `
        <div class="proposition-card">
            <div class="prop-info">
                <div class="prop-subject"><i class='bx bxs-user'></i> ${prop.sujeto}</div>
                <div class="prop-text">"${prop.texto}"</div>
                <div class="prop-meta">Creada por ${prop.autor} · Cierre: ${fechaCierre}</div>
            </div>

            <div class="prop-actions" style="display: flex; flex-direction: row; align-items: center; justify-content: center; gap: 15px; margin-top: 15px;">
                <span class="prop-badge ${badgeClass}">${badgeLabel}</span>
                <button class="btn-predict" onclick="predecir(${prop.id})" style="display: flex; align-items: center; gap: 5px;">
                    <i class='bx bx-target-lock'></i> Predecir
                </button>
            </div>
        </div>`;
    }).join("");

    // [CLAVE] insertAdjacentHTML para append (no borra lo existente), innerHTML para reemplazo
    if (append) {
        lista.insertAdjacentHTML("beforeend", nuevasCards);
    } else {
        lista.innerHTML = nuevasCards;
    }

    // [MODIFICADO] El botón se oculta cuando el servidor confirma que no hay más datos
    if (btnCargarMas) {
        btnCargarMas.style.display = hasMoreProposiciones ? "inline-flex" : "none";
    }
}

// [MODIFICADO] Recibe el array a renderizar + flag append (misma lógica que renderProposiciones)
function renderActividad(actividad, append = false) {
    const lista = document.getElementById("activity-list");
    const btnCargarActividad = document.getElementById("btn-cargar-actividad");

    if (!append && actividad.length === 0) {
        lista.innerHTML = `
            <div class="empty-state">
                <i class='bx bx-time'></i>
                Sin actividad reciente.
            </div>`;
        if (btnCargarActividad) btnCargarActividad.style.display = "none";
        return;
    }

    const nuevosItems = actividad.map(item => `
        <div class="activity-item">
            <div class="activity-icon icon-${item.tipo}">
                <i class='bx ${item.icono}'></i>
            </div>
            <div class="activity-text">${item.texto}</div>
            <div class="activity-time">${calcularTiempoRelativo(item.tiempo)}</div>
        </div>
    `).join("");

    // [CLAVE] insertAdjacentHTML para append, innerHTML para reemplazo
    if (append) {
        lista.insertAdjacentHTML("beforeend", nuevosItems);
    } else {
        lista.innerHTML = nuevosItems;
    }

    if (btnCargarActividad) {
        btnCargarActividad.style.display = hasMoreActividad ? "inline-flex" : "none";
    }
}

// ========== MODAL NUEVA PROPOSICIÓN ==========

const modalOverlay = document.getElementById("modal-proposition");

function abrirModal() {
    modalOverlay.classList.add("show");
}

function cerrarModalProposition() {
    modalOverlay.classList.remove("show");
    document.getElementById("prop-target").value = "";
    document.getElementById("selected-subject-id").value = ""; 
    document.getElementById("autocomplete-results").innerHTML = ""; 
    document.getElementById("prop-text").value = "";
    document.getElementById("prop-deadline").value = "";
}

document.getElementById("btn-nueva-prop").addEventListener("click", abrirModal);
document.getElementById("modal-close").addEventListener("click", cerrarModalProposition);
document.getElementById("btn-cancel").addEventListener("click", cerrarModalProposition);

modalOverlay.addEventListener("click", (e) => {
    if (e.target === modalOverlay) cerrarModalProposition();
});

document.getElementById("btn-submit-prop").addEventListener("click", async () => {
    const subjectId = document.getElementById("selected-subject-id").value;
    const texto = document.getElementById("prop-text").value.trim();
    const deadline = document.getElementById("prop-deadline").value;

    if (!subjectId || !texto || !deadline) {
        alert("Por favor, selecciona un jugador válido y completa los campos.");
        return;
    }

    try {
        const response = await fetch(`${API_URL}/proposiciones`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                creatorId: jugador.id,
                subjectPlayerId: parseInt(subjectId),
                propositionText: texto
            })
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || "Error al procesar la solicitud.");
        }

        Swal.fire({
            icon: 'success',
            title: '¡Éxito!',
            text: 'La proposición se ha creado correctamente.',
            confirmButtonColor: '#3085d6'
        });

        await inicializarDashboard();
        cerrarModal();

    } catch (error) {
        console.error("Error completo:", error);
        Swal.fire({
            icon: 'error',
            title: 'Oops...',
            text: error.message,
            confirmButtonColor: '#d33'
        });
    }
});

// ========== MODAL PREDICCIÓN ==========

function predecir(propId) {
    // predecir() sigue leyendo proposicionesEjemplo global — funciona con el array acumulado
    propSeleccionada = proposicionesEjemplo.find(p => p.id === propId);
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

// ========== UTILIDADES ==========

function calcularTiempoRelativo(fechaIso) {
    if (!fechaIso || fechaIso.trim() === "") return "Reciente";

    const fechaLimpia = fechaIso.replace("T", " ");
    let fechaTransaccion = new Date(fechaLimpia);

    fechaTransaccion.setHours(fechaTransaccion.getHours() - 6);

    const ahora = new Date();
    const diferenciaMs = ahora - fechaTransaccion;

    const segundos = Math.floor(diferenciaMs / 1000);
    const minutos = Math.floor(segundos / 60);
    const horas = Math.floor(minutos / 60);
    const dias = Math.floor(horas / 24);

    if (dias > 7) {
        const dia = String(fechaTransaccion.getDate()).padStart(2, '0');
        const mes = String(fechaTransaccion.getMonth() + 1).padStart(2, '0');
        const anio = String(fechaTransaccion.getFullYear()).slice(-2);
        return `${dia}/${mes}/${anio}`;
    }

    if (segundos < 60) return "Ahora mismo";
    if (minutos < 60) return `Hace ${minutos} min`;
    if (horas < 24) return `Hace ${horas} h`;
    if (dias === 1) return "Ayer";

    return `Hace ${dias} días`;
}

// ========== EVENT LISTENERS ==========

document.getElementById("modal-close-prediction").addEventListener("click", cerrarModal);
document.getElementById("btn-cancel-prediction").addEventListener("click", cerrarModal);

document.getElementById("modal-prediccion").addEventListener("click", (e) => {
    if (e.target === document.getElementById("modal-prediccion")) cerrarModal();
});

document.getElementById("btn-ver-activas").addEventListener("click", () => {
    document.querySelector(".propositions-list").scrollIntoView({ behavior: "smooth" });
});

document.getElementById("btn-mis-predicciones").addEventListener("click", () => {
    window.location.href = "misPredicciones.html";
});

document.getElementById("btn-logout").addEventListener("click", () => {
    if (confirm("¿Estás seguro que deseas cerrar sesión?")) {
        window.location.href = "iniciarSesion.html";
    }
});

// [MODIFICADO] Los botones ahora llaman a las funciones de paginación real en el servidor
document.getElementById("btn-cargar-mas").addEventListener("click", cargarMasProposiciones);
document.getElementById("btn-cargar-actividad").addEventListener("click", cargarMasActividad);

// ========== INIT ==========
document.addEventListener("DOMContentLoaded", inicializarDashboard);