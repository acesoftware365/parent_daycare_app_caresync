import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'form_document_pdf.dart';
import 'pdf_web_helper_stub.dart'
    if (dart.library.html) 'pdf_web_helper_web.dart';

const _appVersion = '1.2.43+56';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ParentDaycareApp());
}

class ParentDaycareApp extends StatelessWidget {
  const ParentDaycareApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFDF7F0);
    const surface = Color(0xFFFFFBF7);
    const brand = Color(0xFF2B6E6A);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parent Daycare App',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(
          primary: brand,
          secondary: Color(0xFFEF8A62),
          surface: surface,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE8DDD2)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class UploadedParentFormFile {
  const UploadedParentFormFile({
    required this.url,
    required this.path,
    required this.fileName,
  });

  final String url;
  final String path;
  final String fileName;
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return ParentPortalGate(user: user);
      },
    );
  }
}

class ParentPortalGate extends StatelessWidget {
  const ParentPortalGate({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentContext?>(
      future: ParentRepository().resolveParentContext(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _SimpleStateScaffold(
            title: 'Parent Access Error',
            message:
                'Could not resolve parent profile. Please contact daycare admin.',
            detail: '${snapshot.error}',
            actionLabel: 'Log Out',
            onAction: () => FirebaseAuth.instance.signOut(),
          );
        }

        final contextData = snapshot.data;
        if (contextData == null) {
          return _SimpleStateScaffold(
            title: 'Parent Access Pending',
            message:
                'No parent profile linked to this login yet. Contact daycare admin.',
            detail: user.email ?? user.uid,
            actionLabel: 'Log Out',
            onAction: () => FirebaseAuth.instance.signOut(),
          );
        }

        return ParentHomeShell(user: user, contextData: contextData);
      },
    );
  }
}

class _SimpleStateScaffold extends StatelessWidget {
  const _SimpleStateScaffold({
    required this.title,
    required this.message,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 8),
            Text(detail),
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
      bottomNavigationBar: const _VersionBar(),
    );
  }
}

class ParentHomeShell extends StatefulWidget {
  const ParentHomeShell({
    super.key,
    required this.user,
    required this.contextData,
  });

  final User user;
  final ParentContext contextData;

  @override
  State<ParentHomeShell> createState() => _ParentHomeShellState();
}

