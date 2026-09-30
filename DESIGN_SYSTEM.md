# PixelFocus — Design System

Référence visuelle de l'app, commune à **iOS, Android et web**.

- **Valeurs** (couleurs, arrondis, espacements, tailles) : [`design/design-tokens.json`](design/design-tokens.json), la **source unique**.
- **iOS** : `python3 tools/generate_theme.py` génère `PixelFocus/UI/Theme/ThemeTokens.generated.swift`. Ne jamais écrire une couleur en dur dans une vue.
- **Android** : le même JSON servira à générer l'équivalent Kotlin (Jetpack Compose).

---

## 1. Principes

1. **La concentration d'abord.** L'app aide à se concentrer sur une tâche précise ; le pixel art est la récompense, pas le sujet. Chaque écran doit mener à « lancer une session ».
2. **Sobre et sombre par défaut.** Fonds neutres, cartes arrondies, peu de couleur. **Le pixel art est la seule touche vraiment colorée.**
3. **Une action principale par écran**, avec le bouton principal (couleur `primary`). Tout le reste est secondaire.
4. **Lisible d'un coup d'œil** : grands chiffres, légendes courtes, progression visible (barres, points).
5. **Neutre et universel** : pas de fête religieuse, pas de drapeau, pas de politique (voir GAME_DESIGN.md §4.4).

---

## 2. Thèmes

| Rôle | Minuit (gratuit, défaut) | Soleil (Premium) | Braise (Premium) |
|---|---|---|---|
| Style | Sombre, noir/gris | Clair, crème | Sombre, bleu nuit |
| `background` | `#0B0B0F` | `#F7F8E3` | `#001427` |
| `surface` (cartes) | `#1C1C22` | `#FFFDF2` | `#0A2238` |
| `surfaceHighlight` (champs, pistes) | `#2A2A33` | `#E7EB90` | `#12304C` |
| `primary` (action principale) | `#7C3AED` | `#2274A5` | `#BF0603` |
| `textPrimary` | `#FFFFFF` | `#632B30` | `#FFF6E0` |
| `textSecondary` | `#9CA3AF` | `#632B30` à 65 % | `#9FB5AB` |
| `streak` (série) | `#FB923C` | `#E6AF2E` | `#E8553F` |
| `record` (record, badges) | `#FACC15` | `#C9971C` | `#F4D58D` |
| `booster` | `#A78BFA` | `#2274A5` | `#F4D58D` |
| `token` (protection) | `#2DD4BF` | `#3A8FBF` | `#8FB0A2` |
| `success` / `danger` | `#4ADE80` / `#F87171` | `#4C8A2A` / `#9B2C2C` | `#8FB0A2` / `#E8553F` |
| `emptyPixel` (pixel non révélé) | `#2A2A33` | `#E7EB90` | `#12304C` |

Règles :
- Texte sur `primary` : toujours `onPrimary` (blanc).
- Sans Premium, Soleil et Braise retombent sur Minuit.
- Les couleurs d'une œuvre pixel art ne dépendent jamais du thème.

---

## 3. Mesures

