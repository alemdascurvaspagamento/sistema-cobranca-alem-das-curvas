import 'package:flutter/material.dart';

import '../config.dart';
import 'cf_theme.dart';

/// Versão dos textos legais. Muda quando os termos mudarem (fica gravada no cadastro).
const legalVersion = '2026-10-29';

enum LegalDoc { terms, privacy }

class _Item {
  const _Item(this.title, this.body);
  final String title, body;
}

String get _contact => AppConfig.supportContact.contains('@') ? AppConfig.supportContact : 'WhatsApp (11) 99182-7006 ou daniel.barsottini@gmail.com';

List<_Item> _items(LegalDoc d) => d == LegalDoc.terms
    ? [
        _Item('1. Quem somos',
            'O Okday é um aplicativo de agenda e cobrança para profissionais liberais, '
                'oferecido pela Além das Curvas (Daniel Barsottini). Fale com a gente: $_contact.'),
        _Item('2. O que o app faz',
            'Ajuda você a organizar agenda, calcular cobranças, acompanhar pagamentos, ganhos e despesas. '
                'O app não recebe nem repassa dinheiro: o Pix e as cobranças acontecem entre você e os seus clientes, fora do app.'),
        _Item('3. Versão de teste',
            'O app está em fase de testes. Pode ter erros, mudar ou ficar fora do ar. Não use como único registro: '
                'guarde sempre uma cópia (em Configurações, "Seus dados" baixa uma planilha com tudo).'),
        _Item('4. Sua conta',
            'Você é responsável pelas informações que cadastra e por manter a senha em segredo. '
                'Cada conta é de uma pessoa. É preciso ter 18 anos ou mais.'),
        _Item('5. Teste grátis e planos',
            'O teste grátis dura 14 dias. Depois, para continuar editando, é preciso assinar um plano. '
                'Sem assinatura, a conta fica só para consulta e nada é apagado. '
                'Durante a fase de testes, nenhuma cobrança é feita. Os valores dos planos serão informados antes de qualquer cobrança.'),
        _Item('6. O que pode e o que não pode',
            'Você pode usar o app para o seu trabalho. Não pode usá-lo para fins ilegais, tentar acessar dados de outras pessoas, '
                'copiar ou revender o app, nem enviar conteúdo ofensivo.'),
        _Item('7. Responsabilidade',
            'Os cálculos do app dependem do que você cadastra. Confira os valores antes de cobrar. '
                'O app não substitui contador, nota fiscal ou orientação jurídica. Fazemos o possível para o app funcionar bem, '
                'mas não garantimos funcionamento sem interrupções.'),
        _Item('8. Cancelar',
            'Você pode parar de usar e pedir a exclusão da sua conta a qualquer momento, pelo contato acima.'),
        _Item('9. Mudanças',
            'Podemos mudar estes termos. Avisaremos no app ou por e-mail antes de mudanças importantes.'),
        _Item('10. Lei aplicável',
            'Valem as leis do Brasil. Em caso de conflito, vale o foro do domicílio do usuário, como prevê a lei do consumidor.'),
      ]
    : [
        _Item('Quem decide sobre os dados',
            'A Além das Curvas (Daniel Barsottini) é a controladora dos dados da sua conta. '
                'Contato sobre dados: $_contact.'),
        _Item('Que dados guardamos',
            'Da sua conta: nome do negócio, e-mail, profissão, chave Pix e dados de uso. '
                'Sobre os seus clientes, o que você cadastrar: nome, telefone, serviço, horários, valores e pagamentos. '
                'Essas informações são suas: você decide o que cadastrar. Não cadastre dados de saúde nem anotações clínicas; '
                'o app não foi feito para prontuário.'),
        _Item('Para que usamos',
            'Para o app funcionar (agenda, cobrança, relatórios), dar suporte e melhorar o produto. '
                'Não vendemos dados e não os usamos para propaganda.'),
        _Item('Onde ficam',
            'Os dados ficam em servidores de empresas que contratamos: Supabase (banco de dados e login), '
                'Vercel (hospedagem do site) e Resend (envio de e-mails). Alguns ficam fora do Brasil. '
                'Quando as assinaturas forem ativadas, o Asaas processará os pagamentos.'),
        _Item('Seus clientes',
            'Você decide sobre os dados dos seus clientes. Avise-os de que guarda o contato e os horários deles '
                'para organizar o atendimento e a cobrança.'),
        _Item('Segurança',
            'Cada conta só enxerga os próprios dados. O acesso exige senha e a sessão encerra sozinha após 30 minutos '
                'sem uso. Nenhum sistema é 100% seguro; se houver um problema que afete você, avisaremos.'),
        _Item('Seus direitos',
            'Você pode pedir para ver, corrigir, baixar ou apagar seus dados, pelo contato acima. '
                'Em Configurações, "Seus dados" já baixa tudo em planilha. Respondemos em até 15 dias.'),
        _Item('Por quanto tempo guardamos',
            'Enquanto a conta existir. Ao excluir a conta, apagamos os dados, salvo o que a lei obrigar a manter.'),
      ];

/// Página com os termos de uso ou a política de privacidade.
class LegalScreen extends StatelessWidget {
  const LegalScreen(this.doc, {super.key});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final terms = doc == LegalDoc.terms;
    return Scaffold(
      backgroundColor: CF.bg,
      appBar: AppBar(
        title: Text(terms ? 'Termos de uso' : 'Política de privacidade', style: CF.body(18, weight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('Versão $legalVersion · fase de testes', style: CF.body(13, color: CF.muted)),
              const SizedBox(height: 12),
              for (final i in _items(doc)) ...[
                Text(i.title, style: CF.body(17, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(i.body, style: CF.body(15, color: CF.text, height: 1.45)),
                const SizedBox(height: 16),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

void openLegal(BuildContext context, LegalDoc doc) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LegalScreen(doc)));
