import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

const _appVersion = '1.2.0+13';

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
    final pages = [
      HomePage(contextData: widget.contextData, uid: widget.user.uid),
      ChildPage(contextData: widget.contextData, uid: widget.user.uid),
      ProfilePage(contextData: widget.contextData, uid: widget.user.uid),
      FormsPage(contextData: widget.contextData, uid: widget.user.uid),
      const BillingPage(),
    ];

    const titles = ['Home', 'Child', 'Profile', 'Form', 'Billing'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CareSync Parent App'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings panel coming soon.')),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          TextButton.icon(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(14), child: pages[_index]),
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
        final daycareName =
            (parent['daycareName'] ?? parent['businessName'] ?? 'My Daycare')
                .toString();

        return StreamBuilder<List<ChildRecordLite>>(
          stream: ParentRepository().watchChildrenForTenant(widget.contextData),
          builder: (context, childSnap) {
            final children = childSnap.data ?? const <ChildRecordLite>[];
            final linkedChildren = children
                .where((c) => c.parentId == widget.contextData.parentId)
                .toList();
            final selected = linkedChildren.isNotEmpty
                ? linkedChildren.first
                : null;

            return ListView(
              children: [
                _SectionCard(
                  title: 'Child Status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daycare: $daycareName'),
                      const SizedBox(height: 6),
                      Text(
                        selected == null
                            ? 'No child linked yet.'
                            : 'Child: ${selected.fullName} | Status: Checked In',
                      ),
                      const SizedBox(height: 4),
                      const Text('Check-in time: 8:10 AM'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'I\'m on my way',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                      FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ETA $_eta min sent to daycare.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Send to daycare'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionCard(
                  title: 'Today Summary',
                  child: Text(
                    'Meals: Breakfast, Lunch\nNaps: 1\nMood: Happy\nAttendance: Present',
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionCard(
                  title: 'Latest Update',
                  child: Text(
                    'Teacher note: Great participation in reading time.\nMedia: Pending upload.',
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Quick Actions',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _QuickActionChip(
                        icon: Icons.event_busy_outlined,
                        label: 'Report Absence',
                      ),
                      _QuickActionChip(
                        icon: Icons.call_outlined,
                        label: 'Call Daycare',
                      ),
                      _QuickActionChip(
                        icon: Icons.description_outlined,
                        label: 'View Forms',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Daycare Feedback',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        children: List.generate(5, (i) {
                          final value = i + 1;
                          return IconButton(
                            onPressed: () => setState(() => _rating = value),
                            icon: Icon(
                              value <= _rating ? Icons.star : Icons.star_border,
                              color: const Color(0xFFF59E0B),
                            ),
                          );
                        }),
                      ),
                      TextField(
                        controller: _feedbackCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Write your feedback...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Feedback submitted.'),
                            ),
                          );
                        },
                        child: const Text('Submit Feedback'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
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

        return ListView(
          children: [
            _SectionCard(
              title: 'Child',
              child: Row(
                children: [
                  Expanded(child: Text('Linked children: ${linked.length}')),
                  FilledButton.icon(
                    onPressed: _requesting ? null : _openChildRequestDialog,
                    icon: const Icon(Icons.add),
                    label: Text(_requesting ? 'Submitting...' : 'Add Child'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (linked.isEmpty)
              const _SectionCard(
                title: 'No child yet',
                child: Text('No child records linked to this parent yet.'),
              )
            else
              ...linked.map(
                (child) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SectionCard(
                    title: child.fullName,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Age: Not specified'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _QuickActionChip(
                              icon: Icons.verified_user_outlined,
                              label: 'Authorized Pickup',
                            ),
                            _QuickActionChip(
                              icon: Icons.medical_services_outlined,
                              label: 'Medical Info',
                            ),
                            _QuickActionChip(
                              icon: Icons.calendar_month_outlined,
                              label: 'Attendance',
                            ),
                            _QuickActionChip(
                              icon: Icons.description_outlined,
                              label: 'Forms',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.contextData, required this.uid});

  final ParentContext contextData;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ParentRepository().watchParentDoc(contextData),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final firstName = (data['firstName'] ?? '').toString();
        final lastName = (data['lastName'] ?? '').toString();
        final fullName = '$firstName $lastName'.trim().isEmpty
            ? 'Parent account'
            : '$firstName $lastName'.trim();

        return ListView(
          children: [
            _SectionCard(
              title: 'Parent Information',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: $fullName'),
                  Text('Role: Parent'),
                  Text('Phone: ${(data['phone'] ?? '').toString()}'),
                  Text('Email: ${(data['email'] ?? '').toString()}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Authorized Pickup',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (data['pickupNotes'] ?? 'No pickup notes yet.').toString(),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () {},
                    child: const Text('Add Authorized Pickup'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Emergency Contacts',
              child: Text(
                'Name: ${(data['emergencyContactName'] ?? '').toString()}\n'
                'Phone: ${(data['emergencyContactPhone'] ?? '').toString()}',
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Settings',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _QuickActionChip(
                    icon: Icons.language_outlined,
                    label: 'Language',
                  ),
                  _QuickActionChip(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                  ),
                  _QuickActionChip(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                  ),
                  _QuickActionChip(
                    icon: Icons.info_outline,
                    label: 'App Version',
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
      stream: ParentRepository().watchParentDoc(widget.contextData),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final contract =
            (data['parentContract'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};

        if (!_initialized) {
          _accepted = contract['accepted'] == true;
          _signName.text = (contract['signedName'] ?? '').toString();
          _signaturePoints = _decodeSignaturePoints(
            contract['signaturePoints'] as List<dynamic>?,
          );
          _initialized = true;
        }

        return ListView(
          children: [
            _SectionCard(
              title: 'Add Signature',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: _accepted,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I accept the contract terms'),
                    onChanged: (v) => setState(() => _accepted = v),
                  ),
                  TextField(
                    controller: _signName,
                    decoration: const InputDecoration(
                      labelText: 'Signature Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Signature pad'),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _signaturePoints = <Offset?>[]),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  SignaturePad(
                    points: _signaturePoints,
                    onChanged: (next) =>
                        setState(() => _signaturePoints = next),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _saving = true);
                            await ParentRepository().updateParentProfile(
                              contextData: widget.contextData,
                              uid: widget.uid,
                              changes: {
                                'parentContract': {
                                  'accepted': _accepted,
                                  'signedName': _signName.text.trim(),
                                  'signaturePoints': _encodeSignaturePoints(
                                    _signaturePoints,
                                  ),
                                  'signatureCaptured': _signaturePoints.any(
                                    (p) => p != null,
                                  ),
                                  'signedAt': FieldValue.serverTimestamp(),
                                },
                              },
                            );
                            if (!mounted) return;
                            setState(() => _saving = false);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Signature saved.')),
                            );
                          },
                    child: const Text('Save Signature'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: 'Pending Signature',
              child: Text('• Registration Form\n• Going Out Permit'),
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: 'Main Documents',
              child: Text(
                '• Contract\n• Registration\n• Emergency Contact Form\n• Medical Information',
              ),
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: 'Signed Documents',
              child: Text('Completed documents will appear here.'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, double?>> _encodeSignaturePoints(List<Offset?> points) {
    return points
        .map(
          (p) => p == null
              ? {'x': null, 'y': null}
              : {'x': p.dx.toDouble(), 'y': p.dy.toDouble()},
        )
        .toList();
  }

  List<Offset?> _decodeSignaturePoints(List<dynamic>? raw) {
    if (raw == null) return <Offset?>[];
    final out = <Offset?>[];
    for (final item in raw) {
      if (item is! Map) continue;
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
    return out;
  }
}

class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _SectionCard(
          title: 'Current Balance',
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  r'$420.00 due',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton(onPressed: () {}, child: const Text('Pay Now')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Upcoming Invoice',
          child: Text('Period: Mar 1 - Mar 31\nAmount: \$420.00'),
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Payment Methods',
          child: Text('Default: Visa •••• 2345\nAdd / Edit methods available.'),
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Recent Payments',
          child: Text('• Feb 01 - \$420.00\n• Jan 01 - \$420.00'),
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Receipts & Tax Records',
          child: Text('Downloadable records will appear here.'),
        ),
      ],
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

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label is ready for integration.')),
        );
      },
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
  const _VersionBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: const Color(0xFFF1E7DC),
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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
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
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Login failed ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Daycare Parent Login'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings are not available before login.'),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Email + password only',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final input = (value ?? '').trim();
                        if (input.isEmpty) return 'Email is required';
                        if (!input.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            value: _rememberLogin,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Remember login'),
                            onChanged: (value) {
                              setState(() => _rememberLogin = value ?? false);
                            },
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'New parents: contact daycare to receive an invite.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _VersionBar(),
    );
  }
}

class ParentContext {
  const ParentContext({required this.tenantId, required this.parentId});

  final String tenantId;
  final String parentId;
}

class ChildRecordLite {
  const ChildRecordLite({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.parentId,
    required this.allergyNotes,
    required this.medicalNotes,
    required this.pickupNotes,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String parentId;
  final String allergyNotes;
  final String medicalNotes;
  final String pickupNotes;

  String get fullName => '$firstName $lastName'.trim();

  factory ChildRecordLite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChildRecordLite(
      id: doc.id,
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      parentId: (data['parentId'] ?? '').toString(),
      allergyNotes: (data['allergyNotes'] ?? '').toString(),
      medicalNotes: (data['medicalNotes'] ?? '').toString(),
      pickupNotes: (data['pickupNotes'] ?? '').toString(),
    );
  }
}

class ParentRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
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
        parentId: _stringField(fields, 'parentId'),
        allergyNotes: _stringField(fields, 'allergyNotes'),
        medicalNotes: _stringField(fields, 'medicalNotes'),
        pickupNotes: _stringField(fields, 'pickupNotes'),
      );
    }).toList();
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
}
