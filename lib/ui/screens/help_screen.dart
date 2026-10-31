import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../widgets/app_card.dart';
import '../widgets/form_sections.dart';
import '../widgets/wanma_logo.dart';

/// Guide rapide intégré, utilisable sans connexion Internet.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guide d’utilisation')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.ink, Color(0xFF1C2C47)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTokens.heroRadius),
              boxShadow: const <BoxShadow>[AppTokens.floatingShadow],
            ),
            child: Row(
              children: <Widget>[
                const WanmaLogo(size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Wanma fonctionne hors ligne',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toutes vos données restent dans une base SQLite '
                        'sur ce téléphone. Aucun compte ni Internet n’est requis.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 11,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Les gestes essentiels'),
          _StepTile(
            number: 1,
            icon: Icons.inventory_2_outlined,
            title: 'Créez vos produits',
            text:
                'Onglet Produits puis bouton « Produit ». Indiquez le prix, '
                'l’unité et le stock initial. Le stock initial crée '
                'automatiquement une entrée justificative.',
          ),
          const SizedBox(height: 10),
          _StepTile(
            number: 2,
            icon: Icons.person_add_alt_1_outlined,
            title: 'Enregistrez vos clients',
            text:
                'Onglet Clients. Le téléphone est conservé comme texte. Un '
                'numéro déjà présent déclenche une confirmation explicite. '
                'Touchez le numéro pour préparer un appel dans le composeur.',
          ),
          const SizedBox(height: 10),
          _StepTile(
            number: 3,
            icon: Icons.arrow_downward_rounded,
            title: 'Approvisionnez le stock',
            text:
                'Depuis l’accueil, touchez « Entrée ». Choisissez le produit, '
                'la quantité et éventuellement le prix d’achat appliqué.',
          ),
          const SizedBox(height: 10),
          _StepTile(
            number: 4,
            icon: Icons.arrow_upward_rounded,
            title: 'Enregistrez une sortie',
            text:
                'Depuis l’accueil, touchez « Sortie ». Sélectionnez un client, '
                'un produit et la quantité. Activez « Vente à crédit » si le '
                'client paie plus tard. Wanma refuse toute sortie supérieure au '
                'stock disponible.',
          ),
          const SizedBox(height: 10),
          _StepTile(
            number: 5,
            icon: Icons.receipt_long_outlined,
            title: 'Consultez et annulez',
            text:
                'L’historique conserve toutes les opérations, regroupées par '
                'journée. Une annulation n’efface rien : elle remet le stock à '
                'niveau et laisse une trace avec son motif.',
          ),
          const SizedBox(height: 10),
          _StepTile(
            number: 6,
            icon: Icons.schedule_rounded,
            title: 'Encaissez les crédits',
            text:
                'Une sortie à crédit reste à recouvrer. Depuis l’accueil, '
                'touchez la carte « Crédits à recouvrer » ou la fiche du client, '
                'puis « Marquer comme payé » dès que le client rembourse.',
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Questions fréquentes'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: const <Widget>[
                _FaqTile(
                  question: 'Mes données peuvent-elles disparaître ?',
                  answer:
                      'Les données sont stockées localement. Créez régulièrement '
                      'une sauvegarde depuis « Outils → Sauvegarde et restauration » '
                      'et conservez le fichier .wanma ailleurs que sur le téléphone.',
                ),
                _FaqTile(
                  question: 'La sauvegarde contient-elle mon code PIN ?',
                  answer:
                      'Non. Le code PIN et son empreinte restent dans les '
                      'préférences sécurisées du téléphone. Après restauration, '
                      'le verrouillage actuel est conservé.',
                ),
                _FaqTile(
                  question:
                      'Pourquoi un produit ne peut-il pas être supprimé ?',
                  answer:
                      'Un produit ou un client lié à des mouvements ne peut pas '
                      'être supprimé, afin que l’historique reste complet et '
                      'cohérent. Vous pouvez annuler les opérations concernées.',
                ),
                _FaqTile(
                  question: 'Comment suivre une vente à crédit ?',
                  answer:
                      'Activez « Vente à crédit » au moment de la sortie. La '
                      'sortie apparaît dans les crédits à recouvrer et sur la '
                      'fiche du client. Quand le client rembourse, ouvrez la '
                      'sortie puis touchez « Marquer comme payé ».',
                ),
                _FaqTile(
                  question: 'Comment exporter mes listes ?',
                  answer:
                      'Depuis « Outils → Exporter les données », choisissez un '
                      'format CSV ou Excel. Vous pouvez enregistrer le fichier '
                      'sur le téléphone ou le partager avec une autre application.',
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const InfoBanner(
            text:
                'Conseil : vérifiez que le stock affiché correspond à votre '
                'inventaire physique au moins une fois par semaine. Un écart '
                'peut être corrigé par une entrée ou une sortie justifiée.',
            icon: Icons.lightbulb_outline_rounded,
            color: AppColors.amberDark,
            backgroundColor: AppColors.amberSoft,
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
  });

  final int number;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.cobaltSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(icon, size: 19, color: AppColors.cobalt),
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.cobalt,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
    this.isLast = false,
  });

  final String question;
  final String answer;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ExpansionTile(
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          iconColor: AppColors.cobalt,
          collapsedIconColor: AppColors.muted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedAlignment: Alignment.centerLeft,
          children: <Widget>[
            Text(
              answer,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.muted,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}
