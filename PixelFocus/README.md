# PixelFocus

**Version 1.0** — Janvier 2026

Application iOS SwiftUI de gamification du focus et de la concentration. Révélez des œuvres pixel art en complétant des sessions de concentration.

---

## Concept du Jeu

PixelFocus transforme le temps de concentration en récompenses visuelles. Chaque session de focus terminée révèle des pixels d'une œuvre d'art, créant une motivation intrinsèque pour maintenir la concentration.

### Types d'Œuvres

| Type | Grille | Disponibilité | Règle de Purge |
|------|--------|---------------|----------------|
| **Daily** | 5×5 (25 px) | 1 par jour | Purgée le 4 du mois suivant |
| **Weekly** | 7×7 (49 px) | 1 par semaine | À finaliser sans purge |
| **Monthly** | 10×10 (100 px) | 1 par mois | Jamais purgée, achetable jusqu'à février N+1 |

### Système de Sessions

- **Durées disponibles** : 15, 20, 25, 30 minutes
- **Récompense** : +5 pixels par session terminée
- **Quotas gratuits** : 15 min = 1/jour, 20 min = 1/jour
- **Illimité** : 25 min et 30 min
- **Token protection** : 30 min = +1 token (cap 3/jour)

### Streak et Bonus

- **Streak** : Compléter une daily chaque jour consécutif
- **Récompense streak** : Tous les 5 jours → +5 pixels stockables (cap 5)
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
│       └── SDDailyQuota.swift       # Quotas journaliers
├── Services/
│   ├── JSONContentLoader.swift      # Chargeur JSON
│   └── ContentStore.swift           # Store de contenu
├── Engine/
│   ├── GameEngine.swift             # Moteur de règles
│   ├── SessionManager.swift         # Gestion des sessions
│   ├── SessionTiming.swift          # Logique de timing
│   ├── DatePolicy.swift             # Règles de dates
│   └── DateParsing.swift            # Parsing ISO
├── UI/
│   ├── Root/MainTabView.swift       # TabView principal
│   ├── Today/TodayView.swift        # Écran "Aujourd'hui"
│   ├── Artwork/
│   │   ├── ArtworkDetailView.swift  # Détail d'une œuvre
│   │   └── SpendBankedPixelsSheet.swift
│   ├── Focus/
│   │   ├── FocusSessionHostView.swift
│   │   └── FocusSessionView.swift   # Timer de session
│   ├── Calendar/
│   │   ├── CalendarView.swift       # Calendrier des daily
│   │   └── DailyFinalizeListView.swift
│   ├── Collection/CollectionView.swift
│   └── Settings/SettingsView.swift
├── Resources/
│   ├── ruleset.json                 # Règles du jeu
│   ├── catalog.json                 # Catalogue mensuel
│   └── artworks/                    # Fichiers d'œuvres
├── Tests/
│   └── PixelFocusTests/
│       ├── SessionTimingTests.swift
│       └── DatePolicyTests.swift
└── Documentation/
    ├── Architecture_Fonctionnelle.md
    └── Architecture_Technique_iOS.md
```

---

## Prérequis

- **Xcode 15.0+**
- **iOS 17.0+**
- **Swift 5.9+**
- **SwiftData** (intégré à iOS 17)

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
xcodebuild test -scheme PixelFocus -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Tests disponibles

- `SessionTimingTests` : Logique de timing des sessions
- `DatePolicyTests` : Règles de dates et purge

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
