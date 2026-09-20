import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_sign_in_web;

import '../../../core/services/google_auth_service.dart';
import '../../../core/services/google_sheets_service.dart';

class GoogleConnectionPage extends StatefulWidget {
  const GoogleConnectionPage({super.key});

  @override
  State<GoogleConnectionPage> createState() => _GoogleConnectionPageState();
}

class _GoogleConnectionPageState extends State<GoogleConnectionPage> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  GoogleSignInAccount? _user;
  bool _isAuthorizing = false;
  bool _isReading = false;
  bool _isAuthorized = false;

  List<List<Object?>> _rows = [];

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _user = GoogleAuthService.instance.currentUser;

    _authSubscription =
        GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (!mounted) {
        return;
      }

      if (event is GoogleSignInAuthenticationEventSignIn) {
        setState(() {
          _user = event.user;
          _errorMessage = null;
        });
      }

      if (event is GoogleSignInAuthenticationEventSignOut) {
        setState(() {
          _user = null;
          _isAuthorized = false;
          _rows = [];
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _authorizeSheets() async {
    if (_user == null) {
      return;
    }

    setState(() {
      _isAuthorizing = true;
      _errorMessage = null;
    });

    try {
      await GoogleAuthService.instance.authorizeSheets();

      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthorized = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Google Sheets authorization failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthorizing = false;
        });
      }
    }
  }

  Future<void> _readSheet() async {
    if (!_isAuthorized) {
      return;
    }

    setState(() {
      _isReading = true;
      _errorMessage = null;
    });

    try {
      final rows = await GoogleSheetsService.instance.readDailyAttendance();

      if (!mounted) {
        return;
      }

      setState(() {
        _rows = rows;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not read Google Sheet: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isReading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await GoogleAuthService.instance.signOut();

    if (!mounted) {
      return;
    }

    setState(() {
      _user = null;
      _isAuthorized = false;
      _rows = [];
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Google Sheet Connection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 900,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Sheet Connection',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect your Google account to access the TG attendance spreadsheet.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                _ConnectionCard(
                  user: _user,
                  isAuthorized: _isAuthorized,
                  isAuthorizing: _isAuthorizing,
                  onAuthorize: _authorizeSheets,
                  onSignOut: _signOut,
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  _ErrorCard(
                    message: _errorMessage!,
                  ),
                if (_user != null && !_isAuthorized)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: _InfoCard(
                      title: 'Next step',
                      message:
                          'Your Google account is connected. Authorize Google Sheets access to continue.',
                    ),
                  ),
                if (_isAuthorized) ...[
                  const SizedBox(height: 20),
                  _SheetTestCard(
                    isReading: _isReading,
                    rows: _rows,
                    onRead: _readSheet,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.user,
    required this.isAuthorized,
    required this.isAuthorizing,
    required this.onAuthorize,
    required this.onSignOut,
  });

  final GoogleSignInAccount? user;
  final bool isAuthorized;
  final bool isAuthorizing;
  final VoidCallback onAuthorize;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final connected = user != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            if (!connected)
              Center(
                child: google_sign_in_web.renderButton(),
              )
            else ...[
              Row(
                children: [
                  if (user!.photoUrl != null)
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(
                        user!.photoUrl!,
                      ),
                    )
                  else
                    const CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.person),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user!.displayName ?? 'Google User',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user!.email,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isAuthorized
                        ? Icons.check_circle
                        : Icons.account_circle_outlined,
                    color: isAuthorized
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!isAuthorized)
                    ElevatedButton.icon(
                      onPressed: isAuthorizing ? null : onAuthorize,
                      icon: isAuthorizing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.table_chart_outlined),
                      label: Text(
                        isAuthorizing
                            ? 'Authorizing...'
                            : 'Authorize Google Sheets',
                      ),
                    ),
                  if (isAuthorized)
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Google Sheets authorized',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onSignOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetTestCard extends StatelessWidget {
  const _SheetTestCard({
    required this.isReading,
    required this.rows,
    required this.onRead,
  });

  final bool isReading;
  final List<List<Object?>> rows;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Sheet Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will read the Daily_Attendace sheet from your configured spreadsheet.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: isReading ? null : onRead,
              icon: isReading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                isReading ? 'Reading...' : 'Read Daily Attendance',
              ),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '${rows.length} rows received',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: List.generate(
                        rows.first.length,
                        (index) => DataColumn(
                          label: Text(
                            rows.first[index]?.toString() ?? '',
                          ),
                        ),
                      ),
                      rows: rows.skip(1).take(20).map((row) {
                        return DataRow(
                          cells: List.generate(
                            rows.first.length,
                            (index) => DataCell(
                              Text(
                                index < row.length
                                    ? row[index]?.toString() ?? ''
                                    : '',
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.withValues(alpha: 0.06),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.withValues(alpha: 0.06),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
    );
  }
}
