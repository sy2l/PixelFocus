# PixelFocus

**Version 1.0** — Janvier 2026

Application iOS SwiftUI de gamification du focus et de la concentration. Révélez des œuvres pixel art en complétant des sessions de concentration.

---

## Concept du Jeu

PixelFocus transforme le temps de concentration en récompenses visuelles. Chaque session de focus terminée révèle des pixels d'une œuvre d'art, créant une motivation intrinsèque pour maintenir la concentration.

### Types d'Œuvres

| Type | Grille | Disponibilité | Règle de Purge |
|------|--------|---------------|----------------|
| **Daily** | 5×5 (25 px) | 1 par jour | Jouable toute l'année, purgée le 1er janvier suivant |
| **Weekly** | 7×7 (49 px) | 1 par semaine | À finaliser sans purge |
| **Monthly** | 10×10 (100 px) | 1 par mois | Jamais purgée. Accès : 1ère offerte, Premium, défi du mois ou achat (voir GAME_DESIGN.md) |

### Système de Sessions

- **Durées disponibles** : 15, 20, 25, 30 minutes
- **Récompense** : +5 pixels par session terminée
- **Quotas gratuits** : 15 min = 1/jour, 20 min = 1/jour
- **Illimité** : 25 min et 30 min
- **Token protection** : 30 min = +1 token (cap 3/jour)

### Streak et Bonus

- **Streak** : Compléter la daily du jour, chaque jour consécutif
- **Récompense streak** : 1 booster tous les 3 jours, +1 tous les 18 jours (stock max 12)
- **Booster** : révèle 5 pixels ; gagnés utilisables 1/jour (3 en Premium), achetés sans limite
- **Bonus >30 min** : +1 pixel bonus par tranche de 5 min au-delà de 30 min (cap 10/jour)

---

## Architecture du Projet

```
PixelFocus/
├── App/
│   ├── PixelFocusApp.swift          # Point d'entrée
│   └── AppCoordinator.swift         # Coordinateur global
├── Models/
│   ├── DTO/
│   │   ├── RulesetDTO.swift         # Règles du jeu
│   │   ├── ArtworkDTO.swift         # Œuvre pixel art
│   │   └── CatalogDTO.swift         # Catalogue mensuel
│   └── SwiftData/
│       ├── SDArtwork.swift          # Œuvre persistée
│       ├── SDProgress.swift         # Progression utilisateur
│       ├── SDStreak.swift           # Streak consécutif
│       ├── SDWallet.swift           # Tokens et pixels stockés
│       ├── SDDailyQuota.swift       # Quotas journaliers
│       ├── SDMonthStats.swift       # Sessions par mois (défi du mois)
│       ├── SDActiveDay.swift        # Jours actifs (badges)
│       └── SDBadge.swift            # Badges débloqués
├── Services/
│   ├── JSONContentLoader.swift      # Chargeur JSON
│   ├── ContentStore.swift           # Store de contenu
│   ├── EntitlementStore.swift       # Droits d'accès (StoreKit + serveur)
│   ├── FirstLaunchStore.swift       # Date du 1er lancement (trousseau)
│   ├── SyncService.swift            # Synchronisation avec l'API (événements, droits)
│   ├── APIClient.swift              # Client HTTP de l'API
│   └── KeychainStore.swift          # Jeton d'API (trousseau iCloud)
├── Store/
│   ├── StoreProducts.swift          # Identifiants des produits App Store
│   └── PurchaseManager.swift        # Achats StoreKit 2
├── Engine/
│   ├── GameEngine.swift             # Moteur de règles
│   ├── SessionManager.swift         # Gestion des sessions
│   ├── SessionTiming.swift          # Logique de timing
│   ├── DatePolicy.swift             # Règles de dates
│   ├── DateParsing.swift            # Parsing ISO
│   ├── BoosterPolicy.swift          # Règles des boosters
│   ├── MonthlyAccessPolicy.swift    # Accès et prix de l'image du mois
│   └── BadgePolicy.swift            # Badges de régularité
├── UI/
│   ├── Theme/                       # Thèmes + composants (voir DESIGN_SYSTEM.md)
│   ├── Onboarding/OnboardingView.swift
│   ├── Store/StoreView.swift        # Boutique (Premium, boosters)
│   ├── Root/MainTabView.swift       # TabView principal + thème
│   ├── Today/TodayView.swift        # Écran "Aujourd'hui"
│   ├── Artwork/
│   │   ├── ArtworkDetailView.swift  # Détail d'une œuvre
│   │   └── UseBoosterSheet.swift
│   ├── Focus/
│   │   ├── FocusSessionHostView.swift
│   │   └── FocusSessionView.swift   # Timer de session
│   ├── Calendar/
│   │   └── CalendarView.swift       # Calendrier de l'année (vignettes des daily)
│   ├── Collection/CollectionView.swift
│   └── Settings/SettingsView.swift
├── Resources/
│   ├── ruleset.json                 # Règles du jeu
│   ├── catalog.json                 # Catalogue mensuel
│   └── artworks/                    # Fichiers d'œuvres

PixelFocusTests/                     # Cible de tests unitaires (à la racine du dépôt)
├── SessionTimingTests.swift
└── DatePolicyTests.swift
```

