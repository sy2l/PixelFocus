# PixelFocus — Game Design & Monétisation

Document de référence des règles métier. En cas de conflit avec le README, **ce document fait foi**.

Statut : v1.0 — règles validées.

---

## 1. Offres Premium

| Produit | Type Apple | Prix |
|---|---|---|
| Premium mensuel | Abonnement auto-renouvelable | 2,99 € / mois |
| Premium annuel | Abonnement auto-renouvelable (essai 7 j) | 24,99 € / an |
| Premium à vie | Achat unique (non-consumable) | 69,99 € |
| Premium à vie — tarif abonné | Achat unique (non-consumable), proposé uniquement aux abonnés actifs | 49,99 € |

Notes techniques :
- Apple n'autorise qu'un prix par produit → le tarif « à vie abonné » est un **produit distinct**, affiché seulement si un abonnement est actif.
- Acheter le « à vie » ne résilie pas l'abonnement automatiquement : l'app doit inviter l'utilisateur à le résilier (lien direct vers la gestion des abonnements).

Le Premium donne :
- Sessions 15 et 20 min illimitées.
- Toutes les images du mois pendant la période d'abonnement.
- Les packs thématiques de l'année en cours.
- 2 boosters offerts au début de chaque mois, et jusqu'à 3 boosters gagnés utilisables par jour (voir §3).
- Accès exclusif aux packs thématiques et géographiques (voir §4.5).

Principe : **le jeu de base (daily, weekly, monthly) est finissable en gratuit**. Payer fait aller plus vite. Les packs thématiques restent un bonus Premium.

---

## 2. Image du mois (Monthly)

### 2.1 Utilisateur gratuit
- **Une seule image du mois offerte** (cadeau de bienvenue) :
  - premier lancement **avant le 25** → image du mois en cours ;
  - premier lancement **le 25 ou après** → image du mois suivant.
- Les autres images du mois sont visibles en **vitrine** (« le mois dernier, les membres Premium ont débloqué… ») mais non jouables, sauf si le gratuit réussit le **défi du mois**.

### 2.1 bis Défi du mois (gratuit)
- Réussir le défi débloque l'image du mois en cours.
- Défi : **20 sessions terminées dans le mois**.

### 2.2 Passage Premium
- Accès à l'image du mois en cours.
- Accès à l'image du **mois précédent uniquement** (avec la progression existante), jouable **jusqu'au 7 du mois en cours**.

### 2.3 Fin du Premium
- Les images terminées restent dans la collection.
- L'image du mois **en cours de progression** est offerte : jouable jusqu'à la **fin du mois calendaire**.
- Au-delà : verrouillée, mais achetable à l'unité.

### 2.4 Achat à l'unité
Toujours disponible, y compris pour les **anciennes** images du mois.

| Situation | Prix |
|---|---|
| Image du mois M, achetée entre le 1er de M et le 7 de M+1, progression **> 50 %** | 0,99 € |
| Image du mois M, achetée entre le 1er de M et le 7 de M+1, progression ≤ 50 % | 1,99 € |
| Image du mois M, achetée **après le 7 de M+1** (archive) | 1,99 € |


Notes techniques :
- Un achat à l'unité est **définitif** (restaurable).
- 2 produits Apple par mois (`monthly_YYYY_MM` à 1,99 € et `monthly_YYYY_MM_reduced` à 0,99 €), soit 24 produits/an → création automatisée via l'API App Store Connect.

---

## 3. Boosters

Remplacent l'ancien système de « pixels stockés » (streak 5 jours → +5 pixels, cap 5), qui est supprimé.

- **1 booster = 5 pixels révélés** sur une image au choix, **uniquement parmi celles auxquelles l'utilisateur a déjà accès** (un booster ne débloque jamais une image verrouillée).

### 3.1 Gagner des boosters (streak)
- **Tous les 3 jours consécutifs** → +1 booster.
- **Tous les 18 jours consécutifs** (18, 36, 54…) → +1 booster supplémentaire.
- Premium : **+2 boosters au début de chaque mois**.
- Stock maximum de boosters gagnés : **12**.

