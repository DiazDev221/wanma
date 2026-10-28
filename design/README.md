# Wanma 2.0 — Direction visuelle

> **« Le calme du commerce bien tenu. »**
>
> Une refonte mobile qui donne la priorité aux chiffres qui comptent, sans perdre la chaleur d’un commerce de proximité.

Maquette : [`wanma-redesign.html`](./wanma-redesign.html) · aperçu : [`wanma-redesign.png`](./wanma-redesign.png)

---

## 1. Intention

L’interface actuelle est fonctionnelle et déjà Material 3, mais elle empile beaucoup de cartes de même poids : quatre indicateurs, une bannière de valeur, quatre actions rapides, deux listes. Le bleu saturé de la barre supérieure et les nombreuses bordures donnent un rendu « tableau de bord administratif » un peu froid.

La nouvelle direction garde les repères de la marque (bleu, jaune, magasin de proximité) mais change le rythme :

- **un seul héros par écran** ;
- **un fond ivoire chaleureux** au lieu du blanc bleuté ;
- **des chiffres très grands**, des unités discrètes ;
- **moins de bordures**, plus d’espace et d’ombre douce ;
- **une navigation flottante** qui laisse respirer le contenu ;
- **des couleurs qui racontent le métier** : entrée = menthe, sortie = corail, alerte = ambre.

Le résultat doit inspirer la confiance d’un carnet de comptes bien tenu, pas la froideur d’un logiciel de gestion.

---

## 2. Trois principes

### 01 · La hiérarchie avant la densité
Une action principale par écran. Les informations secondaires sont regroupées, repliées ou accessibles en un geste. On limite les cartes concurrentes et on laisse respirer les sections.

### 02 · La couleur raconte le mouvement
Menthe pour les entrées, corail pour les sorties, ambre pour l’attention. La couleur ne porte jamais le sens seule : elle est toujours accompagnée d’une icône et d’un libellé.

### 03 · Le chiffre est le héros
Les montants et les quantités sont grands, en Manrope 800, avec des chiffres tabulaires. Les unités et les libellés sont plus petits et plus discrets. On doit pouvoir comparer deux montants d’un seul regard.

---

## 3. Tokens

### Couleurs

| Rôle | Valeur | Usage |
| --- | --- | --- |
| Encre | `#0E1A2B` | Texte principal, carte héros, logo |
| Encre douce | `#22324A` | Texte secondaire fort |
| Cobalt | `#2355F2` | Action principale, sélection, liens |
| Cobalt profond | `#153DB8` | Pression, dégradés |
| Cobalt doux | `#E9EEFF` | Fonds de sélection, résumés |
| Ambre | `#F7B733` | Signature, alertes, accents |
| Ambre doux | `#FFF3D1` | Badges stock faible |
| Ivoire | `#F7F5F0` | Fond d’écran |
| Blanc | `#FFFFFF` | Cartes, champs, navigation |
| Ligne | `#EAE6DD` | Séparateurs, contours fins |
| Texte atténué | `#646B78` | Libellés, métadonnées |
| Menthe | `#0B7A52` / fond `#DFF7EB` | Entrées, stock disponible |
| Corail | `#BE3A4A` / fond `#FFE7E3` | Sorties, ruptures |
| Violet | `#6D5BD0` / fond `#EFEAFF` | Accent client |

Règle : **80 % neutre, 15 % cobalt, 5 % ambre/couleurs métier**. L’ambre ne doit pas être utilisé comme texte sur blanc sans variante foncée (`#9A6500`).

### Typographie

**Manrope** (SIL Open Font License), embarquée dans l’application pour rester 100 % hors ligne.

| Style | Taille / graisse | Usage |
| --- | --- | --- |
| Display | 30–34 / 800 / `-0.045em` | Montant du stock, total d’une opération |
| Titre d’écran | 25 / 800 / `-0.045em` | « Produits », « Nouvelle sortie » |
| Titre de section | 13 / 800 | « À réapprovisionner » |
| Corps | 12–13 / 500–600 | Noms, descriptions |
| Légende | 10–11 / 600 | Prix, dates, aides |
| Micro-label | 9–10 / 800 / `+0.14em` / majuscules | « VALEUR DU STOCK » |

Les montants utilisent `font-variant-numeric: tabular-nums` et sont suivis de l’unité en petit (`FCFA`, `sacs`).

### Espacement

Base de 4 px. Padding d’écran : **18 px**. Écart entre sections : **16–18 px**. Padding de carte : **12–16 px**. Hauteur de ligne de liste : **55–73 px**. Les cibles tactiles font au minimum **48 × 48 px**.

### Rayons

| Élément | Rayon |
| --- | --- |
| Carte héros | 22 |
| Carte | 16–18 |
| Champ / bouton | 14 |
| Badge / chip | 7–10 |
| Navigation flottante | 21 |
| Feuille / dialogue | 24 |

### Élévation

Pas de bordure lourde. Une ombre très douce suffit :

```css
/* carte */
box-shadow: 0 4px 14px rgba(14, 26, 43, .035);

/* navigation flottante */
box-shadow: 0 14px 26px rgba(14, 26, 43, .11);

/* action principale */
box-shadow: 0 12px 22px rgba(35, 85, 242, .26);
```

---

## 4. Composants signature

