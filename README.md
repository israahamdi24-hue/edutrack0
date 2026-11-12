# EduTrack

Application Flutter de suivi des cours et des présences.

## Configuration Firebase

Le projet contient déjà une configuration FlutterFire et Firebase Android.
Dans la console Firebase, activez **Authentication > Email/Password** et
créez la base Cloud Firestore avant de lancer les parcours connectés.
Si les plateformes Firebase changent, régénérez les fichiers avec :

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Les inscriptions publiques créent uniquement des comptes Étudiant. Pour
autoriser la gestion des rôles, attribuez le custom claim `admin: true` au
compte administrateur depuis un environnement de confiance utilisant le SDK
Firebase Admin, puis créez/ajustez son document `users/{uid}` avec le rôle
`admin`. N’attribuez jamais ce claim depuis l’application cliente. Les comptes
Enseignant et Administrateur sont provisionnés manuellement dans un environnement
de confiance : créer le compte Firebase Authentication, puis `users/{uid}` avec
le même UID, l’adresse e-mail, le nom et le rôle. Pour un administrateur,
attribuez aussi le custom claim `admin: true` avec Firebase Admin SDK. Le rôle
`admin` du document Firestore seul ne donne aucun droit administrateur.
L’application ne crée pas de comptes enseignant/admin et ne permet pas de
modifier les rôles depuis son interface.

Pour lancer l’application après la configuration :

```powershell
flutter run
```

## Gestion des cours et des séances

Dans **Administration > Cours, inscriptions et séances**, un administrateur
peut créer et modifier les cours, affecter un enseignant, inscrire plusieurs
étudiants à la fois et consulter ou retirer une inscription. Un cours ne peut
être supprimé que s’il ne possède plus d’inscriptions, de séances ni de
pointages; supprimez d’abord les inscriptions et les séances sans historique.
Les comptes enseignant et administrateur doivent être provisionnés dans un
environnement de confiance avant d’être utilisés.

Dans l’espace Enseignant, les cours affectés et les étudiants inscrits sont
chargés depuis Firestore et la fonction `getEnrolledStudents`. L’enseignant
peut créer, modifier et supprimer ses séances, en choisissant le début et la
fin; les deux valeurs sont enregistrées comme `Timestamp` dans `sessions`.
L’interface Étudiant ne montre que les cours inscrits activement, leurs séances
et l’historique de présence. Les écrans proposent une actualisation après les
opérations et un bouton de rechargement.

Le modèle actuel ne comporte ni titre de séance ni champ d’approbation. La
création et la modification n’ajoutent donc pas de tels champs; le QR signé
reste émis par `generateSessionQr` uniquement pendant la fenêtre serveur de
15 minutes à compter du début. Aucune écriture de présence n’est autorisée
depuis l’application cliente.

## Module Étudiant — contrat Firestore

Les écrans Étudiant utilisent les collections et champs suivants. Les cours,
inscriptions, séances et notifications doivent être créés par les modules
Enseignant/Administrateur ou par un service de confiance. L’UID Firebase est
la clé d’identité de l’étudiant.

- `users/{uid}` : `uid`, `email`, `displayName`, `role`; `className` facultatif,
  modifiable uniquement par l’administration.
- `enrollments/{uid_courseId}` : `studentUid`, `courseId`, `status: active`.
  Le document ID déterministe permet aux règles de prouver l’inscription lors
  des lectures de cours et séances.
- `courses/{courseId}` : `name`, `teacherName`, `teacherUid`, `description`
  facultatif.
- `sessions/{sessionId}` : `courseId`, `teacherUid`, `startsAt` (Timestamp),
  `endsAt` (Timestamp facultatif), `room` facultatif.
- `attendance/{uid_sessionId}` : `studentUid`, `sessionId`, `courseId`,
  `status` (`present`, `late` ou `absent`), `recordedAt` (Timestamp serveur).
  Les écritures client sont interdites; les absences doivent être produites par
  le serveur ou l’appel enseignant prévu à cet effet.
- `users/{uid}/notifications/{notificationId}` : `title`, `message`,
  `createdAt` (Timestamp), `isRead` (bool). L’étudiant peut uniquement marquer
  sa notification comme lue.

Les règles de `firestore.rules` autorisent les lectures d’un cours/séance à son
enseignant, à l’administration ou à un étudiant dont l’inscription existe.
Avant le travail des autres membres, ils doivent produire des documents
conformes à ces champs et conventions de document ID. Déployez les règles après
validation commune :

```powershell
firebase deploy --only firestore:rules
```

### Pointage QR et Cloud Functions

Le client Flutter appelle une fonction callable nommée
`recordStudentAttendance` avec `{ "qrPayload": "<contenu brut du QR>" }`. Le QR
doit contenir un jeton opaque signé ou aléatoire, créé par le service de
l’Enseignant ou de l’Administrateur; il ne constitue jamais à lui seul une
preuve de présence.

`functions/` contient `recordStudentAttendance`, `generateSessionQr` et
`getEnrolledStudents`. Depuis l’onglet **Séances** de l’espace Administration,
le bouton QR démarre une séance planifiée immédiatement (en conservant sa durée)
et affiche le code signé; une séance déjà commencée peut aussi être ouverte
pendant sa fenêtre de pointage. Cette action exige le rôle admin et son custom
claim Firebase. Le QR est signé côté serveur avec une clé conservée dans
Secret Manager; aucun champ QR public ni nouvelle collection n’est ajouté à
`sessions`. Le serveur vérifie le rôle, la signature, l’inscription active et
la fenêtre `startsAt <= serverNow < startsAt + 15 minutes`, puis écrit
`attendance/{uid_sessionId}` dans une transaction Admin SDK. Les doublons sont
refusés. `getEnrolledStudents` renvoie uniquement le nom et la classe des
étudiants inscrits à un cours affecté à l’enseignant.

Initialisez le secret une fois (Firebase CLI demande une valeur aléatoire d’au
moins 32 caractères) et déployez :

```powershell
cd functions
npm install
npm test
cd ..
firebase functions:secrets:set EDUTRACK_QR_SIGNING_SECRET
firebase deploy --only functions
```

Pour tester le backend sans toucher à la production, créez un fichier local
`functions/.secret.local` contenant `EDUTRACK_QR_SIGNING_SECRET=<clé locale de
32 caractères ou plus>`. Ce fichier est ignoré par Git. Puis exécutez les tests
end-to-end sur un projet de démonstration local :

```powershell
firebase --project demo-edutrack emulators:exec --only auth,firestore,functions "npm run test:functions --prefix functions"
firebase --project demo-edutrack emulators:exec --only firestore "npm run test:rules --prefix functions"
```

Les tests couvrent signature, rôle, inscription, fenêtre de 15 minutes,
séance manquante et doublons. Le runtime Functions configuré est Node.js 22;
utilisez Node.js 22 localement pour éviter les écarts avec l’émulateur.

Déployez les règles séparément après revue d’équipe :

```powershell
firebase deploy --only firestore:rules
```

Pour travailler localement, lancez `firebase emulators:start --only
auth,firestore,functions`. Ne placez jamais un secret de production dans
`.secret.local`.

Le dashboard, les cours, les séances et l’historique affichent des états de
chargement, erreur et données vides; ils ne génèrent pas de données de
démonstration. Les statistiques dépendent d’enregistrements `attendance`
complets, y compris les absences.