| Token | Valeur | Usage |
|---|---|---|
| `radius.card` | 22 | Cartes |
| `radius.button` | 18 | Bouton principal |
| `radius.control` | 14 | Boutons secondaires, champs |
| `radius.thumbnail` | 12 | Vignettes d'œuvres |
| `radius.dayCell` | 8 | Cases du calendrier |
| `spacing` | 4 · 8 · 12 · 16 · 24 · 32 | Espacements (16 = marge d'écran et écart entre cartes) |
| `sizes.buttonHeight` | 52 | Bouton principal |
| `sizes.minTouchTarget` | 44 | Toute zone touchable |

## 4. Typographie

Police système (SF Pro sur iOS, Roboto sur Android), tailles dynamiques respectées.

| Style | iOS | Usage |
|---|---|---|
| Titre d'écran | 34 pt, gras | « Aujourd'hui », « Calendrier »… |
| Titre de section | `.title3`, semi-gras | « À jouer aussi », « Badges » |
| Titre de carte | `.headline` | Nom d'une œuvre |
| Texte | `.subheadline` | Descriptions, règles |
| Légende | `.caption` | Sous-titres de tuiles, pourcentages |
| Minuteur | 80 pt, gras, chasse fixe | Écran de session |

---

## 5. Composants

| Composant | Rôle | iOS (`UI/Theme/ThemeComponents.swift`) | Android (à venir) |
|---|---|---|---|
| **Fond d'écran** | Fond du thème, bord à bord | `.themedScreenBackground()` | `Surface(color = background)` |
| **Carte** | Regrouper un contenu | `.themedCard(padding:)` | `Card` |
| **En-tête d'écran** | Logo PixelFocus + grand titre | `ScreenHeader(title:)` | `ScreenHeader` |
| **Titre de section** | Séparer les blocs | `SectionTitle(title:)` | `SectionTitle` |
| **Filtre en pilule** | 2 à 4 options exclusives | `PillPicker(options:selection:title:)` | `SegmentedPill` |
| **Tuile de stat** | Un chiffre + icône + légende + indicateur | `StatTile(icon:color:value:caption:) { … }` | `StatTile` |
| **Points de progression** | Progression courte (série, badges) | `DotsProgress(filled:total:color:)` | `DotsProgress` |
| **Barre de progression** | Progression continue | `ThemedProgressBar(value:color:height:)` | `LinearProgress` |
| **Vignette pixel art** | Afficher une œuvre et sa révélation | `PixelArtView(artwork:revealedCount:emptyColor:)` | `PixelArtCanvas` |
| **Carte d'œuvre (ligne)** | Œuvre + progression + verrou | `ArtworkRowCard` | `ArtworkRow` |
| **Tuile d'œuvre (grille)** | Œuvre dans la collection | `ArtworkTile` | `ArtworkTile` |
| **Bannière** | Message court (erreur, badge) | `MessageBanner(text:color:)` | `Banner` |
| **Bouton principal** | L'action de l'écran | `.buttonStyle(PrimaryButtonStyle())` | `PrimaryButton` |
| **Bouton secondaire** | Actions annexes | `.buttonStyle(SecondaryButtonStyle())` | `SecondaryButton` |

### Règles d'usage
- Toutes les couleurs viennent de `@Environment(\.theme)` ; jamais de `.white`, `.blue`… en dur.
- Un écran = `ScreenHeader` puis une pile de cartes espacées de 16, marge latérale 16.
- Contenu verrouillé : vignette à 35 % d'opacité + cadenas, et une action claire pour débloquer.
- Vignettes pixel art : `PixelArtView` (rendu Canvas), même pour 100 vignettes à l'écran.

---

## 6. Écrans types

| Écran | Structure |
|---|---|
| **Aujourd'hui** | En-tête → intention / image du jour en grand → barre durée + lecture → 4 tuiles (série, record, boosters, tokens) → minutes de concentration → cartes semaine et mois |
| **Calendrier** | En-tête → navigation par mois → grille lundi–dimanche de vignettes → résumé du mois → image du mois |
| **Collection** | En-tête → filtre Tout / Terminées / À finaliser → grille 2 colonnes → Mensuel → Badges → Packs |
| **Réglages** | En-tête → Compte & Premium → Apparence → Synchronisation → Statistiques → Règles → À propos |
| **Session** | Intention → minuteur géant → image qui se révèle → bouton unique |

---

## 7. Ton et textes

- **Tutoiement**, phrases courtes, positives.
- Parler de **concentration** avant de parler de pixels : « 25 min de concentration » plutôt que « +5 pixels ».
- Jamais culpabilisant : « Rien à finaliser. Bravo ! », « Pas encore ? Ce n'est que partie remise. »

## 8. Accessibilité

- Contraste du texte ≥ 4,5:1 (vérifié pour `textPrimary` sur `background` et `onPrimary` sur `primary` dans les 3 thèmes).
- Zones touchables ≥ 44 × 44.
- Les informations ne reposent jamais sur la couleur seule (icône ou texte en plus : cadenas, ✓, pourcentage).
- Chaque badge et vignette a un libellé VoiceOver.
