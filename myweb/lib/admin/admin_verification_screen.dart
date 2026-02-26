import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/auth_service.dart';
import '../services/verification_service.dart';

/// Admin screen for reviewing and managing user verification documents.
///
/// This is a completely NEW screen — it does NOT modify the existing
/// AdminDashboardScreen or any other admin screens.
class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _filter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVerificationList();
  }

  Future<void> _loadVerificationList() async {
    final adminId = AuthService.currentUser?.uid;
    if (adminId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await VerificationService.getVerificationList(adminId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _users = List<Map<String, dynamic>>.from(result['users'] ?? []);
        } else {
          _errorMessage = result['error'] ?? 'Failed to load verification list.';
        }
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_filter == 'all') return _users;
    return _users
        .where((u) => u['verificationStatus'] == _filter)
        .toList();
  }

  Future<void> _verifyUser(String userId, String action) async {
    final adminId = AuthService.currentUser?.uid;
    if (adminId == null) return;

    final result = await VerificationService.verifyUser(
      userId: userId,
      action: action,
      adminId: adminId,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${action == 'approved' ? 'approved' : 'rejected'} successfully.'),
            backgroundColor: action == 'approved' ? Colors.green : Colors.orange,
          ),
        );
        _loadVerificationList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Action failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Verification'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadVerificationList,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final counts = {
      'all': _users.length,
      'pending': _users.where((u) => u['verificationStatus'] == 'pending').length,
      'approved': _users.where((u) => u['verificationStatus'] == 'approved').length,
      'rejected': _users.where((u) => u['verificationStatus'] == 'rejected').length,
    };

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', counts['all']!),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending', counts['pending']!),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', 'approved', counts['approved']!),
                const SizedBox(width: 8),
                _buildFilterChip('Rejected', 'rejected', counts['rejected']!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: _getFilterColor(value).withOpacity(0.2),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Color _getFilterColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.indigo;
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVerificationList,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredUsers;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _filter == 'all'
                  ? 'No verification documents submitted yet.'
                  : 'No ${_filter} verifications.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildUserVerificationCard(filtered[index]);
      },
    );
  }

  Widget _buildUserVerificationCard(Map<String, dynamic> user) {
    final status = user['verificationStatus'] as String? ?? 'unknown';
    final statusColor = _getFilterColor(status);
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final isMobile = MediaQuery.of(context).size.width <= 640;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: statusColor.withOpacity(0.1),
                  side: BorderSide(color: statusColor.withOpacity(0.3)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Meta info
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (user['phone'] != null && (user['phone'] as String).isNotEmpty)
                  _buildInfoChip(Icons.phone, user['phone']),
                if (user['role'] != null && (user['role'] as String).isNotEmpty)
                  _buildInfoChip(Icons.person, user['role']),
                if (user['institution'] != null &&
                    (user['institution'] as String).isNotEmpty)
                  _buildInfoChip(Icons.school, user['institution']),
              ],
            ),
            const SizedBox(height: 12),

            // Document links
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (user['idCardUrl'] != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      _showImageDialog('ID Card', user['idCardUrl']);
                    },
                    icon: const Icon(Icons.badge, size: 16),
                    label: const Text('View ID Card'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  )
                else
                  Chip(
                    label: const Text('No ID Card'),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                if (user['paymentReceiptImageUrl'] != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      _showImageDialog(
                          'Payment Receipt', user['paymentReceiptImageUrl']);
                    },
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('View Receipt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                    ),
                  )
                else
                  Chip(
                    label: const Text('No Receipt'),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),

            // Action buttons (for pending or rejected)
            if (isPending || isRejected) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _confirmAction(
                              user['userId'], 'approved', user['name'] ?? ''),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _confirmAction(
                              user['userId'], 'rejected', user['name'] ?? ''),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _confirmAction(
                              user['userId'], 'rejected', user['name'] ?? ''),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _confirmAction(
                              user['userId'], 'approved', user['name'] ?? ''),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  void _showImageDialog(String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await launchUrlString(imageUrl, webOnlyWindowName: '_blank');
            },
            child: const Text('Open in New Tab'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAction(
      String userId, String action, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action == 'approved' ? 'Approve' : 'Reject'} $userName?'),
        content: Text(
          action == 'approved'
              ? 'This will mark the user\'s documents as verified.'
              : 'This will reject the user\'s documents. They will be asked to reupload.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: action == 'approved' ? Colors.green : Colors.red,
            ),
            child: Text(action == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _verifyUser(userId, action);
    }
  }
}
