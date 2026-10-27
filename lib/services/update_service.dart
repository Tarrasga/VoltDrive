import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'assistant_service.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final String publishedAt;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });
}

class UpdateService {
  // Versão atual instalada da app
  static const String currentVersion = '1.0.20';
  static const String repoUrl = 'https://api.github.com/repos/Tarrasga/VoltDrive/releases/latest';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(repoUrl));
      request.headers.set('User-Agent', 'VoltDrive-App');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json = jsonDecode(body);

      final tagName = (json['tag_name'] as String? ?? '').replaceAll('v', '').trim();
      final bodyText = json['body'] as String? ?? 'Novas melhorias e correções.';
      final publishedAt = json['published_at'] as String? ?? '';

      // Procurar o link do APK nos assets
      String apkUrl = 'https://github.com/Tarrasga/VoltDrive/releases/latest';
      final assets = json['assets'] as List<dynamic>?;
      if (assets != null) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.toLowerCase().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String? ?? apkUrl;
            break;
          }
        }
      }

      final isNewer = _isVersionNewer(latest: tagName, current: currentVersion);

      return AppUpdateInfo(
        hasUpdate: isNewer,
        currentVersion: currentVersion,
        latestVersion: tagName.isEmpty ? currentVersion : 'v$tagName',
        downloadUrl: apkUrl,
        releaseNotes: bodyText,
        publishedAt: publishedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isVersionNewer({required String latest, required String current}) {
    if (latest.isEmpty) return false;
    try {
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return latest != current;
    }
  }

  static void showUpdateDialog(BuildContext context, AppUpdateInfo update, {bool manualCheck = false}) {
    if (!update.hasUpdate) {
      if (manualCheck) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ O teu VoltDrive já está na versão mais recente!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.primaryElectric, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryElectric.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded, color: AppTheme.primaryElectric, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Nova Atualização!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Versão atual: ', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                Text('v$currentVersion', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: AppTheme.primaryElectric, size: 14),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    update.latestVersion,
                    style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Novas funcionalidades e melhorias disponíveis para o teu Renault Zoe e turnos TVDE.',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mais Tarde', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await AssistantService.openUrl(update.downloadUrl);
            },
            icon: const Icon(Icons.download_rounded, color: Colors.black, size: 18),
            label: const Text('Atualizar Agora', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
