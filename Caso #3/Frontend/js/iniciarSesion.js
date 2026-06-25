const API_URL = "/api";

const container = document.querySelector(".container");

const showRegister = document.getElementById("show-register");
const showLogin = document.getElementById("show-login");

showRegister.addEventListener("click", (e) => {
    e.preventDefault();
    container.classList.add("active");
});

showLogin.addEventListener("click", (e) => {
    e.preventDefault();
    container.classList.remove("active");
});

// Iniciar sesion
const loginForm = document.querySelector('.form-box.login form');

loginForm.addEventListener('submit', async (e) => {
    e.preventDefault(); // Detiene la recarga de la página

    const usernameInput = loginForm.querySelector('input[type="text"]').value;
    const passwordInput = loginForm.querySelector('input[type="password"]').value;

    try {
        const response = await fetch(`${API_URL}/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username: usernameInput,
                password: passwordInput
            })
        });

        const data = await response.json();

        if (response.ok) {
            localStorage.setItem("playerId", data.playerId);
            Swal.fire({
                title: '¡Bienvenido de vuelta!',
                text: 'Validando credenciales e iniciando sesión...',
                icon: 'success',
                timer: 2000, 
                showConfirmButton: false, 
                willClose: () => {
                    window.location.href = "../html/inicioGathel.html";
                }
            });

        } else {
            Swal.fire({
                title: 'Error de Autenticación',
                text: data.detail, 
                icon: 'error',
                confirmButtonColor: '#ea4335',
                confirmButtonText: 'Intentar de nuevo'
            });
        }
    } catch (error) {
        console.error("Error en la conexión:", error);
        Swal.fire({
            title: 'Sin respuesta del servidor',
            text: 'No se pudo establecer conexión con el backend de Gathel.',
            icon: 'warning',
            confirmButtonColor: '#555',
            confirmButtonText: 'Entendido'
        });
    }
});

// Registro:
const registerForm = document.querySelector('.form-box.register form');

registerForm.addEventListener('submit', async (e) => {
    e.preventDefault(); 

    const usernameInput = registerForm.querySelector('input[type="text"]').value;
    const emailInput = registerForm.querySelector('input[type="email"]').value;
    const passwordInput = registerForm.querySelector('input[type="password"]').value;

    try {
        const response = await fetch(`${API_URL}/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username: usernameInput,
                email: emailInput,
                password: passwordInput,
                countryId: null 
            })
        });

        const data = await response.json();

        if (response.ok) {
            Swal.fire({
                title: '¡Registro Exitoso!',
                text: 'Tu cuenta ha sido creada y tus puntos de bienvenida fueron asignados.',
                icon: 'success',
                confirmButtonColor: '#3085d6',
                confirmButtonText: 'Genial'
            }).then(() => {
                // Esto se ejecuta cuando el usuario le da al botón del pop-up
                registerForm.reset();
                container.classList.remove('active'); // Volver al login
            });
        } else {
            Swal.fire({
                title: 'No se pudo registrar',
                text: data.detail, 
                icon: 'warning',
                confirmButtonColor: '#d33',
                confirmButtonText: 'Corregir datos'
            });
        }

    } catch (error) {
        console.error("Error de red o conexión con la API:", error);
        Swal.fire({
            title: 'Error de Conexión',
            text: 'No logramos conectar con el servidor de Gathel. Inténtalo más tarde.',
            icon: 'error',
            confirmButtonColor: '#555',
            confirmButtonText: 'Entendido'
        });
    }
});