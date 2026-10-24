import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CardBrand { visa, mastercard, jcb, amex, generic }

class SavedCard {
  final String id;
  final String cardNumber;
  final String last4;
  final CardBrand brand;
  final String holderName;
  final String expiryMonth;
  final String expiryYear;
  final bool isDefault;

  const SavedCard({
    required this.id,
    required this.cardNumber,
    required this.last4,
    required this.brand,
    required this.holderName,
    required this.expiryMonth,
    required this.expiryYear,
    this.isDefault = false,
  });

  String get maskedDisplay => '•••• •••• •••• $last4';
  String get expiryDisplay => '$expiryMonth/${expiryYear.length == 4 ? expiryYear.substring(2) : expiryYear}';
  String get brandTitle => switch (brand) {
    CardBrand.visa => 'Visa',
    CardBrand.mastercard => 'Mastercard',
    CardBrand.jcb => 'JCB',
    CardBrand.amex => 'American Express',
    CardBrand.generic => 'Card',
  };

  SavedCard copyWith({bool? isDefault}) {
    return SavedCard(
      id: id,
      cardNumber: cardNumber,
      last4: last4,
      brand: brand,
      holderName: holderName,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cardNumber': cardNumber,
    'last4': last4,
    'brand': brand.name,
    'holderName': holderName,
    'expiryMonth': expiryMonth,
    'expiryYear': expiryYear,
    'isDefault': isDefault,
  };

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
    id: json['id'] as String? ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
    cardNumber: json['cardNumber'] as String? ?? '',
    last4: json['last4'] as String? ?? '4242',
    brand: CardBrand.values.firstWhere(
      (b) => b.name == json['brand'],
      orElse: () => CardBrand.visa,
    ),
    holderName: json['holderName'] as String? ?? 'CARD HOLDER',
    expiryMonth: json['expiryMonth'] as String? ?? '12',
    expiryYear: json['expiryYear'] as String? ?? '28',
    isDefault: json['isDefault'] as bool? ?? false,
  );
}

class SavedCardService extends ChangeNotifier {
  static final SavedCardService instance = SavedCardService._internal();
  SavedCardService._internal();

  static const String _storageKey = 'my_together_saved_cards_v1';
  List<SavedCard> _cards = [];
  bool _isLoaded = false;

  String _defaultChannel = 'CARD';
  String? _trueMoneyPhone;
  bool _requireBiometric = false;
  bool _quickCheckoutUnder500 = true;
  bool _allowCod = true;
  bool _emailReceipt = true;

  List<SavedCard> get cards => List.unmodifiable(_cards);
  bool get isLoaded => _isLoaded;
  SavedCard? get defaultCard => _cards.where((c) => c.isDefault).firstOrNull ?? _cards.firstOrNull;

  String get defaultChannel => _defaultChannel;
  String? get trueMoneyPhone => _trueMoneyPhone;
  bool get requireBiometric => _requireBiometric;
  bool get quickCheckoutUnder500 => _quickCheckoutUnder500;
  bool get allowCod => _allowCod;
  bool get emailReceipt => _emailReceipt;

  static CardBrand detectBrand(String cleanNumber) {
    final s = cleanNumber.replaceAll(RegExp(r'\D'), '');
    if (s.startsWith('4')) return CardBrand.visa;
    if (s.startsWith('51') ||
        s.startsWith('52') ||
        s.startsWith('53') ||
        s.startsWith('54') ||
        s.startsWith('55') ||
        (s.length >= 4 && int.tryParse(s.substring(0, 4)) != null &&
            int.parse(s.substring(0, 4)) >= 2221 &&
            int.parse(s.substring(0, 4)) <= 2720)) {
      return CardBrand.mastercard;
    }
    if (s.startsWith('35')) return CardBrand.jcb;
    if (s.startsWith('34') || s.startsWith('37')) return CardBrand.amex;
    return CardBrand.generic;
  }