class _ParentHomeShellState extends State<ParentHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 900;
    final pages = [
      HomePage(contextData: widget.contextData, uid: widget.user.uid),
      ChildPage(contextData: widget.contextData, uid: widget.user.uid),
      ProfilePage(contextData: widget.contextData, uid: widget.user.uid),
      FormsPage(contextData: widget.contextData, uid: widget.user.uid),
      BillingPage(contextData: widget.contextData),
    ];

    const titles = ['Home', 'Child', 'Profile', 'Form', 'Billing'];

    if (!isWide) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('CareSync Parent App'),
          actions: [
            TextButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: pages[_index],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: List.generate(
                titles.length,
                (i) => NavigationDestination(
                  icon: Icon(_iconFor(i)),
                  label: titles[i],
                ),
              ),
            ),
            const _VersionBar(),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9F2E8), Color(0xFFF4F9F6), Color(0xFFF7F8FC)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                _DesktopNavRail(
                  selectedIndex: _index,
                  titles: titles,
                  iconFor: _iconFor,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _DesktopTopBar(
                        title: titles[_index],
                        onLogout: () => FirebaseAuth.instance.signOut(),
                      ),
                      const SizedBox(height: 20),
                      Expanded(child: pages[_index]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(int i) {
    switch (i) {
      case 0:
        return Icons.home_outlined;
      case 1:
        return Icons.child_friendly_outlined;
      case 2:
        return Icons.person_outline;
      case 3:
        return Icons.description_outlined;
      case 4:
        return Icons.receipt_long_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}

class _DesktopNavRail extends StatelessWidget {
  const _DesktopNavRail({
    required this.selectedIndex,
    required this.titles,
    required this.iconFor,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<String> titles;
  final IconData Function(int index) iconFor;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE6DDD2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDBF1E5), Color(0xFFDDEBFB)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: Center(
                        child: Text('🏫', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CareSync',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: Color(0xFF203241),
                          ),
                        ),
                        Text(
                          'Parent portal',
                          style: TextStyle(color: Color(0xFF637285)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: titles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final selected = index == selectedIndex;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onDestinationSelected(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2B6E6A)
                            : const Color(0xFFF8F7F4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            iconFor(index),
                            color: selected
                                ? Colors.white
                                : const Color(0xFF5C6675),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            titles[index],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const _VersionBar(compact: true),
          ],
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.title, required this.onLogout});

  final String title;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CareSync Parent App',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF708090),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveContentFrame extends StatelessWidget {
  const _ResponsiveContentFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth >= 1280 ? 8.0 : 0.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}

class _ResponsiveTwoColumn extends StatelessWidget {
  const _ResponsiveTwoColumn({
    required this.mainChildren,
    required this.sideChildren,
  });

  final List<Widget> mainChildren;
  final List<Widget> sideChildren;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _ResponsiveContentFrame(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: Column(children: _withSpacing(mainChildren)),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 5,
              child: Column(children: _withSpacing(sideChildren)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(const SizedBox(height: 18));
      }
    }
    return out;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.contextData, required this.uid});

  final ParentContext contextData;
  final String uid;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _eta = 10;
  int _rating = 0;
  final _feedbackCtrl = TextEditingController();
  String? _selectedChildId;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ParentRepository().watchParentDoc(widget.contextData),
      builder: (context, parentSnap) {
        final parent = parentSnap.data?.data() ?? const <String, dynamic>{};
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ParentRepository().watchTenantDoc(widget.contextData.tenantId),
          builder: (context, tenantSnap) {
            final tenantData =
                tenantSnap.data?.data() ?? const <String, dynamic>{};
            final daycareName = _tenantDisplayName(
              tenantData,
              tenantId: widget.contextData.tenantId,
              uppercase: true,
            );

            return StreamBuilder<List<ChildRecordLite>>(
              stream: ParentRepository().watchChildrenForTenant(
                widget.contextData,
              ),
              builder: (context, childSnap) {
                final children = childSnap.data ?? const <ChildRecordLite>[];
                final linkedChildren = children
                    .where((c) => c.parentId == widget.contextData.parentId)
                    .toList();
                final selected = _resolveSelectedChild(linkedChildren);
                final childName = selected?.fullName.isNotEmpty == true
                    ? selected!.fullName
                    : 'Emma Polanco';
                final hero = _homeHero(
                  childName,
                  linkedChildren,
                  selected?.id,
                );
                final etaCard = _homeEtaCard(
                  context,
                  selected,
                  childName,
                  parent,
                );
                final summaryCard = _homeSummaryCard(selected);
                final latestCard = _homeLatestCard(selected);
                final quickActionsCard = _homeQuickActionsCard();
                final feedbackCard = _homeFeedbackCard(context, childName);
                final isWide = MediaQuery.sizeOf(context).width >= 900;

                if (!isWide) {
                  return ListView(
                    children: [
                      _pageTenantHeading(daycareName),
                      const SizedBox(height: 12),
                      hero,
                      const SizedBox(height: 14),
                      etaCard,
                      const SizedBox(height: 14),
                      summaryCard,
                      const SizedBox(height: 14),
                      latestCard,
                      const SizedBox(height: 14),
                      quickActionsCard,
                      const SizedBox(height: 14),
                      feedbackCard,
                    ],
                  );
                }

                return _ResponsiveTwoColumn(
                  mainChildren: [
                    _pageTenantHeading(daycareName),
                    hero,
                    latestCard,
                    feedbackCard,
                  ],
                  sideChildren: [etaCard, summaryCard, quickActionsCard],
                );
              },
            );
          },
        );
      },
    );
  }

  ChildRecordLite? _resolveSelectedChild(List<ChildRecordLite> linkedChildren) {
    if (linkedChildren.isEmpty) return null;
    for (final child in linkedChildren) {
      if (child.id == _selectedChildId) return child;
    }
    if (_selectedChildId != linkedChildren.first.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedChildId = linkedChildren.first.id);
      });
    }
    return linkedChildren.first;
  }

  Widget _homeHero(
    String childName,
    List<ChildRecordLite> linkedChildren,
    String? selectedChildId,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFBEE3FF), Color(0xFFDFF5E6), Color(0xFFF9DDE6)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  childName,
                  style: const TextStyle(
                    fontSize: 43,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2A3D),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Checked in today',
                  style: TextStyle(color: Color(0xFF5E6D79), fontSize: 18),
                ),
                if (linkedChildren.length > 1) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'SELECT CHILD',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5D6B7A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: linkedChildren.map((child) {
                      final fullName = child.fullName.isEmpty
                          ? 'Child'
                          : child.fullName;
                      return ChoiceChip(
                        label: Text(fullName),
                        selected: child.id == selectedChildId,
                        onSelected: (_) {
                          setState(() => _selectedChildId = child.id);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '● Checked In',
                  style: TextStyle(
                    color: Color(0xFF239B5A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text('8:12 AM', style: TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageTenantHeading(String daycareName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        daycareName,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF526171),
        ),
      ),
    );
  }

  Widget _homeEtaCard(
    BuildContext context,
    ChildRecordLite? selectedChild,
    String childName,
    Map<String, dynamic> parent,
  ) {
    final canSend = selectedChild != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCFEAD7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🚗 I'M ON MY WAY",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Color(0xFF355E52),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select arrival time for $childName',
            style: TextStyle(color: Color(0xFF51697A), fontSize: 18),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EtaChoice(
                label: '5 min',
                selected: _eta == 5,
                onTap: () => setState(() => _eta = 5),
              ),
              _EtaChoice(
                label: '10 min',
                selected: _eta == 10,
                onTap: () => setState(() => _eta = 10),
              ),
              _EtaChoice(
                label: '15 min',
                selected: _eta == 15,
                onTap: () => setState(() => _eta = 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2F9965),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: !canSend
                  ? null
                  : () async {
                      try {
                        await ParentRepository().createPickupNotification(
                          contextData: widget.contextData,
                          uid: widget.uid,
                          etaMinutes: _eta,
                          child: selectedChild,
                          parentFirstName: (parent['firstName'] ?? '')
                              .toString(),
                          parentLastName: (parent['lastName'] ?? '').toString(),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'ETA $_eta min sent to daycare for $childName.',
                            ),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not send arrival notice. Try again later.',
                            ),
                          ),
                        );
                      }
                    },
              child: const Text(
                'Send to daycare',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeSummaryCard(ChildRecordLite? child) {
    final childName = child?.fullName.isNotEmpty == true
        ? child!.fullName
        : 'your child';
    if (child == null) {
      return _SectionCard(
        title: 'TODAY SUMMARY',
        child: const Text('No child selected yet.'),
      );
    }

    return _SectionCard(
      title: 'TODAY SUMMARY',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ParentRepository().watchTodaySummary(
          widget.contextData,
          child.id,
        ),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final tags = (data['tags'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
          final dateKey = (data['dateKey'] ?? '').toString();
          final fallbackTags = child.todaySummaryTags;
          final fallbackDateKey = child.todaySummaryDateKey;
          final visibleTags = tags.isNotEmpty ? tags : fallbackTags;
          final visibleDateKey = dateKey.isNotEmpty ? dateKey : fallbackDateKey;
          final isToday = visibleDateKey == ParentRepository.todayDateKey();

          if (!isToday || visibleTags.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Updates for $childName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('No summary has been posted yet for today.'),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Updates for $childName',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: visibleTags
                    .map(
                      (tag) => _SummaryChip(
                        label: _summaryLabel(tag),
                        color: _summaryColor(tag),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _homeLatestCard(ChildRecordLite? child) {
    final childName = child?.fullName.isNotEmpty == true
        ? child!.fullName
        : 'your child';
    if (child == null) {
      return _SectionCard(
        title: 'LATEST UPDATE',
        child: const Text('No child selected yet.'),
      );
    }

    return _SectionCard(
      title: 'LATEST UPDATE',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ParentRepository().watchLatestUpdate(
          widget.contextData,
          child.id,
        ),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final photoUrl = (data['photoUrl'] ?? '').toString().trim().isNotEmpty
              ? (data['photoUrl'] ?? '').toString()
              : child.latestUpdatePhotoUrl;
          final note = (data['note'] ?? '').toString().trim().isNotEmpty
              ? (data['note'] ?? '').toString()
              : child.latestUpdateNote;
          final createdAt =
              ChildRecordLite._asDateTime(data['createdAt']) ??
              child.latestUpdateCreatedAt;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDCEBFB), Color(0xFFF8E2EC)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 240,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    image: photoUrl.trim().isEmpty
                        ? null
                        : DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: photoUrl.trim().isNotEmpty
                      ? null
                      : const Center(
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 38,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$childName latest classroom moment',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  note.trim().isEmpty
                      ? 'No classroom note has been posted yet.'
                      : 'Teacher note: $note',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 18,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Posted ${DateFormat('h:mm a').format(createdAt.toLocal())}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _homeQuickActionsCard() {
    return _SectionCard(
      title: 'QUICK ACTIONS',
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                child: _ActionButtonCard(
                  label: 'Report\nAbsence',
                  bg: Color(0xFFD9EAFA),
                  fg: Color(0xFF335F8A),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ActionButtonCard(
                  label: 'Call Daycare',
                  bg: Color(0xFFF6EAB8),
                  fg: Color(0xFF92601D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _ActionButtonCard(
            label: 'View Forms',
            bg: Color(0xFFE0DCF8),
            fg: Color(0xFF5A43BE),
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _homeFeedbackCard(BuildContext context, String childName) {
    return _SectionCard(
      title: 'DAYCARE FEEDBACK',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate your experience today for $childName',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
          ),
          const SizedBox(height: 4),
          Wrap(
            children: List.generate(5, (i) {
              final value = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = value),
                icon: Icon(
                  value <= _rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFEAB308),
                ),
              );
            }),
          ),
          TextField(
            controller: _feedbackCtrl,
            decoration: InputDecoration(
              hintText: 'Write a comment...',
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Feedback submitted for $childName.')),
                );
              },
              child: const Text(
                'Submit Feedback',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}

String _summaryLabel(String tag) {
  switch (tag) {
    case 'Breakfast':
      return '🍎 Breakfast';
    case 'Nap Time':
      return '😴 Nap Time';
    case 'Outdoor Play':
      return '☀️ Outdoor Play';
    case 'Diaper Change':
      return '🍼 Diaper Change';
    case 'Lunch':
      return '🥪 Lunch';
    case 'Snack':
      return '🍪 Snack';
    default:
      return tag;
  }
}

Color _summaryColor(String tag) {
  switch (tag) {
    case 'Breakfast':
      return const Color(0xFFE7F5EE);
    case 'Nap Time':
      return const Color(0xFFEDEBFA);
    case 'Outdoor Play':
      return const Color(0xFFF7F2E1);
    case 'Diaper Change':
      return const Color(0xFFF7E8EB);
    case 'Lunch':
      return const Color(0xFFE2F0FC);
    case 'Snack':
      return const Color(0xFFFDF0D6);
    default:
      return const Color(0xFFF1F5F9);
  }
}

class _ActionButtonCard extends StatelessWidget {
  const _ActionButtonCard({
    required this.label,
    required this.bg,
    required this.fg,
    this.fullWidth = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 17),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label tapped.'))),
      child: child,
    );
  }
}

class ChildPage extends StatefulWidget {
  const ChildPage({super.key, required this.contextData, required this.uid});

  final ParentContext contextData;
  final String uid;

  @override
  State<ChildPage> createState() => _ChildPageState();
}

class _ChildPageState extends State<ChildPage> {
  bool _requesting = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ParentRepository().watchTenantDoc(widget.contextData.tenantId),
      builder: (context, tenantSnapshot) {
        final tenantData =
            tenantSnapshot.data?.data() ?? const <String, dynamic>{};
        final daycareName = _tenantDisplayName(tenantData, uppercase: true);

        return StreamBuilder<List<ChildRecordLite>>(
          stream: ParentRepository().watchChildrenForTenant(widget.contextData),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _SectionCard(
                title: 'Child',
                child: Text('Read error: ${snapshot.error}'),
              );
            }

            final children = snapshot.data ?? const <ChildRecordLite>[];
            final linked = children
                .where((c) => c.parentId == widget.contextData.parentId)
                .toList();

            final displayChildren = linked.isEmpty
                ? const [
                    _DisplayChild(
                      name: 'Emma Polanco',
                      age: 3,
                      emoji: '👧',
                      tone: 0,
                    ),
                    _DisplayChild(
                      name: 'Lucas Polanco',
                      age: 5,
                      emoji: '👦',
                      tone: 1,
                    ),
                  ]
                : linked
                      .asMap()
                      .entries
                      .map(
                        (entry) => _DisplayChild(
                          name: entry.value.fullName.isEmpty
                              ? 'Child ${entry.key + 1}'
                              : entry.value.fullName,
                          age: entry.value.id.hashCode.abs() % 7 + 2,
                          emoji: entry.key.isEven ? '👧' : '👦',
                          tone: entry.key % 2,
                        ),
                      )
                      .toList();
            final header = _childHeader(daycareName);
            final childCards = displayChildren
                .map((item) => _childCard(item))
                .toList();
            final isWide = MediaQuery.sizeOf(context).width >= 900;

            if (!isWide) {
              return ListView(
                children: [
                  header,
                  const SizedBox(height: 14),
                  ...displayChildren.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _childCard(item),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: _ResponsiveContentFrame(
                child: Column(
                  children: [
                    header,
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.55,
                          ),
                      itemCount: childCards.length,
                      itemBuilder: (context, index) => childCards[index],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _childHeader(String daycareName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD7F3E6), Color(0xFFD9EBFA), Color(0xFFF8DDE5)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daycareName,
                  style: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5B6B78),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Child',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage your children\nprofiles',
                  style: TextStyle(fontSize: 18, color: Color(0xFF5F6E7A)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _requesting ? null : _openChildRequestDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _requesting ? 'Adding...' : 'Add\nChild',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2F9965),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _childCard(_DisplayChild child) {
    final cardTint = child.tone == 0
        ? const Color(0xFFEAF3FD)
        : const Color(0xFFEAF9F1);
    final avatarTint = child.tone == 0
        ? const Color(0xFFD1E8FF)
        : const Color(0xFFD1F3DE);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardTint,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD8E4EE)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: avatarTint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    child.emoji,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF263445),
                      ),
                    ),
                    Text(
                      'Age ${child.age}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDCE3EA)),
                ),
                child: const Text(
                  'Open',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C7381),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: _ChildPill(label: 'Authorized Pickup')),
              SizedBox(width: 8),
              Expanded(child: _ChildPill(label: 'Medical Info')),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(child: _ChildPill(label: 'Attendance')),
              SizedBox(width: 8),
              Expanded(child: _ChildPill(label: 'Forms')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openChildRequestDialog() async {
    final firstController = TextEditingController();
    final lastController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Request Add Child'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: firstController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _requesting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _requesting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => _requesting = true);
                          setDialogState(() => error = null);
                          try {
                            await ParentRepository().createChildRequest(
                              contextData: widget.contextData,
                              uid: widget.uid,
                              firstName: firstController.text,
                              lastName: lastController.text,
                              notes: notesController.text,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Child request submitted.'),
                              ),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() {
                              error =
                                  'Could not submit request. Try again later.';
                            });
                          } finally {
                            if (mounted) setState(() => _requesting = false);
                          }
                        },
                  child: const Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ChildPill extends StatelessWidget {
  const _ChildPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4EC)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF667085),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DisplayChild {
  const _DisplayChild({
    required this.name,
    required this.age,
    required this.emoji,
    required this.tone,
  });

  final String name;
  final int age;
  final String emoji;
  final int tone;
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.contextData, required this.uid});

  final ParentContext contextData;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ParentRepository().watchTenantDoc(contextData.tenantId),
      builder: (context, tenantSnapshot) {
        final tenantData =
            tenantSnapshot.data?.data() ?? const <String, dynamic>{};
        final daycareName = _tenantDisplayName(tenantData, uppercase: true);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ParentRepository().watchParentDoc(contextData),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final firstName = (data['firstName'] ?? '').toString();
            final lastName = (data['lastName'] ?? '').toString();
            final fullName = '$firstName $lastName'.trim().isEmpty
                ? 'Juan Polanco'
                : '$firstName $lastName'.trim();
            final phone = (data['phone'] ?? '(203) 555-0184').toString();
            final email = (data['email'] ?? 'juan@email.com').toString();
            final header = _profileHeader(daycareName);
            final summary = _profileSummary(fullName, phone, email);
            final pickups = _profileGroup(
              title: 'AUTHORIZED PICKUP',
              trailing: const _TinyGreenPill(label: 'Add'),
              child: const Column(
            children: [
              _SoftListRow(
                text: 'Juan Polanco · Father',
                color: Color(0xFFDDEAF6),
              ),
              SizedBox(height: 10),
              _SoftListRow(
                text: 'Maria Polanco · Mother',
                color: Color(0xFFDFF2EA),
              ),
              SizedBox(height: 10),
              _SoftListRow(
                text: 'Rosa Polanco · Grandmother',
                color: Color(0xFFF4F0DE),
              ),
            ],
          ),
        );
            final emergency = _profileGroup(
              title: 'EMERGENCY CONTACTS',
              child: const Column(
            children: [
              _EmergencyCard(
                title: 'Emergency Contact 1',
                value: 'Maria Polanco · (203) 555-0140',
                color: Color(0xFFF4E7EB),
              ),
              SizedBox(height: 10),
              _EmergencyCard(
                title: 'Emergency Contact 2',
                value: 'Rosa Polanco · (203) 555-0162',
                color: Color(0xFFEAE6F9),
              ),
            ],
          ),
        );
            final isWide = MediaQuery.sizeOf(context).width >= 900;

            if (!isWide) {
              return ListView(
                children: [
                  header,
                  const SizedBox(height: 14),
                  summary,
                  const SizedBox(height: 14),
                  pickups,
                  const SizedBox(height: 14),
                  emergency,
                ],
              );
            }

            return _ResponsiveTwoColumn(
              mainChildren: [header, summary],
              sideChildren: [pickups, emergency],
            );
          },
        );
      },
    );
  }

  Widget _profileHeader(String daycareName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8DDE5), Color(0xFFD2EBFF), Color(0xFFD6F3E0)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Center(child: Text('👥', style: TextStyle(fontSize: 28))),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daycareName,
                  style: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF657384),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Parent information and\npickup details',
                  style: TextStyle(fontSize: 16, color: Color(0xFF607080)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSummary(String fullName, String phone, String email) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4E9FC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Color(0xFF5A6B7A), size: 30),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFF2B3442),
                      ),
                    ),
                    const Text(
                      'Father · Primary\naccount',
                      style: TextStyle(fontSize: 15, color: Color(0xFF67758A)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFF3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6C7482),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _profileInfoCell(label: 'Phone:', value: phone),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _profileInfoCell(label: 'Email:', value: email),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileInfoCell({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF5E6B7A), fontSize: 14),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _profileGroup({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF3C4A5B),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TinyGreenPill extends StatelessWidget {
  const _TinyGreenPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFCFF4DD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2F9965),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SoftListRow extends StatelessWidget {
  const _SoftListRow({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4A5766),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3D4A59),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Color(0xFF596678))),
        ],
      ),
    );
  }
}

class FormsPage extends StatefulWidget {
  const FormsPage({super.key, required this.contextData, required this.uid});

  final ParentContext contextData;
  final String uid;

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> {
  final _signName = TextEditingController();
  List<Offset?> _signaturePoints = <Offset?>[];
  bool _accepted = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _signName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ParentRepository().watchTenantDoc(widget.contextData.tenantId),
      builder: (context, tenantSnapshot) {
        final tenantData =
            tenantSnapshot.data?.data() ?? const <String, dynamic>{};
        final daycareName = _tenantDisplayName(tenantData, uppercase: true);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ParentRepository().watchParentDoc(widget.contextData),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final contract =
                (data['parentContract'] as Map<String, dynamic>?) ??
                const <String, dynamic>{};
        final contractAccepted = contract['accepted'] == true;
        final contractSignedName = (contract['signedName'] ?? '')
            .toString()
            .trim();
        final contractSignaturePoints = _decodeSignaturePoints(
          contract['signaturePoints'] as List<dynamic>?,
        );

        if (!_initialized ||
            (contractAccepted &&
                contractSignedName.isNotEmpty &&
                contractSignaturePoints.any((point) => point != null) &&
                (_accepted != contractAccepted ||
                    _signName.text.trim() != contractSignedName ||
                    _encodeSignaturePoints(_signaturePoints).join('|') !=
                        _encodeSignaturePoints(contractSignaturePoints).join(
                          '|',
                        )))) {
          _accepted = contractAccepted;
          _signName.text = contractSignedName;
          _signaturePoints = contractSignaturePoints;
          _initialized = true;
        }
            return StreamBuilder<List<ChildRecordLite>>(
              stream: ParentRepository().watchChildrenForTenant(
                widget.contextData,
              ),
              builder: (context, childSnapshot) {
                final children = childSnapshot.data ?? const <ChildRecordLite>[];
                final linkedChildren = children
                    .where((c) => c.parentId == widget.contextData.parentId)
                    .toList();

                final header = _formsHeader(daycareName);
                final addSignature = Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3FB37B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saving
                        ? null
                        : () => _openSignatureDialog(data),
                    child: const Text(
                      'Save Signature',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saving
                        ? null
                        : () => _openSavedContractSignatureViewer(data),
                    child: const Text(
                      'View Saved Signature',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
                final photoPermission = _photoPermissionCard(
                  data,
                  linkedChildren,
                );
                final pending = _formsPendingCard(data, linkedChildren);
                final docs = _formsDocsCard();
                final isWide = MediaQuery.sizeOf(context).width >= 900;

                if (!isWide) {
                  return ListView(
                    children: [
                      header,
                      const SizedBox(height: 14),
                      addSignature,
                      const SizedBox(height: 14),
                      photoPermission,
                      const SizedBox(height: 14),
                      pending,
                      const SizedBox(height: 14),
                      docs,
                    ],
                  );
                }

                return _ResponsiveTwoColumn(
                  mainChildren: [header, photoPermission, docs],
                  sideChildren: [addSignature, pending],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _formsHeader(String daycareName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCD9F6), Color(0xFFD2EFE0)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Center(child: Text('📄', style: TextStyle(fontSize: 28))),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daycareName,
                  style: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF657384),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Forms',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Registration and normal\ndaycare documents',
                  style: TextStyle(fontSize: 16, color: Color(0xFF607080)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formsPendingCard(
    Map<String, dynamic> parentData,
    List<ChildRecordLite> linkedChildren,
  ) {
    final pendingCount = _accepted ? 0 : 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PENDING SIGNATURE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF3C4A5B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8E7B5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$pendingCount Pending',
                  style: const TextStyle(
                    color: Color(0xFF9B6A21),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PendingSignCard(
            title: 'Daycare Contract',
            subtitle: 'General daycare terms and parent agreement',
            color: const Color(0xFFF8F3DF),
            onSign: _saving ? null : () => _openSignatureDialog(parentData),
            onView: _saving
                ? null
                : () => _openSavedContractSignatureViewer(parentData),
          ),
        ],
      ),
    );
  }

  Widget _formsDocsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MAIN DOCUMENTS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF3C4A5B),
            ),
          ),
          SizedBox(height: 12),
          _FormsDocRow(text: 'Daycare Contract', color: Color(0xFFDCE8F4)),
          SizedBox(height: 10),
          _FormsDocRow(text: 'Child Registration', color: Color(0xFFDFF2EA)),
          SizedBox(height: 10),
          _FormsDocRow(
            text: 'Photo & Media Permission',
            color: Color(0xFFF4E4EC),
          ),
          SizedBox(height: 10),
          _FormsDocRow(
            text: 'Emergency Contact Form',
            color: Color(0xFFE9E7F8),
          ),
          SizedBox(height: 10),
          _FormsDocRow(text: 'Medical Information', color: Color(0xFFF4F0DE)),
        ],
      ),
    );
  }

  Future<void> _openSignatureDialog(Map<String, dynamic> parentData) async {
    final nameCtrl = TextEditingController(text: _signName.text);
    var acceptedLocal = _accepted;
    var pointsLocal = <Offset?>[..._signaturePoints];
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add Signature'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      value: acceptedLocal,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('I accept the contract terms'),
                      onChanged: (v) => setDialogState(() => acceptedLocal = v),
                    ),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Signature Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Sign with your finger'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              setDialogState(() => pointsLocal = <Offset?>[]),
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                    SignaturePad(
                      points: pointsLocal,
                      onChanged: (next) =>
                          setDialogState(() => pointsLocal = next),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final trimmedName = nameCtrl.text.trim();
                          final signatureCaptured = pointsLocal.any(
                            (p) => p != null,
                          );
                          if (!acceptedLocal) {
                            setDialogState(() {
                              errorText =
                                  'You need to accept the contract terms before saving.';
                            });
                            return;
                          }
                          if (trimmedName.isEmpty) {
                            setDialogState(() {
                              errorText =
                                  'Enter the parent signature name before saving.';
                            });
                            return;
                          }
                          if (!signatureCaptured) {
                            setDialogState(() {
                              errorText =
                                  'Draw the signature before saving the contract.';
                            });
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          setDialogState(() => errorText = null);
                          setState(() => _saving = true);
                          try {
                            await ParentRepository()
                                .saveParentContractSignature(
                                  contextData: widget.contextData,
                                  uid: widget.uid,
                                  accepted: acceptedLocal,
                                  signedName: trimmedName,
                                  signaturePoints: _encodeSignaturePoints(
                                    pointsLocal,
                                  ),
                                  signatureCaptured: signatureCaptured,
                                );
                            if (!mounted) return;
                            setState(() {
                              _accepted = acceptedLocal;
                              _signName.text = trimmedName;
                              _signaturePoints = pointsLocal;
                            });
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Contract signature saved.'),
                              ),
                            );
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                errorText = 'Could not save the signature. $e';
                              });
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _saving = false);
                            }
                          }
                        },
                  child: const Text('Save Signature'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSavedContractSignatureViewer(
    Map<String, dynamic> data,
  ) async {
    Map<String, dynamic> resolvedData = data;
    var usedFallback = false;
    try {
      final latestData = await ParentRepository().loadParentDoc(
        widget.contextData,
      );
      if (latestData.isNotEmpty) {
        resolvedData = latestData;
      } else {
        usedFallback = true;
      }
    } catch (_) {
      usedFallback = true;
    }
    final fallbackContract = <String, dynamic>{
      'accepted': _accepted,
      'signedName': _signName.text.trim(),
      'signaturePoints': _encodeSignaturePoints(_signaturePoints),
    };
    final contract =
        (resolvedData['parentContract'] as Map<String, dynamic>?) ??
        fallbackContract;
    final parentName =
        '${(resolvedData['firstName'] ?? '').toString()} ${(resolvedData['lastName'] ?? '').toString()}'
            .trim();
    final parentEmail = (resolvedData['email'] ?? '').toString();
    final parentPhone = (resolvedData['phone'] ?? '').toString();
    final addressParts = [
      (resolvedData['addressLine1'] ?? '').toString(),
      (resolvedData['city'] ?? '').toString(),
      (resolvedData['state'] ?? '').toString(),
      (resolvedData['zip'] ?? '').toString(),
    ].where((part) => part.trim().isNotEmpty).toList();
    final address = addressParts.join(', ');
    final signedAt = ChildRecordLite._asDateTime(contract['signedAt']);
    final signaturePoints = _decodeSignaturePoints(
      (contract['signaturePoints'] as List<dynamic>?) ??
          fallbackContract['signaturePoints'] as List<dynamic>?,
    );
    final resolvedSignedName = (contract['signedName'] ?? '')
        .toString()
        .trim()
        .isEmpty
        ? _signName.text.trim()
        : (contract['signedName'] ?? '').toString().trim();
    final resolvedAccepted =
        contract['accepted'] == true || (_accepted && usedFallback);

    if (!mounted) return;
    if (usedFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using current screen data for saved signature view.'),
        ),
      );
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Daycare Contract',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD8E2EC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DocInfoRow(
                          title: 'Parent Name',
                          value: parentName.isEmpty ? '-' : parentName,
                        ),
                        _DocInfoRow(
                          title: 'Email',
                          value: parentEmail.isEmpty ? '-' : parentEmail,
                        ),
                        _DocInfoRow(
                          title: 'Phone',
                          value: parentPhone.isEmpty ? '-' : parentPhone,
                        ),
                        _DocInfoRow(
                          title: 'Address',
                          value: address.isEmpty ? '-' : address,
                        ),
                        _DocInfoRow(
                          title: 'Signed Name',
                          value: resolvedSignedName.isEmpty
                              ? '-'
                              : resolvedSignedName,
                        ),
                        _DocInfoRow(
                          title: 'Status',
                          value: resolvedAccepted ? 'Signed' : 'Pending',
                        ),
                        _DocInfoRow(
                          title: 'Signed At',
                          value: signedAt == null
                              ? '-'
                              : DateFormat('M/d/y h:mm a').format(signedAt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Saved Signature',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    child: Opacity(
                      opacity: 0.95,
                      child: SignaturePad(
                        points: signaturePoints,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                  if (!signaturePoints.any((point) => point != null)) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'No saved signature found yet.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _photoPermissionCard(
    Map<String, dynamic> parentData,
    List<ChildRecordLite> linkedChildren,
  ) {
    final parentName =
        '${(parentData['firstName'] ?? '').toString()} ${(parentData['lastName'] ?? '').toString()}'
            .trim();
    final parentEmail = (parentData['email'] ?? '').toString();
    final parentPhone = (parentData['phone'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PHOTO & MEDIA PERMISSION',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF3C4A5B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            parentName.isEmpty ? 'Parent profile' : parentName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          if (parentEmail.isNotEmpty || parentPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                parentEmail,
                parentPhone,
              ].where((value) => value.trim().isNotEmpty).join(' • '),
              style: const TextStyle(color: Color(0xFF607080)),
            ),
          ],
          const SizedBox(height: 12),
          if (linkedChildren.isEmpty)
            const Text('No linked children found for photo permissions yet.')
          else
            ...linkedChildren.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PhotoPermissionChildCard(
                  child: child,
                  onSign: _saving
                      ? null
                      : () => _signPhotoPermissionWithSavedSignature(
                          data: parentData,
                          child: child,
                        ),
                  onView: () => _openPhotoPermissionViewer(
                    data: parentData,
                    child: child,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _signPhotoPermissionWithSavedSignature({
    required Map<String, dynamic> data,
    required ChildRecordLite child,
  }) async {
    await _openPhotoPermissionDocumentFlow(
      data: data,
      child: child,
      action: _PhotoPermissionAction.sign,
    );
  }

  Future<void> _openPhotoPermissionViewer({
    required Map<String, dynamic> data,
    required ChildRecordLite child,
  }) async {
    await _openPhotoPermissionDocumentFlow(
      data: data,
      child: child,
      action: _PhotoPermissionAction.view,
    );
  }

  Future<void> _openPhotoPermissionDocumentFlow({
    required Map<String, dynamic> data,
    required ChildRecordLite child,
    required _PhotoPermissionAction action,
  }) async {
    final repo = ParentRepository();
    Map<String, dynamic> parentData = data;
    Map<String, dynamic> tenantData = const <String, dynamic>{};
    Map<String, dynamic> existingPermission = const <String, dynamic>{};

    try {
      final latestParent = await repo.loadParentDoc(widget.contextData);
      if (latestParent.isNotEmpty) {
        parentData = latestParent;
      }
    } catch (_) {}
    try {
      tenantData = await repo.loadTenantDoc(widget.contextData.tenantId);
    } catch (_) {}
    try {
      existingPermission = await repo.loadPhotoPermissionDocument(
        contextData: widget.contextData,
        childId: child.id,
      );
    } catch (_) {}

    final contract =
        (parentData['parentContract'] as Map<String, dynamic>?) ??
        <String, dynamic>{
          'accepted': _accepted,
          'signedName': _signName.text.trim(),
          'signaturePoints': _encodeSignaturePoints(_signaturePoints),
          'signatureCaptured': _signaturePoints.any((point) => point != null),
        };
    final signedName = (contract['signedName'] ?? '').toString().trim();
    final signatureCaptured =
        contract['signatureCaptured'] == true ||
        _signaturePoints.any((point) => point != null);
    final signaturePoints = _decodeSignaturePoints(
      contract['signaturePoints'] as List<dynamic>?,
    );
    final contractAccepted = contract['accepted'] == true || _accepted;
    final parentName =
        '${(parentData['firstName'] ?? '').toString()} ${(parentData['lastName'] ?? '').toString()}'
            .trim();
    final daycareName = _resolveDaycareName(tenantData);
    final daycareAddress = _resolveDaycareAddress(tenantData);
    final daycarePhone = _resolveDaycarePhone(tenantData);
    final childDobText = _formatDateOnly(child.dateOfBirth);

    if (!mounted) return;
    final hasSavedSignature =
        contractAccepted &&
        signatureCaptured &&
        signedName.isNotEmpty &&
        signaturePoints.any((point) => point != null);
    if (!hasSavedSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use Save Signature first. That saved signature will be reused for this document.',
          ),
        ),
      );
      return;
    }

    var language = (existingPermission['documentLanguage'] ?? 'en')
        .toString()
        .trim()
        .toLowerCase();
    if (language != 'es') {
      language = 'en';
    }
    bool? internalApproved;
    bool? publicApproved;
    if (existingPermission.containsKey('internalCommunicationApproved')) {
      internalApproved = existingPermission['internalCommunicationApproved'] == true;
    }
    if (existingPermission.containsKey('publicWebsiteApproved')) {
      publicApproved = existingPermission['publicWebsiteApproved'] == true;
    }
    final documentCompleted = _isCompletedPhotoPermission(existingPermission);
    if (documentCompleted) {
      final selectedLanguage = await _promptForDocumentLanguage(
        initialLanguage: language,
      );
      if (selectedLanguage == null || !mounted) return;
      if (!mounted) return;
      await _openSavedPhotoPermissionDocumentPreview(
        payload: {
          ...existingPermission,
          'documentLanguage': selectedLanguage,
          'daycareName': daycareName,
          'daycareAddress': daycareAddress,
          'daycarePhone': daycarePhone,
          'childName': child.fullName.isEmpty ? 'Child' : child.fullName,
          'childDateOfBirthText':
              (existingPermission['childDateOfBirthText'] ?? childDobText)
                  .toString(),
          'parentName': parentName.isEmpty ? signedName : parentName,
        },
        child: child,
        fallbackParentName: parentName.isEmpty ? signedName : parentName,
      );
      return;
    }
    if (action == _PhotoPermissionAction.view) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fill this document once with Sign Document. After that, View Document will open it directly.',
          ),
        ),
      );
      return;
    }
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.fullName.isEmpty
                              ? 'Photo & Media Permission'
                              : '${child.fullName} Photo & Media Permission',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose the language and answer the YES/NO questions to fill the printable document.',
                          style: TextStyle(color: Color(0xFF5B6675)),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Document Language',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'en',
                              label: Text('English'),
                            ),
                            ButtonSegment<String>(
                              value: 'es',
                              label: Text('Español'),
                            ),
                          ],
                          selected: {language},
                          onSelectionChanged: (selection) {
                            setDialogState(() => language = selection.first);
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildPermissionQuestion(
                          title: language == 'es'
                              ? '1. Comunicación Interna'
                              : '1. Internal Communication',
                          description: language == 'es'
                              ? 'Permitir fotos/videos en actividades diarias y compartirlas con los padres dentro del programa.'
                              : 'Allow photos/videos during daily activities and share them with parents inside the program.',
                          value: internalApproved,
                          onChanged: (value) =>
                              setDialogState(() => internalApproved = value),
                          yesLabel: language == 'es' ? 'Sí' : 'Yes',
                          noLabel: language == 'es' ? 'No' : 'No',
                        ),
                        const SizedBox(height: 14),
                        _buildPermissionQuestion(
                          title: language == 'es'
                              ? '2. Redes Sociales y Página Web Pública'
                              : '2. Social Media & Public Website',
                          description: language == 'es'
                              ? 'Permitir uso promocional y comunitario en redes sociales y página web pública.'
                              : 'Allow promotional and community use on social media and the public website.',
                          value: publicApproved,
                          onChanged: (value) =>
                              setDialogState(() => publicApproved = value),
                          yesLabel: language == 'es' ? 'Sí' : 'Yes',
                          noLabel: language == 'es' ? 'No' : 'No',
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorText!,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      if (internalApproved == null ||
                                          publicApproved == null) {
                                        setDialogState(() {
                                          errorText =
                                              'Answer both YES/NO questions before continuing.';
                                        });
                                        return;
                                      }
                                      setDialogState(() => errorText = null);
                                      setState(() => _saving = true);
                                      try {
                                        await repo.savePhotoPermissionDocument(
                                          contextData: widget.contextData,
                                          uid: widget.uid,
                                          child: child,
                                          parentData: parentData,
                                          consentGranted: true,
                                          documentLanguage: language,
                                          internalCommunicationApproved:
                                              internalApproved!,
                                          publicWebsiteApproved:
                                              publicApproved!,
                                          daycareName: daycareName,
                                          daycareAddress: daycareAddress,
                                          daycarePhone: daycarePhone,
                                          childDateOfBirthText: childDobText,
                                          signedName: signedName,
                                          signaturePoints: _encodeSignaturePoints(
                                            signaturePoints,
                                          ),
                                          signatureCaptured: true,
                                        );
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                        if (!mounted) return;
                                        await _openSavedPhotoPermissionDocumentPreview(
                                          payload: {
                                            ...existingPermission,
                                            'documentCompleted': true,
                                            'documentLanguage': language,
                                            'daycareName': daycareName,
                                            'daycareAddress': daycareAddress,
                                            'daycarePhone': daycarePhone,
                                            'childName': child.fullName.isEmpty
                                                ? 'Child'
                                                : child.fullName,
                                            'childDateOfBirthText': childDobText,
                                            'parentName': parentName.isEmpty
                                                ? signedName
                                                : parentName,
                                            'internalCommunicationApproved':
                                                internalApproved,
                                            'publicWebsiteApproved':
                                                publicApproved,
                                            'signedName': signedName,
                                            'signedAt': DateTime.now(),
                                            'signaturePoints':
                                                _encodeSignaturePoints(
                                                  signaturePoints,
                                                ),
                                          },
                                          child: child,
                                          fallbackParentName:
                                              parentName.isEmpty
                                              ? signedName
                                              : parentName,
                                        );
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          setDialogState(() {
                                            errorText =
                                                'Could not prepare the document. $e';
                                          });
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _saving = false);
                                        }
                                      }
                                    },
                              child: Text(
                                language == 'es'
                                    ? 'Generar Documento'
                                    : 'Generate Document',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isCompletedPhotoPermission(Map<String, dynamic> payload) {
    if (payload['documentCompleted'] == true) return true;
    return payload['documentLanguage'] != null &&
        payload.containsKey('internalCommunicationApproved') &&
        payload.containsKey('publicWebsiteApproved') &&
        payload['signedName'] != null &&
        ((payload['signaturePoints'] as List<dynamic>?)?.isNotEmpty ?? false);
  }

  Future<String?> _promptForDocumentLanguage({
    required String initialLanguage,
  }) async {
    var selected = initialLanguage == 'es' ? 'es' : 'en';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Document Language'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose the language for this document view.'),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'en',
                        label: Text('English'),
                      ),
                      ButtonSegment<String>(
                        value: 'es',
                        label: Text('Español'),
                      ),
                    ],
                    selected: {selected},
                    onSelectionChanged: (selection) {
                      setDialogState(() => selected = selection.first);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selected),
                  child: const Text('Open Document'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSavedPhotoPermissionDocumentPreview({
    required Map<String, dynamic> payload,
    required ChildRecordLite child,
    required String fallbackParentName,
  }) async {
    final language = (payload['documentLanguage'] ?? 'en').toString();
    final childName = (payload['childName'] ?? '').toString().trim().isEmpty
        ? (child.fullName.isEmpty ? 'Child' : child.fullName)
        : (payload['childName'] ?? '').toString();
    final parentGuardianName =
        (payload['parentName'] ?? payload['parentGuardianName'] ?? '')
            .toString()
            .trim()
            .isEmpty
        ? fallbackParentName
        : (payload['parentName'] ?? payload['parentGuardianName'] ?? '')
              .toString();
    final bytes = await FormPdfBuilder.buildPhotoPermissionPdf(
      languageCode: language,
      daycareName: (payload['daycareName'] ?? '').toString(),
      daycareAddress: (payload['daycareAddress'] ?? '').toString(),
      daycarePhone: (payload['daycarePhone'] ?? '').toString(),
      childName: childName,
      childDateOfBirthText: (payload['childDateOfBirthText'] ?? '-')
          .toString(),
      parentGuardianName: parentGuardianName,
      internalCommunicationApproved:
          payload['internalCommunicationApproved'] == true,
      publicWebsiteApproved: payload['publicWebsiteApproved'] == true,
      signedName: (payload['signedName'] ?? '').toString(),
      signedAt: ChildRecordLite._asDateTime(payload['signedAt']),
      signaturePoints:
          (payload['signaturePoints'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
    if (!mounted) return;
    final fileName =
        '${childName.replaceAll(' ', '_').toLowerCase()}_photo_permission.pdf';
    if (kIsWeb) {
      final opened = await openPdfInNewTab(bytes, fileName);
      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The browser blocked the document tab. Try allowing pop-ups and open the document again.',
            ),
          ),
        );
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                childName.isEmpty
                    ? 'Photo & Media Permission'
                    : '$childName Photo & Media Permission',
              ),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    await Printing.layoutPdf(
                      name: fileName,
                      onLayout: (_) async => bytes,
                    );
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                ),
                IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            body: Container(
              color: const Color(0xFFF4F1EB),
              child: PdfPreview(
                build: (_) async => bytes,
                allowPrinting: false,
                allowSharing: false,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                maxPageWidth: 760,
              ),
            ),
          ),
        );
      },
    );
  }

  String _resolveDaycareName(Map<String, dynamic> tenantData) {
    return (tenantData['daycareName'] ??
            tenantData['businessName'] ??
            tenantData['name'] ??
            '')
        .toString()
        .trim();
  }

  String _resolveDaycareAddress(Map<String, dynamic> tenantData) {
    return [
      (tenantData['addressHouseNumber'] ?? '').toString(),
      (tenantData['addressStreet'] ?? '').toString(),
      (tenantData['addressCity'] ?? '').toString(),
      (tenantData['addressState'] ?? '').toString(),
      (tenantData['addressZip'] ?? '').toString(),
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }

  String _resolveDaycarePhone(Map<String, dynamic> tenantData) {
    final area = (tenantData['phoneAreaCode'] ?? '').toString().trim();
    final number =
        (tenantData['phoneNumber'] ?? tenantData['phone'] ?? '')
            .toString()
            .trim();
    if (area.isEmpty) return number;
    if (number.isEmpty) return area;
    return '($area) $number';
  }

  String _formatDateOnly(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('M/d/y').format(value);
  }

  Widget _buildPermissionQuestion({
    required String title,
    required String description,
    required bool? value,
    required ValueChanged<bool> onChanged,
    required String yesLabel,
    required String noLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF5B6675), height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: Text(yesLabel),
                selected: value == true,
                onSelected: (_) => onChanged(true),
              ),
              ChoiceChip(
                label: Text(noLabel),
                selected: value == false,
                onSelected: (_) => onChanged(false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _encodeSignaturePoints(List<Offset?> points) {
    return points
        .map(
          (p) => p == null
              ? 'BREAK'
              : '${p.dx.toStringAsFixed(2)},${p.dy.toStringAsFixed(2)}',
        )
        .toList();
  }

  List<Offset?> _decodeSignaturePoints(List<dynamic>? raw) {
    if (raw == null) return <Offset?>[];
    final out = <Offset?>[];
    for (final item in raw) {
      if (item is String) {
        if (item == 'BREAK') {
          out.add(null);
          continue;
        }
        final parts = item.split(',');
        if (parts.length != 2) continue;
        final x = double.tryParse(parts[0]);
        final y = double.tryParse(parts[1]);
        if (x != null && y != null) {
          out.add(Offset(x, y));
        }
        continue;
      }
      if (item is Map) {
        final hasBreak = item['break'];
        if (hasBreak == 1 || hasBreak == true) {
          out.add(null);
          continue;
        }
        final x = item['x'];
        final y = item['y'];
        if (x == null || y == null) {
          out.add(null);
          continue;
        }
        if (x is num && y is num) {
          out.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
    return out;
  }
}

class _PendingSignCard extends StatelessWidget {
  const _PendingSignCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onSign,
    required this.onView,
  });

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onSign;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3D4A59),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF63748A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onSign,
                  child: const Text('Sign Document'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onView,
                  child: const Text('View Document'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoPermissionChildCard extends StatelessWidget {
  const _PhotoPermissionChildCard({
    required this.child,
    required this.onSign,
    required this.onView,
  });

  final ChildRecordLite child;
  final VoidCallback? onSign;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final signed = child.photoPermissionSigned;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: signed ? const Color(0xFFE7F6ED) : const Color(0xFFF7ECF0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName.isEmpty
                          ? 'Child Photo and Media Permission'
                          : '${child.fullName} Photo and Media Permission',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3D4A59),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signed
                          ? 'Permission signed'
                          : 'Permission still needs a signature',
                      style: const TextStyle(color: Color(0xFF63748A)),
                    ),
                    if (signed && child.photoPermissionSignedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Signed on ${_formatShortDate(child.photoPermissionSignedAt!)}',
                        style: const TextStyle(color: Color(0xFF63748A)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onSign,
                  child: const Text('Sign Document'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onView,
                  child: const Text('View Document'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocInfoRow extends StatelessWidget {
  const _DocInfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF5F6E7A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatShortDate(DateTime value) {
  return '${value.month}/${value.day}/${value.year}';
}

String _tenantDisplayName(
  Map<String, dynamic> tenantData, {
  String? tenantId,
  bool uppercase = false,
}) {
  final value =
      (tenantData['daycareName'] ??
              tenantData['businessName'] ??
              tenantData['name'] ??
              _humanizeTenantId(tenantId) ??
              'DAYCARE')
          .toString()
          .trim();
  return uppercase ? value.toUpperCase() : value;
}

String? _humanizeTenantId(String? tenantId) {
  final raw = (tenantId ?? '').trim();
  if (raw.isEmpty) return null;
  return raw
      .split('-')
      .where((part) => part.trim().isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        if (lower.length == 1) return lower.toUpperCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

class _FormsDocRow extends StatelessWidget {
  const _FormsDocRow({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4B5A6B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class BillingPage extends StatelessWidget {
  const BillingPage({super.key, required this.contextData});

  final ParentContext contextData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ParentRepository().watchTenantDoc(contextData.tenantId),
      builder: (context, tenantSnapshot) {
        final tenantData =
            tenantSnapshot.data?.data() ?? const <String, dynamic>{};
        final daycareName = _tenantDisplayName(tenantData, uppercase: true);

        final header = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD7F3E6), Color(0xFFD9EBFA), Color(0xFFF8E2B9)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Center(child: Text('💳', style: TextStyle(fontSize: 26))),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daycareName,
                  style: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF607080),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Billing',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Tuition, invoices, receipts, and\npayment methods',
                  style: TextStyle(fontSize: 16, color: Color(0xFF607080)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
        final balanceCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7EF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBE8D7)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT BALANCE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF2F7D64),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  r'$325.00',
                  style: TextStyle(
                    fontSize: 44,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Due on March 15',
                  style: TextStyle(color: Color(0xFF607080)),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F9965),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            onPressed: () {},
            child: const Text(
              'Pay Now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
        final upcomingCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'UPCOMING INVOICE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF3C4A5B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8E7B5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    color: Color(0xFF9B6A21),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F3DF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Tuition',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF344155),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Invoice #1048 · March 10 -\nMarch 14',
                        style: TextStyle(color: Color(0xFF607080)),
                      ),
                    ],
                  ),
                ),
                Text(
                  r'$325.00',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
        final paymentMethodsCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT METHODS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF3C4A5B),
            ),
          ),
          SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFDCE8F4),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Visa ending in 4242 · Default\npayment method',
                style: TextStyle(
                  color: Color(0xFF455569),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
        final isWide = MediaQuery.sizeOf(context).width >= 900;

        if (!isWide) {
          return ListView(
            children: [
              const _DisplayOnlyBanner(),
              const SizedBox(height: 12),
              header,
              const SizedBox(height: 14),
              balanceCard,
              const SizedBox(height: 14),
              upcomingCard,
              const SizedBox(height: 14),
              paymentMethodsCard,
            ],
          );
        }

        return _ResponsiveTwoColumn(
          mainChildren: [const _DisplayOnlyBanner(), header, upcomingCard],
          sideChildren: [balanceCard, paymentMethodsCard],
        );
      },
    );
  }
}

class _DisplayOnlyBanner extends StatelessWidget {
  const _DisplayOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9CC79)),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF8A5B00)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Display only: demo UI. Real data/actions will be connected later.',
              style: TextStyle(
                color: Color(0xFF7A4B00),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _EtaChoice extends StatelessWidget {
  const _EtaChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class SignaturePad extends StatelessWidget {
  const SignaturePad({
    super.key,
    required this.points,
    required this.onChanged,
  });

  final List<Offset?> points;
  final ValueChanged<List<Offset?>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: GestureDetector(
        onPanStart: (d) => _addPoint(d.localPosition),
        onPanUpdate: (d) => _addPoint(d.localPosition),
        onPanEnd: (_) => onChanged([...points, null]),
        child: CustomPaint(
          painter: _SignaturePainter(points),
          size: Size.infinite,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  void _addPoint(Offset p) {
    onChanged([...points, p]);
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2B6E6A)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}

class _VersionBar extends StatelessWidget {
  const _VersionBar({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 8,
        horizontal: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E7DC),
        borderRadius: compact ? BorderRadius.circular(16) : null,
      ),
      child: const Text(
        'Parent App Version: v$_appVersion',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _rememberKey = 'remember_login';
  static const _savedEmailKey = 'saved_login_email';
  static const _savedPasswordKey = 'saved_login_password';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberLogin = true;
  bool _isRegisterMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isRegisterMode) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created successfully.')),
          );
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      await _persistCredentials();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _messageForCode(e.code);
      });
    } catch (_) {
      setState(() {
        _error = 'Unexpected error. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not send reset email. Try again later.');
    }
  }

  Future<void> _restoreSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool(_rememberKey) ?? true;
    final savedEmail = prefs.getString(_savedEmailKey) ?? '';
    final savedPassword = prefs.getString(_savedPasswordKey) ?? '';
    if (!mounted) return;
    setState(() {
      _rememberLogin = remembered;
      if (remembered) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
      }
    });
  }

  Future<void> _persistCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, _rememberLogin);
    if (_rememberLogin) {
      await prefs.setString(_savedEmailKey, _emailController.text.trim());
      await prefs.setString(_savedPasswordKey, _passwordController.text);
    } else {
      await prefs.remove(_savedEmailKey);
      await prefs.remove(_savedPasswordKey);
    }
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Email format is invalid.';
      case 'user-disabled':
        return 'This account is disabled.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Auth failed ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(title: const Text('My Daycare Parent Login')),
      body: Container(
        decoration: BoxDecoration(
          gradient: isWide
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8F1E6),
                    Color(0xFFE6F4EE),
                    Color(0xFFEAF1FB),
                  ],
                )
              : null,
        ),
        child: SafeArea(
          child: isWide ? _buildWideLogin(context) : _buildMobileLogin(context),
        ),
      ),
      bottomNavigationBar: const _VersionBar(),
    );
  }

  Widget _buildMobileLogin(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: _buildLoginForm(context),
        ),
      ),
    );
  }

  Widget _buildWideLogin(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(34),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFD8EBFF),
                        Color(0xFFD8F4E3),
                        Color(0xFFF8DDE5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parent Portal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: Color(0xFF5C6C7A),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'A calmer, clearer daycare website for families.',
                        style: TextStyle(
                          fontSize: 46,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Check attendance, forms, billing, and child updates from one shared dashboard designed for larger screens.',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.4,
                          color: Color(0xFF526171),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: const Color(0xFFE5EAF0)),
                      ),
                      child: _buildLoginForm(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFFCFEEDD),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Text('🏫', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'CareSync Parent',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Parent Login',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),
          _authFieldCard(
            label: 'EMAIL',
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                hintText: 'parent@email.com',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF2F5F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFDDE4EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFDDE4EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF2F9965),
                    width: 1.6,
                  ),
                ),
              ),
              validator: (value) {
                final input = (value ?? '').trim();
                if (input.isEmpty) return 'Email is required';
                if (!input.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          _authFieldCard(
            label: 'PASSWORD',
            child: TextFormField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF2F5F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFDDE4EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFDDE4EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF2F9965),
                    width: 1.6,
                  ),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Password is required';
                if (_isRegisterMode && (value ?? '').length < 6) {
                  return 'Use at least 6 characters';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(
                value: _rememberLogin,
                onChanged: (value) {
                  setState(() => _rememberLogin = value ?? false);
                },
                visualDensity: VisualDensity.compact,
              ),
              const Text(
                'Remember login',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F9965),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _isLoading ? null : _submitAuth,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isRegisterMode ? 'Register' : 'Login',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (!_isRegisterMode)
            TextButton(
              onPressed: _isLoading ? null : _forgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(fontSize: 18, color: Color(0xFF7B8794)),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'New parent? Contact the daycare to\nreceive your invite link.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF5C6C7A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _isRegisterMode = !_isRegisterMode;
                      _error = null;
                    });
                  },
            child: Text(
              _isRegisterMode
                  ? 'Already have account? Login'
                  : 'No account? Register',
              style: const TextStyle(
                color: Color(0xFF6B8E89),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authFieldCard({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7A8799),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class ParentContext {
  const ParentContext({required this.tenantId, required this.parentId});

  final String tenantId;
  final String parentId;
}

enum _PhotoPermissionAction { sign, view }

class ChildRecordLite {
  const ChildRecordLite({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.parentId,
    required this.allergyNotes,
    required this.medicalNotes,
    required this.pickupNotes,
    required this.photoPermissionSigned,
    required this.photoPermissionSignedAt,
    required this.todaySummaryTags,
    required this.todaySummaryDateKey,
    required this.latestUpdateNote,
    required this.latestUpdatePhotoUrl,
    required this.latestUpdatePhotoName,
    required this.latestUpdateCreatedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String parentId;
  final String allergyNotes;
  final String medicalNotes;
  final String pickupNotes;
  final bool photoPermissionSigned;
  final DateTime? photoPermissionSignedAt;
  final List<String> todaySummaryTags;
  final String todaySummaryDateKey;
  final String latestUpdateNote;
  final String latestUpdatePhotoUrl;
  final String latestUpdatePhotoName;
  final DateTime? latestUpdateCreatedAt;

  String get fullName => '$firstName $lastName'.trim();

  factory ChildRecordLite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChildRecordLite(
      id: doc.id,
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      dateOfBirth: _asDateTime(data['dateOfBirth']),
      parentId: (data['parentId'] ?? '').toString(),
      allergyNotes: (data['allergyNotes'] ?? '').toString(),
      medicalNotes: (data['medicalNotes'] ?? '').toString(),
      pickupNotes: (data['pickupNotes'] ?? '').toString(),
      photoPermissionSigned: data['photoPermissionSigned'] == true,
      photoPermissionSignedAt: _asDateTime(data['photoPermissionSignedAt']),
      todaySummaryTags: (data['todaySummaryTags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      todaySummaryDateKey: (data['todaySummaryDateKey'] ?? '').toString(),
      latestUpdateNote: (data['latestUpdateNote'] ?? '').toString(),
      latestUpdatePhotoUrl: (data['latestUpdatePhotoUrl'] ?? '').toString(),
      latestUpdatePhotoName: (data['latestUpdatePhotoName'] ?? '').toString(),
      latestUpdateCreatedAt: _asDateTime(data['latestUpdateCreatedAt']),
    );
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class ParentRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  static const _projectId = 'liisgo-daycare-system';

  Future<ParentContext?> resolveParentContext(String authUid) async {
    try {
      final scanned = await _scanParentByAuthUid(authUid);
      if (scanned != null) return scanned;

      final membershipDoc = await _db
          .collection('parent_memberships')
          .doc(authUid)
          .get();
      final membership = membershipDoc.data();
      if (membership != null) {
        final tenantId = (membership['tenantId'] ?? '').toString();
        final parentId = (membership['parentId'] ?? '').toString();
        if (tenantId.isNotEmpty && parentId.isNotEmpty) {
          return ParentContext(tenantId: tenantId, parentId: parentId);
        }
      }

      final tenantDocs = await _db.collection('tenants').limit(300).get();
      for (final tenantDoc in tenantDocs.docs) {
        final parentQuery = await tenantDoc.reference
            .collection('parents')
            .where('authUid', isEqualTo: authUid)
            .limit(1)
            .get();
        if (parentQuery.docs.isNotEmpty) {
          return ParentContext(
            tenantId: tenantDoc.id,
            parentId: parentQuery.docs.first.id,
          );
        }
      }
    } catch (_) {}

    return _resolveParentContextViaRest(authUid);
  }

  Future<ParentContext?> _scanParentByAuthUid(String authUid) async {
    final tenantDocs = await _db.collection('tenants').limit(300).get();
    for (final tenantDoc in tenantDocs.docs) {
      final parentQuery = await tenantDoc.reference
          .collection('parents')
          .where('authUid', isEqualTo: authUid)
          .limit(1)
          .get();
      if (parentQuery.docs.isNotEmpty) {
        return ParentContext(
          tenantId: tenantDoc.id,
          parentId: parentQuery.docs.first.id,
        );
      }
    }
    return null;
  }

  Future<ParentContext?> _resolveParentContextViaRest(String authUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return null;

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/parent_memberships/$authUid',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 200) return null;

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = (payload['fields'] as Map<String, dynamic>?) ?? {};
    final tenantId = _stringField(fields, 'tenantId');
    final parentId = _stringField(fields, 'parentId');
    if (tenantId.isEmpty || parentId.isEmpty) return null;

    return ParentContext(tenantId: tenantId, parentId: parentId);
  }

  String _stringField(Map<String, dynamic> fields, String key) {
    final raw = fields[key];
    if (raw is! Map<String, dynamic>) return '';
    return (raw['stringValue'] ?? '').toString();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchParentDoc(
    ParentContext contextData,
  ) {
    return _db
        .collection('tenants')
        .doc(contextData.tenantId)
        .collection('parents')
        .doc(contextData.parentId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTenantDoc(
    String tenantId,
  ) {
    return _db.collection('tenants').doc(tenantId).snapshots();
  }

  Future<Map<String, dynamic>> loadParentDoc(ParentContext contextData) async {
    try {
      final doc = await _db
          .collection('tenants')
          .doc(contextData.tenantId)
          .collection('parents')
          .doc(contextData.parentId)
          .get();
      final data = doc.data();
      if (data != null && data.isNotEmpty) {
        return data;
      }
    } catch (_) {}
    return _loadParentDocViaRest(contextData);
  }

  Future<Map<String, dynamic>> loadTenantDoc(String tenantId) async {
    try {
      final doc = await _db.collection('tenants').doc(tenantId).get();
      final data = doc.data();
      if (data != null && data.isNotEmpty) {
        return data;
      }
    } catch (_) {}
    return _loadTenantDocViaRest(tenantId);
  }

  Stream<List<ChildRecordLite>> watchChildrenForTenant(
    ParentContext contextData,
  ) async* {
    while (true) {
      yield await loadChildrenForTenant(contextData);
      await Future<void>.delayed(const Duration(seconds: 8));
    }
  }

  Future<List<ChildRecordLite>> loadChildrenForTenant(
    ParentContext contextData,
  ) async {
    try {
      final snapshot = await _db
          .collection('tenants')
          .doc(contextData.tenantId)
          .collection('children')
          .get();
      return snapshot.docs.map(ChildRecordLite.fromDoc).toList();
    } catch (_) {
      return _loadChildrenViaRest(contextData.tenantId);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLatestUpdate(
    ParentContext contextData,
    String childId,
  ) {
    return _db
        .collection('tenants')
        .doc(contextData.tenantId)
        .collection('children')
        .doc(childId)
        .collection('latest_updates')
        .doc('current')
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTodaySummary(
    ParentContext contextData,
    String childId,
  ) {
    return _db
        .collection('tenants')
        .doc(contextData.tenantId)
        .collection('children')
        .doc(childId)
        .collection('today_summary')
        .doc('current')
        .snapshots();
  }

  static String todayDateKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> updateParentProfile({
    required ParentContext contextData,
    required String uid,
    required Map<String, dynamic> changes,
  }) async {
    await _db
        .collection('tenants')
        .doc(contextData.tenantId)
        .collection('parents')
        .doc(contextData.parentId)
        .set({
          ...changes,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': uid,
          'sourceApp': 'parent_daycare_app',
        }, SetOptions(merge: true));
  }

  Future<void> saveParentContractSignature({
    required ParentContext contextData,
    required String uid,
    required bool accepted,
    required String signedName,
    required List<String> signaturePoints,
    required bool signatureCaptured,
  }) async {
    try {
      await _db
          .collection('tenants')
          .doc(contextData.tenantId)
          .collection('parents')
          .doc(contextData.parentId)
          .set({
            'parentContract': {
              'accepted': accepted,
              'signedName': signedName,
              'signaturePoints': signaturePoints,
              'signatureCaptured': signatureCaptured,
              'signedAt': FieldValue.serverTimestamp(),
            },
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': uid,
            'sourceApp': 'parent_daycare_app',
          }, SetOptions(merge: true));
    } catch (_) {
      await _saveParentContractSignatureViaRest(
        tenantId: contextData.tenantId,
        parentId: contextData.parentId,
        uid: uid,
        accepted: accepted,
        signedName: signedName,
        signaturePoints: signaturePoints,
        signatureCaptured: signatureCaptured,
      );
    }
  }

  Future<void> savePhotoPermissionDocument({
    required ParentContext contextData,
    required String uid,
    required ChildRecordLite child,
    required Map<String, dynamic> parentData,
    required bool consentGranted,
    required String documentLanguage,
    required bool internalCommunicationApproved,
    required bool publicWebsiteApproved,
    required String daycareName,
    required String daycareAddress,
    required String daycarePhone,
    required String childDateOfBirthText,
    required String signedName,
    required List<String> signaturePoints,
    required bool signatureCaptured,
  }) async {
    final childRef = _db
        .collection('tenants')
        .doc(contextData.tenantId)
        .collection('children')
        .doc(child.id);
    final permissionRef = childRef
        .collection('photo_permissions')
        .doc(contextData.parentId);
    final parentName =
        '${(parentData['firstName'] ?? '').toString()} ${(parentData['lastName'] ?? '').toString()}'
            .trim();

    try {
      final batch = _db.batch();
      batch.set(permissionRef, {
        'parentId': contextData.parentId,
        'parentAuthUid': uid,
        'parentName': parentName,
        'parentEmail': (parentData['email'] ?? '').toString(),
        'parentPhone': (parentData['phone'] ?? '').toString(),
        'parentAddressLine1': (parentData['addressLine1'] ?? '').toString(),
        'parentCity': (parentData['city'] ?? '').toString(),
        'parentState': (parentData['state'] ?? '').toString(),
        'parentZip': (parentData['zip'] ?? '').toString(),
        'childId': child.id,
        'childName': child.fullName,
        'childDateOfBirthText': childDateOfBirthText,
        'formType': 'photo_media_permission',
        'consentGranted': consentGranted,
        'documentLanguage': documentLanguage,
        'internalCommunicationApproved': internalCommunicationApproved,
        'publicWebsiteApproved': publicWebsiteApproved,
        'daycareName': daycareName,
        'daycareAddress': daycareAddress,
        'daycarePhone': daycarePhone,
        'documentCompleted': true,
        'signedName': signedName,
        'signaturePoints': signaturePoints,
        'signatureCaptured': signatureCaptured,
        'signedAt': FieldValue.serverTimestamp(),
        'sourceApp': 'parent_daycare_app',
        'updatedByUid': uid,
      }, SetOptions(merge: true));

      batch.set(childRef, {
        'photoPermissionSigned': signatureCaptured,
        'photoPermissionSignedAt': FieldValue.serverTimestamp(),
        'photoPermissionSignedByParentId': contextData.parentId,
        'photoPermissionSignedByName': signedName,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': uid,
        'sourceApp': 'parent_daycare_app',
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (_) {
      await _savePhotoPermissionViaRest(
        tenantId: contextData.tenantId,
        parentId: contextData.parentId,
        child: child,
        uid: uid,
        parentData: parentData,
        consentGranted: consentGranted,
        documentLanguage: documentLanguage,
        internalCommunicationApproved: internalCommunicationApproved,
        publicWebsiteApproved: publicWebsiteApproved,
        daycareName: daycareName,
        daycareAddress: daycareAddress,
        daycarePhone: daycarePhone,
        childDateOfBirthText: childDateOfBirthText,
        signedName: signedName,
        signaturePoints: signaturePoints,
        signatureCaptured: signatureCaptured,
      );
    }
  }

  Future<UploadedParentFormFile> uploadParentFormPdf({
    required String tenantId,
    required String parentId,
    required String documentKey,
    required List<int> bytes,
    required String fileName,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        'tenants/$tenantId/parent_forms/$parentId/$documentKey/$safeName';
    final ref = _storage.ref(path);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: 'application/pdf'),
    );
    final url = await ref.getDownloadURL();
    return UploadedParentFormFile(url: url, path: path, fileName: safeName);
  }

  Future<void> saveParentContractPdfMetadata({
    required ParentContext contextData,
    required String uid,
    required String pdfUrl,
    required String pdfPath,
    required String pdfName,
  }) async {
    await _db
        .collection('tenants')
        .doc(contextData.tenantId)
        .collection('parents')
        .doc(contextData.parentId)
        .set({
          'parentContract.pdfUrl': pdfUrl,
          'parentContract.pdfPath': pdfPath,
          'parentContract.pdfName': pdfName,
          'parentContract.pdfGeneratedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': uid,
          'sourceApp': 'parent_daycare_app',
        }, SetOptions(merge: true));
  }

  Future<void> savePhotoPermissionPdfMetadata({
    required ParentContext contextData,
    required String uid,
    required String childId,
    required String pdfUrl,
    required String pdfPath,
    required String pdfName,
  }) async {
    await _db
        .collection('tenants')
        .doc(contextData.tenantId)
        .collection('children')
        .doc(childId)
        .collection('photo_permissions')
        .doc(contextData.parentId)
        .set({
          'pdfUrl': pdfUrl,
          'pdfPath': pdfPath,
          'pdfName': pdfName,
          'pdfGeneratedAt': FieldValue.serverTimestamp(),
          'updatedByUid': uid,
          'sourceApp': 'parent_daycare_app',
        }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> loadPhotoPermissionDocument({
    required ParentContext contextData,
    required String childId,
  }) async {
    try {
      final doc = await _db
          .collection('tenants')
          .doc(contextData.tenantId)
          .collection('children')
          .doc(childId)
          .collection('photo_permissions')
          .doc(contextData.parentId)
          .get();
      final data = doc.data();
      if (data != null && data.isNotEmpty) {
        return data;
      }
    } catch (_) {}
    return _loadPhotoPermissionViaRest(
      tenantId: contextData.tenantId,
      childId: childId,
      parentId: contextData.parentId,
    );
  }

  Future<void> createChildRequest({
    required ParentContext contextData,
    required String uid,
    required String firstName,
    required String lastName,
    required String notes,
  }) async {
    final requestData = {
      'parentId': contextData.parentId,
      'requestedByUid': uid,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'notes': notes.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'sourceApp': 'parent_daycare_app',
    };

    try {
      await _db
          .collection('tenants')
          .doc(contextData.tenantId)
          .collection('child_requests')
          .add(requestData);
    } catch (_) {
      await _createChildRequestViaRest(
        tenantId: contextData.tenantId,
        parentId: contextData.parentId,
        uid: uid,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        notes: notes.trim(),
      );
    }
  }

  Future<void> createPickupNotification({
    required ParentContext contextData,
    required String uid,
    required int etaMinutes,
    required ChildRecordLite child,
    required String parentFirstName,
    required String parentLastName,
  }) async {
    final parentName = '$parentFirstName $parentLastName'.trim();
    final childName = child.fullName.isEmpty ? 'Child' : child.fullName;
    final safeParentName = parentName.isEmpty ? 'Parent' : parentName;
    final payload = {
      'parentId': contextData.parentId,
      'childId': child.id,
      'requestedByUid': uid,
      'parentName': parentName,
      'childName': childName,
      'etaMinutes': etaMinutes,
      'message':
          '$safeParentName is on the way for pickup in about $etaMinutes minutes.',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'sourceApp': 'parent_daycare_app',
      'type': 'pickup_eta',
    };

    try {
      await _db
          .collection('tenants')
          .doc(contextData.tenantId)
          .collection('pickup_notifications')
          .add(payload);
    } catch (_) {
      await _createPickupNotificationViaRest(
        tenantId: contextData.tenantId,
        parentId: contextData.parentId,
        childId: child.id,
        uid: uid,
        parentName: parentName,
        childName: childName,
        etaMinutes: etaMinutes,
      );
    }
  }

  Future<List<ChildRecordLite>> _loadChildrenViaRest(String tenantId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <ChildRecordLite>[];

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return const <ChildRecordLite>[];

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/$tenantId/children',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 200) {
      return const <ChildRecordLite>[];
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = (payload['documents'] as List<dynamic>?) ?? const [];
    return docs.whereType<Map<String, dynamic>>().map((doc) {
      final name = (doc['name'] ?? '').toString();
      final id = name.split('/').isNotEmpty ? name.split('/').last : '';
      final fields = (doc['fields'] as Map<String, dynamic>?) ?? const {};
      return ChildRecordLite(
        id: id,
        firstName: _stringField(fields, 'firstName'),
        lastName: _stringField(fields, 'lastName'),
        dateOfBirth: _timestampField(fields, 'dateOfBirth'),
        parentId: _stringField(fields, 'parentId'),
        allergyNotes: _stringField(fields, 'allergyNotes'),
        medicalNotes: _stringField(fields, 'medicalNotes'),
        pickupNotes: _stringField(fields, 'pickupNotes'),
        photoPermissionSigned:
            (fields['photoPermissionSigned']
                as Map<String, dynamic>?)?['booleanValue'] ==
            true,
        photoPermissionSignedAt: _timestampField(
          fields,
          'photoPermissionSignedAt',
        ),
        todaySummaryTags: _arrayStringField(fields, 'todaySummaryTags'),
        todaySummaryDateKey: _stringField(fields, 'todaySummaryDateKey'),
        latestUpdateNote: _stringField(fields, 'latestUpdateNote'),
        latestUpdatePhotoUrl: _stringField(fields, 'latestUpdatePhotoUrl'),
        latestUpdatePhotoName: _stringField(fields, 'latestUpdatePhotoName'),
        latestUpdateCreatedAt: _timestampField(fields, 'latestUpdateCreatedAt'),
      );
    }).toList();
  }

  List<String> _arrayStringField(Map<String, dynamic> fields, String key) {
    final raw = fields[key];
    if (raw is! Map<String, dynamic>) return const <String>[];
    final values =
        (raw['arrayValue'] as Map<String, dynamic>?)?['values']
            as List<dynamic>?;
    if (values == null) return const <String>[];
    return values
        .whereType<Map<String, dynamic>>()
        .map((item) => (item['stringValue'] ?? '').toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }

  DateTime? _timestampField(Map<String, dynamic> fields, String key) {
    final raw = fields[key];
    if (raw is! Map<String, dynamic>) return null;
    final value = (raw['timestampValue'] ?? '').toString();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  Future<void> _createChildRequestViaRest({
    required String tenantId,
    required String parentId,
    required String uid,
    required String firstName,
    required String lastName,
    required String notes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Missing auth token');
    }

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/$tenantId/child_requests',
    );
    final body = jsonEncode({
      'fields': {
        'parentId': {'stringValue': parentId},
        'requestedByUid': {'stringValue': uid},
        'firstName': {'stringValue': firstName},
        'lastName': {'stringValue': lastName},
        'notes': {'stringValue': notes},
        'status': {'stringValue': 'pending'},
        'sourceApp': {'stringValue': 'parent_daycare_app'},
        'createdAt': {
          'timestampValue': DateTime.now().toUtc().toIso8601String(),
        },
      },
    });
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed (${response.statusCode})');
    }
  }

  Future<void> _createPickupNotificationViaRest({
    required String tenantId,
    required String parentId,
    required String childId,
    required String uid,
    required String parentName,
    required String childName,
    required int etaMinutes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Missing auth token');
    }

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/$tenantId/pickup_notifications',
    );
    final body = jsonEncode({
      'fields': {
        'parentId': {'stringValue': parentId},
        'childId': {'stringValue': childId},
        'requestedByUid': {'stringValue': uid},
        'parentName': {'stringValue': parentName},
        'childName': {'stringValue': childName},
        'etaMinutes': {'integerValue': etaMinutes.toString()},
        'message': {
          'stringValue':
              '$parentName is on the way for pickup in about $etaMinutes minutes.',
        },
        'status': {'stringValue': 'pending'},
        'sourceApp': {'stringValue': 'parent_daycare_app'},
        'type': {'stringValue': 'pickup_eta'},
        'createdAt': {
          'timestampValue': DateTime.now().toUtc().toIso8601String(),
        },
      },
    });
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> _loadParentDocViaRest(
    ParentContext contextData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <String, dynamic>{};
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      return const <String, dynamic>{};
    }

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/${contextData.tenantId}/parents/${contextData.parentId}',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 200) {
      return const <String, dynamic>{};
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = (payload['fields'] as Map<String, dynamic>?) ?? const {};
    return _decodeFirestoreMap(fields);
  }

  Future<Map<String, dynamic>> _loadTenantDocViaRest(String tenantId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <String, dynamic>{};
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      return const <String, dynamic>{};
    }

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/$tenantId',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 200) {
      return const <String, dynamic>{};
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = (payload['fields'] as Map<String, dynamic>?) ?? const {};
    return _decodeFirestoreMap(fields);
  }

  Future<Map<String, dynamic>> _loadPhotoPermissionViaRest({
    required String tenantId,
    required String childId,
    required String parentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <String, dynamic>{};
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      return const <String, dynamic>{};
    }

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/$tenantId/children/$childId/photo_permissions/$parentId',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 200) {
      return const <String, dynamic>{};
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = (payload['fields'] as Map<String, dynamic>?) ?? const {};
    return _decodeFirestoreMap(fields);
  }

  Map<String, dynamic> _decodeFirestoreMap(Map<String, dynamic> fields) {
    final decoded = <String, dynamic>{};
    fields.forEach((key, value) {
      decoded[key] = _decodeFirestoreValue(value);
    });
    return decoded;
  }

  dynamic _decodeFirestoreValue(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    if (raw.containsKey('stringValue')) {
      return (raw['stringValue'] ?? '').toString();
    }
    if (raw.containsKey('booleanValue')) {
      return raw['booleanValue'] == true;
    }
    if (raw.containsKey('integerValue')) {
      return int.tryParse((raw['integerValue'] ?? '').toString());
    }
    if (raw.containsKey('doubleValue')) {
      return (raw['doubleValue'] as num?)?.toDouble();
    }
    if (raw.containsKey('timestampValue')) {
      final value = (raw['timestampValue'] ?? '').toString();
      return value.isEmpty ? null : DateTime.tryParse(value)?.toLocal();
    }
    if (raw.containsKey('nullValue')) {
      return null;
    }
    if (raw.containsKey('mapValue')) {
      final mapFields =
          (raw['mapValue'] as Map<String, dynamic>?)?['fields']
              as Map<String, dynamic>? ??
          const <String, dynamic>{};
      return _decodeFirestoreMap(mapFields);
    }
    if (raw.containsKey('arrayValue')) {
      final values =
          (raw['arrayValue'] as Map<String, dynamic>?)?['values']
              as List<dynamic>? ??
          const <dynamic>[];
      return values.map(_decodeFirestoreValue).toList();
    }
    return null;
  }

  Future<void> _saveParentContractSignatureViaRest({
    required String tenantId,
    required String parentId,
    required String uid,
    required bool accepted,
    required String signedName,
    required List<String> signaturePoints,
    required bool signatureCaptured,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Missing auth token');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/$tenantId/parents/$parentId'
      '?updateMask.fieldPaths=parentContract'
      '&updateMask.fieldPaths=updatedAt'
      '&updateMask.fieldPaths=updatedByUid'
      '&updateMask.fieldPaths=sourceApp',
    );
    final body = jsonEncode({
      'fields': {
        'parentContract': {
          'mapValue': {
            'fields': {
              'accepted': {'booleanValue': accepted},
              'signedName': {'stringValue': signedName},
              'signaturePoints': {
                'arrayValue': {
                  'values': signaturePoints
                      .map((point) => {'stringValue': point})
                      .toList(),
                },
              },
              'signatureCaptured': {'booleanValue': signatureCaptured},
              'signedAt': {'timestampValue': now},
            },
          },
        },
        'updatedAt': {'timestampValue': now},
        'updatedByUid': {'stringValue': uid},
        'sourceApp': {'stringValue': 'parent_daycare_app'},
      },
    });
    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Contract save failed (${response.statusCode})');
    }
  }

  Future<void> _savePhotoPermissionViaRest({
    required String tenantId,
    required String parentId,
    required ChildRecordLite child,
    required String uid,
    required Map<String, dynamic> parentData,
    required bool consentGranted,
    required String documentLanguage,
    required bool internalCommunicationApproved,
    required bool publicWebsiteApproved,
    required String daycareName,
    required String daycareAddress,
    required String daycarePhone,
    required String childDateOfBirthText,
    required String signedName,
    required List<String> signaturePoints,
    required bool signatureCaptured,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Missing auth token');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final parentName =
        '${(parentData['firstName'] ?? '').toString()} ${(parentData['lastName'] ?? '').toString()}'
            .trim();

    final permissionUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/$tenantId/children/${child.id}/photo_permissions/$parentId'
      '?updateMask.fieldPaths=parentId'
      '&updateMask.fieldPaths=parentAuthUid'
      '&updateMask.fieldPaths=parentName'
      '&updateMask.fieldPaths=parentEmail'
      '&updateMask.fieldPaths=parentPhone'
      '&updateMask.fieldPaths=parentAddressLine1'
      '&updateMask.fieldPaths=parentCity'
      '&updateMask.fieldPaths=parentState'
      '&updateMask.fieldPaths=parentZip'
      '&updateMask.fieldPaths=childId'
      '&updateMask.fieldPaths=childName'
      '&updateMask.fieldPaths=childDateOfBirthText'
      '&updateMask.fieldPaths=formType'
      '&updateMask.fieldPaths=consentGranted'
      '&updateMask.fieldPaths=documentLanguage'
      '&updateMask.fieldPaths=internalCommunicationApproved'
      '&updateMask.fieldPaths=publicWebsiteApproved'
      '&updateMask.fieldPaths=daycareName'
      '&updateMask.fieldPaths=daycareAddress'
      '&updateMask.fieldPaths=daycarePhone'
      '&updateMask.fieldPaths=documentCompleted'
      '&updateMask.fieldPaths=signedName'
      '&updateMask.fieldPaths=signaturePoints'
      '&updateMask.fieldPaths=signatureCaptured'
      '&updateMask.fieldPaths=signedAt'
      '&updateMask.fieldPaths=sourceApp'
      '&updateMask.fieldPaths=updatedByUid',
    );
    final permissionBody = jsonEncode({
      'fields': {
        'parentId': {'stringValue': parentId},
        'parentAuthUid': {'stringValue': uid},
        'parentName': {'stringValue': parentName},
        'parentEmail': {'stringValue': (parentData['email'] ?? '').toString()},
        'parentPhone': {'stringValue': (parentData['phone'] ?? '').toString()},
        'parentAddressLine1': {
          'stringValue': (parentData['addressLine1'] ?? '').toString(),
        },
        'parentCity': {'stringValue': (parentData['city'] ?? '').toString()},
        'parentState': {'stringValue': (parentData['state'] ?? '').toString()},
        'parentZip': {'stringValue': (parentData['zip'] ?? '').toString()},
        'childId': {'stringValue': child.id},
        'childName': {'stringValue': child.fullName},
        'childDateOfBirthText': {'stringValue': childDateOfBirthText},
        'formType': {'stringValue': 'photo_media_permission'},
        'consentGranted': {'booleanValue': consentGranted},
        'documentLanguage': {'stringValue': documentLanguage},
        'internalCommunicationApproved': {
          'booleanValue': internalCommunicationApproved,
        },
        'publicWebsiteApproved': {'booleanValue': publicWebsiteApproved},
        'daycareName': {'stringValue': daycareName},
        'daycareAddress': {'stringValue': daycareAddress},
        'daycarePhone': {'stringValue': daycarePhone},
        'documentCompleted': {'booleanValue': true},
        'signedName': {'stringValue': signedName},
        'signaturePoints': {
          'arrayValue': {
            'values': signaturePoints
                .map((point) => {'stringValue': point})
                .toList(),
          },
        },
        'signatureCaptured': {'booleanValue': signatureCaptured},
        'signedAt': {'timestampValue': now},
        'sourceApp': {'stringValue': 'parent_daycare_app'},
        'updatedByUid': {'stringValue': uid},
      },
    });
    final permissionResponse = await http.patch(
      permissionUri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: permissionBody,
    );
    if (permissionResponse.statusCode < 200 ||
        permissionResponse.statusCode >= 300) {
      throw Exception(
        'Permission save failed (${permissionResponse.statusCode})',
      );
    }

    final childUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/tenants/$tenantId/children/${child.id}'
      '?updateMask.fieldPaths=photoPermissionSigned'
      '&updateMask.fieldPaths=photoPermissionSignedAt'
      '&updateMask.fieldPaths=photoPermissionSignedByParentId'
      '&updateMask.fieldPaths=photoPermissionSignedByName'
      '&updateMask.fieldPaths=updatedAt'
      '&updateMask.fieldPaths=updatedByUid'
      '&updateMask.fieldPaths=sourceApp',
    );
    final childBody = jsonEncode({
      'fields': {
        'photoPermissionSigned': {'booleanValue': signatureCaptured},
        'photoPermissionSignedAt': {'timestampValue': now},
        'photoPermissionSignedByParentId': {'stringValue': parentId},
        'photoPermissionSignedByName': {'stringValue': signedName},
        'updatedAt': {'timestampValue': now},
        'updatedByUid': {'stringValue': uid},
        'sourceApp': {'stringValue': 'parent_daycare_app'},
      },
    });
    final childResponse = await http.patch(
      childUri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: childBody,
    );
    if (childResponse.statusCode < 200 || childResponse.statusCode >= 300) {
      throw Exception(
        'Child permission update failed (${childResponse.statusCode})',
      );
    }
  }
}
