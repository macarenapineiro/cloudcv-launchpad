// Dirección de la Azure Function que cuenta las visitas.
// La completamos cuando la función esté creada.
const API_URL = "";

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