  Future<void> loadCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _cards = list
            .whereType<Map<String, dynamic>>()
            .map((e) => SavedCard.fromJson(e))
            .toList();
      }

      _defaultChannel = prefs.getString('${_storageKey}_channel') ?? 'CARD';
      _trueMoneyPhone = prefs.getString('${_storageKey}_truemoney') ?? '0891234567';
      _requireBiometric = prefs.getBool('${_storageKey}_biometric') ?? false;
      _quickCheckoutUnder500 = prefs.getBool('${_storageKey}_quick_checkout') ?? true;
      _allowCod = prefs.getBool('${_storageKey}_allow_cod') ?? true;
      _emailReceipt = prefs.getBool('${_storageKey}_email_receipt') ?? true;

      // If empty, seed with initial mock card for seamless user preview
      if (_cards.isEmpty) {
        _cards = [
          const SavedCard(
            id: 'card_default_demo',
            cardNumber: '4000123456784242',
            last4: '4242',
            brand: CardBrand.visa,
            holderName: 'MYTOGETHER USER',
            expiryMonth: '12',
            expiryYear: '28',
            isDefault: true,
          ),
          const SavedCard(
            id: 'card_mastercard_demo',
            cardNumber: '5412751234128899',
            last4: '8899',
            brand: CardBrand.mastercard,
            holderName: 'MYTOGETHER USER',
            expiryMonth: '08',
            expiryYear: '27',
            isDefault: false,
          ),
        ];
        await _persist();
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('SavedCardService: loadCards error: $e');
    }
  }

  Future<void> setDefaultChannel(String channel) async {
    _defaultChannel = channel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_storageKey}_channel', channel);
    notifyListeners();
  }

  Future<void> setTrueMoneyPhone(String? phone) async {
    _trueMoneyPhone = phone;
    final prefs = await SharedPreferences.getInstance();
    if (phone == null || phone.isEmpty) {
      await prefs.remove('${_storageKey}_truemoney');
    } else {
      await prefs.setString('${_storageKey}_truemoney', phone);
    }
    notifyListeners();
  }

  Future<void> setRequireBiometric(bool value) async {
    _requireBiometric = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_storageKey}_biometric', value);
    notifyListeners();
  }

  Future<void> setQuickCheckoutUnder500(bool value) async {
    _quickCheckoutUnder500 = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_storageKey}_quick_checkout', value);
    notifyListeners();
  }

  Future<void> setAllowCod(bool value) async {
    _allowCod = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_storageKey}_allow_cod', value);
    notifyListeners();
  }

  Future<void> setEmailReceipt(bool value) async {
    _emailReceipt = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_storageKey}_email_receipt', value);
    notifyListeners();
  }

  Future<void> saveCard({
    required String cardNumber,
    required String holderName,
    required String expiryMonth,
    required String expiryYear,
    bool setAsDefault = true,
  }) async {
    final clean = cardNumber.replaceAll(RegExp(r'\D'), '');
    final last4 = clean.length >= 4 ? clean.substring(clean.length - 4) : '0000';
    final brand = detectBrand(clean);

    final newCard = SavedCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      cardNumber: clean,
      last4: last4,
      brand: brand,
      holderName: holderName.trim().toUpperCase(),
      expiryMonth: expiryMonth.padLeft(2, '0'),
      expiryYear: expiryYear,
      isDefault: setAsDefault || _cards.isEmpty,
    );

    if (newCard.isDefault) {
      _cards = _cards.map((c) => c.copyWith(isDefault: false)).toList();
    }

    _cards.insert(0, newCard);
    await _persist();
    notifyListeners();
  }

  Future<void> removeCard(String id) async {
    _cards.removeWhere((c) => c.id == id);
    if (_cards.isNotEmpty && !_cards.any((c) => c.isDefault)) {
      _cards[0] = _cards[0].copyWith(isDefault: true);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setDefault(String id) async {
    _cards = _cards.map((c) => c.copyWith(isDefault: c.id == id)).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _cards.map((c) => c.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      if (kDebugMode) debugPrint('SavedCardService: _persist error: $e');
    }
  }
}