- **Carte héros** : fond encre dégradé, valeur du stock en display, micro-sparkline ambre, deux boutons « Entrée » et « Sortie » intégrés.
- **Bandeau KPI** : une seule carte, trois métriques séparées par des filets. Plus léger que quatre cartes concurrentes.
- **Ligne produit** : tuile d’initiale colorée, nom, référence en micro-label, prix + unité, pastille de stock, chevron.
- **Ligne de mouvement** : icône carrée teintée, nom, quantité, montant signé, heure. Pas de carte individuelle : un seul conteneur avec des séparateurs.
- **Navigation flottante** : capsule blanche, onglet actif en cobalt doux, icônes 17 px, libellés 9–10 px.
- **Formulaire à pied fixe** : champs en cartes, résumé du total + CTA principal ancrés en bas, note de confiance discrète.
- **Badges** : menthe « En stock », ambre « Stock faible », corail « Rupture ».
- **États vides** : icône simple, une phrase, une seule action.

---

## 5. Écrans

### Accueil
Barre supérieure transparente avec logo, salutation, date + point « hors ligne », cloche. Carte héros « Valeur du stock » avec actions Entrée / Sortie. Bandeau KPI Produits / Clients / Sorties. Section « À réapprovisionner » (2–3 lignes). Dernières opérations (2–3 lignes). Le rapport est accessible depuis la carte héros, plus depuis une bannière séparée.

### Produits
Titre large + compteur + bouton « + » cobalt. Recherche en pilule blanche avec bouton filtre cobalt. Chips « Tous / Stock faible / Récents », tri « Nom A–Z ». Liste de produits aérée. Le bouton d’ajout vit dans l’en-tête, pas en FAB étendu qui masque la liste.

### Fiche produit
En-tête produit avec tuile, nom, référence. Prix et stock mis en avant. Segments « Aperçu / Mouvements ». Barre d’actions fixe « Entrée » / « Sortie ». Les informations secondaires (unité, seuil, dates) sont regroupées dans une carte discrète.

### Mouvements
Segments « Tout / Entrées / Sorties », recherche, filtre avancé en feuille. Timeline groupée par jour, avec totaux du jour. Les annulations restent lisibles mais atténuées, avec badge.

### Entrée / Sortie
Client et produit en cartes de sélection. Quantité avec stepper, prix historique verrouillé et expliqué. Total + CTA dans un pied fixe. En sortie, afficher « stock restant après validation » en note de confiance.

### Clients
Liste avec initiales, nom complet, téléphone et total acheté. Fiche client : résumé du total, historique des sorties, actions « Nouvelle sortie » et « Appeler ».

### Rapports
Résumé en trois chiffres, graphique en barres des entrées/sorties, top produits, répartition clients. Export CSV / Excel / PDF dans une feuille unique, avec un bouton principal.

### Plus / Paramètres
Carte boutique avec statut hors ligne et dernière sauvegarde. Réglages groupés en sections : Données, Sécurité, Application, Aide. Pas de doublon avec le tiroir : le tiroir peut être supprimé au profit de cet onglet.

### Verrouillage PIN
Fond ivoire, logo, quatre points, pavé numérique dessiné sur mesure. Erreur discrète en corail, jamais de vibration agressive.

---

## 6. Mouvement

- Transitions de page : **220 ms**, glissement de 12 px + fondu, `easeOutCubic`.
- Feuilles : **240 ms**, `easeOutCubic`.
- Boutons : échelle 0,98 à l’appui, **120 ms**.
- Compteurs animés : **600 ms** maximum, uniquement sur l’accueil.
- Retour haptique léger à la validation d’une entrée/sortie.
- Pas d’animation décorative de plus de 300 ms.

---

## 7. Accessibilité

- Corps de texte minimum **12 px**, légendes **10,5 px** : ne pas descendre en dessous.
- Contraste AA (4,5:1) sur tous les textes ; l’ambre foncé `#9A6500` est utilisé pour le texte sur fond ambre clair.
- Cible tactile 48 dp, y compris les chevrons et les icônes.
- Ne jamais coder l’information uniquement par la couleur : icône + libellé + couleur.
- Vérifier 320 × 568 et un facteur de texte de 130 % (le test `app_smoke_test.dart` existe déjà).
- Mode sombre : phase 2, une fois la base claire validée.

---

## 8. Mise en œuvre proposée

1. **Fondations** — `AppColors`, `AppTheme`, Manrope embarquée, styles de cartes/boutons/champs/navigation. `AppTokens` pour les espacements et rayons.
2. **Coquille & accueil** — suppression de l’`AppBar` bleue, nouvelle carte héros, bandeau KPI, navigation flottante.
3. **Listes & fiches** — produits, clients, mouvements, fiche produit, stock faible.
4. **Formulaires** — entrée/sortie, pied fixe, stepper, écrans de succès/erreur cohérents.
5. **Rapports & réglages** — graphiques, exports, carte boutique, dernière sauvegarde.
6. **Qualité** — `flutter analyze`, `flutter test`, tests de rendu 320 px / 130 %, audit de contraste, captures golden.

Aucune règle métier ni requête SQLite n’est modifiée : la refonte est d’abord une couche de présentation et de composition.

---

## 9. Ce que l’on garde

- Le bleu et le jaune comme ADN de marque, mais dans des proportions plus maîtrisées.
- Les cinq onglets et les parcours actuels.
- Les mentions « 100 % hors ligne » et la confiance dans les données locales.
- Material 3, la localisation française, les montants en FCFA.
- Les tests de non-régression et la compatibilité petits écrans.

---

*Direction proposée en octobre 2026. Manrope est distribué sous SIL Open Font License.*
