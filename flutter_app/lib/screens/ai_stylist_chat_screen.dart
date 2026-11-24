import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ai_stylist_service.dart';
import '../state/outfit_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/placeholder_image.dart';
import 'wardrobe_item_detail_screen.dart';

class ChatMessage {
  ChatMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.options = const [],
    this.generalAdvice,
  });

  final bool isUser;
  final String text;
  final DateTime timestamp;
  final List<StylistOutfitOption> options;
  final String? generalAdvice;
}

class AiStylistChatScreen extends StatefulWidget {
  const AiStylistChatScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<AiStylistChatScreen> createState() => _AiStylistChatScreenState();
}

class _AiStylistChatScreenState extends State<AiStylistChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();

    // Friendly opening message from AI Stylist explaining free-form input
    _messages.add(
      ChatMessage(
        isUser: false,
        text: 'Halo! Aku AI Stylist pribadimu. Kamu bisa bebas menanyakan rekomendasi outfit untuk acara apa saja, preferensi warna, atau gaya tertentu (misalnya: wisuda teman, ngampus santai, meeting formal, hingga paduan warna netral). Ceritakan apa yang kamu butuhkan!',
        timestamp: DateTime.now(),
      ),
    );

    // If an initial query was passed from Dashboard, submit it immediately
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(widget.initialQuery!.trim());
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || _isThinking) return;

    _textController.clear();

    setState(() {
      _messages.add(
        ChatMessage(isUser: true, text: cleanQuery, timestamp: DateTime.now()),
      );
      _isThinking = true;
    });
    _scrollToBottom();

    // Process through AiStylistService
    try {
      final response = await aiStylistService.recommend(query: cleanQuery);

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: response.message,
            timestamp: DateTime.now(),
            options: response.options,
            generalAdvice: response.generalAdvice,
          ),
        );
        _isThinking = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'Maaf, terjadi kendala saat memproses permintaanmu. Coba sampaikan gayamu dengan kata kunci acara atau warna ya.',
            timestamp: DateTime.now(),
          ),
        );
        _isThinking = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveOptionToFavorites(
    BuildContext context,
    StylistOutfitOption option,
  ) async {
    try {
      final outfit = SavedOutfit(
        id: newOutfitId(),
        name: option.title,
        itemIds: option.items.map((i) => i.id).toList(),
        threshold: option.matchScore / 100.0,
        favorite: true,
      );
      await saveOutfit(outfit);

      if (context.mounted) {
        showSuccessSnackBar(context, 'Kombinasi tersimpan di Favorit');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan favorit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.sheet,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.action.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, color: palette.action, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Stylist GAYAKU',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.ink,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Asisten Gaya Pribadi • Online',
                        style: TextStyle(fontSize: 11, color: palette.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message List (Spacious & Clean)
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                itemCount: _messages.length + (_isThinking ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _buildMessageItem(palette, _messages[index]);
                  }
                  if (_isThinking && index == _messages.length) {
                    return _buildThinkingBubble(palette);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            // Message Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: palette.sheet,
                border: Border(
                  top: BorderSide(color: palette.surfaceMuted, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: palette.surfaceMuted),
                      ),
                      child: TextField(
                        controller: _textController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleSend,
                        style: TextStyle(fontSize: 14, color: palette.ink),
                        decoration: InputDecoration(
                          hintText: 'Tanya rekomendasi gaya pakaian...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: palette.inkMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: palette.action,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _isThinking
                          ? null
                          : () => _handleSend(_textController.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: palette.onAction,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: palette.action.withValues(alpha: 0.12),
            child: Icon(Icons.auto_awesome, size: 16, color: palette.action),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.sheet,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.surfaceMuted),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(palette.action),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Stylist sedang mencocokkan lemarimu...',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(AppPalette palette, ChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.action,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.action.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: palette.onAction,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // AI Message Bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: palette.action.withValues(alpha: 0.12),
            child: Icon(Icons.auto_awesome, size: 16, color: palette.action),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chat explanation bubble
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.sheet,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: palette.surfaceMuted),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: palette.ink,
                    ),
                  ),
                ),

                // General Advice Card (Fallback when wardrobe items are missing)
                if (message.generalAdvice != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: palette.accentInk,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Panduan Gaya Rekomendasi',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: palette.accentInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message.generalAdvice!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: palette.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Outfit Options Cards
                if (message.options.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...message.options.map(
                    (opt) => _buildOutfitOptionCard(palette, opt),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitOptionCard(
    AppPalette palette,
    StylistOutfitOption option,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.sheet,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.action.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Match Score Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  option.title,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB7E4C7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF1E5631),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${option.matchScore}% Match',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E5631),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Garment Thumbnails Row
          SizedBox(
            height: 94,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: option.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final item = option.items[idx];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WardrobeItemDetailScreen(item: item),
                    ),
                  ),
                  child: Container(
                    width: 76,
                    decoration: BoxDecoration(
                      color: palette.canvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.surfaceMuted),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: double.infinity,
                              child: PlaceholderImage(
                                imagePath: item.imagePath,
                                icon: Icons.checkroom_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 8.5,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Styling justification
          Text(
            option.stylingReason,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: palette.inkMuted,
            ),
          ),

          if (option.tips.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...option.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: palette.action)),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Quick Action Button: Simpan ke Favorit
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              icon: Icon(
                Icons.favorite_border,
                size: 16,
                color: palette.action,
              ),
              label: Text(
                'Simpan ke Favorit',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.action,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.action, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _saveOptionToFavorites(context, option),
            ),
          ),
        ],
      ),
    );
  }
}
