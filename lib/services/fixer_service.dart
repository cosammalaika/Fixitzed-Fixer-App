import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fixer.dart';
import '../models/service_request.dart';
import 'api_client.dart';

class FixerService {
  final _api = ApiClient.I;

  Future<Map<String, dynamic>?> dashboard() async {
    final res = await _api.get('/api/fixer/dashboard');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    return null;
  }

  Future<List<ServiceRequest>> requests({String? status}) async {
    final res = await _api.get('/api/fixer/requests', query: {
      if (status != null) 'status': status,
    });
    if (res.statusCode == 200) {
      final root = jsonDecode(res.body);
      if (root is Map<String, dynamic>) {
        final data = root['data'];
        final list = (data is Map<String, dynamic>) ? (data['data'] as List?) : (data as List?);
        if (list != null) {
          return list
              .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } else if (root is List) {
        return root
            .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<List<ServiceRequest>> requestsToday() async {
    final res = await _api.get('/api/fixer/requests/today');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<ServiceRequest?> transition(int id, String action) async {
    final res = await _api.patch('/api/fixer/requests/$id/$action', body: {});
    if (res.statusCode == 200) {
      return ServiceRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    return null;
  }

  // Accept a service request for this fixer according to provided routes
  Future<bool> acceptRequest(int id) async {
    final res = await _api.post('/api/service-requests/$id/accept', body: {});
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // Fetch a single request detail (may include contact info)
  Future<Map<String, dynamic>?> requestDetail(int id) async {
    final res = await _api.get('/api/requests/$id');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return null;
  }

  // Wallet: balance and coins remaining
  Future<Map<String, dynamic>> wallet() async {
    final res = await _api.get('/api/fixer/wallet');
    if (res.statusCode == 200) {
      final root = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (root['data'] ?? root) as Map<String, dynamic>;
      return data;
    }
    return {};
  }

  Future<Fixer?> updateMe({String? bio, String? availability, List<int>? serviceIds}) async {
    final body = <String, dynamic>{
      if (bio != null) 'bio': bio,
      if (availability != null) 'availability': availability,
      if (serviceIds != null) 'service_ids': serviceIds,
    };
    final res = await _api.patch('/api/fixer/me', body: body);
    if (res.statusCode == 200) {
      return Fixer.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    return null;
  }

  Future<bool> uploadAvatar(String filePath) async {
    final req = await _api.multipart('/api/me/avatar', method: 'POST');
    req.files.add(await http.MultipartFile.fromPath('avatar', filePath));
    final streamed = await req.send();
    return streamed.statusCode == 200;
  }
}
