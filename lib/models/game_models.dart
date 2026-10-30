enum RoomKind { entrance, battle, treasure }

class HeroModel {
  const HeroModel({
    required this.level,
    required this.health,
    required this.maxHealth,
    required this.attack,
    required this.weaponRank,
    required this.armorRank,
  });
  final int level, health, maxHealth, attack, weaponRank, armorRank;
}

class DungeonRoom {
  const DungeonRoom({required this.name, required this.kind});
  final String name;
  final RoomKind kind;
}

class DungeonFloor {
  const DungeonFloor({
    required this.number,
    required this.enemyName,
    required this.enemyHealth,
    required this.enemyAttack,
    required this.boss,
    required this.goldReward,
  });
  final int number, enemyHealth, enemyAttack, goldReward;
  final String enemyName;
  final bool boss;

  factory DungeonFloor.fromNumber(int floor) {
    const enemies = [
      ('Cave Slime', 22, 12),
      ('Forgotten Skeleton', 34, 18),
      ('Ember Hound', 46, 23),
      ('Crypt Warden', 58, 30),
    ];
    final isBoss = floor % 10 == 0;
    final enemy = enemies[((floor - 1) ~/ 3) % enemies.length];
    return DungeonFloor(
      number: floor,
      enemyName: isBoss ? 'Catacomb Guardian' : enemy.$1,
      enemyHealth: isBoss ? 75 + floor * 13 : enemy.$2 + floor * 9,
      enemyAttack: 4 + floor * 2,
      boss: isBoss,
      goldReward: isBoss ? 70 + floor * 8 : 12 + floor * 3,
    );
  }
}

class DungeonMap {
  const DungeonMap({
    required this.name,
    required this.backgroundAsset,
    required this.rooms,
  });
  final String name, backgroundAsset;
  final List<DungeonRoom> rooms;

  static const ashenCatacombs = DungeonMap(
    name: 'Ashen Catacombs',
    backgroundAsset: 'ashen-catacombs.png',
    rooms: [
      DungeonRoom(name: 'The Gate', kind: RoomKind.entrance),
      DungeonRoom(name: 'Slime Den', kind: RoomKind.battle),
      DungeonRoom(name: 'Treasure Niche', kind: RoomKind.treasure),
    ],
  );
}

enum GearSlot { weapon, armor }

class LootItem {
  const LootItem({
    required this.name,
    required this.slot,
    required this.rank,
    required this.bonus,
  });
  final String name;
  final GearSlot slot;
  final int rank, bonus;

  Map<String, Object> toJson() => {
        'name': name,
        'slot': slot.name,
        'rank': rank,
        'bonus': bonus,
      };

  factory LootItem.fromJson(Map<String, dynamic> json) => LootItem(
        name: json['name'] as String? ?? 'Worn gear',
        slot: GearSlot.values.firstWhere(
          (slot) => slot.name == json['slot'],
          orElse: () => GearSlot.weapon,
        ),
        rank: json['rank'] as int? ?? 0,
        bonus: json['bonus'] as int? ?? 0,
      );
}