Documents de référence (racine du dépôt) :
- [`GAME_DESIGN.md`](../GAME_DESIGN.md) — règles du jeu et monétisation (fait foi)
- [`DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md) — couleurs, composants, écrans
- [`MISE_EN_PRODUCTION.md`](../MISE_EN_PRODUCTION.md) — étapes pour publier (App Store Connect, serveur, contenu)
- [`server/README.md`](../server/README.md) — API PHP + MySQL (o2switch)

---

## Prérequis

- **Xcode 16.0+** (le projet utilise les dossiers synchronisés d'Xcode 16)
- **iOS 18.2+** (cible de déploiement du projet)
- **Swift 5**
- **SwiftData**

---

## Installation

1. Cloner le repository :
   ```bash
   git clone https://github.com/votre-username/PixelFocus.git
   cd PixelFocus
   ```

2. Ouvrir dans Xcode :
   ```bash
   open PixelFocus.xcodeproj
   ```

3. Sélectionner un simulateur ou appareil iOS 17+

4. Build & Run (⌘R)

---

## Configuration du Projet Xcode

### Création du projet Xcode

1. **File > New > Project**
2. Choisir **App** (iOS)
3. Paramètres :
   - Product Name: `PixelFocus`
   - Team: Votre équipe
   - Organization Identifier: `com.votreorg`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**

4. Importer les fichiers sources selon l'arborescence

### Ajout des ressources JSON

1. Drag & drop le dossier `Resources/` dans le projet
2. Cocher "Copy items if needed"
3. Cocher "Create folder references" (dossier bleu)
4. Vérifier que les fichiers sont dans "Copy Bundle Resources"

---

## Tests

Exécuter les tests unitaires :

```bash
# Via Xcode
⌘U

# Via ligne de commande
xcodebuild test -scheme PixelFocus -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Tests disponibles

- `SessionTimingTests` : Logique de timing des sessions
- `DatePolicyTests` : Règles de dates, fin de période et purge

---

## Roadmap

### V1.0 (MVP) ✅
- [x] Sessions focus 15/20/25/30 min
- [x] Daily, Weekly, Monthly
- [x] Streak et pixels stockés
- [x] Token de protection
- [x] Purge des daily le 4

### V1.1 (Prochaine)
- [ ] StoreKit pour abonnement Premium
- [ ] Notifications de rappel
- [ ] Widgets iOS

### V2.0 (Future)
- [ ] Sync iCloud
- [ ] Partage social
- [ ] Achievements

---

## Contribution

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/amazing-feature`)
3. Commit les changements (`git commit -m 'Add amazing feature'`)
4. Push la branche (`git push origin feature/amazing-feature`)
5. Ouvrir une Pull Request

---

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

---

## Contact

Pour toute question ou suggestion, ouvrez une issue sur GitHub.
