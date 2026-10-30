import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/game_models.dart';

const gold = Color(0xFFFFC857);

class DungeonScene extends FlameGame {
  ui.Image? _background;
  ui.Image? _hero;
  ui.Image? _enemy;
  double _attackTime = 0;
  double _enemyFlash = 0;
  double _idleTime = 0;
  int _damage = 0;
  bool _boss = false;

  @override
  Future<void> onLoad() async {
    _background = await images.load(DungeonMap.ashenCatacombs.backgroundAsset);
    _hero = await images.load('ashen-knight.png');
    _enemy = await images.load('cave-slime.png');
  }

  void setFloor(DungeonFloor floor) {
    _boss = floor.boss;
  }

  void strike(int damage) {
    _damage = damage;
    _attackTime = .34;
    _enemyFlash = .16;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _idleTime += dt;
    _attackTime = (_attackTime - dt).clamp(0, .34);
    _enemyFlash = (_enemyFlash - dt).clamp(0, .16);
  }

  @override
  void render(ui.Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final background = _background;
    if (background == null || w <= 0 || h <= 0) return;

    canvas.drawImageRect(
      background,
      ui.Rect.fromLTWH(
          0, 0, background.width.toDouble(), background.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint(),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, h * .78, w, h * .22),
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(0, h * .78),
          ui.Offset(0, h),
          [const Color(0x0010131C), const Color(0xB810131C)],
        ),
    );

    final bob = math.sin(_idleTime * 4) * 3;
    final lunge = _attackTime > .18 ? 20.0 : (_attackTime > 0 ? -5.0 : 0.0);
    _drawSprite(
      canvas,
      _hero,
      ui.Rect.fromLTWH(w * .07 + lunge, h * .18 + bob, w * .43, h * .78),
    );
    final enemySize = _boss ? .48 : .37;
    final enemyRect = ui.Rect.fromLTWH(
      w * .58,
      h * (.79 - enemySize) + math.sin(_idleTime * 5) * 4,
      w * enemySize,
      h * enemySize,
    );
    _drawSprite(canvas, _enemy, enemyRect, flash: _enemyFlash > 0);

    if (_attackTime > 0) {
      final progress = 1 - (_attackTime / .34);
      final center = ui.Offset(w * (.61 + progress * .08), h * .48);
      final radius = 12 + progress * 25;
      canvas.drawCircle(
        center,
        radius,
        ui.Paint()
          ..color = gold.withOpacity(1 - progress)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      _drawDamage(canvas, center.translate(0, -30 - progress * 12));
    }
    super.render(canvas);
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

  void _drawDamage(ui.Canvas canvas, ui.Offset at) {
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: 18,
      fontWeight: FontWeight.w900,
    ))
      ..pushStyle(ui.TextStyle(color: gold, shadows: const [
        ui.Shadow(color: Colors.black, blurRadius: 5),
      ]))
      ..addText('-$_damage');
    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 70));
    canvas.drawParagraph(paragraph, at.translate(-35, -12));
  }
}
