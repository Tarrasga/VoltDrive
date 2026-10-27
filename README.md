# VoltDrive ⚡ - O Assistente Definitivo TVDE para Veículos Elétricos

**VoltDrive** é uma aplicação nativa Android desenvolvida em **Flutter** criada especialmente para motoristas TVDE (Uber e Bolt em Portugal) que operam veículos 100% elétricos (VE).

---

## 🚀 Funcionalidades Principais

### 1. ⚡ Simulador Rápido de Viagem (Compensa ou Não Compensa?)
* **Cálculo Instantâneo**: Introduz o valor proposto na Uber/Bolt e os quilómetros.
* **Margem Real no Bolso**:
  - Deduz automaticamente a taxa da plataforma (25%) e comissão de frota (se aplicável).
  - Calcula o gasto de eletricidade da viagem com base no consumo do teu carro (ex: 15.5 kWh/100km) e preço do kWh.
  - Deduz portagens (Via Verde).
* **Veredito Visual com Cores de Alto Contraste**:
  - 🟢 **Excelente Viagem** (> 0.85 €/km líquido)
  - 🟡 **Viagem Rentável** (0.55 € - 0.85 €/km líquido)
  - 🟠 **Margem Baixa / Atenção** (< 0.55 €/km líquido)
  - 🔴 **Não Compensa (Prejuízo)** (custo superior ao ganho)
* Mostra Lucro Líquido Real, Lucro por KM (€/km) e Ritmo por Hora (€/h).

### 2. 🔌 Postos de Carregamento VE (Rede Mobi.E & Privados)
* Base de dados dos principais hubs de carregamento em Portugal (Lisboa, Porto, Coimbra, Braga, Faro, autoestradas).
* Filtros por velocidade:
  - **Ultrarrápido (100 kW - 350 kW)**: para cargas rápidas de 10 a 15 min.
  - **Rápido (50 kW - 90 kW)**: 20 a 30 min.
  - **Normal AC (22 kW)**: para paragens longas ou almoço.
* **Simulador de Carga Integrado**:
  - Escolhe a percentagem atual da bateria e pretendida (ex: 20% a 80%).
  - Estima os minutos de paragem e o custo em euros no posto público vs. em casa.
  - Atalho para abrir no GPS (Waze / Google Maps).

### 3. 📊 Fecho do Dia / Balanço do Turno
* Registo simples no fim do turno:
  - Faturação Uber Bruta + Faturação Bolt Bruta + Gorjetas (100% tuas).
  - Km totais percorridos (para apurar km faturados vs. km em vazio).
  - Gastos em carregamento (€ e kWh) e portagens.
* **Cálculo em Tempo Real**:
  - Lucro Líquido Real do Dia.
  - Média ganha por quilómetro rodado (€/km).
  - Média ganha por hora de trabalho (€/h).
  - Comparativo com a tua **Meta Diária** (ex: 120€/dia).

### 4. 📈 Histórico e Estatísticas Acumuladas
* Consulta os teus dias anteriores.
* Totais acumulados da semana e do mês (Total Faturado, Total Gastos, Lucro Líquido Total, Médias).

### 5. ⚙️ Definições do Veículo & Tarifas
* Presets para modelos elétricos comuns em TVDE:
  - Tesla Model 3 / Y
  - MG4 Electric
  - Renault Megane E-Tech
  - BYD Atto 3
  - Kia Niro EV / Hyundai Kona
  - Nissan Leaf
* Configuração do preço da eletricidade em casa (€/kWh) e nos postos de rua (€/kWh).

---

## 📱 Como Executar e Gerar o APK para o Android

### Pré-requisitos
1. **Flutter SDK**: Descarrega o Flutter para Windows em [flutter.dev](https://docs.flutter.dev/get-started/install/windows/mobile).
2. **Android Studio**: Instala o Android Studio com o Android SDK e Command-line Tools.

### Passos de Instalação:
1. Abre o terminal nesta pasta (`e:\VoltDrive`).
2. Descarrega as dependências:
   ```bash
   flutter pub get
   ```
3. Para testar diretamente com o teu telemóvel Android ligado por cabo USB:
   - Ativa a **Depuração USB** (USB Debugging) nas opções de programador do Android.
   - Executa:
     ```bash
     flutter run
     ```
4. Para gerar o ficheiro **APK** instalável:
   ```bash
   flutter build apk --release
   ```
   O ficheiro APK pronto a instalar fica guardado em:
   `build/app/outputs/flutter-apk/app-release.apk`
   Basta enviares este ficheiro para o teu telemóvel (por WhatsApp, Telegram ou Google Drive) e instalar!
