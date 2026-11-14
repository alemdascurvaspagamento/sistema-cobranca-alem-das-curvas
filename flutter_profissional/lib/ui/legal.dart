import 'package:flutter/material.dart';

import '../config.dart';
import 'cf_theme.dart';

/// Versão dos textos legais. Muda quando os termos mudarem (fica gravada no cadastro).
const legalVersion = '2026-11-14';

enum LegalDoc { terms, privacy }

class _Item {
  const _Item(this.title, this.body);
  final String title, body;
}

String get _contact => AppConfig.supportEmail;

List<_Item> _items(LegalDoc d) => d == LegalDoc.terms
    ? [
        _Item('1. Quem somos',
            'O Léguno é um aplicativo de agenda e cobrança para profissionais liberais, oferecido por DANIEL BARSOTTINI - ME (empresário individual), CNPJ 21.828.670/0001-70, de São Paulo/SP, daqui em diante “nós” ou “Léguno”. Fale com a gente: daniel@leguno.com.br.'),
        _Item('2. O que o app faz',
            'Ajuda você a organizar agenda, calcular cobranças, acompanhar pagamentos, ganhos e despesas. O app não recebe nem repassa o dinheiro dos seus clientes: o Pix e as cobranças acontecem entre você e eles, fora do app.'),
        _Item('3. Aceite destes termos',
            'Ao criar a conta e marcar “Li e concordo”, você aceita estes Termos e a Política de Privacidade. Guardamos a versão aceita, a data e a hora do aceite. Se os termos mudarem de forma importante, pediremos um novo aceite.'),
        _Item('4. Sua conta',
            'Você é responsável pelas informações que cadastra e por manter a senha em segredo. Cada conta é de uma pessoa. É preciso ter 18 anos ou mais.'),
        _Item('5. Teste grátis e planos',
            'O teste grátis dura 30 dias, sem cartão. Depois, para continuar editando, é preciso assinar um plano. Plano Essencial: R\$ 34,90 por mês ou R\$ 349 por ano, até 15 clientes ativos. Plano Profissional: R\$ 59,90 por mês ou R\$ 599 por ano, clientes ilimitados, agendamento online, confirmação pelo WhatsApp, agenda no Outlook e Google e relatórios. Oferta de fundador: Profissional por R\$ 39,90 por mês, para as primeiras 100 contas que assinarem durante o teste grátis. Quem entra nessa oferta mantém esse preço enquanto a assinatura estiver ativa, sem interrupção.'),
        _Item('6. Pagamento e renovação',
            'A assinatura é cobrada de forma antecipada, pelos meios mostrados na hora de assinar, e renova sozinha pelo mesmo período (mensal ou anual) até você cancelar. Os pagamentos são processados pelo Asaas. Podemos mudar os preços para novas assinaturas. Para quem já assina, avisamos com 30 dias de antecedência e o novo valor só vale na próxima renovação. Se um pagamento falhar, avisamos por e-mail. Sem regularização, a conta passa a ser só para consulta: você continua vendo e baixando seus dados, e nada é apagado.'),
        _Item('7. Cancelamento e devolução',
            'Você pode cancelar quando quiser, sem multa e sem fidelidade. O acesso continua até o fim do período já pago. Por ser uma contratação feita à distância, você pode desistir em até 7 dias depois de assinar e receber o valor de volta por inteiro. Depois disso, não devolvemos valores já pagos de períodos que já começaram, salvo cobrança indevida ou erro nosso.'),
        _Item('8. Dados dos seus clientes',
            'Você decide quais dados dos seus clientes colocar no app (nome, telefone, horários, valores). Para esses dados, você é o responsável e nós somos o operador: tratamos os dados só para prestar o serviço, seguindo o que você faz no app. Você declara que tem o direito de guardar esses dados e que avisou seus clientes. Não cadastre dados de saúde nem anotações clínicas: o app não é prontuário. Usamos fornecedores para operar o app (Supabase, Vercel, Resend e Asaas) e avisaremos você se houver um incidente de segurança que afete seus dados.'),
        _Item('9. Seus dados e a exclusão da conta',
            'Seus dados são seus. Você pode baixar tudo em planilha em Configurações, “Seus dados”. Pode excluir a conta em Ajustes, “Excluir minha conta”, ou pedir pelo e-mail acima. A exclusão apaga seus dados do Léguno. Cópias de segurança do servidor são substituídas em até 30 dias.'),
        _Item('10. O que pode e o que não pode',
            'Você pode usar o app para o seu trabalho. Não pode usá-lo para fins ilegais, tentar acessar dados de outras pessoas, copiar ou revender o app, nem enviar conteúdo ofensivo.'),
        _Item('11. Mensagens e agendamento online',
            'Os e-mails e os links que o app gera em seu nome (como respostas de agendamento) vão para os seus clientes. Você é responsável por usá-los de forma adequada e por ter o contato deles. O app não envia mensagens de WhatsApp sozinho: você confirma o envio.'),
        _Item('12. Propriedade do app',
            'O app, o nome e a marca Léguno são nossos. Você recebe um direito de uso pessoal, não exclusivo e que não pode ser transferido, enquanto durar a sua conta. Os dados que você cadastra continuam sendo seus.'),
        _Item('13. Responsabilidade',
            'Os cálculos do app dependem do que você cadastra. Confira os valores antes de cobrar. O app não substitui contador, nota fiscal ou orientação jurídica. Fazemos o possível para o app funcionar bem, mas não garantimos funcionamento sem interrupções. Quando a lei permitir, nossa responsabilidade fica limitada ao valor que você pagou nos 12 meses anteriores ao problema. Isso não vale nos casos em que a lei não deixa limitar.'),
        _Item('14. Mudanças nos termos',
            'Podemos mudar estes termos. Avisaremos no app ou por e-mail com 30 dias de antecedência antes de mudanças importantes. Se você não concordar, pode cancelar sem custo.'),
        _Item('15. Lei aplicável',
            'Valem as leis do Brasil. Em caso de conflito, vale o foro do domicílio do usuário, como prevê a lei do consumidor.'),
      ]
    : [
        _Item('Quem decide sobre os dados',
            'DANIEL BARSOTTINI - ME (CNPJ 21.828.670/0001-70) é o controlador dos dados da sua conta. '
                'Contato sobre dados: $_contact.'),
        _Item('Que dados guardamos',
            'Da sua conta: nome do negócio, e-mail, profissão, chave Pix e dados de uso. Os dados de uso são só o nome da função usada e o dia (por exemplo, “cadastrou um cliente”), sem nomes, valores ou telefones de clientes. '
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
              Text('Versão $legalVersion', style: CF.body(13, color: CF.muted)),
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
