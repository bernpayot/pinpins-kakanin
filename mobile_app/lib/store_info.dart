import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';

/// Store details shared with the Shopify theme (pin2/config/settings_data.json).
class StoreInfo {
  static const name = 'Neneng and Andy Kakanin Store';
  static const phone = '0918 408 6461';
  static const address = '137 Malagasang 2-A, Imus, Cavite';
  static final messenger = Uri.parse(
    'https://www.facebook.com/messages/t/118804457802615',
  );
  static final facebook = Uri.parse(
    'https://www.facebook.com/profile.php?id=100090118340170',
  );

  static Uri sms(String body) => Uri(
    scheme: 'sms',
    path: phone.replaceAll(' ', ''),
    queryParameters: {'body': body},
  );

  static Uri get call => Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
}

/// Links are overridable so widget tests never leave the app.
typedef LinkOpener = Future<bool> Function(Uri uri);

LinkOpener openLink = (uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> openLinkOrWarn(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await openLink(uri);
  } catch (_) {}
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $uri')));
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({this.size = 44, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/logo.png',
    width: size,
    height: size,
    semanticLabel: '${StoreInfo.name} logo',
    errorBuilder: (_, _, _) => LeafMark(size: size),
  );
}

/// Replaces the old AppBar: scrolls away with the page.
class BrandHeader extends StatelessWidget {
  const BrandHeader({this.trailing, super.key});
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
    child: Row(
      children: [
        const BrandLogo(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            StoreInfo.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class MessengerCard extends StatelessWidget {
  const MessengerCard({
    this.title = 'Questions before you pay?',
    this.text =
        'Chat with the family on Messenger — we reply before you check out.',
    super.key,
  });
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x0F1859B7),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0x381859B7)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openLinkOrWarn(context, StoreInfo.messenger),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF1859B7),
              foregroundColor: Colors.white,
              child: Icon(Icons.chat_bubble_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: PinpinsColors.brown,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(text, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Color(0xFF1859B7)),
          ],
        ),
      ),
    ),
  );
}

/// Store footer, like the website's: policy, report, contact links.
class StoreFooter extends StatelessWidget {
  const StoreFooter({required this.onOpenHelp, super.key});
  final void Function(HelpTopic topic) onOpenHelp;

  @override
  Widget build(BuildContext context) {
    const cream = TextStyle(color: PinpinsColors.cream);
    Widget link(String label, IconData icon, VoidCallback onTap) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: PinpinsColors.gold, size: 20),
      title: Text(label, style: cream.copyWith(fontWeight: FontWeight.w800)),
      onTap: onTap,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PinpinsColors.deepLeaf,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogo(size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  StoreInfo.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: PinpinsColors.cream),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'A home kitchen in Imus, Cavite, steaming Sapin-Sapin, Puto, Kutsinta, and Maha for 25 years.',
            style: TextStyle(color: PinpinsColors.cream, fontSize: 13),
          ),
          const SizedBox(height: 6),
          link(
            'Cancellation and refund policy',
            Icons.shield_outlined,
            () => openRefundPolicy(context),
          ),
          link(
            'Report an order problem',
            Icons.report_gmailerrorred_outlined,
            () => onOpenHelp(HelpTopic.problem),
          ),
          link(
            'Contact us',
            Icons.mail_outline,
            () => onOpenHelp(HelpTopic.question),
          ),
          link(
            'Chat on Messenger',
            Icons.chat_bubble_outline,
            () => openLinkOrWarn(context, StoreInfo.messenger),
          ),
          const Divider(color: Color(0x33FFFDF7)),
          Text(
            '© ${DateTime.now().year} ${StoreInfo.name}. Home-based in Imus, Cavite.',
            style: const TextStyle(color: Color(0xAAFFFDF7), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

Future<void> openRefundPolicy(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const RefundPolicyPage()));

class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

  static const clauses = [
    (
      Icons.refresh,
      'When you can cancel',
      'You may request a cancellation and a full refund while your order is still “Order received” — before the kitchen starts buying ingredients or preparing it. Send the request in the Help tab (choose Cancellation request) or on Messenger, with your order number.',
    ),
    (
      Icons.calendar_month_outlined,
      'Once preparation starts',
      'Every tray is cooked for the date you name, so once ingredients have been purchased, preparation has started, or cooking is underway, a change-of-mind cancellation or refund is no longer available.',
    ),
    (
      Icons.report_gmailerrorred_outlined,
      'Wrong, damaged, unsafe, or missing items',
      'Report it on the day you receive it with your order number and clear photos. These reports are always reviewed under your consumer rights, whatever the order stage, and we will offer a replacement or a full or partial refund depending on what happened.',
    ),
    (
      Icons.wallet_outlined,
      'How refunds are paid',
      'QR Ph payments through PayMongo are refunded to the original payment method; timing depends on your bank or e-wallet. Cash on Pickup refunds are arranged with you directly.',
    ),
    (
      Icons.local_shipping_outlined,
      'Lalamove fares and Buy For Me',
      'Lalamove fares and any Buy For Me charge are paid to Lalamove and are separate from your order total. The store cannot refund those amounts.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Refund policy')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
      children: [
        const Eyebrow('Store policy', icon: Icons.shield_outlined),
        const SizedBox(height: 6),
        Text(
          'Cancellation and refund policy',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Everything we sell is cooked to order for the date you choose. This explains when an order can be cancelled, what happens if something goes wrong, and how you will hear about your order.',
        ),
        const SizedBox(height: 14),
        for (final clause in clauses) ...[
          PaperCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(clause.$1, color: PinpinsColors.deepLeaf),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clause.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(clause.$3),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const OrderStatusCard(),
        const SizedBox(height: 12),
        const MessengerCard(
          title: 'Something wrong with your order?',
          text: 'Message us on Messenger with your order number and photos.',
        ),
      ],
    ),
  );
}

