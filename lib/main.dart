import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

const _appVersion = '1.1.10+12';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ParentDaycareApp());
}

class ParentDaycareApp extends StatelessWidget {
  const ParentDaycareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parent Daycare App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFF3FAF8),
        useMaterial3: true,
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
            bottomNavigationBar: _VersionBar(),
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
          return Scaffold(
            appBar: AppBar(title: const Text('Parent Access Error')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not resolve parent profile. Please contact daycare admin.',
                  ),
                  const SizedBox(height: 8),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Log Out'),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: const _VersionBar(),
          );
        }

        final contextData = snapshot.data;
        if (contextData == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Parent Access Pending')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No parent profile linked to this login yet. Contact daycare admin.',
                  ),
                  const SizedBox(height: 12),
                  Text('Signed in: ${user.email ?? user.uid}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Log Out'),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: const _VersionBar(),
          );
        }

        return ParentHomeShell(user: user, contextData: contextData);
      },
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
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 760;

    final pages = [
      ParentInfoPage(contextData: widget.contextData, uid: widget.user.uid),
      ChildInfoPage(contextData: widget.contextData, uid: widget.user.uid),
      ContractPage(contextData: widget.contextData, uid: widget.user.uid),
      SettingsPage(contextData: widget.contextData, uid: widget.user.uid),
    ];

    final titles = ['Parent', 'Child', 'Contract', 'Setting'];

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(title: Text(titles[_index]), actions: _actions()),
        body: pages[_index],
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Parent',
                ),
                NavigationDestination(
                  icon: Icon(Icons.child_friendly_outlined),
                  label: 'Child',
                ),
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  label: 'Contract',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Setting',
                ),
              ],
            ),
            const _VersionBar(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index]), actions: _actions()),
      body: Row(
        children: [
          Container(
            width: 260,
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Parent Portal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.email ?? '-',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _sideButton(0, Icons.person_outline, 'Parent'),
                _sideButton(1, Icons.child_friendly_outlined, 'Child'),
                _sideButton(2, Icons.description_outlined, 'Contract'),
                _sideButton(3, Icons.settings_outlined, 'Setting'),
                const Spacer(),
                const Text(
                  'Version: $_appVersion',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Expanded(child: pages[_index]),
        ],
      ),
      bottomNavigationBar: const _VersionBar(),
    );
  }

  List<Widget> _actions() {
    return [
      if (MediaQuery.of(context).size.width < 760)
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Center(
            child: Text('v$_appVersion', style: TextStyle(fontSize: 12)),
          ),
        ),
      TextButton.icon(
        onPressed: () => FirebaseAuth.instance.signOut(),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Log Out'),
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _sideButton(int index, IconData icon, String label) {
    final selected = _index == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonalIcon(
        onPressed: () => setState(() => _index = index),
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.26)
              : Colors.white,
        ),
      ),
    );
  }
}

class ParentInfoPage extends StatefulWidget {
  const ParentInfoPage({
    super.key,
    required this.contextData,
    required this.uid,
  });

  final ParentContext contextData;
  final String uid;

  @override
  State<ParentInfoPage> createState() => _ParentInfoPageState();
}

