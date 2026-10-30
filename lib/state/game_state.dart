import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import '../services/save_service.dart';

class GameState extends ChangeNotifier {
  GameState({SaveService? saveService})
      : _saveService = saveService ?? SaveService();

  final SaveService _saveService;
  Timer? _timer;
  DateTime _lastSaved = DateTime.now();
  bool _ready = false;

  int floor = 1, bestFloor = 1, coins = 0, kills = 0, level = 1;
  int hp = 100, maxHp = 100, damage = 12;
  int foeHp = 30, foeMaxHp = 30, foeDamage = 5;
  int weaponRank = 0, armorRank = 0, potions = 0, roomIndex = 0;
  int visualSequence = 0;
  int incomingDamage = 0;
  bool boss = false, initialized = false;
  String visualAction = 'idle';
  String foe = 'Cave Slime';
  String note = 'The gate of the Ashen Catacombs stands before you.';
  String lootNotice = '';
  List<LootItem> inventory = [];
  LootItem? equippedWeapon, equippedArmor;

  DungeonMap get map => DungeonMap.ashenCatacombs;
  DungeonRoom get currentRoom => map.rooms[roomIndex];
  HeroModel get hero => HeroModel(
        level: level,
        health: hp,
        maxHealth: maxHp,
        attack: damage,
        weaponRank: weaponRank,
        armorRank: armorRank,
      );
  int get bladeCost => 45 + weaponRank * 55;
  int get armorCost => 40 + armorRank * 50;

