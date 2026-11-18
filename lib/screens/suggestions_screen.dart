import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_suggestion.dart';
import '../services/assistant_service.dart';
import '../services/feedback_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> with SingleTickerProviderStateMixin {
  List<AppSuggestion> _mySuggestions = [];
  List<AdminIncomingReport> _incomingReports = [];
  TelemetryStats? _stats;

  bool _isLoading = true;
  bool _isLoadingIncoming = false;
  bool _isLoadingStats = false;
  bool _isAdmin = false;

  TabController? _tabController;
  String _incomingFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _isAdmin = FeedbackService.isAdminMode;
    _initTabs();
    _loadAll();

    FeedbackService.unreadAdminReportsCount.addListener(_onUnreadChanged);
  }

  void _initTabs() {
    _tabController?.dispose();
    if (_isAdmin) {
      _tabController = TabController(length: 3, vsync: this);
    } else {
      _tabController = null;
    }
  }

  @override
  void dispose() {
    FeedbackService.unreadAdminReportsCount.removeListener(_onUnreadChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onUnreadChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final my = await StorageService.loadAppSuggestions();
    _mySuggestions = my;

    if (_isAdmin) {
      await _fetchAdminData();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAdminData() async {
    setState(() {
      _isLoadingIncoming = true;
      _isLoadingStats = true;
    });

    final reports = await FeedbackService.fetchIncomingReports();
    final stats = await FeedbackService.fetchTelemetryStats();

    if (mounted) {
      setState(() {
        _incomingReports = reports;
        _stats = stats;
        _isLoadingIncoming = false;
        _isLoadingStats = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getCategoryColor(String category) {
    if (category.contains('Bug') || category.contains('Erro')) return AppTheme.dangerRed;
    if (category.contains('Melhoria')) return AppTheme.primaryElectric;
    if (category.contains('Carro') || category.contains('Bateria')) return AppTheme.warningAmber;
    return AppTheme.accentGreen;
  }

  void _promptToggleAdminMode() {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: Row(
          children: [
            Icon(
              _isAdmin ? Icons.lock_open_rounded : Icons.admin_panel_settings,
              color: AppTheme.accentGreen,
            ),
            const SizedBox(width: 8),
            Text(_isAdmin ? 'Modo Criador Ativo' : 'Acesso do Criador / Admin'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isAdmin
                  ? 'Estás atualmente no Modo Criador. Desejas desativar e voltar à vista normal?'
                  : 'Introduz o código de programador (PIN: 7777) para ver as sugestões dos condutores e as estatísticas de utilizadores:',
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
            if (!_isAdmin) ...[
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'PIN de Criador (7777)',
                  prefixIcon: Icon(Icons.password, color: AppTheme.accentGreen),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_isAdmin) {
                // Desativar
                await FeedbackService.setAdminMode(false);
                setState(() {
                  _isAdmin = false;
                  _initTabs();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modo Criador desativado.')),
                );
              } else {
                // Ativar
                if (pinController.text.trim() == '7777') {
                  await FeedbackService.setAdminMode(true);
                  setState(() {
                    _isAdmin = true;
                    _initTabs();
                  });
                  Navigator.pop(ctx);
                  _fetchAdminData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('👑 Modo Criador / Administrador ativado!'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Código incorreto. O código padrão é 7777.'),
                      backgroundColor: AppTheme.dangerRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAdmin ? AppTheme.dangerRed : AppTheme.accentGreen,
              foregroundColor: Colors.black,
            ),
            child: Text(_isAdmin ? 'Desativar Modo Criador' : 'Entrar como Criador'),
          ),
        ],
      ),
    );
  }

  void _openCreateDialog() {
    String selectedCategory = '💡 Nova Funcionalidade';
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool isSubmitting = false;

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
                          'Escrever Sugestão / Bug',
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
                  'Envia diretamente pela app sem precisar de WhatsApp. O criador recebe uma notificação imediata:',
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
                    '🐛 Reportar Erro (Bug)',
                    '🚗 Carro / Bateria',
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
                  decoration: InputDecoration(
                    labelText: 'Título da Sugestão ou Erro',
                    hintText: selectedCategory.contains('Bug')
                        ? 'Ex: Erro ao calcular valor na Uber'
                        : 'Ex: Adicionar opção de estimativa de portagens',
                    prefixIcon: const Icon(Icons.title, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descrição Detalhada',
                    hintText: 'Explica detalhadamente o que aconteceu ou qual é a ideia de melhoria...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'O teu Nome / Contacto (Opcional)',
                    hintText: 'Ex: João (TVDE Lisboa)',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 18),

                // Botão Principal: Enviar Pela App (Sem WhatsApp!)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (titleCtrl.text.trim().isEmpty && descCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor, escreve pelo menos um título ou descrição.')),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);

                            final success = await FeedbackService.sendReport(
                              title: titleCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              category: selectedCategory,
                              author: nameCtrl.text.trim(),
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadAll();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        success ? Icons.check_circle : Icons.warning_amber_rounded,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          success
                                              ? '✅ Enviado com sucesso ao criador! Notificação entregue na app.'
                                              : '⚠️ Guardado localmente na pasta (sem ligação no momento).',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: success ? AppTheme.accentGreen : AppTheme.warningAmber,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                    icon: isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.send_rounded, color: Colors.black),
                    label: Text(
                      isSubmitting ? 'A Enviar...' : '🚀 Enviar Pela App (Direto ao Criador)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Botões Secundários: Guardar na Pasta & Enviar WhatsApp
                Row(
                  children: [
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
                            sentOnline: false,
                          );
                          await StorageService.saveAppSuggestion(suggestion);
                          if (mounted) {
                            Navigator.pop(ctx);
                            _loadAll();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📁 Guardado apenas na tua pasta pessoal.'),
                                backgroundColor: AppTheme.primaryElectric,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.folder_special, size: 16, color: AppTheme.textMuted),
                        label: const Text('Guardar Local', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.darkBorder),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (titleCtrl.text.trim().isEmpty && descCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor, escreve pelo menos um título ou descrição.')),
                            );
                            return;
                          }
                          final title = titleCtrl.text.trim().isEmpty ? selectedCategory : titleCtrl.text.trim();
                          final desc = descCtrl.text.trim();
                          final author = nameCtrl.text.trim();

                          final suggestion = AppSuggestion(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: title,
                            description: desc,
                            category: selectedCategory,
                            author: author,
                            createdAt: DateTime.now(),
                            sentViaWhatsApp: true,
                            sentOnline: false,
                          );
                          await StorageService.saveAppSuggestion(suggestion);

                          if (mounted) {
                            Navigator.pop(ctx);
                            _loadAll();
                          }

                          final wa = StringBuffer();
                          wa.writeln('💡 *SUGESTÃO / FEEDBACK VOLTDRIVE*');
                          wa.writeln('📂 Categoria: $selectedCategory');
                          wa.writeln('📌 Título: $title');
                          wa.writeln();
                          wa.writeln('📝 Detalhes:');
                          wa.writeln(desc);
                          if (author.isNotEmpty) {
                            wa.writeln();
                            wa.writeln('👤 De: $author');
                          }
                          wa.writeln();
                          wa.writeln('⚡ VoltDrive v${UpdateService.currentVersion}');

                          await AssistantService.shareWhatsApp(phone: '', message: wa.toString());
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF25D366)),
                        label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366), fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
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

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Copiado para a área de transferência!'),
        backgroundColor: AppTheme.accentGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteMySuggestion(AppSuggestion s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Eliminar da Pasta?'),
        content: Text('Tens a certeza que queres eliminar "${s.title}"?'),
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
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = FeedbackService.unreadAdminReportsCount.value;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.lightbulb_rounded, color: AppTheme.accentGreen, size: 22),
            const SizedBox(width: 8),
            Text(_isAdmin ? 'Painel do Criador (Admin)' : 'Sugestões & Bugs'),
          ],
        ),
        actions: [
          // Botão de alternar Modo Criador / Admin
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _isAdmin ? Icons.shield : Icons.admin_panel_settings_outlined,
                  color: _isAdmin ? AppTheme.accentGreen : AppTheme.textMuted,
                ),
                if (_isAdmin && unread > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.dangerRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: _isAdmin ? 'Modo Criador Ativo' : 'Entrar no Modo Criador',
            onPressed: _promptToggleAdminMode,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.accentGreen),
            tooltip: 'Escrever Sugestão / Bug',
            onPressed: _openCreateDialog,
          ),
        ],
        bottom: _isAdmin && _tabController != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.accentGreen,
                labelColor: AppTheme.accentGreen,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.inbox, size: 20),
                        if (unread > 0)
                          Positioned(
                            right: -8,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.dangerRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unread',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    text: 'Recebidos (${_incomingReports.length})',
                  ),
                  const Tab(
                    icon: Icon(Icons.query_stats, size: 20),
                    text: 'Utilizadores',
                  ),
                  Tab(
                    icon: const Icon(Icons.folder, size: 20),
                    text: 'Minha Pasta (${_mySuggestions.length})',
                  ),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryElectric))
          : _isAdmin && _tabController != null
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAdminIncomingTab(),
                    _buildAdminTelemetryTab(),
                    _buildMySuggestionsTab(),
                  ],
                )
              : _buildMySuggestionsTab(),
    );
  }

  // ==========================================
  // TAB 1 (ADMIN): RECEBIDOS DOS CONDUTORES
  // ==========================================
  Widget _buildAdminIncomingTab() {
    if (_isLoadingIncoming) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
    }

    final filtered = _incomingReports.where((r) {
      if (_incomingFilter == 'Bugs') return r.category.contains('Bug') || r.category.contains('Erro');
      if (_incomingFilter == 'Sugestões') return r.category.contains('Funcionalidade') || r.category.contains('Melhoria');
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchAdminData,
      color: AppTheme.accentGreen,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de controle do Criador
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentGreen.withOpacity(0.2),
                  AppTheme.darkCard,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📥 Caixa de Entrada do Criador',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_incomingReports.length} reporte(s) recebidos diretamente pela app sem WhatsApp.',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await FeedbackService.markAllReportsAsRead();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Todos os relatórios marcados como vistos!')),
                    );
                  },
                  icon: const Icon(Icons.done_all, size: 16, color: AppTheme.accentGreen),
                  label: const Text('Limpar Não Lidos', style: TextStyle(color: AppTheme.accentGreen, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filtros
          Row(
            children: ['Todos', 'Bugs', 'Sugestões'].map((f) {
              final sel = _incomingFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f, style: TextStyle(fontSize: 12, color: sel ? Colors.black : Colors.white)),
                  selected: sel,
                  selectedColor: AppTheme.accentGreen,
                  backgroundColor: AppTheme.darkCard,
                  onSelected: (_) => setState(() => _incomingFilter = f),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 48, color: AppTheme.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Nenhum reporte nesta categoria.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Quando os condutores enviarem bugs ou ideias pela app, surgirão aqui em tempo real.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((r) {
              final catColor = _getCategoryColor(r.category);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: r.category.contains('Bug')
                        ? AppTheme.dangerRed.withOpacity(0.6)
                        : AppTheme.darkBorder,
                    width: r.category.contains('Bug') ? 1.5 : 1.0,
                  ),
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
                            border: Border.all(color: catColor.withOpacity(0.6)),
                          ),
                          child: Text(
                            r.category,
                            style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          _formatDate(r.timestamp),
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    if (r.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        r.description,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('👤 ${r.author}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          Text('🚗 ${r.vehicleName}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          Text('📲 v${r.appVersion}', style: const TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _copyText('${r.title}\n${r.description}\n\nAutor: ${r.author}\nCarro: ${r.vehicleName}\nVersão: ${r.appVersion}');
                          },
                          icon: const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                          label: const Text('Copiar', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
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

  // ==========================================
  // TAB 2 (ADMIN): TELEMETRIA & CONTAGEM DE UTILIZADORES
  // ==========================================
  Widget _buildAdminTelemetryTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
    }

    final s = _stats;

    return RefreshIndicator(
      onRefresh: _fetchAdminData,
      color: AppTheme.accentGreen,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryElectric.withOpacity(0.2),
                  AppTheme.darkCard,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.query_stats, color: AppTheme.primaryElectric, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Estatísticas de Utilização da App',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Contagem privada e discreta de condutores ativos através dos pings diários da app (sem estar mencionado nas atualizações).',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cartões Métricas
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accentGreen.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.bolt, color: AppTheme.accentGreen, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        '${s?.active24h ?? 0}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Text(
                        'Condutores Ativos\n(Últimas 24h)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.people_alt, color: AppTheme.primaryElectric, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        '${s?.active7d ?? 0}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Text(
                        'Condutores Ativos\n(Últimos 7 dias)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Distribuição de Carros
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.electric_car, color: AppTheme.warningAmber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Carros TVDE em Circulação',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (s?.carBreakdown.isEmpty ?? true)
                  const Text('Aguardando pings de veículos...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
                else
                  ...s!.carBreakdown.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.darkSurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${e.value}',
                                style: const TextStyle(color: AppTheme.warningAmber, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Versões da Aplicação
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.system_update_rounded, color: AppTheme.accentGreen, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Versões Instaladas pelos Motoristas',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (s?.versionBreakdown.isEmpty ?? true)
                  const Text('Aguardando pings de versões...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
                else
                  ...s!.versionBreakdown.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('VoltDrive v${e.key}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.darkSurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${e.value}',
                                style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: AS MINHAS SUGESTÕES (PASTA LOCAL)
  // ==========================================
  Widget _buildMySuggestionsTab() {
    return ListView(
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
                    'Sugestões & Reportar Erros (Bugs)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Encontraste algum bug ou tens uma ideia para melhorar o teu dia a dia TVDE? Envia diretamente pela app sem precisar de WhatsApp.',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.edit_note, color: Colors.black),
                  label: const Text(
                    'Escrever Sugestão ou Reportar Bug',
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
                  'As Minhas Sugestões Registadas',
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
                    '${_mySuggestions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryElectric),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_mySuggestions.isEmpty)
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
                    'Usa o botão acima para registar uma sugestão ou reportar um bug diretamente pela app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ..._mySuggestions.map((s) {
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
                      Row(
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
                          if (s.sentOnline) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.cloud_done, size: 12, color: AppTheme.accentGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    'Enviado Online',
                                    style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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
                        onPressed: () => _copyText('${s.category}: ${s.title}\n\n${s.description}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.dangerRed),
                        tooltip: 'Eliminar',
                        onPressed: () => _deleteMySuggestion(s),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
