using System.Globalization;
using AplicacionCitasMedicasDB.Models.ViewModels;

using AplicacionCitasMedicasDB.Filtros;
using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Repositorio;
using Microsoft.AspNetCore.Mvc;


namespace AplicacionCitasMedicasDB.Controllers
{

    [Administrador]
    public class AdminController : Controller
    {
        private readonly IBajasMedico _bajasMedicoDAO;
        private readonly IBajasPaciente _bajasPacienteDAO;

        // NUEVO: DAOs para armar el dashboard
        private readonly ICita _citaDAO;
        private readonly IPaciente _pacienteDAO;
        private readonly IMedico _medicoDAO;

        private const int PageSize = 15;

        public AdminController(
            IBajasMedico bajasMedicoDAO,
            IBajasPaciente bajasPacienteDAO,
            ICita citaDAO,
            IPaciente pacienteDAO,
            IMedico medicoDAO)
        {
            _bajasMedicoDAO = bajasMedicoDAO;
            _bajasPacienteDAO = bajasPacienteDAO;
            _citaDAO = citaDAO;
            _pacienteDAO = pacienteDAO;
            _medicoDAO = medicoDAO;
        }


        public async Task<IActionResult> Menu()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Index", "Login");
            var vm = await BuildDashboardAsync();   // ← await aquí

            return View(vm);
        }

        // ===== Helper privado: arma el ViewModel del dashboard =====
        private async Task<DashboardVm> BuildDashboardAsync()
        {
            var hoy = DateTime.Today;
            var ahora = DateTime.Now;

            // Trae datos base (simple y rápido)
            var pacientes = await Task.Run(() => _pacienteDAO.GetAll(null));
            var medicos = await Task.Run(() => _medicoDAO.GetAll(string.Empty));
            var citas = await Task.Run(() => _citaDAO.GetAll(string.Empty));
            var estados = await Task.Run(() => _citaDAO.GetEstados());

            var mapEstado = estados.ToDictionary(e => e.IdEstadoCita, e => e.Nombre);
            var mapEspPorMedico = medicos.ToDictionary(
                m => m.IdMedico,
                m => string.IsNullOrWhiteSpace(m.NombreEspecialidad) ? "—" : m.NombreEspecialidad!
            );

            var vm = new DashboardVm
            {
                PacientesActivos = pacientes.Count(p => p.FechaBaja == null),
                MedicosActivos = medicos.Count(m => m.FechaBaja == null),
                CitasHoy = citas.Count(c => c.Fecha.Date == hoy)
            };

            // No-show 30 días (ajusta el nombre del estado si difiere)
            var hace30 = hoy.AddDays(-30);
            var ult30 = citas.Where(c => c.Fecha >= hace30 && c.Fecha <= ahora).ToList();
            if (ult30.Count > 0)
            {
                int noShow = ult30.Count(c =>
                    c.IdEstadoCita != 0 &&
                    mapEstado.TryGetValue(c.IdEstadoCita, out var n) &&
                    string.Equals(n, "No asistió", StringComparison.OrdinalIgnoreCase));
                vm.NoShowPct30d = Math.Round(100.0 * noShow / ult30.Count, 1);
            }

            // Citas por especialidad (últ. 8 semanas)
            var desdeSem = hoy.AddDays(-56);
            vm.LabelsSemanas = Enumerable.Range(0, 8).Select(i => $"S{i + 1}").ToArray();
            int idx(DateTime f) => Math.Min(7, Math.Max(0, (int)((f.Date - desdeSem).TotalDays / 7)));

            var citas8 = citas.Where(c => c.Fecha >= desdeSem).ToList();
            vm.CitasPorEspecialidad = citas8
                .GroupBy(c => mapEspPorMedico.TryGetValue(c.IdMedico, out var esp) ? esp : "—")
                .Select(g => new Serie
                {
                    label = g.Key,
                    data = Enumerable.Range(0, 8).Select(i => g.Count(c => idx(c.Fecha) == i)).ToArray()
                })
                .OrderBy(s => s.label)
                .ToList();

            // Altas/Bajas últimos 6 meses
            var desdeMes = new DateTime(hoy.Year, hoy.Month, 1).AddMonths(-5);
            var meses = Enumerable.Range(0, 6).Select(i => desdeMes.AddMonths(i)).ToArray();
            var pe = new CultureInfo("es-PE");
            vm.LabelsMeses = meses.Select(d => d.ToString("MMM", pe)).ToArray();

            // NUEVO: trae pacientes dados de baja con tu DAO de bajas
            var pacientesBaja = await Task.Run(() => _bajasPacienteDAO.GetAllBajas(null));

            // Unifica pacientes (activos + baja) para contar ALTAS históricas
            var todosPacientes = pacientes
                .Concat(pacientesBaja)
                .GroupBy(p => p.IdPaciente)
                .Select(g => g.First())
                .ToList();

            vm.Altas = meses.Select(m =>
                todosPacientes.Count(p => p.FechaCreacion.Year == m.Year &&
                                          p.FechaCreacion.Month == m.Month)
            ).ToArray();

            vm.Bajas = meses.Select(m =>
                pacientesBaja.Count(p => p.FechaBaja.HasValue &&
                                         p.FechaBaja.Value.Year == m.Year &&
                                         p.FechaBaja.Value.Month == m.Month)
            ).ToArray();

            var activos = await Task.Run(() => _medicoDAO.GetAll(string.Empty));
            var bajas = await Task.Run(() => _bajasMedicoDAO.GetAllBajas(null)); // trae FechaBaja

            Func<Medico, DateTime> evento = m =>
                m.FechaBaja ?? m.FechaCreacion ?? m.FechaActualizacion ?? DateTime.MinValue;

            vm.ActividadMedicos = activos
                .Concat(bajas)
                .GroupBy(m => m.IdMedico)
                .Select(g => g.OrderByDescending(evento).First()) // evita quedarte con la versión “vacía”
                .Where(m => evento(m) > DateTime.MinValue)        // sin fecha -> no mostrar
                .OrderByDescending(evento)
                .Take(8)
                .ToList();

            return vm;
        }


