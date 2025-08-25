using AplicacionCitasMedicasDB.Filtros;
using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Repositorio;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace AplicacionCitasMedicasDB.Controllers
{
    [Administrador]

    public class CitasController : Controller
    {

        private readonly ICita _citaDAO;
        private readonly IPaciente _pacienteDAO;
        private readonly IMedico _medicoDAO;


        public CitasController(ICita citaDAO, IPaciente pacienteDAO, IMedico medicoDAO)
        {
            _citaDAO = citaDAO;
            _pacienteDAO = pacienteDAO;
            _medicoDAO = medicoDAO;
        }


        /*
        // ================== Helpers para combos ==================
        private void CargarCombos(int? idPaciente = null, int? idMedico = null, int? idEstado = null)
        {
            // Pacientes (solo activos)
            var pacientes = _pacienteDAO.GetAll("").Select(p => new
            {
                p.IdPaciente,
                Nombre = $"{p.Nombre} {p.Apellido} ({p.DNI})"
            }).ToList();
            ViewBag.Pacientes = new SelectList(pacientes, "IdPaciente", "Nombre", idPaciente);

            // Médicos
            var medicos = _medicoDAO.GetAll("").Select(m => new
            {
                m.IdMedico,
                Nombre = $"{m.Nombre} {m.Apellido} - {m.CMP}"
            }).ToList();
            ViewBag.Medicos = new SelectList(medicos, "IdMedico", "Nombre", idMedico);

            // Estados de cita
            var estados = _citaDAO.GetEstados().ToList();
            ViewBag.EstadosCita = new SelectList(estados, "IdEstadoCita", "Nombre", idEstado);
        }

        */

        // helper para combos + badge del estado
        private void CargarCombos(int? idPaciente = null, int? idMedico = null, int? idEstado = null)
        {
            var pacientes = _pacienteDAO.GetAll().OrderBy(p => p.Apellido).ThenBy(p => p.Nombre).ToList();
            ViewBag.Pacientes = new SelectList(
                pacientes.Select(p => new {
                    p.IdPaciente,
                    Texto = $"{p.Nombre} {p.Apellido} - {p.DNI}"
                }),
                "IdPaciente", "Texto", idPaciente
            );

            var medicos = _medicoDAO.GetAll().OrderBy(m => m.Apellido).ThenBy(m => m.Nombre).ToList();
            ViewBag.Medicos = new SelectList(
                medicos.Select(m => new {
                    m.IdMedico,
                    Texto = $"{m.Nombre} {m.Apellido} - {m.CMP}"
                }),
                "IdMedico", "Texto", idMedico
            );

            var estados = _citaDAO.GetEstados().ToList();
            ViewBag.EstadosCita = new SelectList(estados, "IdEstadoCita", "Nombre", idEstado);

            // badge para el estado seleccionado
            string? nombreEstado = estados.FirstOrDefault(e => e.IdEstadoCita == idEstado)?.Nombre;
            ViewBag.EstadoBadgeClass = nombreEstado switch
            {
                "Programada" => "bg-primary",
                "Atendida" => "bg-success",
                "Cancelada" => "bg-danger",
                "Reprogramada" => "bg-info",
                "No asistió" => "bg-warning text-dark",
                _ => "bg-secondary"
            };
            ViewBag.EstadoNombre = nombreEstado ?? "—";
        }

        // ================== LISTADO + BÚSQUEDA + PAGINACIÓN ==================
        [HttpGet]
        public async Task<IActionResult> Listado(string? filtro, int page = 1)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            const int pageSize = 15;

            var citas = await Task.Run(() => _citaDAO.GetAll(filtro ?? string.Empty));

            // Orden estable (más recientes primero)
            var ordered = citas
                .OrderByDescending(c => c.Fecha)
                .ThenByDescending(c => c.HoraInicio)
                .ThenByDescending(c => c.IdCita)
                .ToList();

            int totalRegistros = ordered.Count;
            int totalPaginas = (int)Math.Ceiling(totalRegistros / (double)pageSize);
            if (totalPaginas == 0) totalPaginas = 1;
            if (page < 1) page = 1;
            if (page > totalPaginas) page = totalPaginas;

            var pagina = ordered
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToList();

            ViewBag.Filtro = filtro ?? string.Empty;
            ViewBag.PaginaActual = page;
            ViewBag.TotalPaginas = totalPaginas;
            ViewBag.TotalRegistros = totalRegistros;

            return View(pagina);
        }

        // ================== CREAR ==================
        [HttpGet]
        public IActionResult Crear()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");


            CargarCombos(); 
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Crear(Cita cita)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            if (!ModelState.IsValid)
            {
                CargarCombos(cita.IdPaciente, cita.IdMedico, cita.IdEstadoCita);
                return View(cita);
            }

            var (code, msg) = await Task.Run(() => _citaDAO.Add(cita));
            if (code <= 0)
            {
                // Mostrar motivo y permanecer en la vista
                ModelState.AddModelError(string.Empty, msg);
                CargarCombos(cita.IdPaciente, cita.IdMedico, cita.IdEstadoCita);
                return View(cita);
            }

            TempData["mensaje"] = msg;
            return RedirectToAction(nameof(Listado));
        }

        // ================== EDITAR ==================
        [HttpGet]
        public async Task<IActionResult> Editar(int id)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var cita = await Task.Run(() => _citaDAO.Search(id));
            if (cita == null) return NotFound();

            CargarCombos(cita.IdPaciente, cita.IdMedico, cita.IdEstadoCita);
            return View(cita);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Editar(Cita cita)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            if (!ModelState.IsValid)
            {
                CargarCombos(cita.IdPaciente, cita.IdMedico, cita.IdEstadoCita);
                return View(cita);
            }

            var (code, msg) = await Task.Run(() => _citaDAO.Update(cita));
            if (code <= 0)
            {
                ModelState.AddModelError(string.Empty, msg);
                CargarCombos(cita.IdPaciente, cita.IdMedico, cita.IdEstadoCita);
                return View(cita);
            }

            TempData["mensaje"] = msg;
            return RedirectToAction(nameof(Listado));
        }

        // ================== DETALLE ==================
        [HttpGet]
        public async Task<IActionResult> Detalle(int id)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var cita = await Task.Run(() => _citaDAO.Search(id));
            if (cita == null) return NotFound();
            return View(cita);
        }

        // ================== ELIMINAR (BAJA LÓGICA) ==================
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Eliminar(int id, string? filtro, int page = 1)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");

            var msg = await Task.Run(() => _citaDAO.Delete(new Cita { IdCita = id }));
            TempData["mensaje"] = msg;

            // conservar filtro y página
            return RedirectToAction(nameof(Listado), new { filtro, page });
        }

    }
}
