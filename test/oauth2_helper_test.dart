import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:oauth2_client_at/access_token_response.dart';
import 'package:oauth2_client_at/oauth2_client.dart';
import 'package:oauth2_client_at/oauth2_exception.dart';
import 'package:oauth2_client_at/oauth2_helper.dart';
import 'package:oauth2_client_at/oauth2_response.dart';
import 'package:oauth2_client_at/src/secure_storage.dart';
import 'package:oauth2_client_at/src/token_storage.dart';
import 'package:oauth2_client_at/src/volatile_storage.dart';
import 'package:http/http.dart' as http;

class OAuth2ClientMock extends Mock implements OAuth2Client {}

class TokenStorageMock extends Mock implements TokenStorage {}

class SecureStorageMock extends Mock implements SecureStorage {}

class HttpClientMock extends Mock implements http.Client {}

void main() {
  final clientId = 'test_client';
  final clientSecret = 'test_secret';
  final scopes = ['scope1', 'scope2'];
  final accessToken = 'test_token';
  final renewedAccessToken = 'test_token_renewed';
  final tokenType = 'Bearer';
  final refreshToken = 'test_refresh_token';
  final expiresIn = 3600;

  final OAuth2Client oauth2Client = OAuth2ClientMock();
  final httpClient = HttpClientMock();

  // final String authorizeUrl = 'http://my.test.app/authorize';
  // final String tokenUrl = 'http://my.test.app/token';
  // final String revokeUrl = 'http://my.test.app/revoke';

  // when(oauth2Client.tokenUrl).thenReturn('my:/token/url');
  // when(oauth2Client.revokeUrl).thenReturn('my:/revoke/url');

  when(oauth2Client.tokenUrl).thenReturn('http://my.test.app/token');
  when(oauth2Client.revokeUrl).thenReturn('http://my.test.app/revoke');

  void _mockGetTokenWithAuthCodeFlow(oauth2Client,
      {Map<String, dynamic> respMap}) {
    var accessTokenMap = <String, dynamic>{
      'access_token': accessToken,
      'token_type': tokenType,
      'refresh_token': refreshToken,
      'scope': scopes,
      'expires_in': expiresIn,
      'http_status_code': 200
    };

    if (respMap != null) {
      respMap.forEach((k, v) => accessTokenMap[k] = v);
    }

    when(oauth2Client.getTokenWithAuthCodeFlow(
            clientId: clientId, clientSecret: clientSecret, scopes: scopes))
        .thenAnswer((_) async => AccessTokenResponse.fromMap(accessTokenMap));
  }

  void _mockGetTokenWithClientCredentials(oauth2Client,
      {Map<String, dynamic> respMap}) {
    var accessTokenMap = <String, dynamic>{
      'access_token': accessToken,
      'token_type': tokenType,
      'refresh_token': refreshToken,
      'scope': scopes,
      'expires_in': expiresIn,
      'http_status_code': 200
    };

    if (respMap != null) {
      respMap.forEach((k, v) => accessTokenMap[k] = v);
    }

    when(oauth2Client.getTokenWithClientCredentialsFlow(
            clientId: clientId, clientSecret: clientSecret, scopes: scopes))
        .thenAnswer((_) async => AccessTokenResponse.fromMap(accessTokenMap));
  }

  void _mockRefreshToken(oauth2Client) {
    when(oauth2Client.refreshToken(refreshToken,
            clientId: clientId, clientSecret: clientSecret))
        .thenAnswer((_) async => AccessTokenResponse.fromMap({
              'access_token': renewedAccessToken,
              'token_type': tokenType,
              'refresh_token': refreshToken,
              'scope': scopes,
              'expires_in': 3600,
              'http_status_code': 200
            }));
  }

  group('Authorization Code Grant.', () {
    test('Authorization Request without errors', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);
    });

    test('Authorization Request with token expiration', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client, respMap: {'expires_in': 1});

      _mockRefreshToken(oauth2Client);

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);

      await Future.delayed(const Duration(seconds: 2), () => 'X');

      tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, renewedAccessToken);
    });

    test('Post authorization Request with server side token expiration',
        () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);
      _mockRefreshToken(oauth2Client);

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      when(httpClient.post('https://my.test.url',
              body: null, headers: {'Authorization': 'Bearer ' + accessToken}))
          .thenAnswer(
              (_) async => http.Response('{"error": "invalid_token"}', 401));

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);

      await hlp.post('https://my.test.url', httpClient: httpClient);
      tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, renewedAccessToken);
    });

    test('Refresh token expiration', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);

      when(oauth2Client.refreshToken(refreshToken,
              clientId: clientId, clientSecret: clientSecret))
          .thenAnswer((_) async => AccessTokenResponse.fromMap(
              {'error': 'invalid_grant', 'http_status_code': 400}));

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.refreshToken(refreshToken);

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);
    });

    test('Get request with refresh token expiration', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);
      _mockRefreshToken(oauth2Client);

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      when(httpClient.get('https://my.test.url',
              headers: {'Authorization': 'Bearer ' + accessToken}))
          .thenAnswer(
              (_) async => http.Response('{"error": "invalid_token"}', 401));

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);

      await hlp.get('https://my.test.url', httpClient: httpClient);
      tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, renewedAccessToken);
    });

    test('Refresh token generic error', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);

      when(oauth2Client.refreshToken(refreshToken,
              clientId: clientId, clientSecret: clientSecret))
          .thenAnswer((_) async => AccessTokenResponse.fromMap(
              {'error': 'generic_error', 'http_status_code': 400}));

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      expect(() async => await hlp.refreshToken(refreshToken),
          throwsA(isInstanceOf<OAuth2Exception>()));
    });

    test('Test GET method with custom headers', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);
      _mockRefreshToken(oauth2Client);

      clearInteractions(httpClient);

      when(httpClient.get('https://my.test.url',
              headers: captureAnyNamed('headers')))
          .thenAnswer(
              (_) async => http.Response('{"error": "invalid_token"}', 401));

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      await hlp.get('https://my.test.url',
          httpClient: httpClient, headers: {'TestHeader': 'test'});

      expect(
          verify(httpClient.get('https://my.test.url',
                  headers: captureAnyNamed('headers')))
              .captured[0],
          {'TestHeader': 'test', 'Authorization': 'Bearer test_token_renewed'});
    });

    test('Test GET method without custom headers', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);
      _mockRefreshToken(oauth2Client);

      clearInteractions(httpClient);

      when(httpClient.get('https://my.test.url',
              headers: captureAnyNamed('headers')))
          .thenAnswer(
              (_) async => http.Response('{"error": "invalid_token"}', 401));

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      await hlp.get('https://my.test.url', httpClient: httpClient);

      expect(
          verify(httpClient.get('https://my.test.url',
                  headers: captureAnyNamed('headers')))
              .captured[0],
          {'Authorization': 'Bearer test_token_renewed'});
    });

    test('Test POST method with custom headers', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);
      _mockRefreshToken(oauth2Client);

      clearInteractions(httpClient);

      when(httpClient.post('https://my.test.url',
              headers: captureAnyNamed('headers')))
          .thenAnswer(
              (_) async => http.Response('{"error": "invalid_token"}', 401));

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      await hlp.post('https://my.test.url',
          httpClient: httpClient, headers: {'TestHeader': 'test'});

      expect(
          verify(httpClient.post('https://my.test.url',
                  headers: captureAnyNamed('headers')))
              .captured[0],
          {'TestHeader': 'test', 'Authorization': 'Bearer test_token_renewed'});
    });

    test('Test POST method without custom headers', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithAuthCodeFlow(oauth2Client);
      _mockRefreshToken(oauth2Client);

      clearInteractions(httpClient);

      when(httpClient.post('https://my.test.url',
              headers: captureAnyNamed('headers')))
          .thenAnswer(
              (_) async => http.Response('{"error": "invalid_token"}', 401));

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.AUTHORIZATION_CODE,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      await hlp.post('https://my.test.url', httpClient: httpClient);

      expect(
          verify(httpClient.post('https://my.test.url',
                  headers: captureAnyNamed('headers')))
              .captured[0],
          {'Authorization': 'Bearer test_token_renewed'});
    });

    test('Token revocation', () async {
      final tknResp = AccessTokenResponse.fromMap({
        'access_token': accessToken,
        'token_type': tokenType,
        'refresh_token': refreshToken,
        'scope': scopes,
        'expires_in': expiresIn,
        'http_status_code': 200
      });

      final tokenStorage = TokenStorageMock();
      when(tokenStorage.getToken(scopes)).thenAnswer((_) async => tknResp);
      when(tokenStorage.deleteToken(scopes)).thenAnswer((_) async => true);

      when(oauth2Client.revokeToken(tknResp,
              clientId: clientId,
              clientSecret: clientSecret,
              httpClient: httpClient))
          .thenAnswer(
              (_) async => OAuth2Response.fromMap({'http_status_code': 200}));

      final hlp = OAuth2Helper(oauth2Client,
          tokenStorage: tokenStorage,
          grantType: OAuth2Helper.CLIENT_CREDENTIALS,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      final revokeResp = await hlp.disconnect(httpClient: httpClient);

      expect(revokeResp.isValid(), true);
    });
  });

  test('Token revocation without a previously fetched token (fallback)',
      () async {
    final tokenStorage = TokenStorageMock();
    when(tokenStorage.getToken(scopes)).thenAnswer((_) async => null);

    final hlp = OAuth2Helper(oauth2Client,
        tokenStorage: tokenStorage,
        grantType: OAuth2Helper.CLIENT_CREDENTIALS,
        clientId: clientId,
        clientSecret: clientSecret,
        scopes: scopes);

    final revokeResp = await hlp.disconnect(httpClient: httpClient);

    expect(revokeResp.isValid(), true);
  });

  group('Client Credentials Grant.', () {
    test('Client Credentials Request without errors', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithClientCredentials(oauth2Client);

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.CLIENT_CREDENTIALS,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);
    });

    test('Client Credentials with token expiration', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithClientCredentials(oauth2Client,
          respMap: {'expires_in': 1});

      _mockRefreshToken(oauth2Client);

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.CLIENT_CREDENTIALS,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);

      await Future.delayed(const Duration(seconds: 2), () => 'X');

      tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, renewedAccessToken);
    });

    test('Client Credentials Request with server side token expiration',
        () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithClientCredentials(oauth2Client);
      _mockRefreshToken(oauth2Client);

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      when(httpClient.post('https://my.test.url',
              body: null, headers: {'Authorization': 'Bearer ' + accessToken}))
          .thenAnswer(
              (_) async => http.Response('{"error": "invalid_token"}', 401));

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.CLIENT_CREDENTIALS,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);

      await hlp.post('https://my.test.url', httpClient: httpClient);
      tknResp = await hlp.getToken();

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, renewedAccessToken);
    });

    test('Refresh token expiration', () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithClientCredentials(oauth2Client);

      when(oauth2Client.refreshToken(refreshToken,
              clientId: clientId, clientSecret: clientSecret))
          .thenAnswer((_) async => AccessTokenResponse.fromMap(
              {'error': 'invalid_grant', 'http_status_code': 400}));

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.CLIENT_CREDENTIALS,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.refreshToken(refreshToken);

      expect(tknResp.isValid(), true);
      expect(tknResp.accessToken, accessToken);
    });

    test(
        'Keep using previous refresh token when no newly refresh token returned',
        () async {
      final tokenStorage =
          TokenStorage(oauth2Client.tokenUrl, storage: VolatileStorage());

      _mockGetTokenWithClientCredentials(oauth2Client);

      when(oauth2Client.refreshToken(refreshToken,
              clientId: clientId, clientSecret: clientSecret))
          .thenAnswer((_) async => AccessTokenResponse.fromMap({
                'access_token': accessToken,
                'token_type': tokenType,
                'expires_in': expiresIn,
                'http_status_code': 200
              }));

      var hlp = OAuth2Helper(oauth2Client, tokenStorage: tokenStorage);

      hlp.setAuthorizationParams(
          grantType: OAuth2Helper.CLIENT_CREDENTIALS,
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: scopes);

      var tknResp = await hlp.refreshToken(refreshToken);

      expect(tknResp.isValid(), true);
      expect(tknResp.refreshToken, refreshToken);
    });
  });
}
