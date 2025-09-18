// Comentarios en español.
// Lógica de cálculo de precio con redondeo hacia arriba por hora.

class PriceCalculator {
  // Retorna el total a cobrar en pesos (COP) y las horas cobradas.
  static ({int total, int hours}) calculate({
    required DateTime entry,
    required DateTime exit,
    required String type, // 'car' o 'moto'
  }) {
    final minutes = exit.difference(entry).inMinutes;
    final minutesNonNegative = minutes < 0 ? 0 : minutes;
    final hours = ((minutesNonNegative + 59) ~/ 60); // redondeo hacia arriba
    final base = type == 'car' ? 3000 : 1500;
    final extra = type == 'car' ? 500 : 200;

    final total = hours <= 1 ? base : base + (hours - 1) * extra;
    return (total: total, hours: hours == 0 ? 1 : hours); // mínimo 1 hora
  }

  // Helper para mostrar tipo en español.
  static String typeLabelEs(String type) => type == 'car' ? 'Carro' : 'Moto';
}