        /* VISTA PARA LISTAR MEDICOS DADOS DE BAJA */
        [HttpGet]
        public async Task<IActionResult> ListadoMedicosBajas(string? filtro, int page = 1)
        {
          
 
            ViewBag.Filtro = filtro;

            var lista = await Task.Run(() => _bajasMedicoDAO.GetAllBajas(filtro));
            int total = lista.Count();
            int totalPages = Math.Max(1, (int)Math.Ceiling(total / (double)PageSize));
            page = Math.Clamp(page, 1, totalPages);

            var medicosPagina = lista.Skip((page - 1) * PageSize).Take(PageSize).ToList();

            ViewBag.PaginaActual = page;
            ViewBag.TotalPaginas = totalPages;
            ViewBag.TotalRegistros = total;
            ViewBag.PageSize = PageSize;

            return View(medicosPagina);
        }

 
        /* METODO PARA ACTIVAR MEDICO */
        [HttpPost]
        public async Task<IActionResult> ActivarMedico(int id, string? filtro, int page = 1)
        {
            Medico medico = await Task.Run(() => _bajasMedicoDAO.SearchMedicoBaja(id));
            if (medico == null)
            {
                TempData["mensaje"] = "El médico no existe o ya está activo.";
                return RedirectToAction(nameof(ListadoMedicosBajas));
            }
            var result = await Task.Run(() => _bajasMedicoDAO.activar(medico));
            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(ListadoMedicosBajas), new { filtro, page });

        }




        /* VISTA PARA LISTAR PACIENTES DADOS DE BAJA */
        [HttpGet]
        public async Task<IActionResult> ListadoPacientesBajas(string? filtro, int page = 1)
        {


            ViewBag.Filtro = filtro;

            var lista = await Task.Run(() => _bajasPacienteDAO.GetAllBajas(filtro));
            int total = lista.Count();
            int totalPages = Math.Max(1, (int)Math.Ceiling(total / (double)PageSize));
            page = Math.Clamp(page, 1, totalPages);

            var pacientesPagina = lista.Skip((page - 1) * PageSize).Take(PageSize).ToList();

            ViewBag.PaginaActual = page;
            ViewBag.TotalPaginas = totalPages;
            ViewBag.TotalRegistros = total;
            ViewBag.PageSize = PageSize;

            return View(pacientesPagina);
        }


        /* METODO PARA ACTIVAR MEDICO */
        [HttpPost]
        public async Task<IActionResult> ActivarPaciente(int id, string? filtro, int page = 1)
        {
            Paciente paciente = await Task.Run(() => _bajasPacienteDAO.SearchPacienteBaja(id));
            if (paciente == null)
            {
                TempData["mensaje"] = "El paciente no existe o ya está activo.";
                return RedirectToAction(nameof(ListadoPacientesBajas));
            }
            var result = await Task.Run(() => _bajasPacienteDAO.activar(paciente));
            TempData["mensaje"] = result.message;
            return RedirectToAction(nameof(ListadoPacientesBajas), new { filtro, page });

        }




    }
}
