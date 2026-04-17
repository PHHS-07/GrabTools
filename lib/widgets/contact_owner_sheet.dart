import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tool_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/chat_screen.dart';
import '../services/users_service.dart';

Future<void> showContactOwnerSheet(BuildContext context, Tool tool) async {
  final owner = await UsersService().getUser(tool.ownerId);
  if (!context.mounted) return;
  await showContactUserSheet(
    context: context,
    tool: tool,
    user: owner,
    heading: 'Contact Owner',
    personLabel: 'Owner',
    missingUserMessage: 'Owner details are not available',
    copiedNumberMessage: 'Owner contact number copied',
    callTitle: 'Call Owner',
    signInChatMessage: 'Please sign in to chat with the owner',
    missingPhoneMessage: 'Owner mobile number is not available',
  );
}

Future<void> showContactUserSheet({
  required BuildContext context,
  required Tool tool,
  required AppUser? user,
  required String heading,
  required String personLabel,
  required String missingUserMessage,
  required String copiedNumberMessage,
  required String callTitle,
  required String signInChatMessage,
  required String missingPhoneMessage,
}) async {
  if (!context.mounted) return;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(missingUserMessage)),
    );
    return;
  }

  final phone = user.phoneNumber?.trim() ?? '';
  final currentUserId = context.read<AuthProvider>().user?.uid;

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Tool: ${tool.title}'),
                Text('$personLabel: ${user.username ?? user.email}'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: phone.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await _showCallOptions(
                                  context: context,
                                  phone: phone,
                                  copiedNumberMessage: copiedNumberMessage,
                                  callTitle: callTitle,
                                );
                              },
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _showChatOptions(
                            context: context,
                            tool: tool,
                            user: user,
                            currentUserId: currentUserId,
                            phone: phone,
                            signInChatMessage: signInChatMessage,
                            missingPhoneMessage: missingPhoneMessage,
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Chat'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showCallOptions({
  required BuildContext context,
  required String phone,
  required String copiedNumberMessage,
  required String callTitle,
}) async {
  await Clipboard.setData(ClipboardData(text: phone));
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(copiedNumberMessage)),
  );

  final callApps = <_ExternalActionApp>[];
  final telUri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(telUri)) {
    callApps.add(
      _ExternalActionApp(
        label: 'Choose Dialer App',
        icon: Icons.call,
        uri: telUri,
      ),
    );
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              callTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('Mobile: $phone'),
            const SizedBox(height: 6),
            const Text(
              'Your device will show the available dialer or caller apps. Choose one to continue.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            if (callApps.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No dialer or caller app is available on this device. The number has been copied.'),
              ),
            ...callApps.map(
              (app) => ListTile(
                leading: Icon(app.icon),
                title: Text(app.label),
                subtitle: const Text('Open the system chooser for available dialer apps'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _launchExternalUri(
                    parentContext: context,
                    uri: app.uri,
                    failureMessage: 'No dialer or caller app available',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showChatOptions({
  required BuildContext context,
  required Tool tool,
  required AppUser user,
  required String? currentUserId,
  required String phone,
  required String signInChatMessage,
  required String missingPhoneMessage,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Chat Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('In App'),
              subtitle: const Text('Use the built-in GrabTools chat'),
              onTap: () {
                if (currentUserId == null) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(signInChatMessage)),
                  );
                  return;
                }
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(tool: tool, owner: user),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Other'),
              subtitle: Text(
                phone.isEmpty
                    ? missingPhoneMessage
                    : 'Continue with available apps using the mobile number',
              ),
              onTap: phone.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _showExternalChatApps(
                        context: context,
                        phone: phone,
                      );
                    },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showExternalChatApps({
  required BuildContext context,
  required String phone,
}) async {
  final apps = [
    _ExternalActionApp(
      label: 'WhatsApp',
      icon: Icons.chat,
      uri: Uri.parse('https://wa.me/${_digitsOnly(phone)}'),
    ),
    _ExternalActionApp(
      label: 'Messages',
      icon: Icons.send,
      uri: Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': 'Hi'},
      ),
    ),
    _ExternalActionApp(
      label: 'SMS',
      icon: Icons.sms_outlined,
      uri: Uri(
        scheme: 'sms',
        path: phone,
      ),
    ),
  ];

  final availableApps = <_ExternalActionApp>[];
  for (final app in apps) {
    if (await canLaunchUrl(app.uri)) {
      availableApps.add(app);
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Continue With',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('Mobile: $phone'),
            const SizedBox(height: 10),
            if (availableApps.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No compatible external messaging app is available on this device.'),
              ),
            ...availableApps.map(
              (app) => ListTile(
                leading: Icon(app.icon),
                title: Text(app.label),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _launchExternalUri(
                    parentContext: context,
                    uri: app.uri,
                    failureMessage: '${app.label} is not available on this device',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _launchExternalUri({
  required BuildContext parentContext,
  required Uri uri,
  required String failureMessage,
}) async {
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      parentContext.mounted) {
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(content: Text(failureMessage)),
    );
  }
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

class _ExternalActionApp {
  final String label;
  final IconData icon;
  final Uri uri;

  const _ExternalActionApp({
    required this.label,
    required this.icon,
    required this.uri,
  });
}
