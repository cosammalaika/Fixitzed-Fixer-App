import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_client.dart';
import '../../services/loyalty_service.dart';
import '../../services/subscription_service.dart';

class SubscriptionCheckoutSheet extends StatefulWidget {
  final Map<String, dynamic> plan;
  const SubscriptionCheckoutSheet({super.key, required this.plan});

  @override
  State<SubscriptionCheckoutSheet> createState() =>
      _SubscriptionCheckoutSheetState();
}

class _SubscriptionCheckoutSheetState extends State<SubscriptionCheckoutSheet> {
  final _api = ApiClient.I;
  final _loyalty = LoyaltyService();
  final _subscription = SubscriptionService();

  bool _loading = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _methods = [];
  String _method = 'cash';
  Map<String, dynamic>? _selectedMethod;

  int _loyaltyBalance = 0;
  double _pointValue = 1;
  int _loyaltyToUse = 0;
  bool _useLoyalty = false;
  double _loyaltyDiscount = 0;
  int _loyaltyThreshold = 0;

  double get _priceKwacha {
    final cents = (widget.plan['price_cents'] as num?)?.toDouble() ?? 0;
    return cents / 100;
  }

  int get _planId => (widget.plan['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> methods;
    try {
      methods = await _fetchMethods();
    } catch (_) {
      methods = _defaultMethods();
    }

    Map<String, dynamic>? loyalty;
    try {
      loyalty = await _loyalty.summary();
    } catch (_) {
      loyalty = null;
    }

    if (!mounted) return;

    setState(() {
      _methods = methods.isEmpty ? _defaultMethods() : methods;
      if (_methods.isNotEmpty) {
        _selectedMethod = _methods.first;
        _method = (_selectedMethod?['code'] ?? 'cash').toString();
      } else {
        _selectedMethod = null;
        _method = 'cash';
      }

      final points = loyalty?['points'];
      final pointValueRaw = loyalty?['point_value'];
      final thresholdRaw = loyalty?['threshold'];

      _loyaltyBalance = points is num
          ? points.toInt()
          : int.tryParse(points?.toString() ?? '') ?? 0;

      _pointValue = pointValueRaw is num
          ? pointValueRaw.toDouble()
          : double.tryParse(pointValueRaw?.toString() ?? '') ?? 1;
      if (_pointValue <= 0) _pointValue = 1;

      _loyaltyThreshold = thresholdRaw is num
          ? thresholdRaw.toInt()
          : int.tryParse(thresholdRaw?.toString() ?? '') ?? 0;

      final eligible =
          _loyaltyThreshold <= 0 || _loyaltyBalance >= _loyaltyThreshold;
      _useLoyalty = eligible && _loyaltyBalance > 0;
      _loading = false;
    });

    _recalculateLoyalty(reset: true);
  }

  Future<List<Map<String, dynamic>>> _fetchMethods() async {
    try {
      final res = await _api.get('/api/payment-methods');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is List) {
          final list = (body['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    } catch (_) {}
    return _defaultMethods();
  }

  List<Map<String, dynamic>> _defaultMethods() {
    return [
      {
        'name': 'Pay via Mobile Money',
        'title': 'Pay via Mobile Money',
        'code': 'cash',
        'is_manual': true,
        'phone': '+260979871199',
        'account': 'Fixitzed Subs',
        'instructions':
            '1. Send :amount to :phone (:account).\n2. Use reference :reference in the payment description.\n3. Notify support once payment is sent.',
      },
    ].map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int _maxRedeemablePointsForAmount(double amount) {
    if (_pointValue <= 0) return 0;
    final pts = (amount / _pointValue).floor();
    return pts > 0 ? pts : 0;
  }

  void _recalculateLoyalty({bool reset = false}) {
    if (!mounted) return;
    final price = _priceKwacha;
    final thresholdMet =
        _loyaltyThreshold <= 0 || _loyaltyBalance >= _loyaltyThreshold;
    var useLoyalty = _useLoyalty && thresholdMet;
    var target = useLoyalty ? _loyaltyToUse : 0;
    if (useLoyalty) {
      final cap = math.min(
        _loyaltyBalance,
        _maxRedeemablePointsForAmount(price),
      );
      if (reset) {
        target = cap;
      }
      if (target > cap) {
        target = cap;
      }
      if (cap <= 0) {
        useLoyalty = false;
        target = 0;
      }
    }
    final discount = target * _pointValue;
    setState(() {
      _useLoyalty = useLoyalty;
      _loyaltyToUse = useLoyalty ? target : 0;
      _loyaltyDiscount = useLoyalty ? discount : 0;
    });
  }

  double get _amountDue =>
      (_priceKwacha - _loyaltyDiscount).clamp(0, _priceKwacha);

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final result = await _subscription.purchase(
      planId: _planId,
      method: _method,
      loyaltyPoints: _useLoyalty ? _loyaltyToUse : 0,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null || result['success'] != true) {
      final message =
          result?['message']?.toString() ??
          'Failed to complete purchase. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final data = result['data'] as Map<String, dynamic>?;
    final message = result['message']?.toString();

    if (data?['requires_manual_payment'] == true) {
      await _showManualInstructionsDialog(data ?? const {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ??
                'Payment request submitted. We will notify you once approved.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Subscription purchased successfully.'),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFFF1592A);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 12,
        ),
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.plan['name']?.toString() ?? 'Plan',
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'K${_priceKwacha.toStringAsFixed(2)} · ${widget.plan['coins']} coins · ${widget.plan['valid_days']} days',
                    style: GoogleFonts.urbanist(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  _loyaltySection(brand),
                  const SizedBox(height: 16),
                  Text(
                    'Payment Method',
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ..._methods.map((m) => _methodTile(m, brand)).toList(),
                  _manualInstructionsCard(brand),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount due',
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'K${_amountDue.toStringAsFixed(2)}',
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w800,
                          color: brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _submitting ? 'Processing…' : 'Confirm Purchase',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _manualInstructionsCard(Color brand) {
    final method = _selectedMethod;
    final isManual = method?['is_manual'] == true;
    final raw = method?['instructions']?.toString().trim();
    if (!isManual || raw == null || raw.isEmpty) {
      return const SizedBox.shrink();
    }

    final preview = _previewInstructions(raw, method!);
    final lines = preview
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final phone = method['phone']?.toString();
    final account = method['account']?.toString();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brand.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Where to send payment',
                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (phone != null || account != null) ...[
            if (phone != null) _metaRow('Mobile number', phone, brand),
            if (account != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _metaRow('Account name', account, brand),
              ),
            const SizedBox(height: 12),
          ],
          for (final line in lines) _instructionBullet(line),
          const SizedBox(height: 12),
          Text(
            'After you submit the request we will confirm the payment and credit your coins.',
            style: GoogleFonts.urbanist(color: Colors.black54, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  String _previewInstructions(String template, Map<String, dynamic> method) {
    var output = template;
    output = output.replaceAll(':amount', 'K${_amountDue.toStringAsFixed(2)}');
    output = output.replaceAll(
      ':plan',
      widget.plan['name']?.toString() ?? 'this plan',
    );
    output = output.replaceAll(
      ':coins',
      widget.plan['coins']?.toString() ?? '',
    );
    output = output.replaceAll(
      ':method',
      method['title']?.toString() ??
          method['name']?.toString() ??
          method['code']?.toString() ??
          'this method',
    );
    output = output.replaceAll(
      ':reference',
      'the payment reference we will send you',
    );
    output = output.replaceAll(':phone', method['phone']?.toString() ?? '');
    output = output.replaceAll(':account', method['account']?.toString() ?? '');
    return output;
  }

  Widget _instructionBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.urbanist(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualInstructionsDialog(Map<String, dynamic> data) async {
    final brand = const Color(0xFFF1592A);
    final instructions = data['payment_instructions']?.toString().trim() ?? '';
    final reference = data['payment_reference']?.toString();
    final title = data['payment_title']?.toString() ?? 'Payment Instructions';
    final amount = data['amount_due'];
    final amountDisplay = amount is num
        ? 'K${amount.toDouble().toStringAsFixed(2)}'
        : null;
    final phone =
        data['payment_phone']?.toString() ??
        _selectedMethod?['phone']?.toString();
    final account =
        data['payment_account']?.toString() ??
        _selectedMethod?['account']?.toString();
    final lines = instructions.isNotEmpty
        ? instructions
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList()
        : <String>[];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (amountDisplay != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Amount due: $amountDisplay',
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (phone != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _metaRow('Mobile number', phone, brand),
                  ),
                if (account != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _metaRow('Account name', account, brand),
                  ),
                if (reference?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _referenceRow(reference!, brand),
                  ),
                if (lines.isNotEmpty)
                  ...lines.map(_instructionBullet)
                else
                  Text(
                    'Follow the instructions shared by the team to complete your payment.',
                    style: GoogleFonts.urbanist(color: Colors.black87),
                  ),
                const SizedBox(height: 12),
                Text(
                  'We will review your payment and credit the coins once approved.',
                  style: GoogleFonts.urbanist(
                    color: Colors.black54,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _referenceRow(String reference, Color brand) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SelectableText(
            'Reference: $reference',
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded),
          color: brand,
          tooltip: 'Copy reference',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: reference));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reference copied to clipboard')),
            );
          },
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value, Color brand) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SelectableText(
            '$label: $value',
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded),
          color: brand,
          tooltip: 'Copy $label',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$label copied')));
          },
        ),
      ],
    );
  }

  Widget _loyaltySection(Color brand) {
    if (_loyaltyBalance <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Earn loyalty points when you pay for plans or complete jobs. Redeem them to reduce future purchases!',
          style: GoogleFonts.urbanist(color: Colors.black54, fontSize: 13),
        ),
      );
    }

    final thresholdMet =
        _loyaltyThreshold <= 0 || _loyaltyBalance >= _loyaltyThreshold;
    final sliderMax = thresholdMet
        ? math.min(_loyaltyBalance, _maxRedeemablePointsForAmount(_priceKwacha))
        : 0;
    final canRedeem = sliderMax > 0 && _priceKwacha > 0;
    final balanceValue = (_loyaltyBalance * _pointValue).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loyalty balance: $_loyaltyBalance pts',
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '≈ K$balanceValue',
                      style: GoogleFonts.urbanist(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _useLoyalty && canRedeem,
                activeColor: brand,
                onChanged: canRedeem && thresholdMet
                    ? (value) {
                        setState(() {
                          _useLoyalty = value;
                        });
                        _recalculateLoyalty(reset: value);
                      }
                    : null,
              ),
            ],
          ),
          if (!thresholdMet)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Earn ${math.max(0, _loyaltyThreshold - _loyaltyBalance)} more points to unlock redemptions.',
                style: GoogleFonts.urbanist(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            )
          else if (!canRedeem)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Not enough points to reduce this purchase yet.',
                style: GoogleFonts.urbanist(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          if (canRedeem) ...[
            const SizedBox(height: 12),
            Slider(
              value: _loyaltyToUse.toDouble().clamp(0, sliderMax.toDouble()),
              min: 0,
              max: sliderMax.toDouble(),
              divisions: sliderMax,
              label: '${_loyaltyToUse} pts',
              activeColor: brand,
              onChanged: (value) {
                setState(() {
                  _useLoyalty = value > 0;
                  _loyaltyToUse = value.round();
                });
                _recalculateLoyalty(reset: false);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Redeeming ${_loyaltyToUse} pts',
                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                ),
                Text(
                  '-K${_loyaltyDiscount.toStringAsFixed(2)}',
                  style: GoogleFonts.urbanist(
                    color: brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _methodTile(Map<String, dynamic> method, Color brand) {
    final code = (method['code'] ?? 'cash').toString();
    final displayName = (method['title'] ?? method['name'] ?? code).toString();
    final selected = _method == code;
    final isManual = method['is_manual'] == true;
    return InkWell(
      onTap: () => setState(() {
        _method = code;
        _selectedMethod = method;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? brand : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.payments_rounded, color: brand),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                  ),
                  if (isManual)
                    Text(
                      'Manual review required',
                      style: GoogleFonts.urbanist(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? brand : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
