class HeroModel {
  const HeroModel({
    required this.level,
    required this.health,
    required this.maxHealth,
    required this.attack,
  });

  final int level;
  final int health;
  final int maxHealth;
  final int attack;
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

  final int number;
  final String enemyName;
  final int enemyHealth;
  final int enemyAttack;
  final bool boss;
  final int goldReward;

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
  });

  final String name;
  final String backgroundAsset;

  static const ashenCatacombs = DungeonMap(
    name: 'Ashen Catacombs',
    backgroundAsset: 'ashen-catacombs.png',
  );
}
