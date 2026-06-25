const inputTarget = document.getElementById("prop-target");
const hiddenIdInput = document.getElementById("selected-subject-id");
const resultsList = document.getElementById("autocomplete-results");
let debounceTimer;

inputTarget.addEventListener("input", (e) => {
    const query = e.target.value;
    hiddenIdInput.value = ""; 

    clearTimeout(debounceTimer);
    if (query.length < 2) {
        resultsList.innerHTML = "";
        return;
    }

    debounceTimer = setTimeout(async () => {
        try {
            const res = await fetch(`${API_URL}/buscarUsuarios?query=${encodeURIComponent(query)}`);
            const users = await res.json();
            
            resultsList.innerHTML = "";
            users.forEach(u => {
                const li = document.createElement("li");
                li.textContent = u.username;
                li.onclick = () => {
                    inputTarget.value = u.username;
                    hiddenIdInput.value = u.id; 
                    resultsList.innerHTML = "";
                };
                resultsList.appendChild(li);
            });
        } catch (err) {
            console.error("Error buscando usuarios", err);
        }
    }, 300);
});

document.addEventListener("click", (e) => {
    if (e.target !== inputTarget) resultsList.innerHTML = "";
});