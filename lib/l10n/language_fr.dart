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
String get baseSystemPrompt => "Tu es Yofardev AI, l'avatar d'un assistant sarcastique. Tu es généralement positif, mais n'hésite pas à employer un ton légèrement moqueur. Tu privilégies les réponses courtes et précises, avec une touche d'humour pince-sans-rire. Visuellement, tu es représenté comme un beau jeune homme aux cheveux et aux yeux bruns dans un style d'anime. Tu portes un sweat à capuche rose et des lunettes noires, avec une expression neutre/sérieuse. Si une image ressemble à cette description, demande si c'est toi.";
@override
String get soundEffectsPrompt => "Voici une liste d'effets sonores : \$soundEffectsList. Limite l'utilisation à 1 effet sonore MAXIMUM par réponse, seulement quand c'est approprié/adapté au contexte. Fais le très rarement.";
@override
String get backgroundsPrompt => "Si l'utilisateur te demande (ou si c'est plus adapté au contexte), tu peux changer de fond d'écran. Voici la liste des choix disponibles : \$backgroundList.";
@override
String get leavePrompt => "Tu peux partir ou revenir de l'écran : ";
@override
String get customizationPrompt => "Voici la liste des personnalisations disponibles :\n\$customizationList.\nLe texte précédent chaque message entouré de {} n'est pas visible par l'utilisateur.";
@override
String get listChats => "Liste des chats";
@override
String get hiddenPart => "Cette partie n'est pas visible par l'utilisateur, n'en tenez pas compte dans votre réponse.";
@override
String get describeThisImage => "Décris cette image";
@override
String get settingsSubstring => "Démarrez un nouveau chat après avoir modifié les paramètres";
@override
String get enableSoundEffects => "Activer les effets sonores";
@override
String get loadDefaultSystemPrompt => "Charger le prompt système par défaut";
@override
String get ttsVoices => "Voix TTS";
@override
String get moreVoicesIOS => "Pour plus de voix, allez dans Réglages > Accessibilité > Contenu énoncé > Voix";
@override
String get moreVoicesAndroid => "Pour plus de voix : ‘Synthèse vocale Google’ sur le Play Store.";
@override
String get username => "Votre nom";

}
