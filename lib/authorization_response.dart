/// Represents the response to an Authorization Request.
/// see https://tools.ietf.org/html/rfc6749#page-26
class AuthorizationResponse {
  String code;
  String idToken;
  String accessToken;
  String state;
  Map<String, String> queryParams;

  String error;
  String errorDescription;

  AuthorizationResponse();

  AuthorizationResponse.fromRedirectUri(String redirectUri, String checkState) {
    queryParams = Uri.parse(redirectUri).queryParameters;

    error = getQueryParam('error');
    errorDescription = getQueryParam('error_description');

    if (error == null) {
      code = getQueryParam('code');
      if (code == null) {
        throw Exception('Expected "code" parameter not found in response');
      }

      idToken = getQueryParam('id_token');
      if (idToken == null) {
        throw Exception('Expected "id_token" parameter not found in response');
      }

      accessToken = getQueryParam('access_token');
      if (accessToken == null) {
        throw Exception(
            'Expected "access_token" parameter not found in response');
      }

      state = getQueryParam('state');
      if (state == null) {
        throw Exception('Expected "state" parameter not found in response');
      }

      if (state != checkState) {
        throw Exception(
            '"state" parameter in response doesn\'t correspond to the expected value');
      }
    }
  }

  /// Returns the value of the [paramName] key in the queryParams map
  dynamic getQueryParam(String paramName) {
    return queryParams != null &&
            queryParams.containsKey(paramName) &&
            queryParams[paramName].isNotEmpty
        ? queryParams[paramName]
        : null;
  }

  bool isAccessGranted() {
    return error != null ? error.isEmpty : true;
  }
}
