# Wanma

**Votre magasin, mieux géré.**

Wanma est une application Android de gestion de stock, de clients et de
mouvements, conçue pour les commerces de proximité. Elle fonctionne
**entièrement hors ligne**, en **français**, avec des montants en **FCFA**.
Toutes les données restent dans une base **SQLite locale** : aucun compte,
aucun serveur, aucune synchronisation et aucune permission Internet.

![Maquette de référence Wanma](<Maquette Wanma _ gestion de stock en français.png>)

---

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Règles métier garanties](#règles-métier-garanties)
- [Installation](#installation)
- [Lancer l'application](#lancer-lapplication)
- [Guide d'utilisation](#guide-dutilisation)
- [Sauvegarde, restauration et exports](#sauvegarde-restauration-et-exports)
- [Sécurité et confidentialité](#sécurité-et-confidentialité)
- [Tests et qualité](#tests-et-qualité)
- [Construire l'APK](#construire-lapk)
- [Structure du projet](#structure-du-projet)
- [Dépannage](#dépannage)
- [Commandes utiles](#commandes-utiles)

---

## Fonctionnalités

### Produits et stock

- Création, modification et consultation de produits : nom, référence
  facultative, prix unitaire en FCFA, unité de mesure, quantité, seuil d'alerte
  et description.
- Stock initial justifié automatiquement par un mouvement d'entrée
  « Stock initial ».
- Recherche instantanée par nom ou référence, insensible aux accents et à la
  casse.
- Tri par nom, quantité, prix ou date d'ajout, et filtre des produits en stock
  faible ou épuisé.
- Écran dédié aux alertes de stock bas.
- La modification d'un produit ne modifie jamais son stock.

### Clients

- Fiche client avec prénom, nom et téléphone conservé comme texte (les zéros
  initiaux et les espaces sont préservés).
- Recherche par nom ou téléphone.
- Détection des numéros déjà enregistrés avec confirmation explicite avant
  d'accepter un doublon.
- Historique des sorties de stock par client.
- Suivi du crédit en cours par client, avec accès direct aux sorties non
  réglées.

### Entrées, sorties et mouvements

- Entrées de stock avec quantité, prix d'achat appliqué, date, observation et
  fournisseur éventuel.
- Sorties de stock rattachées à un client, avec prix de vente historique.
- Option « Vente à crédit » pour une sortie non payée immédiatement.
- Règlement d'une vente à crédit avec le bouton « Marquer comme payé » : la
  date de remboursement est conservée et le crédit sort des sommes à recouvrer.
- Création d'un client directement dans l'écran de sortie, dans la même
  transaction que le mouvement.
- Refus automatique de toute quantité nulle ou négative.
- Refus de toute sortie supérieure au stock disponible : aucun stock négatif
  n'est possible.
- Historique complet avec filtres par type, produit, client et période, dont
  un filtre dédié aux crédits non réglés.
- Opérations regroupées automatiquement par journée (« Aujourd’hui », « Hier »
  ou date complète), avec le nombre d’opérations de chaque jour.
- Annulation traçable d'une entrée ou d'une sortie : le stock est corrigé, le
  mouvement reste visible avec le statut « Annulé » et le motif.

### Tableau de bord et rapports

- Indicateurs du jour : entrées, sorties, chiffre d'affaires, valeur du stock,
  produits en alerte et activité récente.
- Accès rapide aux actions « Entrée », « Sortie », « Produit » et « Client ».
- Rapports sur aujourd'hui, la semaine, le mois ou une période personnalisée.
- Totaux des entrées et sorties, valeur du stock, produits les plus sortis et
  sorties par client.
- Suivi des ventes à crédit et des montants restant à recouvrer, par période et
  par client.
- Export des rapports en **CSV**, **Excel (.xlsx)** et **PDF**.

### Outils et paramètres

- Export des produits, clients et mouvements en CSV ou Excel, avec statut de
  paiement et montants à crédit.
- Partage ou enregistrement local des fichiers via le sélecteur Android.
- Sauvegarde complète `.wanma` et restauration contrôlée.
- Verrouillage optionnel par code PIN à 4 chiffres.
- Guide d'utilisation intégré, accessible sans Internet.
- Interface Material 3 responsive, pensée pour les petits écrans Android.

---

## Règles métier garanties

| Règle | Comportement de Wanma |
| --- | --- |
| Quantités positives | Toute entrée ou sortie nulle/négative est refusée. |
| Pas de stock négatif | Une sortie supérieure au stock est refusée, sans écriture. |
| Atomicité | Le stock, le mouvement et le détail client sont écrits dans une seule transaction SQLite. |
| Prix historiques | Le prix unitaire et le montant sont figés dans le mouvement ; modifier le produit ne les change pas. |
| Annulation | Le mouvement passe à `CANCELLED`, le stock est rétabli ou retiré, l'opération reste dans l'historique. |
| Vente à crédit | Une sortie peut être marquée `CREDIT` ; elle reste à recouvrer jusqu'à « Marquer comme payé », qui enregistre la date de règlement sans effacer l'origine de la vente. |
| Suppression | Un produit ou un client lié à des mouvements ne peut pas être supprimé. |
| Téléphone | Stocké en texte, jamais converti en nombre. |
| Doublon de téléphone | Bloqué par défaut, accepté uniquement après confirmation explicite. |
| Intégrité | Clés étrangères SQLite activées, contraintes `CHECK`, index de recherche. |

---

## Installation

### Prérequis

- **Flutter 3.47.8** ou version stable compatible.
- **Dart 3.13.7** ou version compatible.
- **Android SDK** (API 36 recommandée) et **JDK 17**.
- Un téléphone Android **7.0 (API 24)** ou plus récent, ou un émulateur.

### Récupérer et préparer le projet

```bash
cd /home/ghost/development/projet_flutter
flutter pub get
```

### Vérifier l'environnement

```bash
flutter doctor -v
flutter devices
```

---

## Lancer l'application

Sur un émulateur ou un téléphone connecté en USB (débogage USB activé) :

```bash
flutter run
```

Pour choisir explicitement un appareil :

```bash
flutter devices
flutter run -d <identifiant_du_peripherique>
```

Au premier démarrage, Wanma initialise la base SQLite locale et affiche
l'écran d'accueil. Le code PIN est optionnel et peut être activé plus tard dans
**Outils → Paramètres → Sécurité**.

---

## Guide d'utilisation

### 1. Accueil

L'onglet **Accueil** présente les chiffres du jour, les alertes de stock et les
derniers mouvements. Les boutons **Entrée** et **Sortie** ouvrent directement
les écrans de saisie.

### 2. Produits

1. Ouvrir **Produits → bouton Produit**.
2. Saisir le nom, le prix en FCFA, l'unité et le stock initial.
3. Facultatif : référence, seuil d'alerte, description.
4. Enregistrer. Si le stock initial est supérieur à zéro, Wanma crée
   automatiquement l'entrée « Stock initial ».

La recherche et les filtres se trouvent en haut de la liste. Un appui sur un
produit ouvre sa fiche, son stock et ses mouvements.

### 3. Clients

1. Ouvrir **Clients → bouton Client**.
2. Saisir prénom, nom et téléphone.
3. Enregistrer.

Si le numéro existe déjà, Wanma demande une confirmation avant de continuer.
La fiche client permet de consulter ses sorties et son total acheté.

### 4. Entrée de stock

1. Accueil → **Entrée** (ou fiche produit → **Entrée**).
2. Choisir le produit, la quantité et le prix appliqué.
3. Ajouter une date, un fournisseur ou une observation si nécessaire.
4. Valider : le stock augmente immédiatement.

### 5. Sortie de stock

1. Accueil → **Sortie**.
2. Choisir le client, ou en créer un à la volée.
3. Choisir le produit et la quantité.
4. Pour un paiement différé, activer **Vente à crédit**. Le résumé et la
   confirmation affichent alors « À crédit » au lieu de « Payé ».
5. Valider. Wanma refuse la sortie si la quantité dépasse le stock. Une sortie
   comptant est enregistrée comme payée ; une sortie à crédit reste à
   recouvrer.

### 6. Mouvements, crédits et annulation

L'onglet **Activité** liste toutes les opérations, regroupées par journée avec
le nombre d'opérations de chaque date. Les filtres permettent de retrouver un
mouvement par type, produit, client ou période. Le filtre **Crédits** isole les
sorties à crédit encore non réglées. La carte **Crédits à recouvrer** de
l'accueil ouvre la vue globale de ces créances.

Pour encaisser un remboursement, ouvrir la sortie à crédit et toucher
**Marquer comme payé**. La date de règlement est conservée ; la vente reste
comptée comme vente à crédit dans les rapports, mais sort des sommes à
recouvrer. La fiche client affiche également son crédit en cours et permet
d'ouvrir directement ses sorties non réglées.

Pour annuler une opération, utiliser **Annuler le mouvement**, saisir un motif
et confirmer. Le stock est corrigé et le mouvement reste consultable avec la
mention « Annulé ». Une entrée ne peut être annulée que si le stock actuel
permet de retirer la quantité concernée.

### 7. Rapports

**Outils → Rapports** permet de choisir la période, de consulter les synthèses
et d'exporter le rapport en CSV, Excel ou PDF. Les exports sont générés
localement, puis enregistrés ou partagés via le menu Android.

### 8. Guide intégré

**Outils → Guide d'utilisation** rappelle les gestes essentiels et les règles de
sécurité, sans nécessiter de connexion.

---

## Sauvegarde, restauration et exports

### Créer une sauvegarde

1. Aller dans **Outils → Sauvegarde et restauration**.
2. Toucher **Créer une sauvegarde**.
3. Choisir **Enregistrer** ou **Partager** dans le menu Android.

Le fichier porte un nom du type
`wanma_sauvegarde_20261026_143500.wanma`. Il contient :

- la base SQLite encodée en base64 ;
- la version du schéma et du format ;
- le nombre de produits, clients et mouvements ;
- la date de création ;
- une empreinte **SHA-256** de la base.

Conservez ce fichier hors du téléphone (ordinateur, clé USB, stockage externe).
Il contient des données commerciales sensibles et n'est pas chiffré.

### Restaurer une sauvegarde

1. **Outils → Sauvegarde et restauration**.
2. Toucher **Choisir une sauvegarde à restaurer**.
3. Sélectionner un fichier `.wanma`.
4. Wanma vérifie le format, l'empreinte SHA-256, l'en-tête SQLite et les
   versions avant d'afficher le résumé.
5. Confirmer la restauration. Les données actuelles sont remplacées.

En cas de fichier corrompu ou invalide, la base actuelle n'est pas modifiée.
Une copie de secours temporaire est utilisée pendant l'opération.

> Le code PIN n'est **pas** inclus dans la sauvegarde. Il reste lié au
> téléphone et à ses préférences locales.

### Exporter des listes

**Outils → Exporter** ou **Paramètres → Exporter les données** propose :

- produits : référence, prix, quantité, unité, seuil, valeur, dates, description ;
- clients : prénom, nom, téléphone, date d'enregistrement ;
- mouvements : date, type, produit, client, téléphone, prix, montant, statut,
  statut de paiement, observation et motif d'annulation ;
- rapports : totaux de la période, ventes à crédit, montants à recouvrer et
  part à crédit de chaque client.

Les CSV utilisent le point-virgule, l'encodage UTF-8 avec BOM et sont adaptés à
Excel en français. Les classeurs Excel et les PDF sont générés sans réseau.

---

## Sécurité et confidentialité

- **Aucune permission Internet** : le manifeste Android ne déclare pas
  `android.permission.INTERNET`.
- **Aucun service cloud** : pas de Firebase, pas de client HTTP, pas de compte.
- **Base privée** : SQLite est stocké dans l'espace privé de l'application.
- **Code PIN optionnel** :
  - 4 chiffres ;
  - stockage d'un sel aléatoire et d'un condensat **SHA-256** dans
    `shared_preferences`, jamais le code en clair ;
  - verrouillage à l'ouverture et après **15 secondes** en arrière-plan ;
  - possibilité de changer ou désactiver le code avec vérification du code
    actuel.
- **Exports et sauvegardes** : les fichiers ne quittent le téléphone que si
  l'utilisateur choisit explicitement de les partager.

Le code PIN protège l'accès à l'interface ; il ne chiffre pas la base SQLite.
Pour des données très sensibles, protégez également le téléphone par le
verrouillage Android et conservez les sauvegardes dans un lieu sûr.

---

## Tests et qualité

La suite couvre les 14 scénarios fonctionnels demandés, ainsi que la
persistance, la sécurité, les exports et les garanties hors ligne.

```bash
flutter test
flutter analyze
```

Résultat attendu :

- **47 tests** répartis dans 6 fichiers ;
- `flutter analyze` : **No issues found!**

| Fichier | Couverture |
| --- | --- |
| `test/inventory_scenarios_test.dart` | Scénarios 1 à 11 : produits, stock initial, entrées, sorties, survente, atomicité client, prix historiques, ventes à crédit et règlement, annulations, suppressions, doublons de téléphone. |
| `test/analytics_search_test.dart` | Scénarios 12 et 13 : recherche sans accents, filtres, tableau de bord, rapports, crédits à recouvrer et regroupement des opérations par date. |
| `test/backup_scenarios_test.dart` | Scénario 14 : création, validation, corruption, restauration et rechargement. |
| `test/persistence_security_export_test.dart` | Persistance après fermeture, PIN salé, verrouillage, exports CSV/Excel/PDF avec statut de paiement et absence de réseau. |
| `test/database_migration_test.dart` | Migration des bases v1 et v2 vers le schéma courant, conservation des ventes à crédit existantes. |
| `test/app_smoke_test.dart` | Rendu des cinq onglets et de douze écrans principaux sur petit écran (320 × 568) avec texte agrandi à 130 %. |

Les tests utilisent une base SQLite FFI temporaire par test
(`sqflite_common_ffi`) et des préférences simulées. Aucune donnée réelle n'est
touchée.

---

## Construire l'APK

### APK universel

```bash
flutter build apk --release
```

Fichier produit :

```text
build/app/outputs/flutter-apk/app-release.apk
```

### APK par architecture

```bash
flutter build apk --release --split-per-abi
```

Fichiers produits :

```text
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

### Installer sur un téléphone

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Ou copiez l'APK sur le téléphone et ouvrez-le après avoir autorisé
l'installation depuis cette source.

> **Signature** : la configuration actuelle signe les builds release avec la
> clé de débogage Flutter, ce qui suffit pour une installation directe et une
> utilisation interne. Pour publier sur le Play Store ou distribuer largement,
> créez un keystore de production et configurez `android/app/build.gradle.kts`
> avant de reconstruire l'APK.

### Nettoyer et reconstruire

```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## Structure du projet

```text
lib/
├── app.dart                     # MaterialApp, verrouillage, navigation 5 onglets
├── main.dart                    # Initialisation Flutter, format fr_FR, AppState
├── core/
│   ├── constants/               # Nom, palette, unités, versions
│   ├── database/                # Schéma SQLite, migrations, checkpoint
│   ├── errors/                  # Exceptions métier
│   ├── theme/                   # Thème Material 3
│   └── utils/                   # Formats FCFA, validateurs, recherche, regroupement par date
├── data/
│   ├── models/                  # Produit, client, mouvement, rapport
│   └── repositories/            # Accès SQLite
├── services/
│   ├── analytics_service.dart   # Indicateurs et rapports
│   ├── backup_service.dart      # Format .wanma, SHA-256, restauration
│   ├── export_service.dart      # CSV, Excel, PDF
│   ├── file_transfer_service.dart
│   ├── inventory_service.dart   # Transactions de stock et règlements crédit
│   └── security_service.dart    # PIN salé SHA-256
├── state/
│   └── app_state.dart           # État central et actions
└── ui/
    ├── screens/                 # Accueil, produits, clients, mouvements, outils
    └── widgets/                 # Composants réutilisables, logo Wanma
test/
├── support/test_harness.dart
├── inventory_scenarios_test.dart
├── analytics_search_test.dart
├── backup_scenarios_test.dart
├── persistence_security_export_test.dart
├── database_migration_test.dart
└── app_smoke_test.dart
```

---

## Dépannage

### `flutter pub get` échoue

Vérifiez la connexion lors de la première installation des paquets, puis
relancez :

```bash
flutter clean
flutter pub get
```

Une fois les dépendances téléchargées, l'application elle-même n'a besoin
d'aucune connexion.

### Aucun appareil détecté

```bash
adb devices
flutter devices
```

Sur le téléphone, activez **Options de développeur → Débogage USB** et acceptez
l'autorisation de l'ordinateur. Sur Linux, vérifiez les règles udev si
nécessaire.

### Le build Android échoue

```bash
flutter doctor -v
cd android && ./gradlew clean && cd ..
flutter build apk --release
```

Vérifiez que le JDK 17 est utilisé et que le SDK Android est installé.

### La restauration est refusée

Le fichier doit être une sauvegarde Wanma complète et non modifiée. Un message
d'erreur précise si le format, l'empreinte ou l'intégrité SQLite est en cause.
L'ancienne base reste intacte.

### Le sélecteur de fichiers ne s'ouvre pas

Le sélecteur dépend du système Android. Vérifiez qu'un gestionnaire de fichiers
est disponible et que l'application a accès au stockage choisi. Les exports
peuvent aussi être partagés directement depuis la feuille de partage Android.

---

## Commandes utiles

| Action | Commande |
| --- | --- |
| Installer les dépendances | `flutter pub get` |
| Lancer en debug | `flutter run` |
| Analyser le code | `flutter analyze` |
| Lancer tous les tests | `flutter test` |
| Formater le code | `dart format lib test` |
| Construire l'APK release | `flutter build apk --release` |
| Construire par architecture | `flutter build apk --release --split-per-abi` |
| Installer l'APK | `adb install -r build/app/outputs/flutter-apk/app-release.apk` |
| Nettoyer le build | `flutter clean` |

---

## Notes

- Application **Android uniquement**.
- Interface et messages en **français** ; dates au format `fr_FR`.
- Prix entiers en **FCFA** ; quantités décimales acceptées.
- Les exports CSV/Excel/PDF et les sauvegardes sont créés localement.
- Wanma ne remplace pas une comptabilité officielle : il facilite le suivi
  quotidien du stock et des clients.

**Wanma 1.0.0** — gestion de stock hors ligne, faite pour les commerces de
proximité.
