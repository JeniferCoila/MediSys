namespace AplicacionCitasMedicasDB.Models.ViewModels
{
    public record KpisVm(int PacientesActivos, int MedicosActivos, int CitasHoy, double NoShowPct30d);
    public record SerieVm(string Label, int[] Data);
    public record EspecialidadesChartVm(string[] LabelsSemanas, IReadOnlyList<SerieVm> Series);
    public record AltasBajasChartVm(string[] LabelsMeses, int[] Altas, int[] Bajas);
    public record CitaResumenVm(string Hora, string Doctor, string Especialidad, string Paciente, string Estado);
    public record MedicoActividadVm(int IdMedico, string Nombre, string? FotoUrl, string Tipo, string FechaTexto);

    public class DashboardVm
    {
        public KpisVm Kpis { get; init; } = new(0, 0, 0, 0);
        public EspecialidadesChartVm Especialidades { get; init; } = new(Array.Empty<string>(), Array.Empty<SerieVm>());
        public AltasBajasChartVm AltasBajas { get; init; } = new(Array.Empty<string>(), Array.Empty<int>(), Array.Empty<int>());
        public IReadOnlyList<CitaResumenVm> CitasHoy { get; init; } = Array.Empty<CitaResumenVm>();
        public IReadOnlyList<MedicoActividadVm> ActividadMedicos { get; init; } = Array.Empty<MedicoActividadVm>();
    }
}
