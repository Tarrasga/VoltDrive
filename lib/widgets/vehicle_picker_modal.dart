import 'package:flutter/material.dart';
import '../models/vehicle_preset.dart';
import '../models/vehicle_profile.dart';
import '../services/assistant_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class VehiclePickerModal {
  static Future<VehicleProfile?> show(
    BuildContext context, {
    String? currentVehicleName,
    void Function(VehicleProfile updatedProfile)? onSelected,
  }) async {
    return showModalBottomSheet<VehicleProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _VehiclePickerContent(
        currentVehicleName: currentVehicleName ?? '',
        onSelected: onSelected,
      ),
    );
  }
}

class _VehiclePickerContent extends StatefulWidget {
  final String currentVehicleName;
  final void Function(VehicleProfile updatedProfile)? onSelected;

  const _VehiclePickerContent({
    required this.currentVehicleName,
    this.onSelected,
  });

  @override
  State<_VehiclePickerContent> createState() => _VehiclePickerContentState();
}

class _VehiclePickerContentState extends State<_VehiclePickerContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedBrand = 'Todos';

  List<String> get _brands {
    final set = <String>{'Todos'};
    for (final p in VehiclePreset.allPresets) {
      set.add(p.brand);
    }
    return set.toList();
  }

  List<VehiclePreset> get _filteredPresets {
    final query = _searchCtrl.text.trim().toLowerCase();
    return VehiclePreset.allPresets.where((p) {
      final matchesBrand = _selectedBrand == 'Todos' || p.brand == _selectedBrand;
      final matchesQuery = query.isEmpty ||
          p.fullName.toLowerCase().contains(query) ||
          p.brand.toLowerCase().contains(query) ||
          p.model.toLowerCase().contains(query);
      return matchesBrand && matchesQuery;
    }).toList();
  }

  Future<void> _selectPreset(VehiclePreset preset) async {
    final existingProfile = await StorageService.loadVehicleProfile();
    final updated = VehicleProfile(
      name: preset.fullName,
      batteryCapacityKwh: preset.batteryCapacityKwh,
      avgConsumptionKwh100: preset.avgConsumptionKwh100,
      maxAcPowerKw: preset.maxAcPowerKw,
      homeKwhPrice: existingProfile.homeKwhPrice,
      publicKwhPrice: existingProfile.publicKwhPrice,
      platformFeePercent: existingProfile.platformFeePercent,
      fleetCommissionPercent: existingProfile.fleetCommissionPercent,
      targetDailyProfit: existingProfile.targetDailyProfit,
    );

    await StorageService.saveVehicleProfile(updated);
    await AssistantService.syncSettings(updated);

    if (widget.onSelected != null) {
      widget.onSelected!(updated);
    }

    if (mounted) {
      Navigator.pop(context, updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚗 Carro selecionado: ${preset.fullName}'),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCustomCarDialog() {
    final nameCtrl = TextEditingController();
    final batteryCtrl = TextEditingController(text: '50.0');
    final consumptionCtrl = TextEditingController(text: '16.0');
    final acPowerCtrl = TextEditingController(text: '11.0');

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tune, color: AppTheme.primaryElectric, size: 22),
            SizedBox(width: 8),
            Text('Carro Personalizado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Introduz os dados do teu veículo elétrico ou híbrido:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Marca e Modelo',
                  hintText: 'Ex: Polestar 2 / Toyota Corolla',
                  prefixIcon: Icon(Icons.directions_car, color: AppTheme.primaryElectric),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: batteryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Capacidade da Bateria (kWh)',
                  hintText: 'Ex: 60.0 (ou 0 se híbrido/combustão)',
                  prefixIcon: Icon(Icons.battery_charging_full, color: AppTheme.accentGreen),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: consumptionCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Consumo Médio (kWh/100km)',
                  hintText: 'Ex: 15.5',
                  prefixIcon: Icon(Icons.speed, color: AppTheme.warningAmber),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: acPowerCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Potência Máx. AC (kW)',
                  hintText: 'Ex: 11 ou 22',
                  prefixIcon: Icon(Icons.electric_bolt, color: AppTheme.primaryElectric),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim().isEmpty ? 'Carro Personalizado TVDE' : nameCtrl.text.trim();
              final battery = double.tryParse(batteryCtrl.text.replaceAll(',', '.')) ?? 50.0;
              final consumption = double.tryParse(consumptionCtrl.text.replaceAll(',', '.')) ?? 16.0;
              final acPower = double.tryParse(acPowerCtrl.text.replaceAll(',', '.')) ?? 11.0;

              Navigator.pop(dlgCtx);
              _selectPreset(VehiclePreset(
                brand: 'Outro',
                model: name,
                fullName: name,
                batteryCapacityKwh: battery,
                avgConsumptionKwh100: consumption,
                maxAcPowerKw: acPower,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            child: const Text('Aplicar & Guardar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredPresets;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de arrasto
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Título e botão de fechar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.directions_car_filled, color: AppTheme.accentGreen, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Escolhe o Teu Carro TVDE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Seleciona a tua viatura para calcular consumos, custos por km e carregamentos com precisão:',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Barra de pesquisa
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Pesquisar modelo (ex: Zoe, Tesla, MG4, Dolphin, Leaf...)',
              prefixIcon: const Icon(Icons.search, color: AppTheme.primaryElectric, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          // Filtro por marcas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _brands.map((brand) {
                final isSelected = _selectedBrand == brand;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(brand, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white)),
                    selected: isSelected,
                    selectedColor: AppTheme.accentGreen,
                    backgroundColor: AppTheme.darkSurface,
                    onSelected: (val) {
                      if (val) setState(() => _selectedBrand = brand);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Lista de modelos
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.car_crash_outlined, size: 40, color: AppTheme.textMuted),
                        const SizedBox(height: 8),
                        Text('Nenhum modelo encontrado para "${_searchCtrl.text}"', style: const TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showCustomCarDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Adicionar Carro Personalizado'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final p = list[i];
                      final isCurrent = widget.currentVehicleName.isNotEmpty &&
                          (widget.currentVehicleName.toLowerCase().contains(p.model.toLowerCase()) ||
                           p.fullName.toLowerCase().contains(widget.currentVehicleName.toLowerCase()));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.accentGreen.withOpacity(0.12)
                              : AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? AppTheme.accentGreen.withOpacity(0.6)
                                : AppTheme.darkBorder,
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          onTap: () => _selectPreset(p),
                          leading: CircleAvatar(
                            backgroundColor: isCurrent
                                ? AppTheme.accentGreen.withOpacity(0.2)
                                : AppTheme.darkSurface,
                            child: Icon(
                              Icons.directions_car,
                              color: isCurrent ? AppTheme.accentGreen : AppTheme.primaryElectric,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isCurrent ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Ativo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildSpecPill('🔋 ${p.batteryCapacityKwh.toStringAsFixed(0)} kWh', AppTheme.accentGreen),
                                _buildSpecPill('⚡ ${p.avgConsumptionKwh100.toStringAsFixed(1)} kWh/100km', AppTheme.primaryElectric),
                                _buildSpecPill('🔌 ${p.maxAcPowerKw.toStringAsFixed(0)} kW AC', AppTheme.warningAmber),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),

          // Botão para carro personalizado
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCustomCarDialog,
              icon: const Icon(Icons.tune, size: 18, color: AppTheme.primaryElectric),
              label: const Text('O teu carro não está na lista? Inserir Manualmente', style: TextStyle(color: AppTheme.primaryElectric, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.darkBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