class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({super.key});

  static const stages = [
    (
      'Order received',
      'Confirmation email sent. Cancellation is still possible.',
    ),
    (
      'In preparation',
      'Ingredients bought or cooking started. Change-of-mind refunds close.',
    ),
    (
      'Ready for pickup or delivery',
      'We confirm the final time by text or Messenger.',
    ),
    ('Completed', 'Collected or delivered. Report any problem the same day.'),
  ];

  @override
  Widget build(BuildContext context) => PaperCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order status updates',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          'Every update goes to the email you used at checkout. Signed-in customers can also see each order in Account.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (final (index, stage) in stages.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: PinpinsColors.deepLeaf,
                  foregroundColor: PinpinsColors.cream,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.$1,
                        style: const TextStyle(
                          color: PinpinsColors.brown,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(stage.$2, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

enum HelpTopic {
  question('General question'),
  status('Order status update'),
  cancel('Cancellation request'),
  problem('Report a problem');

  const HelpTopic(this.label);
  final String label;
}

/// The Help tab: FAQ, refund policy, and the contact / report form.
class HelpPage extends StatelessWidget {
  const HelpPage({required this.formKey, super.key});
  final GlobalKey<ContactFormState> formKey;

  static const faqs = [
    (
      'How do I pay?',
      'PayMongo supports QR Ph. Cash on Pickup means paying in cash when collecting from the store.',
    ),
    (
      'Is there a minimum order?',
      'None at all. One tub is a real order and we treat it like any other.',
    ),
    (
      'Do you deliver?',
      'We can request a Lalamove rider where coverage is available. Lalamove’s fare is separate. For a large order, message us on Messenger before checkout.',
    ),
    (
      'How far ahead do I need to order?',
      'A day, normally. November 1, December 24, and December 31 need seven days’ notice.',
    ),
    (
      'How will I know my order went through?',
      'Order confirmation and status updates are sent to the email used at checkout.',
    ),
    (
      'Can I change or cancel an order? What is your refund policy?',
      'You may request a cancellation and refund only before the kitchen begins preparing your order. After that, a change-of-mind refund is no longer available.',
    ),
    (
      'What if my order arrives wrong or damaged?',
      'Report it the day you receive it using the form below, with your order number and photos. Wrong, damaged, unsafe, or missing items are always reviewed.',
    ),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
    children: [
      const SafeArea(bottom: false, child: BrandHeader()),
      const Eyebrow('Plan your order', icon: Icons.help_outline),
      const SizedBox(height: 6),
      Text(
        'Pre-order questions, answered',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            for (final faq in faqs)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(faq.$1),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedAlignment: Alignment.centerLeft,
                children: [
                  Text(faq.$2),
                  if (faq.$1.contains('refund') || faq.$1.contains('wrong'))
                    TextButton(
                      onPressed: () => openRefundPolicy(context),
                      child: const Text('Read the full policy'),
                    ),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        margin: EdgeInsets.zero,
        color: const Color(0x2ED59B2D),
        child: ListTile(
          leading: const Icon(
            Icons.shield_outlined,
            color: PinpinsColors.brown,
          ),
          title: const Text('Cancellation and refund policy'),
          subtitle: const Text(
            'Cancel for a full refund before preparation starts. Problems are always reviewed.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openRefundPolicy(context),
        ),
      ),
      const SizedBox(height: 12),
      const OrderStatusCard(),
      const SizedBox(height: 12),
      const MessengerCard(
        title: 'Chat with the family',
        text: 'The fastest way to reach us is Messenger.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openLinkOrWarn(context, StoreInfo.call),
              icon: const Icon(Icons.call_outlined),
              label: const Text(StoreInfo.phone),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openLinkOrWarn(context, StoreInfo.facebook),
              icon: const Icon(Icons.facebook),
              label: const Text('Facebook'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ContactForm(key: formKey),
    ],
  );
}

class ContactForm extends StatefulWidget {
  const ContactForm({super.key});

  @override
  State<ContactForm> createState() => ContactFormState();
}

class ContactFormState extends State<ContactForm> {
  /// People take more than a few seconds to write a message; scripts do not.
  static Duration minimumFillTime = const Duration(seconds: 3);

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _order = TextEditingController();
  final _message = TextEditingController();
  // A field people never see; automated input fills it.
  final _trap = TextEditingController();
  DateTime _openedAt = DateTime.now();
  HelpTopic _topic = HelpTopic.question;
  bool _human = false;
  String? _robotError;

  void selectTopic(HelpTopic topic) => setState(() {
    _topic = topic;
    _openedAt = DateTime.now();
  });

  @override
  void dispose() {
    for (final controller in [_name, _order, _message, _trap]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final tooFast = DateTime.now().difference(_openedAt) < minimumFillTime;
    if (!_human || tooFast || _trap.text.isNotEmpty) {
      setState(
        () => _robotError =
            'Please tick “I’m not a robot”, then send your message again.',
      );
      return;
    }
    setState(() => _robotError = null);
    final body = [
      '${_topic.label} — ${_name.text.trim()}',
      if (_order.text.trim().isNotEmpty) 'Order: ${_order.text.trim()}',
      _message.text.trim(),
    ].join('\n');
    await openLinkOrWarn(context, StoreInfo.sms(body));
  }

  @override
  Widget build(BuildContext context) => PaperCard(
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _topic == HelpTopic.problem
                ? 'Report an order problem'
                : 'Send an inquiry',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _topic == HelpTopic.problem
                ? 'Include your order number. Send photos in the text thread or on Messenger.'
                : 'Your message opens in your texting app, addressed to the family.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<HelpTopic>(
            initialValue: _topic,
            key: ValueKey(_topic),
            decoration: const InputDecoration(
              labelText: 'What can we help with?',
            ),
            items: [
              for (final topic in HelpTopic.values)
                DropdownMenuItem(value: topic, child: Text(topic.label)),
            ],
            onChanged: (value) => setState(() => _topic = value ?? _topic),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _order,
            decoration: const InputDecoration(
              labelText: 'Order number (if applicable)',
              hintText: '#1001',
            ),
            validator: (value) =>
                _topic != HelpTopic.question &&
                    _topic != HelpTopic.status &&
                    (value ?? '').trim().isEmpty
                ? 'Please add your order number'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _message,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Your message'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Please write a message' : null,
          ),
          Offstage(
            child: ExcludeSemantics(
              child: TextField(
                controller: _trap,
                enableInteractiveSelection: false,
              ),
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _human,
            onChanged: (value) => setState(() {
              _human = value ?? false;
              if (_human) _robotError = null;
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('I’m not a robot'),
            secondary: const Icon(
              Icons.verified_user_outlined,
              color: PinpinsColors.deepLeaf,
            ),
          ),
          if (_robotError != null)
            Text(
              _robotError!,
              style: const TextStyle(
                color: Color(0xFF8A2323),
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _send,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send inquiry'),
          ),
          TextButton(
            onPressed: () => openRefundPolicy(context),
            child: const Text('Read the cancellation and refund policy'),
          ),
        ],
      ),
    ),
  );
}
