import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final sizes = [16, 32, 64, 128, 256, 512, 1024];
  
  for (final size in sizes) {
    final icon = generateIcon(size);
    final fileName = 'app_icon_$size.png';
    final path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/$fileName';
    File(path).writeAsBytesSync(img.encodePng(icon));
    print('Generated $path');
  }
  
  print('\nAll icons generated successfully!');
}

img.Image generateIcon(int size) {
  final image = img.Image(width: size, height: size);
  final random = Random(42); // Fixed seed for consistent results
  
  // Colors
  final accentColor = img.ColorRgba8(230, 168, 85, 255);  // #E6A855 - amber
  final textColor = img.ColorRgba8(255, 255, 255, 255);   // white
  
  final cornerRadius = size * 0.22;
  
  // Fill background with rounded corners and gradient
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (_isInRoundedRect(x, y, size, size, cornerRadius)) {
        final gradientFactor = ((x + y) / (size * 2)).clamp(0.0, 1.0);
        final r = _lerp(13, 22, gradientFactor).round();
        final g = _lerp(17, 27, gradientFactor).round();
        final b = _lerp(23, 34, gradientFactor).round();
        image.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
      }
    }
  }
  
  final centerX = size / 2;
  final centerY = size / 2;
  
  // Calculate bracket dimensions
  final bracketHeight = size * 0.55;
  final bracketWidth = size * 0.08;
  final bracketInset = size * 0.15;
  final bracketTopY = centerY - bracketHeight / 2;
  
  // Right bracket X position (needed for particle boundary)
  final rightBracketX = size - bracketInset - bracketWidth;
  final rightBracketInnerX = rightBracketX - bracketWidth * 1.2;
  // Particles can go up to the vertical bar of ], not just to the inner horizontal arms
  final particleBoundaryX = rightBracketX;
  
  // Left bracket [
  final leftBracketX = bracketInset;
  _fillRect(image, leftBracketX.round(), bracketTopY.round(), 
            bracketWidth.round(), bracketHeight.round(), accentColor);
  _fillRect(image, leftBracketX.round(), bracketTopY.round(), 
            (bracketWidth * 2.2).round(), bracketWidth.round(), accentColor);
  _fillRect(image, leftBracketX.round(), (bracketTopY + bracketHeight - bracketWidth).round(), 
            (bracketWidth * 2.2).round(), bracketWidth.round(), accentColor);
  
  // Right bracket ]
  _fillRect(image, rightBracketX.round(), bracketTopY.round(), 
            bracketWidth.round(), bracketHeight.round(), accentColor);
  _fillRect(image, rightBracketInnerX.round(), bracketTopY.round(), 
            (bracketWidth * 2.2).round(), bracketWidth.round(), accentColor);
  _fillRect(image, rightBracketInnerX.round(), (bracketTopY + bracketHeight - bracketWidth).round(), 
            (bracketWidth * 2.2).round(), bracketWidth.round(), accentColor);
  
  // Draw "64" centered between the brackets
  if (size >= 32) {
    final textHeight = size * 0.32;
    final textWidth = textHeight * 1.3;
    
    final textStartX = centerX - textWidth / 2;
    final textStartY = centerY - textHeight / 2;
    
    final charWidth = textHeight * 0.5;
    final spacing = textHeight * 0.15;
    
    // Draw "6" (solid)
    _drawSix(image, textStartX.round(), textStartY.round(), textHeight.round(), charWidth.round(), textColor);
    
    // Draw "4" with fragmentation effect
    final fourX = (textStartX + charWidth + spacing).round();
    _drawFourFragmented(
      image, 
      fourX, 
      textStartY.round(), 
      textHeight.round(), 
      charWidth.round(), 
      textColor, 
      random, 
      iconSize: size,
      maxParticleX: particleBoundaryX.round() - 2,  // Can go into bracket's interior space
    );
  }
  
  return image;
}

double _lerp(double a, double b, double t) {
  return a + (b - a) * t;
}

bool _isInRoundedRect(int x, int y, int width, int height, double radius) {
  if (x < radius && y < radius) {
    return _distance(x, y, radius, radius) <= radius;
  }
  if (x >= width - radius && y < radius) {
    return _distance(x, y, width - radius - 1, radius) <= radius;
  }
  if (x < radius && y >= height - radius) {
    return _distance(x, y, radius, height - radius - 1) <= radius;
  }
  if (x >= width - radius && y >= height - radius) {
    return _distance(x, y, width - radius - 1, height - radius - 1) <= radius;
  }
  return true;
}

double _distance(int x1, int y1, double x2, double y2) {
  return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
}

void _fillRect(img.Image image, int x, int y, int w, int h, img.Color color) {
  for (int dy = 0; dy < h; dy++) {
    for (int dx = 0; dx < w; dx++) {
      final px = x + dx;
      final py = y + dy;
      if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
        image.setPixel(px, py, color);
      }
    }
  }
}

