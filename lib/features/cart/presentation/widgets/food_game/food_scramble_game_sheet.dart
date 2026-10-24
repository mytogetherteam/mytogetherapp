import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'food_word_item.dart';
import 'food_words_dataset.dart';

class FoodTile {
  final int id;
  final String text;
  bool isUsed;

  FoodTile({
    required this.id,
    required this.text,
    this.isUsed = false,
  });
}

class FoodScrambleGameSheet extends StatefulWidget {
  const FoodScrambleGameSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FoodScrambleGameSheet(),
    );
  }

  @override
  State<FoodScrambleGameSheet> createState() => _FoodScrambleGameSheetState();
}

class _FoodScrambleGameSheetState extends State<FoodScrambleGameSheet>
    with TickerProviderStateMixin {
  late List<FoodWordItem> _shuffledItems;
  int _currentIndex = 0;

  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  List<FoodTile> _availableTiles = [];
  List<FoodTile?> _placedTiles = [];

  bool _isSuccess = false;
  bool _isWrong = false;
  bool _isGameOver = false;

  int _score = 0; // Score earned in this game run (starts at 0)
  int _highScore = 0; // All-time high score loaded from SharedPreferences
  int _streak = 0; // Current combo streak
  int _maxRunStreak = 0; // Highest combo achieved in this game run
  int _bestStreak = 0; // All-time best combo streak
  int _solvedCount = 0; // Number of foods solved in this game run
  int _hintsRemaining = 2;
  int _lives = 3;

  // Dynamic Countdown Timer (12s to 18s based on streak)
  Timer? _countdownTimer;
  int _remainingSeconds = 18;
  int _totalSeconds = 18;

  int get _currentLevelTotalSeconds {
    if (_streak >= 15) return 12;
    if (_streak >= 8) return 15;
    return 18;
  }

  late AnimationController _celebrationController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _score = 0;
    _solvedCount = 0;
    _streak = 0;
    _maxRunStreak = 0;
    _loadSavedStats();

    _shuffledItems = List<FoodWordItem>.from(FoodWordsDataset.items)..shuffle();

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -9.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -9.0, end: 9.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 9.0, end: -7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _initLevel();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _celebrationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _highScore = prefs.getInt('myanmar_food_game_high_score') ?? 0;
          _bestStreak = prefs.getInt('myanmar_food_game_best_streak') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_score > _highScore) {
        _highScore = _score;
        await prefs.setInt('myanmar_food_game_high_score', _highScore);
      }
      if (_maxRunStreak > _bestStreak) {
        _bestStreak = _maxRunStreak;
        await prefs.setInt('myanmar_food_game_best_streak', _bestStreak);
      }
    } catch (_) {}
  }

  FoodWordItem get _currentItem => _shuffledItems[_currentIndex];

  void _startTimer() {
    _countdownTimer?.cancel();
    _totalSeconds = _currentLevelTotalSeconds;
    _remainingSeconds = _totalSeconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isSuccess || _isGameOver) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds <= 5) {
          HapticFeedback.selectionClick();
        }
      } else {
        timer.cancel();
        _onTimeExpired();
      }
    });
  }

  void _onTimeExpired() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);

    setState(() {
      _remainingSeconds = 0;
      _lives--;
      _streak = 0;
      _isWrong = true;
    });

    if (_lives <= 0) {
      _triggerGameOver();
    } else {
      // Auto go to next game after a brief 1.2s delay
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && !_isGameOver && !_isSuccess) {
          _nextLevel();
        }
      });
    }
  }

  void _triggerGameOver() {
    _countdownTimer?.cancel();
    setState(() {
      _isGameOver = true;
    });
    _saveStats();
  }

  void _initLevel() {
    _isSuccess = false;
    _isWrong = false;
    final item = _currentItem;

    final pool = <String>[...item.syllables];

    // HARD MODE: 7 to 9 deceptive syllables from curated distractors + other items
    final targetDistractors = _streak >= 10 ? 9 : (_streak >= 4 ? 8 : 7);
    final extraDistractors = <String>[...item.distractors];
    final rand = Random();
    final allOtherItems = FoodWordsDataset.items.where((i) => i.id != item.id).toList();
    allOtherItems.shuffle(rand);

    for (final other in allOtherItems) {
      if (extraDistractors.length >= targetDistractors) break;
      for (final syl in other.syllables) {
        if (!extraDistractors.contains(syl) && !item.syllables.contains(syl)) {
          extraDistractors.add(syl);
          if (extraDistractors.length >= targetDistractors) break;
        }
      }
    }

    pool.addAll(extraDistractors);
    pool.shuffle(Random());

    _availableTiles = List.generate(
      pool.length,
      (i) => FoodTile(id: i, text: pool[i]),
    );

    _placedTiles = List<FoodTile?>.filled(item.syllables.length, null);

    _startTimer();
  }

  void _onTileTap(FoodTile tile) {
    if (tile.isUsed || _isSuccess || _isGameOver) return;

    final emptySlotIndex = _placedTiles.indexOf(null);
    if (emptySlotIndex == -1) return;

    HapticFeedback.lightImpact();

    setState(() {
      tile.isUsed = true;
      _placedTiles[emptySlotIndex] = tile;
      _isWrong = false;
    });

    _checkAnswer();
  }

  void _onPlacedSlotTap(int index) {
    if (_isSuccess || _isGameOver) return;
    final tile = _placedTiles[index];
    if (tile == null) return;

    HapticFeedback.lightImpact();

    setState(() {
      tile.isUsed = false;
      _placedTiles[index] = null;
      _isWrong = false;
    });
  }

  void _checkAnswer() {
    if (_placedTiles.any((t) => t == null)) return;

    final item = _currentItem;
    final formedWord = _placedTiles.map((t) => t!.text).join('');
    final correctWord = item.syllables.join('');

    if (formedWord == correctWord) {
      // SUCCESS!
      _countdownTimer?.cancel();
      HapticFeedback.mediumImpact();
      _celebrationController.forward(from: 0.0);

      final speedBonus = (_remainingSeconds >= (_totalSeconds * 0.6)) ? 30 : 0;
      final streakBonus = _streak * 20;

      setState(() {
        _isSuccess = true;
        _isWrong = false;
        _streak += 1;
        if (_streak > _maxRunStreak) {
          _maxRunStreak = _streak;
        }
        _solvedCount += 1;
        _score += 100 + streakBonus + speedBonus;
      });

      _saveStats();
    } else {
      // WRONG GUESS in HARD MODE: Penalize time and life!
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0.0);

      setState(() {
        _isWrong = true;
        _streak = 0;
        _remainingSeconds = max(0, _remainingSeconds - 3);
        _lives--;
      });

      if (_lives <= 0) {
        _triggerGameOver();
      }
    }
  }

  void _shuffleAvailableTiles() {
    if (_isSuccess || _isGameOver) return;
    HapticFeedback.selectionClick();
    setState(() {
      _availableTiles.shuffle(Random());
    });
  }

  void _useHint() {
    if (_hintsRemaining <= 0 || _isSuccess || _isGameOver) return;

    final item = _currentItem;
    int targetSlot = -1;

    for (int i = 0; i < item.syllables.length; i++) {
      if (_placedTiles[i] == null || _placedTiles[i]!.text != item.syllables[i]) {
        targetSlot = i;
        break;
      }
    }

    if (targetSlot == -1) return;

    HapticFeedback.selectionClick();

    if (_placedTiles[targetSlot] != null) {
      _placedTiles[targetSlot]!.isUsed = false;
      _placedTiles[targetSlot] = null;
    }

    final neededSyllable = item.syllables[targetSlot];

    FoodTile? foundTile;
    for (final t in _availableTiles) {
      if (!t.isUsed && t.text == neededSyllable) {
        foundTile = t;
        break;
      }
    }

    if (foundTile == null) {
      for (int i = 0; i < _placedTiles.length; i++) {
        if (_placedTiles[i]?.text == neededSyllable) {
          foundTile = _placedTiles[i];
          _placedTiles[i] = null;
          break;
        }
      }
    }

    if (foundTile != null) {
      setState(() {
        _hintsRemaining--;
        foundTile!.isUsed = true;
        _placedTiles[targetSlot] = foundTile;
        _isWrong = false;
      });
      _checkAnswer();
    }
  }

  void _resetCurrentWord() {
    if (_isSuccess || _isGameOver) return;
    HapticFeedback.lightImpact();
    setState(() {
      for (final t in _availableTiles) {
        t.isUsed = false;
      }
      _placedTiles = List<FoodTile?>.filled(_currentItem.syllables.length, null);
      _isWrong = false;
    });
  }

  void _nextLevel() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentIndex < _shuffledItems.length - 1) {
        _currentIndex++;
      } else {
        _shuffledItems.shuffle();
        _currentIndex = 0;
      }
      _initLevel();
    });
  }

  void _restartGame() {
    HapticFeedback.mediumImpact();
    setState(() {
      _score = 0;
      _solvedCount = 0;
      _streak = 0;
      _maxRunStreak = 0;
      _lives = 3;
      _hintsRemaining = 2;
      _isGameOver = false;
      _shuffledItems.shuffle();
      _currentIndex = 0;
      _initLevel();
    });
  }

  Future<void> _shareResultImage() async {
    if (_isSharing) return;
    HapticFeedback.lightImpact();
    setState(() => _isSharing = true);

    try {
      // Delay slightly so layout/repaint is guaranteed
      await Future.delayed(const Duration(milliseconds: 60));
      final boundary =
          _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'myanmar_food_game_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text:
              '🔥 အစားအသောက် စကားလုံးဆက်တမ်းမှာ $_score pts တောင် ရထားတယ်နော်! 😎 ကိုယ့်ထက် ပိုရနိုင်မလား... လာစိန်ခေါ်ကြည့်လိုက်ပါဦး 🍜😋✨',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing game result image: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  String _getRankTitle(int score) {
    if (score >= 800) return '👑 မြန်မာ့အစားအစာ ဆရာကြီး';
    if (score >= 500) return '🥇 စားဖိုမှူးကြီး';
    if (score >= 250) return '🥈 Foodie အစားကြိုက်သူလေး';
    if (score > 0) return '🥉 အစားအသောက် ဝါသနာရှင်လေး';
    return '🥄 စတင်လေ့လာသူလေး';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final item = _currentItem;

    final timerFraction = (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0);
    final isTimerLow = _remainingSeconds <= 5;
    final timerColor = isTimerLow
        ? const Color(0xFFEF4444)
        : _remainingSeconds <= 10
            ? AppColors.secondary
            : AppColors.primary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        children: [
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Unified Status Bar: Lives + Timer + Score + Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Lives
                      Row(
                        children: List.generate(3, (i) {
                          final isAlive = i < _lives;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Icon(
                              isAlive
                                  ? PhosphorIcons.heartFill
                                  : PhosphorIcons.heartBreakFill,
                              size: 19,
                              color: isAlive
                                  ? AppColors.primary
                                  : const Color(0xFFE2E8F0),
                            ),
                          );
                        }),
                      ),

                      // Countdown Timer Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: timerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: timerColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIcons.timerBold,
                              size: 13,
                              color: timerColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_remainingSeconds s',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: timerColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right Controls: Score & Close
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(PhosphorIcons.starFill, size: 13, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 3),
                                Text(
                                  '$_score',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIcons.xBold,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Slim Timer Progress Indicator with Primary Gradient
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 3.2,
                      width: double.infinity,
                      color: const Color(0xFFF1F5F9),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: timerFraction,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: isTimerLow
                                  ? const LinearGradient(
                                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                    )
                                  : AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // If Game Over, show Game Over Screen with Image Sharing
                  if (_isGameOver) ...[
                    _buildGameOverView(),
                  ] else ...[
                    // Category & Challenge subhead
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.12),
                                AppColors.secondary.withValues(alpha: 0.12),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            item.category,
                            style: AppFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            if (_streak > 1) ...[
                              Text(
                                '🔥 x$_streak   ',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                            Text(
                              'ပွဲ #${_currentIndex + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Clue Box: Clean, bright, centered
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        item.hint,
                        style: AppFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Target Placed Slots (Responsive, beautiful Primary Gradient)
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final int slotCount = item.syllables.length;
                          final double slotSpacing = slotCount > 5 ? 6.0 : 8.0;
                          final double maxUsableWidth = constraints.maxWidth - ((slotCount - 1) * slotSpacing);
                          final double slotWidth = (maxUsableWidth / slotCount).clamp(42.0, 56.0);
                          final double slotHeight = (slotWidth * 0.94).clamp(44.0, 52.0);

                          return Wrap(
                            spacing: slotSpacing,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: List.generate(slotCount, (index) {
                              final placedTile = _placedTiles[index];
                              final isFilled = placedTile != null;

                              return InkWell(
                                onTap: () => _onPlacedSlotTap(index),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: slotWidth,
                                  height: slotHeight,
                                  decoration: BoxDecoration(
                                    gradient: isFilled
                                        ? (_isSuccess
                                            ? const LinearGradient(
                                                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : _isWrong
                                                ? const LinearGradient(
                                                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : AppColors.primaryGradient)
                                        : null,
                                    color: isFilled ? null : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isFilled
                                          ? Colors.transparent
                                          : const Color(0xFFCBD5E1),
                                      width: isFilled ? 0 : 1.5,
                                    ),
                                    boxShadow: isFilled
                                        ? [
                                            BoxShadow(
                                              color: (_isSuccess
                                                      ? const Color(0xFF16A34A)
                                                      : _isWrong
                                                          ? const Color(0xFFDC2626)
                                                          : AppColors.primary)
                                                  .withValues(alpha: 0.32),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: Text(
                                          placedTile?.text ?? '',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: AppFonts.poppins(
                                            fontSize: slotCount > 5 ? 15.0 : 16.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),

                    if (_isWrong) ...[
                      const SizedBox(height: 8),
                      Text(
                        _remainingSeconds == 0
                            ? '⏰ အချိန်ကုန်သွားပြီနော်!'
                            : '❌ အဖြေမှားသွားတယ် (-၃s)',
                        style: AppFonts.poppins(
                          fontSize: 11.5,
                          color: const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // Success Celebration Card
                    if (_isSuccess) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  PhosphorIcons.checkCircleFill,
                                  color: Color(0xFF16A34A),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '🎉 အောင်မြင်ပါတယ်! (${item.name})',
                                  style: AppFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.funFact,
                              style: AppFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF15803D),
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _nextLevel,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Center(
                                    child: Text(
                                      'နောက်တစ်ပွဲ ကစားမည် ➔',
                                      style: AppFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Scrambled Syllable Tiles (Responsive wordboxes, no wrapped Burmese glyphs)
                    if (!_isSuccess) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const double tileSpacing = 8.0;
                          final int columns = 5;
                          final double tileWidth = ((constraints.maxWidth - (columns - 1) * tileSpacing) / columns)
                              .floorToDouble()
                              .clamp(52.0, 68.0);
                          final double tileHeight = 48.0;

                          return Wrap(
                            spacing: tileSpacing,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _availableTiles.map((tile) {
                              return Opacity(
                                opacity: tile.isUsed ? 0.35 : 1.0,
                                child: InkWell(
                                  onTap: tile.isUsed ? null : () => _onTileTap(tile),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: tileWidth,
                                    height: tileHeight,
                                    decoration: BoxDecoration(
                                      color: tile.isUsed
                                          ? const Color(0xFFF1F5F9)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tile.isUsed
                                            ? const Color(0xFFE2E8F0)
                                            : const Color(0xFFCBD5E1),
                                        width: 1.2,
                                      ),
                                      boxShadow: tile.isUsed
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text(
                                            tile.text,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: AppFonts.poppins(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                              color: tile.isUsed
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Action Controls: Clean toolbar with primary gradient Hint button
                      Row(
                        children: [
                          // Primary Gradient Hint Button
                          Expanded(
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: _hintsRemaining > 0
                                    ? AppColors.primaryGradient
                                    : null,
                                color: _hintsRemaining > 0 ? null : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _hintsRemaining > 0
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.28),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _hintsRemaining > 0 ? _useHint : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        PhosphorIcons.lightbulbFill,
                                        size: 16,
                                        color: _hintsRemaining > 0 ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'အရိပ်အမြွက် ($_hintsRemaining)',
                                        style: AppFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _hintsRemaining > 0 ? Colors.white : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Shuffle
                          IconButton.filledTonal(
                            onPressed: _shuffleAvailableTiles,
                            icon: const Icon(PhosphorIcons.shuffleBold, size: 16),
                            tooltip: 'နေရာလွှဲ',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF8FAFC),
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Reset
                          IconButton.filledTonal(
                            onPressed: _resetCurrentWord,
                            icon: const Icon(PhosphorIcons.arrowCounterClockwiseBold, size: 16),
                            tooltip: 'ပြန်စမည်',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF8FAFC),
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Skip
                          IconButton.filledTonal(
                            onPressed: _nextLevel,
                            icon: const Icon(PhosphorIcons.fastForwardBold, size: 16),
                            tooltip: 'ကျော်ရန်',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF8FAFC),
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Particle Celebration Confetti Overlay
          if (_isSuccess)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _celebrationController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _celebrationController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameOverView() {
    return Column(
      children: [
        // Shareable Card wrapped in RepaintBoundary for high-res screenshot capture
        RepaintBoundary(
          key: _shareCardKey,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF311042)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Brand Watermark Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/images/logo_3d.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MyTogether • Food Game',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ရိုးရာဉာဏ်စမ်း',
                        style: AppFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Center Trophy / Skull Badge
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        const Color(0xFFEF4444).withValues(alpha: 0.25),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFDE68A),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 34)),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  _getRankTitle(_score),
                  style: AppFonts.poppins(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFDE68A),
                  ),
                ),
                const SizedBox(height: 4),

                // Large Score
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFFED7AA)],
                  ).createShader(bounds),
                  child: Text(
                    '$_score',
                    style: GoogleFonts.poppins(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  'FINAL POINTS',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildShareStatItem('အောင်မြင်သောမုန့်', '$_solvedCount ပွဲ'),
                      Container(width: 1, height: 26, color: Colors.white24),
                      _buildShareStatItem('အမြင့်ဆုံး Combo', 'x$_maxRunStreak'),
                      Container(width: 1, height: 26, color: Colors.white24),
                      _buildShareStatItem('အဆင့်', '#${_solvedCount + 1}'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'အော်ဒါစောင့်ရင်း မြန်မာ့အစားအစာလေးတွေ အတူတူ ဉာဏ်စမ်းကြမယ် 🍲✨',
                  style: AppFonts.poppins(
                    fontSize: 10.5,
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons: Share Image & Play Again
        Row(
          children: [
            // Share Image Button (Styled with primary gradient)
            Expanded(
              flex: 3,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSharing ? null : _shareResultImage,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSharing)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          else
                            const Icon(
                              PhosphorIcons.shareNetworkBold,
                              size: 18,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isSharing
                                ? 'မျှဝေနေသည်...'
                                : 'ရလဒ် မျှဝေမည်',
                            style: AppFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Restart Button
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(PhosphorIcons.arrowClockwiseBold, size: 17),
                  label: Text(
                    'ပြန်ဆော့မည်',
                    style: AppFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShareStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppFonts.poppins(
            fontSize: 10,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final Color color;
  final double size;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final List<_ConfettiParticle> _particles = _generateParticles();

  _ConfettiPainter({required this.progress});

  static List<_ConfettiParticle> _generateParticles() {
    final rand = Random(42);
    final colors = [
      const Color(0xFFED3973),
      const Color(0xFFF96232),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
    ];

    return List.generate(45, (i) {
      final angle = rand.nextDouble() * 2 * pi;
      final speed = 150 + rand.nextDouble() * 250;
      return _ConfettiParticle(
        x: 0.5,
        y: 0.45,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 60,
        color: colors[rand.nextInt(colors.length)],
        size: 5 + rand.nextDouble() * 5,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _particles) {
      final currentX = (p.x * size.width) + (p.vx * progress);
      final currentY = (p.y * size.height) + (p.vy * progress) + (0.5 * 400 * progress * progress);
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      paint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(currentX, currentY), p.size * (1 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
