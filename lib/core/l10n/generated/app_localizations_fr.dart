// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonError => 'Une erreur s\'est produite';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonDone => 'Terminé';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get test => 'test';

  @override
  String get appName => 'Yofardev AI';

  @override
  String get assistantTask => 'Assistant';

  @override
  String get currentAvatarConfig => 'Configuration de l’avatar actuelle';

  @override
  String get currentDate => 'Date actuelle';

  @override
  String get currentUsername => 'Nom de l’utilisateur';

  @override
  String get describeThisImage => 'Décris cette image';

  @override
  String get empty => '(vide)';

  @override
  String get enableSoundEffects => 'Activer les effets sonores';

  @override
  String get functionCallingLlmDescription =>
      'LLM utilisé pour la détection d\'outils/fonctions';

  @override
  String get functionCallingTask => 'Appel de fonctions';

  @override
  String get hiddenPart =>
      'Cette partie n\'est pas visible par l\'utilisateur, n\'en tenez pas compte dans votre réponse.';

  @override
  String get listChats => 'Liste des chats';

  @override
  String get loadDefaultSystemPrompt => 'Charger le prompt système par défaut';

  @override
  String get memory => 'Mémoire';

  @override
  String get memoryDescription =>
      'Les faits que votre avatar retient sur vous dans toutes les conversations';

  @override
  String get memoryPageSubtitle =>
      'Votre avatar retient des faits sur vous à travers toutes les conversations. Consultez-les, supprimez-les ou effacez-les ici.';

  @override
  String get enableMemory => 'Activer la mémoire globale';

  @override
  String get memoryEmpty =>
      'Rien de mémorisé pour l\'instant. Discutez avec votre avatar et il retiendra des faits sur vous.';

  @override
  String get clearMemory => 'Effacer toute la mémoire';

  @override
  String get clearMemoryConfirmation =>
      'Supprimer tous les faits mémorisés ? Cette action est irréversible.';

  @override
  String get memoryDeleted => 'Élément de mémoire supprimé';

  @override
  String get memoryTask => 'Extraction de mémoire';

  @override
  String get memoryLlmDescription =>
      'LLM utilisé pour extraire les faits de la mémoire globale';

  @override
  String get moreVoicesAndroid =>
      'Pour plus de voix : ‘Synthèse vocale Google’ sur le Play Store.';

  @override
  String get moreVoicesIOS =>
      'Pour plus de voix, allez dans Réglages > Accessibilité > Contenu énoncé > Voix';

  @override
  String get newChat => 'Nouvelle conversation';

  @override
  String get personaAssistant => 'Personnalité de l’assistant';

  @override
  String get personaNameAssistant => 'Assistant';

  @override
  String get personaNameNormal => 'Normal';

  @override
  String get personaNameDoomer => 'Doomer';

  @override
  String get personaNameConservative => 'Conservateur';

  @override
  String get personaNamePhilosopher => 'Philosophe';

  @override
  String get personaNameGeek => 'Geek';

  @override
  String get personaNameCoach => 'Coach';

  @override
  String get personaNamePsychologist => 'Psychologue';

  @override
  String get personaDescriptionAssistant => 'Utile, clair et équilibré.';

  @override
  String get personaDescriptionNormal =>
      'Ton neutre pour les échanges du quotidien.';

  @override
  String get personaDescriptionDoomer => 'Vision pessimiste et cynique.';

  @override
  String get personaDescriptionConservative =>
      'Points de vue traditionnels et prudents.';

  @override
  String get personaDescriptionPhilosopher =>
      'Réponses réfléchies avec un raisonnement plus profond.';

  @override
  String get personaDescriptionGeek =>
      'Style technique avec des références nerd.';

  @override
  String get personaDescriptionCoach =>
      'Conseils motivants, pratiques et orientés action.';

  @override
  String get personaDescriptionPsychologist =>
      'Approche empathique et introspective.';

  @override
  String get resultsFunctionCalling => 'Résultats de functions calling';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsSubstring =>
      'Démarrez un nouveau chat après avoir modifié les paramètres';

  @override
  String get settings_apiKey => 'Clé API';

  @override
  String get settings_enable => 'Activer';

  @override
  String get settings_engineId => 'ID de Moteur de Recherche';

  @override
  String get settings_functionCalling => 'Appel de Fonctions';

  @override
  String get settings_functionCalling_description =>
      'Configurez les clés API pour les fonctionnalités d\'appel de fonctions.';

  @override
  String get settings_functionCalling_saved => 'Configuration enregistrée';

  @override
  String get settings_googleSearch => 'Recherche Google';

  @override
  String get settings_googleSearch_description =>
      'Rechercher sur le web pour des informations actuelles.';

  @override
  String get settings_news => 'Actualités';

  @override
  String get settings_news_description =>
      'Obtenir les actualités les plus populaires du jour.';

  @override
  String get settings_save => 'Enregistrer';

  @override
  String get settings_weather => 'Météo';

  @override
  String get settings_weather_description =>
      'Obtenir la météo actuelle pour n\'importe quel lieu.';

  @override
  String get taskLlmConfig => 'Configuration LLM par tâche';

  @override
  String get taskLlmConfigDescription =>
      'Configurez différents LLM pour l\'assistant, la génération de titres et l\'appel de fonctions';

  @override
  String get taskLlmDescription =>
      'LLM utilisé pour les réponses principales du chat';

  @override
  String get taskLlmNote =>
      'Note: Si aucun LLM n’est sélectionné pour une tâche, le LLM assistant par défaut sera utilisé.';

  @override
  String get titleGenerationPrompt =>
      'Générez un titre concis (max 5 mots) pour cette conversation: ';

  @override
  String get titleGenerationSystemPrompt =>
      'Vous êtes un assistant utile qui génère des titres de conversation courts et descriptifs. Returnz uniquement le titre, sans guillemets ni texte supplémentaire.';

  @override
  String get titleLlmDescription =>
      'LLM utilisé pour générer les titres des conversations';

  @override
  String get titleTask => 'Génération de titre';

  @override
  String get ttsVoices => 'Voix TTS';

  @override
  String get useDefaultLlm => 'Utiliser le LLM par défaut';

  @override
  String get userMessage => 'Message de l’utilisateur';

  @override
  String get username => 'Votre nom';

  @override
  String get apiPicker => 'Sélection API';

  @override
  String get deleteChatTitle => 'Supprimer la conversation ?';

  @override
  String get deleteChatConfirmation =>
      'Cette conversation sera définitivement supprimée.';

  @override
  String get timeJustNow => 'à l\'instant';

  @override
  String timeMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String get timeYesterday => 'hier';

  @override
  String timeDaysAgo(int count) {
    return 'il y a $count j';
  }

  @override
  String get demoModeActivated => 'Mode démo activé';

  @override
  String get deleteConfig => 'Supprimer la configuration';

  @override
  String deleteConfigConfirmation(String configLabel) {
    return 'Êtes-vous sûr de vouloir supprimer \"$configLabel\" ?';
  }

  @override
  String get llmProviderSelection => 'Sélection du fournisseur LLM';

  @override
  String get noLlmConfigurations => 'Aucune configuration LLM trouvée.';

  @override
  String get addProvider => 'Ajouter un fournisseur';

  @override
  String get responseInterrupted => 'Réponse interrompue';

  @override
  String conversationDownloaded(String fileName) {
    return 'Conversation téléchargée : $fileName';
  }

  @override
  String failedToDownload(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get pageNotFound => 'Page non trouvée';

  @override
  String errorWithMessage(String message) {
    return 'Erreur : $message';
  }

  @override
  String get aiAssistantAvatar => 'Avatar de l\'assistant IA';

  @override
  String get failedToLoadLlmConfigs =>
      'Échec du chargement des configurations LLM';

  @override
  String get noLlmConfigurationSelected =>
      'Aucune configuration LLM sélectionnée';

  @override
  String get llmConfigAdd => 'Ajouter une configuration LLM';

  @override
  String get llmConfigEdit => 'Modifier la configuration LLM';

  @override
  String get llmConfigLabel => 'Nom (ex. Mon OpenAI)';

  @override
  String get llmConfigBaseUrl => 'URL de base';

  @override
  String get llmConfigBaseUrlHint => 'https://api.openai.com/v1';

  @override
  String get llmConfigApiKey => 'Clé API';

  @override
  String get llmConfigModelName => 'Nom du modèle (ex. gpt-4o)';

  @override
  String get llmConfigTemperature => 'Température :';

  @override
  String get llmConfigResponseFormat => 'Format de réponse JSON';

  @override
  String get llmConfigResponseFormatHelper =>
      'Format pour les réponses en mode JSON';

  @override
  String get llmConfigResponseFormatJsonObject => 'json_object (OpenAI)';

  @override
  String get llmConfigResponseFormatJsonSchema =>
      'json_schema (Certaines API locales)';

  @override
  String get llmConfigResponseFormatText => 'text (Générique)';

  @override
  String get llmConfigResponseFormatNone =>
      'none (Aucun format, utiliser uniquement le prompt)';

  @override
  String get commonRequired => 'Obligatoire';

  @override
  String get failureStorage =>
      'Échec de l\'enregistrement ou de la lecture des données';

  @override
  String get failureNetwork => 'Erreur réseau';

  @override
  String get failureTts => 'Erreur de synthèse vocale';

  @override
  String get failureConfig => 'Erreur de configuration';

  @override
  String get failureUnknown => 'Une erreur inattendue est survenue';

  @override
  String get googleSearchApiTitle => 'Google Search API';

  @override
  String get googleSearchApiKeyHint => 'Saisissez votre clé API Google Search';

  @override
  String get searchEngineIdHint => 'Saisissez votre ID de moteur de recherche';

  @override
  String get openWeatherApiTitle => 'OpenWeather API';

  @override
  String get openWeatherApiKeyHint => 'Saisissez votre clé API OpenWeather';

  @override
  String get nytApiTitle => 'New York Times API';

  @override
  String get nytApiKeyHint => 'Saisissez votre clé API New York Times';

  @override
  String chatMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
      zero: '0 message',
    );
    return '$_temp0';
  }

  @override
  String functionResultTitle(String name) {
    return 'Résultat : $name';
  }

  @override
  String get toolSearching => 'Recherche sur le web…';

  @override
  String get toolWeather => 'Je regarde la météo…';

  @override
  String get toolNews => 'Je lis les nouvelles…';

  @override
  String get toolMemory => 'Je fouille ma mémoire…';

  @override
  String get toolWorking => 'Je m\'en occupe…';

  @override
  String get askAnything => 'Demande-moi n\'importe quoi…';

  @override
  String get micPermissionDenied =>
      'Autorise le micro dans les réglages pour me parler.';

  @override
  String get micUnavailable => 'La dictée n\'est pas disponible ici.';

  @override
  String get composerAttach => 'Joindre une image';

  @override
  String get composerTools => 'Outils';

  @override
  String get composerSend => 'Envoyer';

  @override
  String get composerStop => 'Arrêter';

  @override
  String get composerListen => 'Parler';

  @override
  String get composerMore => 'Plus d\'options';

  @override
  String get stageHistory => 'Historique';

  @override
  String get stageShowCaptions => 'Afficher les sous-titres';

  @override
  String get stageHideCaptions => 'Masquer les sous-titres';

  @override
  String get stageDemo => 'Lancer la démo';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameFrench => 'Français';

  @override
  String get stageMenu => 'Menu';

  @override
  String stageLanguageSwitch(Object language) {
    return 'Langue : $language';
  }

  @override
  String get stageScenes => 'Décors';

  @override
  String get scenePickerTitle => 'Choisir un décor';

  @override
  String get sceneLivingRoom => 'Salon';

  @override
  String get sceneCampfire => 'Feu de camp';

  @override
  String get sceneBeach => 'Plage';

  @override
  String get sceneDeepSpace => 'Espace';

  @override
  String get sceneCafe => 'Café';

  @override
  String get sceneRooftop => 'Toit-terrasse';

  @override
  String get sceneMountainHut => 'Refuge';

  @override
  String get sceneForestCabin => 'Cabane en forêt';

  @override
  String get sceneTrainCompartment => 'Compartiment de train';

  @override
  String get sceneLibrary => 'Bibliothèque';

  @override
  String stageSemanticsLabel(Object name, Object scene) {
    return '$name dans le décor $scene';
  }

  @override
  String get stagePhaseIdle => 'au repos';

  @override
  String get stagePhaseListening => 'à l’écoute';

  @override
  String get stagePhaseThinking => 'réfléchit';

  @override
  String get stagePhaseSpeaking => 'parle';

  @override
  String get scenePickerCurrentHint => 'Décor actuel';

  @override
  String get stagePropLamp => 'Toucher la lampe';

  @override
  String get stagePropTv => 'Toucher la télé';

  @override
  String get stagePropCat => 'Taquiner le chat';

  @override
  String get stagePropPlant => 'Toucher la plante';

  @override
  String get stagePropFire => 'Toucher le feu';

  @override
  String get stagePropTent => 'Toucher la tente';

  @override
  String get stagePropOwl => 'Taquiner le hibou';

  @override
  String get stagePropSky => 'Regarder le ciel';

  @override
  String get stagePropCrab => 'Taquiner le crabe';

  @override
  String get stagePropUmbrella => 'Toucher le parasol';

  @override
  String get stagePropSeagull => 'Taquiner la mouette';

  @override
  String get stagePropPlanet => 'Toucher la planète';

  @override
  String get stagePropUfo => 'Toucher l’OVNI';

  @override
  String get stagePropRubberDuck => 'Presser le canard en plastique';

  @override
  String get stagePropCup => 'Toucher la tasse';

  @override
  String get stagePropEspresso => 'Lancer la machine à expresso';

  @override
  String get stagePropWindow => 'Toucher la fenêtre';

  @override
  String get stagePropFish => 'Toucher le poisson';

  @override
  String get stagePropTelescope => 'Regarder dans le télescope';

  @override
  String get stagePropAntenna => 'Toucher l’antenne';

  @override
  String get stagePropPigeon => 'Taquiner le pigeon';

  @override
  String get stagePropMoon => 'Regarder la lune';

  @override
  String get stagePropStove => 'Toucher le poêle';

  @override
  String get stagePropDog => 'Caresser le chien';

  @override
  String get stagePropBell => 'Sonner la cloche';

  @override
  String get stagePropLantern => 'Toucher la lanterne';

  @override
  String get stagePropPinwheel => 'Toucher le moulinet';

  @override
  String get stagePropSquirrel => 'Taquiner l’écureuil';

  @override
  String get stagePropWoodpile => 'Toucher le tas de bois';

  @override
  String get stagePropSuitcase => 'Toucher la valise';

  @override
  String get stagePropLadybug => 'Taquiner la coccinelle';

  @override
  String get stagePropBook => 'Ouvrir le livre';

  @override
  String get stagePropGlobe => 'Faire tourner le globe';

  @override
  String get stagePropClock => 'Toucher l’horloge';

  @override
  String get stagePropMouse => 'Taquiner la souris';

  @override
  String get stageDragCord => 'Tirer le cordon de la lampe';

  @override
  String get stageDragPoke => 'Attiser le feu';

  @override
  String get stageDragSand => 'Dessiner dans le sable';

  @override
  String get stageDragSpin => 'Faire tourner la planète';

  @override
  String get stageDragWipe => 'Essuyer la vitre embuée';

  @override
  String get stageDragAim => 'Pivoter le télescope';

  @override
  String get stageDragRope => 'Tirer la corde de la cloche';

  @override
  String get stageDragPinwheel => 'Faire tourner le moulinet';

  @override
  String get stageDragChain => 'Tirer la chaîne d’alarme';

  @override
  String get stageDragLadder => 'Faire glisser l’échelle';

  @override
  String get ttsVoiceTitle => 'Voix Kokoro';

  @override
  String get ttsVoiceSource =>
      'Téléchargement unique de 132 Mo depuis GitHub (k2-fsa/sherpa-onnx). Ensuite, tout reste sur l\'appareil.';

  @override
  String get ttsVoiceNotInstalled => 'Pas encore installée';

  @override
  String ttsVoiceDownloading(Object percent) {
    return 'Téléchargement… $percent %';
  }

  @override
  String get ttsVoiceDownloadingStarted => 'Téléchargement…';

  @override
  String get ttsVoiceExtracting => 'Installation…';

  @override
  String get ttsVoiceLoading => 'Chargement…';

  @override
  String get ttsVoiceReady => 'Prête, sur cet appareil';

  @override
  String get ttsVoiceFailed => 'Échec de l\'installation';

  @override
  String get ttsVoiceRetry => 'Réessayer';

  @override
  String get ttsVoiceDownload => 'Télécharger';

  @override
  String get ttsVoiceFallbackNote => 'En attendant, la voix de secours parle.';

  @override
  String get ttsVoiceBannerTitle => 'Installation de la nouvelle voix';

  @override
  String get ttsVoiceDismiss => 'Masquer';

  @override
  String get llmSetupTitle => 'Connectez une IA pour commencer à discuter';

  @override
  String get llmSetupBody =>
      'Ajoutez une clé d\'API (compatible OpenAI ou Gemini). Elle reste sur cet appareil.';

  @override
  String get llmSetupAction => 'Configurer';

  @override
  String get llmSetupDismiss => 'Plus tard';
}
