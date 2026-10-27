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
  static const String currentVersion = '1.0.27';
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
      if (json['assets'] is List) {
        final assets = json['assets'] as List;
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.toLowerCase().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String? ?? apkUrl;
            break;
          }
        }
      }

      final hasUpdate = _isNewer(tagName, currentVersion);

      return AppUpdateInfo(
        hasUpdate: hasUpdate,
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

  static bool _isNewer(String latest, String current) {
    if (latest.isEmpty || current.isEmpty) return false;
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
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
              'Atualização direta com descarregamento e instalação automática no teu telemóvel.',
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
            onPressed: () {
              Navigator.pop(ctx);
              startAutomaticUpdate(context, update);
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

  // ==========================================
  // ATUALIZAÇÃO AUTOMÁTICA DIRETA NO TELEMÓVEL
  // ==========================================

  static void startAutomaticUpdate(BuildContext context, AppUpdateInfo update) async {
    // Verificar se o Android permite instalar apps desconhecidas
    final canInstall = await AssistantService.canRequestPackageInstalls();
    if (!canInstall && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.primaryElectric),
          ),
          title: const Row(
            children: [
              Icon(Icons.security_update_good, color: AppTheme.primaryElectric),
              SizedBox(width: 8),
              Expanded(
                child: Text('Autorizar Instalação', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: const Text(
            'Para o VoltDrive se atualizar sozinho sem precisares do navegador, autoriza "Permitir desta fonte" nas definições.',
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c, true);
                AssistantService.requestInstallPackagesPermission();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryElectric),
              child: const Text('Abrir Definições', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!context.mounted) return;

    double progress = 0.0;
    int received = 0;
    int total = 0;
    String statusText = 'A ligar aos servidores da atualização...';
    bool isDone = false;
    StateSetter? dialogState;
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        dialogContext = dlgCtx;
        return StatefulBuilder(
          builder: (dlgCtx, setDialogState) {
            dialogState = setDialogState;
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppTheme.accentGreen, width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.cloud_download_rounded, color: AppTheme.accentGreen, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDone ? 'A Instalar Atualização' : 'A Atualizar VoltDrive',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusText, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 8,
                      backgroundColor: AppTheme.darkSurface,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (total > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${(received / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    // Iniciar download
    _executeDownloadAndInstall(
      url: update.downloadUrl,
      onProgress: (p, rec, tot) {
        progress = p;
        received = rec;
        total = tot;
        statusText = 'A descarregar VoltDrive (${(p * 100).toStringAsFixed(0)}%)...';
        dialogState?.call(() {});
      },
      onInstalling: () {
        isDone = true;
        statusText = 'Download concluído! A abrir instalador do Android...';
        dialogState?.call(() {});
      },
      onError: (err) {
        if (dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.pop(dialogContext!);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha no download automático ($err). A abrir navegador...'),
              backgroundColor: AppTheme.warningAmber,
            ),
          );
          AssistantService.openUrl(update.downloadUrl);
        }
      },
      onSuccess: () {
        if (dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.pop(dialogContext!);
        }
      },
    );
  }

  static Future<void> _executeDownloadAndInstall({
    required String url,
    required Function(double progress, int received, int total) onProgress,
    required VoidCallback onInstalling,
    required Function(String error) onError,
    required VoidCallback onSuccess,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      Uri targetUri = Uri.parse(url);
      HttpClientResponse? response;

      // Seguir redirecionamentos do GitHub (302 para S3 CDN)
      for (int i = 0; i < 6; i++) {
        final req = await client.getUrl(targetUri);
        req.headers.set('User-Agent', 'VoltDrive-App');
        response = await req.close();

        if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307) {
          final loc = response.headers.value('location');
          if (loc != null) {
            targetUri = Uri.parse(loc);
            await response.drain();
            continue;
          }
        }
        break;
      }

      if (response == null || response.statusCode != 200) {
        onError('Código HTTP ${response?.statusCode ?? 0}');
        return;
      }

      final totalBytes = response.contentLength;

      // Obter diretoria de cache da aplicação para compatibilidade total com FileProvider
      final cachePath = await AssistantService.getCacheDir();
      final targetDir = (cachePath != null && cachePath.isNotEmpty) ? Directory(cachePath) : Directory.systemTemp;
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final apkFile = File('${targetDir.path}/VoltDrive_Update.apk');
      if (await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }

      final sink = apkFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes, receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();

      onInstalling();

      // Abrir o instalador do sistema Android automaticamente
      final installed = await AssistantService.installApk(apkFile.path);
      if (installed) {
        onSuccess();
      } else {
        onError('Não foi possível iniciar o instalador do Android');
      }
    } catch (e) {
      onError(e.toString());
    }
  }
}
