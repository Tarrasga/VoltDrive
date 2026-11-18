import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_suggestion.dart';
import '../services/assistant_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  List<AppSuggestion> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final list = await StorageService.loadAppSuggestions();
    if (mounted) {
      setState(() {
        _suggestions = list;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getCategoryColor(String category) {
    if (category.contains('Ideia')) return AppTheme.accentGreen;
    if (category.contains('Melhoria')) return AppTheme.primaryElectric;
    if (category.contains('Erro')) return AppTheme.dangerRed;
    return AppTheme.warningAmber;
  }

  void _openCreateDialog() {
    String selectedCategory = '💡 Nova Funcionalidade';
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_rounded, color: AppTheme.accentGreen, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Nova Sugestão para a App',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'A tua opinião é essencial! Descreve uma nova função, melhoria ou erro:',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),

                // Categorias
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '💡 Nova Funcionalidade',
                    '⚡ Melhoria TVDE',
                    '🐛 Reportar Erro',
                    '🚗 Zoe / Bateria',
                  ].map((cat) {
                    final isSelected = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white)),
                      selected: isSelected,
                      selectedColor: _getCategoryColor(cat),
                      backgroundColor: AppTheme.darkSurface,
                      onSelected: (val) {
                        if (val) setModalState(() => selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título da Sugestão',
                    hintText: 'Ex: Adicionar cálculo de portagens Via Verde',
                    prefixIcon: Icon(Icons.title, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descrição / Detalhes',
                    hintText: 'Explica o que gostarias de ver ou qual foi o problema encontrado...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'O teu Nome / Contacto (Opcional)',
                    hintText: 'Ex: João (Condutor Lisboa)',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 18),

                // Botões de ação
                Row(
                  children: [
                    // Guardar localmente
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (titleCtrl.text.trim().isEmpty && descCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor, escreve pelo menos um título ou descrição.')),
                            );
                            return;
                          }
                          final suggestion = AppSuggestion(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleCtrl.text.trim().isEmpty ? selectedCategory : titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            category: selectedCategory,
                            author: nameCtrl.text.trim(),
                            createdAt: DateTime.now(),
                            sentViaWhatsApp: false,
                          );
                          await StorageService.saveAppSuggestion(suggestion);
                          if (mounted) {
                            Navigator.pop(ctx);
                            _loadSuggestions();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Sugestão guardada na tua pasta!'),
                                backgroundColor: AppTheme.accentGreen,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.folder_special, size: 18, color: AppTheme.primaryElectric),
                        label: const Text('Guardar na Pasta', style: TextStyle(color: AppTheme.primaryElectric, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryElectric),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Enviar por WhatsApp
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (titleCtrl.text.trim().isEmpty && descCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor, escreve pelo menos um título ou descrição.')),
                            );
                            return;
                          }

                          final suggestion = AppSuggestion(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleCtrl.text.trim().isEmpty ? selectedCategory : titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            category: selectedCategory,
                            author: nameCtrl.text.trim(),
                            createdAt: DateTime.now(),
                            sentViaWhatsApp: true,
                          );

                          await StorageService.saveAppSuggestion(suggestion);
                          if (mounted) {
                            Navigator.pop(ctx);
                            _loadSuggestions();
                          }

                          // Formatar mensagem para WhatsApp
                          final waMessage = StringBuffer()
                            ..writeln('💡 *SUGESTÃO / FEEDBACK VOLTDRIVE*')
                            ..writeln('📂 Categoria: $selectedCategory')
                            ..writeln('📌 Título: ${suggestion.title}')
                            ..writeln()
                            ..writeln('📝 Detalhes:')
                            ..writeln(suggestion.description);
                          if (suggestion.author.isNotEmpty) {
                            ..writeln()
                            ..writeln('👤 De: ${suggestion.author}');
                          }
                          ..writeln()
                          ..writeln('⚡ VoltDrive v${UpdateService.currentVersion}');

                          await AssistantService.shareWhatsApp(phone: '', message: waMessage.toString());
                        },
                        icon: const Icon(Icons.chat_bubble, size: 18, color: Colors.white),
                        label: const Text('Enviar WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
  }

  void _sendSuggestionViaWhatsApp(AppSuggestion s) async {
    final waMessage = StringBuffer()
      ..writeln('💡 *SUGESTÃO VOLTDRIVE*')
      ..writeln('📂 Categoria: ${s.category}')
      ..writeln('📌 Título: ${s.title}')
      ..writeln()
      ..writeln('📝 Detalhes:')
      ..writeln(s.description);
    if (s.author.isNotEmpty) {
      ..writeln()
      ..writeln('👤 De: ${s.author}');
    }
    ..writeln()
    ..writeln('⚡ VoltDrive v${UpdateService.currentVersion}');

    await AssistantService.shareWhatsApp(phone: '', message: waMessage.toString());
  }

  void _copySuggestionText(AppSuggestion s) {
    final text = '${s.category}: ${s.title}\n\n${s.description}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Sugestão copiada para a área de transferência!'),
        backgroundColor: AppTheme.accentGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteSuggestion(AppSuggestion s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Eliminar Sugestão?'),
        content: Text('Tens a certeza que queres eliminar "${s.title}" da tua pasta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteAppSuggestion(s.id);
      _loadSuggestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: AppTheme.primaryElectric, size: 22),
            SizedBox(width: 8),
            Text('Pasta de Sugestões'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.accentGreen),
            tooltip: 'Escrever Nova Sugestão',
            onPressed: _openCreateDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryElectric))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Cartão informativo de topo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryElectric.withOpacity(0.18),
                        AppTheme.darkCard,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppTheme.accentGreen, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Ajuda a Inovar o VoltDrive!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tens alguma ideia de melhoria para o teu dia a dia TVDE, cálculo de consumos Zoe, ou encontraste algum erro? Envia diretamente por WhatsApp para ser incluído nas próximas versões!',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openCreateDialog,
                          icon: const Icon(Icons.edit_note, color: Colors.black),
                          label: const Text(
                            'Escrever Nova Sugestão / Ideia',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Título da lista
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Sugestões Guardadas na Pasta',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: Text(
                            '${_suggestions.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryElectric),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_suggestions.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.folder_open, size: 48, color: AppTheme.textMuted.withOpacity(0.6)),
                          const SizedBox(height: 12),
                          const Text(
                            'A pasta de sugestões está vazia.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Usa o botão acima para registar a tua primeira ideia ou melhoria para a app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._suggestions.map((s) {
                    final catColor = _getCategoryColor(s.category);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: catColor.withOpacity(0.5)),
                                ),
                                child: Text(
                                  s.category,
                                  style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                _formatDate(s.createdAt),
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          if (s.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              s.description,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.35),
                            ),
                          ],
                          if (s.author.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Autor: ${s.author}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ],
                          const Divider(color: AppTheme.darkBorder, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18, color: AppTheme.textMuted),
                                tooltip: 'Copiar Texto',
                                onPressed: () => _copySuggestionText(s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.dangerRed),
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteSuggestion(s),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _sendSuggestionViaWhatsApp(s),
                                icon: const Icon(Icons.chat_bubble, size: 14, color: Colors.white),
                                label: const Text('Enviar WhatsApp', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
