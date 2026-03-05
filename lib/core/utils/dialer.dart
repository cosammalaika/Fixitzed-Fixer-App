import 'package:fixitzed_fixer_app/core/utils/phone_utils.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> callNumber(String phone) async {
  final normalized = normalizeZambianNumber(phone);
  final uri = Uri.parse('tel:$normalized');

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
    return true;
  }

  return false;
}
