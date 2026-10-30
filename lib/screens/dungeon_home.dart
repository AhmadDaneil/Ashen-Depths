import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/dungeon_scene.dart';
import '../models/game_models.dart';

const gold = Color(0xFFFFC857);
const panel = Color(0xFF1B202D);

class DungeonHome extends StatefulWidget {
  const DungeonHome({super.key});
  @override
  State<DungeonHome> createState() => _DungeonHomeState();
}

class _DungeonHomeState extends State<DungeonHome> with WidgetsBindingObserver {
  final scene = DungeonScene();
  SharedPreferences? prefs;
  Timer? timer;
  int floor = 1, best = 1, coins = 0, kills = 0, level = 1;
  int hp = 100,
      maxHp = 100,
      damage = 12,
      foeHp = 30,
      foeMaxHp = 30,
      foeDamage = 5;
  int weapon = 0, armor = 0, potions = 0;
  bool boss = false, loading = true;
  String foe = 'Cave Slime',
      note = 'Your adventure begins in the Ashen Catacombs.';
  DateTime savedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    final raw = prefs!.getString('save');
    if (raw != null) {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      floor = d['floor'] ?? 1;
      best = d['best'] ?? floor;
      coins = d['coins'] ?? 0;
      kills = d['kills'] ?? 0;
      level = d['level'] ?? 1;
      hp = d['hp'] ?? 100;
      maxHp = d['maxHp'] ?? 100;
      damage = d['damage'] ?? 12;
      weapon = d['weapon'] ?? 0;
      armor = d['armor'] ?? 0;
      potions = d['potions'] ?? 0;
      final then = DateTime.tryParse(d['time'] ?? '');
      if (then != null) {
        final seconds =
            DateTime.now().difference(then).inSeconds.clamp(0, 28800);
        final reward = (seconds * (1 + floor * .35)).floor();
        coins += reward;
        if (reward > 0)
          note = 'Your hero earned ' + reward.toString() + ' gold while away.';
      }
    }
    _spawn();
    if (mounted) setState(() => loading = false);
    timer = Timer.periodic(const Duration(milliseconds: 1100), (_) => _tick());
    _save();
  }

  void _spawn() {
    final mapFloor = DungeonFloor.fromNumber(floor);
    boss = mapFloor.boss;
    foe = mapFloor.enemyName;
    foeMaxHp = mapFloor.enemyHealth;
    foeHp = foeMaxHp;
    foeDamage = mapFloor.enemyAttack;
    scene.setFloor(mapFloor);
  }

  void _tick() {
    if (!mounted || loading) return;
    scene.strike(damage);
    setState(() {
      foeHp -= damage;
      if (foeHp <= 0) {
        final reward = boss ? 70 + floor * 8 : 12 + floor * 3;
        coins += reward;
        kills++;
        note = (boss ? 'Guardian defeated!' : foe + ' defeated.') +
            '  +' +
            reward.toString() +
            ' gold.';
        if (boss) potions++;
        floor++;
        if (floor > best) best = floor;
        if (kills % 4 == 0) {
          level++;
          damage += 2;
          maxHp += 12;
          hp = maxHp;
          note = 'Level up! You are now level ' + level.toString() + '.';
        }
        _spawn();
      } else {
        hp -= foeDamage;
        if (hp <= 0) {
          hp = maxHp;
          floor = floor > 1 ? floor - 1 : 1;
          _spawn();
          note = 'You were knocked out and recovered at floor ' +
              floor.toString() +
              '.';
        }
      }
    });
    if (DateTime.now().difference(savedAt).inSeconds > 8) _save();
  }

  Future<void> _save() async {
    if (prefs == null) return;
    savedAt = DateTime.now();
    await prefs!.setString(
      'save',
      jsonEncode({
        'floor': floor,
        'best': best,
        'coins': coins,
        'kills': kills,
        'level': level,
        'hp': hp,
        'maxHp': maxHp,
        'damage': damage,
        'weapon': weapon,
        'armor': armor,
        'potions': potions,
        'time': savedAt.toIso8601String(),
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) _save();
  }

  int get bladeCost => 45 + weapon * 55;
  int get armorCost => 40 + armor * 50;
  void _blade() {
    if (coins < bladeCost) return;
    setState(() {
      coins -= bladeCost;
      weapon++;
      damage += 5;
      note = 'Blade upgraded to rank ' + weapon.toString() + '.';
    });
    _save();
  }

  void _armor() {
    if (coins < armorCost) return;
    setState(() {
      coins -= armorCost;
      armor++;
      maxHp += 25;
      hp = (hp + 25).clamp(0, maxHp).toInt();
      note = 'Armor upgraded to rank ' + armor.toString() + '.';
    });
    _save();
  }

  void _potion() {
    if (potions == 0 || hp == maxHp) return;
    setState(() {
      potions--;
      hp = (hp + (maxHp * .55).round()).clamp(0, maxHp).toInt();
      note = 'A potion restored your strength.';
    });
    _save();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: gold)),
      );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      _hero(),
                      const SizedBox(height: 14),
                      _battle(),
                      const SizedBox(height: 14),
                      _upgrades(),
                      const SizedBox(height: 14),
                      _journal(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: gold.withOpacity(.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.shield_moon, color: gold),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DUNGEON',
                    style: TextStyle(
                      letterSpacing: 3,
                      fontSize: 11,
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'ASCENDANT',
                    style: TextStyle(
                      letterSpacing: 1.6,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            _pill(Icons.monetization_on, coins.toString(), gold),
          ],
        ),
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34334A), Color(0xFF222838)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFF171B27),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text('🛡️', style: TextStyle(fontSize: 43)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ASHEN KNIGHT',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        'LVL ' + level.toString(),
                        style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Best floor  ' +
                        best.toString() +
                        '  ·  ' +
                        kills.toString() +
                        ' victories',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _meter(
                    hp / maxHp,
                    const Color(0xFF73E0B1),
                    'HP  ' + hp.toString() + ' / ' + maxHp.toString(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⚔  ' + damage.toString() + ' damage per strike',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _battle() => _card(
        Column(
          children: [
            Row(
              children: [
                _pill(
                  Icons.layers,
                  'FLOOR ' + floor.toString(),
                  const Color(0xFFB9A7FF),
                ),
                const Spacer(),
                if (boss)
                  _pill(
                    Icons.local_fire_department,
                    'BOSS',
                    const Color(0xFFFF7777),
                  ),
                Text(
                  '  AUTO BATTLE',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.48),
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 218,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GameWidget(game: scene),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x550A0D14),
                              Colors.transparent,
                              Color(0xE60A0D14)
                            ],
                            stops: [0, .36, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _pill(
                        Icons.auto_awesome,
                        'ASHEN CATACOMBS',
                        const Color(0xFF9AE8D2),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          key: ValueKey<int>(foeHp),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xCC151923),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '−$damage',
                            style: const TextStyle(
                                color: gold, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            foe.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 15,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 8)
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),
                          _meter(
                            foeHp / foeMaxHp,
                            boss
                                ? const Color(0xFFFF7777)
                                : const Color(0xFFFFC857),
                            foeHp.toString() +
                                ' / ' +
                                foeMaxHp.toString() +
                                ' HP',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flash_on, color: gold, size: 16),
                Text(
                  '  ' + foeDamage.toString() + ' enemy damage',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(width: 18),
                FilledButton.tonalIcon(
                  onPressed: _potion,
                  icon: const Icon(Icons.local_drink, size: 16),
                  label: Text('Potion  $potions'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _upgrades() => _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'THE QUARTERMASTER',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _upgradeRow(
              Icons.gavel,
              'Sharpened Blade',
              '+5 attack damage · Rank ' + weapon.toString(),
              bladeCost,
              _blade,
              coins >= bladeCost,
            ),
            const SizedBox(height: 9),
            _upgradeRow(
              Icons.shield,
              'Guardian Armor',
              '+25 maximum health · Rank ' + armor.toString(),
              armorCost,
              _armor,
              coins >= armorCost,
            ),
          ],
        ),
      );

  Widget _upgradeRow(
    IconData icon,
    String title,
    String detail,
    int cost,
    VoidCallback action,
    bool enabled,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.035),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: gold.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: gold, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: enabled ? action : null,
              child: Text(cost.toString() + ' G'),
            ),
          ],
        ),
      );

  Widget _journal() => _card(
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 17, color: gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                note,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(.055)),
        ),
        child: child,
      );

  Widget _pill(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

  Widget _meter(double value, Color color, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.black26,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      );
}
