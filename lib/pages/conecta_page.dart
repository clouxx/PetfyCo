import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/image_validator.dart';

class ConectaPage extends StatefulWidget {
  const ConectaPage({super.key});

  @override
  State<ConectaPage> createState() => _ConectaPageState();
}

class _ConectaPageState extends State<ConectaPage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _sb
          .from('posts')
          .select('*, profiles(display_name), post_likes(user_id), post_comments(id)')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() => _posts = List<Map<String, dynamic>>.from(data));
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike(String postId, bool liked) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    if (liked) {
      await _sb.from('post_likes').delete().eq('post_id', postId).eq('user_id', uid);
    } else {
      await _sb.from('post_likes').insert({'post_id': postId, 'user_id': uid});
    }
    await _load();
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CreatePostSheet(onPosted: _load),
    );
  }

  void _openComments(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CommentsSheet(postId: postId, onCommented: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _sb.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Conecta', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Publicar', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.purple,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final p = _posts[i];
                      final likes = (p['post_likes'] as List? ?? []);
                      final liked = likes.any((l) => l['user_id'] == uid);
                      final comments = (p['post_comments'] as List? ?? []);
                      final displayName = (p['profiles'] as Map?)?['display_name'] as String? ?? 'Usuario';
                      final isOwn = p['user_id'] == uid;

                      return _PostCard(
                        post: p,
                        displayName: displayName,
                        liked: liked,
                        likesCount: likes.length,
                        commentsCount: comments.length,
                        isOwn: isOwn,
                        onLike: () => _toggleLike(p['id'], liked),
                        onComment: () => _openComments(p['id']),
                        onDelete: isOwn ? () => _deletePost(p['id']) : null,
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _deletePost(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar publicación'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _sb.from('posts').delete().eq('id', id);
      await _load();
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.people_alt_outlined, size: 48, color: AppColors.purple),
            ),
            const SizedBox(height: 20),
            const Text('¡Sé el primero en publicar!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text('Comparte momentos, consejos y fotos de tus mascotas con la comunidad.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Hacer una publicación', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple, foregroundColor: Colors.white,
                minimumSize: const Size(220, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Post Card ───────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.displayName,
    required this.liked,
    required this.likesCount,
    required this.commentsCount,
    required this.isOwn,
    required this.onLike,
    required this.onComment,
    this.onDelete,
  });

  final Map<String, dynamic> post;
  final String displayName;
  final bool liked, isOwn;
  final int likesCount, commentsCount;
  final VoidCallback onLike, onComment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl = post['image_url'] as String?;
    final content = post['content'] as String? ?? '';
    final createdAt = post['created_at'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.15), shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.purple, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy)),
                      if (createdAt != null)
                        Text(_timeAgo(createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                if (isOwn && onDelete != null)
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'delete') onDelete!(); },
                    icon: Icon(Icons.more_horiz, color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: Row(children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ])),
                    ],
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(content, style: const TextStyle(fontSize: 14, color: AppColors.navy, height: 1.5)),
          ),

          // Image
          if (imageUrl != null) ...[
            ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(0), bottomRight: Radius.circular(0)),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Like
                _actionBtn(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.red : Colors.grey.shade500,
                  label: likesCount > 0 ? '$likesCount' : '',
                  onTap: onLike,
                ),
                const SizedBox(width: 4),
                // Comment
                _actionBtn(
                  icon: Icons.chat_bubble_outline,
                  color: Colors.grey.shade500,
                  label: commentsCount > 0 ? '$commentsCount' : '',
                  onTap: onComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Ahora mismo';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
      if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}

// ─── Create Post Sheet ───────────────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({required this.onPosted});
  final VoidCallback onPosted;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _sb = Supabase.instance.client;
  final _ctrl = TextEditingController();
  File? _image;
  bool _posting = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xf == null) return;

    final bytes = await xf.readAsBytes();
    final validation = validateImageBytes(bytes);
    if (!validation.valid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validation.error!), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _image = File(xf.path));
  }

  Future<void> _post() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _posting = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;

      String? imageUrl;
      if (_image != null) {
        final ext = _image!.path.split('.').last;
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _sb.storage.from('post-images').upload(path, _image!);
        imageUrl = _sb.storage.from('post-images').getPublicUrl(path);
      }

      await _sb.from('posts').insert({
        'user_id': uid,
        'content': _ctrl.text.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onPosted();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Column(
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Nueva publicación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.navy)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), color: AppColors.greyText),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Text input
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _ctrl,
              maxLines: 5,
              minLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '¿Qué quieres compartir con la comunidad?',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 15, color: AppColors.navy, height: 1.5),
            ),
          ),

          // Preview image
          if (_image != null)
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(_image!, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 8, right: 28,
                  child: GestureDetector(
                    onTap: () => setState(() => _image = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

          const Divider(height: 16),

          // Bottom actions
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                // Add photo
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined, color: AppColors.purple, size: 26),
                  tooltip: 'Agregar foto',
                ),
                const Spacer(),
                // Post button
                ElevatedButton(
                  onPressed: _posting ? null : _post,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple, foregroundColor: Colors.white,
                    minimumSize: const Size(110, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _posting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Publicar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comments Sheet ───────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.postId, required this.onCommented});
  final String postId;
  final VoidCallback onCommented;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _sb = Supabase.instance.client;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _sb
          .from('post_comments')
          .select('*, profiles(display_name)')
          .eq('post_id', widget.postId)
          .order('created_at');
      if (mounted) setState(() => _comments = List<Map<String, dynamic>>.from(data));
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;
      await _sb.from('post_comments').insert({
        'post_id': widget.postId,
        'user_id': uid,
        'content': _ctrl.text.trim(),
      });
      _ctrl.clear();
      widget.onCommented();
      await _load();
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // Handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Comentarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.navy)),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Comments list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(child: Text('Sin comentarios aún. ¡Sé el primero!',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final name = (c['profiles'] as Map?)?['display_name'] as String? ?? 'Usuario';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.15), shape: BoxShape.circle),
                                  child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.purple, fontSize: 13))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: AppColors.greyBg, borderRadius: BorderRadius.circular(14)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy)),
                                        const SizedBox(height: 2),
                                        Text(c['content'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.navy, height: 1.4)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Input
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario…',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true, fillColor: AppColors.greyBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _sending ? AppColors.purple.withOpacity(0.5) : AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
