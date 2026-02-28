import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bfm_app/auth/token_store.dart';
import 'package:bfm_app/api/api_client.dart';
import 'package:bfm_app/api/auth_api.dart';
import 'package:bfm_app/api/akahu_api.dart';
import 'package:bfm_app/api/messages_api.dart';
import 'package:bfm_app/api/profile_api.dart';
import 'package:bfm_app/api/content_api.dart';

/// Single shared [TokenStore] instance.
final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());

/// Dio-based HTTP client wired to [TokenStore].
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenStore: ref.watch(tokenStoreProvider)),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final akahuApiProvider = Provider<AkahuApi>(
  (ref) => AkahuApi(ref.watch(apiClientProvider)),
);

final messagesApiProvider = Provider<MessagesApi>(
  (ref) => MessagesApi(ref.watch(apiClientProvider)),
);

final profileApiProvider = Provider<ProfileApi>(
  (ref) => ProfileApi(ref.watch(apiClientProvider)),
);

final contentApiProvider = Provider<ContentApi>(
  (ref) => ContentApi(ref.watch(apiClientProvider)),
);
