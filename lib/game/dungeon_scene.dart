import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/game_models.dart';

const gold = Color(0xFFFFC857);

class DungeonScene extends FlameGame {
  ui.Image? _background;
  ui.Image? _hero;
  final Map<String, ui.Image> _enemies = {};
  double _attackTime = 0;
  double _enemyFlash = 0;
  double _heroFlash = 0;
  double _idleTime = 0;
  double _lootGlow = 0;
  double _incomingTime = 0;
  double _heroX = .06;
  double _targetHeroX = .06;
  int _damage = 0;
  int _incomingDamage = 0;
  int _roomIndex = 0;
  bool _boss = false;
  String _enemyAsset = 'cave-slime.png';

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _background = await images.load(DungeonMap.ashenCatacombs.backgroundAsset);
    _hero = await images.load('ashen-knight.png');
    for (final asset in [
      'cave-slime.png',
      'forgotten-skeleton.png',
      'ember-hound.png',
    ]) {
      _enemies[asset] = await images.load(asset);
    }
  }

  void setFloor(DungeonFloor floor) {
    _boss = floor.boss;
    _enemyAsset = switch (floor.enemyName) {
      'Forgotten Skeleton' ||
      'Crypt Warden' ||
      'Catacomb Guardian' =>
        'forgotten-skeleton.png',
      'Ember Hound' => 'ember-hound.png',
      _ => 'cave-slime.png',
    };
  }

  void setRoom(int index) {
    _roomIndex = index.clamp(0, 2);
  }

  void walkToRoom(int index) {
    setRoom(index);
    _targetHeroX = switch (index) {
      0 => .04,
      1 => .25,
      _ => .46,
    };
    _attackTime = 0;
  }

  void strike(int damage) {
    _damage = damage;
    _attackTime = .36;
    _enemyFlash = .2;
  }

  void enemyStrike(int damage) {
    _incomingDamage = damage;
    _incomingTime = .62;
  }

  void showLoot() {
    _lootGlow = 1.1;
  }

  void recoverAtEntrance() {
    _roomIndex = 0;
    _targetHeroX = .06;
    _attackTime = 0;
    _enemyFlash = 0;
    _heroFlash = 0;
    _incomingTime = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _idleTime += dt;
    _attackTime = (_attackTime - dt).clamp(0, .36);
    _enemyFlash = (_enemyFlash - dt).clamp(0, .2);
    _heroFlash = (_heroFlash - dt).clamp(0, .18);
    final beforeCounter = _incomingTime;
    _incomingTime = (_incomingTime - dt).clamp(0, .62);
    if (beforeCounter > .28 && _incomingTime <= .28) _heroFlash = .18;
    _lootGlow = (_lootGlow - dt).clamp(0, 1.1);
    _heroX += (_targetHeroX - _heroX) * (1 - math.exp(-dt * 4));
  }

  @override
  void render(ui.Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final background = _background;
    if (background != null && w > 0 && h > 0) {
      final sourceWidth = background.width * .82;
      final maxOffset = background.width - sourceWidth;
      final sourceLeft = maxOffset * (_roomIndex / 2);
      canvas.drawImageRect(
        background,
        ui.Rect.fromLTWH(
            sourceLeft, 0, sourceWidth, background.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, w, h),
        ui.Paint(),
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(0, h * .77, w, h * .23),
        ui.Paint()
          ..shader = ui.Gradient.linear(
            ui.Offset(0, h * .77),
            ui.Offset(0, h),
            [const Color(0x0010131C), const Color(0xB810131C)],
          ),
      );

      final bob = math.sin(_idleTime * 7) * 4;
      final heroWidth = h * .50;
      final heroHeight = h * .80;
      final lunge = _attackTime > 0
          ? math.sin((1 - _attackTime / .36) * math.pi) * 38
          : 0.0;
      final recoil = _incomingTime > 0 && _incomingTime < .28 ? -18.0 : 0.0;
      final heroRect = ui.Rect.fromLTWH(
        w * _heroX + lunge + recoil,
        h * .16 + bob,
        heroWidth,
        heroHeight,
      );
      _drawSprite(
        canvas,
        _hero,
        heroRect,
        flash: _heroFlash > 0,
      );

      if (_roomIndex == 1) {
        final enemySize = h * (_boss ? .63 : .53);
        final enemyRect = ui.Rect.fromLTWH(
          w * .65 + (_attackTime > 0 ? 9.0 : 0.0),
          h * .79 - enemySize + math.sin(_idleTime * 6) * 5,
          enemySize,
          enemySize,
        );
        _drawSprite(canvas, _enemies[_enemyAsset], enemyRect,
            flash: _enemyFlash > 0);
        if (_incomingTime > 0 && _incomingTime < .32) {
          canvas.drawCircle(
            ui.Offset(enemyRect.left + 12, enemyRect.center.dy),
            12 + (1 - _incomingTime / .32) * 13,
            ui.Paint()
              ..color = const Color(0xFFFF704F).withOpacity(_incomingTime / .32)
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 4,
          );
        }
      } else if (_roomIndex == 2) {
        _drawChest(canvas, ui.Offset(w * .73, h * .72));
      }

      if (_attackTime > 0 && _roomIndex == 1) {
        final progress = 1 - (_attackTime / .36);
        final start =
            ui.Offset(heroRect.right - 8, heroRect.top + heroHeight * .34);
        final end = ui.Offset(w * .67, h * .52);
        final center = ui.Offset.lerp(start, end, progress)!;
        canvas.drawCircle(
          center,
          8 + progress * 22,
          ui.Paint()
            ..color = gold.withOpacity(1 - progress)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 5,
        );
        final slash = ui.Path()
          ..moveTo(start.dx, start.dy + 18)
          ..quadraticBezierTo(
            center.dx - 5,
            center.dy - 50,
            end.dx,
            end.dy - 12,
          );
        canvas.drawPath(
          slash,
          ui.Paint()
            ..color = const Color(0xFFFFF3B0).withOpacity(1 - progress)
            ..style = ui.PaintingStyle.stroke
            ..strokeCap = ui.StrokeCap.round
            ..strokeWidth = 5,
        );
        for (var spark = 0; spark < 4; spark++) {
          final spread = math.sin(_idleTime * 21 + spark * 7) * 12;
          canvas.drawCircle(
            center.translate(spread, (spark - 2) * 7),
            2.5,
            ui.Paint()..color = gold.withOpacity((1 - progress) * .8),
          );
        }
        _drawDamage(
            canvas, center.translate(0, -30 - progress * 13), _damage, gold);
      }
      if (_incomingTime > 0 && _incomingTime < .28) {
        final progress = 1 - (_incomingTime / .28);
        _drawDamage(
          canvas,
          ui.Offset(heroRect.center.dx, heroRect.top - 10 - progress * 18),
          _incomingDamage,
          const Color(0xFFFF725F),
        );
      }
      if (_lootGlow > 0 && _roomIndex == 2) {
        canvas.drawCircle(
          ui.Offset(w * .77, h * .57),
          34 + math.sin(_idleTime * 8) * 4,
          ui.Paint()
            ..color = gold.withOpacity((_lootGlow / 1.1) * .45)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18),
        );
      }
    }
    super.render(canvas);
  }

  void _drawChest(ui.Canvas canvas, ui.Offset ground) {
    final rect = ui.Rect.fromCenter(
      center: ground.translate(0, -21),
      width: 56,
      height: 38,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(8)),
      ui.Paint()..color = const Color(0xFF78492B),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(rect.left, rect.top + 16, rect.width, 7),
      ui.Paint()..color = gold,
    );
    canvas.drawCircle(
      rect.center.translate(0, 17),
      5,
      ui.Paint()..color = const Color(0xFFFFE8A0),
    );
  }

  void _drawSprite(ui.Canvas canvas, ui.Image? image, ui.Rect destination,
      {bool flash = false}) {
    if (image == null) return;
    final paint = ui.Paint();
    if (flash) {
      paint.colorFilter =
          const ui.ColorFilter.mode(Colors.white, ui.BlendMode.srcATop);
    }
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      paint,
    );
  }

  void _drawDamage(ui.Canvas canvas, ui.Offset at, int amount, Color color) {
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: 18,
      fontWeight: FontWeight.w900,
    ))
      ..pushStyle(ui.TextStyle(color: color, shadows: const [
        ui.Shadow(color: Colors.black, blurRadius: 5),
      ]))
      ..addText('-$amount');
    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 70));
    canvas.drawParagraph(paragraph, at.translate(-35, -12));
  }
}