  Future<void> initialize() async {
    await _saveService.initialize();
    final data = _saveService.load();
    if (data != null) _restore(data);
    _spawnEnemy();
    final savedAt = DateTime.tryParse(data?['time'] as String? ?? '');
    if (savedAt != null) {
      final seconds =
          DateTime.now().difference(savedAt).inSeconds.clamp(0, 28800);
      final reward = (seconds * (1 + floor * .35)).floor();
      if (reward > 0) {
        coins += reward;
        note = 'Your hero earned ' + reward.toString() + ' gold while away.';
      }
    }
    _ready = true;
    initialized = true;
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) => tick());
    notifyListeners();
    await save();
  }

  void tick() {
    if (!initialized) return;
    final room = currentRoom;
    if (room.kind == RoomKind.entrance) {
      roomIndex = 1;
      visualSequence++;
      visualAction = 'walk';
      note = 'You enter the Slime Den.';
    } else if (room.kind == RoomKind.battle) {
      visualSequence++;
      visualAction = 'strike';
      incomingDamage = 0;
      foeHp -= damage;
      if (foeHp <= 0) {
        _winEncounter();
        roomIndex = 2;
        visualAction = 'loot';
      } else {
        incomingDamage = foeDamage;
        hp -= foeDamage;
        if (hp <= 0) _recover();
      }
    } else {
      final reward = 18 + floor * 4;
      coins += reward;
      note = 'Treasure room cleared. You found ' + reward.toString() + ' gold.';
      lootNotice = '+' + reward.toString() + ' gold';
      roomIndex = 0;
      floor++;
      if (floor > bestFloor) bestFloor = floor;
      _spawnEnemy();
      visualSequence++;
      visualAction = 'walk';
    }
    notifyListeners();
    if (DateTime.now().difference(_lastSaved).inSeconds >= 8) save();
  }

  void _spawnEnemy() {
    final enemy = DungeonFloor.fromNumber(floor);
    foe = enemy.enemyName;
    foeMaxHp = enemy.enemyHealth;
    foeHp = foeMaxHp;
    foeDamage = enemy.enemyAttack;
    boss = enemy.boss;
  }

  void _winEncounter() {
    final enemy = DungeonFloor.fromNumber(floor);
    final reward = enemy.goldReward;
    coins += reward;
    kills++;
    hp = (hp + (maxHp * .12).round()).clamp(0, maxHp).toInt();
    note = (enemy.boss ? 'Guardian defeated!' : foe + ' defeated!') +
        ' +' +
        reward.toString() +
        ' gold.';
    lootNotice = '+' + reward.toString() + ' gold';

    final drop = _rollLoot();
    if (drop != null) {
      inventory = [drop, ...inventory].take(5).toList();
      final equipped =
          drop.slot == GearSlot.weapon ? equippedWeapon : equippedArmor;
      if (equipped == null || drop.rank > equipped.rank) {
        _equip(drop);
        note = 'Loot found and equipped: ' +
            drop.name +
            ' (+' +
            drop.bonus.toString() +
            ').';
      } else {
        lootNotice = drop.name + ' found';
        note = foe + ' defeated. ' + drop.name + ' was added to your pack.';
      }
    }
    if (enemy.boss) potions++;
    if (kills % 4 == 0) {
      level++;
      damage += 2;
      maxHp += 12;
      hp = maxHp;
      note = 'Level up! You are now level ' + level.toString() + '.';
    }
  }

  LootItem? _rollLoot() {
    if (kills % 3 != 0 && !boss) return null;
    final rank = (kills ~/ 3).clamp(1, 99);
    final slot = kills.isEven ? GearSlot.armor : GearSlot.weapon;
    return LootItem(
      name: slot == GearSlot.weapon ? 'Catacomb Blade' : 'Warden Mail',
      slot: slot,
      rank: rank,
      bonus: slot == GearSlot.weapon ? 3 + rank * 2 : 8 + rank * 5,
    );
  }

  void _equip(LootItem item) {
    if (item.slot == GearSlot.weapon) {
      final previous = equippedWeapon?.bonus ?? 0;
      equippedWeapon = item;
      weaponRank = item.rank;
      damage += item.bonus - previous;
    } else {
      final previous = equippedArmor?.bonus ?? 0;
      equippedArmor = item;
      armorRank = item.rank;
      maxHp += item.bonus - previous;
      hp = (hp + item.bonus - previous).clamp(1, maxHp).toInt();
    }
  }

  void _recover() {
    hp = maxHp;
    roomIndex = 0;
    floor = floor > 1 ? floor - 1 : 1;
    _spawnEnemy();
    note = 'The knight recovers at the entrance of floor ' +
        floor.toString() +
        '.';
    visualSequence++;
    visualAction = 'recover';
  }

  void buyWeaponUpgrade() {
    if (coins < bladeCost) return;
    coins -= bladeCost;
    weaponRank++;
    damage += 5;
    note = 'Blade upgraded to rank ' + weaponRank.toString() + '.';
    notifyListeners();
    save();
  }

  void buyArmorUpgrade() {
    if (coins < armorCost) return;
    coins -= armorCost;
    armorRank++;
    maxHp += 25;
    hp = (hp + 25).clamp(0, maxHp).toInt();
    note = 'Armor upgraded to rank ' + armorRank.toString() + '.';
    notifyListeners();
    save();
  }

  void drinkPotion() {
    if (potions == 0 || hp == maxHp) return;
    potions--;
    hp = (hp + (maxHp * .55).round()).clamp(0, maxHp).toInt();
    note = 'A potion restored your strength.';
    notifyListeners();
    save();
  }

  Future<void> save() async {
    if (!_ready) return;
    _lastSaved = DateTime.now();
    await _saveService.save({
      'floor': floor,
      'best': bestFloor,
      'coins': coins,
      'kills': kills,
      'level': level,
      'hp': hp,
      'maxHp': maxHp,
      'damage': damage,
      'weapon': weaponRank,
      'armor': armorRank,
      'potions': potions,
      'room': roomIndex,
      'inventory': inventory.map((item) => item.toJson()).toList(),
      'equippedWeapon': equippedWeapon?.toJson(),
      'equippedArmor': equippedArmor?.toJson(),
      'time': _lastSaved.toIso8601String(),
    });
  }

  void _restore(Map<String, dynamic> data) {
    floor = data['floor'] as int? ?? 1;
    bestFloor = data['best'] as int? ?? floor;
    coins = data['coins'] as int? ?? 0;
    kills = data['kills'] as int? ?? 0;
    level = data['level'] as int? ?? 1;
    hp = data['hp'] as int? ?? 100;
    maxHp = data['maxHp'] as int? ?? 100;
    damage = data['damage'] as int? ?? 12;
    weaponRank = data['weapon'] as int? ?? 0;
    armorRank = data['armor'] as int? ?? 0;
    potions = data['potions'] as int? ?? 0;
    roomIndex = (data['room'] as int? ?? 0).clamp(0, 2);
    final items = data['inventory'] as List<dynamic>? ?? [];
    inventory =
        items.whereType<Map<String, dynamic>>().map(LootItem.fromJson).toList();
    final weaponData = data['equippedWeapon'];
    if (weaponData is Map<String, dynamic>)
      equippedWeapon = LootItem.fromJson(weaponData);
    final armorData = data['equippedArmor'];
    if (armorData is Map<String, dynamic>)
      equippedArmor = LootItem.fromJson(armorData);
  }

  @override
  void dispose() {
    _timer?.cancel();
    save();
    super.dispose();
  }
}