void _drawSix(img.Image image, int x, int y, int h, int w, img.Color color) {
  final thickness = (h * 0.18).round().clamp(2, 100);
  
  _fillRect(image, x + thickness, y, w - thickness, thickness, color);
  _fillRect(image, x, y, thickness, h, color);
  _fillRect(image, x + thickness, y + (h - thickness) ~/ 2, w - thickness, thickness, color);
  _fillRect(image, x + thickness, y + h - thickness, w - thickness, thickness, color);
  _fillRect(image, x + w - thickness, y + (h + thickness) ~/ 2, thickness, (h - thickness) ~/ 2, color);
}

void _drawFourFragmented(img.Image image, int x, int y, int h, int w, img.Color color, Random random, {required int iconSize, required int maxParticleX}) {
  final thickness = (h * 0.18).round().clamp(2, 100);
  
  // Square size for both holes and particles - consistent size
  final squareSize = (iconSize * 0.025).round().clamp(2, 16);
  
  // Draw the solid parts of the "4"
  // Left vertical (top 55%) - fully solid
  _fillRect(image, x, y, thickness, (h * 0.55).round(), color);
  
  // Middle horizontal (at ~45% height) - fully solid  
  _fillRect(image, x, y + (h * 0.45).round(), w, thickness, color);
  
  // Right vertical - draw with grid-based fragmentation
  final rightEdgeX = x + w - thickness;
  
  // Create a grid of squares for the right vertical stroke
  final numSquaresX = (thickness / squareSize).ceil();
  final numSquaresY = (h / squareSize).ceil();
  
  // Track which squares are removed (will become particles)
  final List<Point> removedSquares = [];
  
  for (int gridY = 0; gridY < numSquaresY; gridY++) {
    for (int gridX = 0; gridX < numSquaresX; gridX++) {
      final squareX = rightEdgeX + gridX * squareSize;
      final squareY = y + gridY * squareSize;
      
      // Fragmentation probability increases from left to right
      final fragmentProgress = gridX / numSquaresX;
      final shouldFragment = random.nextDouble() < fragmentProgress * 0.85;
      
      if (shouldFragment) {
        // This square is removed - save for particle drawing
        removedSquares.add(Point(squareX.round(), squareY.round()));
      } else {
        // Draw the square as part of the "4"
        _fillRect(image, squareX.round(), squareY.round(), squareSize, squareSize, color);
      }
    }
  }
  
  // Draw particles for removed squares - floating to the right
  // High density near the 4, fading to the right
  for (final removed in removedSquares) {
    final floatDistance = (random.nextDouble() * iconSize * 0.08 + squareSize).round();
    final floatY = ((random.nextDouble() - 0.5) * squareSize * 3).round();
    
    final particleX = removed.x + floatDistance;
    final particleY = removed.y + floatY;
    
    if (particleX + squareSize > maxParticleX) continue;
    
    // Fade based on distance from the 4
    final distanceRatio = floatDistance / (maxParticleX - removed.x);
    final opacity = (255 * (1.0 - distanceRatio * 0.7)).round().clamp(80, 255);
    final particleColor = img.ColorRgba8(255, 255, 255, opacity);
    
    _fillRect(image, particleX, particleY, squareSize, squareSize, particleColor);
  }
  
  // Scattered particles with density gradient (high on left, low on right)
  // Start particles from within the 4 (from the right vertical stroke area)
  final particleStartX = x + w - thickness;  // Start from within the 4
  final totalGapWidth = maxParticleX - particleStartX;
  final totalParticles = (iconSize * 0.05).round().clamp(5, 25);
  
  for (int i = 0; i < totalParticles; i++) {
    // Bias position toward the left (near/inside the 4)
    // Use squared random to cluster more particles on the left
    final positionBias = random.nextDouble() * random.nextDouble();  // Clusters left
    final floatX = (particleStartX + positionBias * (totalGapWidth - squareSize)).round();
    final floatY = (y + random.nextDouble() * h + (random.nextDouble() - 0.5) * h * 0.3).round();
    
    if (floatX + squareSize > maxParticleX) continue;
    
    // Opacity fades as particles get further from the 4
    final distanceFromFour = floatX - particleStartX;
    final distanceRatio = distanceFromFour / totalGapWidth;
    final opacity = (220 * (1.0 - distanceRatio * 0.6) + random.nextDouble() * 30).round().clamp(50, 230);
    final particleColor = img.ColorRgba8(255, 255, 255, opacity);
    
    _fillRect(image, floatX, floatY, squareSize, squareSize, particleColor);
  }
}

class Point {
  final int x;
  final int y;
  Point(this.x, this.y);
}
