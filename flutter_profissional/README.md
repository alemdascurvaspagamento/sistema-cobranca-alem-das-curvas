# Coach Flow Profissional — Flutter

Primeira fundação isolada da versão Flutter (Android, iOS e dashboard web).

## Estado
- Shell responsivo: menu lateral em desktop e navegação inferior no celular.
- Identidade visual: preto, grafite, prata e dourado.
- Seções iniciais: Início, Agenda, Clientes, Financeiro e Mais.
- **Somente demonstração visual**: nenhuma conexão ao banco ou valores reais.
- O Coach Flow pessoal e a versão SaaS web existente permanecem intactos.

## Como executar
Instale Flutter SDK e Android Studio / Xcode conforme plataforma.
No diretório `flutter_profissional`, execute:

```bash
flutter create --platforms=android,ios,web .
flutter pub get
flutter run -d chrome
flutter run -d android
flutter run -d ios
```

O comando `flutter create` gera os diretórios nativos de plataforma; não execute sobre arquivos personalizados sem revisar o diff.

## Próximas etapas
1. Validar SDK e compilação nas três plataformas.
2. Separar arquivos em features, widgets, tema, roteamento e camada de dados.
3. Auditar o backend e a segregação multi-tenant antes de integrar autenticação.
4. Conectar clientes, agenda, cobranças e relatórios, com testes de isolamento.
5. Configurar assinatura iOS, Android e pipeline de builds.
6. Homologar com usuários de teste e publicar somente após validação.

**Nunca incluir segredos de Supabase, tokens ou dados de clientes no repositório.**
