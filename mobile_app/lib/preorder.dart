class SizeGuide {
  const SizeGuide(this.label, this.dimensions, this.serves, this.occasion);

  final String label;
  final String dimensions;
  final String serves;
  final String occasion;
}

const _sizes = <String, SizeGuide>{
  'tub': SizeGuide(
    'Tub',
    'Single tub',
    '1–2 pax',
    'A personal merienda or a small pasalubong',
  ),
  '250ml-tub': SizeGuide(
    'Tub',
    'Single tub',
    '1–2 pax',
    'A personal merienda or a small pasalubong',
  ),
  'extra-small': SizeGuide(
    'X-Small',
    '10-inch bilao',
    '4–6 pax',
    'A quiet family snack or a gift to bring along',
  ),
  '10-bilao-xs': SizeGuide(
    'X-Small',
    '10-inch bilao',
    '4–6 pax',
    'A quiet family snack or a gift to bring along',
  ),
  'small': SizeGuide(
    'Small',
    '12-inch bilao',
    '8–10 pax',
    'Small gatherings and office merienda',
  ),
  '12-bilao-s': SizeGuide(
    'Small',
    '12-inch bilao',
    '8–10 pax',
    'Small gatherings and office merienda',
  ),
  'medium': SizeGuide(
    'Medium',
    '16-inch bilao',
    '15–20 pax',
    'Birthdays, reunions, and handaan',
  ),
  '16-bilao-m': SizeGuide(
    'Medium',
    '16-inch bilao',
    '15–20 pax',
    'Birthdays, reunions, and handaan',
  ),
  'large': SizeGuide(
    'Large',
    '18-inch bilao',
    '25–30 pax',
    'Fiestas, weddings, and big celebrations',
  ),
  '18-bilao-l': SizeGuide(
    'Large',
    '18-inch bilao',
    '25–30 pax',
    'Fiestas, weddings, and big celebrations',
  ),
};

String _handle(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

SizeGuide sizeGuide(String variantTitle) =>
    _sizes[_handle(variantTitle)] ?? SizeGuide(variantTitle, '', '', '');

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSpecialDate(DateTime date) =>
    (date.month == 11 && date.day == 1) ||
    (date.month == 12 && (date.day == 24 || date.day == 31));

String? preorderDateError(DateTime selected, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final date = dateOnly(selected);
  final days = date.difference(today).inDays;
  if (days < 1) return 'Please choose tomorrow or later.';
  if (isSpecialDate(date) && days < 7) {
    return 'November 1, December 24, and December 31 require seven days’ notice.';
  }
  return null;
}

DateTime firstAvailableDate({DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  var date = today.add(const Duration(days: 1));
  while (preorderDateError(date, now: today) != null) {
    date = date.add(const Duration(days: 1));
  }
  return date;
}

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String formatDate(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}

String productStory(String handle) => switch (handle) {
  'sapin-sapin' =>
    'Sapin-sapin means “layer upon layer”: three tinted layers of glutinous rice and coconut milk, finished with golden, nutty latik.',
  'puto' =>
    'Light, faintly sweet steamed rice cakes, made in small batches so they arrive tender rather than dense.',
  'kutsinta' =>
    'Deep amber steamed rice cakes with a springy chew, served with freshly grated coconut on the side.',
  'maha' || 'maja' || 'maja-blanca' =>
    'A gentle coconut milk pudding with sweet corn and toasted latik, best served chilled.',
  _ => 'Freshly steamed to order in our home kitchen in Imus, Cavite.',
};