class _ParentInfoPageState extends State<ParentInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _address1.dispose();
    _address2.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ParentRepository().watchParentDoc(widget.contextData),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        if (!_initialized) {
          _first.text = (data['firstName'] ?? '').toString();
          _last.text = (data['lastName'] ?? '').toString();
          _phone.text = (data['phone'] ?? '').toString();
          _address1.text = (data['addressLine1'] ?? '').toString();
          _address2.text = (data['addressLine2'] ?? '').toString();
          _city.text = (data['city'] ?? '').toString();
          _state.text = (data['state'] ?? '').toString();
          _zip.text = (data['zip'] ?? '').toString();
          _emergencyName.text = (data['emergencyContactName'] ?? '').toString();
          _emergencyPhone.text = (data['emergencyContactPhone'] ?? '')
              .toString();
          _initialized = true;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parent Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _twoCol(
                        _field(_first, 'First Name'),
                        _field(_last, 'Last Name'),
                      ),
                      _twoCol(
                        _field(_phone, 'Phone'),
                        _readonlyField(
                          (data['email'] ?? '').toString(),
                          'Email',
                        ),
                      ),
                      _twoCol(
                        _field(_address1, 'Address Line 1'),
                        _field(_address2, 'Address Line 2'),
                      ),
                      _twoCol(_field(_city, 'City'), _field(_state, 'State')),
                      _field(_zip, 'ZIP Code'),
                      const Divider(height: 28),
                      Text(
                        'Emergency Contact',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _twoCol(
                        _field(_emergencyName, 'Emergency Contact Name'),
                        _field(_emergencyPhone, 'Emergency Contact Phone'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : () => _save(data),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Parent Info'),
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

  Widget _field(TextEditingController c, String label, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        enabled: enabled,
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _readonlyField(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        enabled: false,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _twoCol(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 740) {
          return Column(children: [left, right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Future<void> _save(Map<String, dynamic> previous) async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ParentRepository().updateParentProfile(
        contextData: widget.contextData,
        uid: widget.uid,
        changes: {
          'firstName': _first.text.trim(),
          'lastName': _last.text.trim(),
          'phone': _phone.text.trim(),
          'addressLine1': _address1.text.trim(),
          'addressLine2': _address2.text.trim(),
          'city': _city.text.trim(),
          'state': _state.text.trim(),
          'zip': _zip.text.trim(),
          'emergencyContactName': _emergencyName.text.trim(),
          'emergencyContactPhone': _emergencyPhone.text.trim(),
          'email': (previous['email'] ?? '').toString(),
        },
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Parent information saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ChildInfoPage extends StatefulWidget {
  const ChildInfoPage({
    super.key,
    required this.contextData,
    required this.uid,
  });

  final ParentContext contextData;
  final String uid;

  @override
  State<ChildInfoPage> createState() => _ChildInfoPageState();
}

class _ChildInfoPageState extends State<ChildInfoPage> {
  bool _requesting = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChildRecordLite>>(
      stream: ParentRepository().watchChildrenForTenant(widget.contextData),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Child read error: ${snapshot.error}'),
                ),
              ),
            ],
          );
        }
        final children = snapshot.data ?? const <ChildRecordLite>[];
        final linkedChildren = children
            .where((child) => child.parentId == widget.contextData.parentId)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Children linked to this parent: ${linkedChildren.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tenant: ${widget.contextData.tenantId} | Parent: ${widget.contextData.parentId}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tenant children loaded: ${children.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _requesting ? null : _openChildRequestDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  _requesting ? 'Submitting...' : 'Request Add Child',
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (linkedChildren.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No child records linked to this parent yet.'),
                ),
              )
            else
              ...linkedChildren.map(
                (child) => ChildCard(
                  child: child,
                  onSave: (changes) => ParentRepository().updateChildInfo(
                    contextData: widget.contextData,
                    childId: child.id,
                    uid: widget.uid,
                    changes: changes,
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

class ChildCard extends StatefulWidget {
  const ChildCard({super.key, required this.child, required this.onSave});

  final ChildRecordLite child;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<ChildCard> {
  late final TextEditingController _allergies;
  late final TextEditingController _medical;
  late final TextEditingController _pickup;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _allergies = TextEditingController(text: widget.child.allergyNotes);
    _medical = TextEditingController(text: widget.child.medicalNotes);
    _pickup = TextEditingController(text: widget.child.pickupNotes);
  }

  @override
  void dispose() {
    _allergies.dispose();
    _medical.dispose();
    _pickup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.child.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _allergies,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _medical,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Medical Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pickup,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Pickup Instructions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _saving = true);
                      await widget.onSave({
                        'allergyNotes': _allergies.text.trim(),
                        'medicalNotes': _medical.text.trim(),
                        'pickupNotes': _pickup.text.trim(),
                      });
                      if (!mounted) return;
                      setState(() => _saving = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('${widget.child.fullName} updated.'),
                        ),
                      );
                    },
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Child Info'),
            ),
          ],
        ),
      ),
    );
  }
}

class ContractPage extends StatefulWidget {
  const ContractPage({super.key, required this.contextData, required this.uid});

  final ParentContext contextData;
  final String uid;

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> {
  final _signName = TextEditingController();
  final _notes = TextEditingController();
  List<Offset?> _signaturePoints = <Offset?>[];
  bool _accepted = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _signName.dispose();
    _notes.dispose();
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
          _notes.text = (contract['notes'] ?? '').toString();
          _signaturePoints = _decodeSignaturePoints(
            contract['signaturePoints'] as List<dynamic>?,
          );
          _initialized = true;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parent Contract',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('Review and accept daycare contract terms.'),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _accepted,
                      title: const Text('I accept the current contract terms'),
                      onChanged: (value) => setState(() => _accepted = value),
                    ),
                    TextField(
                      controller: _signName,
                      decoration: const InputDecoration(
                        labelText: 'Signature Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Contract Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Finger Signature',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _signaturePoints = <Offset?>[]),
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SignaturePad(
                      points: _signaturePoints,
                      onChanged: (next) =>
                          setState(() => _signaturePoints = next),
                    ),
                    const SizedBox(height: 12),
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
                                    'notes': _notes.text.trim(),
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
                                const SnackBar(
                                  content: Text('Contract information saved.'),
                                ),
                              );
                            },
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Contract'),
                    ),
                  ],
                ),
              ),
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
      ..color = const Color(0xFF0F766E)
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.contextData, required this.uid});

  final ParentContext contextData;
  final String uid;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEmail = true;
  bool _notificationsSms = false;
  String _language = 'English';
  bool _initialized = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ParentRepository().watchParentDoc(widget.contextData),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final settings =
            (data['parentAppSettings'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};

        if (!_initialized) {
          _notificationsEmail = settings['notificationsEmail'] != false;
          _notificationsSms = settings['notificationsSms'] == true;
          _language = (settings['preferredLanguage'] ?? 'English').toString();
          _initialized = true;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _notificationsEmail,
                      title: const Text('Email Notifications'),
                      onChanged: (value) =>
                          setState(() => _notificationsEmail = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _notificationsSms,
                      title: const Text('SMS Notifications'),
                      onChanged: (value) =>
                          setState(() => _notificationsSms = value),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: const InputDecoration(
                        labelText: 'Preferred Language',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'English',
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: 'Spanish',
                          child: Text('Spanish'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _language = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
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
                                  'parentAppSettings': {
                                    'notificationsEmail': _notificationsEmail,
                                    'notificationsSms': _notificationsSms,
                                    'preferredLanguage': _language,
                                  },
                                },
                              );
                              if (!mounted) return;
                              setState(() => _saving = false);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Settings saved.'),
                                ),
                              );
                            },
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
      'https://firestore.googleapis.com/v1/projects/liisgo-daycare-system/databases/(default)/documents/parent_memberships/$authUid',
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

  Future<void> updateChildInfo({
    required ParentContext contextData,
    required String childId,
    required String uid,
    required Map<String, dynamic> changes,
  }) async {
    await _db
        .collection('tenants')
        .doc(contextData.tenantId)
        .collection('children')
        .doc(childId)
        .set({
          ...changes,
          'parentUpdatedAt': FieldValue.serverTimestamp(),
          'parentUpdatedByUid': uid,
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

class _VersionBar extends StatelessWidget {
  const _VersionBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: const Color(0xFFE6F2EF),
      child: Text(
        'Parent App Version: v$_appVersion',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Parent Portal Login',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with your parent account',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
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
                    CheckboxListTile(
                      value: _rememberLogin,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Remember login'),
                      onChanged: (value) {
                        setState(() => _rememberLogin = value ?? false);
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Log In'),
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
