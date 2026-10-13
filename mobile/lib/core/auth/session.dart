import 'auth_mode.dart';

// Uma conta que o colaborador logado pertence (um usuário pode estar em
// mais de uma conta do Chatwoot/Duedesk - vem embutido na resposta do
// login, não existe endpoint separado "minhas contas").
class AgentAccount {
  const AgentAccount({required this.id, required this.name});

  final int id;
  final String name;

  factory AgentAccount.fromJson(Map<String, dynamic> json) => AgentAccount(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

// Tudo que o app precisa pra fazer uma requisição autenticada, guardado de
// uma vez (ver SessionStorage). Os campos usados dependem do `mode`:
// colaborador usa os 3 headers do devise_token_auth; cliente usa só
// `apiAccessToken`.
class Session {
  const Session({
    required this.mode,
    this.accessToken,
    this.client,
    this.uid,
    this.userId,
    this.pubsubToken,
    this.accounts = const [],
    this.selectedAccountId,
    this.apiAccessToken,
    this.contactId,
  });

  final AuthMode mode;

  // Colaborador (devise_token_auth).
  final String? accessToken;
  final String? client;
  final String? uid;
  final int? userId;
  final String? pubsubToken;
  final List<AgentAccount> accounts;
  final int? selectedAccountId;

  // Cliente final.
  final String? apiAccessToken;
  final int? contactId;

  // Só pergunta qual conta quando há mais de uma - a maioria dos
  // colaboradores tem só uma, e perguntar à toa é um passo a mais sem
  // necessidade.
  bool get needsAccountSelection =>
      mode == AuthMode.agent && selectedAccountId == null && accounts.length > 1;

  Session copyWith({
    String? accessToken,
    String? client,
    String? uid,
    int? selectedAccountId,
  }) =>
      Session(
        mode: mode,
        accessToken: accessToken ?? this.accessToken,
        client: client ?? this.client,
        uid: uid ?? this.uid,
        userId: userId,
        pubsubToken: pubsubToken,
        accounts: accounts,
        selectedAccountId: selectedAccountId ?? this.selectedAccountId,
        apiAccessToken: apiAccessToken,
        contactId: contactId,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'accessToken': accessToken,
        'client': client,
        'uid': uid,
        'userId': userId,
        'pubsubToken': pubsubToken,
        'accounts': accounts.map((account) => account.toJson()).toList(),
        'selectedAccountId': selectedAccountId,
        'apiAccessToken': apiAccessToken,
        'contactId': contactId,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        mode: AuthMode.values.byName(json['mode'] as String),
        accessToken: json['accessToken'] as String?,
        client: json['client'] as String?,
        uid: json['uid'] as String?,
        userId: json['userId'] as int?,
        pubsubToken: json['pubsubToken'] as String?,
        accounts: (json['accounts'] as List<dynamic>? ?? const [])
            .map((entry) => AgentAccount.fromJson(entry as Map<String, dynamic>))
            .toList(),
        selectedAccountId: json['selectedAccountId'] as int?,
        apiAccessToken: json['apiAccessToken'] as String?,
        contactId: json['contactId'] as int?,
      );
}
