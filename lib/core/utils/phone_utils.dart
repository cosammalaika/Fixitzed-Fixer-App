String normalizeZambianNumber(String phone) {
  var value = phone.trim();
  if (value.isEmpty) return value;

  value = value.replaceAll(RegExp(r'[\s\-()]'), '');

  if (value.startsWith('+260')) return value;

  if (value.startsWith('0') && value.length >= 10) {
    return '+260${value.substring(1)}';
  }

  if (value.length == 9 && RegExp(r'^[789]\d{8}$').hasMatch(value)) {
    return '+260$value';
  }

  return value;
}
