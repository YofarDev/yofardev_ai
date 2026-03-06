import 'languages.dart';

class LanguageFr extends Languages {
  ///   Global   ///
  @override
  String get appName => "Yofardev AI";
  @override
  String get empty => "(vide)";
  @override
  String get settings => "Paramètres";
  @override
  String get listChats => "Liste des chats";
  @override
  String get hiddenPart =>
      "Cette partie n'est pas visible par l'utilisateur, n'en tenez pas compte dans votre réponse.";
  @override
  String get describeThisImage => "Décris cette image";
  @override
  String get settingsSubstring =>
      "Démarrez un nouveau chat après avoir modifié les paramètres";
  @override
  String get enableSoundEffects => "Activer les effets sonores";
  @override
  String get loadDefaultSystemPrompt => "Charger le prompt système par défaut";
  @override
  String get ttsVoices => "Voix TTS";
  @override
  String get moreVoicesIOS =>
      "Pour plus de voix, allez dans Réglages > Accessibilité > Contenu énoncé > Voix";
  @override
  String get moreVoicesAndroid =>
      "Pour plus de voix : ‘Synthèse vocale Google’ sur le Play Store.";
  @override
  String get username => "Votre nom";
  @override
  String get userMessage => "Message de l’utilisateur";
  @override
  String get currentDate => "Date actuelle";
  @override
  String get currentAvatarConfig => "Configuration de l’avatar actuelle";
  @override
  String get currentUsername => "Nom de l’utilisateur";
  @override
  String get resultsFunctionCalling => "Résultats de functions calling";
  @override
  String get personaAssistant => "Personnalité de l’assistant";

  ///   Task LLM Config   ///
  @override
  String get newChat => "Nouvelle conversation";
  @override
  String get taskLlmConfig => "Configuration LLM par tâche";
  @override
  String get assistantTask => "Assistant";
  @override
  String get titleTask => "Génération de titre";
  @override
  String get functionCallingTask => "Appel de fonctions";
  @override
  String get useDefaultLlm => "Utiliser le LLM par défaut";
  @override
  String get taskLlmNote =>
      "Note: Si aucun LLM n’est sélectionné pour une tâche, le LLM assistant par défaut sera utilisé.";
  @override
  String get taskLlmDescription =>
      "LLM utilisé pour les réponses principales du chat";
  @override
  String get titleLlmDescription =>
      "LLM utilisé pour générer les titres des conversations";
  @override
  String get functionCallingLlmDescription =>
      "LLM utilisé pour la détection d'outils/fonctions";

  @override
  String get titleGenerationPrompt =>
      "Générez un titre concis (max 5 mots) pour cette conversation: ";

  @override
  String get titleGenerationSystemPrompt =>
      "Vous êtes un assistant utile qui génère des titres de conversation courts et descriptifs. Returnz uniquement le titre, sans guillemets ni texte supplémentaire.";
}
