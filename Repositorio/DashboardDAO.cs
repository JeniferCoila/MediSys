using System.Globalization;
using AplicacionCitasMedicasDB.Models;
using AplicacionCitasMedicasDB.Models.ViewModels;

namespace AplicacionCitasMedicasDB.Repositorio
{
    public class DashboardDAO : IDashboardDAO
    {
        private readonly IBajasMedico _bajasMedicoDAO;
        private readonly IBajasPaciente _bajasPacienteDAO;
        private readonly ICita _citaDAO;
        private readonly IPaciente _pacienteDAO;
        private readonly IMedico _medicoDAO;

        public DashboardDAO(
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

        public DashboardVm Build()
        {
            var ahora = DateTime.Now;
            var hoy = DateTime.Today;
            var pe = new CultureInfo("es-PE");

            // Base
            var pacientes = _pacienteDAO.GetAll(null);
            var medicos   = _medicoDAO.GetAll(string.Empty);
            var citas     = _citaDAO.GetAll(string.Empty);
            var estados   = _citaDAO.GetEstados();

            // Maps
            var mapEstado   = estados.ToDictionary(e => e.IdEstadoCita, e => e.Nombre);
            var mapMedico   = medicos.ToDictionary(m => m.IdMedico, m => m);
            var mapPaciente = pacientes.ToDictionary(p => p.IdPaciente, p => p);

            // KPIs
            int pacientesActivos = pacientes.Count(p => p.FechaBaja == null);
            int medicosActivos   = medicos.Count(m => m.FechaBaja == null);
            int citasHoy         = citas.Count(c => c.Fecha.Date == hoy);

            double noShowPct30 = 0;
            var desde30 = hoy.AddDays(-30);
            var ult30 = citas.Where(c => c.Fecha >= desde30 && c.Fecha <= ahora).ToList();
            if (ult30.Count > 0)
            {
                int noShow = ult30.Count(c =>
                    mapEstado.TryGetValue(c.IdEstadoCita, out var n) &&
                    string.Equals(n, "No asistió", StringComparison.OrdinalIgnoreCase));
                noShowPct30 = Math.Round(100.0 * noShow / ult30.Count, 1);
            }
            var kpis = new KpisVm(pacientesActivos, medicosActivos, citasHoy, noShowPct30);

            // Citas por especialidad (8 semanas)
            var desdeSem = hoy.AddDays(-56);
            string[] labelsSem = Enumerable.Range(0, 8).Select(i => $"S{i+1}").ToArray();
            int SemanaIndex(DateTime f) => Math.Clamp((int)((f.Date - desdeSem).TotalDays / 7), 0, 7);
            string EspDe(int idMedico) =>
                mapMedico.TryGetValue(idMedico, out var m) && !string.IsNullOrWhiteSpace(m.NombreEspecialidad)
                ? m.NombreEspecialidad! : "—";

            var citas8 = citas.Where(c => c.Fecha >= desdeSem).ToList();
            var seriesEsp = citas8
                .GroupBy(c => EspDe(c.IdMedico))
                .Select(g => new SerieVm(
                    g.Key,
                    Enumerable.Range(0,8).Select(i => g.Count(c => SemanaIndex(c.Fecha)==i)).ToArray()
                ))
                .OrderBy(s => s.Label)
                .ToList();
            var especialidades = new EspecialidadesChartVm(labelsSem, seriesEsp);

            // Altas/Bajas (6 meses)
            var inicio = new DateTime(hoy.Year, hoy.Month, 1).AddMonths(-5);
            var meses = Enumerable.Range(0,6).Select(i => inicio.AddMonths(i)).ToArray();
            var labelsMes = meses.Select(d => d.ToString("MMM", pe)).ToArray();

            var pacientesBaja = _bajasPacienteDAO.GetAllBajas(null);
            var todosPac = pacientes.Concat(pacientesBaja).GroupBy(p => p.IdPaciente).Select(g => g.First()).ToList();

            int[] altas = meses.Select(m =>
                todosPac.Count(p =>
                    p.FechaCreacion.Year == m.Year &&
                    p.FechaCreacion.Month == m.Month
                )
            ).ToArray();


            int[] bajas = meses.Select(m =>
                pacientesBaja.Count(p => p.FechaBaja.HasValue &&
                                         p.FechaBaja.Value.Year==m.Year &&
                                         p.FechaBaja.Value.Month==m.Month)).ToArray();

            var altasBajas = new AltasBajasChartVm(labelsMes, altas, bajas);

            // Citas HOY (tabla)
            static string Nombre(string? n, string? a) => $"{n} {a}".Trim();
            string DoctorNombre(Medico m) => $"Dr. {Nombre(m.Nombre, m.Apellido)}";

            var citasHoyList = citas
                .Where(c => c.Fecha.Date == hoy)
                .OrderBy(c => c.HoraInicio)
                .Select(c =>
                {
                    var doc = mapMedico.GetValueOrDefault(c.IdMedico);
                    var pac = mapPaciente.GetValueOrDefault(c.IdPaciente);
                    var estado = mapEstado.GetValueOrDefault(c.IdEstadoCita, "—");

                    return new CitaResumenVm(
                        c.HoraInicio.ToString(@"hh\:mm"),
                        doc is null ? "—" : DoctorNombre(doc),
                        doc?.NombreEspecialidad ?? "—",
                        pac is null ? "—" : Nombre(pac.Nombre, pac.Apellido),
                        estado
                    );
                })
                .ToList();

            // Actividad médicos
            var medBajas = _bajasMedicoDAO.GetAllBajas(null);
            DateTime EventOf(Medico m) => m.FechaBaja ?? m.FechaActualizacion ?? m.FechaCreacion ?? DateTime.MinValue;
            string Tipo(Medico m) => m.FechaBaja.HasValue ? "Baja" : "Alta";

            var actividad = medicos.Concat(medBajas)
                .GroupBy(m => m.IdMedico)
                .Select(g => g.OrderByDescending(EventOf).First())
                .Where(m => EventOf(m) > DateTime.MinValue)
                .OrderByDescending(EventOf)
                .Take(8)
                .Select(m => new MedicoActividadVm(
                    m.IdMedico,
                    Nombre(m.Nombre, m.Apellido),
                    m.FotoUrl,
                    Tipo(m),
                    EventOf(m).ToString("dd MMM yyyy HH:mm", pe)))
                .ToList();

            // VM final
            return new DashboardVm
            {
                Kpis = kpis,
                Especialidades = especialidades,
                AltasBajas = altasBajas,
                CitasHoy = citasHoyList,
                ActividadMedicos = actividad
            };
        }
    }
}
