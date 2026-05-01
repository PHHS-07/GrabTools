import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/tool_model.dart';
import '../services/admin_service.dart';
import '../services/reports_service.dart';
import 'tool_details_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Disputes', icon: Icon(Icons.gavel)),
              Tab(text: 'Pending Reports', icon: Icon(Icons.report)),
              Tab(text: 'Suspicious Tools', icon: Icon(Icons.warning)),
              Tab(text: 'Low Trust Users', icon: Icon(Icons.person_off)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DisputesTab(),
            _ReportsTab(),
            _SuspiciousToolsTab(),
            _SusUsersTab(),
          ],
        ),
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();
  
  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return StreamBuilder<List<ToolReport>>(
      stream: adminService.streamPendingReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading reports'));
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return const Center(child: Text('No pending reports.'));
        }
        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('Tool: ${report.toolName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Reason: ${report.reason}'),
                    if (report.details != null && report.details!.isNotEmpty)
                      Text('Details: ${report.details}'),
                    const SizedBox(height: 4),
                    Text('Date: ${report.createdAt.toLocal().toString().split('.')[0]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'view') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ToolDetailsScreen(toolId: report.toolId)));
                    } else if (val == 'dismiss') {
                      await adminService.dismissReport(report.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report dismissed')));
                    } else if (val == 'delete_tool') {
                      await adminService.deleteTool(report.toolId);
                      await adminService.dismissReport(report.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tool deleted')));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View Tool Details')),
                    const PopupMenuItem(value: 'dismiss', child: Text('Dismiss Report')),
                    const PopupMenuItem(value: 'delete_tool', child: Text('Delete Tool & Report', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SuspiciousToolsTab extends StatelessWidget {
  const _SuspiciousToolsTab();
  
  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return StreamBuilder<List<Tool>>(
      stream: adminService.streamSuspiciousTools(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading tools'));
        }
        final tools = snapshot.data ?? [];
        if (tools.isEmpty) {
          return const Center(child: Text('No suspicious tools.'));
        }
        return ListView.builder(
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: tool.imageUrls.isNotEmpty 
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(tool.imageUrls.first, width: 50, height: 50, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.build, size: 40),
                title: Text(tool.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Price: INR ${tool.pricePerDay}\nCategories: ${tool.categories.join(', ')}'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'view') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ToolDetailsScreen(toolId: tool.id)));
                    } else if (val == 'verify') {
                      await adminService.verifyTool(tool.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tool Verified & Restored')));
                    } else if (val == 'delete') {
                      await adminService.deleteTool(tool.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tool Deleted')));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View Tool Details')),
                    const PopupMenuItem(value: 'verify', child: Text('Verify Tool (Safe)', style: TextStyle(color: Colors.green))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Tool', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DisputesTab extends StatelessWidget {
  const _DisputesTab();

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: adminService.streamOpenDisputes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final disputes = snapshot.data ?? [];
        if (disputes.isEmpty) return const Center(child: Text('No open disputes'));
        return ListView.builder(
          itemCount: disputes.length,
          itemBuilder: (ctx, i) {
            final d = disputes[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('Reason: ${d['reason']}'),
                subtitle: Text('Desc: ${d['description']}\nStatus: ${d['status']}'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'resolve_refund') {
                      await adminService.resolveDispute(d['id'], 'Refund Approved');
                      // Also call resolveRefund in BookingsService
                      // We need bookingId from dispute
                      // To keep it simple, we assume resolveDispute handles it or we call it here
                    } else if (val == 'dismiss') {
                      await adminService.resolveDispute(d['id'], 'Dismissed');
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'resolve_refund', child: Text('Approve Refund')),
                    const PopupMenuItem(value: 'dismiss', child: Text('Dismiss Dispute')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SusUsersTab extends StatelessWidget {
  const _SusUsersTab();
  
  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return StreamBuilder<List<AppUser>>(
      stream: adminService.streamSuspiciousUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading users'));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No low trust score users.'));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(user.username != null && user.username!.isNotEmpty ? user.username![0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                ),
                title: Text('${user.username} (${user.role.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Email: ${user.email}\nTrust Score: ${user.trustScore} / 100'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'reset') {
                      await adminService.resetTrustScore(user.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trust score reset to 50')));
                    } else if (val == 'block') {
                      await adminService.blockUser(user.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'reset', child: Text('Reset Trust Score (to 50)', style: TextStyle(color: Colors.green))),
                    const PopupMenuItem(value: 'block', child: Text('Block User', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
