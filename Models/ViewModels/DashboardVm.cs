namespace AplicacionCitasMedicasDB.Models.ViewModels
{
    public class Serie
    {
        public string label { get; set; } = "";
        public int[] data { get; set; } = Array.Empty<int>();
    }

    public class DashboardVm
    {
        // KPIs
        public int PacientesActivos { get; set; }
        public int MedicosActivos { get; set; }
        public int CitasHoy { get; set; }
        public double NoShowPct30d { get; set; }

        // Gráfica: Citas por especialidad (últimas 8 semanas)
        public string[] LabelsSemanas { get; set; } = Array.Empty<string>();
        public List<Serie> CitasPorEspecialidad { get; set; } = new();

        // Gráfica: Altas/Bajas de pacientes (últimos 6 meses)
        public string[] LabelsMeses { get; set; } = Array.Empty<string>();
        public int[] Altas { get; set; } = Array.Empty<int>();
        public int[] Bajas { get; set; } = Array.Empty<int>();
        public List<Medico> ActividadMedicos { get; set; } = new();

    }
}
