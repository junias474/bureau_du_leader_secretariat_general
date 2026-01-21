# Gestionnaire d'Archives - Bureau du Leader

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![License](https://img.shields.io/badge/License-Proprietary-red.svg)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)

## 📋 Description

**Gestionnaire d'Archives** est une solution professionnelle de gestion documentaire développée par le **Département de la Communication** pour le **Secrétariat Général du Bureau du Leader**. Cette application desktop permet d'organiser, archiver, sécuriser et retrouver facilement tous vos documents importants.

### 🎯 Objectif

Fournir une solution complète et sécurisée pour la gestion des archives administratives avec une interface moderne et intuitive, tout en garantissant la confidentialité et l'intégrité des documents.

## ✨ Fonctionnalités Principales

### 📁 Gestion Hiérarchique
- **Organisation en 3 niveaux** : Compartiments → Archives → Documents
- Création et gestion de compartiments thématiques
- Archives avec titre et sous-titre descriptifs
- Support de multiples formats de documents (PDF, images, Word, Excel, etc.)

### 🔒 Sécurité Avancée
- **Authentification** : Mot de passe principal obligatoire à l'ouverture
- **Archives verrouillées** : Système de verrouillage avec mot de passe global
- **Chiffrement** : Mots de passe chiffrés avec SHA-256
- **Réinitialisation sécurisée** : Double confirmation avec mot de passe

### 🔍 Recherche Intelligente
- **Recherche rapide** : Barre de recherche globale instantanée
- **Recherche avancée** : Filtres multi-critères
  - Par compartiment
  - Par archive
  - Par type de document
  - Par nom de document

### 📊 Rapports et Statistiques
- **Génération de rapports PDF professionnels**
  - Vue d'ensemble des statistiques globales
  - Analyse détaillée par compartiment
  - Journal d'activité récente
  - Export avec en-tête et pied de page personnalisés
  
- **Filtrage temporel**
  - Aujourd'hui
  - Cette semaine
  - Ce mois
  - Période personnalisée

- **Statistiques en temps réel**
  - Nombre de compartiments, archives et documents
  - Moyenne de documents par archive
  - Répartition par compartiment

### 💾 Sauvegarde et Restauration
- **Sauvegarde complète** : Export de la base de données vers l'emplacement de votre choix
- **Restauration** : Import d'une sauvegarde précédente avec confirmation
- **Réinitialisation** : Suppression totale des données avec double confirmation

### 📄 Gestion des Documents
- **Ajout multiple** : Importation simultanée de plusieurs fichiers
- **Visualisation** : Ouverture directe des documents
- **Suppression** : Retrait des documents avec suppression du fichier physique
- **Organisation** : Tri et affichage par nom

## 🛠️ Technologies Utilisées

### Framework et Langage
- **Flutter 3.0+** : Framework multiplateforme de Google
- **Dart 3.0+** : Langage de programmation moderne et performant

### Base de Données
- **SQLite** : Base de données locale relationnelle
- **sqflite_common_ffi** : Support desktop haute performance
- **Crypto (SHA-256)** : Chiffrement sécurisé des mots de passe

### Génération de Documents
- **pdf** : Création de rapports PDF professionnels
- **open_file** : Ouverture automatique des fichiers générés

### Utilitaires
- **intl** : Internationalisation et formatage des dates
- **path_provider** : Accès aux répertoires système
- **file_picker** : Sélection de fichiers et dossiers
- **Material Design 3** : Interface utilisateur moderne

## 📦 Installation

### Prérequis

- **Flutter SDK** : Version 3.0 ou supérieure
- **Dart SDK** : Version 3.0 ou supérieure
- Système d'exploitation : Windows, macOS ou Linux

### Étapes d'installation

1. **Cloner le projet**
```bash
git clone https://github.com/votre-organisation/bureau_du_leader_secretariat_general.git
cd bureau_du_leader_secretariat_general
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Vérifier la configuration Flutter**
```bash
flutter doctor
```

4. **Lancer l'application**
```bash
flutter run -d windows  # Pour Windows
flutter run -d macos    # Pour macOS
flutter run -d linux    # Pour Linux
```

## 🏗️ Structure du Projet

```
lib/
├── main.dart                 # Point d'entrée de l'application
├── database.dart             # Gestion de la base de données SQLite
├── pages/
│   ├── login_page.dart       # Page de connexion
│   ├── home_page.dart        # Page d'accueil avec navigation
│   ├── dashboard_page.dart   # Tableau de bord principal
│   ├── compartments_page.dart # Gestion des compartiments
│   ├── archives_page.dart    # Gestion des archives
│   ├── documents_page.dart   # Gestion des documents
│   ├── search_page.dart      # Page de recherche
│   ├── reports_page.dart     # Rapports et statistiques
│   ├── settings_page.dart    # Paramètres et configuration
│   ├── about_page.dart       # À propos de l'application
│   └── locked_archives_page.dart # Gestion des archives verrouillées
└── assets/
    └── logo.png              # Logo de l'application
```

## 🗄️ Structure de la Base de Données

### Tables Principales

#### 1. `users` - Utilisateurs
- `id` : Identifiant unique (INTEGER PRIMARY KEY)
- `password_hash` : Hash SHA-256 du mot de passe (TEXT)
- `created_at` : Date de création (TEXT ISO-8601)

#### 2. `compartments` - Compartiments
- `id` : Identifiant unique (INTEGER PRIMARY KEY)
- `name` : Nom du compartiment (TEXT)
- `description` : Description (TEXT)
- `created_at` : Date de création (TEXT ISO-8601)

#### 3. `archives` - Archives
- `id` : Identifiant unique (INTEGER PRIMARY KEY)
- `compartment_id` : Référence au compartiment (INTEGER FK)
- `name` : Nom de l'archive (TEXT)
- `subtitle` : Sous-titre (TEXT)
- `is_locked` : État de verrouillage (INTEGER 0/1)
- `password_hash` : Hash du mot de passe si verrouillée (TEXT)
- `created_at` : Date de création (TEXT ISO-8601)

#### 4. `documents` - Documents
- `id` : Identifiant unique (INTEGER PRIMARY KEY)
- `archive_id` : Référence à l'archive (INTEGER FK)
- `name` : Nom du document (TEXT)
- `file_path` : Chemin du fichier (TEXT)
- `file_type` : Type de fichier (TEXT)
- `added_at` : Date d'ajout (TEXT ISO-8601)

#### 5. `locked_archives_settings` - Configuration des archives verrouillées
- `id` : Toujours 1 (INTEGER PRIMARY KEY)
- `password_hash` : Hash du mot de passe global (TEXT)
- `created_at` : Date de création (TEXT ISO-8601)

## 🚀 Utilisation

### Premier Lancement

1. Au premier démarrage, créez votre **mot de passe principal**
2. Ce mot de passe sera requis à chaque ouverture de l'application

### Workflow Standard

1. **Créer un compartiment** (ex: "Ressources Humaines", "Finances", etc.)
2. **Ajouter des archives** dans le compartiment (ex: "Contrats 2024", "Factures Q1")
3. **Importer des documents** dans chaque archive
4. **Verrouiller les archives sensibles** si nécessaire
5. **Générer des rapports** pour suivre l'activité

### Fonctionnalités Avancées

#### Verrouillage d'Archives
1. Accédez à une archive
2. Activez l'option "Verrouiller l'archive"
3. Définissez le mot de passe global (première fois uniquement)
4. L'archive nécessitera le mot de passe pour être ouverte

#### Génération de Rapports
1. Allez dans l'onglet "Rapports"
2. Sélectionnez la période souhaitée
3. Cliquez sur "Générer PDF"
4. Choisissez l'emplacement de sauvegarde
5. Le rapport s'ouvre automatiquement

#### Sauvegarde
1. Allez dans "Paramètres"
2. Cliquez sur "Sauvegarder"
3. Sélectionnez le dossier de destination
4. La sauvegarde est créée avec horodatage

## 🔐 Sécurité

### Bonnes Pratiques

- ✅ Utilisez un mot de passe complexe (minimum 4 caractères, recommandé 8+)
- ✅ Effectuez des sauvegardes régulières
- ✅ Ne partagez jamais vos mots de passe
- ✅ Vérrouillez les archives contenant des informations sensibles
- ⚠️ La réinitialisation supprime TOUTES les données de façon irréversible

### Chiffrement

- Tous les mots de passe sont chiffrés avec **SHA-256**
- Aucun mot de passe n'est stocké en clair
- Les fichiers sont stockés dans le répertoire système de l'application

## 📞 Support et Contact

### Développeur

Pour toute question, bug ou suggestion :

- **Téléphone** : +237 695 628 941 | +237 650 858 337
- **Email** : bedingjunias474@gmail.com

> ℹ️ **Note** : Le service client est en cours de mise en place. Contactez directement le développeur pour toute assistance.

### Organisation

**Développé par** : Département de la Communication  
**Pour** : Secrétariat Général - Bureau du Leader  
**Localisation** : Cameroun 🇨🇲

## 📝 Licence

© 2025 Gestionnaire d'Archives - Bureau du Leader. Tous droits réservés.

Ce logiciel est la propriété du **Bureau du Leader - Secrétariat Général**.  
Développé par le **Département de la Communication**.

**Usage interne uniquement** - Toute redistribution ou modification non autorisée est interdite.

## 🙏 Remerciements

- **Flutter Team** : Pour le framework exceptionnel
- **SQLite** : Pour la base de données robuste et performante
- **Département de la Communication** : Pour le développement
- **Bureau du Leader** : Pour la confiance accordée

---

**Version** : 1.0.0  
**Dernière mise à jour** : Janvier 2025  
**Développé avec ❤️ au Cameroun**

---

Pour toute contribution ou amélioration, veuillez contacter le Département de la Communication.