### 3.2 Utiliser des boosters

| | Gratuit | Premium |
|---|---|---|
| Boosters **gagnés** utilisables par jour | 1 | 3 |
| Boosters **achetés** | sans limite | sans limite |

- Deux stocks séparés : **gagnés** (soumis à la limite du jour) et **achetés** (aucune limite, aucune expiration).
- Ordre de consommation : les gagnés d'abord tant que la limite du jour le permet, puis les achetés.

### 3.3 Achat de boosters (consommables)
| Lot | Prix |
|---|---|
| 1 booster | 0,99 € |
| 5 boosters | 3,99 € |
| 15 boosters | 9,99 € |

Note technique : un consommable n'est pas restauré par Apple → le stock acheté est sauvegardé par l'app (iCloud), puis sur le compte utilisateur quand Android et le web arriveront.

---

## 4. Packs thématiques

6 à 8 packs par an, **thèmes neutres et universels** : aucune fête religieuse ou semi-religieuse (pas de Noël, Halloween, Pâques…), pas de « Bonne année ».

### 4.1 Packs géographiques — cycle de 5 ans

| Année du cycle | Continent | Capitales |
|---|---|---|
| 1 | Europe | 8–10 capitales, tous continents |
| 2 | Asie | 8–10 autres capitales |
| 3 | Afrique | … |
| 4 | Amériques | … |
| 5 | Océanie & pôles | … |

Le cycle recommence ensuite avec de nouvelles images.

### 4.2 Packs saisonniers / thématiques
- Reviennent chaque année avec des **images spécifiques à l'année** (été 2027 ≠ été 2028).
- La liste des thèmes est **renouvelée tous les 5 ans**.
- Exemples : Printemps & nature, Vacances d'été, Saveurs du monde (semaine du goût), Océans, Espace…

### 4.3 Fin d'année (remplace tout pack « nouvel an »)
- **Rétrospective** de l'année écoulée : faits marquants **positifs ou consensuels uniquement** (sport, espace, science, culture, nature).
- **L'année à venir** : sans vœux ni « bonne année ».

### 4.4 Règles de neutralité du contenu
- Pas de drapeaux, pas de territoires ou capitales au statut contesté.
- Pas d'édifices religieux : privilégier monuments civils, paysages, faune, cuisine.
- Pas de politique, conflits ou catastrophes.

### 4.5 Accès aux packs
- Les packs (thématiques, continents, capitales) sont **réservés au Premium** : pas de défi gratuit pour les débloquer.
- Packs de l'**année en cours** : inclus dans le Premium.

| Pack | Premium | Gratuit (achat à l'unité) |
|---|---|---|
| Année en cours | inclus | 3,99 € |
| Années précédentes | 2,99 € | 2,99 € |

- Fin du Premium en cours d'année : les images de pack terminées restent dans la collection ; les packs en cours se bloquent mais restent rachetables.
- Côté Apple : 2 produits par pack (`pack_<id>` à 3,99 € pendant l'année, `pack_<id>_archive` à 2,99 € ensuite).
- Un pack acheté est définitif (règle Apple).

---

## 5. Identité utilisateur & multiplateforme

- **V1 (iOS)** : pas de compte. La date du premier lancement est stockée dans le **trousseau iCloud** (résiste à la réinstallation) pour la règle du cadeau de bienvenue.
- **Cible (Android, web)** : il faudra un compte utilisateur et un backend pour partager achats et progression entre plateformes.
  - Le code isole les droits d'accès derrière un service unique (`EntitlementService`) pour pouvoir brancher ensuite un fournisseur multiplateforme (ex. RevenueCat) sans réécrire le jeu.

---

## 6. Contenu

Environ 500 images par an (365 daily, 52 weekly, 12 monthly, et les packs).
- Le catalogue et les images sont **téléchargés depuis un hébergement statique** (ex. GitHub Pages), ce qui permet de publier sans mise à jour App Store.
- Un contenu minimal est embarqué dans l'app pour le mode hors ligne et le premier lancement.
