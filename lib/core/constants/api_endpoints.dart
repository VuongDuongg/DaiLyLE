class ApiEndpoints {
  ApiEndpoints._();

  // Supabase Edge Function identifier
  static const String assessPronunciationEdgeFunction = 'assess-pronunciation';

  // Optional direct Python FastAPI endpoint (e.g. for local dev or private GPU cluster)
  static const String fastApiBaseUrl = 'http://localhost:8000';
  static const String fastApiAssess = '$fastApiBaseUrl/assess';
}

