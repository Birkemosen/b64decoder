import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_highlight/flutter_highlight.dart';

void main() {
  runApp(const B64DecoderApp());
}

class B64DecoderApp extends StatelessWidget {
  const B64DecoderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B64 Decoder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE6A855),
          secondary: Color(0xFF58A6FF),
          surface: Color(0xFF161B22),
          error: Color(0xFFF85149),
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const DecoderScreen(),
    );
  }
}

enum LayoutMode { sideBySide, stacked }

enum ContentType { plain, json, xml, html }

class DecoderScreen extends StatefulWidget {
  const DecoderScreen({super.key});

  @override
  State<DecoderScreen> createState() => _DecoderScreenState();
}

class _DecoderScreenState extends State<DecoderScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  String _decodedOutput = '';
  String? _errorMessage;
  bool _isDecoding = false;
  bool _autoDecode = true;
  LayoutMode _layoutMode = LayoutMode.sideBySide;
  ContentType _detectedType = ContentType.plain;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Custom theme based on atom-one-dark but matching our app colors
  final Map<String, TextStyle> _customTheme = {
    'root': TextStyle(
      color: const Color(0xFFABB2BF),
      backgroundColor: const Color(0xFF161B22),
    ),
    'comment': const TextStyle(color: Color(0xFF5C6370), fontStyle: FontStyle.italic),
    'quote': const TextStyle(color: Color(0xFF5C6370), fontStyle: FontStyle.italic),
    'doctag': const TextStyle(color: Color(0xFFC678DD)),
    'keyword': const TextStyle(color: Color(0xFFC678DD)),
    'formula': const TextStyle(color: Color(0xFFC678DD)),
    'section': const TextStyle(color: Color(0xFFE06C75)),
    'name': const TextStyle(color: Color(0xFFE06C75)),
    'selector-tag': const TextStyle(color: Color(0xFFE06C75)),
    'deletion': const TextStyle(color: Color(0xFFE06C75)),
    'subst': const TextStyle(color: Color(0xFFE06C75)),
    'literal': const TextStyle(color: Color(0xFF56B6C2)),
    'string': const TextStyle(color: Color(0xFF98C379)),
    'regexp': const TextStyle(color: Color(0xFF98C379)),
    'addition': const TextStyle(color: Color(0xFF98C379)),
    'attribute': const TextStyle(color: Color(0xFF98C379)),
    'meta-string': const TextStyle(color: Color(0xFF98C379)),
    'built_in': const TextStyle(color: Color(0xFFE6C07B)),
    'attr': const TextStyle(color: Color(0xFFD19A66)),
    'variable': const TextStyle(color: Color(0xFFD19A66)),
    'template-variable': const TextStyle(color: Color(0xFFD19A66)),
    'type': const TextStyle(color: Color(0xFFD19A66)),
    'selector-class': const TextStyle(color: Color(0xFFD19A66)),
    'selector-attr': const TextStyle(color: Color(0xFFD19A66)),
    'selector-pseudo': const TextStyle(color: Color(0xFFD19A66)),
    'number': const TextStyle(color: Color(0xFFD19A66)),
    'symbol': const TextStyle(color: Color(0xFF61AEEE)),
    'bullet': const TextStyle(color: Color(0xFF61AEEE)),
    'link': const TextStyle(color: Color(0xFF61AEEE)),
    'meta': const TextStyle(color: Color(0xFF61AEEE)),
    'selector-id': const TextStyle(color: Color(0xFF61AEEE)),
    'title': const TextStyle(color: Color(0xFF61AEEE)),
    'emphasis': const TextStyle(fontStyle: FontStyle.italic),
    'strong': const TextStyle(fontWeight: FontWeight.bold),
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_autoDecode) {
      _tryAutoDecode();
    }
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  bool _isValidBase64(String input) {
    if (input.isEmpty) return false;
    
    // Remove whitespace for validation
    final cleaned = input.replaceAll(RegExp(r'\s'), '');
    
    // Check if it matches base64 pattern
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    if (!base64Pattern.hasMatch(cleaned)) return false;
    
    // Check length is valid (must be multiple of 4 after padding)
    if (cleaned.length % 4 != 0) return false;
    
    // Minimum length check (at least 4 chars for meaningful content)
    if (cleaned.length < 4) return false;
    
    return true;
  }

  void _tryAutoDecode() {
    final input = _inputController.text.trim();
    
    if (input.isEmpty) {
      setState(() {
        _decodedOutput = '';
        _detectedType = ContentType.plain;
      });
      _animationController.reverse();
      return;
    }

    if (!_isValidBase64(input)) {
      // Not valid base64, clear output silently
      if (_decodedOutput.isNotEmpty) {
        setState(() {
          _decodedOutput = '';
          _detectedType = ContentType.plain;
        });
        _animationController.reverse();
      }
      return;
    }

    try {
      final decoded = utf8.decode(base64Decode(input));
      final detectedType = _detectContentType(decoded);
      final formattedOutput = _formatContent(decoded, detectedType);
      
      setState(() {
        _decodedOutput = formattedOutput;
        _detectedType = detectedType;
        _errorMessage = null;
      });
      _animationController.forward();
    } catch (e) {
      // Silently fail for auto-decode
      if (_decodedOutput.isNotEmpty) {
        setState(() {
          _decodedOutput = '';
          _detectedType = ContentType.plain;
        });
        _animationController.reverse();
      }
    }
  }

  ContentType _detectContentType(String content) {
    final trimmed = content.trim();
    
    // Check for JSON
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        json.decode(trimmed);
        return ContentType.json;
      } catch (_) {}
    }
    
    // Check for HTML
    if (trimmed.contains('<!DOCTYPE html') ||
        trimmed.contains('<html') ||
        (trimmed.startsWith('<') && 
         (trimmed.contains('<head') || 
          trimmed.contains('<body') || 
          trimmed.contains('<div') ||
          trimmed.contains('<p>') ||
          trimmed.contains('<span') ||
          trimmed.contains('<script') ||
          trimmed.contains('<style')))) {
      return ContentType.html;
    }
    
    // Check for XML
    if (trimmed.startsWith('<?xml') ||
        (trimmed.startsWith('<') && 
         trimmed.endsWith('>') && 
         !trimmed.contains('<!DOCTYPE html'))) {
      // Basic XML pattern check
      final xmlPattern = RegExp(r'^<[a-zA-Z][\w-]*(\s+[^>]*)?>[\s\S]*</[a-zA-Z][\w-]*>$|^<\?xml');
      if (xmlPattern.hasMatch(trimmed)) {
        return ContentType.xml;
      }
      // Also check for self-closing or simple tags
      if (trimmed.startsWith('<') && trimmed.contains('</')) {
        return ContentType.xml;
      }
    }
    
    return ContentType.plain;
  }

  String _formatContent(String content, ContentType type) {
    switch (type) {
      case ContentType.json:
        return _prettyPrintJson(content);
      case ContentType.xml:
        return _prettyPrintXml(content);
      case ContentType.html:
        return _prettyPrintHtml(content);
      case ContentType.plain:
        return content;
    }
  }

  String _prettyPrintJson(String content) {
    try {
      final parsed = json.decode(content);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (_) {
      return content;
    }
  }

  String _prettyPrintXml(String content) {
    try {
      final buffer = StringBuffer();
      int indent = 0;
      final String indentStr = '  ';
      
      // Collect all tokens (tags and text)
      final regex = RegExp(r'(<[^>]+>)|([^<]+)');
      final matches = regex.allMatches(content).toList();
      
      int i = 0;
      while (i < matches.length) {
        final match = matches[i];
        final tag = match.group(1);
        final text = match.group(2);
        
        if (tag != null) {
          if (tag.startsWith('<?')) {
            // XML declaration
            buffer.writeln(tag);
          } else if (tag.startsWith('<!--')) {
            // Comment
            buffer.writeln('${indentStr * indent}$tag');
          } else if (tag.startsWith('</')) {
            // Closing tag
            indent = (indent - 1).clamp(0, 100);
            buffer.writeln('${indentStr * indent}$tag');
          } else if (tag.endsWith('/>')) {
            // Self-closing tag
            buffer.writeln('${indentStr * indent}$tag');
          } else {
            // Opening tag - check if we can inline it
            final tagNameMatch = RegExp(r'<(\w+)').firstMatch(tag);
            final tagName = tagNameMatch?.group(1) ?? '';
            
            // Look ahead to see if this is a simple element (open tag, text, close tag)
            if (i + 2 < matches.length) {
              final nextText = matches[i + 1].group(2)?.trim();
              final closeTag = matches[i + 2].group(1);
              
              if (nextText != null && 
                  nextText.isNotEmpty && 
                  !nextText.contains('\n') &&
                  closeTag != null && 
                  closeTag == '</$tagName>') {
                // Inline: <tag>text</tag>
                buffer.writeln('${indentStr * indent}$tag$nextText$closeTag');
                i += 3;
                continue;
              }
            }
            
            // Not inline - regular formatting
            buffer.writeln('${indentStr * indent}$tag');
            indent++;
          }
        } else if (text != null) {
          final trimmedText = text.trim();
          if (trimmedText.isNotEmpty) {
            buffer.writeln('${indentStr * indent}$trimmedText');
          }
        }
        i++;
      }
      
      return buffer.toString().trim();
    } catch (_) {
      return content;
    }
  }

  String _prettyPrintHtml(String content) {
    try {
      final buffer = StringBuffer();
      int indent = 0;
      final String indentStr = '  ';
      
      // Void elements that don't have closing tags
      final voidElements = {
        'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
        'link', 'meta', 'param', 'source', 'track', 'wbr'
      };
      
      // Block elements that should have content on separate lines
      final blockElements = {
        'html', 'head', 'body', 'div', 'section', 'article', 'header', 
        'footer', 'nav', 'main', 'aside', 'ul', 'ol', 'table', 'thead',
        'tbody', 'tfoot', 'tr', 'form', 'fieldset'
      };
      
      // Collect all tokens
      final regex = RegExp(r'(<[^>]+>)|([^<]+)');
      final matches = regex.allMatches(content).toList();
      
      int i = 0;
      while (i < matches.length) {
        final match = matches[i];
        final tag = match.group(1);
        final text = match.group(2);
        
        if (tag != null) {
          final tagNameMatch = RegExp(r'</?(\w+)').firstMatch(tag);
          final tagName = tagNameMatch?.group(1)?.toLowerCase() ?? '';
          final isVoid = voidElements.contains(tagName);
          final isBlock = blockElements.contains(tagName);
          
          if (tag.startsWith('<!')) {
            // DOCTYPE or comment
            buffer.writeln(tag);
          } else if (tag.startsWith('</')) {
            // Closing tag
            indent = (indent - 1).clamp(0, 100);
            buffer.writeln('${indentStr * indent}$tag');
          } else if (tag.endsWith('/>') || isVoid) {
            // Self-closing or void tag
            buffer.writeln('${indentStr * indent}$tag');
          } else if (isBlock) {
            // Block element - always expand
            buffer.writeln('${indentStr * indent}$tag');
            indent++;
          } else {
            // Non-block element - try to inline
            if (i + 2 < matches.length) {
              final nextText = matches[i + 1].group(2)?.trim();
              final closeTag = matches[i + 2].group(1);
              
              if (nextText != null && 
                  nextText.isNotEmpty && 
                  !nextText.contains('\n') &&
                  closeTag != null && 
                  closeTag.toLowerCase() == '</$tagName>') {
                // Inline: <tag>text</tag>
                buffer.writeln('${indentStr * indent}$tag$nextText$closeTag');
                i += 3;
                continue;
              }
            }
            
            // Can't inline - regular formatting
            buffer.writeln('${indentStr * indent}$tag');
            indent++;
          }
        } else if (text != null) {
          final trimmedText = text.trim();
          if (trimmedText.isNotEmpty) {
            buffer.writeln('${indentStr * indent}$trimmedText');
          }
        }
        i++;
      }
      
      return buffer.toString().trim();
    } catch (_) {
      return content;
    }
  }

  String _getLanguageString(ContentType type) {
    switch (type) {
      case ContentType.json:
        return 'json';
      case ContentType.xml:
        return 'xml';
      case ContentType.html:
        return 'html';
      case ContentType.plain:
        return 'plaintext';
    }
  }

  String _getContentTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.json:
        return 'JSON';
      case ContentType.xml:
        return 'XML';
      case ContentType.html:
        return 'HTML';
      case ContentType.plain:
        return 'TEXT';
    }
  }

  Color _getContentTypeColor(ContentType type) {
    switch (type) {
      case ContentType.json:
        return const Color(0xFFE6C07B); // Yellow
      case ContentType.xml:
        return const Color(0xFF61AEEE); // Blue
      case ContentType.html:
        return const Color(0xFFE06C75); // Red
      case ContentType.plain:
        return const Color(0xFF7EE787); // Green
    }
  }

  void _decodeBase64() {
    setState(() {
      _isDecoding = true;
      _errorMessage = null;
    });

    try {
      final input = _inputController.text.trim();
      if (input.isEmpty) {
        setState(() {
          _decodedOutput = '';
          _detectedType = ContentType.plain;
          _isDecoding = false;
        });
        _animationController.reverse();
        return;
      }

      // Decode base64
      final decoded = utf8.decode(base64Decode(input));
      final detectedType = _detectContentType(decoded);
      final formattedOutput = _formatContent(decoded, detectedType);
      
      setState(() {
        _decodedOutput = formattedOutput;
        _detectedType = detectedType;
        _isDecoding = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid Base64 input';
        _decodedOutput = '';
        _detectedType = ContentType.plain;
        _isDecoding = false;
      });
      _animationController.reverse();
    }
  }

  void _copyToClipboard() {
    if (_decodedOutput.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _decodedOutput));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied to clipboard!',
            style: GoogleFonts.jetBrainsMono(),
          ),
          backgroundColor: const Color(0xFF238636),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _clearAll() {
    setState(() {
      _inputController.clear();
      _decodedOutput = '';
      _detectedType = ContentType.plain;
      _errorMessage = null;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1117),
              Color(0xFF161B22),
              Color(0xFF0D1117),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 24),

                // Main content
                Expanded(
                  child: _layoutMode == LayoutMode.sideBySide
                      ? _buildSideBySideLayout()
                      : _buildStackedLayout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/icon.png',
            width: 86,
            height: 86,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'B64 Decoder',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Decode Base64 encoded messages',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
        // Auto-decode toggle
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Tooltip(
            message: _autoDecode ? 'Auto-decode ON' : 'Auto-decode OFF',
            child: InkWell(
              onTap: () => setState(() => _autoDecode = !_autoDecode),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: _autoDecode 
                          ? const Color(0xFFE6A855) 
                          : Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AUTO',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _autoDecode 
                            ? const Color(0xFFE6A855) 
                            : Colors.white38,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Layout toggle button
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLayoutToggleButton(
                icon: Icons.view_sidebar_rounded,
                isSelected: _layoutMode == LayoutMode.sideBySide,
                onTap: () => setState(() => _layoutMode = LayoutMode.sideBySide),
                tooltip: 'Side by side',
              ),
              _buildLayoutToggleButton(
                icon: Icons.view_agenda_rounded,
                isSelected: _layoutMode == LayoutMode.stacked,
                onTap: () => setState(() => _layoutMode = LayoutMode.stacked),
                tooltip: 'Stacked',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE6A855).withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? const Color(0xFFE6A855) : Colors.white38,
          ),
        ),
      ),
    );
  }

  Widget _buildSideBySideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left pane - Input
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildInputSection(expanded: true)),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Right pane - Output
        Expanded(child: _buildOutputSection()),
      ],
    );
  }

  Widget _buildStackedLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input section
        _buildInputSection(expanded: false),
        const SizedBox(height: 16),
        // Action buttons
        _buildActionButtons(),
        const SizedBox(height: 16),
        // Output section
        Expanded(child: _buildOutputSection()),
      ],
    );
  }

  Widget _buildInputSection({required bool expanded}) {
    final content = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _errorMessage != null
              ? const Color(0xFFF85149).withOpacity(0.5)
              : const Color(0xFF30363D),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF58A6FF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'INPUT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF58A6FF),
                    letterSpacing: 1.5,
                  ),
                ),
                if (_autoDecode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF238636).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LIVE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF238636),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Paste your Base64 encoded text here...',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: Colors.white24,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Color(0xFFF85149),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: const Color(0xFFF85149),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (expanded) {
      return content;
    } else {
      return SizedBox(height: 180, child: content);
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isDecoding ? null : _decodeBase64,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE6A855),
              foregroundColor: const Color(0xFF0D1117),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isDecoding)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0D1117),
                    ),
                  )
                else
                  const Icon(Icons.transform_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'DECODE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: IconButton(
            onPressed: _clearAll,
            icon: const Icon(
              Icons.clear_all_rounded,
              color: Colors.white54,
            ),
            tooltip: 'Clear all',
          ),
        ),
      ],
    );
  }

  Widget _buildOutputSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _decodedOutput.isNotEmpty
                            ? const Color(0xFF238636)
                            : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OUTPUT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _decodedOutput.isNotEmpty
                            ? const Color(0xFF238636)
                            : Colors.white38,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (_decodedOutput.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getContentTypeColor(_detectedType)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getContentTypeColor(_detectedType)
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _getContentTypeLabel(_detectedType),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _getContentTypeColor(_detectedType),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_decodedOutput.isNotEmpty)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: TextButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: Color(0xFF58A6FF),
                      ),
                      label: Text(
                        'Copy',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: const Color(0xFF58A6FF),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF30363D)),
          Expanded(
            child: _decodedOutput.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.output_rounded,
                          size: 48,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _autoDecode 
                              ? 'Start typing Base64 to see live output'
                              : 'Decoded output will appear here',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: _buildHighlightedOutput(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedOutput() {
    if (_detectedType == ContentType.plain) {
      // Plain text - use SelectableText
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _decodedOutput,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            color: const Color(0xFF7EE787),
            height: 1.6,
          ),
        ),
      );
    }

    // Syntax highlighted content
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0),
      child: HighlightView(
        _decodedOutput,
        language: _getLanguageString(_detectedType),
        theme: _customTheme,
        padding: const EdgeInsets.all(16),
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }
}
