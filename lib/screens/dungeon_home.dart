import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/dungeon_scene.dart';
import '../models/game_models.dart';
import '../state/game_state.dart';

const gold = Color(0xFFFFC857);
const panel = Color(0xFF1B202D);

class DungeonHome extends StatefulWidget {
  const DungeonHome({super.key});
  @override
  State<DungeonHome> createState() => _DungeonHomeState();
}

class _DungeonHomeState extends State<DungeonHome> with WidgetsBindingObserver {
  final scene = DungeonScene();
  final gameState = GameState();
  bool loading = true;
  int _lastVisualSequence = 0;

  int get floor => gameState.floor;
  int get best => gameState.bestFloor;
  int get coins => gameState.coins;
  int get kills => gameState.kills;
  int get level => gameState.level;
  int get hp => gameState.hp;
  int get maxHp => gameState.maxHp;
  int get damage => gameState.damage;
  int get foeHp => gameState.foeHp;
  int get foeMaxHp => gameState.foeMaxHp;
  int get foeDamage => gameState.foeDamage;
  int get weapon => gameState.weaponRank;
  int get armor => gameState.armorRank;
  int get potions => gameState.potions;
  int get roomIndex => gameState.roomIndex;
  int get bladeCost => gameState.bladeCost;
  int get armorCost => gameState.armorCost;
  bool get boss => gameState.boss;
  String get foe => gameState.foe;
  String get note => gameState.note;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gameState.addListener(_onGameStateChanged);
    _load();
  }

  Future<void> _load() async {
    await gameState.initialize();
    if (!mounted) return;
    scene.setFloor(DungeonFloor.fromNumber(floor));
    scene.setRoom(roomIndex);
    _lastVisualSequence = gameState.visualSequence;
    setState(() => loading = false);
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    scene.setFloor(DungeonFloor.fromNumber(floor));
    scene.setRoom(roomIndex);
    if (gameState.visualSequence != _lastVisualSequence) {
      _lastVisualSequence = gameState.visualSequence;
      switch (gameState.visualAction) {
        case 'walk':
          scene.walkToRoom(roomIndex);
        case 'strike':
          scene.strike(damage);
          if (gameState.incomingDamage > 0) {
            scene.enemyStrike(gameState.incomingDamage);
          }
        case 'loot':
          scene.walkToRoom(roomIndex);
          scene.showLoot();
        case 'recover':
          scene.recoverAtEntrance();
      }
    }
    setState(() {});
  }

  void _blade() => gameState.buyWeaponUpgrade();
  void _armor() => gameState.buyArmorUpgrade();
  void _potion() => gameState.drinkPotion();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      gameState.save();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gameState.removeListener(_onGameStateChanged);
    gameState.dispose();
    super.dispose();
  }

  Widget _route() => _card(
        Row(
          children: List.generate(gameState.map.rooms.length, (index) {
            final active = index == roomIndex;
            final room = gameState.map.rooms[index];
            final icon = switch (room.kind) {
              RoomKind.entrance => Icons.door_front_door,
              RoomKind.battle => Icons.sports_martial_arts,
              RoomKind.treasure => Icons.workspace_premium,
            };
            return Expanded(
              child: Column(children: [
                Icon(icon, color: active ? gold : Colors.white38, size: 22),
                const SizedBox(height: 5),
                Text(room.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: active ? gold : Colors.white54,
                        fontSize: 10,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal)),
              ]),
            );
          }),
        ),
      );

  Widget _equipment() => _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('EQUIPPED GEAR',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 12)),
          const SizedBox(height: 10),
          Text(
              '⚔  ' +
                  (gameState.equippedWeapon?.name ?? 'Starter Blade') +
                  '  ·  rank ' +
                  weapon.toString(),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
              '🛡  ' +
                  (gameState.equippedArmor?.name ?? 'Traveler Armor') +
                  '  ·  rank ' +
                  armor.toString(),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (gameState.inventory.isNotEmpty) ...[
            const Divider(height: 20),
            Text(
                'PACK  ·  ' +
                    gameState.inventory.map((item) => item.name).join('  •  '),
                style: const TextStyle(color: gold, fontSize: 11)),
          ],
        ]),
      );

  Widget _lootBanner() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey<String>(gameState.lootNotice),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: gold.withOpacity(.13),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: gold.withOpacity(.3)),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: gold, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'LOOT FOUND  ·  ' + gameState.lootNotice,
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                  fontSize: 11,
                ),
              ),
            ),
          ]),
        ),
      );

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
                      if (gameState.lootNotice.isNotEmpty) _lootBanner(),
                      _route(),
                      const SizedBox(height: 14),
                      _upgrades(),
                      const SizedBox(height: 14),
                      _equipment(),
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
                    'THE ASHEN',
                    style: TextStyle(
                      letterSpacing: 3,
                      fontSize: 11,
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'DEPTHS',
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
                        'LVL ' + gameState.hero.level.toString(),
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
                height: 260,
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
                        gameState.map.name.toUpperCase() +
                            '  ·  ' +
                            gameState.currentRoom.name.toUpperCase(),
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
