import 'dart:async';

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/story.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/story_service.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storyServiceProvider = Provider<StoryService>(
  (ref) => StoryService(ref.watch(apiClientProvider)),
);

class StoriesScreen extends ConsumerStatefulWidget {
  const StoriesScreen({super.key});

  @override
  ConsumerState<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends ConsumerState<StoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Story> _all = [];
  List<Story> _donor = [];
  List<Story> _recipient = [];
  bool _loading = true;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider).currentUser;
      if (auth != null) {
        _profile = await ref
            .read(userServiceProvider)
            .getProfileByFirebaseUid(auth.uid);
      }
      final svc = ref.read(storyServiceProvider);
      final results = await Future.wait([
        svc.getStories(),
        svc.getStories(role: 'donor'),
        svc.getStories(role: 'recipient'),
      ]);
      if (!mounted) return;
      setState(() {
        _all = results[0];
        _donor = results[1];
        _recipient = results[2];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleLike(Story story) async {
    final nowLiked = !story.isLikedByMe;
    final updated = story.copyWith(
      isLikedByMe: nowLiked,
      likesCount: nowLiked ? story.likesCount + 1 : story.likesCount - 1,
    );
    setState(() {
      _replaceIn(_all, story.id, updated);
      _replaceIn(_donor, story.id, updated);
      _replaceIn(_recipient, story.id, updated);
    });
    await ref.read(storyServiceProvider).toggleLike(story.id);
  }

  void _replaceIn(List<Story> list, String id, Story updated) {
    final idx = list.indexWhere((s) => s.id == id);
    if (idx >= 0) list[idx] = updated;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stories'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Donors'),
            Tab(text: 'Recipients'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Share your story',
            onPressed: () => _openSubmit(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _StoryList(stories: _all, onLike: _toggleLike, onRefresh: _load),
                _StoryList(stories: _donor, onLike: _toggleLike, onRefresh: _load),
                _StoryList(stories: _recipient, onLike: _toggleLike, onRefresh: _load),
              ],
            ),
    );
  }

  Future<void> _openSubmit() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitSheet(profile: _profile),
    );
    if (done == true) _load();
  }
}

// ─── Story list ───────────────────────────────────────────────────────────────
class _StoryList extends StatelessWidget {
  const _StoryList({
    required this.stories,
    required this.onLike,
    required this.onRefresh,
  });
  final List<Story> stories;
  final void Function(Story) onLike;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🩸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No stories yet.\nBe the first to share yours.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }
    final featured = stories.where((s) => s.isFeatured).toList();
    final regular = stories.where((s) => !s.isFeatured).toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          if (featured.isNotEmpty) ...[
            _Label('⭐  Featured'),
            const SizedBox(height: 8),
            ...featured.map((s) => _StoryCard(story: s, onLike: onLike, featured: true)),
            const SizedBox(height: 20),
            _Label('All Stories'),
            const SizedBox(height: 8),
          ],
          ...regular.map((s) => _StoryCard(story: s, onLike: onLike)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );
}

// ─── Story card ───────────────────────────────────────────────────────────────
class _StoryCard extends StatefulWidget {
  const _StoryCard({required this.story, required this.onLike, this.featured = false});
  final Story story;
  final void Function(Story) onLike;
  final bool featured;
  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _heart;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _heart = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heart, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.story;
    final isDonor = s.role == 'donor';
    final roleColor = isDonor ? AppColors.primaryRed : AppColors.success;
    final preview = s.body.length > 180 ? '${s.body.substring(0, 180)}…' : s.body;
    final timeAgo = _ago(s.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: widget.featured
            ? Border.all(color: AppColors.primaryRed.withOpacity(0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [roleColor.withOpacity(0.8), roleColor],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      s.authorBloodType.isEmpty ? '?' : s.authorBloodType,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.authorName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDonor ? '🩸 Donor' : '💙 Recipient',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.featured) const Text('⭐', style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(s.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.3)),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _expanded ? s.body : preview,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ),
          if (s.body.length > 180)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryRed),
                ),
              ),
            ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    widget.onLike(s);
                    _heart.forward(from: 0);
                  },
                  child: AnimatedBuilder(
                    animation: _scale,
                    builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
                    child: Row(
                      children: [
                        Icon(
                          s.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                          color: s.isLikedByMe ? AppColors.primaryRed : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 4),
                        Text('${s.likesCount}',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: s.isLikedByMe ? AppColors.primaryRed : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (s.bloodType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(s.bloodType!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryRed)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 30) return '${dt.day}/${dt.month}/${dt.year}';
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    return 'Just now';
  }
}

// ─── Submit bottom sheet ──────────────────────────────────────────────────────
class _SubmitSheet extends ConsumerStatefulWidget {
  const _SubmitSheet({this.profile});
  final UserProfile? profile;
  @override
  ConsumerState<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends ConsumerState<_SubmitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _role = 'donor';
  bool _submitting = false;
  int _chars = 0;

  @override
  void initState() {
    super.initState();
    if (widget.profile?.role == UserRole.recipient) _role = 'recipient';
    _bodyCtrl.addListener(() => setState(() => _chars = _bodyCtrl.text.length));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(storyServiceProvider).submitStory(
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            role: _role,
            bloodType: widget.profile?.bloodType,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Submitted! Your story will appear after review.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Share your story', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Your story can inspire someone to donate today.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                // Role toggle
                Row(
                  children: [
                    _RoleChip(label: '🩸 I donated', selected: _role == 'donor', onTap: () => setState(() => _role = 'donor')),
                    const SizedBox(width: 10),
                    _RoleChip(label: '💙 I needed blood', selected: _role == 'recipient', onTap: () => setState(() => _role = 'recipient')),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'Give your story a title…', counterText: ''),
                  validator: (v) => (v == null || v.trim().length < 5) ? 'At least 5 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: 'Your story',
                    hintText: 'Tell us what happened…',
                    alignLabelWithHint: true,
                    counterText: '$_chars / 2000',
                  ),
                  validator: (v) => (v == null || v.trim().length < 50) ? 'At least 50 characters' : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AppButton.primary(
                    label: _submitting ? 'Submitting…' : 'Submit Story',
                    onPressed: _submitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryRed.withOpacity(0.1) : AppColors.background,
          border: Border.all(color: selected ? AppColors.primaryRed : AppColors.divider, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryRed : AppColors.textSecondary,
            )),
      ),
    );
  }
}
