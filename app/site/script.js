// La dirección de la Azure Function la escribe OpenTofu en config.js (window.API_URL).
// Si no hay dirección (por ejemplo, abriendo el HTML desde la compu), el contador muestra "—".
const API_URL = window.API_URL || "";

async function mostrarVisitas() {
  const span = document.getElementById("visitas");

  if (!API_URL) {
    span.textContent = "—";
    return;
  }

  try {
    const respuesta = await fetch(API_URL, { method: "POST" });
    const datos = await respuesta.json();
    span.textContent = datos.visitas;
  } catch (error) {
    span.textContent = "—";
  }
}

mostrarVisitas();
