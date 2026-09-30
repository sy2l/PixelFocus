# PixelFocus — Guide de mise en production

Tout ce qu'il reste à faire **de ton côté** pour passer de l'app de développement à l'App Store.
Les étapes sont dans l'ordre ; chacune indique comment vérifier qu'elle est faite.

---

## 1. Tester en local (sans App Store Connect ni serveur)

1. **Achats de test** — Xcode › *Product › Scheme › Edit Scheme… › Run › Options* › **StoreKit Configuration** : choisir `PixelFocus.storekit` (à la racine du dépôt).
   → La boutique affiche les prix (2,99 €, 24,99 €…) et les achats fonctionnent dans le simulateur. *Debug › StoreKit › Manage Transactions* permet de rembourser ou d'expirer un achat.
2. **Premium simulé** — Réglages › *Premium simulé (développement)* : pour tester sans acheter (n'existe pas dans la version App Store).
3. **Sans serveur**, la synchronisation affiche « Hors ligne » : tout fonctionne en local.

> Si Xcode refuse d'ouvrir `PixelFocus.storekit`, le recréer : *File › New › File › StoreKit Configuration File*, puis ajouter les produits de la section 3.

## 2. Capacités du projet Xcode

Cible **PixelFocus** › *Signing & Capabilities* › **+ Capability** :
- **Sign in with Apple** (bouton « Se connecter avec Apple » dans Réglages)
- **In-App Purchase**

## 3. App Store Connect

### 3.1 Contrats
*Accords, taxes et banque* : signer l'accord **Apps payantes** et renseigner banque et fiscalité (sans cela, aucun achat ne fonctionne).
Adhérer au **Small Business Program** (commission de 15 %).

### 3.2 Produits (identifiants exacts, voir `PixelFocus/Store/StoreProducts.swift`)

| Identifiant | Type | Prix |
|---|---|---|
| `com.sy2l.pixelfocus.premium.monthly` | Abonnement auto-renouvelable (groupe « PixelFocus Premium ») | 2,99 € / mois |
| `com.sy2l.pixelfocus.premium.yearly` | Abonnement auto-renouvelable (même groupe), offre de lancement : 1 semaine gratuite | 24,99 € / an |
| `com.sy2l.pixelfocus.lifetime` | Non consommable | 69,99 € |
| `com.sy2l.pixelfocus.lifetime.member` | Non consommable | 49,99 € |
| `com.sy2l.pixelfocus.boosters.1` / `.5` / `.15` | Consommable | 0,99 € / 3,99 € / 9,99 € |
| `com.sy2l.pixelfocus.monthly.AAAA_MM` | Non consommable (un par mois) | 1,99 € |
| `com.sy2l.pixelfocus.monthly.AAAA_MM.reduced` | Non consommable (un par mois) | 0,99 € |
| `com.sy2l.pixelfocus.pack.<id>` / `.archive` | Non consommable (un par pack) | 3,99 € / 2,99 € |

Les produits « image du mois » et « pack » sont nombreux : ils seront créés automatiquement via l'API App Store Connect (prochaine étape).

### 3.3 Clé d'API pour le serveur
*Utilisateurs et accès › Intégrations › Achats intégrés* : générer une clé. Noter l'**Issuer ID** et le **Key ID**, télécharger le fichier **`AuthKey_XXXX.p8`** (une seule fois possible).

### 3.4 Notifications du serveur
*App › Informations sur l'app › Notifications du serveur App Store* :
- Production et bac à sable : `https://api.tondomaine.fr/v1/webhooks/apple`
- Version : **Version 2**

## 4. Serveur (o2switch)

Suivre [`server/README.md`](server/README.md), puis dans `server/config/config.php` :
- la base MySQL,
- le bloc `apple` : `issuer_id`, `key_id`, et `private_key_path` vers le `.p8` (placé dans `server/config/`, jamais dans `public/`).

Vérifier : `https://api.tondomaine.fr/v1/health` → `{"ok":true,...}`

## 5. Brancher l'app sur le serveur

Dans `PixelFocus/App/AppConfig.swift`, remplacer :
```swift
static let apiBaseURLString = "https://api.CHANGE-ME.fr"
```
par l'adresse réelle. Vérifier dans l'app : Réglages › *Compte et synchronisation* → « Synchronisé ».

## 6. Contenu

- `tools/generate_test_content.py` a produit du **contenu de test** : à remplacer par les vraies œuvres.
- Convertir une image : `python3 tools/image_to_artwork.py image.png --id daily_2027_02_14 --title "…" --mode daily`
- Vérifier : `python3 tools/catalog_tool.py check`
- Relire visuellement : `python3 tools/catalog_tool.py preview --month 2027-02` (ouvre `build/catalog-preview.html`)

## 7. Obligations App Store (vérifiées par Apple)

- [ ] Politique de confidentialité en ligne, lien dans Réglages (`SettingsView`) et dans la fiche App Store
- [ ] Conditions d'utilisation (le contrat standard d'Apple convient, lien déjà dans la boutique)
- [ ] Bouton « Restaurer les achats » (présent : boutique et Réglages)
- [ ] Suppression du compte dans l'app (présent : Réglages)
- [ ] « Se connecter avec Apple » proposé avant toute autre connexion (présent)
- [ ] Fiche « Confidentialité » dans App Store Connect : identifiant utilisateur (non lié à l'identité), historique d'utilisation de l'app, achats
- [ ] Remplacer les liens `https://example.com/...` par les vraies URL

## 8. Avant la soumission

- [ ] Compiler en **Release** : l'interrupteur « Premium simulé » disparaît
- [ ] Tester un achat réel en **TestFlight** (bac à sable) : le serveur doit enregistrer l'achat (`/v1/state` → `entitlements`)
- [ ] Tester sur deux appareils : Se connecter avec Apple sur le second → la progression est retrouvée
